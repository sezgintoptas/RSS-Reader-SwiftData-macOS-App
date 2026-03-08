import SwiftUI
import SwiftData

struct ArticleListView: View {
    var item: SidebarItem

    @Query private var articles: [Article]
    @Environment(\.modelContext) private var modelContext

    @Binding var selectedArticle: Article?
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    init(item: SidebarItem, selectedArticle: Binding<Article?>) {
        self.item = item
        self._selectedArticle = selectedArticle

        switch item {
        case .feed(let feed):
            let feedId = feed.id
            let predicate = #Predicate<Article> { article in
                article.feed?.id == feedId
            }
            _articles = Query(filter: predicate, sort: \Article.publishedDate, order: .reverse)

        case .smartFolder(let folder):
            switch folder {
            case .allFeeds:
                _articles = Query(sort: \Article.publishedDate, order: .reverse)

            case .allUnread:
                let predicate = #Predicate<Article> { !$0.isRead }
                _articles = Query(filter: predicate, sort: \Article.publishedDate, order: .reverse)

            case .arrivedToday:
                let now = Date()
                let startOfDay = Calendar.current.startOfDay(for: now)
                let predicate = #Predicate<Article> { article in
                    if let date = article.publishedDate {
                        return date >= startOfDay
                    } else {
                        return false
                    }
                }
                _articles = Query(filter: predicate, sort: \Article.publishedDate, order: .reverse)

            case .starred:
                let predicate = #Predicate<Article> { $0.isStarred }
                _articles = Query(filter: predicate, sort: \Article.publishedDate, order: .reverse)
            }
        }
    }

    // MARK: - Arama Filtresi

    private var filteredArticles: [Article] {
        if searchText.isEmpty { return articles }
        let query = searchText.lowercased()
        return articles.filter { article in
            article.title.lowercased().contains(query) ||
            (article.content?.lowercased().contains(query) ?? false)
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Arama Çubuğu
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Makale ara…", text: $searchText)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(.bar)
            .contentShape(Rectangle())
            .onTapGesture { isSearchFocused = true }

            Divider()

            // Makale Listesi
            List(selection: $selectedArticle) {
                ForEach(filteredArticles) { article in
                    ArticleRowView(article: article)
                        .contextMenu {
                            Button {
                                article.isStarred.toggle()
                                try? modelContext.save()
                            } label: {
                                Label(
                                    article.isStarred ? "Yıldızı Kaldır" : "Yıldızla",
                                    systemImage: article.isStarred ? "star.slash" : "star"
                                )
                            }
                            Button {
                                article.isRead.toggle()
                                try? modelContext.save()
                            } label: {
                                Label(
                                    article.isRead ? "Okunmadı İşaretle" : "Okundu İşaretle",
                                    systemImage: article.isRead ? "envelope.badge" : "envelope.open"
                                )
                            }
                        }
                        .tag(article)
                }
            }
        }
        .navigationTitle(titleFor(item: item))
        .toolbar {
            // Tümünü Okundu İşaretle
            ToolbarItem {
                Button {
                    markAllRead()
                } label: {
                    Label("Tümünü Okundu İşaretle", systemImage: "envelope.open.fill")
                }
                .help("Tüm görünür makaleleri okundu olarak işaretle")
                .disabled(filteredArticles.allSatisfy(\.isRead))
            }
        }
        #if os(macOS)
        .navigationSplitViewColumnWidth(min: 250, ideal: 320)
        .onExitCommand {
            if isSearchFocused {
                searchText = ""
                isSearchFocused = false
            }
        }
        #endif
    }

    // MARK: - Tümünü Okundu İşaretle

    private func markAllRead() {
        for article in filteredArticles where !article.isRead {
            article.isRead = true
        }
        try? modelContext.save()
    }

    // MARK: - Başlık

    private func titleFor(item: SidebarItem) -> String {
        switch item {
        case .feed(let feed):     return feed.title
        case .smartFolder(let f): return f.rawValue
        }
    }
}

// MARK: - ArticleRowView (Snippet dahil)

struct ArticleRowView: View {
    let article: Article

    /// Bugünü “14:30”, daha eskisini “8 Mar” olarak gösterir — asla saniye göstermez.
    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.doesRelativeDateFormatting = false
        f.locale = Locale.current
        return f
    }()

    private func formattedDate(_ date: Date) -> String {
        let f = ArticleRowView.dateFormatter
        if Calendar.current.isDateInToday(date) {
            f.dateStyle = .none
            f.timeStyle = .short  // “14:30” — sistem saatine göre, saniye yok
        } else if Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year) {
            f.dateFormat = "d MMM"  // “8 Mar”
        } else {
            f.dateFormat = "d MMM yyyy"  // “8 Mar 2024”
        }
        return f.string(from: date)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                // Başlık
                Text(article.title)
                    .font(.headline)
                    .fontWeight(article.isRead ? .regular : .bold)
                    .lineLimit(2)

                // Feed adı + Tarih
                HStack(spacing: 6) {
                    if let feedTitle = article.feed?.title {
                        Text(feedTitle)
                            .font(.caption2)
                            .foregroundColor(.accentColor)
                            .lineLimit(1)
                    }
                    if let date = article.publishedDate {
                        Text(formattedDate(date))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer(minLength: 0)

            // Sağ taraf ikonlar
            VStack(spacing: 4) {
                if article.isStarred {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.caption2)
                }
                if !article.isRead {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 4)
    }
}


