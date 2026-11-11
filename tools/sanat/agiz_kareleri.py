"""Konuşma canlandırması için ağız karelerini üretir.

Girdi: her portre sayfasının iki çeşitlemesi (ağız hafif açık / açık) — tools/sanat/ham/agiz1_*.png,
agiz2_*.png. Her kişi için çeşitlemedeki yüz, göz ve burun noktalarından ana portreye hizalanır;
yalnızca alt yüz bölgesi (ağız, çene) yumuşak kenarlı bir maske ile kesilip iki karelik küçük bir
atlas olarak kaydedilir. Oyun bu kareleri portrenin üstüne bindirerek ağzı oynatır (portre.gdshader).

Çıktı: assets/img/portre/agiz/<kimlik>.webp  (yan yana 2 kare)
       data/portreler.json → "agiz_kare": [x, y, en, boy]  (ana portreye oranlı, 0..1)
Denetim: tools/sanat/ham/agiz_denetim_*.jpg

Kullanım: python tools/sanat/agiz_kareleri.py
"""
import json
import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from dilimle import HAVUZ, HIKAYE, OMUZ_GENISLIGI, bilesenler  # noqa: E402

KOK = Path(__file__).resolve().parents[2]
HAM = Path(__file__).resolve().parent / "ham"
PORTRE = KOK / "assets" / "img" / "portre"
AGIZ = PORTRE / "agiz"
KUNYE = KOK / "data" / "portreler.json"
DOLGU = 3  # atlasta kareler arası saydam pay (piksel)


def yuz_noktalari(bulucu, rgba: np.ndarray):
    """YuNet ile iki göz ve burun noktası (piksel). Bulunamazsa None."""
    zemin = np.full(rgba.shape[:2] + (3,), (128, 134, 128), np.uint8)
    a = rgba[..., 3:4].astype(np.float32) / 255.0
    bgr = (rgba[..., :3][..., ::-1] * a + zemin * (1 - a)).astype(np.uint8)
    buyuk = cv2.resize(bgr, None, fx=2, fy=2, interpolation=cv2.INTER_CUBIC)
    bulucu.setInputSize((buyuk.shape[1], buyuk.shape[0]))
    _, yuzler = bulucu.detect(buyuk)
    if yuzler is None or len(yuzler) == 0:
        return None
    f = [float(t) / 2 for t in max(yuzler, key=lambda r: r[2] * r[3])]
    g1, g2 = (f[4], f[5]), (f[6], f[7])
    if g1[0] > g2[0]:
        g1, g2 = g2, g1
    return np.array([g1, g2, (f[8], f[9])], np.float32)


def kisi_isle(bulucu, kimlik: str, ana: np.ndarray, cesitler: list, bilgi: dict, denetim: list) -> bool:
    h, w = ana.shape[:2]
    ana_n = np.array([[bilgi["goz"][0][0] * w, bilgi["goz"][0][1] * h],
                      [bilgi["goz"][1][0] * w, bilgi["goz"][1][1] * h],
                      [bilgi["burun"][0] * w, bilgi["burun"][1] * h]], np.float32)
    agiz = np.array([bilgi["agiz"][0] * w, bilgi["agiz"][1] * h])
    burun_y = bilgi["burun"][1] * h
    cene_y = bilgi["cene"] * h
    goz_arasi = bilgi["goz_arasi"] * w

    # Alt yüz bölgesi: burnun hemen altından çenenin biraz altına
    x0 = int(max(0, agiz[0] - goz_arasi * 1.02))
    x1 = int(min(w, agiz[0] + goz_arasi * 1.02))
    y0 = int(max(0, burun_y + (agiz[1] - burun_y) * 0.30))
    y1 = int(min(h, cene_y + h * 0.050))
    pw, ph = x1 - x0, y1 - y0
    if pw < 16 or ph < 16:
        return False
    # yumuşak kenarlı elips maske
    yy, xx = np.mgrid[0:ph, 0:pw].astype(np.float32)
    r = np.sqrt(((xx - pw / 2) / (pw / 2)) ** 2 + ((yy - ph * 0.46) / (ph * 0.56)) ** 2)
    maske = np.clip((1.0 - r) / 0.30, 0.0, 1.0)
    maske = maske * maske * (3 - 2 * maske)

    ana_rgb = ana[y0:y1, x0:x1, :3].astype(np.float32)
    kareler = []
    onizleme = [ana[..., :3].copy()]
    for cesit in cesitler:
        if cesit.shape[:2] != ana.shape[:2]:
            cesit = cv2.resize(cesit, (w, h), interpolation=cv2.INTER_LANCZOS4)
        n = yuz_noktalari(bulucu, cesit)
        if n is None:
            return False
        m, _ = cv2.estimateAffinePartial2D(n, ana_n, method=cv2.LMEDS)
        if m is None:
            return False
        hizali = cv2.warpAffine(cesit, m, (w, h), flags=cv2.INTER_LANCZOS4, borderMode=cv2.BORDER_CONSTANT,
                                borderValue=(0, 0, 0, 0))
        yama = hizali[y0:y1, x0:x1, :3].astype(np.float32)
        yama_alfa = hizali[y0:y1, x0:x1, 3].astype(np.float32) / 255.0
        ana_alfa = ana[y0:y1, x0:x1, 3].astype(np.float32) / 255.0
        # Kenar bandında ana portreyle ton farkını gider (yeniden boyamada renk biraz oynayabilir).
        bant = (maske > 0.03) & (maske < 0.45) & (yama_alfa > 0.9) & (ana_alfa > 0.9)
        if bant.sum() > 40:
            yama += (ana_rgb[bant].mean(axis=0) - yama[bant].mean(axis=0))
        alfa = maske * np.minimum(yama_alfa, ana_alfa)
        kare = np.dstack([np.clip(yama, 0, 255), alfa * 255.0]).astype(np.uint8)
        kareler.append(kare)
        birlesik = ana[..., :3].astype(np.float32).copy()
        birlesik[y0:y1, x0:x1] = birlesik[y0:y1, x0:x1] * (1 - alfa[..., None]) + np.clip(yama, 0, 255) * alfa[..., None]
        onizleme.append(birlesik.astype(np.uint8))

    atlas = np.zeros((ph + 2 * DOLGU, 2 * (pw + 2 * DOLGU), 4), np.uint8)
    for i, kare in enumerate(kareler):
        ox = i * (pw + 2 * DOLGU) + DOLGU
        atlas[DOLGU:DOLGU + ph, ox:ox + pw] = kare
    Image.fromarray(atlas, "RGBA").save(AGIZ / f"{kimlik}.webp", quality=92, method=4, alpha_quality=100)
    bilgi["agiz_kare"] = [round(x0 / w, 4), round(y0 / h, 4), round(pw / w, 4), round(ph / h, 4)]

    # denetim: yüz bölgesi — kapalı | hafif açık | açık
    yx0, yx1 = int(max(0, agiz[0] - goz_arasi * 1.9)), int(min(w, agiz[0] + goz_arasi * 1.9))
    yy0, yy1 = int(max(0, burun_y - goz_arasi * 1.7)), int(min(h, cene_y + h * 0.06))
    serit = np.hstack([cv2.resize(o[yy0:yy1, yx0:yx1], (150, 170)) for o in onizleme])
    cv2.putText(serit, kimlik, (4, 14), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (255, 255, 0), 1)
    denetim.append(serit)
    return True


