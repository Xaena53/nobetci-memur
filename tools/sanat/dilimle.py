"""Üretilen sayfaları (ızgara hâlinde portreler / nesneler) tek tek görsellere dilimler.

Saydam zemin üzerindeki her figür alfa kanalından bağlı bileşen olarak bulunur, satır-sütun
sırasına dizilir, kendi sınır kutusuna kırpılır ve sayfa başına tek bir ölçekle küçültülür
(böylece aynı sayfadaki herkes birbirine göre doğru boyda kalır).

Kullanım: python tools/sanat/dilimle.py            (tools/sanat/ham/ içindeki sayfaları işler)
Çıktı:    assets/img/portre/*.webp, assets/img/nesne/*.webp, data/portreler.json
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

KOK = Path(__file__).resolve().parents[2]
HAM = Path(__file__).resolve().parent / "ham"
PORTRE = KOK / "assets" / "img" / "portre"
NESNE = KOK / "assets" / "img" / "nesne"

OMUZ_GENISLIGI = 400  # yetişkin bir büstün hedef genişliği (piksel)

# Havuz sayfalarındaki kişiler satır satır: (cinsiyet, yaş)
HAVUZ = {
    "havuz_a": "E45 K60 E28 K35 E70 K25 E55 K45 E35 K70 E22 K30 E60 K50 E40 K20",
    "havuz_b": "E50 K28 E65 K55 E19 K40 E33 K75 E58 K22 E45 K33 E72 K48 E27 K60",
    "havuz_c": "E38 K19 E80 K42 E30 K52 E48 K26 E62 K68 E24 K37 E55 K30 E42 K58",
    "havuz_d": "E36 K65 E26 K24 E68 K44 E52 K34 E21 K80 E46 K29 E59 K38 E31 K50",
}
HIKAYE = [
    ("husnu", "E", 74), ("nermin", "K", 48), ("rusvetci", "E", 42), ("mudur", "E", 58),
    ("murat", "E", 38), ("mufettis", "E", 38), ("yusuf", "E", 10), ("anne", "K", 72),
    ("elif", "K", 8), ("can", "E", 4), ("cayci", "E", 15), ("evsahibi", "E", 63),
]
NESNELER = ["muhur", "buyutec", "zarf", "igne", "daktilo", "para", "anahtar", "komur",
            "ekmek", "ilac", "defter", "mektup"]


def bilesenler(im: Image.Image, adet: int, satir: int):
    """Alfa kanalından en büyük `adet` bileşeni bulur; satır-sütun sırasıyla kutularını döndürür."""
    alfa = np.array(im)[..., 3]
    etiket, n = ndimage.label(alfa > 24)
    dilimler = ndimage.find_objects(etiket)
    alanlar = ndimage.sum(alfa > 24, etiket, range(1, n + 1))
    sirali = sorted(range(n), key=lambda i: -alanlar[i])[:adet]
    kutular = []
    for i in sirali:
        ys, xs = dilimler[i]
        kutular.append((xs.start, ys.start, xs.stop, ys.stop))
    # yakın küçük parçaları (küpe, kurdele ucu) ana figüre kat
    for i in sorted(range(n), key=lambda i: -alanlar[i])[adet:]:
        if alanlar[i] < 40:
            continue
        ys, xs = dilimler[i]
        cx, cy = (xs.start + xs.stop) / 2, (ys.start + ys.stop) / 2
        for j, (x0, y0, x1, y1) in enumerate(kutular):
            if x0 - 30 <= cx <= x1 + 30 and y0 - 30 <= cy <= y1 + 30:
                kutular[j] = (min(x0, xs.start), min(y0, ys.start), max(x1, xs.stop), max(y1, ys.stop))
                break
    # satırlara ayır: dikey merkeze göre sırala, sonra her satırı yatayda diz
    kutular.sort(key=lambda k: (k[1] + k[3]) / 2)
    sutun = adet // satir
    sonuc = []
    for r in range(satir):
        sira = sorted(kutular[r * sutun:(r + 1) * sutun], key=lambda k: (k[0] + k[2]) / 2)
        sonuc.extend(sira)
    return sonuc


def kaydet(im: Image.Image, kutu, olcek: float, yol: Path, pay: int = 2):
    x0, y0, x1, y1 = kutu
    parca = im.crop((max(0, x0 - pay), max(0, y0 - pay), min(im.width, x1 + pay), min(im.height, y1 + pay)))
    w, h = max(1, round(parca.width * olcek)), max(1, round(parca.height * olcek))
    parca = parca.resize((w, h), Image.LANCZOS)
    # tam saydam piksellerin rengini sıfırla: kenarlarda renk sızıntısı olmasın
    a = np.array(parca)
    a[a[..., 3] < 6] = 0
    Image.fromarray(a).save(yol, quality=92, method=4, alpha_quality=100)
    return w, h


def para_guncelle() -> None:
    """Zarf ve para: banknotların üstünde portre bulunmayan ayrı sayfadan alınır (para2.png)."""
    yol = HAM / "para2.png"
    if not yol.exists():
        return
    im = Image.open(yol).convert("RGBA")
    kutular = bilesenler(im, 2, 1)
    for kutu, ad in zip(kutular, ["zarf", "para"]):
        kaydet(im, kutu, 0.72, NESNE / f"{ad}.webp")
    print("zarf ve para: portresiz sürümle değiştirildi")


KAGITLAR = ["sayfa", "makbuz", "cuzdan_mavi", "cuzdan_pembe", "teleks", "daktilo_sayfa"]


def kagitlari_dilimle() -> None:
    """Belgelerin zemini olan boş kâğıt dokuları (kagitlar.png: 3 sütun x 2 satır)."""
    yol = HAM / "kagitlar.png"
    if not yol.exists():
        return
    hedef = KOK / "assets" / "img" / "kagit"
    hedef.mkdir(parents=True, exist_ok=True)
    im = Image.open(yol).convert("RGBA")
    kutular = bilesenler(im, 6, 2)
    for kutu, ad in zip(kutular, KAGITLAR):
        w, h = kaydet(im, kutu, 1.0, hedef / f"{ad}.webp", pay=3)
        print(f"  {ad}: {w}x{h}")
    print("kâğıt dokuları: 6 parça")


def main() -> None:
    PORTRE.mkdir(parents=True, exist_ok=True)
    NESNE.mkdir(parents=True, exist_ok=True)
    kunye = {}

    no = 0
    for sayfa, liste in HAVUZ.items():
        im = Image.open(HAM / f"{sayfa}.png").convert("RGBA")
        kutular = bilesenler(im, 16, 4)
        genislikler = sorted(k[2] - k[0] for k in kutular)
        olcek = OMUZ_GENISLIGI / genislikler[len(genislikler) // 2]
        for kutu, kisi in zip(kutular, liste.split()):
            no += 1
            kimlik = f"v{no:02d}"
            w, h = kaydet(im, kutu, olcek, PORTRE / f"{kimlik}.webp")
            kunye[kimlik] = {"cinsiyet": kisi[0], "yas": int(kisi[1:])}
        print(f"{sayfa}: 16 portre, ölçek {olcek:.3f}")

    im = Image.open(HAM / "hikaye.png").convert("RGBA")
    kutular = bilesenler(im, 12, 3)
    yetiskin = sorted(k[2] - k[0] for k in kutular)[-6:]
    olcek = OMUZ_GENISLIGI / (sum(yetiskin) / len(yetiskin))
    for kutu, (kimlik, cins, yas) in zip(kutular, HIKAYE):
        kaydet(im, kutu, olcek, PORTRE / f"{kimlik}.webp")
        kunye[kimlik] = {"cinsiyet": cins, "yas": yas, "ozel": True}
    print(f"hikaye: 12 portre, ölçek {olcek:.3f}")

    im = Image.open(HAM / "nesneler.png").convert("RGBA")
    kutular = bilesenler(im, 12, 3)
    for kutu, ad in zip(kutular, NESNELER):
        kaydet(im, kutu, 0.62, NESNE / f"{ad}.webp")
    print("nesneler: 12 parça")
    para_guncelle()

    (KOK / "data" / "portreler.json").write_text(
        json.dumps(kunye, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8")
    print("künye yazıldı:", len(kunye), "kayıt")


if __name__ == "__main__":
    import sys
    if "--para" in sys.argv:
        NESNE.mkdir(parents=True, exist_ok=True)
        para_guncelle()
    elif "--kagit" in sys.argv:
        kagitlari_dilimle()
    else:
        main()
        kagitlari_dilimle()
