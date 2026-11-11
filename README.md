# TNB KEP — macOS'ta e-imza ile giriş

TNB KEP'e (`kep.hs02.kep.tr`) **Mac + Chrome** üzerinden e-imza ile giriş yapabilmek için gayriresmi kurulum betiği. E-Tuğra kartı/tokenı ile denenmiştir.

> **Gayriresmidir.** Bu depo TNB Teknoloji, E-Tuğra veya AET Europe ile bağlantılı değildir ve onlar tarafından desteklenmez. Kullanmadan önce [Sorumluluk reddi](#sorumluluk-reddi-ve-yasal-bildirim) bölümünü okuyun.

## Sorun ne?

KEP sitesinde "sertifika seç" dediğinizde hiçbir şey olmuyorsa nedeni şudur: site, bilgisayarınızda çalışan küçük bir imza uygulamasıyla konuşmak ister ve TNB bu uygulamayı yalnızca Windows için (`TNBTeknolojiImza.exe`) dağıtır. Mac için bir kurulum paketi yoktur.

Oysa o Windows paketinin içindeki asıl uygulama saf Java'dır ve macOS'u düşünerek yazılmıştır; eksik olan yalnızca Mac kurulumudur. Bu betik o eksik kurulumu yapar.

## Kimler kullanabilir?

| Durum | Sonuç |
|---|---|
| E-Tuğra kartı/tokenı (SafeSign sürücüsü) | Denendi, çalışıyor |
| SafeNet eToken (`libeTPkcs11.dylib`) | Uygulama bu sürücüyü de arıyor; denenmedi |
| AKİS kartı (Kamu SM vb.) | **Çalışmaz** — aşağıdaki alternatife bakın |

Gereksinimler:

- macOS (Apple Silicon ya da Intel). Apple Silicon'da **Rosetta** gerekir.
- Google Chrome ve [TNB Teknoloji Elektronik İmza](https://chromewebstore.google.com/detail/tnb-teknoloji-elektronik/ppgjmopocehhllbjblnpdajkkkfghpan) eklentisi.
- Aktivasyonu yapılmış, PIN'i belirlenmiş bir e-imza. (E-Tuğra'ya göre ilk aktivasyon ve PIN belirleme yalnızca Windows'ta yapılabiliyor.)

### Alternatif: Rosetta'sız, AKİS destekli port

[saidsurucu/tnb-eimza-mac-arm64](https://github.com/saidsurucu/tnb-eimza-mac-arm64) aynı sorunu farklı bir yoldan çözer: uygulamayı yamalayıp Apple Silicon için yerel (arm64) bir `.app` olarak derler ve AKİS kartlarını destekler. AKİS kartınız varsa ya da Rosetta kullanmak istemiyorsanız ona bakın.

Bu deponun farkı: TNB'nin uygulamasını **değiştirmeden** çalıştırır, derleme araçları (Xcode) istemez ve E-Tuğra sürücüsünü de kendisi kurar.

## Kurulum

Terminal'i açın ve şunları çalıştırın:

```bash
git clone https://github.com/yusufcetin82/tnb-kep-mac-eimza.git
cd tnb-kep-mac-eimza
./install.sh
```

`git` yoksa:

```bash
curl -L https://github.com/yusufcetin82/tnb-kep-mac-eimza/archive/refs/heads/main.zip -o tnb-kep.zip
unzip tnb-kep.zip && cd tnb-kep-mac-eimza-main
./install.sh
```

Apple Silicon Mac'te Rosetta kurulu değilse betik durur ve şu komutu ister:

```bash
softwareupdate --install-rosetta --agree-to-license
```

Kurulumdan sonra:

1. Kartınızı/tokenınızı takın.
2. `./test.sh` ile kartın okunduğunu sınayın (PIN sorulmaz, bir şey imzalanmaz).
3. Chrome'da KEP sayfasını yenileyin ve e-imza ile giriş yapın.

Betik `sudo` istemez ve yönetici parolası sormaz.

## Betik tam olarak ne yapıyor?

Çalıştırmadan önce [`install.sh`](install.sh) dosyasını okumanızı öneririm; kısa ve açıklamalıdır. Özetle:

| Adım | Kaynak | Nereye |
|---|---|---|
| TNB imza uygulaması (`TNBTeknolojiImza.jar`) | `kep.hs02.kep.tr` — TNB'nin kendi Windows paketinden çıkarılır | `~/Library/TNBTeknolojiImza/` |
| Java 8 çalışma ortamı (Intel) | Eclipse Temurin, `api.adoptium.net` | `~/Library/TNBTeknolojiImza/jre/` |
| E-Tuğra kart sürücüsü (SafeSign) | `e-tugra.com.tr` | `/Applications/tokenadmin.app` |
| Chrome bağlantısı | betik yazar | `~/Library/Application Support/Google/Chrome/NativeMessagingHosts/tnbtimzahost.json` |

Ek olarak:

- Windows paketini açmak için 7-Zip gerekir. Bilgisayarınızda yoksa `7-zip.org` adresinden geçici olarak indirilir ve kurulum bitince silinir.
- İndirilen TNB uygulamasının SHA-256 özeti, bu betiğin denendiği sürümle karşılaştırılır. Farklıysa uyarır ve devam etmek isteyip istemediğinizi sorar.
- SafeSign kurulmadan önce Apple imzası ve yayımcısı (AET Europe B.V.) doğrulanır; uymuyorsa kurulmaz.
- Sistem genelinde Java kurulmaz; indirilen Java yalnızca bu klasörün içinde durur.

**Bu depoda TNB'ye, E-Tuğra'ya ya da AET'ye ait hiçbir dosya yoktur.** Hepsi kurulum sırasında kendi resmi adreslerinden indirilir.

## Nasıl çalışıyor?

```
KEP sayfası  →  Chrome eklentisi  →  tnbtimza-host.sh  →  Java (TNBTeknolojiImza.jar)  →  SafeSign sürücüsü  →  kart
```

Windows'ta bu zinciri TNB'nin kurulum paketi kurar. Mac'te üç engel vardı:

1. **Kurulum paketi yok.** Chrome'un uygulamayı bulabilmesi için gereken tanım dosyası ve başlatıcı Windows'a özel (`.bat`, kayıt defteri). Betik bunların macOS karşılıklarını yazar.
2. **Yerel kütüphane yalnızca Intel.** Uygulamanın karta erişmek için kullandığı `libpkcs11wrapper.jnilib` içinde Apple Silicon (arm64) kodu yok. Bu yüzden Intel Java 8, Rosetta üzerinden kullanılır.
3. **Gatekeeper engeli.** Uygulama bu kütüphaneyi her çalışmada geçici bir dosyaya çıkarıp oradan yükler. Chrome'un başlattığı işlemlerin oluşturduğu dosyaları macOS karantinaya aldığı için şu uyarı çıkar:

   > Apple, "SignArtAppletPkcs11Wrap….tmp" öğesinin Mac'inize zarar verebilecek veya gizliliğinizi ihlal edebilecek bir kötü amaçlı yazılım içermediğini doğrulayamadı.

   Çözüm: küçük bir başlatıcı (`launcher.js`) kütüphaneyi önce sabit, karantinasız bir konumdan yükler. Kütüphane bir kez yüklenince uygulama geçici kopyayı yüklemeyi atlar. Gatekeeper kapatılmaz, hiçbir güvenlik ayarı değiştirilmez.

## Sorun giderme

**"Sertifika seç" deyince hiçbir şey olmuyor**
- Chrome eklentisinin kurulu ve etkin olduğuna bakın (`chrome://extensions`).
- Chrome'u tamamen kapatıp (Cmd+Q) yeniden açın.
- Sertifika penceresi Chrome'un arkasında kalmış olabilir; Dock'ta beliren Java simgesine tıklayın.

**Sertifika listesi boş / kart bulunamadı**
- `./test.sh` çalıştırın. Kartın sistemce görülüp görülmediğini şu komut gösterir:
  ```bash
  system_profiler SPSmartCardsDataType
  ```
  "Readers" altında okuyucunuz ve bir ATR değeri görünmelidir.
- AKİS kartı kullanıyorsanız bu betik işe yaramaz; yukarıdaki alternatife bakın.

**Gatekeeper uyarısı çıkıyor**
- Kurulumu yeniden çalıştırın (`./install.sh`). Açık kalmış uyarı penceresinde "Çöp Sepetine Taşı" demeyin, "Bitti" deyin.

**Günlük dosyaları**
- `~/TnbTeknolojiImza.log` ve `~/TnbTeknolojiImza.err.log` — uygulamanın kendi günlükleri; hatanın nedeni burada yazar.

Günlükleri ya da `test.sh` çıktısını bir yerde paylaşmadan önce içinde adınızın ve sertifikanızın bulunabileceğini unutmayın.

## Kaldırma

```bash
./uninstall.sh                   # imza uygulaması, Java ve Chrome tanımı
./uninstall.sh --with-safesign   # ayrıca SafeSign (tokenadmin.app)
```

## Güvenlik notları

- Betik PIN'inize hiçbir şekilde dokunmaz. PIN'i yalnızca TNB'nin kendi uygulamasının açtığı pencereye girersiniz.
- İmzalama, TNB'nin değiştirilmemiş uygulaması ve E-Tuğra'nın kendi sürücüsü tarafından yapılır; bu depo yalnızca onları Mac'te başlatır.
- İnternetten indirdiğiniz her betikte olduğu gibi, çalıştırmadan önce içeriğini okuyun.
- E-imza, ıslak imzayla aynı hukuki sonucu doğurur. Uzaktan destek alırken PIN'inizi kimseye söylemeyin, ekranınız paylaşılırken girmeyin.

## Bilinen sınırlar

- **Rosetta'ya bağlıdır.** Apple, Rosetta'yı ileride kaldırdığında bu yöntem Apple Silicon'da çalışmaz.
- **TNB tarafındaki değişiklikler bozabilir.** Site, eklenti ya da imza uygulaması güncellenirse yeniden uyarlama gerekebilir.
- Yalnızca Google Chrome için tanım yazar. Diğer Chromium tabanlı tarayıcılar denenmedi.
- Java 8 eski bir sürümdür; burada yalnızca bu uygulamayı çalıştırmak için, sistemin geri kalanından ayrı tutulur.

## Sorumluluk reddi ve yasal bildirim

Bu bölüm bir hukuki danışmanlık değildir; deponun hangi koşullarla paylaşıldığını açıklar.

- **Garanti yoktur.** Bu depodaki betikler "olduğu gibi" sunulur. Çalışacağına, belirli bir amaca uygun olduğuna, hatasız ya da kesintisiz olduğuna dair açık veya örtülü hiçbir garanti verilmez.
- **Sorumluluk kabul edilmez.** Betiklerin kullanılmasından ya da kullanılamamasından doğabilecek doğrudan veya dolaylı hiçbir zarardan — veri kaybı, kartın/tokenın kilitlenmesi, hatalı ya da istenmeyen imza, kaçırılan süreler, hukuki ya da mali sonuçlar dahil — depo sahibi ve katkıda bulunanlar sorumlu tutulamaz. Kullanım tümüyle kendi sorumluluğunuzdadır.
- **Resmi bir ürün değildir.** Bu depo TNB Teknoloji, E-Tuğra EBG A.Ş., AET Europe B.V., Eclipse Adoptium, 7-Zip ya da Google ile bağlantılı, onlar tarafından onaylanmış veya desteklenen bir ürün değildir. Bu kuruluşlar bu kurulumla ilgili destek vermek zorunda değildir.
- **Üçüncü taraf yazılımlar.** `TNBTeknolojiImza.jar`, SafeSign, Java çalışma ortamı ve 7-Zip bu depoda yer almaz ve yeniden dağıtılmaz; kurulum sırasında kendi yayımcılarının adreslerinden indirilir. Bu yazılımların kullanımı kendi lisans ve kullanım koşullarına tabidir; bu koşullara uymak kullanıcının sorumluluğundadır.
- **Markalar.** Anılan tüm ürün ve şirket adları ilgili sahiplerinin markalarıdır; yalnızca neyle uyumlu olduğunu belirtmek için kullanılmıştır.
- **Elektronik imzanın sorumluluğu sizdedir.** 5070 sayılı Elektronik İmza Kanunu uyarınca güvenli elektronik imza, elle atılan imzayla aynı hukuki sonucu doğurur. İmza oluşturma aracınızı ve PIN'inizi korumak, neyi imzaladığınızı denetlemek sizin yükümlülüğünüzdür.
- **Kurumsal kullanım.** Bir kurum bilgisayarında ya da kurum adına kullanacaksanız, kurumunuzun bilgi güvenliği kurallarına uygunluğunu önceden kendiniz doğrulayın.

Betiklerin lisansı [MIT](LICENSE)'tir; lisans metnindeki garanti ve sorumluluk reddi hükümleri de geçerlidir.

## Katkı

Farklı bir kartla denediyseniz ya da bir şey bozulduysa issue açın; kart türünü, macOS sürümünü ve (kişisel bilgileri çıkararak) günlükteki hata satırını ekleyin.

---

**English summary:** Unofficial installer that makes e-signature login to TNB KEP (`kep.hs02.kep.tr`, a Turkish registered e-mail provider) work on macOS + Chrome. The vendor only ships a Windows installer; this script downloads the vendor's own Java signing app, an x64 Java 8 runtime and the E-Tuğra SafeSign PKCS#11 driver from their official sources and wires them up as a Chrome native messaging host. No vendor binaries are redistributed here. Provided as is, without warranty; not affiliated with any of the vendors.
