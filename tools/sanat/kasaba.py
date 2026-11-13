"""Kasaba sahnelerini (geçiş ekranında görünen boyalı resimler) ham görsellerden hazırlar.

Ham görseller tools/sanat/ham/kasaba/<ad>.jpg|png altında durur (git dışı). Her biri 16:9'a ortadan
kırpılır, 2560×1440'a getirilir ve assets/img/kasaba/<ad>.webp olarak yazılır. Sonra
`python tools/ice_aktarma.py` ve Godot içe aktarması çalıştırılmalıdır.

Sahnenin bacaları, lambaları ve ışıklı pencereleri data/ara_ekran.json dosyasında tanımlanır;
yerlerini bulmak için `--izgara <ad>` 1280×720 ölçekli, ızgaralı bir önizleme yazar.

Kullanım: python tools/sanat/kasaba.py [--izgara <ad> <çıktı.jpg>]
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

KOK = Path(__file__).resolve().parents[2]
HAM = Path(__file__).resolve().parent / "ham" / "kasaba"
HEDEF = KOK / "assets" / "img" / "kasaba"
BOYUT = (2560, 1440)


def hazirla(yol: Path) -> Image.Image:
    im = Image.open(yol).convert("RGB")
    oran = BOYUT[0] / BOYUT[1]
    if im.width / im.height > oran:
        en = round(im.height * oran)
        x0 = (im.width - en) // 2
        im = im.crop((x0, 0, x0 + en, im.height))
    else:
        boy = round(im.width / oran)
        y0 = (im.height - boy) // 2
        im = im.crop((0, y0, im.width, y0 + boy))
    return im.resize(BOYUT, Image.LANCZOS)


def izgara(ad: str, cikti: str) -> None:
    im = Image.open(HEDEF / f"{ad}.webp").convert("RGB").resize((1280, 720), Image.LANCZOS)
    im = im.resize((2560, 1440), Image.LANCZOS)
    d = ImageDraw.Draw(im)
    for x in range(0, 1280, 50):
        d.line((x * 2, 0, x * 2, 1440), fill=(255, 0, 255) if x % 100 == 0 else (0, 255, 255))
        if x % 100 == 0:
            d.text((x * 2 + 3, 3), str(x), fill=(255, 255, 0))
    for y in range(0, 720, 50):
        d.line((0, y * 2, 2560, y * 2), fill=(255, 0, 255) if y % 100 == 0 else (0, 255, 255))
        if y % 100 == 0:
            d.text((3, y * 2 + 3), str(y), fill=(255, 255, 0))
    im.save(cikti, quality=88)


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    if len(sys.argv) >= 4 and sys.argv[1] == "--izgara":
        izgara(sys.argv[2], sys.argv[3])
        return
    HEDEF.mkdir(parents=True, exist_ok=True)
    for yol in sorted(list(HAM.glob("*.jpg")) + list(HAM.glob("*.png"))):
        hedef = HEDEF / f"{yol.stem}.webp"
        hazirla(yol).save(hedef, quality=95, method=6)
        print(f"{yol.name} -> {hedef.relative_to(KOK).as_posix()} ({hedef.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
