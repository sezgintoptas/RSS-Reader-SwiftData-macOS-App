# Proje İlerleme Özeti (Progress Report)

Tarih: 7 Mart 2026

## Tamamlanan Aşamalar

**Aşama 1: Veri ve Arayüz İskeleti**
- SwiftData `@Model` yapıları (`Folder`, `Feed`, `Article`) oluşturuldu.
- `SidebarView`, `ArticleListView` ve temel `ContentView` SwiftUI düzeni kuruldu.
- Test amaçlı sahte veri ekleyebilen ilk iskelet test için hazırlandı.

**Aşama 2: OPML İçe Aktarımı**
- `XMLParser` tabanlı `OPMLParser` nesnesi kodlandı.
- macOS native `NSOpenPanel` kullanılarak `SidebarView` içine OPML "İçe Aktar" fonksiyonu eklendi.
- Ayrıştırılan OPML verisinin SwiftData `modelContext` üzerinden veritabanına kaydedilmesi sağlandı.

**Aşama 3: Arka Plan Senkronizasyonu**
- `FeedKit` kütüphanesinin completion handler blokları modern `async/await` yapısı (`FeedParser+Async.swift`) ile sarmalandı.
- UI (Ana iş parçacığı) donmasını engellemek amacıyla `#ModelActor` ile `SyncEngine` yapılandırması geliştirildi.
- Kopya makalelerin tespit edilip veritabanına eklenmesini sağlayan arka plan eşzamanlama motoru başarıyla uygulandı ve `SidebarView` içindeki "Senkronize Et" butonu ile entegre edildi.

**Aşama 4: Çevrimiçi Okuma ve Reklam Engelleyici**
- `NSViewRepresentable` kullanılarak `WKWebView` SwiftUI içerisine (`ArticleWebView`) sarmalandı.
- Test için basit reklam ağlarını (doubleclick, google syndication vb.) hedef alan `BlockList.json` dosyası oluşturuldu.
- `BlockList.json` dosyası okunarak `WKContentRuleListStore` üzerinden derlendi (compile) ve sayfa yüklendikten sonra çalışıp performans düşüren JS yöntemleri yerine daha efektif olan ağ tabanlı (network-level) WebView konfigürasyonuna eklendi.
- Seçilen makalenin `ArticleWebView` üzerinde gösterilmesi için `ContentView` bağlandı.

Bu aşamalarla beraber "Aşama 1-4" planlanan proje adımları, belirtilen SwiftUI, SwiftData ve performans kısıtlamalarına tam olarak uyularak başarıyla tamamlanmıştır ve native uygulamaya hazır hale getirilmiştir.

**Aşama 5: Dinamik OPML Abonelikleri**
- `DynamicOPMLSubscription` modeli SwiftData şemasına eklendi.
- `SidebarView` arayüzüne "Dinamik OPML Ekle" menü seçeneği ve URL giriş ekranı eklendi.
- `SyncEngine` sınıfına `syncDynamicOPMLs()` fonksiyonu eklenerek, kayıtlı OPML linklerinin arka planda URLSession ile indirilip `OPMLParser` yardımıyla çözümlenmesi ve yeni beslemelerin veritabanına senkronize edilmesi sağlandı. (Kullanıcı arayüzü kilitlenmeden)

---
## Bekleyen Özellik: macOS Widget Entegrasyonu

**Durum:** Ertelendi
Mevcut projemiz Swift Package Manager (`Package.swift`) üzerinden derlenen bir Executable yapısındadır. Swift Package Manager native olarak "Widget Extension" veya diğer App Extension hedeflerini üretmeyi desteklemez. Widget geliştirebilmemiz için Xcode Projesi (`.xcodeproj`) gerekmektedir. Bu nedenle, kullanıcının onayıyla Widget entegrasyonu şimdilik ertelenmiş olup projenin temel OPML/RSS çalışma özellikleri tamamlanmıştır.

