"""Masa sahnesinin PERSPEKTİFLİ yerleşim taslağı (oturan memurun gözünden, hafif yukarıdan).

Duvar, gişe ve sağdaki evrak dolabının önü cepheden görünür; masa düzlemi duvara doğru hafifçe
daralır. Masa düzlemi "düz masa koordinatları"ndan (u: 0..1280, v: 0..460) ekrana bir homografi
ile taşınır; aynı dönüşüm oyunda scripts/Perspektif.gd içinde kullanılır.

Çıktı: tools/sanat/ham/mock_masa_p.png (1280x720)
"""
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

K = 2
W, H = 1280, 720

DUVAR, DUVAR_KOYU, SERIT = "#b9c9b0", "#8fa78a", "#6e8a6b"
AHSAP, AHSAP_ACIK, AHSAP_KOYU = "#6b4a32", "#7d5a3e", "#4a3222"
SUMEN, KREM, BORDO = "#3f5345", "#f1e7cc", "#7a1f2b"

# Masa düzlemi: düz koordinat dikdörtgeni → ekrandaki yamuk
MASA_DUZ = [(0, 0), (1280, 0), (1280, 460), (0, 460)]
MASA_EKRAN = [(56, 306), (1208, 306), (1280, 720), (0, 720)]


def homografi(kaynak, hedef):
    a, b = [], []
    for (u, v), (x, y) in zip(kaynak, hedef):
        a.append([u, v, 1, 0, 0, 0, -u * x, -v * x]); b.append(x)
        a.append([0, 0, 0, u, v, 1, -u * y, -v * y]); b.append(y)
    h = np.linalg.solve(np.array(a, float), np.array(b, float))
    return np.append(h, 1.0).reshape(3, 3)


HM = homografi(MASA_DUZ, MASA_EKRAN)


def P(u, v):
    x, y, w = HM @ np.array([u, v, 1.0])
    return (x / w, y / w)


