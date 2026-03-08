---
description: Xcode derleme hatalarını sistematik olarak analiz edip çözme formülü
---

# 🔧 Xcode Derleme Hatası Çözme Formülü

Kullanıcı Xcode'dan derleme hataları kopyaladığında bu workflow'u takip et.

## Formül: H.A.T.A. (Hata Analizi ve Taktik Aksiyon)

### Adım 1: SINIFLANDIR — Hata Tipini Belirle
Kullanıcıdan gelen hata mesajını analiz et ve aşağıdaki kategorilerden birine ata:

| Kategori | Anahtar Kelimeler | Öncelik |
|----------|-------------------|---------|
| 🔴 **Tip Hatası** | `cannot convert`, `type mismatch`, `expected type`, `cannot assign` | Yüksek |
| 🟠 **Eksik Referans** | `undeclared`, `cannot find in scope`, `use of unresolved identifier` | Yüksek |
| 🟡 **Protokol/Uyumsuzluk** | `does not conform`, `missing required`, `protocol requirement` | Orta |
| 🔵 **SwiftUI Görünüm** | `opaque return type`, `ViewBuilder`, `some View`, `body` | Orta |
| 🟣 **SwiftData/Model** | `@Model`, `@Query`, `PersistentModel`, `migration`, `schema` | Yüksek |
| ⚪ **Bağımlılık** | `no such module`, `missing package`, `dependency`, `FeedKit`, `SwiftSoup` | Düşük |
| 🟤 **Ambiguity** | `ambiguous`, `multiple matches`, `overloaded` | Orta |
| ⚫ **Linker/Build** | `linking`, `duplicate symbol`, `undefined symbol`, `architecture` | Düşük |

### Adım 2: LOKASYONU BUL — Hatanın Kaynak Dosyasını Aç
// turbo
1. Xcode hata mesajındaki dosya adını ve satır numarasını çıkar
2. İlgili dosyayı `view_file` ile aç (hata satırı ±20 satır genişliğinde)
3. Eğer hata birden fazla dosyayı etkiliyorsa, hepsini paralel olarak oku

```
Dosya yapısı referansı:
├── Sources/RSSReader/
│   ├── Models/          → Veri modelleri (ItemModels.swift, ReadingMode.swift)
│   ├── Views/           → UI bileşenleri (ContentView, SettingsView, vb.)
│   ├── Utils/           → Yardımcı sınıflar (Managers, Parsers)
│   └── RSSReaderApp.swift → Ana giriş noktası
├── Package.swift        → Bağımlılıklar ve yapılandırma
```

### Adım 3: KÖK NEDEN ANALİZİ — Neden Böyle Oldu?
Her hata için şu soruları sor:

1. **Bu hata tek başına mı, yoksa zincirleme mi?**
   - Xcode bazen 1 hatadan 10+ hata üretir. İLK hatayı çözmek diğerlerini ortadan kaldırır.
   - Kural: En düşük satır numaralı hatadan başla.

2. **Son değişiklik ne idi?**
   - `git diff` ile son değişiklikleri kontrol et
   - Yeni eklenen veya değiştirilen dosyaları belirle

3. **API değişikliği mi var?**
   - SwiftUI/SwiftData API'leri macOS sürümlerine göre değişir
   - `Package.swift` → `.macOS(.v14)` platformunu kontrol et

### Adım 4: ÇÖZÜMÜ UYGULA — Kategori Bazlı Çözüm Şablonları

#### 🔴 Tip Hatası Çözümleri:
```swift
// Sorun: cannot convert value of type 'X' to expected argument type 'Y'
// Çözüm 1: Açık tip dönüşümü ekle
let value = someValue as? TargetType

// Çözüm 2: Optional unwrap
if let value = optionalValue { ... }

// Çözüm 3: Binding dönüşümü (SwiftUI)
Binding(get: { value }, set: { newValue in ... })
```

#### 🟠 Eksik Referans Çözümleri:
```swift
// Sorun: cannot find 'X' in scope
// Kontrol listesi:
// 1. import eksik mi? → import SwiftUI / import SwiftData / import FeedKit
// 2. Dosya doğru target'a ekli mi?
// 3. Değişken/fonksiyon adı doğru mu? (büyük/küçük harf)
// 4. Erişim seviyesi (private/internal/public) uygun mu?
```

#### 🟡 Protokol Uyumsuzluğu Çözümleri:
```swift
// Sorun: Type 'X' does not conform to protocol 'Y'
// Çözüm: Eksik protokol gereksinimlerini ekle
// 1. view_code_item ile sınıfı görüntüle
// 2. Protokolün gerektirdiği method/property'leri belirle
// 3. Eksik implementasyonları ekle
```

#### 🔵 SwiftUI Görünüm Hataları:
```swift
// Sorun: "Function declares an opaque return type..."
// Çözüm: body içinde tek bir kök View döndüğünden emin ol
var body: some View {
    // ❌ if/else olmadan iki ayrı view döndürmek
    // ✅ Group, VStack, veya @ViewBuilder kullan
    Group {
        if condition {
            ViewA()
        } else {
            ViewB()
        }
    }
}
```

#### 🟣 SwiftData Hataları:
```swift
// Sorun: Migration veya schema hataları
// Çözüm dizisi:
// 1. @Model sınıfındaki property'leri kontrol et
// 2. @Attribute(.unique) çakışması var mı?
// 3. Yeni property'ye varsayılan değer atandı mı?
// 4. Gerekirse migration planı oluştur veya DB'yi yeniden oluştur
```

#### ⚪ Bağımlılık Hataları:
```bash
# Sorun: No such module 'FeedKit'
# Çözüm:
swift package resolve
swift package update
swift build
# Package.swift'teki bağımlılık URL ve sürüm kontrolü
```

### Adım 5: DOĞRULA — Düzeltmeyi Test Et
// turbo
1. Değişiklik sonrası derleme:
```bash
cd "/Users/gengreener/Desktop/RSS Projem" && swift build 2>&1 | head -50
```
2. Hata devam ediyorsa Adım 1'e dön
3. Başarılı ise çalıştırma testi:
```bash
swift run
```

---

## 🎯 Hızlı Referans: Sık Karşılaşılan Hatalar

### Bu Projede Bilinen Riskli Alanlar:
| Dosya | Risk | Açıklama |
|-------|------|----------|
| `ItemModels.swift` | 🟣 SwiftData | Model değişiklikleri migration gerektirebilir |
| `ContentView.swift` | 🔵 SwiftUI | Karmaşık NavigationSplitView yapısı |
| `SettingsView.swift` | 🔵 SwiftUI | Binding'ler ve @AppStorage kullanımı |
| `InAppWebView.swift` | 🔴 Tip | WKWebView coordinator ile SwiftUI köprüsü |
| `ContentBlockerManager.swift` | 🟠 API | WKContentRuleList async API |
| `SyncEngine.swift` | 🟣 SwiftData | CloudKit + SwiftData entegrasyonu |
| `UpdateManager.swift` | 🟠 Referans | GitHub API ve dış bağımlılıklar |

### Kullanım:
Kullanıcı hata kopyaladığında:
1. Hatayı yukarıdaki tabloyla eşleştir
2. İlgili dosyayı aç ve hata satırını incele
3. Çözüm şablonunu uygula
4. `swift build` ile doğrula
