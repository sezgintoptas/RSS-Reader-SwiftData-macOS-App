import Foundation
import AppKit

// MARK: - E-posta Alıcı Modeli

struct EmailRecipient: Codable, Identifiable, Equatable, Hashable {
    var id: UUID = UUID()
    var name: String
    var email: String

    var displayName: String {
        name.isEmpty ? email : "\(name) <\(email)>"
    }
}

// MARK: - Gönderim Durumu

enum EmailSendState: Equatable {
    case idle
    case sending
    case success
    case error(String)
}

// MARK: - Resend Email Manager

@MainActor
final class ResendEmailManager: ObservableObject {
    static let shared = ResendEmailManager()
    private init() {}

    @Published var sendState: EmailSendState = .idle

    // MARK: - Ayarlardan Oku

    static func apiKey() -> String {
        UserDefaults.standard.string(forKey: "resendApiKey") ?? ""
    }

    static func fromDomain() -> String {
        UserDefaults.standard.string(forKey: "resendDomain") ?? ""
    }

    static func recipients() -> [EmailRecipient] {
        guard let data = UserDefaults.standard.data(forKey: "resendRecipients"),
              let list = try? JSONDecoder().decode([EmailRecipient].self, from: data)
        else { return [] }
        return list
    }

    static func saveRecipients(_ recipients: [EmailRecipient]) {
        if let data = try? JSONEncoder().encode(recipients) {
            UserDefaults.standard.set(data, forKey: "resendRecipients")
        }
    }

    // MARK: - Gönder

    func sendEmail(to recipient: EmailRecipient, subject: String, htmlBody: String) async {
        sendState = .sending

        let apiKey = ResendEmailManager.apiKey()
        let domain = ResendEmailManager.fromDomain()

        guard !apiKey.isEmpty, !domain.isEmpty else {
            sendState = .error("API anahtarı veya domain ayarlanmamış.")
            return
        }

        let fromAddress = "RSS Okuyucu <noreply@\(domain)>"

        // JSON payload
        let payload: [String: Any] = [
            "from": fromAddress,
            "to": [recipient.email],
            "subject": subject,
            "html": htmlBody
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: payload) else {
            sendState = .error("İstek oluşturulamadı.")
            return
        }

        var request = URLRequest(url: URL(string: "https://api.resend.com/emails")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                if (200...299).contains(httpResponse.statusCode) {
                    sendState = .success
                } else {
                    let msg = String(data: data, encoding: .utf8) ?? "Bilinmeyen hata"
                    sendState = .error("HTTP \(httpResponse.statusCode): \(msg)")
                }
            }
        } catch {
            sendState = .error(error.localizedDescription)
        }
    }

    // MARK: - HTML Şablonu Oluştur

    static func buildHTMLBody(article: Article) -> String {
        let title = article.title.htmlEscaped
        let feedName = (article.feed?.title ?? "RSS Feed").htmlEscaped
        let url = article.link ?? ""
        let urlEscaped = url.htmlEscaped

        // İçerikten düz metin özeti oluştur (HTML entity'leri doğru çözer)
        let rawContent = article.content ?? ""
        let plainContent = rawContent.htmlToPlainText()
        let preview = String(plainContent.prefix(600))
        let previewEscaped = preview.isEmpty ? "" : preview.htmlEscaped + (plainContent.count > 600 ? "\u{2026}" : "")

        return """
        <!DOCTYPE html>
        <html lang="tr">
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          body {
            margin: 0;
            padding: 0;
            background-color: #f5f5f7;
            font-family: -apple-system, BlinkMacSystemFont, 'Helvetica Neue', Helvetica, Arial, sans-serif;
            -webkit-font-smoothing: antialiased;
          }
          .wrapper {
            max-width: 600px;
            margin: 40px auto;
            background: #ffffff;
            border-radius: 16px;
            overflow: hidden;
            box-shadow: 0 4px 24px rgba(0,0,0,0.08);
          }
          .header {
            background: linear-gradient(135deg, #1c1c1e 0%, #2c2c2e 100%);
            padding: 28px 32px 22px;
          }
          .header .source-label {
            font-size: 11px;
            font-weight: 600;
            letter-spacing: 0.08em;
            text-transform: uppercase;
            color: rgba(255,255,255,0.45);
            margin-bottom: 8px;
          }
          .header .feed-name {
            font-size: 13px;
            font-weight: 500;
            color: #64d2ff;
          }
          .body {
            padding: 28px 32px 24px;
          }
          .article-title {
            font-size: 22px;
            font-weight: 700;
            line-height: 1.35;
            color: #1c1c1e;
            margin: 0 0 16px;
            letter-spacing: -0.3px;
          }
          .divider {
            height: 1px;
            background: #e5e5ea;
            margin: 20px 0;
          }
          .preview-text {
            font-size: 15px;
            line-height: 1.65;
            color: #3a3a3c;
            margin: 0 0 28px;
          }
          .cta-btn {
            display: inline-block;
            padding: 12px 24px;
            background: #007aff;
            color: #ffffff !important;
            font-size: 15px;
            font-weight: 600;
            text-decoration: none;
            border-radius: 10px;
          }
          .footer {
            background: #f5f5f7;
            padding: 16px 32px;
            text-align: center;
          }
          .footer p {
            font-size: 12px;
            color: #8e8e93;
            margin: 0;
          }
        </style>
        </head>
        <body>
          <div class="wrapper">
            <div class="header">
              <div class="source-label">RSS Akışı</div>
              <div class="feed-name">\(feedName)</div>
            </div>
            <div class="body">
              <h1 class="article-title">\(title)</h1>
              <div class="divider"></div>
              \(previewEscaped.isEmpty ? "" : "<p class=\"preview-text\">\(previewEscaped)</p>")
              \(url.isEmpty ? "" : "<a class=\"cta-btn\" href=\"\(urlEscaped)\">Makaleyi Oku →</a>")
            </div>
            <div class="footer">
              <p>RSS Okuyucu uygulaması üzerinden paylaşıldı</p>
            </div>
          </div>
        </body>
        </html>
        """
    }
}

// MARK: - String Yardımcı Metodları

extension String {
    /// HTML entity'leri çözerek ve tag'leri silerek düz metin döndürür.
    /// NSAttributedString kullanarak &#252; gibi entity'leri doğru decode eder.
    func htmlToPlainText() -> String {
        guard !self.isEmpty else { return "" }
        // NSAttributedString HTML entity'leri ve tag'leri otomatik çözer
        if let data = self.data(using: .utf8),
           let attributed = try? NSAttributedString(
               data: data,
               options: [
                   .documentType: NSAttributedString.DocumentType.html,
                   .characterEncoding: String.Encoding.utf8.rawValue
               ],
               documentAttributes: nil
           ) {
            return attributed.string
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // Fallback: sadece tag'leri sil (entity'ler ham kalabilir)
        return self
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var htmlEscaped: String {
        self
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}

