# RSS Okuyucu — macOS Native RSS Reader

> **Swift · SwiftUI · SwiftData · macOS 14+**  
> Tamamen yerel, gizlilik odaklı, reklamsız bir RSS/Atom beslemesi okuyucusu.

---

## ✨ Özellikler

| Özellik | Durum |
|---------|-------|
| 📂 OPML içe/dışa aktarım | ✅ |
| 🔄 Dinamik OPML abonelikleri | ✅ |
| ⏱ Otomatik periyodik yenileme | ✅ |
| 🗂 Akıllı Klasörler (Okunmayanlar, Bugün, Favoriler) | ✅ |
| 🔍 Başlık + içerik araması | ✅ |
| ⭐ Yıldızlama / Favoriler | ✅ |
| ✉️ Tümünü Okundu İşaretle | ✅ |
| 📝 Makale özet satırı (snippet) | ✅ |
| 🌐 Uygulama içi web görünümü | ✅ |
| 🚫 uBlock tarzı ağ-seviyesi reklam engelleme | ✅ |
| 📖 Temiz Okuma Modu (SwiftSoup) | ✅ |
| 🔗 Harici Safari modu | ✅ |
| 📺 YouTube özel oynatıcı | ✅ |
| 🔔 Otomatik güncelleme (GitHub Releases) | ✅ |
| 🧹 Otomatik arşiv limiti ve eski makale temizliği | ✅ |

---

## 📥 Kurulum

### Hazır Binary (Önerilen)

1. [**Releases**](https://github.com/sezgintoptas/RSS-Reader-SwiftData-macOS-App/releases/latest) sayfasından `RSSReader.app.zip` dosyasını indirin
2. Zip'i açın
3. `RSSReader.app`'i `/Applications` klasörüne sürükleyin
4. **İlk açılışta:** Sağ tıklayın → **"Aç"** seçin (imzasız uygulama Gatekeeper uyarısı için)

```bash
# Terminal ile Gatekeeper karantinasını kaldırma (alternatif)
xattr -cr /Applications/RSSReader.app
```

### Kaynaktan Derleme

**Gereksinimler:** macOS 14+, Xcode 16+, Swift 5.10+

```bash
git clone https://github.com/sezgintoptas/RSS-Reader-SwiftData-macOS-App.git
cd RSS-Reader-SwiftData-macOS-App
swift build -c release
# Binary: .build/release/RSSReader
```

---

## 🚀 Kullanım

### Besleme Ekleme
- **Toolbar → `···` menüsü → "RSS Ekle"** — Doğrudan RSS/Atom URL'si
- **OPML İçe Aktar** — Inoreader, Feedly, NewsBlur'dan alınan OPML dosyaları
- **Dinamik OPML** — Belirli aralıklarla otomatik güncellenen OPML URL'leri

### Okuma Modları
`Cmd+,` (Ayarlar) → **Varsayılan Okuma Modu** seçin:
| Mod | Açıklama |
|-----|----------|
| **Uygulama İçi** | EasyList tabanlı reklam engelleme ile WKWebView |
| **Temiz Okuma** | HTML'den makale içeriği çekilerek sade görünüm |
| **Harici Safari** | Makaleleri varsayılan tarayıcıda aç |

### Otomatik Yenileme
`Cmd+,` → **Genel Ayarlar → Otomatik Yenileme** → 5/10/15/30/60 dakika seçin.

---

## 🔄 Otomatik Güncelleme

Uygulama içindeki güncelleme sistemi GitHub Releases API'sini kullanır:
- **Cmd+, → Uygulama Güncellemesi → "Güncelleme Kontrol Et"**
- Yeni sürüm varsa indirip kurar ve uygulamayı yeniden başlatır.

---

## 🏗 Mimari

```
Sources/RSSReader/
├── Models/
│   ├── ItemModels.swift          # SwiftData @Model (Folder, Feed, Article)
│   └── ReadingMode.swift         # Enum: okuma modları
├── Utils/
│   ├── SyncEngine.swift          # @ModelActor arka plan senkronizasyonu
│   ├── BackgroundRefreshManager  # Periyodik otomatik yenileme
│   ├── ContentBlockerManager     # EasyList reklam engelleme
│   ├── ReadabilityExtractor      # SwiftSoup temiz okuma
│   ├── OPMLParser.swift          # XMLParser tabanlı OPML ayrıştırma
│   ├── UpdateManager.swift       # GitHub Releases auto-updater
│   └── AppVersion.swift          # Sürüm ve repo bilgileri
└── Views/
    ├── ContentView.swift
    ├── SidebarView.swift         # Klasörler + Akıllı Klasörler
    ├── ArticleListView.swift     # Makale listesi + arama + snippet
    ├── ArticleDetailCoordinatorView.swift # Mod yönlendirici (WebView/Reader/Safari/YouTube)
    ├── YouTubePlayerView.swift   # Özel YouTube IFrame oynatıcı
    ├── InAppWebView.swift        # WKWebView wrapper
    ├── ReaderModeView.swift      # Temiz okuma
    ├── ManageFeedsView.swift     # Besleme yönetimi (drag-drop)
    └── SettingsView.swift        # Ayarlar
```

**Bağımlılıklar** (Swift Package Manager):
- [FeedKit](https://github.com/nmdias/FeedKit) — RSS/Atom/JSON ayrıştırma
- [SwiftSoup](https://github.com/scinfu/SwiftSoup) — HTML ayrıştırma (Temiz Okuma Modu)

---

## 🤝 Katkıda Bulunma

1. Fork'layın
2. Feature branch oluşturun: `git checkout -b feature/ozellik-adi`
3. Commit'leyin: `git commit -m 'feat: yeni özellik'`
4. Push'layın: `git push origin feature/ozellik-adi`
5. Pull Request açın

---

## 📄 Lisans

MIT License — Bkz. [LICENSE](LICENSE)