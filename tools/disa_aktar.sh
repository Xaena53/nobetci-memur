#!/usr/bin/env bash
# Windows ve Web yapılarını üretir ve yüklemeye hazır zip dosyalarını çıkarır.
#   bash tools/disa_aktar.sh
# Önce dışa aktarma şablonları kurulmuş olmalıdır:  python tools/sablon_indir.py
# Çıktı: build/windows/NobetciMemur.exe, build/web/index.html,
#        build/NobetciMemur-windows.zip, build/NobetciMemur-web.zip
set -e
cd "$(dirname "$0")/.."
G="${GODOT:-/c/Users/pc/Godot/4.3/Godot_v4.3-stable_win64_console.exe}"
rm -rf build
mkdir -p build/windows build/web
touch build/.gdignore      # Godot bu klasörü proje varlığı saymasın
"$G" --headless --path . --import
"$G" --headless --path . --export-release "Windows" build/windows/NobetciMemur.exe
"$G" --headless --path . --export-release "Web" build/web/index.html
python -c "import shutil; shutil.make_archive('build/NobetciMemur-windows', 'zip', 'build/windows'); shutil.make_archive('build/NobetciMemur-web', 'zip', 'build/web')"
ls -la build build/windows build/web
