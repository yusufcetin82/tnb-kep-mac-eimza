#!/bin/bash
#
# Kurulumu Chrome olmadan sınar: imza uygulamasına, sitenin gönderdiği
# "sertifika seç" isteğinin aynısını yollar ve karttan okunan sertifikayı gösterir.
# PIN sorulmaz, hiçbir şey imzalanmaz.
#
# Kartta birden fazla sertifika varsa bir seçim penceresi açılır (Chrome'un
# arkasında kalabilir; Dock'taki Java simgesine tıklayın).
#
set -euo pipefail

INSTALL_DIR="${TNBT_INSTALL_DIR:-$HOME/Library/TNBTeknolojiImza}"
HOST="$INSTALL_DIR/tnbtimza-host.sh"
[ -x "$HOST" ] || { echo "Kurulum bulunamadı: $HOST — önce ./install.sh çalıştırın." >&2; exit 1; }

REQUEST='{"extensionVersion":"1.0.0","isCspSupported":"false","isPkcs11Supported":"true","logLevel":"0","language":"tr","request":{"functionName":"selectCertificate"}}'

echo "İmza uygulaması başlatılıyor, kart okunuyor..."
# Chrome native messaging biçimi: 4 baytlık uzunluk (little-endian) + JSON.
RESPONSE="$(perl -e 'print pack("V", length($ARGV[0])), $ARGV[0]' "$REQUEST" | "$HOST" | tail -c +5)"

CERT_B64="$(printf '%s' "$RESPONSE" | sed -n 's/.*"certificateB64":"\([^"]*\)".*/\1/p' | tr -d '\\')"

case "$CERT_B64" in
  "")
    echo "BAŞARISIZ: uygulamadan anlaşılır bir yanıt gelmedi."
    echo "Yanıt: ${RESPONSE:0:300}"
    echo "Ayrıntı için: ~/TnbTeknolojiImza.log"
    exit 1 ;;
  _cancel_)
    echo "İptal edildi: sertifika seçilmedi ya da kart bulunamadı."
    echo "Kart takılı mı? Ayrıntı için: ~/TnbTeknolojiImza.log"
    exit 1 ;;
  _error_)
    echo "BAŞARISIZ: uygulama hata döndürdü. Ayrıntı için: ~/TnbTeknolojiImza.log"
    exit 1 ;;
esac

echo "BAŞARILI: karttan sertifika okundu."
printf '%s' "$CERT_B64" | base64 -D | openssl x509 -inform der -noout -subject -issuer -enddate 2>/dev/null \
  | sed -e 's/serialNumber=[0-9]*/serialNumber=(gizlendi)/' -e 's/^/    /' || echo "    (sertifika ayrıntıları gösterilemedi)"
