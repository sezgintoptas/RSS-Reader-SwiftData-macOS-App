## 🆕 v1.12.0 — 2026-03-09

### ✨ Yenilikler (OPML & YouTube İyileştirmeleri)
- **OPML Duplikasyon Koruması:** OPML içe aktarırken aynı beslemeleri (URL bazlı) tekrar ekleme sorunu giderildi. Artık mükerrer kayıtlar otomatik atlanıyor.
- **YouTube Reader Mode:** YouTube üzerinden gelen RSS makaleleri artık varsayılan olarak saf okuma modunda (Reader Mode) açılıyor, daha temiz bir deneyim sağlıyor.
- **Email HTML Düzeltmeleri:** Paylaşılan e-postalarda karakterlerin (\&, \<, \>) çift encode (double-encoding) edilme hatası düzeltildi.
- **Arayüz Kararlılığı:** Sidebar ve besleme yönetimi işlemlerindeki kararlılık artırıldı.

## 🆕 v1.11.0 — 2026-03-08

### ✨ Yenilikler (E-posta Paylaşımı İyileştirmeleri)
- Mail gönderme butonu artık makale detay görünümünün toolbar'ında yıldız butonunun yanında konumlanıyor
- Popover açıldığında alıcı listesi UserDefaults'dan doğru okunuyor (boş görünme hatası düzeltildi)
- Mail butonu makale listesi satırından kaldırıldı, daha temiz bir arayüz sağlandı

## 🆕 v1.10.0 — 2026-03-08

### ✨ Yenilikler (E-posta ile Paylaşma)
- Makaleleri e-posta yoluyla arkadaşlarınızla veya kendinize paylaşma özelliği eklendi (Resend API entegrasyonu)
- Ayarlar sayfasına Resend API anahtarı ve alıcı listesi yönetimi eklendi
- Şık ve modern bir HTML e-posta şablonu tasarlandı
- Paylaşılan makale içerikleri artık daha okunabilir ve profesyonel görünüyor

## 🆕 v1.9.0 — 2026-03-08

### ✨ Yenilikler
- CloudKit senkronizasyonunda veri tutarlılığı artırıldı
- Arka plan güncelleme yöneticisi (UpdateManager) daha kararlı hale getirildi
- Makale listesi ve ayarlar arayüzünde ufak iyileştirmeler yapıldı
- Çeşitli hata düzeltmeleri ve performans iyileştirmeleri

## 🆕 v1.8.0 — 2026-03-08

### ✨ Yenilikler
- Yerel Yedekleme ve Geri Yükleme özelliği eklendi
- Kullanıcılar artık verilerini JSON formatında yedekleyebilir
- Yedeklenen veriler ~/Documents/RSSReader Backups/ klasörüne kaydedilir
- Yedek dosyalarından klasörler, beslemeler, favori makaleler ve okuma durumları geri yüklenebilir
- SwiftData ve CloudKit senkronizasyonu için iyileştirmeler yapıldı
- Çeşitli hata düzeltmeleri ve performans iyileştirmeleri

## 🆕 v1.7.0 — 2026-03-08

### ✨ Yenilikler
- YouTube videolarında ileriye sarma hatası düzeltildi
- Önerilen video görselleri artık doğru yükleniyor
- YouTube domain'lerinde content blocker otomatik devre dışı
- YouTube giriş bilgileri kalıcı olarak saklanıyor
- Ayarlar'a YouTube Oturumunu Koru toggle'ı eklendi
- YouTube cookie temizleme butonu eklendi
- YouTube kozmetik reklam gizleme ve skip butonu aktif

## 🆕 v1.6.0 — 2026-03-08

### ✨ Yenilikler
- 
-  
- versiyon güncelleştirmesi

## 🆕 v1.5.1 — Yenilikler

### ✨ Yeni Özellikler
- CloudKit senkronizasyonu sırasında oluşan feed sıralama hataları giderildi.
- İçerik yüklenirken karşılaşılan boş (nil) veri kontrolleri güçlendirildi.
- Arayüzdeki okumamış sayısı (unread count) hesaplaması optimize edildi.

