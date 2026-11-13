#!/usr/bin/env bash
# Bütün çekim senaryolarını verilen dilde çalıştırır; kareleri ve günlüğü bir klasöre toplar.
#   bash tools/dil/tara.sh <dil> <klasör> [senaryo ...]
# Her senaryodan önce tools/cikti boşaltılır (önceki koşudan kalan kareler karışmasın).
# Günlükte "TR?" satırları Türkçe kalan yazıları, "TAS" satırları alanına sığmayan yazıları gösterir.
set -u
cd "$(dirname "$0")/../.."
dil="$1"
hedef="$2"
shift 2
senaryolar=("$@")
[ ${#senaryolar[@]} -eq 0 ] && senaryolar=(akis masa hikaye rontgen defter sinir genelge ayarlar ara ev yakala)
mkdir -p "$hedef"
: > "$hedef/log.txt"
for s in "${senaryolar[@]}"; do
	python -c "import pathlib; [f.unlink() for f in pathlib.Path('tools/cikti').glob('*') if f.suffix in ('.png', '.jpg')]"
	echo "=== $s" >> "$hedef/log.txt"
	timeout 600 bash tools/cek.sh "$s" "dil=$dil" >> "$hedef/log.txt" 2>&1
	for f in tools/cikti/*.png; do
		[ -e "$f" ] && cp "$f" "$hedef/${s}__$(basename "$f")"
	done
done
echo "bitti" >> "$hedef/log.txt"
