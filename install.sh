#!/bin/bash
#
# TNB KEP (kep.hs02.kep.tr) e-imza girişi için macOS kurulum betiği.
#
# TNB Teknoloji imza bileşenini yalnızca Windows için dağıtıyor. Bu betik aynı
# bileşeni (Java uygulaması) resmi adresinden indirip macOS + Chrome üzerinde
# çalışacak şekilde kurar. Gayriresmidir; TNB Teknoloji veya E-Tuğra ile bir
# bağı yoktur.
#
# Yaptıkları (hepsi kullanıcı hesabınızın içinde, sudo istemez):
#   1. TNBTeknolojiImza.exe dosyasını kep.hs02.kep.tr adresinden indirir,
#      içinden TNBTeknolojiImza.jar dosyasını çıkarır.
#   2. Intel (x64) Java 8 çalışma ortamını (Eclipse Temurin) indirir.
#   3. E-Tuğra'nın SafeSign kart sürücüsünü e-tugra.com.tr adresinden indirir,
#      Apple imzasını doğrular ve /Applications/tokenadmin.app olarak kurar.
#   4. Chrome'un imza uygulamasını bulabilmesi için native messaging tanımını yazar.
#
# Kullanım:
#   ./install.sh              Kurulum
#   ./install.sh --yes        Sorulara otomatik "evet" der
#   ./install.sh --no-safesign  SafeSign kurulumunu atlar (başka sürücü kullananlar için)
#
set -euo pipefail

INSTALL_DIR="${TNBT_INSTALL_DIR:-$HOME/Library/TNBTeknolojiImza}"
CHROME_NMH_DIR="$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"
SAFESIGN_APP="/Applications/tokenadmin.app"

TNB_EXE_URL="https://kep.hs02.kep.tr/TNBTeknolojiImza.exe"
JRE_URL="https://api.adoptium.net/v3/binary/latest/8/ga/mac/x64/jre/hotspot/normal/eclipse"
SAFESIGN_URL="https://e-tugra.com.tr/portals/6/downloads/MacOS-Safesign.rar"
SEVENZIP_URL="https://www.7-zip.org/a/7z2501-mac.tar.xz"
EXTENSION_ID="ppgjmopocehhllbjblnpdajkkkfghpan"
EXTENSION_URL="https://chromewebstore.google.com/detail/tnb-teknoloji-elektronik/$EXTENSION_ID"

# Bu betiğin denendiği TNBTeknolojiImza.jar sürümü (Nisan 2024 tarihli).
KNOWN_JAR_SHA256="8323ac99c92a8fb4c6fb29384dbb6904d3d8141df7d01ec151bfff8dc8f2edc9"
# SafeSign'ı yayımlayan AET Europe'un Apple geliştirici kimliği.
SAFESIGN_TEAM_ID="9UT52UVZVY"

ASSUME_YES=0
WITH_SAFESIGN=1
for arg in "$@"; do
  case "$arg" in
    -y|--yes) ASSUME_YES=1 ;;
    --no-safesign) WITH_SAFESIGN=0 ;;
    -h|--help) sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Bilinmeyen seçenek: $arg" >&2; exit 2 ;;
  esac
done

say()  { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '\033[33m    UYARI: %s\033[0m\n' "$*"; }
die()  { printf '\033[31mHATA: %s\033[0m\n' "$*" >&2; exit 1; }

confirm() {
  [ "$ASSUME_YES" = 1 ] && return 0
  local answer
  read -r -p "    $1 [e/H] " answer </dev/tty || return 1
  case "$answer" in e|E|evet|Evet|y|Y) return 0 ;; *) return 1 ;; esac
}

download() { # download <url> <hedef>
  curl --fail --location --silent --show-error --max-time 600 \
    -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15" \
    -o "$2" "$1" || die "İndirilemedi: $1"
}

WORK="$(mktemp -d "${TMPDIR:-/tmp}/tnbt-kurulum.XXXXXX")"
MOUNT_POINT=""
cleanup() {
  [ -n "$MOUNT_POINT" ] && hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
  rm -rf "$WORK"
}
trap cleanup EXIT

