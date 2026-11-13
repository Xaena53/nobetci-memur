"""Ev sahnesinin penceresindeki boyalı (duran) kar tanelerini siler.

Oyunda pencerenin ardında kar canlandırılır (scripts/EvCanlandirma.gd); resimdeki duran taneler
hareketli tanelerin arasında donmuş gibi kalıyordu. Bu betik camların gökyüzü bölümünde, çevresinden
belirgin biçimde açık olan küçük lekeleri bulur ve yerlerini çevrenin ortanca rengiyle doldurur.
Ağaç, minare, tepeler ve evler (koyu ya da büyük biçimler) etkilenmez.

Asıl görselin yedeği tools/sanat/ham/ev_arkaplan_karli.webp olarak saklanır; betik her zaman
yedekten çalışır (yeniden çalıştırmak sonucu değiştirmez).

Kullanım: python tools/sanat/ev_pencere.py
"""
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

KOK = Path(__file__).resolve().parents[2]
YOL = KOK / "assets" / "img" / "ev_arkaplan.webp"
YEDEK = Path(__file__).resolve().parent / "ham" / "ev_arkaplan_karli.webp"
## Camlar, ekran biriminde (1280×720): sol üst, sağ üst, sol alt, sağ alt. EvCanlandirma.CAMLAR ile aynı.
CAMLAR = [(143, 129, 205, 215), (218, 129, 285, 215), (143, 228, 205, 339), (218, 228, 285, 339)]
GOK_ALTI = 292          # bu satırın altı tepeler ve evlerdir: dokunulmaz


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    if not YEDEK.exists():
        YEDEK.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(YOL, YEDEK)
    im = Image.open(YEDEK).convert("RGB")
    olcek = im.width / 1280.0
    a = np.array(im).astype(np.float32)
    isik = a @ np.array([0.299, 0.587, 0.114], np.float32)
    ortanca = np.array(im.filter(ImageFilter.MedianFilter(size=int(17 * olcek) | 1))).astype(np.float32)
    ortanca_isik = ortanca @ np.array([0.299, 0.587, 0.114], np.float32)
    toplam = 0
    for x0, y0, x1, y1 in CAMLAR:
        y1 = min(y1, GOK_ALTI)
        kutu = (slice(int(y0 * olcek), int(y1 * olcek)), slice(int(x0 * olcek), int(x1 * olcek)))
        acik = (isik[kutu] - ortanca_isik[kutu]) > 16.0
        # yalnız küçük lekeler: tane; büyük açık alanlar (pervaz kenarı, dallardaki kar) kalsın
        etiket, adet = ndimage.label(acik)
        alanlar = ndimage.sum(acik, etiket, range(1, adet + 1))
        kucuk = np.isin(etiket, [i + 1 for i in range(adet) if alanlar[i] < 260 * olcek])
        kucuk = ndimage.binary_dilation(kucuk, iterations=max(1, int(1.5 * olcek)))
        yumusak = np.array(Image.fromarray((kucuk * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2))).astype(np.float32) / 255.0
        a[kutu] = a[kutu] * (1.0 - yumusak[..., None]) + ortanca[kutu] * yumusak[..., None]
        toplam += int(kucuk.sum())
    Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).save(YOL, quality=95, method=6)
    print(f"{toplam} piksel dolduruldu → {YOL.relative_to(KOK).as_posix()}")


if __name__ == "__main__":
    main()
