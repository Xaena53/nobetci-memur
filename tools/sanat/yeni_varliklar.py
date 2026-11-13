"""1.5.0 ile gelen boyalı varlıkları ham sayfalardan (tools/sanat/ham/yeni/) dilimler.

  takvim.png    yedi takvim yaprağı (koyu zeminde)      → assets/img/nesne/takvim_<gün>.webp
  saat.png      çevirmeli saat, rakam kartları, ibreler  → assets/img/nesne/saat_*.webp
  mutfak.png    tencere, çaydanlık, kestane tavası       → assets/img/nesne/{tencere,caydanlik,kestane}.webp
  kolluk.png    iki kolluk görevlisi büstü               → assets/img/portre/kolluk_{1,2}.webp

İbrelerin dönme merkezi (halkanın ortası) ve yaprakların ölçüleri data/varliklar.json dosyasına yazılır.

Kullanım: python tools/sanat/yeni_varliklar.py
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

KOK = Path(__file__).resolve().parents[2]
HAM = Path(__file__).resolve().parent / "ham" / "yeni"
IMG = KOK / "assets" / "img"
GUNLER = [9, 10, 11, 12, 13, 16, 17]


def parcalar(alfa: np.ndarray, en_az: int = 400, sisirme: int = 6) -> list:
    """Bağlantılı parçaların kutuları (x0, y0, x1, y1), alanı `en_az`dan büyük olanlar."""
    maske = ndimage.binary_dilation(alfa > 24, iterations=sisirme)
    etiket, adet = ndimage.label(maske)
    cikti = []
    for no, dilim in enumerate(ndimage.find_objects(etiket), 1):
        if ndimage.sum(alfa > 24, etiket, no) < en_az:
            continue
        cikti.append((dilim[1].start, dilim[0].start, dilim[1].stop, dilim[0].stop))
    return cikti


def kes(im: Image.Image, kutu: tuple, en: int, pay: int = 4) -> Image.Image:
    x0, y0, x1, y1 = kutu
    parca = im.crop((max(0, x0 - pay), max(0, y0 - pay), min(im.width, x1 + pay), min(im.height, y1 + pay)))
    kutu2 = parca.getchannel("A").point(lambda v: 255 if v > 12 else 0).getbbox()
    parca = parca.crop(kutu2)
    if parca.width > en:
        parca = parca.resize((en, max(1, round(parca.height * en / parca.width))), Image.LANCZOS)
    return parca


def yaz(parca: Image.Image, yol: Path) -> None:
    yol.parent.mkdir(parents=True, exist_ok=True)
    parca.save(yol, quality=93, method=6, alpha_quality=100)
    print(f"  {yol.relative_to(KOK).as_posix()}: {parca.width}x{parca.height}")


def satir_sirasi(kutular: list, satir_boyu: float) -> list:
    """Kutuları okuma sırasına dizer (önce satır, sonra soldan sağa)."""
    return sorted(kutular, key=lambda k: (round(((k[1] + k[3]) / 2) / satir_boyu), k[0]))


def takvim(bilgi: dict) -> None:
    im = Image.open(HAM / "takvim.png").convert("RGB")
    a = np.array(im).astype(np.float32)
    zemin = np.median(a[:40, :40].reshape(-1, 3), axis=0)
    uzak = np.sqrt(((a - zemin) ** 2).sum(axis=2))
    alfa = np.clip((uzak - 26.0) / 30.0, 0.0, 1.0)
    alfa = ndimage.binary_fill_holes(alfa > 0.5) * 1.0 * np.maximum(alfa, ndimage.binary_erosion(ndimage.binary_fill_holes(alfa > 0.5), iterations=2))
    rgba = Image.fromarray(np.dstack([a, alfa * 255.0]).astype(np.uint8), "RGBA")
    kutular = satir_sirasi(parcalar(np.array(rgba.getchannel("A")), 20000, 2), im.height / 2)
    assert len(kutular) == 7, f"7 yaprak bekleniyordu, {len(kutular)} bulundu"
    for gun, kutu in zip(GUNLER, kutular):
        yaz(kes(rgba, kutu, 248), IMG / "nesne" / f"takvim_{gun:02d}.webp")
    bilgi["takvim_gunleri"] = GUNLER


def saat(bilgi: dict) -> None:
    im = Image.open(HAM / "saat.png").convert("RGBA")
    alfa = np.array(im.getchannel("A"))
    kutular = parcalar(alfa, 1500, 3)
    h = im.height
    ust = [k for k in kutular if (k[1] + k[3]) / 2 < h * 0.42]
    orta = sorted([k for k in kutular if h * 0.42 <= (k[1] + k[3]) / 2 < h * 0.70], key=lambda k: k[0])
    alt = sorted([k for k in kutular if (k[1] + k[3]) / 2 >= h * 0.70], key=lambda k: k[1])
    assert len(ust) == 1 and len(orta) == 11 and len(alt) == 3, (len(ust), len(orta), len(alt))
    govde = kes(im, ust[0], 360)
    yaz(govde, IMG / "nesne" / "saat_govde.webp")
    # gösterge penceresinin gövdedeki yeri: gövdenin ortasındaki koyu dikdörtgen
    g = np.array(govde.convert("RGB")).astype(np.float32).sum(axis=2)
    koyu = (g < 140) & (np.array(govde.getchannel("A")) > 200)
    et, n = ndimage.label(koyu)
    en_buyuk = int(np.argmax(ndimage.sum(koyu, et, range(1, n + 1)))) + 1
    d = ndimage.find_objects(et)[en_buyuk - 1]
    bilgi["saat_pencere"] = [round(v, 4) for v in (d[1].start / govde.width, d[0].start / govde.height,
                             (d[1].stop - d[1].start) / govde.width, (d[0].stop - d[0].start) / govde.height)]
    for i, kutu in enumerate(orta):
        ad = f"saat_rakam_{i}" if i < 10 else "saat_iki_nokta"
        yaz(kes(im, kutu, 72), IMG / "nesne" / f"{ad}.webp")
    for ad, kutu in zip(["saat_akrep", "saat_yelkovan", "saat_saniye"], alt):
        parca = kes(im, kutu, 300)
        yaz(parca, IMG / "nesne" / f"{ad}.webp")
        # dönme merkezi: soldaki halkanın ortası (halkanın yüksekliği = ibrenin sol ucundaki en büyük kalınlık)
        pa = np.array(parca.getchannel("A")) > 60
        delik = ndimage.binary_fill_holes(pa) & ~pa
        delik[:, parca.width // 3:] = False
        ys, xs = np.nonzero(delik if delik.any() else pa[:, : max(4, parca.height // 2)])
        bilgi[ad] = [round(float(xs.mean()) / parca.width, 4), round(float(ys.mean()) / parca.height, 4)]


def mutfak() -> None:
    im = Image.open(HAM / "mutfak.png").convert("RGBA")
    kutular = sorted(parcalar(np.array(im.getchannel("A")), 5000, 4), key=lambda k: k[0])
    assert len(kutular) == 3, len(kutular)
    for ad, kutu in zip(["tencere", "caydanlik", "kestane"], kutular):
        yaz(kes(im, kutu, 220), IMG / "nesne" / f"{ad}.webp")


def kolluk() -> None:
    im = Image.open(HAM / "kolluk.png").convert("RGBA")
    kutular = sorted(parcalar(np.array(im.getchannel("A")), 50000, 2), key=lambda k: k[0])
    assert len(kutular) == 2, len(kutular)
    for i, kutu in enumerate(kutular, 1):
        yaz(kes(im, kutu, 430), IMG / "portre" / f"kolluk_{i}.webp")


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    bilgi = {"aciklama": "tools/sanat/yeni_varliklar.py üretir: ibrelerin dönme merkezi (0..1), saatin gösterge penceresi (0..1), takvim yaprakları."}
    takvim(bilgi)
    saat(bilgi)
    mutfak()
    kolluk()
    (KOK / "data" / "varliklar.json").write_text(json.dumps(bilgi, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8", newline="\n")
    print("data/varliklar.json yazıldı")


if __name__ == "__main__":
    main()
