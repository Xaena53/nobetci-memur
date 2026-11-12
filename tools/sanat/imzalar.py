"""İmza sayfasını (tools/sanat/ham/imzalar.png: beyaz üstüne lacivert mürekkep, 4x4) tek tek imzalara ayırır.

Her imza beyaz renkli bir saydamlık maskesi olarak saklanır: mürekkebin koyuluğu saydamlığa çevrilir,
böylece oyun imzayı istediği mürekkep rengiyle çizer ve kalem baskısındaki ton farkı korunur.

Çıktı: assets/img/imza/<kod>.webp      Denetim: tools/sanat/ham/imza_denetim.jpg
Kullanım: python tools/sanat/imzalar.py
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

KOK = Path(__file__).resolve().parents[2]
HAM = Path(__file__).resolve().parent / "ham"
HEDEF = KOK / "assets" / "img" / "imza"

# sayfadaki sıra (satır satır); "mudur" ve "veznedar" dışındakiler muhtar adlarıdır (data/adlar.json)
KISILER = ["mudur", "Rıza Aksoy", "Kâzım Türkmen", "Nuri Bozkurt",
           "Hamdi Ersoy", "Sabri Güneş", "Şükrü Akın", "Bekir Sezer",
           "Osman Tuna", "Halil Çınar", "Celâl Erdem", "Fevzi Balcı",
           "Tahir Ayaz", "İdris Kökten", "Mevlüt Sarıkaya", "veznedar"]
HARFLER = str.maketrans({"ı": "i", "İ": "i", "ş": "s", "Ş": "s", "ğ": "g", "Ğ": "g", "ü": "u", "Ü": "u",
                         "ö": "o", "Ö": "o", "ç": "c", "Ç": "c", "â": "a", "Â": "a", "î": "i", "û": "u"})


def kod(kisi: str) -> str:
    """scripts/Imza.gd içindeki `kod` ile aynı kural: "Kâzım Türkmen" → "kazim_turkmen"."""
    s = kisi.strip().translate(HARFLER).lower()
    for ayrac in " .-":
        s = s.replace(ayrac, "_")
    while "__" in s:
        s = s.replace("__", "_")
    return s.rstrip("_")


def main() -> None:
    HEDEF.mkdir(parents=True, exist_ok=True)
    im = Image.open(HAM / "imzalar.png").convert("RGB")
    a = np.array(im).astype(np.float32) / 255.0
    # mürekkep: beyazdan uzaklık (lacivert mürekkepte kırmızı ve yeşil düşer)
    koyuluk = 1.0 - np.minimum(a[..., 0], a[..., 1])
    alfa = np.clip((koyuluk - 0.10) / 0.62, 0.0, 1.0)
    h, w = alfa.shape
    etiket, n = ndimage.label(alfa > 0.25)
    dilimler = ndimage.find_objects(etiket)
    alanlar = ndimage.sum(alfa > 0.25, etiket, range(1, n + 1))
    kutular = [None] * 16
    for i in range(n):
        if alanlar[i] < 25:
            continue
        ys, xs = dilimler[i]
        cx, cy = (xs.start + xs.stop) / 2, (ys.start + ys.stop) / 2
        k = min(3, int(cy / h * 4)) * 4 + min(3, int(cx / w * 4))
        kutu = (xs.start, ys.start, xs.stop, ys.stop)
        o = kutular[k]
        kutular[k] = kutu if o is None else (min(o[0], kutu[0]), min(o[1], kutu[1]), max(o[2], kutu[2]), max(o[3], kutu[3]))
    denetim = Image.new("RGB", (4 * 420, 4 * 190), (241, 231, 204))
    ciz = ImageDraw.Draw(denetim)
    for i, (kisi, kutu) in enumerate(zip(KISILER, kutular)):
        if kutu is None:
            print(f"  {kisi}: BULUNAMADI")
            continue
        pay = 8
        x0, y0 = max(0, kutu[0] - pay), max(0, kutu[1] - pay)
        x1, y1 = min(w, kutu[2] + pay), min(h, kutu[3] + pay)
        maske = (alfa[y0:y1, x0:x1] * 255).astype(np.uint8)
        rgba = np.dstack([np.full_like(maske, 255)] * 3 + [maske])
        parca = Image.fromarray(rgba, "RGBA")
        if parca.width > 440:
            parca = parca.resize((440, round(parca.height * 440 / parca.width)), Image.LANCZOS)
        parca.save(HEDEF / f"{kod(kisi)}.webp", quality=92, method=4, alpha_quality=100)
        print(f"  {kod(kisi)}: {parca.width}x{parca.height}")
        # denetim: lacivert mürekkeple kâğıt üstünde
        kucuk = parca.copy()
        kucuk.thumbnail((400, 150))
        murekkep = Image.new("RGBA", kucuk.size, (43, 58, 122, 255))
        murekkep.putalpha(kucuk.getchannel("A"))
        x, y = (i % 4) * 420, (i // 4) * 190
        denetim.paste(murekkep, (x + (420 - kucuk.width) // 2, y + 22 + (150 - kucuk.height) // 2), murekkep)
        ciz.text((x + 6, y + 4), kisi, fill=(90, 40, 40))
    denetim.save(HAM / "imza_denetim.jpg", quality=90)


if __name__ == "__main__":
    main()
