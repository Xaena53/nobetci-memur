"""Görsellerin ekran belleğinde (açılmış hâlde, RGBA) ne kadar yer tuttuğunu klasör klasör döker.

Diskteki boyut sıkıştırılmış hâlidir; ekran kartına yüklenen doku en × boy × 4 bayttır. Gösterildiği
boyuttan çok büyük saklanan görseller burada belli olur.

Kullanım: python tools/doku_bellegi.py
"""
import collections
import sys
from pathlib import Path

from PIL import Image

KOK = Path(__file__).resolve().parents[1]


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    klasorler = collections.defaultdict(lambda: [0, 0.0, []])
    for f in (KOK / "assets" / "img").rglob("*.webp"):
        w, h = Image.open(f).size
        mb = w * h * 4 / 1e6
        k = klasorler[f.parent.relative_to(KOK).as_posix()]
        k[0] += 1
        k[1] += mb
        k[2].append((mb, f.name, w, h))
    print(f"{'klasör':30} {'adet':>4} {'bellekte MB':>12}  en büyükler")
    for ad, (adet, mb, liste) in sorted(klasorler.items(), key=lambda x: -x[1][1]):
        liste.sort(reverse=True)
        print(f"{ad:30} {adet:4d} {mb:12.1f}  " + ", ".join(f"{a} ({w}x{h})" for _, a, w, h in liste[:4]))
    print(f"toplam {sum(v[1] for v in klasorler.values()):.0f} MB (hepsi aynı anda yüklenirse)")


if __name__ == "__main__":
    main()
