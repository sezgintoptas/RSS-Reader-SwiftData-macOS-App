import Foundation
import SwiftData
import OSLog

// MARK: - Periyodik Arka Plan Yenileme Yöneticisi
// Uygulama açık olduğu sürece, belirlenen aralıklarla besleme yenilemesini tetikler.

@MainActor
final class BackgroundRefreshManager: ObservableObject {
    static let shared = BackgroundRefreshManager()

    private var timer: Timer?
    private let logger = Logger(subsystem: "com.rssreader.app", category: "BackgroundRefresh")

    // Varsayılan: 15 dakikada bir yenile. Kullanıcı Settings'den değiştirebilir.
    @Published var intervalMinutes: Int {
        didSet {
            UserDefaults.standard.set(intervalMinutes, forKey: "refreshIntervalMinutes")
            reschedule()
        }
    }

    @Published var lastRefreshDate: Date? {
        didSet {
            if let date = lastRefreshDate {
                UserDefaults.standard.set(date, forKey: "lastRefreshDate")
            }
        }
    }

    @Published var isRefreshing = false

    private init() {
        let saved = UserDefaults.standard.integer(forKey: "refreshIntervalMinutes")
        intervalMinutes = saved > 0 ? saved : 15
        lastRefreshDate = UserDefaults.standard.object(forKey: "lastRefreshDate") as? Date
    }

    // MARK: - Zamanlayıcıyı Başlat

    func start(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        scheduleTimer()
        logger.info("Arka plan yenileme başlatıldı — aralık: \(self.intervalMinutes) dakika")
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        logger.info("Arka plan yenileme durduruldu.")
    }

    // MARK: - Manuel Tetikleme

    func refreshNow() {
        guard let container = modelContainer else { return }
        performRefresh(container: container)
    }

    // MARK: - Özel

    private var modelContainer: ModelContainer?

    private func scheduleTimer() {
        timer?.invalidate()
        let interval = TimeInterval(intervalMinutes * 60)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let container = self.modelContainer else { return }
                self.performRefresh(container: container)
            }
        }
    }

    private func reschedule() {
        guard modelContainer != nil else { return }
        scheduleTimer()
        logger.info("Zamanlayıcı yeniden ayarlandı — aralık: \(self.intervalMinutes) dakika")
    }

    private func performRefresh(container: ModelContainer) {
        guard !isRefreshing else {
            logger.debug("Senkronizasyon zaten devam ediyor, atlanıyor.")
            return
        }

        isRefreshing = true
        logger.info("⏱ Otomatik senkronizasyon başlıyor…")

        Task {
            let engine = SyncEngine(modelContainer: container)
            await engine.syncAllFeeds()

            await MainActor.run {
                self.lastRefreshDate = Date()
                self.isRefreshing = false
                self.logger.info("✅ Otomatik senkronizasyon tamamlandı.")
            }
        }
    }
}
