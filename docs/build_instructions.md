# Terminal Üzerinden Uygulamayı Derleme ve Çalıştırma Kılavuzu

Projenizi Xcode açmadan, doğrudan terminal (komut satırı) üzerinden derleyip çalıştırmak için **Swift Package Manager (SPM)** araçlarını kullanabilirsiniz. Proje kök dizininde yer alan `Package.swift` dosyası, uygulamanızı bir yürütülebilir paket (executable) olarak tanımlar ve `FeedKit` bağımlılığını otomatik olarak indirir.

Aşağıdaki adımları sırasıyla terminal üzerinde uygulayabilirsiniz:

## 1. Proje Dizinine Gitme
Öncelikle Terminal uygulamasını açın ve projenizin bulunduğu klasöre gidin:

```bash
cd "/Users/gengreener/Desktop/RSS Projem"
```

## 2. Uygulamayı Derleme (Build)
Uygulamanızı sadece derlemek (kodlarda hata olup olmadığını kontrol etmek veya bağımlılıkları indirmek) için aşağıdaki komutu kullanın:

```bash
swift build
```
*Bu komut işlemi sırasında Swift, önce `FeedKit` kütüphanesini GitHub üzerinden indirecek ardından tüm `.swift` dosyalarınızı derleyecektir.*

## 3. Uygulamayı Çalıştırma (Run)
Uygulamanızı derleyip hemen ardından macOS üzerinde başlatmak (çalıştırmak) için şu komutu kullanın:

```bash
swift run
```
*Bu komutu girdiğinizde uygulama yerel macOS penceresi ile açılacaktır. Terminal ekranında uygulamanın konsol çıktılarını (`print` log'larını) anlık olarak görebilirsiniz.*

---

### Ek İpuçları
- **Release (Yayın) Modunda Derlemek:** Eğer uygulamayı en yüksek performansla, optimize edilmiş şekilde derlemek isterseniz yapılandırma (configuration) belirtebilirsiniz:
  ```bash
  swift build -c release
  ```

- **Xcode Projesi Olarak Açmak:** Klasörü terminal yerine MacOS Finder üzerinden standart olarak **Xcode** ile açabilirsiniz:
  ```bash
  open Package.swift
  ```
  *(Bu komut projeyi Xcode IDE üzerinde açar ve orada "Play" butonuna basarak da uygulamayı test edebilirsiniz.)*

## 4. Yayınlama ve Dağıtım (Release & Deployment)
Uygulamanın GitHub üzerinde yayınlanması ve paketlenmesi için hazırlanan scriptleri kullanabilirsiniz:

- **scripts/release.sh:** Sürüm numarasını (`AppVersion.swift`) günceller, release notlarını hazırlar, git tag oluşturur ve GitHub'a push eder. GitHub Actions otomatik olarak build ve release sürecini başlatır.
  ```bash
  bash scripts/release.sh
  ```

- **scripts/build_and_deploy.sh:** Uygulamayı lokal olarak derleyip `/Applications` klasörüne kurar ve başlatır.
  ```bash
  bash scripts/build_and_deploy.sh
  ```

*Not: GitHub Actions, public repo'larda ücretsizdir. `v*` formatında tag push'landığında otomatik build başlar.*
