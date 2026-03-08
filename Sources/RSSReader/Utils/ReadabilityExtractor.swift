import Foundation
import SwiftSoup

/// Makale URL'sinden ana içeriği ayıklayan Readability motoru.
/// SwiftSoup kullanarak HTML'den yapısal bloklar (paragraf, başlık, resim, YouTube) çıkarır.
struct ReadabilityExtractor {
    
    /// İçerik bloğu türleri
    enum ContentBlock: Identifiable {
        case heading(text: String, level: Int)
        case paragraph(text: String)
        case image(url: URL, alt: String?)
        case youtube(videoID: String)
        case link(text: String, url: URL)
        case blockquote(text: String)
        case listItem(text: String)
        
        var id: String {
            switch self {
            case .heading(let t, let l): return "h\(l)_\(t.prefix(30))"
            case .paragraph(let t): return "p_\(t.prefix(40))"
            case .image(let u, _): return "img_\(u.absoluteString.prefix(40))"
            case .youtube(let v): return "yt_\(v)"
            case .link(let t, _): return "link_\(t.prefix(30))"
            case .blockquote(let t): return "bq_\(t.prefix(30))"
            case .listItem(let t): return "li_\(t.prefix(30))"
            }
        }
    }
    
    struct ExtractedArticle {
        let title: String
        let blocks: [ContentBlock]
        let imageURL: URL?
        let siteName: String?
    }
    
    /// Verilen URL'den makale içeriğini asenkron olarak ayıklar.
    static func extract(from url: URL) async throws -> ExtractedArticle {
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else {
            throw ExtractorError.invalidEncoding
        }
        return try parse(html: html, baseURL: url)
    }
    
    /// HTML string'den makale içeriğini ayıklar.
    static func parse(html: String, baseURL: URL) throws -> ExtractedArticle {
        let doc = try SwiftSoup.parse(html)
        
        let title = try extractTitle(from: doc)
        let imageURL = try extractMainImage(from: doc, baseURL: baseURL)
        let siteName = try doc.select("meta[property=og:site_name]").first()?.attr("content")
        let blocks = try extractBlocks(from: doc, baseURL: baseURL)
        
        return ExtractedArticle(
            title: title,
            blocks: blocks,
            imageURL: imageURL,
            siteName: siteName
        )
    }
    
    // MARK: - Private Helpers
    
    private static func extractTitle(from doc: Document) throws -> String {
        if let ogTitle = try doc.select("meta[property=og:title]").first()?.attr("content"),
           !ogTitle.isEmpty {
            return ogTitle
        }
        if let titleTag = try doc.title().nilIfEmpty {
            return titleTag
        }
        if let h1 = try doc.select("h1").first()?.text() {
            return h1
        }
        return "Başlıksız Makale"
    }
    
    private static func extractMainImage(from doc: Document, baseURL: URL) throws -> URL? {
        if let ogImage = try doc.select("meta[property=og:image]").first()?.attr("content"),
           let url = URL(string: ogImage, relativeTo: baseURL) {
            return url
        }
        if let firstImg = try doc.select("article img, main img, .post img, .entry-content img").first(),
           let src = try? firstImg.attr("src"),
           let url = URL(string: src, relativeTo: baseURL) {
            return url
        }
        return nil
    }
    
    /// Ana içerik elementini bul
    private static func findContentElement(from doc: Document) throws -> Element? {
        // Gereksiz elementleri kaldır
        try doc.select("script, style, nav, header, footer, aside, .sidebar, .comments, .ad, .advertisement, .social-share, .related-posts, .menu, .nav, .cookie, .popup").remove()
        
        let selectors = [
            "article", "main", "[role=main]",
            ".post-content", ".entry-content", ".article-content",
            ".article-body", ".post-body", ".story-body", ".content"
        ]
        
        for selector in selectors {
            if let element = try doc.select(selector).first() {
                let text = try element.text()
                if text.count > 200 {
                    return element
                }
            }
        }
        
        return try doc.body()
    }
    
    /// Element içindeki yapısal blokları çıkar
    private static func extractBlocks(from doc: Document, baseURL: URL) throws -> [ContentBlock] {
        guard let contentElement = try findContentElement(from: doc) else {
            return [.paragraph(text: "İçerik ayıklanamadı.")]
        }
        
        var blocks: [ContentBlock] = []
        
        // YouTube iframe'lerini çıkarmadan ÖNCE koru
        let iframes = try contentElement.select("iframe")
        for iframe in iframes {
            if let src = try? iframe.attr("src"),
               let videoID = extractYouTubeID(from: src) {
                blocks.append(.youtube(videoID: videoID))
            }
        }
        
        // Blok elementleri çıkar
        try processElement(contentElement, into: &blocks, baseURL: baseURL, depth: 0)
        
        // YouTube blokları zaten eklenmiş, tekrar etmesin
        // Boş paragrafları filtrele
        blocks = blocks.filter { block in
            if case .paragraph(let text) = block {
                return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && text.count > 10
            }
            return true
        }
        
        // Tekrarlı blokları kaldır (uniqueBy id)
        var seen = Set<String>()
        blocks = blocks.filter { block in
            let id = block.id
            if seen.contains(id) { return false }
            seen.insert(id)
            return true
        }
        
        return blocks
    }
    
