import Foundation

/// Kullanıcının makale okuma tercihi.
/// @AppStorage ile kalıcı olarak saklanır.
enum ReadingMode: String, CaseIterable, Identifiable {
    case inApp = "inApp"
    case readerMode = "readerMode"
    case externalSafari = "externalSafari"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .inApp: return "Uygulama İçi (uBlock Filtreli)"
        case .readerMode: return "Saf Okuma Modu (Reader Mode)"
        case .externalSafari: return "Harici Safari"
        }
    }
    
    var description: String {
        switch self {
        case .inApp: return "Makaleyi uygulama içinde WKWebView ile açar. EasyList reklam engelleme kuralları otomatik uygulanır."
        case .readerMode: return "Makale içeriğini ayıklayarak reklamsız, temiz bir görünümde gösterir."
        case .externalSafari: return "Makaleyi Safari tarayıcısında açar. Kurulu eklentiler (uBlock Origin vb.) devreye girer."
        }
    }
}
