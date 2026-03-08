import SwiftUI

#if os(macOS)
import AppKit

/// Mod 2: Saf Okuma Modu — makale içeriğini yapısal bloklara ayırarak
/// reklamsız, okunaklı bir SwiftUI arayüzünde sunar.
struct ReaderModeView: View {
    let article: Article
    
    @Environment(\.modelContext) private var modelContext
    @State private var extractedArticle: ReadabilityExtractor.ExtractedArticle?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if let content = extractedArticle {
                    articleContentView(content)
                }
            }
            .padding(.horizontal, 48)
            .padding(.vertical, 32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
        .onAppear {
            markAsRead()
            loadContent()
        }
        .onChange(of: article) {
            markAsRead()
            isLoading = true
            errorMessage = nil
            extractedArticle = nil
            loadContent()
        }
    }
    
    // MARK: - Sub Views
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Makale içeriği ayıklanıyor...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            
            Text("İçerik Ayıklanamadı")
                .font(.headline)
            
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            if let linkString = article.link, let url = URL(string: linkString) {
                Button("Safari'de Aç") {
                    NSWorkspace.shared.open(url)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.top, 100)
    }
    
    @ViewBuilder
    private func articleContentView(_ content: ReadabilityExtractor.ExtractedArticle) -> some View {
        // Üst bilgi
        if let siteName = content.siteName {
            Text(siteName.uppercased())
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(Color.accentColor)
                .tracking(1.2)
                .padding(.bottom, 8)
        }
        
        // Başlık
        Text(content.title)
            .font(.largeTitle)
            .fontWeight(.bold)
            .lineSpacing(4)
            .padding(.bottom, 4)
        
        // Tarih
        if let date = article.publishedDate {
            Text(date, style: .date)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)
        }
        
        Divider()
            .padding(.vertical, 12)
        
        // Ana resim
        if let imageURL = content.imageURL {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(8)
                        .padding(.bottom, 16)
                case .failure:
                    EmptyView()
                case .empty:
                    ProgressView()
                        .frame(height: 200)
                        .padding(.bottom, 16)
                @unknown default:
                    EmptyView()
                }
            }
        }
        
        // İçerik Blokları
        ForEach(Array(content.blocks.enumerated()), id: \.offset) { index, block in
            renderBlock(block)
        }
        
        Spacer(minLength: 40)
        
        // Alt kısım — orijinal makale linki
        if let linkString = article.link, let url = URL(string: linkString) {
            Divider()
                .padding(.vertical, 12)
            
            Button(action: { NSWorkspace.shared.open(url) }) {
                Label("Orijinal Makaleyi Tarayıcıda Aç", systemImage: "safari")
            }
            .buttonStyle(.link)
            .padding(.bottom, 16)
        }
    }
    
    // MARK: - Block Renderer
    
    @ViewBuilder
    private func renderBlock(_ block: ReadabilityExtractor.ContentBlock) -> some View {
        switch block {
        case .heading(let text, let level):
            Text(text)
                .font(fontForHeading(level))
                .fontWeight(.bold)
                .textSelection(.enabled)
                .padding(.top, level <= 2 ? 20 : 14)
                .padding(.bottom, 6)
            
        case .paragraph(let text):
            Text(text)
                .font(.body)
                .lineSpacing(6)
                .textSelection(.enabled)
                .padding(.bottom, 12)
            
        case .image(let url, let alt):
            VStack(alignment: .center, spacing: 4) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(6)
                    case .failure:
                        EmptyView()
                    case .empty:
                        ProgressView()
                            .frame(height: 150)
                    @unknown default:
                        EmptyView()
                    }
                }
                if let alt = alt, !alt.isEmpty {
                    Text(alt)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            
        case .youtube(let videoID):
            youtubeCard(videoID: videoID)
                .padding(.vertical, 8)
            
        case .link(let text, let url):
            Button(action: { NSWorkspace.shared.open(url) }) {
                Label(text, systemImage: "link")
            }
            .buttonStyle(.link)
            .padding(.bottom, 8)
            
        case .blockquote(let text):
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor.opacity(0.5))
                    .frame(width: 4)
                
                Text(text)
                    .font(.body)
                    .italic()
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
                    .textSelection(.enabled)
                    .padding(.leading, 12)
                    .padding(.vertical, 4)
            }
            .padding(.vertical, 8)
            
        case .listItem(let text):
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                    .font(.body)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                Text(text)
                    .font(.body)
                    .lineSpacing(4)
                    .textSelection(.enabled)
            }
            .padding(.bottom, 4)
            .padding(.leading, 8)
        }
    }
    
    // MARK: - YouTube Card
    
    private func youtubeCard(videoID: String) -> some View {
        // mqdefault is 320x180 (native 16:9), so it does not contain the black letterboxing 
        // that hqdefault (480x360) has. We scale it up with .fill to fit the width.
        let thumbnailURL = URL(string: "https://img.youtube.com/vi/\(videoID)/mqdefault.jpg")
        let watchURL = URL(string: "https://www.youtube.com/watch?v=\(videoID)")!
        
        return VStack(spacing: 0) {
            Button(action: {
                NSWorkspace.shared.open(watchURL)
            }) {
                ZStack {
                    if let thumbnailURL = thumbnailURL {
                        AsyncImage(url: thumbnailURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(16/9, contentMode: .fill)
                                    .frame(maxWidth: .infinity)
                                    .clipped()
                            case .failure:
                                Rectangle()
                                    .fill(Color.black.opacity(0.8))
                                    .aspectRatio(16/9, contentMode: .fit)
                                    .overlay {
                                        Text("Kapak yüklenemedi")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                    }
                            case .empty:
                                Rectangle()
                                    .fill(Color.gray.opacity(0.15))
                                    .aspectRatio(16/9, contentMode: .fit)
                                    .overlay {
                                        ProgressView()
                                    }
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }
                    
                    Circle()
                        .fill(Color.red)
                        .frame(width: 64, height: 64)
                        .overlay {
                            Image(systemName: "play.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .offset(x: 2)
                        }
                        .shadow(color: .black.opacity(0.4), radius: 8)
                }
                .cornerRadius(12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            HStack(spacing: 6) {
                Image(systemName: "play.rectangle.fill")
                    .foregroundColor(.red)
                Text("YouTube'da İzle")
                    .font(.callout)
                    .fontWeight(.medium)
            }
            .padding(.top, 8)
            .foregroundStyle(.primary)
        }
    }
    
    // MARK: - Helpers
    
    private func fontForHeading(_ level: Int) -> Font {
        switch level {
        case 1: return .title
        case 2: return .title2
        case 3: return .title3
        default: return .headline
        }
    }
    
    private func loadContent() {
        guard let linkString = article.link, let url = URL(string: linkString) else {
            errorMessage = "Bu makalenin bağlantısı bulunmuyor."
            isLoading = false
            return
        }

        // YouTube linkleri için özel reader modu
        if let videoID = ReadabilityExtractor.extractYouTubeID(from: linkString) {
            var blocks: [ReadabilityExtractor.ContentBlock] = []

            // 1. YouTube oynat kartı
            blocks.append(.youtube(videoID: videoID))

            // 2. RSS'ten gelen açıklamayı düz metne çevir (entity'ler dahil)
            let rawContent = article.content ?? ""
            let plain = rawContent.htmlToPlainText()
            if !plain.isEmpty {
                blocks.append(.paragraph(text: plain))
            }

            extractedArticle = ReadabilityExtractor.ExtractedArticle(
                title: article.title,
                blocks: blocks,
                imageURL: URL(string: "https://img.youtube.com/vi/\(videoID)/maxresdefault.jpg"),
                siteName: article.feed?.title
            )
            isLoading = false
            return
        }

        // Normal makaleler için web'den çek
        Task {
            do {
                let result = try await ReadabilityExtractor.extract(from: url)
                extractedArticle = result
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
    
    private func markAsRead() {
        if !article.isRead {
            article.isRead = true
            try? modelContext.save()
        }
    }
}

#endif
