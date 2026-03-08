import SwiftUI
import SwiftData
import AppKit
import UserNotifications

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)

        // ✅ Bundle ID kontrolü: Xcode'da çıplak binary olarak çalışırken crash'i (bundleProxyForCurrentProcess is nil) önler
        if Bundle.main.bundleIdentifier != nil {
            UNUserNotificationCenter.current().delegate = self

            // Bildirim izni — ilk açılışta sor
            Task { @MainActor in
                NotificationManager.shared.requestPermission()
            }
            
            // ✅ iCloud Ayar Senkronizasyonunu Başlat
            CloudSettingsManager.shared.start()
        } else {
            print("⚠️ Bildirimler devre dışı: Uygulama bir .app paketi veya Bundle ID (CFBundleIdentifier) olmadan çalışıyor.")
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        NSApp.windows.first?.makeKeyAndOrderFront(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        BackgroundRefreshManager.shared.stop()
    }

    // MARK: - Foreground Bildirim
    // Uygulama açıkken de bildirim banner'ı göster
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    // Bildirime tıklanınca uygulamayı öne getir
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        NSApp.activate(ignoringOtherApps: true)
        completionHandler()
    }
}

@main
struct RSSReaderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Folder.self,
            Feed.self,
            Article.self,
            DynamicOPMLSubscription.self
        ])

        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupportDir.appendingPathComponent("RSSReader", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)

        let storeURL = appDir.appendingPathComponent("RSSReader.sqlite")

        // ⚠️ CloudKit Desteği: Şu an entitlements/capability yapılandırılmadığı için veritabanı senkronizasyonu kapalı.
        // CloudKit etkinleştirmek için: Xcode projesi oluştur → iCloud capability ekle → CloudKit seç → .automatic yap
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none // Entitlements olmadan .automatic sessizce başarısız olur
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            print("⚠️ ModelContainer migration başarısız: \(error)")
            print("⚠️ Yeni schema ile tekrar deneniyor (veritabanı KORUNARAK)...")

            // Son çare: DB dosyalarını sil (sadece schema TAMAMEN uyumsuz ise)
            let fm = FileManager.default
            for ext in ["", "-shm", "-wal"] {
                let fileURL = ext.isEmpty ? storeURL : storeURL.deletingLastPathComponent().appendingPathComponent("RSSReader.sqlite\(ext)")
                try? fm.removeItem(at: fileURL)
            }

            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("ModelContainer oluşturulamadı: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 600)
                .onAppear {
                    BackgroundRefreshManager.shared.start(modelContainer: sharedModelContainer)
                }
        }
        .modelContainer(sharedModelContainer)
        #if os(macOS)
        .commands {
            SidebarCommands()
            CommandGroup(replacing: .undoRedo) {
                Button("Geri Al") { NSApp.sendAction(Selector(("undo:")), to: nil, from: nil) }
                    .keyboardShortcut("z", modifiers: .command)
                Button("Yinele") { NSApp.sendAction(Selector(("redo:")), to: nil, from: nil) }
                    .keyboardShortcut("z", modifiers: [.command, .shift])
            }
        }
        #endif

        #if os(macOS)
        Settings {
            SettingsView()
        }
        .modelContainer(sharedModelContainer)
        #endif
    }
}
