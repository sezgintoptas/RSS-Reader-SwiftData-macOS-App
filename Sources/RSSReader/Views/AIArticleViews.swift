import SwiftUI

#if os(macOS)

// MARK: - AI Özet Paneli

/// Toolbar'daki ✨ butonuna tıklanınca popover olarak açılır.
/// onAppear → henüz analiz edilmemişse otomatik analiz başlatır.
struct AIArticleSummaryPanel: View {
    let article: Article
    @ObservedObject private var aiManager = AIManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // ── Başlık
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.purple)
                Text("AI Özeti")
                    .font(.headline)
                Spacer()
                if let cat = article.aiCategory {
                    badge(cat, color: .purple)
                }
                if let sent = article.aiSentiment {
                    badge(sent, color: .blue)
                }
            }

            Divider()

            // ── İçerik
            if aiManager.isProcessing {
                HStack(spacing: 10) {
                    ProgressView().scaleEffect(0.8)
                    Text("Makale analiz ediliyor…")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

            } else if let error = aiManager.lastError {
                VStack(alignment: .leading, spacing: 8) {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .font(.callout)
                    // Extractive fallback varsa göster
                    if let summary = article.aiSummary {
                        Divider()
                        Text("Çıkarılan özet:")
                            .font(.caption).foregroundStyle(.secondary)
                        Text(summary).font(.callout)
                    }
                }

            } else if let summary = article.aiSummary {
                Text(summary)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    Task { await aiManager.analyze(article: article) }
                } label: {
                    Label("Yeniden Analiz Et", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

            } else if article.isAIProcessed {
                // İşlendi ama özet üretilemedi
                VStack(alignment: .leading, spacing: 8) {
                    Label("Özet üretilemedi.", systemImage: "exclamationmark.circle")
                        .foregroundStyle(.orange).font(.callout)
                    Button {
                        Task { await aiManager.analyze(article: article) }
                    } label: {
                        Label("Tekrar Dene", systemImage: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                }
            } else {
                Text("Henüz analiz edilmedi.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }

        }
        .padding(16)
        .frame(width: 360)
        .onAppear {
            // Popover açılır açılmaz — analiz edilmemişse başlat
            if !article.isAIProcessed && !aiManager.isProcessing {
                Task { await aiManager.analyze(article: article) }
            }
        }
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

#endif