def sayfa_kisileri(ad: str, adet: int, satir: int, olcek_fn):
    """Bir sayfadaki kişilerin ana ölçekte RGBA görüntüleri (satır satır)."""
    im = Image.open(HAM / f"{ad}.png").convert("RGBA")
    kutular = bilesenler(im, adet, satir)
    olcek = olcek_fn(kutular)
    kisiler = []
    for (x0, y0, x1, y1) in kutular:
        parca = im.crop((max(0, x0 - 2), max(0, y0 - 2), min(im.width, x1 + 2), min(im.height, y1 + 2)))
        parca = parca.resize((max(1, round(parca.width * olcek)), max(1, round(parca.height * olcek))), Image.LANCZOS)
        kisiler.append(np.array(parca))
    return kisiler


def havuz_olcegi(kutular):
    g = sorted(k[2] - k[0] for k in kutular)
    return OMUZ_GENISLIGI / g[len(g) // 2]


def hikaye_olcegi(kutular):
    g = sorted(k[2] - k[0] for k in kutular)[-6:]
    return OMUZ_GENISLIGI / (sum(g) / len(g))


def main() -> None:
    AGIZ.mkdir(parents=True, exist_ok=True)
    kunye = json.loads(KUNYE.read_text(encoding="utf-8"))
    bulucu = cv2.FaceDetectorYN.create(str(HAM / "yunet.onnx"), "", (320, 320), 0.5, 0.3, 50)
    denetim, basarisiz = [], []

    gruplar = []
    no = 0
    for sayfa in HAVUZ:
        ek = sayfa.split("_")[1]
        kimlikler = [f"v{no + i + 1:02d}" for i in range(16)]
        no += 16
        gruplar.append((ek, kimlikler, 16, 4, havuz_olcegi))
    gruplar.append(("hikaye", [k for k, _, _ in HIKAYE], 12, 3, hikaye_olcegi))

    for ek, kimlikler, adet, satir, olcek_fn in gruplar:
        y1, y2 = HAM / f"agiz1_{ek}.png", HAM / f"agiz2_{ek}.png"
        if not (y1.exists() and y2.exists()):
            print(f"{ek}: çeşitleme sayfaları yok, atlandı")
            continue
        c1 = sayfa_kisileri(f"agiz1_{ek}", adet, satir, olcek_fn)
        c2 = sayfa_kisileri(f"agiz2_{ek}", adet, satir, olcek_fn)
        tamam = 0
        for i, kimlik in enumerate(kimlikler):
            ana = np.array(Image.open(PORTRE / f"{kimlik}.webp").convert("RGBA"))
            if kisi_isle(bulucu, kimlik, ana, [c1[i], c2[i]], kunye[kimlik], denetim):
                tamam += 1
            else:
                basarisiz.append(kimlik)
                kunye[kimlik].pop("agiz_kare", None)
        print(f"{ek}: {tamam}/{len(kimlikler)} kişi")

    KUNYE.write_text(json.dumps(kunye, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8")
    print("başarısız:", basarisiz)
    for s in range(0, len(denetim), 24):
        parca = denetim[s:s + 24]
        satirlar = [np.hstack(parca[i:i + 4] + [np.zeros_like(parca[0])] * (4 - len(parca[i:i + 4]))) for i in range(0, len(parca), 4)]
        cv2.imwrite(str(HAM / f"agiz_denetim_{s // 24}.jpg"), cv2.cvtColor(np.vstack(satirlar), cv2.COLOR_RGB2BGR),
                    [cv2.IMWRITE_JPEG_QUALITY, 90])


if __name__ == "__main__":
    main()
