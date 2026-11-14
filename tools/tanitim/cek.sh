#!/usr/bin/env bash
# Tanıtım filmi için bir sahneyi kaydeder:  bash tools/tanitim/cek.sh <sahne> <çıktı klasörü> [ek argümanlar]
# Pencere ekran dışında ve odak almadan açılır; görüntü 1920x1080, saniyede 30 kare, sesiyle birlikte
# <çıktı klasörü>/<sahne>.avi dosyasına yazılır. Kesim işaretleri <sahne>.json içindedir.
set -e
cd "$(dirname "$0")/../.."
G="${GODOT:-/c/Users/pc/Godot/4.3/Godot_v4.3-stable_win64_console.exe}"
SAHNE="$1"; CIKTI="$2"; shift 2
mkdir -p "$CIKTI"
cat > override.cfg <<'EOC'
[display]
window/size/no_focus=true
window/size/window_width_override=1872
window/size/window_height_override=1053
window/size/initial_position_type=0
window/size/initial_position=Vector2i(-4000, -4000)

[editor]
movie_writer/mjpeg_quality=0.97
movie_writer/fps=30
EOC
trap 'rm -f override.cfg' EXIT
"$G" --path . --fixed-fps 30 --write-movie "$(cygpath -w "$CIKTI/$SAHNE.avi")" \
	res://tools/tanitim/Tanitim.tscn -- "$SAHNE" "cikti=$(cygpath -m "$CIKTI")" "$@"
