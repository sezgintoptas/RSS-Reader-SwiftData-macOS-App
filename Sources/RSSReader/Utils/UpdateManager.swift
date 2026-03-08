import Foundation
import AppKit

// MARK: - GitHub Release Model
struct GitHubRelease: Codable {
    let tagName: String
    let name: String
    let body: String?
    let htmlUrl: String
    let assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlUrl = "html_url"
        case assets
    }
}

struct GitHubAsset: Codable {
    let name: String
    let browserDownloadUrl: String
    let size: Int

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
        case size
    }
}

// MARK: - Güncelleme Durumu
enum UpdateState: Equatable {
    case idle
    case checking
    case upToDate
    case updateAvailable(version: String, releaseNotes: String?)
    case downloading(progress: Double)
    case readyToInstall(appPath: String)
    case error(String)
}

// MARK: - UpdateManager
@MainActor
final class UpdateManager: ObservableObject {
    static let shared = UpdateManager()

    @Published var state: UpdateState = .idle
    @Published var latestRelease: GitHubRelease? = nil

    private init() {}

    // MARK: - Versiyon Karşılaştırma
    func isNewer(_ version: String, than current: String) -> Bool {
        let v1 = version.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
        let v2 = current.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
        return v1.compare(v2, options: .numeric) == .orderedDescending
    }