# --------------------------------------------------------------- ön kontroller
say "Sistem kontrol ediliyor"
[ "$(uname -s)" = "Darwin" ] || die "Bu betik yalnızca macOS içindir."
info "macOS $(sw_vers -productVersion), $(uname -m)"

if [ "$(uname -m)" = "arm64" ]; then
  # İmza uygulamasının yerel kütüphanesi yalnızca Intel mimarisinde; Rosetta gerekir.
  if ! arch -x86_64 /usr/bin/true 2>/dev/null; then
    die "Rosetta kurulu değil. Önce şunu çalıştırın, sonra betiği yeniden başlatın:
      softwareupdate --install-rosetta --agree-to-license"
  fi
  info "Rosetta kurulu."
fi

[ -d "/Applications/Google Chrome.app" ] || warn "Google Chrome /Applications altında bulunamadı; kurulum yine de devam edecek."

# 7-Zip: Windows kurulum paketini (NSIS) açmak için gerekli.
SEVENZIP=""
for candidate in 7zz 7z 7za; do
  if command -v "$candidate" >/dev/null 2>&1; then SEVENZIP="$(command -v "$candidate")"; break; fi
done
if [ -z "$SEVENZIP" ]; then
  info "7-Zip bulunamadı; 7-zip.org adresinden geçici olarak indiriliyor (kalıcı kurulmaz)."
  mkdir -p "$WORK/7zip"
  download "$SEVENZIP_URL" "$WORK/7zip/7z-mac.tar.xz"
  tar -xf "$WORK/7zip/7z-mac.tar.xz" -C "$WORK/7zip"
  SEVENZIP="$WORK/7zip/7zz"
  [ -x "$SEVENZIP" ] || die "7-Zip açılamadı."
fi

mkdir -p "$INSTALL_DIR/lib"

# ------------------------------------------------------------ 1. TNB imza jar'ı
say "TNB imza uygulaması indiriliyor (kep.hs02.kep.tr)"
mkdir -p "$WORK/tnb"
download "$TNB_EXE_URL" "$WORK/tnb/TNBTeknolojiImza.exe"
"$SEVENZIP" x -y -o"$WORK/tnb/x" "$WORK/tnb/TNBTeknolojiImza.exe" TNBTeknolojiImza.jar >/dev/null \
  || die "Kurulum paketi açılamadı."
JAR="$WORK/tnb/x/TNBTeknolojiImza.jar"
[ -f "$JAR" ] || die "Paketin içinde TNBTeknolojiImza.jar bulunamadı; TNB paketi değişmiş olabilir."

JAR_SHA256="$(shasum -a 256 "$JAR" | cut -d' ' -f1)"
if [ "$JAR_SHA256" = "$KNOWN_JAR_SHA256" ]; then
  info "Jar sürümü, betiğin denendiği sürümle aynı."
else
  warn "TNB imza uygulamasının sürümü bu betiğin denendiğinden farklı."
  info "beklenen: $KNOWN_JAR_SHA256"
  info "indirilen: $JAR_SHA256"
  info "TNB uygulamayı güncellemiş olabilir; kurulum çalışmayabilir."
  confirm "Yine de devam edilsin mi?" || die "Kurulum iptal edildi."
fi
cp "$JAR" "$INSTALL_DIR/TNBTeknolojiImza.jar"

# Jar'ın içindeki macOS yerel kütüphanesini kalıcı bir konuma çıkar (nedeni: launcher.js).
unzip -o -q -j "$INSTALL_DIR/TNBTeknolojiImza.jar" libpkcs11wrapper.jnilib -d "$INSTALL_DIR/lib" \
  || die "Jar içinde libpkcs11wrapper.jnilib bulunamadı."

# --------------------------------------------------------------------- 2. Java
say "Java 8 (Intel, Eclipse Temurin) indiriliyor"
if [ -x "$INSTALL_DIR/jre/Contents/Home/bin/java" ]; then
  info "Zaten kurulu, atlanıyor: $INSTALL_DIR/jre"
