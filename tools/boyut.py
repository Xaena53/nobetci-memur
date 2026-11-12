"""Paket boyutunun dökümü: hangi klasör ne kadar yer tutuyor (kaynak dosya ve içe aktarılmış hâli).

Kullanım: python tools/boyut.py        (önce `godot --headless --path . --import` çalışmış olmalı)
"""
import collections
import re
import sys
from pathlib import Path

KOK = Path(__file__).resolve().parents[1]


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    kayitlar = {}
    for f in (KOK / "assets").rglob("*.import"):
        s = f.read_text(encoding="utf-8")
        m = re.search(r'path="res://(\.godot/imported/[^"]+)"', s)
        asil = f.with_suffix("")
        if not m or not (KOK / m.group(1)).exists() or not asil.exists():
            continue
        kip = re.search(r"compress/mode=(\d)", s)
        kayitlar[asil.relative_to(KOK).as_posix()] = (asil.stat().st_size, (KOK / m.group(1)).stat().st_size,
                                                       kip.group(1) if kip else "-", "mipmaps/generate=true" in s)
    klasorler = collections.defaultdict(lambda: [0, 0, 0])
    for ad, (kaynak, paket, _, _) in kayitlar.items():
        k = klasorler[str(Path(ad).parent.as_posix())]
        k[0] += kaynak
        k[1] += paket
        k[2] += 1
    print(f"{'klasör':40} {'adet':>5} {'kaynak MB':>10} {'paket MB':>10}")
    for ad, (kaynak, paket, adet) in sorted(klasorler.items(), key=lambda x: -x[1][1]):
        print(f"{ad:40} {adet:5d} {kaynak / 1e6:10.1f} {paket / 1e6:10.1f}")
    print(f"{'toplam':40} {len(kayitlar):5d} {sum(v[0] for v in kayitlar.values()) / 1e6:10.1f} {sum(v[1] for v in kayitlar.values()) / 1e6:10.1f}")
    print("sıkıştırma kipleri (0 kayıpsız, 1 kayıplı, 2 VRAM):", dict(collections.Counter(v[2] for v in kayitlar.values())),
          "| mipmap:", dict(collections.Counter(v[3] for v in kayitlar.values())))
    print("en büyükler:")
    for ad, (kaynak, paket, _, _) in sorted(kayitlar.items(), key=lambda x: -x[1][1])[:10]:
        print(f"  {ad:58} kaynak {kaynak / 1e3:7.0f} KB   paket {paket / 1e3:7.0f} KB")


if __name__ == "__main__":
    main()
