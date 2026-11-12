"""Röntgen cihazının görsellerini üretilen sayfalardan dilimler.

Girdi (tools/sanat/ham/):
  rontgen_esya1.png  5x4 eşya (zararsız)          rontgen_esya2.png  4x4 eşya (yasaklar ve benzerleri)
  rontgen_kabuk.png  2x2 boş çanta röntgeni        konsol.png         cihazın kumanda masası
  cantalar.png       dört çantanın dıştan görünüşü

Eşya ve kabuklar "yoğunluk haritası" olarak saklanır: siyah zemin üzerinde gri tonlu, renksiz. Oyun
bunları üst üste bindirip (yoğunluklar çarpılarak birikir) ekran gölgelendiricisiyle fosfor rengine
boyar. Üretimden gelen yarı saydam hâle temizlenir.

Çıktı: assets/img/rontgen/esya/<ad>.webp, assets/img/rontgen/kabuk/<tur>.webp,
       assets/img/rontgen/konsol.webp, assets/img/nesne/canta_<tur>.webp
Denetim: tools/sanat/ham/rontgen_denetim.jpg

Kullanım: python tools/sanat/rontgen.py
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

sys.path.insert(0, str(Path(__file__).resolve().parent))
from dilimle import bilesenler, kaydet  # noqa: E402

KOK = Path(__file__).resolve().parents[2]
HAM = Path(__file__).resolve().parent / "ham"
RONTGEN = KOK / "assets" / "img" / "rontgen"
NESNE = KOK / "assets" / "img" / "nesne"

ESYA1 = ["kazak", "ayakkabi", "ekmek", "tursu", "sise",
         "calar_saat", "radyo", "fon", "utu", "caydanlik",
         "makas", "anahtar", "gozluk", "kitap", "semsiye",
         "sucuk", "yun", "catal_kasik", "termos", "tespih"]
ESYA2 = ["tabanca", "toplu", "mermi", "el_bombasi",
         "saatli_bomba", "dinamit", "satir", "kama",
         "bicak", "matkap", "mum", "fotograf_makinesi",
         "pense", "tabaka", "para_destesi", "kasa"]
KABUKLAR = ["bavul", "el_cantasi", "evrak_cantasi", "torba"]


def yogunluk(yol: Path, taban: float) -> np.ndarray:
    """Sayfayı 0..1 yoğunluk haritasına çevirir; nesnelerin etrafındaki yarı saydam hâleyi atar."""
    a = np.array(Image.open(yol).convert("RGBA")).astype(np.float32) / 255.0
    parlak = a[..., 0] * 0.299 + a[..., 1] * 0.587 + a[..., 2] * 0.114
    alfa = a[..., 3]
    v = parlak * alfa
    d = np.clip((v - taban) / (1.0 - taban), 0.0, 1.0)
    # yalnızca nesnenin kendisi (alfası dolu bölge) ve hemen kenarı kalsın
    govde = ndimage.binary_dilation(alfa > 0.72, iterations=2)
    maske = ndimage.gaussian_filter(govde.astype(np.float32), 1.2)
    return d * np.clip(maske * 1.4, 0.0, 1.0)


def hucre_kutulari(d: np.ndarray, sutun: int, satir: int) -> list:
    """Izgaradaki her hücre için, merkezi o hücreye düşen parçaların ortak kutusu."""
    etiket, n = ndimage.label(d > 0.06)
    dilimler = ndimage.find_objects(etiket)
    alanlar = ndimage.sum(d > 0.06, etiket, range(1, n + 1))
    h, w = d.shape
    kutular = [None] * (sutun * satir)
    for i in range(n):
        if alanlar[i] < 90:
            continue
        ys, xs = dilimler[i]
        cx, cy = (xs.start + xs.stop) / 2, (ys.start + ys.stop) / 2
        k = min(satir - 1, int(cy / h * satir)) * sutun + min(sutun - 1, int(cx / w * sutun))
        kutu = (xs.start, ys.start, xs.stop, ys.stop)
        if kutular[k] is None:
            kutular[k] = kutu
        else:
            o = kutular[k]
            kutular[k] = (min(o[0], kutu[0]), min(o[1], kutu[1]), max(o[2], kutu[2]), max(o[3], kutu[3]))
    return kutular


def gri_kaydet(d: np.ndarray, kutu, yol: Path, en_uzun: int, pay: int = 6) -> tuple:
    x0, y0, x1, y1 = kutu
    x0, y0 = max(0, x0 - pay), max(0, y0 - pay)
    x1, y1 = min(d.shape[1], x1 + pay), min(d.shape[0], y1 + pay)
    parca = Image.fromarray((np.clip(d[y0:y1, x0:x1], 0, 1) * 255).astype(np.uint8), "L")
    olcek = min(1.0, en_uzun / max(parca.size))
    if olcek < 1.0:
        parca = parca.resize((round(parca.width * olcek), round(parca.height * olcek)), Image.LANCZOS)
    # kenarda siyah bir çerçeve: doğrusal süzme komşu pikselden parlaklık taşımasın
    cerceveli = Image.new("L", (parca.width + 4, parca.height + 4), 0)
    cerceveli.paste(parca, (2, 2))
    cerceveli.convert("RGB").save(yol, quality=90, method=4)
    return cerceveli.size


def esyalar(denetim: list) -> None:
    hedef = RONTGEN / "esya"
    hedef.mkdir(parents=True, exist_ok=True)
    for sayfa, adlar, sutun, satir in [("rontgen_esya1", ESYA1, 5, 4), ("rontgen_esya2", ESYA2, 4, 4)]:
        d = yogunluk(HAM / f"{sayfa}.png", 0.17)
        kutular = hucre_kutulari(d, sutun, satir)
        for ad, kutu in zip(adlar, kutular):
            if kutu is None:
                print(f"  {ad}: BULUNAMADI")
                continue
            w, h = gri_kaydet(d, kutu, hedef / f"{ad}.webp", 384)
            denetim.append((ad, Image.open(hedef / f"{ad}.webp")))
            print(f"  {ad}: {w}x{h}")


def kabuklar(denetim: list) -> None:
    hedef = RONTGEN / "kabuk"
    hedef.mkdir(parents=True, exist_ok=True)
    d = yogunluk(HAM / "rontgen_kabuk.png", 0.045)
    for ad, kutu in zip(KABUKLAR, hucre_kutulari(d, 2, 2)):
        w, h = gri_kaydet(d, kutu, hedef / f"{ad}.webp", 800, 10)
        denetim.append((ad, Image.open(hedef / f"{ad}.webp")))
        print(f"  kabuk {ad}: {w}x{h}")


def konsol() -> None:
    im = Image.open(HAM / "konsol.png").convert("RGBA")
    a = np.array(im)
    # kenardaki renkli saçak: alfayı biraz içeri çek
    alfa = ndimage.grey_erosion(a[..., 3], size=(5, 5))
    alfa = ndimage.gaussian_filter(alfa.astype(np.float32), 0.8)
    a[..., 3] = np.clip(alfa, 0, 255).astype(np.uint8)
    im = Image.fromarray(a)
    kutu = Image.fromarray((a[..., 3] > 40).astype(np.uint8) * 255).getbbox()
    im = im.crop(kutu)
    olcek = 1400 / im.width
    im = im.resize((1400, round(im.height * olcek)), Image.LANCZOS)
    b = np.array(im)
    b[b[..., 3] < 6] = 0
    Image.fromarray(b).save(RONTGEN / "konsol.webp", quality=92, method=4, alpha_quality=100)
    print(f"  konsol: {im.size[0]}x{im.size[1]}")


def cantalar() -> None:
    im = Image.open(HAM / "cantalar.png").convert("RGBA")
    for ad, kutu in zip(KABUKLAR, bilesenler(im, 4, 1)):
        w, h = kaydet(im, kutu, 1.0, NESNE / f"canta_{ad}.webp")
        print(f"  çanta {ad}: {w}x{h}")


def main() -> None:
    RONTGEN.mkdir(parents=True, exist_ok=True)
    denetim = []
    esyalar(denetim)
    kabuklar(denetim)
    konsol()
    cantalar()
    # denetim sayfası
    hucre = 200
    sutun = 8
    satir = (len(denetim) + sutun - 1) // sutun
    sayfa = Image.new("RGB", (sutun * hucre, satir * hucre), (0, 0, 0))
    ciz = ImageDraw.Draw(sayfa)
    for i, (ad, g) in enumerate(denetim):
        g = g.copy()
        g.thumbnail((hucre - 10, hucre - 26))
        x, y = (i % sutun) * hucre, (i // sutun) * hucre
        sayfa.paste(g, (x + (hucre - g.width) // 2, y + 20 + (hucre - 26 - g.height) // 2))
        ciz.text((x + 4, y + 3), ad, fill=(120, 255, 160))
    sayfa.save(HAM / "rontgen_denetim.jpg", quality=88)


if __name__ == "__main__":
    main()
