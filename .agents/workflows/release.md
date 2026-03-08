---
description: Uygulamayı GitHub'a build & release etme workflow'u
---

# 🚀 Build & Release Workflow

Bu workflow ile uygulamanızı sürümleyip GitHub'a release edebilirsiniz.
GitHub Actions **public repo'lar için ücretsizdir** (ayda 2000 dakika).

## Adımlar

// turbo-all

### 1. Mevcut durumu kontrol et
```bash
cd "/Users/gengreener/Desktop/RSS Projem" && echo "📌 Kod sürümü: $(grep -o '"[0-9]*\.[0-9]*\.[0-9]*"' Sources/RSSReader/Utils/AppVersion.swift | head -1)" && echo "📌 Git tag: $(git tag -l 'v*' | sort -V | tail -1)" && git status --short
```

### 2. Değişiklikleri commit et (varsa)
Eğer adım 1'de uncommitted değişiklikler görünüyorsa:
```bash
cd "/Users/gengreener/Desktop/RSS Projem" && git add -A && git commit -m "chore: release öncesi değişiklikler" && git push origin main
```

### 3. Release (AI-Dostu / Manuel Yöntem)
Script interaktif olduğu için AI agent'lar aşağıdaki adımları sırayla manuel yapmalıdır:

1. **Sürümü Güncelle**: `Sources/RSSReader/Utils/AppVersion.swift` dosyasındaki `current` değerini yeni sürüme (örn: `1.8.0`) ayarla.
2. **Notları Hazırla**: `docs/RELEASE_NOTES.md` dosyasının en başına yeni sürüm notlarını ekle.
3. **Commit & Tag**:
```bash
cd "/Users/gengreener/Desktop/RSS Projem" && git add Sources/RSSReader/Utils/AppVersion.swift docs/RELEASE_NOTES.md && git commit -m "release: v1.8.0" && git tag v1.8.0 && git push origin main && git push origin v1.8.0
```

### 4. Release Script (İnsan İçin)
Eğer bir insan çalıştırıyorsa interaktif script kullanılabilir:
```bash
bash "/Users/gengreener/Desktop/RSS Projem/scripts/release.sh"
```

### 5. GitHub Actions build'i takip et
Script veya manuel push sonrası Actions linkini açın:
```bash
open "https://github.com/sezgintoptas/RSS-Reader-SwiftData-macOS-App/actions"
```

### 6. (Opsiyonel) Lokal build & test
```bash
bash "/Users/gengreener/Desktop/RSS Projem/scripts/build_and_deploy.sh"
```

---

## 📁 Dosya Yapısı

```
RSS Projem/
├── docs/                    ← Dokümantasyon
│   ├── RELEASE_NOTES.md
│   ├── readme.md
│   ├── progress.md
│   └── build_instructions.md
├── scripts/                 ← Otomasyon scriptleri
│   ├── release.sh           ← Sürüm + tag + push
│   └── build_and_deploy.sh  ← Lokal build + install
├── .github/workflows/
│   └── build-release.yml    ← GitHub Actions CI/CD
└── Sources/                 ← Uygulama kaynak kodu
```

## 💰 Maliyet
- ✅ **Ücretsiz** — Public repo'larda GitHub Actions tamamen ücretsiz
- Her build ~2-3 dakika macOS runner kullanır
- Eski release'ler otomatik temizlenir (son 3 kalır)
