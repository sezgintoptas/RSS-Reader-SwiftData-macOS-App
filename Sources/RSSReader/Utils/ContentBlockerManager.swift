import Foundation
import WebKit

#if os(macOS)

enum FilterCategory: String, CaseIterable, Identifiable {
    case ads = "Reklamlar"
    case privacy = "Gizlilik"
    case malware = "Zararlı Alan Adları"
    case annoyances = "Rahatsız Ediciler"
    case other = "Diğer / Düzeltmeler"
    
    var id: String { self.rawValue }
}

struct AdBlockerFilterOption: Identifiable, Hashable {
    let id: String
    let displayName: String
    let category: FilterCategory
    let rawURLStrings: [String]
}

let availableFilters: [AdBlockerFilterOption] = [
    // Ads
    AdBlockerFilterOption(id: "easylist", displayName: "EasyList", category: .ads, rawURLStrings: [
        "https://github.com/bnema/ublock-webkit-filters/releases/latest/download/easylist-part1.json",
        "https://github.com/bnema/ublock-webkit-filters/releases/latest/download/easylist-part2.json",
        "https://github.com/bnema/ublock-webkit-filters/releases/latest/download/easylist-part3.json"
    ]),
    AdBlockerFilterOption(id: "peter-lowe", displayName: "Peter Lowe - Ads", category: .ads, rawURLStrings: [
        "https://github.com/bnema/ublock-webkit-filters/releases/latest/download/peter-lowe.json"
    ]),
    AdBlockerFilterOption(id: "ublock-filters", displayName: "uBlock filters - Ads", category: .ads, rawURLStrings: [
        "https://github.com/bnema/ublock-webkit-filters/releases/latest/download/ublock-filters.json"
    ]),
    
    // Privacy
    AdBlockerFilterOption(id: "easyprivacy", displayName: "EasyPrivacy", category: .privacy, rawURLStrings: [
        "https://github.com/bnema/ublock-webkit-filters/releases/latest/download/easyprivacy-part1.json",
        "https://github.com/bnema/ublock-webkit-filters/releases/latest/download/easyprivacy-part2.json",
        "https://github.com/bnema/ublock-webkit-filters/releases/latest/download/easyprivacy-part3.json"
    ]),
    AdBlockerFilterOption(id: "ublock-privacy", displayName: "uBlock filters - Privacy", category: .privacy, rawURLStrings: [
        "https://github.com/bnema/ublock-webkit-filters/releases/latest/download/ublock-privacy.json"
    ]),
    
    // Malware
    AdBlockerFilterOption(id: "ublock-badware", displayName: "uBlock filters - Badware risks", category: .malware, rawURLStrings: [
        "https://github.com/bnema/ublock-webkit-filters/releases/latest/download/ublock-badware.json"
    ]),
    
    // Other (and default mapped annoyances for standard uBlock config)
    AdBlockerFilterOption(id: "ublock-quick-fixes", displayName: "uBlock Quick Fixes", category: .other, rawURLStrings: [
        "https://github.com/bnema/ublock-webkit-filters/releases/latest/download/ublock-quick-fixes.json"
    ]),
    AdBlockerFilterOption(id: "ublock-unbreak", displayName: "uBlock Unbreak", category: .other, rawURLStrings: [
        "https://github.com/bnema/ublock-webkit-filters/releases/latest/download/ublock-unbreak.json"
    ])
]

/// Reklam engelleme kurallarını internetten indirip
/// WKContentRuleList olarak derleyen singleton yönetici.
@MainActor
final class ContentBlockerManager: ObservableObject {
    static let shared = ContentBlockerManager()
    
    @Published private(set) var ruleLists: [WKContentRuleList] = []
    @Published private(set) var isActive = false
    @Published private(set) var isError = false
    @Published private(set) var lastUpdatedDate: Date?
    
    @Published var activeFilterIDs: Set<String> = [] {
        didSet {
            let array = Array(activeFilterIDs)
            UserDefaults.standard.set(array, forKey: "activeAdBlockerFilterIDs")
            // Async olarak yeni listeyi yükle
            Task {
                await loadRules(forceUpdate: false)
            }
        }
    }
    
    private var isLoading = false
    
