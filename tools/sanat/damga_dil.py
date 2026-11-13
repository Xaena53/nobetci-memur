"""Yazılı lastik damgaların (onay, ret, görülmüştür) İngilizce ve Rusça hâllerini üretir.

Damga görselleri beyaz + saydamlıktır (renk oyunda mürekkepten gelir). Çerçeve olduğu gibi kalır;
yalnızca iç çerçevedeki yazı silinip yeni dilde basılır. Yeni yazı, eskisinin satır kutularına oturur
(dar ve kalın lastik harfler: Old Standard Bold, gerekirse yatayda sıkıştırılır) ve lastik damga
dokusu verilir: kenar pürüzü, mürekkebin tutmadığı benekler.

Çıktı: assets/img/damga/<dil>/<ad>.webp  (oyunda Damga.doku → Dil.yol bunları bulur)

Kullanım: python tools/sanat/damga_dil.py [denetim.png]
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

KOK = Path(__file__).resolve().parents[2]
DAMGA = KOK / "assets" / "img" / "damga"
FONT = KOK / "assets" / "font" / "OldStandard-Bold.ttf"
METINLER = {
    "en": {"onay": ["APPROVED", "Ardıçlı Registry Office"], "ret": ["REJECTED", "Ardıçlı Registry Office"],
           "gorulmustur": ["REVIEWED", "Director"]},
    "ru": {"onay": ["ОДОБРЕНО", "Управление учёта Ардычлы"], "ret": ["ОТКАЗАНО", "Управление учёта Ардычлы"],
           "gorulmustur": ["ПРОСМОТРЕНО", "Начальник"]},
}
BUYUTME = 4


def cizgi_kosulari(dolu: np.ndarray) -> list:
    """Bir boyuttaki dolu (çizgi) koşuları [(baş, son), ...]."""
    kosular, bas = [], None
    for i, d in enumerate(dolu):
        if d and bas is None:
            bas = i
        if not d and bas is not None:
            kosular.append((bas, i))
            bas = None
    if bas is not None:
        kosular.append((bas, len(dolu)))
    return kosular


def en_uzun_kosu(satir: np.ndarray) -> int:
    en, simdi = 0, 0
    for v in satir:
        simdi = simdi + 1 if v else 0
        en = max(en, simdi)
    return en


def yazi_alani(alfa: np.ndarray) -> tuple:
    """İç çerçevenin içinde, yazının durduğu bölme: (x0, y0, x1, y1)."""
    # çerçeve çizgisi: içinde boşluksuz uzun bir koşu bulunan satır ya da sütun (kalın harf satırları
    # çok piksel kaplar ama harf aralarında kesilir). Lastik dokusundaki küçük boşluklar kapatılır.
    m = ndimage.binary_closing(alfa > 110, structure=np.ones((1, 7)))
    m_dikey = ndimage.binary_closing(alfa > 110, structure=np.ones((7, 1)))
    h, w = m.shape
    yatay = cizgi_kosulari(np.array([en_uzun_kosu(m[y]) for y in range(h)]) > w * 0.7)
    dikey = cizgi_kosulari(np.array([en_uzun_kosu(m_dikey[:, x]) for x in range(w)]) > h * 0.7)
    # dıştan içe: dış çerçeve, iç çerçeve; yazı iç üst çizgi ile bir sonraki yatay çizgi arasında
    return dikey[1][1] + 2, yatay[1][1] + 2, dikey[-2][0] - 2, yatay[2][0] - 2


def lastik_dokusu(maske: np.ndarray, tohum: int) -> np.ndarray:
    """Basılan harflere lastik damga dokusu: pürüzlü kenar ve mürekkebin tutmadığı küçük benekler."""
    rng = np.random.default_rng(tohum)
    kenar_gurultusu = ndimage.gaussian_filter(rng.random(maske.shape), 1.1)
    m = maske * np.clip((kenar_gurultusu - 0.30) / 0.12, 0.0, 1.0) ** 0.25
    benek = ndimage.gaussian_filter(rng.random(maske.shape), 0.8) < 0.30
    m = np.where(benek & (rng.random(maske.shape) < 0.55), m * 0.15, m)
    return np.clip(m, 0.0, 1.0)


def bas(alfa: np.ndarray, metin: str, kutu: tuple, tohum: int, kalinlik: int = 0) -> None:
    """Metni kutuya sığdırarak (yükseklik kutunun, en en çok kutunun) saydamlık kanalına basar."""
    x0, y0, x1, y1 = kutu
    en, boy = x1 - x0, y1 - y0
    font = ImageFont.truetype(str(FONT), boy * BUYUTME)
    sol, ust, sag, alt = font.getbbox(metin)
    katman = Image.new("L", (sag - sol + 8, alt - ust + 8), 0)
    ImageDraw.Draw(katman).text((4 - sol, 4 - ust), metin, font=font, fill=255)
    # harf yüksekliği kutuya oturur; en sığmıyorsa yatayda sıkıştırılır (lastik damga harfleri dardır)
    hedef_boy = boy
    hedef_en = round(katman.width * hedef_boy / katman.height)
    if hedef_en > en:
        hedef_en = en
    katman = katman.resize((max(1, hedef_en), max(1, hedef_boy)), Image.LANCZOS)
    m = np.array(katman).astype(np.float32) / 255.0
    if kalinlik > 0:                                     # özgün başlıklar kalın lastik harflerdir
        m = ndimage.grey_dilation(m, size=(kalinlik, kalinlik + 1))
    m = lastik_dokusu(m, tohum)
    ox = x0 + (en - katman.width) // 2
    bolge = alfa[y0:y0 + katman.height, ox:ox + katman.width]
    alfa[y0:y0 + katman.height, ox:ox + katman.width] = np.maximum(bolge, m[:bolge.shape[0], :bolge.shape[1]] * 255.0)


def cevir(ad: str, dil: str) -> Image.Image:
    im = Image.open(DAMGA / f"{ad}.webp").convert("RGBA")
    a = np.array(im)
    alfa = a[..., 3].astype(np.float32)
    x0, y0, x1, y1 = yazi_alani(alfa)
    # eski yazının satır kutuları (yeni yazı aynı yere ve boya oturur)
    ic = alfa[y0:y1, x0:x1] > 90
    satirlar = [(y0 + s, y0 + e) for s, e in cizgi_kosulari(ic.sum(axis=1) > 0) if e - s >= 6]
    satirlar = sorted(satirlar, key=lambda q: q[0])
    # harflerin noktaları (İ, Ü) ayrı satır sayılmasın: aradaki boşluk küçükse birleştirilir
    birlesik = []
    for q in satirlar:
        if birlesik and q[0] - birlesik[-1][1] < 6:
            birlesik[-1] = (birlesik[-1][0], q[1])
        else:
            birlesik.append(q)
    satirlar = birlesik
    assert len(satirlar) == 2, (ad, satirlar)
    alfa[y0:y1, x0:x1] = 0.0
    yeni = METINLER[dil][ad]
    pay = int((x1 - x0) * 0.05)
    for i, (sy0, sy1) in enumerate(satirlar):
        bas(alfa, yeni[i], (x0 + pay, sy0, x1 - pay, sy1), 1984 + i, 3 if i == 0 else 0)
    a[..., 3] = np.clip(alfa, 0, 255).astype(np.uint8)
    a[..., :3] = 255
    return Image.fromarray(a, "RGBA")


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    denetim = []
    for dil, damgalar in METINLER.items():
        (DAMGA / dil).mkdir(exist_ok=True)
        for ad in damgalar:
            im = cevir(ad, dil)
            im.save(DAMGA / dil / f"{ad}.webp", quality=92, method=4, alpha_quality=100)
            denetim.append((ad, im))
        print(f"{dil}: {len(damgalar)} damga")
    if len(sys.argv) > 1:
        renkler = {"onay": (31, 107, 60), "ret": (170, 30, 30), "gorulmustur": (122, 31, 43)}
        sayfa = Image.new("RGBA", (3 * 450, 2 * 265), (240, 232, 214, 255))
        for i, (ad, im) in enumerate(denetim):
            renk = Image.new("RGBA", im.size, renkler[ad] + (255,))
            z = Image.new("RGBA", im.size, (0, 0, 0, 0))
            z.paste(renk, (0, 0), im.getchannel("A"))
            sayfa.alpha_composite(z, ((i % 3) * 450 + 5, (i // 3) * 265 + 5))
        sayfa.convert("RGB").save(sys.argv[1])


if __name__ == "__main__":
    main()
