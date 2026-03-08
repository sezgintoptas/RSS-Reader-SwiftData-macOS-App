import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedSidebarItem: SidebarItem?
    @State private var selectedArticle: Article?
    @State private var showingManageFeeds: Bool = false

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedSidebarItem: $selectedSidebarItem, showingManageFeeds: $showingManageFeeds)
        } content: {
            if let item = selectedSidebarItem {
                ArticleListView(item: item, selectedArticle: $selectedArticle)
            } else {
                Text("Lütfen bir besleme veya klasör seçin")
                    .foregroundColor(.secondary)
            }
        } detail: {
            if let article = selectedArticle {
                ArticleDetailCoordinatorView(article: article)
            } else {
                Text("Lütfen okumak için bir makale seçin")
                    .foregroundColor(.secondary)
            }
        }
        // MARK: - Gecikmeli Okundu İşaretleme
        .onChange(of: selectedArticle) { oldArticle, newArticle in
            // Kullanıcı başka bir makaleye geçtiğinde, önceki makaleyi okundu yap
            if let previous = oldArticle, !previous.isRead {
                previous.isRead = true
                try? modelContext.save()
            }
        }
        .sheet(isPresented: $showingManageFeeds) {
            ManageFeedsView()
                .frame(minWidth: 600, minHeight: 450)
        }
    }
}
