# iGet — Ürün ve Geliştirme Planı
**Ekip:** Emirhan × Zeynep  
**Lisans:** MIT  
**Tarih:** Kasım 2026 (Ekip İçi Blueprint)  
**Platform:** macOS 14.0+ (Sonoma) · Swift 5.9 · SwiftUI · WidgetKit  
**App Group:** `group.com.twobitdev.iGet`  

---

## 1. Ürün Vizyonu ve Yaklaşımı

Hedef: Çok sayıda küçük araçtan önce, masaüstünde tutarlı bir deneyim ve sağlam widget altyapısı kurmak.

- **Quiet by Design:** Yalnızca etkin veri sağlayıcıları çalışır. Düşük güç modu örneklemeyi azaltır.
- **Small but Coherent:** Ortak tasarım sistemi; her widget 3 boyutta (Small, Medium, Large) doğrulanır; tema değişimi mat ve tutarlı kalır.
- **Safe Sharing:** Sürümlü JSON tema/paketleri. Harici kod/script çalıştırılmaz.
- **One-click Spaces:** Uygulama içi profiller (Study, Developer, Daily) ile tek tıkla görünüm ve tema geçişi.

---

## 2. Sürüm ve Öncelik Matrisi

| Sürüm | Faz | Kapsam | Odak |
|---|---|---|---|
| **P0 · MVP** | **01 Widget Library** | Clock, Countdown, Tasks, Focus, Widget Galerisi, Ayarlar, Tema Seçimi, WidgetKit Entegrasyonu, CI | 4 temel widget, yerel veri, sıfır harici hesap |
| **P1 · v0.2** | **02 Widget Studio** | Parametrik şablon editörü, tema özelleştirme, içe/dışa JSON aktarımı, Notes, Calendar, Habits, Battery | Kodsuz özelleştirme & günlük araçlar |
| **P1 · v0.3** | **03 Spaces** | Study, Developer ve Daily uygulama içi profilleri, Menü Çubuğu hızlı profil geçişi | Kişiselleştirilmiş çalışma ortamları |
| **P2 · v0.4** | **04 Live Layer** | NSPanel/NSWindow canlı masaüstü katmanı, canlı CPU/RAM/pil metrikleri, konum hatırlama | İsteğe bağlı masaüstü overlay pencereleri |
| **P2 · İleri** | **05 Ekosistem** | GitHub katkı haritası, WeatherKit entegrasyonu, hızlı başlatıcı (Launcher) | Servis sözleşmeleri doğrulanmış harici kaynaklar |

---

## 3. Dosya Sahipliği ve İş Bölümü

| Sahip | Klasör / Modül | Sorumluluk |
|---|---|---|
| **Emirhan** | `Packages/iGetCore/**`<br>`Packages/iGetData/**`<br>`App/Integration/**` | Model, veri saklama, provider sözleşmeleri, fixtures, wiring |
| **Emirhan** | `Features/Tasks/**`, `Features/Focus/**`<br>`Widgets/Tasks/**`, `Widgets/Focus/**` | Görev ve odak sayacı iş mantığı, App Intent'ler, WidgetKit görünümleri |
| **Emirhan** | `iGet.xcodeproj/**`, `Config/**`, `.github/**`, `Tests/Core/**` | Proje ayarları, target/entitlements, CI/CD, mimari testleri |
| **Zeynep** | `Packages/iGetDesign/**`<br>`App/Shell/**`, `App/Screens/**`, `App/Assets/**` | Tasarım sistemi (ThemeTokens, WidgetCard), Navigasyon, Galeri, Studio, Spaces ekranları |
| **Zeynep** | `Features/Clock/**`, `Features/Countdown/**`<br>`Widgets/Clock/**`, `Widgets/Countdown/**` | Saat ve geri sayım özellikleri, yerel hesaplamalar, 3 boyutlu widget görünümleri |
| **Zeynep** | `Tests/UI/**`, `docs/design/**` | Arayüz smoke testleri, erişilebilirlik (VoiceOver, Dynamic Type), tasarım dokümantasyonu |
| **Tek Entegratör: Emirhan** | `App/iGetApp.swift`, `Widgets/iGetWidgetBundle.swift`, `Package.swift` | Merkezi kayıt noktaları ve bağımlılık listesi (Zeynep PR/issue ile değişiklik talep eder) |

---

## 4. Repo Yapısı

