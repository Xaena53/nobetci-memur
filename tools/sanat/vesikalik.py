"""Nüfus cüzdanlarındaki vesikalık fotoğrafları ve arananlar listesinin eski resimlerini üretir.

Girdi: her portre sayfasının "yıllar önceki hâli" çeşitlemesi (aynı kişiler; başka kıyafet, başka saç,
şapkasız) — tools/sanat/ham/vesika_a..d.png (havuz) ve vesika_hikaye.png (hikâye karakterleri ile
arananların eski dosya resimleri; düzeni HIKAYE_SAYFASI'nda).

Her kişi yüz noktalarına göre (YuNet) aynı kadraja oturtulur: gözler karenin belirli bir yerinde,
baş ve omuzlar görünür. Böylece vesikalıklar, gişedeki büstten ayrı bir çekim gibi durur.

Ayrıca yüz benzerliği ölçülür (OpenCV SFace): her kişi için "benzer" listesi çıkarılır. Sahte cüzdandaki
fotoğraf ve arananlara benzeyen masum vatandaşlar bu listeden seçilir.

Çıktı: assets/img/portre/vesika/<kimlik>.webp, assets/img/portre/aranan/<kimlik>.webp
       data/portreler.json → "benzer": [...], "aranan_benzer": [...]
Denetim: tools/sanat/ham/vesika_denetim_*.jpg

Kullanım: python tools/sanat/vesikalik.py
Gerekenler: tools/sanat/ham/yunet.onnx ve sface.onnx (opencv_zoo)
"""
import json
import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from dilimle import HAVUZ, bilesenler  # noqa: E402

KOK = Path(__file__).resolve().parents[2]
HAM = Path(__file__).resolve().parent / "ham"
PORTRE = KOK / "assets" / "img" / "portre"
VESIKA = PORTRE / "vesika"
ARANAN = PORTRE / "aranan"
KUNYE = KOK / "data" / "portreler.json"

# vesika_hikaye.png: üst sırada 4, alt sırada 3 kişi. (kimlik, klasör)
HIKAYE_SAYFASI = [("husnu", VESIKA), ("nermin", VESIKA), ("rusvetci", VESIKA), ("murat", VESIKA),
                  ("evsahibi", VESIKA), ("v27", ARANAN), ("v22", ARANAN)]

KARE = (228, 288)        # vesikalığın pikseli (cüzdandaki 76x96 alanın üç katı)
GOZ_ARASI = 0.215        # iki göz arası / kare genişliği
GOZ_Y = 0.42             # gözlerin kare içindeki yüksekliği
BENZER_ADEDI = 6


def bgr_yap(rgba: np.ndarray) -> np.ndarray:
    zemin = np.full(rgba.shape[:2] + (3,), (128, 134, 128), np.uint8)
    a = rgba[..., 3:4].astype(np.float32) / 255.0
    return (rgba[..., :3][..., ::-1] * a + zemin * (1 - a)).astype(np.uint8)


def yuz_bul(bulucu, rgba: np.ndarray):
    """YuNet satırı (kutu + 5 nokta + puan), 2 kat büyütülmüş görüntünün koordinatlarında."""
    buyuk = cv2.resize(bgr_yap(rgba), None, fx=2, fy=2, interpolation=cv2.INTER_CUBIC)
    bulucu.setInputSize((buyuk.shape[1], buyuk.shape[0]))
    _, yuzler = bulucu.detect(buyuk)
    if yuzler is None or len(yuzler) == 0:
        return None, buyuk
    return max(yuzler, key=lambda r: r[2] * r[3]), buyuk


