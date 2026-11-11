"""Ev sahnesindeki tam boy aile figürlerini dilimler ve yüz noktalarını çıkarır.

Girdi: tools/sanat/ham/aile_boy.png (saydam zeminde yan yana üç figür: anne, Elif, Can).
Çıktı: assets/img/portre/{anne,elif,can}_boy.webp ve data/portreler.json içindeki künyeleri.
Figürler tek ölçekle küçültülür; birbirlerine göre boyları korunur.

Kullanım: python tools/sanat/aile_figurleri.py     (denetim: tools/sanat/ham/aile_denetim.jpg)
"""
import json
import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from dilimle import bilesenler, kaydet  # noqa: E402

KOK = Path(__file__).resolve().parents[2]
HAM = Path(__file__).resolve().parent / "ham"
PORTRE = KOK / "assets" / "img" / "portre"
KUNYE = KOK / "data" / "portreler.json"
ANNE_BOYU = 800  # annenin (sandalyesiyle) görseldeki boyu; ekranda bunun yarısı kadar çizilir

# (kimlik, cinsiyet, yaş, nefesin bittiği çizgi 0..1, göz kırpar mı)
FIGURLER = [("anne_boy", "K", 72, 0.52, True), ("elif_boy", "K", 8, 0.62, False), ("can_boy", "E", 4, 0.72, True)]
# Yüzü bulucuya yakalanmayan figürler için elle ölçülmüş noktalar (0..1): Elif başını deftere eğmiştir.
ELLE = {}


def main() -> None:
    im = Image.open(HAM / "aile_boy.png").convert("RGBA")
    kutular = bilesenler(im, 3, 1)
    olcek = ANNE_BOYU / (kutular[0][3] - kutular[0][1])
    kunye = json.loads(KUNYE.read_text(encoding="utf-8"))
    bulucu = cv2.FaceDetectorYN.create(str(HAM / "yunet.onnx"), "", (320, 320), 0.4, 0.3, 50)
    kareler = []
    for kutu, (kimlik, cinsiyet, yas, nefes_alti, kirpar) in zip(kutular, FIGURLER):
        w, h = kaydet(im, kutu, olcek, PORTRE / f"{kimlik}.webp")
        b = {"cinsiyet": cinsiyet, "yas": yas, "ozel": True, "tam_boy": True, "oran": round(w / h, 4),
             "nefes_alti": nefes_alti, "nefes_gucu": 0.45}
        parca = Image.open(PORTRE / f"{kimlik}.webp").convert("RGBA")
        zemin = Image.new("RGBA", parca.size, (128, 134, 128, 255))
        zemin.alpha_composite(parca)
        bgr = cv2.cvtColor(np.array(zemin.convert("RGB")), cv2.COLOR_RGB2BGR)
        # yüz görselin üst bölümünde: bulucuya yalnızca orayı, büyüterek ver
        ust = bgr[: int(h * 0.55)]
        buyuk = cv2.resize(ust, None, fx=2, fy=2, interpolation=cv2.INTER_CUBIC)
        bulucu.setInputSize((buyuk.shape[1], buyuk.shape[0]))
        _, yuzler = bulucu.detect(buyuk)
        if yuzler is not None and len(yuzler) > 0 and kimlik not in ELLE:
            f = [float(t) / 2 for t in max(yuzler, key=lambda r: r[2] * r[3])]
            x, y, fw, fh = f[0:4]
            ga, gb = (f[4], f[5]), (f[6], f[7])
            if ga[0] > gb[0]:
                ga, gb = gb, ga
            aa, ab = (f[10], f[11]), (f[12], f[13])
            b["goz"] = [[round(ga[0] / w, 4), round(ga[1] / h, 4)], [round(gb[0] / w, 4), round(gb[1] / h, 4)]]
            b["burun"] = [round(f[8] / w, 4), round(f[9] / h, 4)]
            b["agiz"] = [round((aa[0] + ab[0]) / 2 / w, 4), round((aa[1] + ab[1]) / 2 / h, 4)]
            b["agiz_gen"] = round(abs(ab[0] - aa[0]) / w, 4)
            b["goz_arasi"] = round(float(np.hypot(gb[0] - ga[0], gb[1] - ga[1])) / w, 4)
            b["cene"] = round((y + fh) / h, 4)
            b["boyun_olcegi"] = round(min(1.0, fh / h / 0.36), 3)   # büstte yüz, görselin ~%36'sıdır
            for p in (ga, gb):
                cv2.circle(bgr, (int(p[0]), int(p[1])), 4, (0, 255, 255), -1)
            cv2.line(bgr, (int(aa[0]), int(aa[1])), (int(ab[0]), int(ab[1])), (0, 0, 255), 2)
            cv2.line(bgr, (int(x), int(y + fh)), (int(x + fw), int(y + fh)), (0, 255, 0), 2)
            print(f"{kimlik}: {w}x{h}, yüz bulundu, boyun ölçeği {b['boyun_olcegi']}")
        elif kimlik in ELLE:
            b.update(ELLE[kimlik])
            print(f"{kimlik}: {w}x{h}, elle girilen noktalar")
        else:
            print(f"{kimlik}: {w}x{h}, YÜZ BULUNAMADI")
        if not kirpar:
            b["gozu_kapali"] = True
        cv2.line(bgr, (0, int(nefes_alti * h)), (w, int(nefes_alti * h)), (255, 0, 255), 1)
        kunye[kimlik] = b
        kareler.append(bgr)
    KUNYE.write_text(json.dumps(kunye, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8")
    yuk = max(k.shape[0] for k in kareler)
    sayfa = np.full((yuk, sum(k.shape[1] for k in kareler), 3), 90, np.uint8)
    x = 0
    for k in kareler:
        sayfa[: k.shape[0], x:x + k.shape[1]] = k
        x += k.shape[1]
    cv2.imwrite(str(HAM / "aile_denetim.jpg"), sayfa, [cv2.IMWRITE_JPEG_QUALITY, 90])


if __name__ == "__main__":
    main()
