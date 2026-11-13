"""Yazılı nesnelerin (plaket, etiket, şerit, defter kapağı, levha) İngilizce ve Rusça hâllerini dilimler.

Ham sayfalar tools/sanat/ham/yazili_esya_<dil>.png: Türkçe sayfayla (yazili_esya.png) aynı 4×4 düzende,
aynı nesneler, yalnız yazıları o dilde. Her nesne, Türkçe karşılığıyla aynı piksel boyutuna getirilip
assets/img/nesne/<dil>/<ad>.webp olarak yazılır; oyunda `Dil.yol()` dile özgü dosyayı bulur.

Rusça sayfada "СУМКУ НА РЕНТГЕН" şeridinin son harfi "И" çıkmıştı: aynı şeritteki "Н" harfi
kopyalanarak düzeltilir.

Kullanım: python tools/sanat/etiket_dil.py [denetim.png]
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from damgalar import ESYALAR, hucre_kutulari  # noqa: E402
from dilimle import kaydet  # noqa: E402

KOK = Path(__file__).resolve().parents[2]
HAM = Path(__file__).resolve().parent / "ham"
NESNE = KOK / "assets" / "img" / "nesne"
DILLER = ["en", "ru"]
ATLANAN = {"serit_bos", "fis_eksik"}        # yazısız şerit ve artık kullanılmayan fiş: Türkçesi yeter


def son_harfi_duzelt(parca: Image.Image, kaynak_no: int) -> Image.Image:
    """Şeritteki son harfi, aynı şeritteki `kaynak_no`. harfin kopyasıyla değiştirir."""
    a = np.array(parca.convert("RGBA")).astype(np.float32)
    isik = a[..., :3].mean(axis=2)
    yazi = (isik > 150) & (a[..., 3] > 200)                 # açık renkli kabartma harfler
    sutun = yazi.sum(axis=0) > 1
    harfler = []
    bas = None
    for x, d in enumerate(sutun):
        if d and bas is None:
            bas = x
        if not d and bas is not None:
            if x - bas >= 4:
                harfler.append((bas, x))
            bas = None
    if bas is not None:
        harfler.append((bas, len(sutun)))
    print(f"  şeritte {len(harfler)} harf bulundu")
    k0, k1 = harfler[kaynak_no]
    s0, s1 = harfler[-1]
    satirlar = np.nonzero(yazi[:, k0:k1].sum(axis=1) > 0)[0]
    y0, y1 = satirlar.min() - 2, satirlar.max() + 3
    # son harfin yeri şeridin zemin rengiyle kapatılır (yanındaki boş sütunlardan)
    zemin = a[y0:y1, s1 + 2:s1 + 6].mean(axis=1, keepdims=True)
    a[y0:y1, s0 - 1:s1 + 1] = zemin
    kopya = np.array(parca.convert("RGBA")).astype(np.float32)[y0:y1, k0 - 1:k1 + 1]
    a[y0:y1, s0 - 1:s0 - 1 + kopya.shape[1]] = kopya
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    denetim = []
    for dil in DILLER:
        yol = HAM / f"yazili_esya_{dil}.png"
        ham = np.array(Image.open(yol).convert("RGBA"))
        temiz = np.clip((ham[..., 3].astype(np.float32) - 90.0) / 150.0, 0.0, 1.0)
        ham[..., 3] = (temiz * 255).astype(np.uint8)
        im = Image.fromarray(ham, "RGBA")
        (NESNE / dil).mkdir(exist_ok=True)
        for ad, kutu in zip(ESYALAR, hucre_kutulari(ham[..., 3] > 60, 4, 4, 400)):
            if kutu is None or ad in ATLANAN:
                continue
            hedef = NESNE / dil / f"{ad}.webp"
            kaydet(im, kutu, 1.0, hedef)
            parca = Image.open(hedef).convert("RGBA")
            if dil == "ru" and ad == "serit_canta":
                parca = son_harfi_duzelt(parca, -5)         # …РЕ[Н]ТГЕ?: sondan beşinci harf "Н"
            # Türkçe nesneyle aynı boyut: yerleşim değişmesin
            asil = Image.open(NESNE / f"{ad}.webp")
            parca = parca.resize(asil.size, Image.LANCZOS)
            parca.save(hedef, quality=92, method=4, alpha_quality=100)
            denetim.append(parca)
            print(f"{dil}/{ad}: {parca.width}x{parca.height}")
    if len(sys.argv) > 1:
        sayfa = Image.new("RGBA", (1800, 1500), (120, 150, 130, 255))
        x = y = 8
        satir = 0
        for p in denetim:
            p = p.copy()
            p.thumbnail((330, 240))
            if x + p.width > 1790:
                x, y, satir = 8, y + satir + 8, 0
            sayfa.alpha_composite(p, (x, y))
            x += p.width + 8
            satir = max(satir, p.height)
        sayfa.convert("RGB").save(sys.argv[1])


if __name__ == "__main__":
    main()
