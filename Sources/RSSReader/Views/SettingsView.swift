import SwiftUI
import SwiftData
import WebKit
import UniformTypeIdentifiers

#if os(macOS)
struct SettingsView: View {
    /// Bugün: "14:30", daha eski: "8 Mar 14:30" — saniye göstermez.
    static let shortTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        f.doesRelativeDateFormatting = false
        return f
    }()

    var body: some View {
        TabView {
            GeneralTab()
                .tabItem {
                    Label("Genel", systemImage: "gearshape")
                }

            NotificationTab()
                .tabItem {
                    Label("Bildirimler", systemImage: "bell.badge")
                }

            AdBlockerTab()
                .tabItem {
                    Label("Reklam Engelleme", systemImage: "shield.checkered")
                }

            YouTubeTab()
                .tabItem {
                    Label("YouTube", systemImage: "play.rectangle")
                }

            BackupTab()
                .tabItem {
                    Label("Yedekleme", systemImage: "externaldrive")
                }

            EmailTab()
                .tabItem {
                    Label("E-posta", systemImage: "envelope")
                }

            AISettingsTab()
                .tabItem {
                    Label("Yapay Zeka", systemImage: "sparkles")
                }

            UpdateTab()
                .tabItem {
                    Label("Güncelleme", systemImage: "arrow.triangle.2.circlepath")
                }
        }
        .frame(width: 520, height: 500)
    }
}

// MARK: - Genel Ayarlar Sekmesi

private struct GeneralTab: View {
    @AppStorage("readingMode") private var readingMode: String = ReadingMode.inApp.rawValue
    @AppStorage("articleArchiveLimit") private var articleArchiveLimit: Int = 1000
    @StateObject private var refreshManager = BackgroundRefreshManager.shared
    @StateObject private var cloudSettings = CloudSettingsManager.shared

    private var selectedMode: ReadingMode {
        ReadingMode(rawValue: readingMode) ?? .inApp
    }

