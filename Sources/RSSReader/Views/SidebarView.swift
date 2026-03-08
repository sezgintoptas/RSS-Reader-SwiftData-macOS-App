import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AppKit

enum SmartFolder: String, CaseIterable, Identifiable, Hashable {
    case allFeeds = "Tüm Beslemeler"
    case allUnread = "Okunmayanlar"
    case arrivedToday = "Bugün"
    case starred = "Favoriler"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .allFeeds: return "tray.2.fill"
        case .allUnread: return "tray.full.fill"
        case .arrivedToday: return "sun.max.fill"
        case .starred: return "star.fill"
        }
    }
}

enum SidebarItem: Hashable {
    case smartFolder(SmartFolder)
    case feed(Feed)
}

struct SidebarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Folder.sortIndex) private var folders: [Folder]
    @Query(sort: \Feed.sortIndex) private var allFeeds: [Feed]
    
    @Binding var selectedSidebarItem: SidebarItem?
    @Binding var showingManageFeeds: Bool
    
    @State private var showingAddDynamicOPML = false
    @State private var dynamicOPMLURL = ""
    @State private var showingAddRSS = false
    @State private var newRSSURL = ""
    
    var body: some View {
        let sortedFolders = folders.sorted { $0.sortIndex < $1.sortIndex }
        let standaloneFeeds = allFeeds.filter { $0.folder == nil }.sorted { $0.sortIndex < $1.sortIndex }
        
        List(selection: $selectedSidebarItem) {
            // MARK: - Akıllı Klasörler (Smart Filters)
            Section(header: Text("Akıllı Klasörler")) {
                ForEach(SmartFolder.allCases) { smartFolder in
                    NavigationLink(value: SidebarItem.smartFolder(smartFolder)) {
                        SmartFolderRowView(smartFolder: smartFolder)
                    }
                }
            }
            
            // MARK: - Klasörler ve içindeki beslemeler
            ForEach(sortedFolders) { folder in
                Section(header: Text(folder.name)) {
                    let sortedFeeds = (folder.feeds ?? []).sorted { $0.sortIndex < $1.sortIndex }
                    ForEach(sortedFeeds) { feed in
                        NavigationLink(value: SidebarItem.feed(feed)) {
                            FeedRowView(feed: feed)
                        }
                    }
                    .onMove { source, destination in
                        moveFeedsInFolder(folder: folder, from: source, to: destination)
                    }
                }
            }
            .onMove { source, destination in
                moveFolders(from: source, to: destination)
            }
            
            // MARK: - Klasörsüz beslemeler
            if !standaloneFeeds.isEmpty {
                Section(header: Text("Diğer Beslemeler")) {
                    ForEach(standaloneFeeds) { feed in
                        NavigationLink(value: SidebarItem.feed(feed)) {
                            FeedRowView(feed: feed)
                        }
                    }
                }
            }
        }
        .navigationTitle("RSS Okuyucu")
        #if os(macOS)
        .navigationSplitViewColumnWidth(min: 200, ideal: 250)
        #endif
        .toolbar {
            ToolbarItem {
                Menu {
                    Button(action: syncFeeds) {
                        Label("Senkronize Et", systemImage: "arrow.clockwise")
                    }
                    Button(action: importOPML) {
                        Label("OPML İçe Aktar", systemImage: "square.and.arrow.down")
                    }
                    Button(action: { showingAddDynamicOPML = true }) {
                        Label("Dinamik OPML Ekle", systemImage: "link.badge.plus")
                    }
                    Button(action: { showingAddRSS = true }) {
                        Label("RSS Ekle", systemImage: "plus.circle")
                    }
                    Divider()
                    Button(action: { showingManageFeeds = true }) {
                        Label("Beslemeleri Yönet", systemImage: "list.bullet.rectangle")
                    }
                    Divider()
                    SettingsLink {
                        Label("Ayarlar", systemImage: "gearshape")
                    }
                } label: {
                    Label("Seçenekler", systemImage: "ellipsis.circle")
                }
            }
        }
        .alert("Dinamik OPML Ekle", isPresented: $showingAddDynamicOPML) {
            TextField("OPML URL", text: $dynamicOPMLURL)
            Button("İptal", role: .cancel) {
                dynamicOPMLURL = ""
            }
            Button("Ekle") {
                addDynamicOPML()
            }
        } message: {
            Text("Inoreader, Feedly gibi servislerden aldığınız OPML veya Feed yönlendirme linkini girin.")
        }
        .alert("RSS Ekle", isPresented: $showingAddRSS) {
            TextField("RSS URL", text: $newRSSURL)
            Button("İptal", role: .cancel) {
                newRSSURL = ""
            }
            Button("Ekle") {
                addRSS()
            }
        } message: {
            Text("Gerçek bir RSS veya Atom besleme bağlantısı girin.")
        }
    }
    
    // MARK: - Sürükle-Bırak Sıralama
    
    private func moveFolders(from source: IndexSet, to destination: Int) {
        var sortedFolders = folders.sorted { $0.sortIndex < $1.sortIndex }
        sortedFolders.move(fromOffsets: source, toOffset: destination)
        for (index, folder) in sortedFolders.enumerated() {
            folder.sortIndex = index
        }
        try? modelContext.save()
    }
    
    private func moveFeedsInFolder(folder: Folder, from source: IndexSet, to destination: Int) {
        guard var feeds = folder.feeds?.sorted(by: { $0.sortIndex < $1.sortIndex }) else { return }
        feeds.move(fromOffsets: source, toOffset: destination)
        for (index, feed) in feeds.enumerated() {
            feed.sortIndex = index
        }
        try? modelContext.save()
    }
    
    // MARK: - Dinamik OPML
    
    private func addDynamicOPML() {
        guard let _ = URL(string: dynamicOPMLURL), !dynamicOPMLURL.isEmpty else { return }
        let subscription = DynamicOPMLSubscription(url: dynamicOPMLURL)
        modelContext.insert(subscription)
        dynamicOPMLURL = ""
        syncFeeds()
    }
    
    // MARK: - OPML İçe Aktarma
    
    private func importOPML() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [UTType.xml, UTType(filenameExtension: "opml")].compactMap { $0 }
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try Data(contentsOf: url)
                let parser = OPMLParser()
                let result = parser.parse(data: data)
                
                for parsedFolder in result.folders {
                    let folder = Folder(name: parsedFolder.name)
                    modelContext.insert(folder)
                    
                    for parsedFeed in parsedFolder.feeds {
                        let feed = Feed(title: parsedFeed.title, url: parsedFeed.xmlUrl, siteUrl: parsedFeed.siteUrl, folder: folder)
                        modelContext.insert(feed)
                    }
                }
                
                for parsedFeed in result.feeds {
                    let feed = Feed(title: parsedFeed.title, url: parsedFeed.xmlUrl, siteUrl: parsedFeed.siteUrl, folder: nil)
                    modelContext.insert(feed)
                }
            } catch {
                print("OPML okuma hatası: \(error)")
            }
        }
    }
    
    // MARK: - RSS Ekleme
    
    private func addRSS() {
        guard let _ = URL(string: newRSSURL), !newRSSURL.isEmpty else { return }
        let newFeed = Feed(title: newRSSURL, url: newRSSURL, folder: nil)
        modelContext.insert(newFeed)
        newRSSURL = ""
        syncFeeds()
    }
    
    // MARK: - Senkronizasyon
    
    private func syncFeeds() {
        Task {
            let container = modelContext.container
            let engine = SyncEngine(modelContainer: container)
            await engine.syncAllFeeds()
        }
    }
}

