import Foundation
import Combine

/// Application settings'lerini (UserDefaults) iCloud (NSUbiquitousKeyValueStore) üzerinden otomatik senkronize eden yardımcı sınıf.
final class CloudSettingsManager: ObservableObject {
    static let shared = CloudSettingsManager()
    
    private let cloudStore = NSUbiquitousKeyValueStore.default
    private let localStore = UserDefaults.standard
    
    // MARK: - Durum
    
    enum SyncStatus: Equatable {
        case idle
        case syncing
        case synced(Date)
        case failed(String)
    }
    
    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncDate: Date?
    
    /// Senkronize edilecek anahtar kelimeler listesi.
    private let syncedKeys: Set<String> = [
        "refreshIntervalMinutes",
        "totalAdsBlocked",
        "activeAdBlockerFilterIDs",
        "adBlockerLastUpdated",
        "articleArchiveLimit"
    ]
    
    private init() {}
    
    /// Senkronizasyon servisini başlatır.
    func start() {
        // iCloud'dan gelen değişiklikleri dinle
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cloudStoreDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloudStore
        )
        
        // Yerel değişimleri dinle
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(localStoreDidChange),
            name: UserDefaults.didChangeNotification,
            object: localStore
        )
        
        // İlk açılışta verileri tazeleyelim
        syncToCloud()
        cloudStore.synchronize()
    }
    
    /// Manuel eşitleme tetikleyici — Ayarlar'daki buton tarafından çağrılır.
    func syncNow() {
        DispatchQueue.main.async {
            self.syncStatus = .syncing
        }
        
        syncToCloud()
        let success = cloudStore.synchronize()
        
        DispatchQueue.main.async {
            if success {
                let now = Date()
                self.lastSyncDate = now
                self.syncStatus = .synced(now)
                print("☁️ CloudSettingsManager: Manuel eşitleme tamamlandı.")
            } else {
                self.syncStatus = .failed("iCloud Key-Value Store eşitlenemedi. iCloud hesabınızı kontrol edin.")
                print("⚠️ CloudSettingsManager: Manuel eşitleme başarısız.")
            }
        }
    }
    
    /// iCloud'dan yerel storage'a verileri çeker.
    @objc private func cloudStoreDidChange(_ notification: Notification) {
        print("☁️ CloudSettingsManager: iCloud'da değişiklik algılandı, yerel ayarlar güncelleniyor...")
        
        for key in syncedKeys {
            if let cloudValue = cloudStore.object(forKey: key) {
                let localValue = localStore.object(forKey: key)
                if !isEqual(cloudValue, localValue) {
                    localStore.set(cloudValue, forKey: key)
                }
            }
        }
        
        DispatchQueue.main.async {
            let now = Date()
            self.lastSyncDate = now
            self.syncStatus = .synced(now)
        }
    }
    
    /// Yerel storage'dan iCloud'a verileri iteler.
    @objc private func localStoreDidChange(_ notification: Notification) {
        syncToCloud()
    }
    
    private func syncToCloud() {
        var changed = false
        for key in syncedKeys {
            let localValue = localStore.object(forKey: key)
            let cloudValue = cloudStore.object(forKey: key)
            
            if !isEqual(localValue, cloudValue) {
                cloudStore.set(localValue, forKey: key)
                changed = true
            }
        }
        
        if changed {
            print("☁️ CloudSettingsManager: Yerel değişiklikler iCloud'a itelendi.")
            cloudStore.synchronize()
        }
    }
    
    private func isEqual(_ lhs: Any?, _ rhs: Any?) -> Bool {
        guard let lhs = lhs, let rhs = rhs else { return lhs == nil && rhs == nil }
        
        if let l = lhs as? Int, let r = rhs as? Int { return l == r }
        if let l = lhs as? String, let r = rhs as? String { return l == r }
        if let l = lhs as? Bool, let r = rhs as? Bool { return l == r }
        if let l = lhs as? Double, let r = rhs as? Double { return l == r }
        if let l = lhs as? [String], let r = rhs as? [String] { return l == r }
        if let l = lhs as? Date, let r = rhs as? Date { return l == r }
        
        return false
    }
}