    var body: some View {
        Form {
            // Okuma Modu
            Section("Okuma Modu") {
                Picker("Varsayılan Mod", selection: $readingMode) {
                    ForEach(ReadingMode.allCases) { mode in
                        Text(mode.displayName).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.radioGroup)

                Text(selectedMode.description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            // Otomatik Yenileme
            Section("Otomatik Yenileme") {
                Picker("Yenileme Aralığı", selection: $refreshManager.intervalMinutes) {
                    Text("5 dakika").tag(5)
                    Text("10 dakika").tag(10)
                    Text("15 dakika").tag(15)
                    Text("30 dakika").tag(30)
                    Text("60 dakika").tag(60)
                }
                .pickerStyle(.menu)

                HStack {
                    Text("Son Yenileme:")
                    Spacer()
                    if let last = refreshManager.lastRefreshDate {
                        Text(last, formatter: SettingsView.shortTimeFormatter)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Henüz yenilenmedi")
                            .foregroundStyle(.secondary)
                    }
                    if refreshManager.isRefreshing {
                        ProgressView().scaleEffect(0.6)
                    }
                }

                Button("Şimdi Yenile") {
                    refreshManager.refreshNow()
                }
                .disabled(refreshManager.isRefreshing)
            }

            // Veri Yönetimi
            Section("Veri Yönetimi") {
                Picker("Makale Arşiv Limiti", selection: $articleArchiveLimit) {
                    Text("500 makale").tag(500)
                    Text("1.000 makale").tag(1000)
                    Text("2.000 makale").tag(2000)
                    Text("5.000 makale").tag(5000)
                }
                .pickerStyle(.menu)

                Text("Favori (yıldızlı) makaleler asla silinmez.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            // iCloud
            Section("iCloud Ayar Eşitleme") {
                HStack {
                    Text("Durum")
                    Spacer()
                    switch cloudSettings.syncStatus {
                    case .idle:
                        Label("Bekliyor", systemImage: "minus.circle")
                            .foregroundColor(.secondary)
                    case .syncing:
                        HStack(spacing: 4) {
                            ProgressView().scaleEffect(0.6)
                            Text("Eşitleniyor…").foregroundStyle(.secondary)
                        }
                    case .synced:
                        Label("Eşitlendi", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    case .failed(let msg):
                        Label("Hata", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .help(msg)
                    }
                }

                if let lastSync = cloudSettings.lastSyncDate {
                    HStack {
                        Text("Son Eşitleme:")
                        Spacer()
                        Text(lastSync, formatter: SettingsView.shortTimeFormatter).foregroundStyle(.secondary)
                    }
                }

                Button("Ayarları Şimdi Eşitle") {
                    cloudSettings.syncNow()
                }
                .disabled(cloudSettings.syncStatus == .syncing)

                Text("Yenileme aralığı ve filtre seçimleri iCloud üzerinden eşitlenir.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Bildirimler Sekmesi

private struct NotificationTab: View {
    @StateObject private var notificationManager = NotificationManager.shared
    @Query(sort: \Feed.title) private var allFeeds: [Feed]

    var body: some View {
        Form {
            Section("Bildirim İzni") {
                HStack {
                    Text("Durum")
                    Spacer()
                    switch notificationManager.authorizationStatus {
                    case .authorized:
                        Label("Verilmiş", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    case .denied:
                        Label("Reddedilmiş", systemImage: "xmark.circle.fill")
                            .foregroundColor(.red)
                    case .notDetermined:
                        Button("İzin Ver") { notificationManager.requestPermission() }
                            .buttonStyle(.bordered)
                    default:
                        Text("Bilinmiyor").foregroundStyle(.secondary)
                    }
                }

                if notificationManager.authorizationStatus == .denied {
                    Text("Sistem Tercihleri → Bildirimler → RSS Okuyucu'dan etkinleştirin.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if notificationManager.authorizationStatus == .authorized {
                Section("Besleme Bildirimleri") {
                    // Tümünü aç/kapat
                    HStack {
                        Text("Tüm Bildirimler")
                            .fontWeight(.medium)
                        Spacer()
                        let allOn = allFeeds.allSatisfy { $0.notificationsEnabled }
                        Button(allOn ? "Tümünü Kapat" : "Tümünü Aç") {
                            for feed in allFeeds { feed.notificationsEnabled = !allOn }
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(Color.accentColor)
                    }

                    ForEach(allFeeds) { feed in
                        Toggle(isOn: Binding(
                            get: { feed.notificationsEnabled },
                            set: { feed.notificationsEnabled = $0 }
                        )) {
                            HStack(spacing: 6) {
                                if let host = URL(string: feed.url)?.host {
                                    AsyncImage(url: URL(string: "https://s2.googleusercontent.com/s2/favicons?domain=\(host)&sz=64")) { img in
                                        img.resizable().frame(width: 14, height: 14).cornerRadius(3)
                                    } placeholder: {
                                        Image(systemName: "dot.radiowaves.up.forward")
                                            .font(.caption2)
                                    }
                                }
                                Text(feed.title)
                                    .lineLimit(1)
                                if feed.consecutiveFailures > 0 {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.caption2)
                                        .foregroundColor(feed.consecutiveFailures >= 3 ? .red : .orange)
                                }
                            }
                        }
                        .toggleStyle(.switch)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Reklam Engelleyici Sekmesi

private struct AdBlockerTab: View {
    @AppStorage("totalAdsBlocked") private var totalAdsBlocked: Int = 0
    @StateObject private var blockerManager = ContentBlockerManager.shared

    private func binding(for filterID: String) -> Binding<Bool> {
        Binding(
            get: { blockerManager.activeFilterIDs.contains(filterID) },
            set: { isEnabled in
                if isEnabled {
                    blockerManager.activeFilterIDs.insert(filterID)
                } else {
                    blockerManager.activeFilterIDs.remove(filterID)
                }
            }
        )
    }

    var body: some View {
        Form {
            Section("Filtre Kuralları") {
                ForEach(FilterCategory.allCases) { category in
                    let categoryFilters = availableFilters.filter { $0.category == category }
                    if !categoryFilters.isEmpty {
                        DisclosureGroup(category.rawValue) {
                            ForEach(categoryFilters) { filter in
                                Toggle(filter.displayName, isOn: binding(for: filter.id))
                                    .toggleStyle(.switch)
                                    .padding(.vertical, 2)
                            }
                        }
                    }
                }
            }

            Section("Durum") {
                HStack {
                    Text("Engelleme:")
                    Spacer()
                    if blockerManager.isActive {
                        Label("Aktif (\(blockerManager.ruleLists.count) Kural Seti)", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else if blockerManager.isError {
                        Label("Hata", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                    } else {
                        Label("İşleniyor...", systemImage: "arrow.2.circlepath")
                            .foregroundColor(.orange)
                    }
                }

                HStack {
                    Text("Son Güncelleme:")
                    Spacer()
                    if let date = blockerManager.lastUpdatedDate {
                        Text(date, style: .date).foregroundStyle(.secondary)
                        Text(date, style: .time).foregroundStyle(.secondary)
                    } else {
                        Text("Bilinmiyor").foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Text("Gizlenen Reklam:")
                    Spacer()
                    Text("\(totalAdsBlocked)")
                        .bold()
                        .foregroundColor(.accentColor)
                }

                Button("Listeleri Şimdi Güncelle") {
                    Task {
                        await blockerManager.loadRules(forceUpdate: true)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            Task {
                if !blockerManager.isActive && !blockerManager.activeFilterIDs.isEmpty {
                    await blockerManager.loadRules(forceUpdate: false)
                }
            }
        }
    }
}

// MARK: - YouTube Sekmesi

private struct YouTubeTab: View {
    @AppStorage("persistYouTubeSession") private var persistYouTubeSession: Bool = true

    var body: some View {
        Form {
            Section("Oturum") {
                Toggle("YouTube Oturumunu Koru", isOn: $persistYouTubeSession)
                    .toggleStyle(.switch)

                Text("Etkinleştirildiğinde, YouTube giriş bilgileriniz saklanır. Premium hesabınız varsa reklamsız izleme deneyimi sağlanır.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Reklam Engelleme") {
                Text("YouTube, reklamları video akışına sunucu tarafında gömülü olarak gönderir. Tam reklam engellemesi için YouTube Premium veya Google hesabı ile giriş yapmanız önerilir.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Veri Temizleme") {
                Button("YouTube Cookie'lerini Temizle") {
                    clearYouTubeCookies()
                }
                .foregroundColor(.red)

                Text("Giriş bilgileriniz silinir ve YouTube'a tekrar giriş yapmanız gerekir.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func clearYouTubeCookies() {
        let dataStore = WKWebsiteDataStore.default()
        let allTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        dataStore.fetchDataRecords(ofTypes: allTypes) { records in
            let youtubeRecords = records.filter { record in
                let domain = record.displayName.lowercased()
                return domain.contains("youtube") ||
                       domain.contains("google") ||
                       domain.contains("googlevideo") ||
                       domain.contains("ytimg") ||
                       domain.contains("gstatic")
            }
            dataStore.removeData(ofTypes: allTypes, for: youtubeRecords) {
                print("YouTube cookie'leri temizlendi. (\(youtubeRecords.count) kayıt)")
            }
        }
    }
}

// MARK: - Yedekleme Sekmesi

private struct BackupTab: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var backupManager = BackupManager.shared
    @State private var showRestoreFilePicker = false

    var body: some View {
        Form {
            Section("Yedekleme") {
                // Durum
                switch backupManager.status {
                case .idle:
                    EmptyView()
                case .inProgress:
                    HStack {
                        ProgressView().scaleEffect(0.6)
                        Text("İşlem devam ediyor…").foregroundStyle(.secondary)
                    }
                case .success(let message):
                    Label(message, systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.callout)
                case .failed(let message):
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.callout)
                }

                if let lastBackup = backupManager.lastBackupDate {
                    HStack {
                        Text("Son Yedekleme:")
                        Spacer()
                        Text(lastBackup, formatter: SettingsView.shortTimeFormatter).foregroundStyle(.secondary)
                    }
                }

                Button {
                    backupManager.exportBackup(modelContext: modelContext)
                } label: {
                    Label("Şimdi Yedekle", systemImage: "arrow.down.doc.fill")
                }
                .disabled(backupManager.status == .inProgress)
            }

            Section("Geri Yükleme") {
                Button {
                    showRestoreFilePicker = true
                } label: {
                    Label("Dosyadan Geri Yükle…", systemImage: "arrow.up.doc.fill")
                }
                .disabled(backupManager.status == .inProgress)

                // Mevcut yedekler
                let backups = backupManager.listBackups()
                if !backups.isEmpty {
                    ForEach(backups) { backup in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(backup.fileName)
                                    .font(.caption)
                                    .lineLimit(1)
                                Text("\(backup.date, style: .date) — \(backup.sizeFormatted)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Geri Yükle") {
                                backupManager.importBackup(from: backup.url, modelContext: modelContext)
                            }
                            .buttonStyle(.borderless)
                            .foregroundColor(.accentColor)
                            .font(.caption)

                            Button {
                                NSWorkspace.shared.activateFileViewerSelecting([backup.url])
                            } label: {
                                Image(systemName: "folder")
                            }
                            .buttonStyle(.borderless)
                            .foregroundColor(.secondary)
                            .help("Finder'da göster")
                        }
                    }
                }
            }

            Section {
                Text("Yedekler ~/Documents/RSSReader Backups/ klasörüne kaydedilir. Beslemeler, klasörler, favori makaleler ve okuma durumları yedeklenir.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .fileImporter(
            isPresented: $showRestoreFilePicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                if url.startAccessingSecurityScopedResource() {
                    backupManager.importBackup(from: url, modelContext: modelContext)
                    url.stopAccessingSecurityScopedResource()
                }
            }
        }
    }
}

// MARK: - E-posta Sekmesi

private struct EmailTab: View {
    @AppStorage("resendApiKey") private var apiKey: String = ""
    @AppStorage("resendDomain") private var domain: String = ""

    @State private var recipients: [EmailRecipient] = []
    @State private var newName: String = ""
    @State private var newEmail: String = ""
    @State private var showAddRow: Bool = false

    var body: some View {
        Form {
            // API Ayarları
            Section("Resend.com API Ayarları") {
                SecureField("API Anahtarı (re_...)", text: $apiKey)
                    .textFieldStyle(.roundedBorder)

                TextField("Domain (örn: gengreener.com)", text: $domain)
                    .textFieldStyle(.roundedBorder)

                Text("Gönderici: noreply@\(domain.isEmpty ? "example.com" : domain)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Alıcı Listesi
            Section("E-posta Alıcıları") {
                if recipients.isEmpty && !showAddRow {
                    Text("Henüz alıcı eklenmedi.")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                } else {
                    ForEach(recipients) { recipient in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(recipient.name.isEmpty ? recipient.email : recipient.name)
                                    .font(.callout)
                                if !recipient.name.isEmpty {
                                    Text(recipient.email)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button {
                                recipients.removeAll { $0.id == recipient.id }
                                saveRecipients()
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    }
                }

                if showAddRow {
                    VStack(spacing: 6) {
                        TextField("Ad Soyad (opsiyonel)", text: $newName)
                            .textFieldStyle(.roundedBorder)
                        TextField("E-posta adresi", text: $newEmail)
                            .textFieldStyle(.roundedBorder)
                        HStack {
                            Button("İptal") {
                                showAddRow = false
                                newName = ""
                                newEmail = ""
                            }
                            .buttonStyle(.bordered)
                            Spacer()
                            Button("Ekle") {
                                let trimmed = newEmail.trimmingCharacters(in: .whitespaces)
                                guard !trimmed.isEmpty else { return }
                                let r = EmailRecipient(name: newName.trimmingCharacters(in: .whitespaces),
                                                       email: trimmed)
                                recipients.append(r)
                                saveRecipients()
                                showAddRow = false
                                newName = ""
                                newEmail = ""
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(newEmail.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if !showAddRow {
                    Button {
                        showAddRow = true
                    } label: {
                        Label("Alıcı Ekle", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Color.accentColor)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            recipients = ResendEmailManager.recipients()
        }
    }

    private func saveRecipients() {
        ResendEmailManager.saveRecipients(recipients)
    }
}

// MARK: - Yapay Zeka Ayarları Sekmesi

private struct AISettingsTab: View {
    @AppStorage("geminiApiKey") private var apiKey: String = ""
    @State private var testStatus: TestStatus = .idle

    enum TestStatus {
        case idle, testing, success, failed(String)
    }

    var body: some View {
        Form {
            Section("Google Gemini API") {
                SecureField("API Anahtarı (AIza...)", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: apiKey) { _, _ in testStatus = .idle }

                HStack {
                    Link("AI Studio'dan ücretsiz al →",
                         destination: URL(string: "https://aistudio.google.com/apikey")!)
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                    Spacer()
                    // Test butonu
                    if case .testing = testStatus {
                        HStack(spacing: 4) {
                            ProgressView().scaleEffect(0.6)
                            Text("Test ediliyor…").font(.caption).foregroundStyle(.secondary)
                        }
                    } else {
                        Button("Bağlantıyı Test Et") {
                            Task { await testConnection() }
                        }
                        .buttonStyle(.bordered)
                        .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                switch testStatus {
                case .idle:
                    EmptyView()
                case .testing:
                    EmptyView()
                case .success:
                    Label("Bağlantı başarılı ✓", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green).font(.callout)
                case .failed(let msg):
                    Label(msg, systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.red).font(.callout)
                }
            }

            Section("Model") {
                HStack {
                    Text("Model")
                    Spacer()
                    Text("Gemini Flash")
                        .foregroundStyle(.secondary)
                        .monospaced()
                }
                Text("Ücretsiz katmanda dakikada 15 istek, günde 1.500 istek hakkı bulunur. Yoğun kullanımda Gemini 1.5 Pro kullanmayı değerlendirin.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Gizlilik") {
                Text("Makalelerinizin yalnızca ilk ~4.000 karakteri Google'ın API'sine gönderilir. Kişisel veriniz işlenmez. Detaylar: ai.google.dev/terms")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func testConnection() async {
        guard !apiKey.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        testStatus = .testing

        let urlStr = "https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent"
        guard let url = URL(string: urlStr) else {
            testStatus = .failed("Geçersiz URL")
            return
        }

        let body: [String: Any] = [
            "contents": [["parts": [["text": "Merhaba, test."]]]],
            "generationConfig": ["maxOutputTokens": 10]
        ]

        do {
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue(apiKey, forHTTPHeaderField: "X-goog-api-key")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            req.timeoutInterval = 15

            let (_, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse {
                if http.statusCode == 200 {
                    testStatus = .success
                } else if http.statusCode == 400 {
                    testStatus = .failed("Geçersiz API anahtarı (400)")
                } else if http.statusCode == 403 {
                    testStatus = .failed("Erişim reddedildi (403)")
                } else {
                    testStatus = .failed("HTTP \(http.statusCode)")
                }
            }
        } catch {
            testStatus = .failed(error.localizedDescription)
        }
    }
}

// MARK: - Güncelleme Sekmesi

private struct UpdateTab: View {
    @StateObject private var updater = UpdateManager.shared

    var body: some View {
        Form {
            Section("Uygulama Güncellemesi") {
                HStack {
                    Text("Mevcut Sürüm")
                    Spacer()
                    Text(AppVersion.current)
                        .foregroundStyle(.secondary)
                        .monospaced()
                }

                switch updater.state {
                case .idle:
                    Button("Güncelleme Kontrol Et") {
                        updater.checkForUpdates()
                    }

                case .checking:
                    HStack {
                        ProgressView().scaleEffect(0.7)
                        Text("Kontrol ediliyor…").foregroundStyle(.secondary)
                    }

                case .upToDate:
                    Label("Uygulama güncel", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Button("Tekrar Kontrol Et") { updater.checkForUpdates() }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)

                case .updateAvailable(let version, let notes):
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Yeni sürüm: \(version)", systemImage: "arrow.down.circle.fill")
                            .foregroundColor(.accentColor)
                            .font(.headline)
                        if let notes = notes, !notes.isEmpty {
                            ScrollView {
                                if let attrString = try? AttributedString(markdown: notes, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                                    Text(attrString)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                } else {
                                    Text(notes)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .frame(maxHeight: 120)
                            .padding(8)
                            .background(Color(.textBackgroundColor).opacity(0.5))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                        }
                        HStack {
                            Button("İndir ve Güncelle") {
                                updater.downloadAndInstall()
                            }
                            .buttonStyle(.borderedProminent)

                            Button("Release Sayfası") {
                                updater.openReleasePage()
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                case .downloading(let progress):
                    VStack(alignment: .leading, spacing: 4) {
                        Text("İndiriliyor…")
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                    }

                case .readyToInstall:
                    Label("Kurulum tamamlandı — yeniden başlatılıyor…",
                          systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)

                case .error(let message):
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Hata oluştu", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Tekrar Dene") { updater.checkForUpdates() }
                            .buttonStyle(.borderless)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
#endif
