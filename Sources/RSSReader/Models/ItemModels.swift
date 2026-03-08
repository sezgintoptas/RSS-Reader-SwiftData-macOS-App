import Foundation
import SwiftData

@Model
final class Folder {
    var id: UUID = UUID()
    var name: String = ""
    var sortIndex: Int = 0
    
    // Custom relationship
    @Relationship(deleteRule: .cascade, inverse: \Feed.folder)
    var feeds: [Feed]? = []
    
    init(id: UUID = UUID(), name: String, sortIndex: Int = 0) {
        self.id = id
        self.name = name
        self.sortIndex = sortIndex
    }
}

@Model
final class Feed {
    var id: UUID = UUID()
    var title: String = ""
    @Attribute(.unique) var url: String = ""
    var siteUrl: String?
    var lastUpdated: Date?
    var sortIndex: Int = 0
    var isActive: Bool = true

    // MARK: - Bildirim
    /// Kullanıcı bu besleme için bildirim almak istiyor mu?
    var notificationsEnabled: Bool = true

    // MARK: - Sağlık / Hata Takibi
    /// Art arda kaç kez senkronizasyon hatası oluştu?
    var consecutiveFailures: Int = 0
    /// Son hata mesajı (UI'da gösterilmek üzere)
    var lastError: String?

    var folder: Folder?

    @Relationship(deleteRule: .cascade, inverse: \Article.feed)
    var articles: [Article]? = []

    init(
        id: UUID = UUID(),
        title: String,
        url: String,
        siteUrl: String? = nil,
        lastUpdated: Date? = nil,
        folder: Folder? = nil,
        sortIndex: Int = 0,
        isActive: Bool = true,
        notificationsEnabled: Bool = true,
        consecutiveFailures: Int = 0,
        lastError: String? = nil
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.siteUrl = siteUrl
        self.lastUpdated = lastUpdated
        self.folder = folder
        self.sortIndex = sortIndex
        self.isActive = isActive
        self.notificationsEnabled = notificationsEnabled
        self.consecutiveFailures = consecutiveFailures
        self.lastError = lastError
    }
}

@Model
final class Article {
    @Attribute(.unique) var id: String = "" // Can be the GUID or URL from the RSS feed
    var title: String = ""
    var link: String?
    var content: String?
    var publishedDate: Date?
    var isRead: Bool = false
    var isStarred: Bool = false
    
    var feed: Feed?
    
    init(id: String, title: String, link: String? = nil, content: String? = nil, publishedDate: Date? = nil, isRead: Bool = false, isStarred: Bool = false, feed: Feed? = nil) {
        self.id = id
        self.title = title
        self.link = link
        self.content = content
        self.publishedDate = publishedDate
        self.isRead = isRead
        self.isStarred = isStarred
        self.feed = feed
    }
}

@Model
final class DynamicOPMLSubscription {
    var id: UUID = UUID()
    var url: String = ""
    var lastSynced: Date?
    
    init(id: UUID = UUID(), url: String, lastSynced: Date? = nil) {
        self.id = id
        self.url = url
        self.lastSynced = lastSynced
    }
}
