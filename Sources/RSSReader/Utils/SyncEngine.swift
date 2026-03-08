import Foundation
import SwiftData
import FeedKit
import OSLog

/// ModelActor runs on a background context automatically
/// preventing any UI freezing during heavy sync/parsing tasks.
@ModelActor
actor SyncEngine {

    private let logger = Logger(subsystem: "com.rssreader.app", category: "SyncEngine")

    // MARK: - Tüm Besleme Senkronizasyonu

    /// Syncs all feeds currently in the database
    func syncAllFeeds() async {
        await syncDynamicOPMLs()

        do {
            let descriptor = FetchDescriptor<Feed>()
            let allFeeds = try modelContext.fetch(descriptor)

            // (feedTitle, newArticleCount, notificationsEnabled)
            var notificationBatch: [(String, Int, Bool)] = []

            for feed in allFeeds {
                guard feed.isActive else { continue }
                let newCount = await syncFeed(feed)
                if newCount > 0 {
                    notificationBatch.append((feed.title, newCount, feed.notificationsEnabled))
                }
            }

            try modelContext.save()
            logger.info("✅ Tüm beslemeler senkronize edildi.")

            purgeOldArticles()

            // Bildirimleri MainActor üzerinde gönder
            await sendNotifications(batch: notificationBatch)

        } catch {
            logger.error("Beslemeler çekilirken hata: \(error.localizedDescription)")
        }
    }

    // MARK: - Tek Besleme Senkronizasyonu
    // Dönen değer: kaç yeni makale eklendi

    @discardableResult
    private func syncFeed(_ feed: Feed) async -> Int {
        guard let url = URL(string: feed.url) else { return 0 }

        let parser = FeedParser(URL: url)

        do {
            let fetchedFeed = try await parser.parseAsync()
            var newCount = 0

            switch fetchedFeed {
            case .atom(let atomFeed):
                if let remoteTitle = atomFeed.title, !remoteTitle.isEmpty {
                    feed.title = remoteTitle
                }
                if feed.siteUrl == nil {
                    feed.siteUrl = atomFeed.links?
                        .first(where: { $0.attributes?.rel == "alternate" })?
                        .attributes?.href
                }
                newCount = processAtomFeed(atomFeed, into: feed)

            case .rss(let rssFeed):
                if let remoteTitle = rssFeed.title, !remoteTitle.isEmpty {
                    feed.title = remoteTitle
                }
                if feed.siteUrl == nil {
                    feed.siteUrl = rssFeed.link
                }
                newCount = processRSSFeed(rssFeed, into: feed)

            case .json(let jsonFeed):
                // ✅ JSON Feed desteği
                if let remoteTitle = jsonFeed.title, !remoteTitle.isEmpty {
                    feed.title = remoteTitle
                }
                if feed.siteUrl == nil {
                    feed.siteUrl = jsonFeed.homePageURL
                }
                newCount = processJSONFeed(jsonFeed, into: feed)
            }

            feed.lastUpdated = Date()

            // Başarılı → hata sayacını sıfırla
            feed.consecutiveFailures = 0
            feed.lastError = nil

            return newCount

        } catch {
            // ❌ Hata → sayacı artır, pasife al (3 ardışık hatadan sonra)
            feed.consecutiveFailures += 1
            feed.lastError = error.localizedDescription
            logger.warning("⚠️ \(feed.title) senkronize edilemedi (\(feed.consecutiveFailures). deneme): \(error.localizedDescription)")

            if feed.consecutiveFailures >= 3 {
                feed.isActive = false
                logger.error("❌ \(feed.title) 3 ardışık hata sonrası devre dışı bırakıldı.")
            }
            return 0
        }
    }

    // MARK: - Atom İşleyici

    @discardableResult
    private func processAtomFeed(_ atomFeed: AtomFeed, into feed: Feed) -> Int {
        let entries = atomFeed.entries ?? []
        var added = 0
        for entry in entries {
            let id    = entry.id ?? entry.links?.first?.attributes?.href ?? UUID().uuidString
            let title = entry.title ?? "İsimsiz Makale"
            let link  = entry.links?.first?.attributes?.href ?? ""
            let content = entry.content?.value ?? entry.summary?.value
            let date    = entry.published ?? entry.updated
            if insertArticleIfNotExists(id: id, title: title, link: link, content: content, publishedDate: date, for: feed) {
                added += 1
            }
        }
        return added
    }

    // MARK: - RSS İşleyici

    @discardableResult
    private func processRSSFeed(_ rssFeed: RSSFeed, into feed: Feed) -> Int {
        let items = rssFeed.items ?? []
        var added = 0
        for item in items {
            let id    = item.guid?.value ?? item.link ?? UUID().uuidString
            let title = item.title ?? "İsimsiz Makale"
            let link  = item.link ?? ""
            let content = item.content?.contentEncoded ?? item.description
            if insertArticleIfNotExists(id: id, title: title, link: link, content: content, publishedDate: item.pubDate, for: feed) {
                added += 1
            }
        }
        return added
    }

    // MARK: - JSON Feed İşleyici ✅

    @discardableResult
    private func processJSONFeed(_ jsonFeed: JSONFeed, into feed: Feed) -> Int {
        let items = jsonFeed.items ?? []
        var added = 0
        for item in items {
            let id      = item.id ?? item.url ?? UUID().uuidString
            let title   = item.title ?? "İsimsiz Makale"
            let link    = item.url ?? item.externalUrl ?? ""
            let content = item.contentHtml ?? item.contentText
            let date    = item.datePublished ?? item.dateModified
            if insertArticleIfNotExists(id: id, title: title, link: link, content: content, publishedDate: date, for: feed) {
                added += 1
            }
        }
        return added
    }

    // MARK: - Kopya Kontrolü

    /// true döner → yeni makale eklendi
    @discardableResult
    private func insertArticleIfNotExists(
        id: String, title: String, link: String, content: String?,
        publishedDate: Date?, for feed: Feed
    ) -> Bool {
        let descriptor = FetchDescriptor<Article>(predicate: #Predicate { $0.id == id })
        do {
            // Makale zaten varsa — isRead/isStarred durumuna DOKUNMA!
            if let existing = try modelContext.fetch(descriptor).first {
                // Sadece başlık değişmişse güncelle
                if existing.title != title { existing.title = title }
                return false // Yeni değil
            }

            // Gerçekten yeni makale — ekle
            let article = Article(
                id: id, title: title, link: link,
                content: content, publishedDate: publishedDate, feed: feed
            )
            modelContext.insert(article)
            return true
        } catch {
            logger.error("Unique attribute check error: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Bildirim Gönderme (MainActor)

    private func sendNotifications(batch: [(String, Int, Bool)]) async {
        // Her besleme ayrı ayrı bildirilir (notificationsEnabled=false olanlar atlanır)
        await MainActor.run {
            let manager = NotificationManager.shared
            var notifiedFeeds = 0
            var totalNew = 0
            for (title, count, enabled) in batch {
                if enabled {
                    manager.sendNewArticlesNotification(
                        feedTitle: title,
                        newCount: count,
                        feedNotificationsEnabled: true
                    )
                    notifiedFeeds += 1
                    totalNew += count
                }
            }
            // Eğer birden fazla bildirimli besleme varsa ek özet gönder (opsiyonel)
            // manager.sendSummaryNotification(totalNew: totalNew, feedCount: notifiedFeeds)
        }
    }

    // MARK: - Otomatik Veritabanı Temizliği

    private func purgeOldArticles() {
        let limit = UserDefaults.standard.integer(forKey: "articleArchiveLimit")
        let effectiveLimit = limit > 0 ? limit : 1000

        do {
            let descriptor = FetchDescriptor<Article>(
                predicate: #Predicate<Article> { !$0.isStarred },
                sortBy: [SortDescriptor(\Article.publishedDate, order: .reverse)]
            )
            let nonStarred = try modelContext.fetch(descriptor)
            if nonStarred.count > effectiveLimit {
                let toDelete = Array(nonStarred.dropFirst(effectiveLimit))
                toDelete.forEach { modelContext.delete($0) }
                try modelContext.save()
                logger.info("🗑 \(toDelete.count) eski makale silindi (limit: \(effectiveLimit))")
            }
        } catch {
            logger.error("Arşiv temizliği hatası: \(error.localizedDescription)")
        }
    }

    // MARK: - Dynamic OPML Sync

    func syncDynamicOPMLs() async {
        do {
            let subscriptions = try modelContext.fetch(FetchDescriptor<DynamicOPMLSubscription>())
            for subscription in subscriptions {
                await syncOPMLSubscription(subscription)
            }
        } catch {
            logger.error("Dinamik OPML hata: \(error.localizedDescription)")
        }
    }

    private func syncOPMLSubscription(_ subscription: DynamicOPMLSubscription) async {
        guard let url = URL(string: subscription.url) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let parser = OPMLParser()
            let (parsedFolders, parsedStandaloneFeeds) = parser.parse(data: data)

            for parsedFolder in parsedFolders {
                let folder = try getOrCreateFolder(name: parsedFolder.name)
                for parsedFeed in parsedFolder.feeds {
                    try getOrCreateFeed(title: parsedFeed.title, url: parsedFeed.xmlUrl, siteUrl: parsedFeed.siteUrl, folder: folder)
                }
            }
            for parsedFeed in parsedStandaloneFeeds {
                try getOrCreateFeed(title: parsedFeed.title, url: parsedFeed.xmlUrl, siteUrl: parsedFeed.siteUrl, folder: nil)
            }
            subscription.lastSynced = Date()
            try modelContext.save()
        } catch {
            logger.error("OPML indirme hatası \(url): \(error.localizedDescription)")
        }
    }

    private func getOrCreateFolder(name: String) throws -> Folder {
        let folderName = name
        let descriptor = FetchDescriptor<Folder>(predicate: #Predicate { $0.name == folderName })
        if let existing = try modelContext.fetch(descriptor).first { return existing }
        let newFolder = Folder(name: name)
        modelContext.insert(newFolder)
        return newFolder
    }

    @discardableResult
    private func getOrCreateFeed(title: String, url: String, siteUrl: String?, folder: Folder?) throws -> Feed {
        let targetUrl = url
        let descriptor = FetchDescriptor<Feed>(predicate: #Predicate { $0.url == targetUrl })
        if let existing = try modelContext.fetch(descriptor).first { return existing }
        let newFeed = Feed(title: title, url: url, siteUrl: siteUrl, folder: folder)
        modelContext.insert(newFeed)
        return newFeed
    }
}
