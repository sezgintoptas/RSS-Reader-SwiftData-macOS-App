import Foundation

// MARK: - Uygulama Versiyon Bilgisi
// Her güncelleme sonrası bu dosya otomatik güncellenir.

enum AppVersion {
    /// Mevcut sürüm numarası (GitHub Release tag ile eşleşmeli)
    static let current = "1.13.3"

    /// GitHub repo bilgileri (auto-updater için)
    static let githubOwner = "sezgintoptas"
    static let githubRepo  = "RSS-Reader-SwiftData-macOS-App"

    /// GitHub Releases API URL'si (her zaman production)
    static var releasesAPIURL: URL {
        URL(string: "https://api.github.com/repos/\(githubOwner)/\(githubRepo)/releases/latest")!
    }
}
