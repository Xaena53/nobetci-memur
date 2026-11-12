#!/usr/bin/env bash
# Sağlamlık testi:  bash tools/saglamlik.sh [veri kayit uretici ipucu akis maymun]
# Test sonucunun yanında konsola düşen her betik hatasını ve uyarısını da başarısızlık sayar.
cd "$(dirname "$0")/.."
G="${GODOT:-/c/Users/pc/Godot/4.3/Godot_v4.3-stable_win64_console.exe}"
GUNLUK="$(mktemp)"
timeout 1500 "$G" --headless --path . res://tools/Saglamlik.tscn -- "$@" > "$GUNLUK" 2>&1
KOD=$?
grep -E "^==|✗|!|tur [0-9]+:|SAĞLAMLIK" "$GUNLUK"
HATA=$(grep -cE "SCRIPT ERROR|^ERROR|^WARNING|ObjectDB instances leaked|resources still in use" "$GUNLUK")
if [ "$HATA" -gt 0 ]; then
  echo "KONSOLDA $HATA HATA/UYARI SATIRI:"
  grep -E -A3 "SCRIPT ERROR|^ERROR|^WARNING|ObjectDB instances leaked|resources still in use" "$GUNLUK" | head -80
  KOD=1
fi
cp "$GUNLUK" tools/cikti/saglamlik.log 2>/dev/null
rm -f "$GUNLUK"
exit $KOD