def kadrajla(rgba: np.ndarray, yuz) -> Image.Image:
    """Gözleri sabit yere getirerek kişiyi vesikalık karesine oturtur (dışarıda kalan yer saydam)."""
    g1 = np.array([yuz[4], yuz[5]]) / 2.0
    g2 = np.array([yuz[6], yuz[7]]) / 2.0
    if g1[0] > g2[0]:
        g1, g2 = g2, g1
    orta = (g1 + g2) / 2.0
    olcek = (GOZ_ARASI * KARE[0]) / max(1.0, float(np.linalg.norm(g2 - g1)))
    m = np.array([[olcek, 0, KARE[0] / 2.0 - orta[0] * olcek],
                  [0, olcek, KARE[1] * GOZ_Y - orta[1] * olcek]], np.float32)
    # önce renkleri alfa ile çarp: saydam kenarlardan renk sızmasın
    f = rgba.astype(np.float32)
    f[..., :3] *= f[..., 3:4] / 255.0
    c = cv2.warpAffine(f, m, KARE, flags=cv2.INTER_AREA if olcek < 1 else cv2.INTER_CUBIC,
                       borderMode=cv2.BORDER_CONSTANT, borderValue=(0, 0, 0, 0))
    a = np.clip(c[..., 3:4], 0, 255)
    c[..., :3] = np.where(a > 1, c[..., :3] * 255.0 / np.maximum(a, 1), 0)
    return Image.fromarray(np.clip(c, 0, 255).astype(np.uint8), "RGBA")


def oznitelik(tanici, buyuk_bgr: np.ndarray, yuz) -> np.ndarray:
    hizali = tanici.alignCrop(buyuk_bgr, yuz)
    v = tanici.feature(hizali).flatten()
    return v / max(1e-9, float(np.linalg.norm(v)))


def sayfa_kisileri(yol: Path, adet: int, satir: int) -> list:
    im = Image.open(yol).convert("RGBA")
    return [np.array(im.crop(k)) for k in bilesenler(im, adet, satir)]


def hikaye_kisileri(yol: Path) -> list:
    """Üst sırada 4, alt sırada 3 büst."""
    im = Image.open(yol).convert("RGBA")
    # bilesenler eşit sütunlu ızgara bekler; burada sıralar eşit değil: elle sırala
    from scipy import ndimage
    alfa = np.array(im)[..., 3]
    etiket, n = ndimage.label(alfa > 24)
    dilimler = ndimage.find_objects(etiket)
    alanlar = ndimage.sum(alfa > 24, etiket, range(1, n + 1))
    buyukler = sorted(range(n), key=lambda i: -alanlar[i])[:7]
    kutular = [(dilimler[i][1].start, dilimler[i][0].start, dilimler[i][1].stop, dilimler[i][0].stop) for i in buyukler]
    kutular.sort(key=lambda k: (k[1] + k[3]) / 2)
    ust = sorted(kutular[:4], key=lambda k: k[0])
    alt = sorted(kutular[4:], key=lambda k: k[0])
    return [np.array(im.crop(k)) for k in ust + alt]