def main() -> None:
    im = Image.new("RGB", (W * K, H * K), DUVAR)
    d = ImageDraw.Draw(im)

    def kutu(x0, y0, x1, y1, renk, kenar=None, kal=0):
        d.rectangle([x0 * K, y0 * K, x1 * K, y1 * K], fill=renk, outline=kenar, width=kal * K)

    def cokgen(noktalar, renk, kenar=None, kal=1):
        d.polygon([(x * K, y * K) for x, y in noktalar], fill=renk, outline=kenar, width=kal * K)

    def daire(cx, cy, rx, ry, renk, kenar=None, kal=0):
        d.ellipse([(cx - rx) * K, (cy - ry) * K, (cx + rx) * K, (cy + ry) * K], fill=renk, outline=kenar, width=kal * K)

    def masa_dortgen(u0, v0, u1, v1):
        return [P(u0, v0), P(u1, v0), P(u1, v1), P(u0, v1)]

    # --- Masa düzlemi (önce çiz; duvar ve dolap üstüne gelir) ---
    kutu(0, 300, 1280, 720, AHSAP)
    for u in range(-200, 1500, 70):                      # duvara doğru daralan tahta çizgileri
        (x0, y0), (x1, y1) = P(u, 0), P(u + 6, 460)
        d.line([x0 * K, y0 * K, x1 * K, y1 * K], fill="#5f412b", width=K)
    cokgen(masa_dortgen(48, 26, 902, 448), SUMEN, "#2c3b31", 3)
    cokgen(masa_dortgen(62, 40, 888, 434), None, "#55705d", 1)

    # araç tepsisi: kenarlıklı, çuha kaplı
    cokgen(masa_dortgen(948, 168, 1270, 452), AHSAP_ACIK, "#3a2718", 2)
    cokgen(masa_dortgen(960, 180, 1258, 440), "#34463a", "#26342b", 1)
    # ıstampa kutusu (üç boyutlu teneke kutu; kapağı arkaya açık)
    cokgen(masa_dortgen(978, 196, 1094, 226), "#8b8f92", "#3c4043", 1)     # açık kapak
    cokgen(masa_dortgen(978, 230, 1094, 296), "#6f7478", "#3c4043", 1)     # kutu
    cokgen(masa_dortgen(986, 237, 1086, 289), BORDO)
    (ax, ay), (bx, by) = P(978, 296), P(1094, 296)
    cokgen([(ax, ay), (bx, by), (bx, by + 7), (ax, ay + 7)], "#4d5154")     # kutunun ön yüzü
    # çay bardağı: tabak (elips) + ayakta ince belli bardak
    cx, cy = P(1212, 392)
    daire(cx, cy, 36, 24, "#e8e0cf", "#a39a84", 2)
    cokgen([(cx - 13, cy - 44), (cx + 13, cy - 44), (cx + 9, cy - 22), (cx + 14, cy), (cx - 14, cy), (cx - 9, cy - 22)],
           "#9a3a1f", "#e8e0cf", 1)
    daire(cx, cy - 44, 13, 5, "#b5502a", "#e8e0cf", 1)

    # --- Duvar (cepheden) ---
    kutu(0, 0, 900, 306, DUVAR)
    kutu(0, 176, 900, 306, DUVAR_KOYU)
    kutu(0, 172, 900, 177, SERIT)
    kutu(0, 300, 900, 306, "#5c7358")                                       # süpürgelik gölgesi

    # gişe penceresi: çerçeve, boş salon, öne çıkan pervaz
    kutu(14, 10, 338, 268, AHSAP, AHSAP_KOYU, 2)
    kutu(40, 31, 313, 260, "#4c5a52")
    kutu(40, 31, 313, 112, "#566660")
    cokgen([(8, 262), (344, 262), (352, 276), (0, 276)], AHSAP_ACIK, AHSAP_KOYU, 1)   # pervazın üst yüzü
    kutu(0, 276, 352, 300, AHSAP, AHSAP_KOYU, 1)                                       # pervazın ön yüzü
    kutu(112, 281, 240, 291, "#2a2018")

    # saat, takvim
    daire(676.5, 60, 36, 36, AHSAP_KOYU)
    daire(676.5, 60, 31, 31, KREM)
    for i in range(12):
        a = math.radians(i * 30)
        d.line([(676.5 + math.sin(a) * 24) * K, (60 - math.cos(a) * 24) * K,
                (676.5 + math.sin(a) * 29) * K, (60 - math.cos(a) * 29) * K], fill="#2a2622", width=2 * K)
    kutu(645, 105, 708, 196, "#d9cfb4", "#7c705a", 1)
    kutu(645, 105, 708, 123, BORDO)
    kutu(647, 124, 707, 193, "#f7f2e4")

    # müdür odasının camlı bölmesi + plaket
    kutu(722, 39, 886, 200, AHSAP, AHSAP_KOYU, 2)
    kutu(731, 50, 876, 190, "#39453f")
    kutu(762, 14, 846, 35, "#c9b27a", "#5a4a2a", 1)

    # raf üstünde radyo (üst yüzü hafifçe görünür)
    kutu(366, 290, 560, 298, AHSAP_KOYU)
    cokgen([(389, 228), (536, 228), (540, 236), (385, 236)], "#a06c46", AHSAP_KOYU, 1)
    kutu(385, 236, 540, 290, "#8a5a3a", AHSAP_KOYU, 2)
    kutu(393, 244, 478, 283, "#c9b98f")
    for x in range(397, 476, 6):
        d.line([x * K, 246 * K, x * K, 281 * K], fill="#7a6a4a", width=K)
    daire(510, 262, 15, 15, KREM, AHSAP_KOYU, 2)

    # askılık: palto ve kasket
    kutu(752, 212, 872, 221, AHSAP_KOYU)
    kutu(778, 221, 836, 300, "#4a4640")
    daire(858, 232, 11, 13, "#5a5348")

    # --- Sağda evrak dolabı: önü cepheden, sol yanı ince bir şerit hâlinde görünür ---
    cokgen([(900, 0), (900, 440), (888, 306), (888, 0)], "#2f1f14")
    kutu(900, 0, 1280, 440, AHSAP_KOYU)
    kutu(908, 8, 1268, 430, "#8a6a44", "#3a2718", 3)
    kutu(916, 16, 1260, 421, "#b9945f")
    kutu(900, 432, 1280, 440, "#2f1f14")                                    # dolabın masaya düşen gölgesi

    cikti = Path(__file__).parent / "ham"
    cikti.mkdir(exist_ok=True)
    im.resize((W, H), Image.LANCZOS).save(cikti / "mock_masa_p.png")
    print("yazildi:", cikti / "mock_masa_p.png")


if __name__ == "__main__":
    main()
