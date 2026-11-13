"""Görsellerin içe aktarma kipini ayarlar: fotoğraf benzeri büyük görseller kayıplı (WebP, kalite 0,92),
maske ve yoğunluk haritaları kayıpsız.

Neden: görseller depoda kayıplı WebP olarak durur. Godot onları kayıpsız içe aktarınca aynı görsel pakette
üç kat yer tutar (13 MB → 42 MB). Kayıplı kipte paket kaynak boyutuna iner; ölçülen fark en kötü görselde
42,7 dB PSNR'dir (bkz. tools/sanat/kalite_olc.py), saydamlık kanalı değişmez.

Kayıpsız kalanlar: röntgen yoğunluk haritaları (gri tonlar eşiklenir), imza ve damga maskeleri.

Kullanım: python tools/ice_aktarma.py && godot --headless --path . --import
Yeni görsel eklendikten sonra yeniden çalıştırılır.
"""
import re
import sys
from pathlib import Path

KOK = Path(__file__).resolve().parents[1]
KALITE = "0.92"
KAYIPLI = ["assets/img/portre", "assets/img/portre/vesika", "assets/img/portre/agiz", "assets/img/portre/aranan",
           "assets/img", "assets/img/nesne", "assets/img/kagit", "assets/img/kasaba", "assets/img/nesne/en", "assets/img/nesne/ru"]


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    degisen = 0
    toplam = 0
    for klasor in KAYIPLI:
        for f in sorted((KOK / klasor).glob("*.webp.import")):
            toplam += 1
            s = f.read_text(encoding="utf-8")
            yeni = re.sub(r"compress/mode=\d", "compress/mode=1", s)
            yeni = re.sub(r"compress/lossy_quality=[\d.]+", f"compress/lossy_quality={KALITE}", yeni)
            if yeni != s:
                f.write_text(yeni, encoding="utf-8", newline="\n")
                degisen += 1
    print(f"{toplam} görselden {degisen} tanesinin içe aktarma kipi kayıplıya alındı (kalite {KALITE}).")


if __name__ == "__main__":
    main()