def main() -> None:
    VESIKA.mkdir(parents=True, exist_ok=True)
    ARANAN.mkdir(parents=True, exist_ok=True)
    kunye = json.loads(KUNYE.read_text(encoding="utf-8"))
    bulucu = cv2.FaceDetectorYN.create(str(HAM / "yunet.onnx"), "", (320, 320), 0.5, 0.3, 50)
    tanici = cv2.FaceRecognizerSF.create(str(HAM / "sface.onnx"), "")

    isler = []      # (kimlik, klasör, çeşitleme rgba)
    no = 0
    # (sayfa eki, kişi sayısı, satır sayısı): ilk dört sayfa 4x4, sonradan eklenen "e" sayfası 5x5
    for ek, adet, satir in [(s.split("_")[1], 16, 4) for s in HAVUZ] + [("e", 25, 5)]:
        yol = HAM / f"vesika_{ek}.png"
        kimlikler = [f"v{no + i + 1:02d}" for i in range(adet)]
        no += adet
        if not yol.exists():
            print(f"vesika_{ek}.png yok, atlandı")
            continue
        for kimlik, kisi in zip(kimlikler, sayfa_kisileri(yol, adet, satir)):
            isler.append((kimlik, VESIKA, kisi))
    yol = HAM / "vesika_hikaye.png"
    if yol.exists():
        for (kimlik, klasor), kisi in zip(HIKAYE_SAYFASI, hikaye_kisileri(yol)):
            isler.append((kimlik, klasor, kisi))

    taban_oz, vesika_oz, aranan_oz = {}, {}, {}
    denetim, basarisiz = [], []
    for kimlik, klasor, kisi in isler:
        yuz, buyuk = yuz_bul(bulucu, kisi)
        if yuz is None:
            basarisiz.append(kimlik)
            continue
        kare = kadrajla(kisi, yuz)
        kare.save(klasor / f"{kimlik}.webp", quality=90, method=4, alpha_quality=100)
        (aranan_oz if klasor == ARANAN else vesika_oz)[kimlik] = oznitelik(tanici, buyuk, yuz)
        # denetim: gişedeki büst | yeni kare
        ana = np.array(Image.open(PORTRE / f"{kimlik}.webp").convert("RGBA"))
        if kimlik not in taban_oz:
            y2, b2 = yuz_bul(bulucu, ana)
            if y2 is not None:
                taban_oz[kimlik] = oznitelik(tanici, b2, y2)
        sol = cv2.resize(bgr_yap(ana), (KARE[1] * ana.shape[1] // ana.shape[0], KARE[1]))
        sag = bgr_yap(np.array(kare))
        cift = np.hstack([sol, sag])
        cv2.putText(cift, kimlik, (4, 16), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1, cv2.LINE_AA)
        denetim.append(cift)
    print(f"{len(isler) - len(basarisiz)} kare yazıldı; yüzü bulunamayan: {basarisiz}")

    # --- benzerlik ---
    havuz = [k for k in vesika_oz if k in taban_oz and not kunye.get(k, {}).get("ozel", False)]
    kendine = []
    for a in vesika_oz:
        if a in taban_oz:
            kendine.append(float(taban_oz[a] @ vesika_oz[a]))
    if kendine:
        print(f"aynı kişi (büst ile vesikalık) benzerliği: ortalama {np.mean(kendine):.2f}, en düşük {np.min(kendine):.2f}")
    sira_hatasi = 0
    for a in list(vesika_oz):
        if a not in taban_oz or a not in kunye:
            continue
        cins, yas = kunye[a].get("cinsiyet"), int(kunye[a].get("yas", 40))
        adaylar = []
        for b in havuz:
            if b == a or kunye[b].get("cinsiyet") != cins or abs(int(kunye[b].get("yas", 40)) - yas) > 16:
                continue
            puan = 0.5 * float(taban_oz[a] @ vesika_oz[b]) + 0.5 * float(vesika_oz[a] @ vesika_oz[b])
            adaylar.append((puan, b))
        adaylar.sort(reverse=True)
        kunye[a]["benzer"] = [b for _, b in adaylar[:BENZER_ADEDI]]
        if adaylar and float(taban_oz[a] @ vesika_oz[adaylar[0][1]]) > float(taban_oz[a] @ vesika_oz[a]):
            sira_hatasi += 1
    print(f"benzer listeleri yazıldı; en yakın benzeri kendi vesikalığından daha çok benzeyen: {sira_hatasi} kişi")
    # arananlara benzeyen masumlar: gişedeki görünüşü, listedeki eski resme en çok benzeyenler
    for a, oz in aranan_oz.items():
        cins, yas = kunye[a].get("cinsiyet"), int(kunye[a].get("yas", 40))
        adaylar = []
        for b in havuz:
            if kunye[b].get("cinsiyet") != cins or abs(int(kunye[b].get("yas", 40)) - yas) > 14:
                continue
            adaylar.append((0.6 * float(taban_oz[b] @ oz) + 0.4 * float(taban_oz[b] @ taban_oz[a]), b))
        adaylar.sort(reverse=True)
        kunye[a]["aranan_benzer"] = [b for _, b in adaylar[:4]]
        print(f"  {a}: listedeki resme benzeyen masumlar {kunye[a]['aranan_benzer']} "
              f"(kendi büstüyle benzerliği {float(taban_oz[a] @ oz):.2f})")

    KUNYE.write_text(json.dumps(kunye, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8")
    for s in range(0, len(denetim), 24):
        parca = denetim[s:s + 24]
        w = max(p.shape[1] for p in parca)
        parca = [cv2.copyMakeBorder(p, 0, 0, 0, w - p.shape[1], cv2.BORDER_CONSTANT, value=(40, 40, 40)) for p in parca]
        bos = np.full_like(parca[0], 40)
        satirlar = [np.hstack(parca[i:i + 6] + [bos] * (6 - len(parca[i:i + 6]))) for i in range(0, len(parca), 6)]
        cv2.imwrite(str(HAM / f"vesika_denetim_{s // 24}.jpg"), np.vstack(satirlar), [cv2.IMWRITE_JPEG_QUALITY, 88])


if __name__ == "__main__":
    main()
