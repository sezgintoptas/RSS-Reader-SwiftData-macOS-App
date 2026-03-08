import Foundation
import SwiftData
import OSLog

/// Uygulama verilerini JSON formatında yedekler ve geri yükler.
/// Yedek dosyaları: ~/Documents/RSSReader Backups/
@MainActor
final class BackupManager: ObservableObject {
    static let shared = BackupManager()
    
    private let logger = Logger(subsystem: "com.rssreader.app", category: "BackupManager")
    
    enum BackupStatus: Equatable {
        case idle
        case inProgress
        case success(String) // mesaj
        case failed(String)  // hata mesajı
    }
    
    @Published var status: BackupStatus = .idle
    @Published var lastBackupDate: Date? = UserDefaults.standard.object(forKey: "lastBackupDate") as? Date
    
    private init() {}
    
    // MARK: - Yedekleme Dizini
    
    var backupDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("RSSReader Backups", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    // MARK: - Dışa Aktar (Export)
    
    func exportBackup(modelContext: ModelContext) {
        status = .inProgress
        
        do {
            // Tüm verileri çek
            let folders = try modelContext.fetch(FetchDescriptor<Folder>(sortBy: [SortDescriptor(\.sortIndex)]))
            let feeds = try modelContext.fetch(FetchDescriptor<Feed>(sortBy: [SortDescriptor(\.sortIndex)]))
            let articles = try modelContext.fetch(FetchDescriptor<Article>(sortBy: [SortDescriptor(\.publishedDate, order: .reverse)]))
            let opmlSubs = try modelContext.fetch(FetchDescriptor<DynamicOPMLSubscription>())
            
            // Codable modellere dönüştür
            let backupData = BackupData(
                version: 1,
                exportDate: Date(),
                appVersion: AppVersion.current,
                folders: folders.map { FolderBackup(from: $0) },
                feeds: feeds.map { FeedBackup(from: $0) },
                starredArticles: articles.filter { $0.isStarred }.map { ArticleBackup(from: $0) },
                readArticleIDs: articles.filter { $0.isRead }.map { $0.id },
                opmlSubscriptions: opmlSubs.map { OPMLBackup(from: $0) }
            )
            
            // JSON olarak kaydet
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(backupData)
            
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HH-mm"
            let fileName = "RSSReader_Backup_\(formatter.string(from: Date())).json"
            let fileURL = backupDirectory.appendingPathComponent(fileName)
            
            try data.write(to: fileURL)
            
            let now = Date()
            lastBackupDate = now
            UserDefaults.standard.set(now, forKey: "lastBackupDate")
            
            let sizeKB = ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
            status = .success("\(fileName) (\(sizeKB)) kaydedildi")
            logger.info("✅ Yedekleme tamamlandı: \(fileName) — \(feeds.count) besleme, \(articles.filter { $0.isStarred }.count) favori makale")
            
        } catch {
            status = .failed(error.localizedDescription)
            logger.error("❌ Yedekleme hatası: \(error.localizedDescription)")
        }
    }
    
    // MARK: - İçe Aktar (Import / Restore)
    
    func importBackup(from url: URL, modelContext: ModelContext) {
        status = .inProgress
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let backupData = try decoder.decode(BackupData.self, from: data)
            
            var restoredFeeds = 0
            var restoredFolders = 0
            var restoredStarred = 0
            
            // 1. Klasörleri geri yükle
            var folderMap: [UUID: Folder] = [:]
            for folderBackup in backupData.folders {
                let folderName = folderBackup.name
                let descriptor = FetchDescriptor<Folder>(predicate: #Predicate { $0.name == folderName })
                if let existing = try modelContext.fetch(descriptor).first {
                    folderMap[folderBackup.id] = existing
                } else {
                    let folder = Folder(id: folderBackup.id, name: folderBackup.name, sortIndex: folderBackup.sortIndex)
                    modelContext.insert(folder)
                    folderMap[folderBackup.id] = folder
                    restoredFolders += 1
                }
            }
            
            // 2. Beslemeleri geri yükle
            var feedMap: [UUID: Feed] = [:]
            for feedBackup in backupData.feeds {
                let feedUrl = feedBackup.url
                let descriptor = FetchDescriptor<Feed>(predicate: #Predicate { $0.url == feedUrl })
                if let existing = try modelContext.fetch(descriptor).first {
                    feedMap[feedBackup.id] = existing
                    // Mevcut feed'in ayarlarını güncelle
                    existing.notificationsEnabled = feedBackup.notificationsEnabled
                    existing.sortIndex = feedBackup.sortIndex
                } else {
                    let folder = feedBackup.folderID.flatMap { folderMap[$0] }
                    let feed = Feed(
                        id: feedBackup.id,
                        title: feedBackup.title,
                        url: feedBackup.url,
                        siteUrl: feedBackup.siteUrl,
                        folder: folder,
                        sortIndex: feedBackup.sortIndex,
                        notificationsEnabled: feedBackup.notificationsEnabled
                    )
                    modelContext.insert(feed)
                    feedMap[feedBackup.id] = feed
                    restoredFeeds += 1
                }
            }
            
            // 3. Favori makaleleri geri yükle
            for articleBackup in backupData.starredArticles {
                let articleID = articleBackup.id
                let descriptor = FetchDescriptor<Article>(predicate: #Predicate { $0.id == articleID })
                let existing = try modelContext.fetch(descriptor).first
                if let existing = existing {
                    existing.isStarred = true
                } else {
                    let feed = articleBackup.feedID.flatMap { feedMap[$0] }
                    let article = Article(
                        id: articleBackup.id,
                        title: articleBackup.title,
                        link: articleBackup.link,
                        content: articleBackup.content,
                        publishedDate: articleBackup.publishedDate,
                        isRead: true,
                        isStarred: true,
                        feed: feed
                    )
                    modelContext.insert(article)
                    restoredStarred += 1
                }
            }
            
            // 4. Okunmuş durumlarını geri yükle
            for readID in backupData.readArticleIDs {
                let rid = readID
                let descriptor = FetchDescriptor<Article>(predicate: #Predicate { $0.id == rid })
                if let article = try modelContext.fetch(descriptor).first {
                    article.isRead = true
                }
            }
            
            // 5. OPML aboneliklerini geri yükle
            for opml in backupData.opmlSubscriptions {
                let opmlUrl = opml.url
                let descriptor = FetchDescriptor<DynamicOPMLSubscription>(predicate: #Predicate { $0.url == opmlUrl })
                if try modelContext.fetch(descriptor).first == nil {
                    let sub = DynamicOPMLSubscription(url: opml.url)
                    modelContext.insert(sub)
                }
            }
            
            try modelContext.save()
            
            status = .success("\(restoredFolders) klasör, \(restoredFeeds) besleme, \(restoredStarred) favori makale geri yüklendi")
            logger.info("✅ Geri yükleme tamamlandı: \(restoredFolders) klasör, \(restoredFeeds) besleme, \(restoredStarred) favori")
            
        } catch {
            status = .failed("Geri yükleme hatası: \(error.localizedDescription)")
            logger.error("❌ Geri yükleme hatası: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Yedek Dosyalarını Listele
    
    func listBackups() -> [BackupFileInfo] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: backupDirectory, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey]) else {
            return []
        }
        
        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> BackupFileInfo? in
                let attrs = try? fm.attributesOfItem(atPath: url.path)
                let size = attrs?[.size] as? Int ?? 0
                let date = attrs?[.creationDate] as? Date ?? Date()
                return BackupFileInfo(url: url, fileName: url.lastPathComponent, date: date, size: size)
            }
            .sorted { $0.date > $1.date }
    }
}

// MARK: - Yedek Dosya Bilgisi

struct BackupFileInfo: Identifiable {
    let id = UUID()
    let url: URL
    let fileName: String
    let date: Date
    let size: Int
    
    var sizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
}

// MARK: - JSON Modelleri (Codable)

struct BackupData: Codable {
    let version: Int
    let exportDate: Date
    let appVersion: String
    let folders: [FolderBackup]
    let feeds: [FeedBackup]
    let starredArticles: [ArticleBackup]
    let readArticleIDs: [String]
    let opmlSubscriptions: [OPMLBackup]
}

struct FolderBackup: Codable {
    let id: UUID
    let name: String
    let sortIndex: Int
    
    init(from folder: Folder) {
        self.id = folder.id
        self.name = folder.name
        self.sortIndex = folder.sortIndex
    }
}

struct FeedBackup: Codable {
    let id: UUID
    let title: String
    let url: String
    let siteUrl: String?
    let sortIndex: Int
    let notificationsEnabled: Bool
    let folderID: UUID?
    
    init(from feed: Feed) {
        self.id = feed.id
        self.title = feed.title
        self.url = feed.url
        self.siteUrl = feed.siteUrl
        self.sortIndex = feed.sortIndex
        self.notificationsEnabled = feed.notificationsEnabled
        self.folderID = feed.folder?.id
    }
}

struct ArticleBackup: Codable {
    let id: String
    let title: String
    let link: String?
    let content: String?
    let publishedDate: Date?
    let feedID: UUID?
    
    init(from article: Article) {
        self.id = article.id
        self.title = article.title
        self.link = article.link
        self.content = article.content
        self.publishedDate = article.publishedDate
        self.feedID = article.feed?.id
    }
}

struct OPMLBackup: Codable {
    let url: String
    
    init(from sub: DynamicOPMLSubscription) {
        self.url = sub.url
    }
}
