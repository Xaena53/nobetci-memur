"""Ret mührünün izini (assets/img/damga/ret.webp) eldeki boyalı damgalardan kurar.

"REDDEDİLMİŞTİR" yazısı, vezne kaşesindeki "TAHSİL EDİLMİŞTİR" satırının harflerinden dizilir (aynı yazı
tipi, aynı mürekkep dokusu): "EDİLMİŞTİR" bloğu olduğu gibi alınır, başına aynı satırdan R, E, D, D eklenir.
Çerçeve, alt satır ("Ardıçlı Nüfus Müdürlüğü") ve tarih şeridi onay mühründen gelir; yalnızca üst sözcük
değişir. Sonuç öbür damgalar gibi beyaz renkli bir saydamlık maskesidir; mürekkebin rengi oyunda verilir.

Kullanım: python tools/sanat/ret_damgasi.py      (denetim görseli: tools/sanat/ham/ret_denetim.png)
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

KOK = Path(__file__).resolve().parents[2]
DAMGA = KOK / "assets" / "img" / "damga"
HAM = Path(__file__).resolve().parent / "ham"


def maske(ad: str) -> np.ndarray:
    return np.array(Image.open(DAMGA / f"{ad}.webp").convert("RGBA"))[..., 3].astype(np.float32) / 255.0


def kosular(dolu: np.ndarray, en_az_bosluk: int = 1) -> list:
    """Dolu sütunların (ya da satırların) art arda geldiği aralıklar: [(baş, son+1)]."""
    sonuc, bas = [], None
    bosluk = 0
    for i, d in enumerate(dolu):
        if d:
            if bas is None:
                bas = i
            bosluk = 0
        elif bas is not None:
            bosluk += 1
            if bosluk >= en_az_bosluk:
                sonuc.append((bas, i - bosluk + 1))
                bas = None
    if bas is not None:
        sonuc.append((bas, len(dolu)))
    return sonuc


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    vezne = maske("vezne_gercek")
    onay = maske("onay")

    # --- vezne kaşesinde üst satır: çerçevenin içi, iki yazı satırının üstteki ---
    ic = vezne[14:-14, 16:-16]                         # dış çerçeveyi at
    satirlar = kosular((ic > 0.35).sum(axis=1) > 3, 3)
    satirlar = [s for s in satirlar if s[1] - s[0] > 12]
    ust = satirlar[0]
    y0, y1 = ust[0] + 14 - 12, ust[1] + 14 + 8         # İ'nin noktası ve Ş'nin çengeli için pay
    bant = vezne[y0:y1, 16:-16]
    # kalın harflerin tırnakları birbirine değer: bir sütunda dört pikselden az mürekkep varsa harf arası sayılır
    harfler = kosular((bant > 0.45).sum(axis=0) > 4, 1)
    print("üst satırdaki harf parçaları:", len(harfler), [(a, b - a) for a, b in harfler])
    # beklenen: TA H S İ L | E D İ LM İ Ş T İ R  (sözcük arası en geniş boşluk; L ile M bitişik)
    bosluklar = [harfler[i + 1][0] - harfler[i][1] for i in range(len(harfler) - 1)]
    ara = int(np.argmax(bosluklar))                     # "TAHSİL" ile "EDİLMİŞTİR" arası
    ikinci = harfler[ara + 1:]
    # yalnız üç harf tek tek gerekir: baştaki E ve D ile sondaki R (aradakiler blok olarak alınır)
    for parca in (ikinci[0], ikinci[1], ikinci[-1]):
        if not 14 <= parca[1] - parca[0] <= 30:
            raise SystemExit(f"E, D ya da R tek harf olarak ayrılamadı: {ikinci}; eşiği ayarlayın")
    harf_arasi = 2
    kes = lambda aralik: bant[:, aralik[0]:aralik[1]]   # noqa: E731
    e, d, r = kes(ikinci[0]), kes(ikinci[1]), kes(ikinci[-1])
    blok = bant[:, ikinci[0][0]:ikinci[-1][1]]          # EDİLMİŞTİR
    bos = np.zeros((bant.shape[0], max(1, harf_arasi)), np.float32)
    sozcuk = np.hstack([r, bos, e, bos, d, bos, d, bos, blok])
    # yazının dikey sınırlarına kırp
    dolu_satir = np.flatnonzero((sozcuk > 0.3).sum(axis=1) > 0)
    sozcuk = sozcuk[dolu_satir[0]:dolu_satir[-1] + 1]

    # --- onay mühründe üst sözcüğün yeri ---
    h, w = onay.shape
    ic_onay = onay.copy()
    kenar = int(w * 0.075)
    ic_onay[:, :kenar] = 0
    ic_onay[:, -kenar:] = 0
    o_satirlar = [s for s in kosular((ic_onay[int(h * 0.08):int(h * 0.62)] > 0.35).sum(axis=1) > 3, 3) if s[1] - s[0] > 14]
    oy0, oy1 = o_satirlar[0][0] + int(h * 0.08), o_satirlar[0][1] + int(h * 0.08)
    sutunlar = np.flatnonzero((ic_onay[oy0:oy1] > 0.35).sum(axis=0) > 0)
    ox0, ox1 = int(sutunlar[0]), int(sutunlar[-1]) + 1
    print(f"onay sözcüğünün yeri: x {ox0}..{ox1}, y {oy0}..{oy1}")

    # yeni sözcüğü aynı yüksekliğe ölçekle; genişliği sığmıyorsa yatayda sıkıştır
    # yeni sözcük daha dar harflidir: çerçeveyi doldursun diye beşte bir büyütülür (alt satıra değmeden)
    buyutme = 1.2
    orta_y = (oy0 + oy1) // 2
    hedef_y = int(round((oy1 - oy0) * buyutme))
    oy0, oy1 = orta_y - hedef_y // 2, orta_y - hedef_y // 2 + hedef_y
    olcek = hedef_y / sozcuk.shape[0]
    hedef_x = min(int(round(sozcuk.shape[1] * olcek)), ox1 - ox0)
    yeni = np.array(Image.fromarray((sozcuk * 255).astype(np.uint8)).resize((hedef_x, hedef_y), Image.LANCZOS)).astype(np.float32) / 255.0
    ret = onay.copy()
    ret[oy0 - 1:oy1 + 1, kenar:w - kenar] = 0           # eski sözcüğü sil (çerçeveye dokunmadan)
    bx = (ox0 + ox1 - hedef_x) // 2
    ret[oy0:oy1, bx:bx + hedef_x] = np.maximum(ret[oy0:oy1, bx:bx + hedef_x], yeni)

    cikti = np.zeros((h, w, 4), np.uint8)
    cikti[..., :3] = 255
    cikti[..., 3] = (np.clip(ret, 0, 1) * 255).astype(np.uint8)
    Image.fromarray(cikti, "RGBA").save(DAMGA / "ret.webp", lossless=True, quality=100, method=6, exact=True)

    # denetim: kırmızı mürekkeple kâğıt üstünde ret, mavi mürekkeple onay
    HAM.mkdir(parents=True, exist_ok=True)
    sayfa = Image.new("RGB", (w * 2 + 60, h + 40), (243, 236, 219))
    for i, (m, renk) in enumerate(((ret, (163, 38, 44)), (onay, (43, 74, 143)))):
        murekkep = Image.new("RGB", (w, h), renk)
        sayfa.paste(murekkep, (20 + i * (w + 20), 20), Image.fromarray((np.clip(m, 0, 1) * 235).astype(np.uint8)))
    sayfa.save(HAM / "ret_denetim.png")
    print("yazıldı:", DAMGA / "ret.webp")


def muhur_araclari() -> None:
    """Tepsideki mühür görselinden iki araç üretir: lastiği mavi (onay) ve kırmızı (ret) mühür."""
    import colorsys
    nesne = KOK / "assets" / "img" / "nesne"
    im = np.array(Image.open(nesne / "muhur.webp").convert("RGBA")).astype(np.float32) / 255.0
    hsv = np.array(Image.fromarray((im[..., :3] * 255).astype(np.uint8)).convert("HSV")).astype(np.float32)
    ton, doygunluk = hsv[..., 0] / 255.0 * 360.0, hsv[..., 1] / 255.0
    # lastik: kırmızıya yakın ve doygun pikseller (ahşap turuncuya kaçar, o dışarıda kalır)
    lastik = ((ton < 9.0) | (ton > 346.0)) & (doygunluk > 0.50) & (im[..., 3] > 0.3)
    print("lastik pikseli:", int(lastik.sum()))
    Image.fromarray((im * 255).astype(np.uint8), "RGBA").save(nesne / "muhur_ret.webp", quality=95, method=6)
    mavi = hsv.copy()
    mavi[..., 0][lastik] = 218.0 / 360.0 * 255.0
    mavi[..., 1][lastik] = np.clip(mavi[..., 1][lastik] * 0.92, 0, 255)
    rgb = np.array(Image.fromarray(mavi.astype(np.uint8), "HSV").convert("RGB"))
    cikti = np.dstack([rgb, (im[..., 3] * 255).astype(np.uint8)])
    Image.fromarray(cikti, "RGBA").save(nesne / "muhur_onay.webp", quality=95, method=6)
    yan = Image.new("RGBA", (im.shape[1] * 2 + 30, im.shape[0] + 20), (52, 96, 70, 255))
    yan.alpha_composite(Image.fromarray(cikti, "RGBA"), (10, 10))
    yan.alpha_composite(Image.fromarray((im * 255).astype(np.uint8), "RGBA"), (im.shape[1] + 20, 10))
    yan.convert("RGB").save(HAM / "muhur_denetim.png")


if __name__ == "__main__":
    main()
    muhur_araclari()