// MARK: - SmartFolderRowView

struct SmartFolderRowView: View {
    let smartFolder: SmartFolder
    @Query private var articles: [Article]
    
    init(smartFolder: SmartFolder) {
        self.smartFolder = smartFolder
        
        switch smartFolder {
        case .allFeeds:
            // Tüm makaleler (filtre yok)
            _articles = Query(sort: \Article.publishedDate, order: .reverse)
        case .allUnread:
            let predicate = #Predicate<Article> { !$0.isRead }
            _articles = Query(filter: predicate)
        case .arrivedToday:
            let now = Date()
            let startOfDay = Calendar.current.startOfDay(for: now)
            let predicate = #Predicate<Article> { article in
                if let date = article.publishedDate {
                    return date >= startOfDay
                } else {
                    return false
                }
            }
            _articles = Query(filter: predicate)
        case .starred:
            let predicate = #Predicate<Article> { $0.isStarred }
            _articles = Query(filter: predicate)
        }
    }
    
    var body: some View {
        HStack {
            Image(systemName: smartFolder.iconName)
                .frame(width: 16, height: 16)
                .foregroundColor(.accentColor)
            Text(smartFolder.rawValue)
                .lineLimit(1)
            Spacer()
            
            let count: Int = {
                switch smartFolder {
                case .allFeeds:
                    return articles.count
                case .allUnread:
                    return articles.count
                case .arrivedToday:
                    return articles.filter { !$0.isRead }.count
                case .starred:
                    return articles.count
                }
            }()
            
            if count > 0 {
                Text("\(count)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
            }
        }
    }
}

// MARK: - FeedRowView

struct FeedRowView: View {
    let feed: Feed

    /// Hata durumu var mı?
    private var hasError: Bool { feed.consecutiveFailures > 0 }

    var body: some View {
        HStack(spacing: 6) {
            // Favicon
            if let host = URL(string: feed.url)?.host {
                AsyncImage(url: URL(string: "https://s2.googleusercontent.com/s2/favicons?domain=\(host)&sz=64")) { image in
                    image.resizable().frame(width: 16, height: 16).cornerRadius(4)
                } placeholder: {
                    Image(systemName: "dot.radiowaves.up.forward").frame(width: 16, height: 16)
                }
            } else {
                Image(systemName: "dot.radiowaves.up.forward").frame(width: 16, height: 16)
            }

            // Başlık
            Text(feed.title)
                .lineLimit(1)
                .foregroundColor(feed.isActive ? .primary : .secondary)

            // ———— Durum ikonları ————

            // Hata uyarısı
            if hasError {
                let tip = feed.lastError ?? "Senkronizasyon hatası"
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundColor(feed.consecutiveFailures >= 3 ? .red : .orange)
                    .help(tip)
            }

            // Devre dışı (manuel veya 3 hata sonrası)
            if !feed.isActive && !hasError {
                Image(systemName: "pause.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Bildirim kapalı göstergesi
            if !feed.notificationsEnabled {
                Image(systemName: "bell.slash.fill")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .help("Bu besleme için bildirimler kapalı")
            }

            Spacer()

            // Okunmamış sayısı
            let unreadCount = feed.articles?.filter { !$0.isRead }.count ?? 0
            if unreadCount > 0 {
                Text("\(unreadCount)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(hasError ? Color.orange : Color.accentColor)
                    .clipShape(Capsule())
            }
        }
    }
}