    /// Cache dosya yolu (Application Support/RSSReader/)
    private func cacheFileURL(for filter: String, part: Int) -> URL {
        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupportDir.appendingPathComponent("RSSReader", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("\(filter)_part\(part)_content_blocker.json")
    }
    
    private init() {
        self.lastUpdatedDate = UserDefaults.standard.object(forKey: "adBlockerLastUpdated") as? Date
        if let savedArray = UserDefaults.standard.stringArray(forKey: "activeAdBlockerFilterIDs") {
            self.activeFilterIDs = Set(savedArray)
        } else {
            // Default olarak temel kuralları aç
            self.activeFilterIDs = ["easylist", "easyprivacy", "ublock-filters"]
        }
    }
    
    /// Tüm aktif filtreleri yükler (sırayla veya cache'ten okuyarak)
    func loadRules(forceUpdate: Bool = false) async {
        guard !isLoading else { return }
        isLoading = true
        self.isActive = false
        self.isError = false
        defer {
            isLoading = false
        }
        
        let filterIDs = activeFilterIDs
        print("ContentBlocker: \(filterIDs.count) adet aktif filtre yükleniyor...")
        
        if filterIDs.isEmpty {
            self.ruleLists = []
            self.isActive = true
            return
        }
        
        var newRuleLists = [WKContentRuleList]()
        var anyError = false
        
        for filterID in filterIDs {
            guard let filter = availableFilters.first(where: { $0.id == filterID }) else { continue }
            
            var didCompileFilter = false
            
            // 1. Force update değilse Cache'ten oku
            if !forceUpdate {
                var allCachedRules = [String]()
                var cacheExists = true
                
                for (index, _) in filter.rawURLStrings.enumerated() {
                    if let cachedJSON = loadFromCache(for: filter.id, part: index) {
                        allCachedRules.append(cachedJSON)
                    } else {
                        cacheExists = false
                        break
                    }
                }
                
                if cacheExists && !allCachedRules.isEmpty {
                    let compiledRules = await compileMultipleRules(jsons: allCachedRules, baseIdentifier: filter.id)
                    if compiledRules.count == allCachedRules.count {
                        newRuleLists.append(contentsOf: compiledRules)
                        didCompileFilter = true
                    }
                }
            }
            
            // 2. İnternetten indir
            if !didCompileFilter {
                if let downloadedRules = await downloadAndCompile(filter: filter) {
                    newRuleLists.append(contentsOf: downloadedRules)
                } else {
                    anyError = true
                }
            }
        }
        
        self.ruleLists = newRuleLists
        
        if anyError {
            self.isError = true
            self.isActive = false // Tamamı yüklenmedi
        } else {
            self.isActive = true
            self.isError = false
            
            // Güncelleme tarihini sadece force update veya başarılı internet çekimlerinde yenileyebiliriz
            let now = Date()
            self.lastUpdatedDate = now
            UserDefaults.standard.set(now, forKey: "adBlockerLastUpdated")
        }
    }
    
    /// Cache'ten JSON oku
    private func loadFromCache(for filterID: String, part: Int) -> String? {
        let url = cacheFileURL(for: filterID, part: part)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }
    
    /// İnternetten indir ve cache'le, ardından derleyip listeyi döner
    private func downloadAndCompile(filter: AdBlockerFilterOption) async -> [WKContentRuleList]? {
        var downloadedJsons = [String]()
        
        for (index, urlString) in filter.rawURLStrings.enumerated() {
            guard let url = URL(string: urlString) else { continue }
            if let json = await downloadJSON(from: url) {
                saveToCache(json, for: filter.id, part: index)
                downloadedJsons.append(json)
            } else {
                print("ContentBlocker: Kural part \(index) indirilemedi. (\(filter.id))")
            }
        }
        
        if downloadedJsons.count == filter.rawURLStrings.count {
            return await compileMultipleRules(jsons: downloadedJsons, baseIdentifier: filter.id)
        } else {
            print("ContentBlocker: İnternet erişimi başarısız, kurallar eksik indirilemedi/derlenemedi. (\(filter.id))")
            return nil
        }
    }
    
    /// URL'den JSON indir
    private func downloadJSON(from url: URL) async -> String? {
        do {
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("ContentBlocker: HTTP hatası, URL: \(url)")
                return nil
            }
            let jsonString = String(data: data, encoding: .utf8)
            print("ContentBlocker: JSON başarıyla indirildi (\(data.count) byte) from \(url.lastPathComponent)")
            return jsonString
        } catch {
            print("ContentBlocker: İndirme hatası: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// JSON'u disk cache'ine kaydet
    private func saveToCache(_ json: String, for filterID: String, part: Int) {
        let url = cacheFileURL(for: filterID, part: part)
        do {
            try json.write(to: url, atomically: true, encoding: .utf8)
            print("ContentBlocker: JSON cache'e kaydedildi. (\(filterID)_part\(part))")
        } catch {
            print("ContentBlocker: Cache kaydetme hatası: \(error.localizedDescription)")
        }
    }
    
    /// Birden fazla WKContentRuleList derle
    private func compileMultipleRules(jsons: [String], baseIdentifier: String) async -> [WKContentRuleList] {
        var rules = [WKContentRuleList]()
        
        for (index, json) in jsons.enumerated() {
            let identifier = "\(baseIdentifier)_part\(index)"
            if let compiled = await compileRule(from: json, identifier: identifier) {
                rules.append(compiled)
            }
        }
        
        return rules
    }
    
    /// Tekil WKContentRuleList derle
    private func compileRule(from jsonString: String, identifier: String) async -> WKContentRuleList? {
        return await withCheckedContinuation { continuation in
            // Main thread'de çalıştırdığımızdan emin olmak WKWebKit işlemlerinde iyidir
            WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: identifier,
                encodedContentRuleList: jsonString
            ) { compiledList, error in
                if let error = error {
                    print("ContentBlocker: Kural derleme hatası [\(identifier)]: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                } else if let compiledList = compiledList {
                    print("ContentBlocker: Reklam engelleme kuralları başarıyla derlendi. (\(identifier))")
                    continuation.resume(returning: compiledList)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    // MARK: - YouTube Whitelist
    
    /// YouTube ve ilişkili domain'ler için URL kontrolü.
    /// Bu domain'lerde content blocker devre dışı bırakılır.
    static func isYouTubeRelatedURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        let youtubeDomains = [
            "youtube.com", "www.youtube.com", "m.youtube.com",
            "youtu.be",
            "youtube-nocookie.com", "www.youtube-nocookie.com",
            "googlevideo.com",      // video stream
            "ytimg.com", "i.ytimg.com", "s.ytimg.com", "img.youtube.com", // thumbnail
            "yt3.ggpht.com",        // channel avatars
            "accounts.google.com",  // login
            "accounts.youtube.com"
        ]
        return youtubeDomains.contains(where: { host == $0 || host.hasSuffix(".\($0)") })
    }
}

#endif