    // MARK: - GitHub'dan Son Sürümü Kontrol Et
    func checkForUpdates() {
        state = .checking

        Task {
            do {
                var request = URLRequest(url: AppVersion.releasesAPIURL)
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                request.setValue("RSSReader/\(AppVersion.current)", forHTTPHeaderField: "User-Agent")
                request.timeoutInterval = 10

                let (data, response) = try await URLSession.shared.data(for: request)

                guard let http = response as? HTTPURLResponse else {
                    state = .upToDate // Yanıt alınamadı, sessizce geç
                    return
                }

                // 404 = henüz release yayınlanmamış → güncel say
                if http.statusCode == 404 {
                    state = .upToDate
                    return
                }

                guard http.statusCode == 200 else {
                    state = .error("Sunucu hatası (HTTP \(http.statusCode))")
                    return
                }

                let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                latestRelease = release

                if isNewer(release.tagName, than: AppVersion.current) {
                    state = .updateAvailable(version: release.tagName, releaseNotes: release.body)
                } else {
                    state = .upToDate
                }
            } catch let urlError as URLError {
                // Ağ erişimi yoksa sessizce geç
                if urlError.code == .notConnectedToInternet || urlError.code == .networkConnectionLost {
                    state = .upToDate
                } else {
                    state = .error("Ağ hatası: \(urlError.localizedDescription)")
                }
            } catch {
                state = .error("Kontrol hatası: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Güncellemeyi İndir ve Uygula
    // Strateji: GitHub release'teki .zip asset'ini indir,
    // içindeki binary'yi mevcut .app bundle'ına kopyala, uygulamayı yeniden başlat.
    func downloadAndInstall() {
        guard let release = latestRelease,
              let asset = release.assets.first(where: { $0.name.hasSuffix(".zip") || $0.name == "RSSReader.app.zip" }),
              let downloadURL = URL(string: asset.browserDownloadUrl) else {
            // Asset yoksa kaynak zip'i dene
            downloadSourceAndRebuild()
            return
        }

        downloadAppZip(from: downloadURL, version: release.tagName)
    }

    // MARK: - Kaynak kod zip indir (binary release yoksa)
    // GitHub, her release için otomatik kaynak zip oluşturur.
    private func downloadSourceAndRebuild() {
        guard let release = latestRelease else { return }

        let tag = release.tagName
        let zipURLString = "https://github.com/\(AppVersion.githubOwner)/\(AppVersion.githubRepo)/archive/refs/tags/\(tag).zip"

        guard let zipURL = URL(string: zipURLString) else {
            state = .error("Geçersiz indirme URL'si")
            return
        }

        state = .downloading(progress: 0)

        Task {
            do {
                // 1. Zip'i indir
                let (localURL, _) = try await URLSession.shared.download(from: zipURL)
                state = .downloading(progress: 1.0)

                // 2. Geçici klasöre çıkar
                let tmpDir = FileManager.default.temporaryDirectory
                    .appendingPathComponent("RSSUpdate-\(UUID().uuidString)")
                try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

                let unzipProcess = Process()
                unzipProcess.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
                unzipProcess.arguments = ["-q", localURL.path, "-d", tmpDir.path]
                try unzipProcess.run()
                unzipProcess.waitUntilExit()

                // 3. Swift build yap
                let sourceDir = tmpDir.appendingPathComponent(
                    "\(AppVersion.githubRepo)-\(tag.trimmingCharacters(in: CharacterSet(charactersIn: "v")))"
                )

                state = .readyToInstall(appPath: sourceDir.path)

                // 4. Build scriptini çalıştır
                buildAndReplace(sourceDir: sourceDir, version: tag)
            } catch {
                state = .error("İndirme hatası: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Derle ve Değiştir
    private func buildAndReplace(sourceDir: URL, version: String) {
        Task {
            do {
                // swift build
                let buildProcess = Process()
                buildProcess.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                buildProcess.arguments = ["swift", "build", "-c", "release",
                                          "--package-path", sourceDir.path]
                let buildPipe = Pipe()
                buildProcess.standardOutput = buildPipe
                buildProcess.standardError = buildPipe
                try buildProcess.run()
                buildProcess.waitUntilExit()

                if buildProcess.terminationStatus != 0 {
                    let output = String(data: buildPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    state = .error("Derleme hatası:\n\(output.suffix(300))")
                    return
                }

                // Yeni binary yolu
                let newBinary = sourceDir
                    .appendingPathComponent(".build/release/RSSReader")

                // Mevcut .app bundle binary yolu
                guard let currentExec = Bundle.main.executableURL else {
                    state = .error("Mevcut binary bulunamadı")
                    return
                }

                // Eski binary'yi yedekle ve yenisiyle değiştir
                let backupURL = currentExec.appendingPathExtension("bak")
                try? FileManager.default.removeItem(at: backupURL)
                try FileManager.default.moveItem(at: currentExec, to: backupURL)
                try FileManager.default.copyItem(at: newBinary, to: currentExec)
                try FileManager.default.removeItem(at: backupURL)

                // Uygulamayı yeniden başlat
                DispatchQueue.main.async {
                    self.relaunchApp()
                }
            } catch {
                state = .error("Kurulum hatası: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Binary zip indir
    private func downloadAppZip(from url: URL, version: String) {
        state = .downloading(progress: 0)

        let task = URLSession.shared.downloadTask(with: url) { [weak self] localURL, _, error in
            Task { @MainActor in
                if let error = error {
                    self?.state = .error("İndirme hatası: \(error.localizedDescription)")
                    return
                }
                guard let localURL = localURL else {
                    self?.state = .error("Dosya bulunamadı")
                    return
                }

                // Zip'i aç ve binary'yi değiştir
                let tmpDir = FileManager.default.temporaryDirectory
                    .appendingPathComponent("RSSUpdate-\(UUID().uuidString)")
                try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

                let unzip = Process()
                unzip.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
                unzip.arguments = ["-q", "-o", localURL.path, "-d", tmpDir.path]
                try? unzip.run()
                unzip.waitUntilExit()

                if let appURL = try? FileManager.default.contentsOfDirectory(
                    at: tmpDir, includingPropertiesForKeys: nil
                ).first(where: { $0.lastPathComponent == "RSSReader.app" }) {
                    self?.replaceCurrentApp(with: appURL)
                } else {
                    self?.state = .error("Güncel .app paketi bulunamadı")
                }
            }
        }
        task.resume()
    }

    // MARK: - Mevcut .app'i Değiştir
    private func replaceCurrentApp(with newApp: URL) {
        guard let bundlePath = Bundle.main.bundlePath as String? else { return }
        let currentApp = URL(fileURLWithPath: bundlePath)

        do {
            let backup = currentApp.appendingPathExtension("old_version_backup")
            
            // Mevcut .app'in içine yazmaya çalışmak yerine ismini değiştirip yeni olanı kopyalamak daha güvenlidir
            try? FileManager.default.removeItem(at: backup)
            try FileManager.default.moveItem(at: currentApp, to: backup)
            
            do {
                try FileManager.default.copyItem(at: newApp, to: currentApp)
            } catch {
                // Eğer kopyalama başarısız olursa backup'ı geri al
                try? FileManager.default.moveItem(at: backup, to: currentApp)
                throw error
            }
            
            try? FileManager.default.removeItem(at: backup)
            
            state = .readyToInstall(appPath: bundlePath)
            
            // UI'ın güncellenmesi için küçük bir gecikme
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.relaunchApp()
            }
        } catch {
            print("❌ Güncelleme hatası: \(error)")
            state = .error("Uygulama dosyaları değiştirilemedi: \(error.localizedDescription)")
        }
    }

    // MARK: - Uygulamayı Yeniden Başlat
    func relaunchApp() {
        let bundlePath = Bundle.main.bundlePath
        
        // 1 saniye bekle, uygulamayı aç ve mevcut uygulamayı kapat
        // Gecikme, OS'in eski instance'ın kapandığını anlaması için kritiktir.
        let script = "sleep 1.0; open \"\(bundlePath)\""
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["sh", "-c", script]
        
        do {
            try task.run()
            NSApp.terminate(nil)
        } catch {
            print("❌ Yeniden başlatma başarısız: \(error)")
            state = .error("Yeniden başlatılamadı: \(error.localizedDescription)")
        }
    }

    // MARK: - Tarayıcıda Release Sayfasını Aç
    func openReleasePage() {
        guard let release = latestRelease,
              let url = URL(string: release.htmlUrl) else { return }
        NSWorkspace.shared.open(url)
    }
}