---
**Aşama 6: İyileştirmeler ve Hata Giderme**
- WKWebView içerisindeki reklam engelleyici kurallarında (`WKContentRuleListStore`) yaşanan derleme hatalarını gidermek için detaylı `do-catch` blokları eklendi ve JSON ayrıştırma konsol çıkışları netleştirildi. Engelleyici listesi, sayfa yüklenmeden **önce** konfigürasyon içerisine basarili sekilde enjekte edilmeye baslandi.
- Makale okuma durumu (isRead) veritabanına `modelContext.save()` ile kalıcı olarak işlendi. Tıklanan makale anında okundu olarak işaretlenmekte.
- `SidebarView` içindeki RSS beslemelerinde jenerik ikonlar yerine gerçek sitelerin Favicon'ları `AsyncImage` ile Google Favicon servisinden çekilerek yüklendi.
- Klasör ve tekil beslemelerin yanına okunmamış makale sayılarını belirten bildirim sayıları (`.badge()` benzeri SwiftUI kapsülleri kullanılarak) eklendi. Listede okunmamış makaleler **kalın (bold)** font ile öne çıkarıldı.

---
**Aşama 7: Gelişmiş Okuma Modları ve Reklam Engelleme Ayarları**
- macOS `Settings` sahnesi eklendi (Cmd+, kısayoluyla açılır). 3 modlu `Picker` menüsü `@AppStorage` ile kalıcı olarak saklanır.
- **Mod 1 – Uygulama İçi (uBlock Filtreli):** `ContentBlockerManager` singleton'ı oluşturuldu. EasyList reklam engelleme kurallarını internetten indirip `Application Support/RSSReader/` altına cache'ler. `WKContentRuleListStore` ile async derleyerek `WKWebView`'a uygular. İnternet yoksa 10 temel kural içeren fallback kullanır.
- **Mod 2 – Saf Okuma Modu:** `SwiftSoup` SPM bağımlılığı eklendi. `ReadabilityExtractor` makale URL'sinden HTML indirip `<article>`, `<main>` gibi semantik elementlerden veya en uzun paragraf grubundan başlık, ana resim ve saf metin çıkarır. `ReaderModeView` bunu SwiftUI `ScrollView` ile reklamsız, temiz bir arayüzde sunar.
- **Mod 3 – Harici Safari:** `ExternalSafariView` (`NSWorkspace.shared.open` ile Safari'ye yönlendirme) mevcut altyapıdan adapte edildi.
- `ArticleDetailCoordinatorView` oluşturularak, kullanıcı Ayarlar'da seçtiği moda göre makale anında uygun görünüme yönlendirilir.
- Eski `BlockList.json` ve `WKWebViewWrapper` tamamen kaldırıldı, yerlerine yeni modüler yapı kuruldu.

---
**Aşama 8: Akıllı Klasörler, Favoriler ve Arama**
- `SmartFolder` mantığı eklendi: "Okunmayanlar", "Bugün" ve "Favoriler" klasörleri Sidebar'a entegre edildi.
- Makale listesi (`ArticleListView`) içine başlık ve içerik bazlı anlık arama (Search) özelliği eklendi.
- "Yıldızlama" (Star/Favorite) sistemi eklendi, makaleler SwiftData üzerinden favori olarak işaretlenip "Favoriler" klasöründe listelenebilmekte.

**Aşama 9: YouTube Oynatıcı ve Hata Çözümleri**
- YouTube videolarındaki "Error 153" (OAuth/Navigation) hatasını çözmek için özel `YouTubePlayerView` geliştirildi. Makale URL'leri analiz edilerek YouTube linkleri otomatik olarak bu native sarmalayıcıya yönlendirildi.
- YouTube IFrame API kullanılarak reklamsız ve hafif bir oynatıcı deneyimi sağlandı.

**Aşama 10: Sürüm 1.4.0 - Stabilite ve Güncelleme Onarımı**
- Sürüm 1.3.x sonrası raporlanan "güncelleme sonrası verilerin kaybolması" ve "uygulama başlangıç çökmesi" sorunları, SwiftData şema migrasyonu ve `context` yönetimi iyileştirilerek çözüldü.
- Bildirim izni penceresinin tepki vermeme sorunu `NotificationManager` içindeki async akış düzeltilerek giderildi.
- `release.sh` ve `build_and_deploy.sh` scriptleri ile CI/CD süreci standartlaştırıldı.

---
**Aşama 11: iCloud Senkronizasyonu ve Yedekleme (CloudKit)**
- SwiftData modelleri CloudKit senkronizasyonu için optimize edildi (opsiyonel alanlar ve varsayılan değerler).
- `RSSReaderApp` üzerinde `cloudKitDatabase: .automatic` konfigürasyonu aktif edildi.
- `CloudSettingsManager` sınıfı yazılarak `UserDefaults` verilerinin `NSUbiquitousKeyValueStore` üzerinden tüm cihazlarda senkronize edilmesi sağlandı.