    /// Recursive element processing
    private static func processElement(_ element: Element, into blocks: inout [ContentBlock], baseURL: URL, depth: Int) throws {
        guard depth < 10 else { return } // sonsuz döngü koruması
        
        for child in element.children() {
            let tagName = child.tagName().lowercased()
            
            switch tagName {
            case "h1", "h2", "h3", "h4", "h5", "h6":
                let text = try child.text().trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    let level = Int(String(tagName.last!)) ?? 2
                    blocks.append(.heading(text: text, level: level))
                }
                
            case "p":
                let text = try child.text().trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    // Paragraf içinde YouTube linki var mı?
                    if let ytLink = try child.select("a[href*=youtube], a[href*=youtu.be]").first(),
                       let href = try? ytLink.attr("href"),
                       let videoID = extractYouTubeID(from: href) {
                        blocks.append(.youtube(videoID: videoID))
                    }
                    blocks.append(.paragraph(text: text))
                }
                
            case "img":
                if let src = try? child.attr("src"),
                   let url = URL(string: src, relativeTo: baseURL) {
                    let alt = try? child.attr("alt")
                    blocks.append(.image(url: url, alt: alt))
                }
                
            case "figure":
                // İçindeki img ve figcaption'ı çıkar
                if let img = try child.select("img").first(),
                   let src = try? img.attr("src"),
                   let url = URL(string: src, relativeTo: baseURL) {
                    let caption = try child.select("figcaption").first()?.text()
                    blocks.append(.image(url: url, alt: caption))
                }
                
            case "blockquote":
                let text = try child.text().trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    blocks.append(.blockquote(text: text))
                }
                
            case "ul", "ol":
                let items = try child.select("li")
                for item in items {
                    let text = try item.text().trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        blocks.append(.listItem(text: text))
                    }
                }
                
            case "iframe":
                // YouTube embed
                if let src = try? child.attr("src"),
                   let videoID = extractYouTubeID(from: src) {
                    blocks.append(.youtube(videoID: videoID))
                }
                
            case "a":
                // Bağımsız link (paragraf dışında)
                if let href = try? child.attr("href"),
                   let url = URL(string: href, relativeTo: baseURL) {
                    if let videoID = extractYouTubeID(from: href) {
                        blocks.append(.youtube(videoID: videoID))
                    }
                }
                
            case "div", "section", "article", "main":
                // Recursive: alt elementlere dal
                try processElement(child, into: &blocks, baseURL: baseURL, depth: depth + 1)
                
            default:
                // Bilinmeyen element — metin içeriği varsa paragraf olarak ekle
                let text = try child.text().trimmingCharacters(in: .whitespacesAndNewlines)
                if text.count > 50 {
                    try processElement(child, into: &blocks, baseURL: baseURL, depth: depth + 1)
                }
            }
        }
    }
    
    /// YouTube video ID çıkar (embed URL, watch URL, kısa URL)
    static func extractYouTubeID(from urlString: String) -> String? {
        // youtube.com/embed/VIDEO_ID
        if urlString.contains("youtube.com/embed/") {
            return urlString.components(separatedBy: "youtube.com/embed/").last?
                .components(separatedBy: "?").first?
                .components(separatedBy: "&").first
        }
        // youtube.com/watch?v=VIDEO_ID
        if urlString.contains("youtube.com/watch") {
            let components = URLComponents(string: urlString)
            return components?.queryItems?.first(where: { $0.name == "v" })?.value
        }
        // youtu.be/VIDEO_ID
        if urlString.contains("youtu.be/") {
            return urlString.components(separatedBy: "youtu.be/").last?
                .components(separatedBy: "?").first
        }
        // youtube.com/shorts/VIDEO_ID
        if urlString.contains("youtube.com/shorts/") {
            return urlString.components(separatedBy: "youtube.com/shorts/").last?
                .components(separatedBy: "?").first
        }
        return nil
    }
    
    enum ExtractorError: Error, LocalizedError {
        case invalidEncoding
        
        var errorDescription: String? {
            switch self {
            case .invalidEncoding: return "HTML sayfasının karakter kodlaması tanınamadı."
            }
        }
    }
}

// Helper extension
private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