else
  mkdir -p "$WORK/jre/x"
  download "$JRE_URL" "$WORK/jre/jre.tar.gz"
  tar -xzf "$WORK/jre/jre.tar.gz" -C "$WORK/jre/x"
  JRE_ROOT="$(find "$WORK/jre/x" -maxdepth 1 -mindepth 1 -type d | head -1)"
  [ -x "$JRE_ROOT/Contents/Home/bin/java" ] || die "İndirilen Java paketi beklenen yapıda değil."
  file "$JRE_ROOT/Contents/Home/bin/java" | grep -q x86_64 || die "İndirilen Java Intel (x86_64) değil."
  rm -rf "$INSTALL_DIR/jre"
  mv "$JRE_ROOT" "$INSTALL_DIR/jre"
fi
info "$("$INSTALL_DIR/jre/Contents/Home/bin/java" -version 2>&1 | head -1)"

# ----------------------------------------------------------------- 3. SafeSign
if [ "$WITH_SAFESIGN" = 1 ]; then
  say "E-Tuğra kart sürücüsü (SafeSign) kuruluyor"
  if [ -d "$SAFESIGN_APP" ]; then
    info "Zaten kurulu, atlanıyor: $SAFESIGN_APP"
  else
    mkdir -p "$WORK/safesign"
    download "$SAFESIGN_URL" "$WORK/safesign/MacOS-Safesign.rar"
    tar -xf "$WORK/safesign/MacOS-Safesign.rar" -C "$WORK/safesign" || die "SafeSign arşivi açılamadı."
    DMG="$(find "$WORK/safesign" -maxdepth 1 -name '*.dmg' | head -1)"
    [ -n "$DMG" ] || die "SafeSign arşivinde .dmg bulunamadı."
    MOUNT_POINT="$WORK/safesign/mnt"
    hdiutil attach -nobrowse -readonly -quiet -mountpoint "$MOUNT_POINT" "$DMG" || die "SafeSign disk imajı açılamadı."
    SRC_APP="$MOUNT_POINT/tokenadmin.app"
    [ -d "$SRC_APP" ] || die "Disk imajında tokenadmin.app bulunamadı."

    # Apple imzasını ve yayımcıyı doğrula; uymuyorsa kurma.
    codesign --verify --deep --strict "$SRC_APP" 2>/dev/null || die "tokenadmin.app imzası geçersiz."
    TEAM="$(codesign -dv "$SRC_APP" 2>&1 | sed -n 's/^TeamIdentifier=//p')"
    [ "$TEAM" = "$SAFESIGN_TEAM_ID" ] || die "tokenadmin.app beklenen yayımcıdan (AET Europe) gelmiyor: $TEAM"
    spctl -a "$SRC_APP" 2>/dev/null || die "tokenadmin.app Gatekeeper denetiminden geçmedi."
    info "İmza doğrulandı: AET Europe B.V. ($TEAM), Apple onaylı."

    cp -R "$SRC_APP" "$SAFESIGN_APP" || die "$SAFESIGN_APP kopyalanamadı (Uygulamalar klasörüne yazma izni gerekli)."
    hdiutil detach "$MOUNT_POINT" -quiet || true
    MOUNT_POINT=""
  fi
  [ -f "$SAFESIGN_APP/Contents/Frameworks/libaetpkss.dylib" ] \
    || warn "SafeSign içinde libaetpkss.dylib bulunamadı; kart okunamayabilir."
else
  say "SafeSign kurulumu atlandı (--no-safesign)"
fi

# ------------------------------------------------------- 4. başlatıcı ve Chrome
say "Chrome bağlantısı kuruluyor"

