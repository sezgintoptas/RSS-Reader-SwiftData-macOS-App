import SwiftUI
import SwiftData

#if os(macOS)
struct ManageFeedsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \Feed.sortIndex) private var allFeeds: [Feed]
    @Query(sort: \Folder.sortIndex) private var folders: [Folder]
    
    @State private var showingNewFolder = false
    @State private var newFolderName = ""
    @State private var feedToDelete: Feed?
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Başlık
            HStack {
                Text("Beslemeleri Yönet")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("Kapat") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()
            
            Divider()
            
            // MARK: - Besleme Listesi
            List {
                ForEach(allFeeds) { feed in
                    HStack(spacing: 12) {
                        // Favicon
                        if let host = URL(string: feed.url)?.host {
                            AsyncImage(url: URL(string: "https://s2.googleusercontent.com/s2/favicons?domain=\(host)&sz=64")) { image in
                                image.resizable().frame(width: 20, height: 20).cornerRadius(4)
                            } placeholder: {
                                Image(systemName: "dot.radiowaves.up.forward").frame(width: 20, height: 20)
                            }
                        }
                        
                        // Başlık ve URL
                        VStack(alignment: .leading, spacing: 2) {
                            Text(feed.title)
                                .font(.body)
                                .fontWeight(.medium)
                                .lineLimit(1)
                            Text(feed.url)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        .frame(minWidth: 200, alignment: .leading)
                        
                        Spacer()
                        
                        // Klasör seçici
                        Picker("", selection: folderBinding(for: feed)) {
                            Text("Klasörsüz").tag(nil as Folder?)
                            ForEach(folders) { folder in
                                Text(folder.name).tag(folder as Folder?)
                            }
                        }
                        .frame(width: 130)
                        .labelsHidden()
                        
                        // Aktif/Pasif toggle
                        Toggle("", isOn: Binding(
                            get: { feed.isActive },
                            set: { feed.isActive = $0; try? modelContext.save() }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .frame(width: 50)
                        
                        // Sil butonu
                        Button(role: .destructive) {
                            feedToDelete = feed
                            showingDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                }
            }
            
            Divider()
            
            // MARK: - Alt Araç Çubuğu
            HStack {
                Button {
                    showingNewFolder = true
                } label: {
                    Label("Yeni Klasör", systemImage: "folder.badge.plus")
                }
                
                Spacer()
                
                Text("\(allFeeds.count) besleme")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Klasör silme menüsü
                if !folders.isEmpty {
                    Menu {
                        ForEach(folders) { folder in
                            Button(role: .destructive) {
                                deleteFolder(folder)
                            } label: {
                                Label("Sil: \(folder.name)", systemImage: "trash")
                            }
                        }
                    } label: {
                        Label("Klasör Sil", systemImage: "folder.badge.minus")
                    }
                }
            }
            .padding()
        }
        .alert("Yeni Klasör Oluştur", isPresented: $showingNewFolder) {
            TextField("Klasör adı", text: $newFolderName)
            Button("İptal", role: .cancel) { newFolderName = "" }
            Button("Oluştur") {
                createFolder()
            }
        }
        .alert("Beslemeyi Sil", isPresented: $showingDeleteConfirmation) {
            Button("İptal", role: .cancel) { feedToDelete = nil }
            Button("Sil", role: .destructive) {
                if let feed = feedToDelete {
                    modelContext.delete(feed)
                    try? modelContext.save()
                    feedToDelete = nil
                }
            }
        } message: {
            if let feed = feedToDelete {
                Text("'\(feed.title)' beslemesini ve tüm makalelerini silmek istediğinize emin misiniz?")
            }
        }
    }
    
    // MARK: - Helpers
    
    private func folderBinding(for feed: Feed) -> Binding<Folder?> {
        Binding(
            get: { feed.folder },
            set: { newFolder in
                feed.folder = newFolder
                try? modelContext.save()
            }
        )
    }
    
    private func createFolder() {
        guard !newFolderName.isEmpty else { return }
        let folder = Folder(name: newFolderName, sortIndex: folders.count)
        modelContext.insert(folder)
        try? modelContext.save()
        newFolderName = ""
    }
    
    private func deleteFolder(_ folder: Folder) {
        // Klasördeki feedleri "Klasörsüz" yap (silme yerine)
        for feed in folder.feeds ?? [] {
            feed.folder = nil
        }
        modelContext.delete(folder)
        try? modelContext.save()
    }
}
#endif
