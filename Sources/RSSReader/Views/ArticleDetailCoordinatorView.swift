import SwiftUI

#if os(macOS)

/// Kullanıcının Ayarlar'da seçtiği okuma moduna göre
/// makaleyi uygun görünüme yönlendiren koordinatör.
struct ArticleDetailCoordinatorView: View {
    let article: Article

    @AppStorage("readingMode") private var readingModeRaw: String = ReadingMode.inApp.rawValue
    @State private var showAIPanel: Bool = false

    private var readingMode: ReadingMode {
        ReadingMode(rawValue: readingModeRaw) ?? .inApp
    }

    var body: some View {
        Group {
            switch readingMode {
            case .inApp:
                if let linkString = article.link, let url = URL(string: linkString) {
                    InAppWebView(article: article, url: url)
                } else {
                    noLinkView
                }
            case .readerMode:
                ReaderModeView(article: article)
            case .externalSafari:
                ExternalSafariView(article: article)
            }
        }
        .navigationTitle(article.title)
        .toolbar {
            // ── AI Özetle Butonu (popover açar, menü bozulmaz)
            ToolbarItem {
                Button {
                    showAIPanel.toggle()
                } label: {
                    Label(
                        article.isAIProcessed ? "AI Özeti" : "Özetle",
                        systemImage: "sparkles"
                    )
                }
                .help(article.isAIProcessed ? "AI özetini göster" : "Makaleyi özetle")
                .popover(isPresented: $showAIPanel, arrowEdge: .bottom) {
                    AIArticleSummaryPanel(article: article)
                }
            }
            ToolbarItem {
                ArticleMailToolbarButton(article: article)
            }
            ToolbarItem {
                Button {
                    article.isStarred.toggle()
                } label: {
                    Image(systemName: article.isStarred ? "star.fill" : "star")
                        .foregroundColor(article.isStarred ? .yellow : .primary)
                }
                .help(article.isStarred ? "Favorilerden Çıkar" : "Favorilere Ekle")
            }
        }
    }

    private var noLinkView: some View {
        VStack(spacing: 12) {
            Image(systemName: "link.badge.plus")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Bu makalenin bağlantısı bulunmuyor.")
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Toolbar Mail Butonu

private struct ArticleMailToolbarButton: View {
    let article: Article

    @State private var showPopover = false
    @State private var recipients: [EmailRecipient] = []
    @State private var selectedRecipient: EmailRecipient?
    @ObservedObject private var emailManager = ResendEmailManager.shared
    @State private var feedbackMessage: String?

    var body: some View {
        Button {
            showPopover = true
        } label: {
            Image(systemName: "envelope")
        }
        .help("Bu makaleyi e-posta ile gönder")
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            MailSendPopoverView(
                article: article,
                recipients: recipients,
                selectedRecipient: $selectedRecipient,
                emailManager: emailManager,
                feedbackMessage: $feedbackMessage,
                onDismiss: { showPopover = false }
            )
            .onAppear {
                // Her açılışta güncel listeyi oku
                recipients = ResendEmailManager.recipients()
                if selectedRecipient == nil || !recipients.contains(where: { $0.id == selectedRecipient?.id }) {
                    selectedRecipient = recipients.first
                }
                feedbackMessage = nil
                emailManager.sendState = .idle
            }
        }
    }
}

// MARK: - Mail Popover İçeriği

private struct MailSendPopoverView: View {
    let article: Article
    let recipients: [EmailRecipient]
    @Binding var selectedRecipient: EmailRecipient?
    @ObservedObject var emailManager: ResendEmailManager
    @Binding var feedbackMessage: String?
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Başlık Satırı
            HStack(spacing: 8) {
                Image(systemName: "envelope.fill")
                    .foregroundStyle(Color.accentColor)
                Text("Makaleyi Gönder")
                    .font(.headline)
                Spacer()
                Button { onDismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()

            // ── Konu
            VStack(alignment: .leading, spacing: 3) {
                Text("Konu:").font(.caption).foregroundStyle(.secondary)
                Text(article.title)
                    .font(.callout).fontWeight(.medium)
                    .lineLimit(2)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.textBackgroundColor).opacity(0.5))

            // ── Alıcı
            if recipients.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .font(.title2).foregroundStyle(.secondary)
                    Text("Henüz alıcı eklenmedi.")
                        .foregroundStyle(.secondary)
                    Text("Ayarlar → E-posta → Alıcı Ekle")
                        .font(.caption).foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Alıcı:").font(.caption).foregroundStyle(.secondary)
                    Picker("", selection: $selectedRecipient) {
                        ForEach(recipients) { r in
                            Text(r.displayName).tag(Optional(r))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            // ── Geri Bildirim
            if let msg = feedbackMessage {
                HStack(spacing: 6) {
                    Image(systemName: emailManager.sendState == .success
                          ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(emailManager.sendState == .success ? .green : .red)
                        .font(.caption)
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(emailManager.sendState == .success ? Color.green : Color.red)
                        .lineLimit(3)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }

            Divider()

            // ── Gönder Butonu
            HStack {
                Spacer()
                if emailManager.sendState == .sending {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.7)
                        Text("Gönderiliyor…").foregroundStyle(.secondary)
                    }
                } else {
                    Button { sendMail() } label: {
                        Label("Mail Gönder", systemImage: "paperplane.fill")
                            .font(.callout.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedRecipient == nil || recipients.isEmpty)
                    .keyboardShortcut(.return, modifiers: .command)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 300)
    }

    private func sendMail() {
        guard let recipient = selectedRecipient else { return }
        feedbackMessage = nil
        Task {
            let html = ResendEmailManager.buildHTMLBody(article: article)
            await emailManager.sendEmail(to: recipient, subject: article.title, htmlBody: html)
            switch emailManager.sendState {
            case .success:
                feedbackMessage = "Mail gönderildi ✓"
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                onDismiss()
            case .error(let msg):
                feedbackMessage = msg
            default:
                break
            }
        }
    }
}

#endif
