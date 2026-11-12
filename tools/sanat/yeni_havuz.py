"""Havuza sonradan eklenen 25 kişiyi (havuz_e.png, 5x5) oyuna alır: v65..v89.

Yaptıkları:
  1. Portreleri keser (assets/img/portre/vNN.webp) ve künyeye cinsiyet ile yaşı yazar.
  2. Yüz noktalarını bulur (göz, burun, ağız, çene): canlandırma bunları kullanır.
  3. Konuşma karelerini üretir. Bu sayfanın yalnızca "ağız açık" çeşitlemesi vardır (agiz2_e.png);
     "hafif açık" kare, açık kareden bükülerek üretilir (agiz_ara_kare.py).
Vesikalıklar ve benzerlik listeleri için ardından tools/sanat/vesikalik.py çalıştırılır.

Kullanım: python tools/sanat/yeni_havuz.py && python tools/sanat/vesikalik.py
"""
import json
import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import agiz_ara_kare  # noqa: E402
import agiz_kareleri  # noqa: E402
import kadro  # noqa: E402
from dilimle import OMUZ_GENISLIGI, bilesenler, kaydet  # noqa: E402

KOK = Path(__file__).resolve().parents[2]
HAM = Path(__file__).resolve().parent / "ham"
PORTRE = KOK / "assets" / "img" / "portre"
KUNYE = KOK / "data" / "portreler.json"
ADET, SATIR = 25, 5


def olcek_bul(kutular) -> float:
    g = sorted(k[2] - k[0] for k in kutular)
    return OMUZ_GENISLIGI / g[len(g) // 2]


def noktalari_yaz(bulucu, kimlik: str, bilgi: dict) -> bool:
    """tools/sanat/yuz_noktalari.py ile aynı ölçüm, tek kişi için."""
    im = Image.open(PORTRE / f"{kimlik}.webp").convert("RGBA")
    w, h = im.size
    zemin = Image.new("RGBA", im.size, (128, 134, 128, 255))
    zemin.alpha_composite(im)
    bgr = cv2.cvtColor(np.array(zemin.convert("RGB")), cv2.COLOR_RGB2BGR)
    buyuk = cv2.resize(bgr, (w * 2, h * 2), interpolation=cv2.INTER_CUBIC)
    bulucu.setInputSize((buyuk.shape[1], buyuk.shape[0]))
    _, yuzler = bulucu.detect(buyuk)
    if yuzler is None or len(yuzler) == 0:
        return False
    f = [float(t) / 2 for t in max(yuzler, key=lambda r: r[2] * r[3])]
    y, fh = f[1], f[3]
    goz_a, goz_b = (f[4], f[5]), (f[6], f[7])
    if goz_a[0] > goz_b[0]:
        goz_a, goz_b = goz_b, goz_a
    burun = (f[8], f[9])
    agiz_a, agiz_b = (f[10], f[11]), (f[12], f[13])
    agiz = ((agiz_a[0] + agiz_b[0]) / 2, (agiz_a[1] + agiz_b[1]) / 2)
    bilgi["goz"] = [[round(goz_a[0] / w, 4), round(goz_a[1] / h, 4)], [round(goz_b[0] / w, 4), round(goz_b[1] / h, 4)]]
    bilgi["burun"] = [round(burun[0] / w, 4), round(burun[1] / h, 4)]
    bilgi["agiz"] = [round(agiz[0] / w, 4), round(agiz[1] / h, 4)]
    bilgi["agiz_gen"] = round(abs(agiz_b[0] - agiz_a[0]) / w, 4)
    bilgi["goz_arasi"] = round(float(np.hypot(goz_b[0] - goz_a[0], goz_b[1] - goz_a[1])) / w, 4)
    bilgi["cene"] = round(min(1.0, (y + fh) / h), 4)
    bilgi["oran"] = round(w / h, 4)
    return True


def main() -> None:
    kunye = json.loads(KUNYE.read_text(encoding="utf-8"))
    kisiler = kadro.YENI_HAVUZ.split()
    kimlikler = [f"v{kadro.ILK_YENI + i:02d}" for i in range(ADET)]

    # 1. portreler
    im = Image.open(HAM / "havuz_e.png").convert("RGBA")
    kutular = bilesenler(im, ADET, SATIR)
    olcek = olcek_bul(kutular)
    for kimlik, kisi, kutu in zip(kimlikler, kisiler, kutular):
        kaydet(im, kutu, olcek, PORTRE / f"{kimlik}.webp")
        eski = kunye.get(kimlik, {})
        kunye[kimlik] = {"cinsiyet": kisi[0], "yas": int(kisi[1:])}
        for alan in ("benzer", "ozel"):
            if alan in eski:
                kunye[kimlik][alan] = eski[alan]
    print(f"havuz_e: {ADET} portre, ölçek {olcek:.3f}")

    # 2. yüz noktaları
    bulucu = cv2.FaceDetectorYN.create(str(HAM / "yunet.onnx"), "", (320, 320), 0.5, 0.3, 50)
    bulunamayan = [k for k in kimlikler if not noktalari_yaz(bulucu, k, kunye[k])]
    print("yüzü bulunamayan:", bulunamayan)

    # 3. konuşma kareleri (tek çeşitlemeden)
    agiz_kareleri.AGIZ.mkdir(parents=True, exist_ok=True)
    acik = agiz_kareleri.sayfa_kisileri("agiz2_e", ADET, SATIR, olcek_bul)
    denetim, basarisiz, ara_denetim = [], [], []
    for kimlik, cesit in zip(kimlikler, acik):
        if kimlik in bulunamayan:
            continue
        ana = np.array(Image.open(PORTRE / f"{kimlik}.webp").convert("RGBA"))
        if not agiz_kareleri.kisi_isle(bulucu, kimlik, ana, [cesit, cesit], kunye[kimlik], denetim):
            basarisiz.append(kimlik)
            kunye[kimlik].pop("agiz_kare", None)
            continue
        # atlasın ilk karesi "hafif açık": açık kareden bükülerek üretilir (bkz. agiz_ara_kare.py)
        (agiz_ara_kare.YEDEK / f"{kimlik}.png").unlink(missing_ok=True)
        agiz_ara_kare.isle(kimlik, kunye[kimlik], ara_denetim)
    print(f"konuşma kareleri: {ADET - len(basarisiz) - len(bulunamayan)}/{ADET}; başarısız: {basarisiz}")
    KUNYE.write_text(json.dumps(kunye, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8")
    if denetim:
        satirlar = [np.hstack(denetim[i:i + 5] + [np.zeros_like(denetim[0])] * (5 - len(denetim[i:i + 5]))) for i in range(0, len(denetim), 5)]
        cv2.imwrite(str(HAM / "agiz_denetim_e.jpg"), cv2.cvtColor(np.vstack(satirlar), cv2.COLOR_RGB2BGR), [cv2.IMWRITE_JPEG_QUALITY, 90])


if __name__ == "__main__":
    main()
