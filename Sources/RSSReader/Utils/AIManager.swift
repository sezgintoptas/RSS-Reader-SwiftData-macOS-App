import Foundation
import NaturalLanguage
import OSLog

/// Butona basılınca çalışan on-demand AI özetleme servisi.
/// Google Gemini API (AI Studio) kullanır. API key UserDefaults'ta saklanır.
@MainActor
final class AIManager: ObservableObject {

    static let shared = AIManager()
    private let logger = Logger(subsystem: "com.rssreader.app", category: "AIManager")

    @Published var isProcessing: Bool = false
    @Published var lastError: String? = nil

    // Ayarlar'dan okunan API key
    private var apiKey: String {
        UserDefaults.standard.string(forKey: "geminiApiKey") ?? ""
    }

    // gemini-flash-latest — kararlı, ücretsiz, v1beta endpoint
    private let geminiModel = "gemini-flash-latest"

    private init() {}

    // MARK: - Ana Giriş Noktası

    func analyze(article: Article) async {
        guard !isProcessing else { return }
        isProcessing = true
        lastError = nil

        defer { isProcessing = false }

        let rawText = article.content ?? article.title
        let cleanText = extractPlainText(from: rawText)

        guard !cleanText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            lastError = "İşlenecek içerik bulunamadı."
            return
        }

        // NaturalLanguage → her zaman çalışır (hızlı, offline)
        let category  = detectCategory(from: cleanText)
        let sentiment = detectSentiment(from: cleanText)

        // Özet → Gemini API varsa, yoksa extractive fallback
        let summary: String?
        if !apiKey.isEmpty {
            summary = await summarizeWithGemini(text: cleanText, title: article.title)
        } else {
            summary = extractiveSummary(from: cleanText)
            if lastError == nil {
                lastError = "Gemini API anahtarı girilmedi. Ayarlar → Yapay Zeka'dan ekleyin."
            }
        }

        article.aiSummary   = summary
        article.aiCategory  = category
        article.aiSentiment = sentiment
        article.isAIProcessed = true

        logger.info("✅ AI analizi tamamlandı: '\(article.title.prefix(40))'")
    }

    // MARK: - Google Gemini API

    // Gemini yanıt yapısı — Codable ile güvenli parse
    private struct GeminiResponse: Decodable {
        let candidates: [Candidate]?
        struct Candidate: Decodable {
            let content: Content?
            struct Content: Decodable {
                let parts: [Part]?
                struct Part: Decodable {
                    let text: String?
                }
            }
        }
    }

    private func summarizeWithGemini(text: String, title: String) async -> String? {
        // API key'i header ile gönder (curl örneğiyle aynı yöntem)
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(geminiModel):generateContent"
        guard let url = URL(string: urlString) else { return nil }

        let prompt = "Aşağıdaki makaleyi Türkçe olarak 2-3 cümleyle özetle. Sadece özet metnini yaz.\n\nBaşlık: \(title)\n\nİçerik: \(text.prefix(3000))"

        let body: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ],
            "generationConfig": [
                "temperature": 0.3,
                "maxOutputTokens": 500
            ]
        ]

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(apiKey, forHTTPHeaderField: "X-goog-api-key")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            request.timeoutInterval = 30

            let (data, response) = try await URLSession.shared.data(for: request)

            // HTTP hata kontrolü
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                let msg = String(data: data, encoding: .utf8) ?? "Bilinmeyen hata"
                logger.error("Gemini API hatası (\(http.statusCode)): \(msg)")
                switch http.statusCode {
                case 400: lastError = "Geçersiz istek — API anahtarını kontrol edin (400)"
                case 401: lastError = "Yetkisiz — API anahtarı hatalı (401)"
                case 403: lastError = "Erişim reddedildi — API etkin değil (403)"
                case 404: lastError = "Model bulunamadı (404)"
                case 429: lastError = "Kota aşıldı — günlük limit doldu (429)"
                default:  lastError = "Gemini API Hatası: HTTP \(http.statusCode)"
                }
                return extractiveSummary(from: text)
            }

            // Codable ile güvenli parse
            let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
            let resultText = decoded.candidates?.first?.content?.parts?.first?.text

            if let result = resultText?.trimmingCharacters(in: .whitespacesAndNewlines),
               !result.isEmpty {
                logger.info("Gemini yanıtı: \(result.prefix(80))")
                return result
            } else {
                // Parse başarılı ama metin yok — raw response'u logla
                let raw = String(data: data, encoding: .utf8) ?? "-"
                logger.warning("Gemini metin boş. Ham yanıt: \(raw.prefix(300))")
                lastError = "Gemini yanıt verdi ama metin üretemedi."
                return extractiveSummary(from: text)
            }

        } catch {
            logger.error("Gemini istek hatası: \(error.localizedDescription)")
            lastError = "Bağlantı hatası: \(error.localizedDescription)"
            return extractiveSummary(from: text)
        }
    }

    // MARK: - Extractive Fallback (ilk 3 cümle)

    private func extractiveSummary(from text: String) -> String? {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var sentences: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let s = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !s.isEmpty { sentences.append(s) }
            return sentences.count < 3
        }
        return sentences.isEmpty ? nil : sentences.joined(separator: " ")
    }

    // MARK: - Kategori

    private func detectCategory(from text: String) -> String? {
        let map: [(String, [String])] = [
            ("🤖 Yapay Zeka",  ["yapay zeka", "ai", "machine learning", "llm", "gpt", "openai", "gemini"]),
            ("💻 Teknoloji",   ["apple", "google", "microsoft", "iphone", "mac", "android", "yazılım"]),
            ("💰 Ekonomi",     ["borsa", "dolar", "euro", "enflasyon", "faiz", "ekonomi", "piyasa"]),
            ("🏛 Politika",    ["hükümet", "cumhurbaşkanı", "meclis", "seçim", "siyaset"]),
            ("⚽️ Spor",       ["futbol", "basketbol", "maç", "turnuva", "lig"]),
            ("🔬 Bilim",       ["araştırma", "bilim", "keşif", "uzay", "nasa"]),
            ("🌍 Dünya",       ["savaş", "kriz", "nato", "bm", "uluslararası"]),
        ]
        let lower = text.lowercased()
        for (cat, keys) in map {
            if keys.contains(where: { lower.contains($0) }) { return cat }
        }
        return "📰 Genel"
    }

    // MARK: - Duygu

    private func detectSentiment(from text: String) -> String? {
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text
        let (tag, _) = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
        guard let s = tag?.rawValue, let score = Double(s) else { return "😐 Nötr" }
        if score > 0.1  { return "😊 Olumlu" }
        if score < -0.1 { return "😟 Olumsuz" }
        return "😐 Nötr"
    }

    // MARK: - HTML Temizleme

    private func extractPlainText(from html: String) -> String {
        var text = html
        let entities = ["&amp;":"&","&lt;":"<","&gt;":">","&quot;":"\"","&apos;":"'","&nbsp;":" "]
        entities.forEach { text = text.replacingOccurrences(of: $0.key, with: $0.value) }
        if let re = try? NSRegularExpression(pattern: "<[^>]+>") {
            text = re.stringByReplacingMatches(in: text,
                                               range: NSRange(text.startIndex..., in: text),
                                               withTemplate: " ")
        }
        return text.components(separatedBy: .whitespacesAndNewlines)
                   .filter { !$0.isEmpty }.joined(separator: " ")
    }
}