# launcher.js: Java 8'in içindeki betik motoru (Nashorn) ile çalışır.
cat > "$INSTALL_DIR/launcher.js" <<'EOF'
// TNB imza uygulamasının macOS başlatıcısı.
//
// Uygulama, yerel kütüphanesini (libpkcs11wrapper.jnilib) her çalışmada geçici
// bir dosyaya çıkarıp oradan yükler. Chrome'un başlattığı işlemlerin oluşturduğu
// dosyalar macOS tarafından karantinaya alındığı için Gatekeeper bu yüklemeyi
// "kötü amaçlı yazılım içermediği doğrulanamadı" uyarısıyla engeller.
//
// Burada kütüphaneyi önce sabit, karantinasız konumdan yüklüyoruz. Kütüphane
// bir kez yüklendiğinde uygulamanın geçici dosyayı yükleme çağrısı atlanır.
var wrapper = java.lang.System.getProperty("tnbmac.wrapper");
Java.type("iaik.pkcs.pkcs11.wrapper.PKCS11Implementation").ensureLinkedAndInitialized(wrapper);
Java.type("com.tnbt.imza.applet.MainApplet").main(["Chrome"]);
EOF

# tnbtimza-host.sh: Chrome'un çalıştırdığı dosya (Windows'taki tnbtimza-host.bat karşılığı).
cat > "$INSTALL_DIR/tnbtimza-host.sh" <<'EOF'
#!/bin/bash
# TNB Teknoloji İmza - Chrome native messaging host (macOS uyarlaması).
DIR="$(cd "$(dirname "$0")" && pwd)"
# Kart sürücülerinin arandığı yerler: SafeSign (E-Tuğra), sonra standart konumlar.
export DYLD_FALLBACK_LIBRARY_PATH="/Applications/tokenadmin.app/Contents/Frameworks:$DIR/lib:/usr/local/lib:/usr/lib"
exec "$DIR/jre/Contents/Home/bin/java" -Xmx1024M \
  -Dtnbmac.wrapper="$DIR/lib/libpkcs11wrapper.jnilib" \
  -cp "$DIR/TNBTeknolojiImza.jar" jdk.nashorn.tools.Shell "$DIR/launcher.js"
EOF
chmod +x "$INSTALL_DIR/tnbtimza-host.sh"

# İndirilen dosyalarda karantina işareti kaldıysa temizle.
xattr -dr com.apple.quarantine "$INSTALL_DIR" 2>/dev/null || true

if [ "${TNBT_SKIP_MANIFEST:-0}" = 1 ]; then
  info "Chrome tanımı atlandı (TNBT_SKIP_MANIFEST=1)."
else
  mkdir -p "$CHROME_NMH_DIR"
  cat > "$CHROME_NMH_DIR/tnbtimzahost.json" <<EOF
{
  "name": "tnbtimzahost",
  "description": "TnbTeknoloji Imza Chrome Native Messaging Host",
  "path": "$INSTALL_DIR/tnbtimza-host.sh",
  "type": "stdio",
  "allowed_origins": [
    "chrome-extension://$EXTENSION_ID/"
  ]
}
EOF
  info "Yazıldı: $CHROME_NMH_DIR/tnbtimzahost.json"
fi

# ------------------------------------------------------------------- bitiş
say "Kurulum tamamlandı"
info "Kurulum klasörü: $INSTALL_DIR"

if ls -d "$HOME/Library/Application Support/Google/Chrome"/*/Extensions/"$EXTENSION_ID" >/dev/null 2>&1; then
  info "Chrome eklentisi zaten kurulu."
else
  info "Chrome eklentisi kurulu değil. Şu sayfadan \"Chrome'a ekle\" deyin:"
  info "$EXTENSION_URL"
  if [ -d "/Applications/Google Chrome.app" ] && [ "${TNBT_SKIP_MANIFEST:-0}" != 1 ]; then
    open -a "Google Chrome" "$EXTENSION_URL" 2>/dev/null || true
  fi
fi

cat <<EOF

    Sonraki adımlar:
      1. E-imza kartınızı/tokenınızı takın.
      2. İsterseniz kartın okunduğunu sınayın:  ./test.sh
      3. Chrome'da https://kep.hs02.kep.tr adresini yenileyip e-imza ile giriş yapın.
         Sertifika penceresi Chrome'un arkasında açılırsa Dock'taki Java simgesine tıklayın.

    Sorun olursa günlük dosyası: ~/TnbTeknolojiImza.log
EOF