```text
iGet/
├── App/
│   ├── iGetApp.swift                     [Emirhan - Entegratör]
│   ├── Integration/                      [Emirhan]
│   ├── Shell/                            [Zeynep] -> Ana pencere, sidebar, toolbar
│   ├── Screens/                          [Zeynep]
│   │   ├── Gallery/                      -> Widget keşfi, arama, filtreleme, detay
│   │   ├── Studio/                       -> Parametrik stil & tema önizleme
│   │   ├── Spaces/                       -> Study, Developer, Daily profil yönetimi
│   │   └── Settings/                     -> Görünüm, güç modu, izinler
│   └── Assets/                           [Zeynep] -> Vektör ikonlar ve renk katalogları
├── Packages/
│   ├── iGetCore/                         [Emirhan] -> Contracts, WidgetConfig, Protocols
│   ├── iGetData/                         [Emirhan] -> SQLite / App Group Store, Providers
│   └── iGetDesign/                       [Zeynep]  -> ThemeTokens (Sage, Paper, Lilac, Slate), WidgetCard
├── Features/
│   ├── Tasks/ , Focus/                   [Emirhan]
│   └── Clock/ , Countdown/               [Zeynep]
├── Widgets/
│   ├── iGetWidgetBundle.swift            [Emirhan - Entegratör]
│   ├── Tasks/ , Focus/                   [Emirhan]
│   └── Clock/ , Countdown/               [Zeynep]
├── Tests/
│   ├── Core/                             [Emirhan]
│   └── UI/                               [Zeynep]
├── Config/ & .github/                    [Emirhan] -> CODEOWNERS, CI
└── docs/design/                          [Zeynep]  -> Konsept rehberleri ve tasarım notları
```

---

## 5. Tasarım Sistemi (`iGetDesign`)

Görsel dil: Mat renkler, sakin tipografi, küçük köşe yarıçapı, yeterli kontrast. Dekoratif 3D veya parlama/neon kullanılmaz.

### Temel Renk Paletleri (Küratörlü Önayarlar):
1. **Sage (Adaçayı):** Doğal, dinlendirici yeşil tonlar (`#E2E8DE` arka plan / `#3A5A40` vurgu)
2. **Paper (Kağıt):** Sıcak nötr bej (`#F4EFE6` arka plan / `#4A4036` vurgu)
3. **Lilac (Leylak):** Yumuşak pastel mor (`#EAE4F2` arka plan / `#5B4B70` vurgu)
4. **Slate (Arduvaz):** Dengeli açık gri-mavi (`#E2E7EC` arka plan / `#3E4C59` vurgu)

---

## 6. Altı Haftalık Sprint Yol Haritası

| Sprint | Emirhan | Zeynep | Çıkış Kriteri |
|---|---|---|---|
| **0 / Kurulum** | Core sözleşmesi, Xcode target'ları, CI, App Group, Fixtures | Tasarım token'ları, shell, galeri mockup'ı | Boş app + extension build; ortak API onayı |
| **1 / Temel Widget** | Tasks CRUD ve store; Focus model başlangıcı | Clock + Countdown yerel görünümleri | Clock & Countdown gerçek cihazda görünür |
| **2 / İşlevler** | Focus oturumu, App Intents, reload, task testleri | Galeri, detay, ayar, hata/boş durum ekranları | 4 widget çalışır; app restart sonrası veri korunur |
| **3 / Tasarım** | Native wiring, snapshot ve migration testleri | Tema önayarları, erişilebilirlik, Light/Dark mod | Tema/snapshot uyumu, UI smoke test |
| **4 / QA** | CI, Instruments, enerji/CPU ölçümü, imzalama denemesi | UI testleri, farklı boyut ve çözünürlük testleri | Crash-free smoke test; performans raporu |
| **5 / Alpha** | Entegrasyon, geri bildirim, release adayı | Polish, kullanıcı rehberi, onboarding | İki tarafın onayladığı v0.1 alpha |

---

## 7. İlk 8 GitHub Issue'su

- `#01 E · Core foundation:` `Contracts.swift`, `Store.swift`, `PreviewFixtures.swift`
- `#02 Z · Design tokens:` `iGetDesign/ThemeTokens.swift`, `WidgetCard.swift`
- `#03 E · Tasks:` `Features/Tasks`, `Widgets/Tasks`
- `#04 Z · Clock:` `Features/Clock`, `Widgets/Clock`
- `#05 E · Focus:` `Features/Focus`, `Widgets/Focus`
- `#06 Z · Countdown:` `Features/Countdown`, `Widgets/Countdown`
- `#07 Z · Shell/Gallery:` `App/Shell`, `App/Screens/Gallery`
- `#08 E · Integration:` `App/Integration`, `WidgetBundle`, `Config`, `CI`
