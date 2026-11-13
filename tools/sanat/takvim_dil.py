"""Takvim yapraklarının İngilizce ve Rusça hâllerini üretir.

Boyalı Türkçe yapraklar (assets/img/nesne/takvim_<gün>.webp) korunur: kâğıt, kırmızı başlık ve büyük gün
rakamı aynen kalır; yalnızca yazılar (ay, haftanın günü, alttaki küçük satır) silinip yeni dilde basılır.
Silme: yazının pikselleri, bulundukları şeridin (kırmızı başlık ya da kâğıt) yakın çevresindeki renkle
doldurulur. Basma: Old Standard Bold ile dört kat büyük çizilir, küçültülür, baskı gibi hafifçe
dağıtılır (kenar yumuşatma ve mürekkep pürüzü).

Çıktı: assets/img/nesne/<dil>/takvim_<gün>.webp  (oyunda Dil.yol() bunları bulur)

Kullanım: python tools/sanat/takvim_dil.py [denetim.png]
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from scipy import ndimage

KOK = Path(__file__).resolve().parents[2]
NESNE = KOK / "assets" / "img" / "nesne"
FONT = KOK / "assets" / "font" / "OldStandard-Bold.ttf"
GUNLER = {9: 0, 10: 1, 11: 2, 12: 3, 13: 4, 16: 0, 17: 1}        # gün → haftanın günü (0 = pazartesi)
METINLER = {
    "en": {"ay": "JANUARY 1984", "hafta": ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY"], "alt": "Day {n} of the year"},
    "ru": {"ay": "ЯНВАРЬ 1984", "hafta": ["ПОНЕДЕЛЬНИК", "ВТОРНИК", "СРЕДА", "ЧЕТВЕРГ", "ПЯТНИЦА"], "alt": "{n}-й день года"},
}
BUYUTME = 4


def satir_bloklari(maske: np.ndarray, en_az: int = 3) -> list:
    """Maskede piksel bulunan ardışık satır aralıkları [(y0, y1), ...]."""
    dolu = maske.sum(axis=1) > 2
    bloklar = []
    bas = None
    for y, d in enumerate(dolu):
        if d and bas is None:
            bas = y
        if not d and bas is not None:
            if y - bas >= en_az:
                bloklar.append((bas, y))
            bas = None
    if bas is not None:
        bloklar.append((bas, len(dolu)))
    return bloklar


def sil(a: np.ndarray, maske: np.ndarray) -> None:
    """Maskelenen pikselleri, çevrelerindeki maskesiz piksellerin bulanık rengiyle doldurur."""
    renk = a[..., :3].astype(np.float32)
    agirlik = (~maske).astype(np.float32)
    toplam = np.zeros_like(renk)
    for k in range(3):
        toplam[..., k] = ndimage.gaussian_filter(renk[..., k] * agirlik, 7)
    pay = ndimage.gaussian_filter(agirlik, 7)
    dolgu = toplam / np.maximum(pay[..., None], 1e-3)
    gurultu = np.random.default_rng(1984).normal(0, 2.2, maske.shape)[..., None]
    a[..., :3] = np.where(maske[..., None], np.clip(dolgu + gurultu, 0, 255), renk).astype(np.uint8)


def bas(im: Image.Image, metin: str, kutu: tuple, renk: tuple, en_payi: float = 0.94) -> None:
    """Metni kutunun ortasına, kutuya sığan en büyük puntoyla basar (baskı dokusuyla)."""
    x0, y0, x1, y1 = kutu
    en, boy = (x1 - x0) * BUYUTME, (y1 - y0) * BUYUTME
    punto = int(boy * 1.25)
    while punto > 8:
        font = ImageFont.truetype(str(FONT), punto)
        sol, ust, sag, alt = font.getbbox(metin)
        if sag - sol <= en * en_payi and alt - ust <= boy:
            break
        punto -= 2
    katman = Image.new("L", (en, boy), 0)
    ImageDraw.Draw(katman).text(((en - (sag - sol)) / 2 - sol, (boy - (alt - ust)) / 2 - ust), metin, font=font, fill=255)
    katman = katman.resize((x1 - x0, y1 - y0), Image.LANCZOS).filter(ImageFilter.GaussianBlur(0.35))
    m = np.array(katman).astype(np.float32) / 255.0
    m *= 0.86 + 0.14 * np.random.default_rng(len(metin)).random(m.shape)          # mürekkep her yerde aynı tutmaz
    a = np.array(im)
    bolge = a[y0:y1, x0:x1, :3].astype(np.float32)
    a[y0:y1, x0:x1, :3] = (bolge * (1 - m[..., None]) + np.array(renk, np.float32) * m[..., None]).astype(np.uint8)
    im.paste(Image.fromarray(a, "RGBA"))


def cevir(gun: int, dil: str) -> Image.Image:
    im = Image.open(NESNE / f"takvim_{gun:02d}.webp").convert("RGBA")
    a = np.array(im)
    h, w = a.shape[:2]
    r, g, b = (a[..., i].astype(np.int32) for i in range(3))
    mat = a[..., 3] > 200
    kirmizi = (r > 120) & (g < 90) & (b < 90) & mat
    bant = satir_bloklari(kirmizi, 10)[0]                         # kırmızı başlık
    acik_yazi = (r > 170) & (g > 150) & (b > 110) & mat           # başlıktaki krem harfler
    acik_yazi[: bant[0]] = False
    acik_yazi[bant[1]:] = False
    koyu = (r + g + b < 250) & mat                                 # kâğıttaki siyah yazı
    koyu[: bant[1] + 4] = False
    bloklar = satir_bloklari(koyu)
    # sıra: büyük rakam, haftanın günü, çizgi, küçük satır
    rakam = max(bloklar, key=lambda q: q[1] - q[0])
    sonrakiler = [q for q in bloklar if q[0] >= rakam[1]]
    cizgi = min(sonrakiler, key=lambda q: q[1] - q[0])
    hafta = [q for q in sonrakiler if q[1] <= cizgi[0]]
    alt = [q for q in sonrakiler if q[0] >= cizgi[1]]
    hafta_kutu = (hafta[0][0], hafta[-1][1])
    alt_kutu = (alt[0][0], alt[-1][1])
    silinecek = np.zeros((h, w), bool)
    silinecek[bant[0]:bant[1]] = acik_yazi[bant[0]:bant[1]]
    for y0, y1 in (hafta_kutu, alt_kutu):
        silinecek[y0:y1] = koyu[y0:y1]
    # harflerin yumuşak kenarı da gitsin
    silinecek = np.array(Image.fromarray(silinecek).filter(ImageFilter.MaxFilter(5))) & mat
    sil(a, silinecek)
    im = Image.fromarray(a, "RGBA")
    t = METINLER[dil]
    kenar = int(w * 0.07)
    bas(im, t["ay"], (kenar, bant[0] + 6, w - kenar, bant[1] - 6), (244, 226, 190))
    bas(im, t["hafta"][GUNLER[gun]], (kenar, hafta_kutu[0] - 2, w - kenar, hafta_kutu[1] + 2), (34, 28, 24))
    bas(im, t["alt"].format(n=gun), (kenar * 2, alt_kutu[0] - 2, w - kenar * 2, alt_kutu[1] + 3), (40, 34, 30), 0.80)
    return im


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    denetim = []
    for dil in METINLER:
        (NESNE / dil).mkdir(exist_ok=True)
        for gun in GUNLER:
            im = cevir(gun, dil)
            im.save(NESNE / dil / f"takvim_{gun:02d}.webp", quality=93, method=6, alpha_quality=100)
            denetim.append(im)
        print(f"{dil}: {len(GUNLER)} yaprak")
    if len(sys.argv) > 1:
        sayfa = Image.new("RGB", (7 * 256, 2 * 344), (120, 150, 130))
        for i, im in enumerate(denetim):
            sayfa.paste(im, ((i % 7) * 256 + 4, (i // 7) * 344 + 4), im)
        sayfa.save(sys.argv[1])


if __name__ == "__main__":
    main()
