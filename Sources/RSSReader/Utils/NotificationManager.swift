import Foundation
import UserNotifications
import OSLog

// MARK: - Bildirim Yöneticisi
// Her beslemedeki notificationsEnabled bayrağını okuyarak
// yalnızca kullanıcının seçtiği kaynakların yeni makalelerini bildirir.

@MainActor
final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    private let logger = Logger(subsystem: "com.rssreader.app", category: "Notifications")

    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private init() {
        if Bundle.main.bundleIdentifier != nil {
            refreshAuthorizationStatus()
        }
    }

    // MARK: - İzin İste

    func requestPermission() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { [weak self] granted, error in
            Task { @MainActor [weak self] in
                self?.refreshAuthorizationStatus()
                if let error = error {
                    self?.logger.error("Bildirim izni hatası: \(error.localizedDescription)")
                }
            }
        }
    }

    func refreshAuthorizationStatus() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            Task { @MainActor [weak self] in
                self?.authorizationStatus = settings.authorizationStatus
            }
        }
    }

    // MARK: - Yeni Makale Bildirimi

    /// Senkronizasyon sonrası yeni bulunan makaleleri bildirir.
    /// feedNotificationsEnabled: false olan beslemeler sessizce atlanır.
    func sendNewArticlesNotification(feedTitle: String, newCount: Int, feedNotificationsEnabled: Bool) {
        guard Bundle.main.bundleIdentifier != nil else { return }
        guard feedNotificationsEnabled else { return }
        guard authorizationStatus == .authorized else { return }
        guard newCount > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = feedTitle
        content.body = newCount == 1
            ? "1 yeni makale"
            : "\(newCount) yeni makale"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "feed-\(feedTitle)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil  // Anlık
        )

        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error = error {
                self?.logger.error("Bildirim gönderilemedi (\(feedTitle)): \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Özet Bildirim (toplam)

    func sendSummaryNotification(totalNew: Int, feedCount: Int) {
        guard Bundle.main.bundleIdentifier != nil else { return }
        guard authorizationStatus == .authorized else { return }
        guard totalNew > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "RSS Okuyucu"
        content.body = "\(feedCount) kaynaktan \(totalNew) yeni makale"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "summary-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
