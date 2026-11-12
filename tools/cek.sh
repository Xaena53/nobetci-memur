#!/usr/bin/env bash
# Ekran görüntüsü senaryosu çalıştırır:  bash tools/cek.sh <senaryo> [ek argümanlar]
# Pencere ekran dışında ve odak almadan açılır, ses kapalıdır; kareler tools/cikti/ altına yazılır.
set -e
cd "$(dirname "$0")/.."
G="${GODOT:-/c/Users/pc/Godot/4.3/Godot_v4.3-stable_win64_console.exe}"
cat > override.cfg <<'EOF'
[display]
window/size/no_focus=true
window/size/initial_position_type=0
window/size/initial_position=Vector2i(-4000, -4000)
EOF
trap 'rm -f override.cfg' EXIT
mkdir -p tools/cikti && touch tools/cikti/.gdignore   # kareler proje varlığı sayılmasın
"$G" --path . --audio-driver Dummy res://tools/Cekim.tscn -- "$@"
