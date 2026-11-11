#!/bin/bash
#
# install.sh ile kurulanları kaldırır.
#
#   ./uninstall.sh                  İmza uygulaması, Java ve Chrome tanımını kaldırır
#   ./uninstall.sh --with-safesign  Ayrıca /Applications/tokenadmin.app (SafeSign) uygulamasını kaldırır
#
# SafeSign varsayılan olarak bırakılır, çünkü başka e-imza uygulamaları da onu kullanıyor olabilir.
#
set -euo pipefail

INSTALL_DIR="${TNBT_INSTALL_DIR:-$HOME/Library/TNBTeknolojiImza}"
MANIFEST="$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts/tnbtimzahost.json"
SAFESIGN_APP="/Applications/tokenadmin.app"

WITH_SAFESIGN=0
for arg in "$@"; do
  case "$arg" in
    --with-safesign) WITH_SAFESIGN=1 ;;
    -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Bilinmeyen seçenek: $arg" >&2; exit 2 ;;
  esac
done

remove() {
  if [ -e "$1" ]; then rm -rf "$1" && echo "Kaldırıldı: $1"; else echo "Zaten yok:  $1"; fi
}

# Yanlış bir klasörü silmemek için kurulum klasörünün gerçekten bize ait olduğunu doğrula.
if [ -d "$INSTALL_DIR" ] && [ ! -f "$INSTALL_DIR/tnbtimza-host.sh" ]; then
  echo "HATA: $INSTALL_DIR bu betiğin kurduğu klasöre benzemiyor; silinmedi." >&2
  exit 1
fi

remove "$MANIFEST"
remove "$INSTALL_DIR"
remove "$HOME/TnbTeknolojiImza.log"
remove "$HOME/TnbTeknolojiImza.err.log"

if [ "$WITH_SAFESIGN" = 1 ]; then
  remove "$SAFESIGN_APP"
else
  [ -d "$SAFESIGN_APP" ] && echo "Bırakıldı:  $SAFESIGN_APP (kaldırmak için --with-safesign)"
fi

echo "Chrome eklentisini kaldırmak isterseniz: chrome://extensions"
