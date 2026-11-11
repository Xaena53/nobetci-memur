"""Portrelerdeki göz, burun ve ağız noktalarını bulup data/portreler.json'a yazar.

Oyun bu noktaları portreyi canlandırmak için kullanır (göz kırpma, konuşurken çene, öfleme).
Yüz bulucu: OpenCV'nin YuNet modeli (tools/sanat/ham/yunet.onnx; opencv_zoo'dan indirilir).
Bütün koordinatlar görselin genişlik/yüksekliğine oranlıdır (0..1).

Kullanım: python tools/sanat/yuz_noktalari.py     (denetim görseli: tools/sanat/ham/yuz_denetim.jpg)
"""
import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

KOK = Path(__file__).resolve().parents[2]
HAM = Path(__file__).resolve().parent / "ham"
PORTRE = KOK / "assets" / "img" / "portre"
KUNYE = KOK / "data" / "portreler.json"
BUYUTME = 2  # küçük yüzlerde bulucu daha kararlı çalışsın
GOZU_KAPALI = {"murat"}  # koyu gözlüklüler: göz kırpma çizilmez


def main() -> None:
    kunye = json.loads(KUNYE.read_text(encoding="utf-8"))
    bulucu = cv2.FaceDetectorYN.create(str(HAM / "yunet.onnx"), "", (320, 320), 0.5, 0.3, 50)
    kareler = []
    bulunamayan = []
    for kimlik in sorted(kunye):
        im = Image.open(PORTRE / f"{kimlik}.webp").convert("RGBA")
        w, h = im.size
        zemin = Image.new("RGBA", im.size, (128, 134, 128, 255))
        zemin.alpha_composite(im)
        bgr = cv2.cvtColor(np.array(zemin.convert("RGB")), cv2.COLOR_RGB2BGR)
        buyuk = cv2.resize(bgr, (w * BUYUTME, h * BUYUTME), interpolation=cv2.INTER_CUBIC)
        bulucu.setInputSize((buyuk.shape[1], buyuk.shape[0]))
        _, yuzler = bulucu.detect(buyuk)
        if yuzler is None or len(yuzler) == 0:
            bulunamayan.append(kimlik)
            continue
        f = [float(t) / BUYUTME for t in max(yuzler, key=lambda r: r[2] * r[3])]
        x, y, fw, fh = f[0:4]
        goz_a, goz_b = (f[4], f[5]), (f[6], f[7])            # görüntüde soldaki / sağdaki göz
        if goz_a[0] > goz_b[0]:
            goz_a, goz_b = goz_b, goz_a
        burun = (f[8], f[9])
        agiz_a, agiz_b = (f[10], f[11]), (f[12], f[13])
        agiz = ((agiz_a[0] + agiz_b[0]) / 2, (agiz_a[1] + agiz_b[1]) / 2)
        gozler_arasi = float(np.hypot(goz_b[0] - goz_a[0], goz_b[1] - goz_a[1]))
        b = kunye[kimlik]
        b["goz"] = [[round(goz_a[0] / w, 4), round(goz_a[1] / h, 4)], [round(goz_b[0] / w, 4), round(goz_b[1] / h, 4)]]
        b["burun"] = [round(burun[0] / w, 4), round(burun[1] / h, 4)]
        b["agiz"] = [round(agiz[0] / w, 4), round(agiz[1] / h, 4)]
        b["agiz_gen"] = round(abs(agiz_b[0] - agiz_a[0]) / w, 4)
        b["goz_arasi"] = round(gozler_arasi / w, 4)
        b["cene"] = round(min(1.0, (y + fh) / h), 4)          # yüz kutusunun altı ≈ çene
        b["oran"] = round(w / h, 4)
        if kimlik in GOZU_KAPALI:
            b["gozu_kapali"] = True

        # denetim görseli
        cizim = bgr.copy()
        for p in (goz_a, goz_b):
            cv2.circle(cizim, (int(p[0]), int(p[1])), 4, (0, 255, 255), -1)
        cv2.circle(cizim, (int(burun[0]), int(burun[1])), 4, (255, 128, 0), -1)
        cv2.line(cizim, (int(agiz_a[0]), int(agiz_a[1])), (int(agiz_b[0]), int(agiz_b[1])), (0, 0, 255), 3)
        cv2.line(cizim, (int(x), int(y + fh)), (int(x + fw), int(y + fh)), (0, 255, 0), 2)
        cv2.putText(cizim, kimlik, (4, 16), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)
        kareler.append(cv2.resize(cizim, (210, 210 * h // w)))

    KUNYE.write_text(json.dumps(kunye, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8")
    print(f"{len(kunye) - len(bulunamayan)} portrede yüz bulundu; bulunamayan: {bulunamayan}")

    sutun = 10
    yuk = max(k.shape[0] for k in kareler)
    satir = (len(kareler) + sutun - 1) // sutun
    sayfa = np.full((satir * yuk, sutun * 210, 3), 90, np.uint8)
    for i, k in enumerate(kareler):
        r, c = divmod(i, sutun)
        sayfa[r * yuk:r * yuk + k.shape[0], c * 210:c * 210 + 210] = k
    cv2.imwrite(str(HAM / "yuz_denetim.jpg"), sayfa, [cv2.IMWRITE_JPEG_QUALITY, 88])


if __name__ == "__main__":
    main()
