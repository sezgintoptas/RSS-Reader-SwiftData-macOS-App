import SwiftUI

#if os(macOS)
import AppKit

/// Mod 3: Makaleyi harici Safari tarayıcısında açar.
/// Kullanıcının Safari'ye kurduğu uBlock Origin gibi eklentiler devreye girer.
struct ExternalSafariView: View {
    let article: Article
    
    @Environment(\.modelContext) private var modelContext
    @State private var didOpen = false
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "safari")
                .font(.system(size: 72))
                .foregroundStyle(Color.accentColor)
            
            VStack(spacing: 8) {
                Text("Makale Safari'de Açılıyor")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(article.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            if let linkString = article.link, let url = URL(string: linkString) {
                Button("Safari'de Aç") {
                    openInSafari(url: url)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Text("Bu makalenin bağlantısı bulunmuyor.")
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            markAsRead()
            if !didOpen, let linkString = article.link, let url = URL(string: linkString) {
                didOpen = true
                openInSafari(url: url)
            }
        }
        .onChange(of: article) {
            didOpen = false
            markAsRead()
            if let linkString = article.link, let url = URL(string: linkString) {
                didOpen = true
                openInSafari(url: url)
            }
        }
    }
    
    private func openInSafari(url: URL) {
        let safariAppURL = URL(fileURLWithPath: "/Applications/Safari.app")
        NSWorkspace.shared.open(
            [url],
            withApplicationAt: safariAppURL,
            configuration: NSWorkspace.OpenConfiguration()
        )
    }
    
    private func markAsRead() {
        if !article.isRead {
            article.isRead = true
            try? modelContext.save()
        }
    }
}

#endif
