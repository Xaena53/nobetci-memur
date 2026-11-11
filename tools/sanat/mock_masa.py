"""Masa sahnesinin yerleşim taslağı (mock).

Görsel üretim aracına "bu yerleşimi boya" diye referans verilir; oyun arayüzü de aynı
koordinatları kullanır (scripts/Yerlesim.gd). Çıktı: tools/sanat/ham/mock_masa.png (1280x720).
"""
from pathlib import Path
from PIL import Image, ImageDraw

K = 2  # 2x çizip küçült: kenarlar yumuşasın
W, H = 1280, 720

DUVAR = "#b9c9b0"
DUVAR_KOYU = "#8fa78a"
SERIT = "#6e8a6b"
AHSAP = "#6b4a32"
AHSAP_ACIK = "#7d5a3e"
AHSAP_KOYU = "#4a3222"
SUMEN = "#3f5345"
KREM = "#f1e7cc"
BORDO = "#7a1f2b"
KARANLIK = "#4c5a52"


def main() -> None:
    im = Image.new("RGB", (W * K, H * K), DUVAR)
    d = ImageDraw.Draw(im)

    def kutu(x0, y0, x1, y1, renk, kenar=None, kal=0):
        d.rectangle([x0 * K, y0 * K, x1 * K, y1 * K], fill=renk, outline=kenar, width=kal * K)

    def daire(cx, cy, r, renk, kenar=None, kal=0):
        d.ellipse([(cx - r) * K, (cy - r) * K, (cx + r) * K, (cy + r) * K], fill=renk, outline=kenar, width=kal * K)

    # Duvar: üst açık, alt yağlı boya kuşağı
    kutu(0, 0, 896, 304, DUVAR)
    kutu(0, 176, 896, 304, DUVAR_KOYU)
    kutu(0, 172, 896, 177, SERIT)

    # Gişe penceresi: ahşap çerçeve, karanlık bekleme salonu, pervaz ve evrak yarığı
    kutu(14, 10, 338, 296, AHSAP, AHSAP_KOYU, 2)
    kutu(38, 30, 314, 268, KARANLIK)
    kutu(38, 30, 314, 110, "#566660")           # salonun arka duvarı (biraz aydınlık)
    kutu(8, 268, 344, 304, AHSAP_ACIK, AHSAP_KOYU, 2)
    kutu(112, 280, 240, 291, "#2a2018")         # evrak yarığı

    # Duvar saati (akrep-yelkovan yok), takvim
    daire(678, 64, 36, AHSAP_KOYU)
    daire(678, 64, 31, KREM)
    for i in range(12):
        import math
        a = math.radians(i * 30)
        x0, y0 = 678 + math.sin(a) * 24, 64 - math.cos(a) * 24
        x1, y1 = 678 + math.sin(a) * 29, 64 - math.cos(a) * 29
        d.line([x0 * K, y0 * K, x1 * K, y1 * K], fill="#2a2622", width=2 * K)
    kutu(646, 110, 710, 202, "#d9cfb4", "#7c705a", 1)
    kutu(646, 110, 710, 128, BORDO)
    kutu(652, 132, 704, 198, "#f7f2e4")

    # Müdür odasının camlı bölmesi ve kapı üstü plaket
    kutu(724, 42, 888, 206, AHSAP, AHSAP_KOYU, 2)
    kutu(734, 52, 878, 196, "#39453f")
    kutu(764, 20, 848, 40, "#c9b27a", "#5a4a2a", 1)

    # Raf üstünde eski radyo
    kutu(366, 296, 560, 303, AHSAP_KOYU)
    kutu(384, 240, 540, 296, "#8a5a3a", AHSAP_KOYU, 2)
    kutu(392, 248, 478, 288, "#c9b98f")
    for x in range(396, 476, 6):
        d.line([x * K, 250 * K, x * K, 286 * K], fill="#7a6a4a", width=K)
    daire(510, 268, 16, KREM, AHSAP_KOYU, 2)

    # Askılık: palto ve kasket
    kutu(752, 216, 872, 224, AHSAP_KOYU)
    kutu(780, 224, 838, 302, "#4a4640")
    daire(858, 232, 11, "#5a5348")

    # Masa: üstten görünüm, yeşil sümen
    kutu(0, 304, 896, 720, AHSAP)
    kutu(0, 304, 896, 312, AHSAP_KOYU)
    for y in range(322, 720, 22):
        d.line([0, y * K, 896 * K, (y + 3) * K], fill="#5f412b", width=K)
    kutu(28, 332, 868, 704, SUMEN, "#2c3b31", 3)
    kutu(40, 344, 856, 692, None, "#55705d", 1)

    # Sağ yan dolap: mantar pano ve çuha kaplı araç tepsisi
    kutu(896, 0, 1280, 720, AHSAP_KOYU)
    kutu(896, 0, 902, 720, "#2f1f14")
    kutu(908, 12, 1268, 436, "#8a6a44", "#3a2718", 3)
    kutu(916, 20, 1260, 428, "#b9945f")
    kutu(908, 448, 1268, 708, "#6b4a32", "#3a2718", 3)
    kutu(916, 456, 1260, 700, "#34463a")
    # ıstampa kutusu (açık, bordo mürekkep)
    kutu(928, 480, 1058, 562, "#6f7478", "#3c4043", 2)
    kutu(938, 490, 1048, 552, BORDO)
    # çay bardağı ve tabağı (üstten)
    daire(1206, 646, 34, "#e8e0cf", "#a39a84", 2)
    daire(1206, 646, 19, "#9a3a1f", "#e8e0cf", 3)

    cikti = Path(__file__).parent / "ham"
    cikti.mkdir(exist_ok=True)
    im = im.resize((W, H), Image.LANCZOS)
    im.save(cikti / "mock_masa.png")
    print("yazıldı:", cikti / "mock_masa.png")


if __name__ == "__main__":
    main()