## 🆕 v1.5.0 — iCloud Senkronizasyon ve Yedekleme

### ✨ iCloud & Sync
- **iCloud Senkronizasyonu** — Artık tüm feed'leriniz, klasörleriniz ve makaleleriniz iCloud üzerinden Apple ID'nize yedeklenir. Uygulamayı silseniz bile anında geri gelir.
- **Ayarların Yedeklenmesi** — Uygulama ayarlarınız (reklam engelleyici tercihleri, yenileme aralığı vb.) tüm Mac'leriniz arasında otomatik olarak senkronize edilir.
- **Gelişmiş SwiftData Modelleri** — CloudKit uyumluluğu için veri modelleri optimize edildi.

## 🆕 v1.4.0 — Kritik Düzeltmeler ve İyileştirmeler

### ✨ YouTube ve Stabilite
- **YouTube "Error 153" Çözümü** — macOS OAuth navigasyon hatası nedeniyle YouTube videolarının açılmaması sorunu native IFrame oynatıcı ile kökten çözüldü.
- **Güncelleme Onarımı** — v1.3.x sürümlerinde görülen güncelleme sonrası veritabanı kaybolması ve başlangıçtaki çökme (crash) sorunları giderildi.
- **Bildirim İzni Düzeltmesi** — macOS bildirim izni penceresinin takılması sorunu asenkron izin akışı iyileştirilerek çözüldü.
- **SwiftData Migrasyonu** — Veritabanı şema değişiklikleri artık daha güvenli ve hata durumunda otomatik kurtarma mekanizmasına sahip.

## 🆕 v1.3.0 — Yenilikler

### ✨ Stabilite ve Hata Giderme
- **Crash Koruması & Stabilite** — Xcode üzerinden çalışırken bildirim merkezi kaynaklı kilitlenmeler (crash) ve donmalar (freeze) tamamen giderildi.
- **Kritik Dosya Verifikasyonu** — `SyncEngine`, `BackgroundRefreshManager` ve `NotificationManager` gibi temel sistem dosyaları geri yüklendi ve stabilizesi artırıldı.
- **Bundle ID Kontrolü** — Uygulama paketi dışındaki çalışma modları için akıllı Bundle ID kontrolü eklendi.
- **Performans İyileştirmeleri** — Uygulama açılışı ve arka plan senkronizasyon süreleri optimize edildi.

## 🆕 v1.2.0 — Yenilikler

### ✨ Yeni Özellikler
- **Besleme Bildirimleri** — Yeni makaleler geldiğinde macOS bildirim merkezinden haberdar olun
- **Sağlık Göstergesi** — Hangi beslemelerin aktif, hangilerinin hatalı olduğunu görsel olarak takip edin
- **JSON Feed Desteği** — Modern JSON tabanlı RSS formatları için tam destek
- **Otomatik Periyodik Yenileme** — Uygulama açıkken belirlediğiniz aralıkta (5/10/15/30/60 dk) beslemeler otomatik güncellenir
- **Makale Özet Satırı (Snippet)** — Her makale satırında ilk 300 karakterlik içerik önizlemesi
- **Tümünü Okundu İşaretle** — Toolbar'daki tek butonla tüm makaleleri okundu işaretle

### 🐛 Düzeltmeler
- Besleme başlıkları artık her senkronizasyonda RSS kaynak başlığından güncelleniyor
- Güncelleme sistemi artık gerçek GitHub Releases API'sini kullanıyor (test modu kaldırıldı)

### 💻 Kurulum
1. `RSSReader.app.zip` dosyasını indirin ve açın
2. `RSSReader.app`'i `/Applications` klasörüne taşıyın
3. İlk açılışta sağ tıklayıp **"Aç"** seçin

```bash
# Terminal ile karantinayı kaldırma
xattr -cr /Applications/RSSReader.app
```

**SHA256:** Bkz. `RSSReader.app.zip.sha256`
