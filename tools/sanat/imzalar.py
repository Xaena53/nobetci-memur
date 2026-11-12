"""İmza sayfasını (tools/sanat/ham/imzalar.png: beyaz üstüne lacivert mürekkep, 4x4) tek tek imzalara ayırır.

Her imza beyaz renkli bir saydamlık maskesi olarak saklanır: mürekkebin koyuluğu saydamlığa çevrilir,
böylece oyun imzayı istediği mürekkep rengiyle çizer ve kalem baskısındaki ton farkı korunur.

Sayfalar: imzalar.png (müdür, muhtarlar, veznedar; 4x4) ve imzalar_1..4.png (vatandaşlar, hikâye kişileri,
vize memurları; 5x5, sırası tools/sanat/kadro.py'den).

Çıktı: assets/img/imza/<kod>.webp      Denetim: tools/sanat/ham/imza_denetim*.jpg
Kullanım: python tools/sanat/imzalar.py
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

sys.path.insert(0, str(Path(__file__).resolve().parent))
import kadro  # noqa: E402

KOK = Path(__file__).resolve().parents[2]
HAM = Path(__file__).resolve().parent / "ham"
HEDEF = KOK / "assets" / "img" / "imza"

# sayfadaki sıra (satır satır); "mudur" ve "veznedar" dışındakiler muhtar adlarıdır (data/adlar.json)
KISILER = ["mudur", "Rıza Aksoy", "Kâzım Türkmen", "Nuri Bozkurt",
           "Hamdi Ersoy", "Sabri Güneş", "Şükrü Akın", "Bekir Sezer",
           "Osman Tuna", "Halil Çınar", "Celâl Erdem", "Fevzi Balcı",
           "Tahir Ayaz", "İdris Kökten", "Mevlüt Sarıkaya", "veznedar"]
# imza sayfasındaki ad → dosya kodu (adı olmayan görevliler); None: atlanır
OZEL_KODLAR = {"J. Hoffmann": "vize_memuru", "A. Keller": "vize_memuru_2", "Cevdet": None}
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


def sayfa_isle(dosya: Path, kisiler: list, sutun: int, satir: int, denetim_adi: str) -> None:
    """Bir imza sayfasını ızgara hücrelerine göre keser; her imzayı kişinin koduyla kaydeder."""
    im = Image.open(dosya).convert("RGB")
    a = np.array(im).astype(np.float32) / 255.0
    # mürekkep: beyazdan uzaklık (lacivert mürekkepte kırmızı ve yeşil düşer)
    koyuluk = 1.0 - np.minimum(a[..., 0], a[..., 1])
    alfa = np.clip((koyuluk - 0.10) / 0.62, 0.0, 1.0)
    h, w = alfa.shape
    etiket, n = ndimage.label(alfa > 0.25)
    dilimler = ndimage.find_objects(etiket)
    alanlar = ndimage.sum(alfa > 0.25, etiket, range(1, n + 1))
    kutular = [None] * (sutun * satir)
    for i in range(n):
        if alanlar[i] < 25:
            continue
        ys, xs = dilimler[i]
        cx, cy = (xs.start + xs.stop) / 2, (ys.start + ys.stop) / 2
        k = min(satir - 1, int(cy / h * satir)) * sutun + min(sutun - 1, int(cx / w * sutun))
        kutu = (xs.start, ys.start, xs.stop, ys.stop)
        o = kutular[k]
        kutular[k] = kutu if o is None else (min(o[0], kutu[0]), min(o[1], kutu[1]), max(o[2], kutu[2]), max(o[3], kutu[3]))
    hucre = (420, 190)
    denetim = Image.new("RGB", (sutun * hucre[0], satir * hucre[1]), (241, 231, 204))
    ciz = ImageDraw.Draw(denetim)
    for i, (kisi, kutu) in enumerate(zip(kisiler, kutular)):
        if kisi is None:
            continue
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
        kucuk = parca.copy()
        kucuk.thumbnail((hucre[0] - 20, hucre[1] - 40))
        murekkep = Image.new("RGBA", kucuk.size, (43, 58, 122, 255))
        murekkep.putalpha(kucuk.getchannel("A"))
        x, y = (i % sutun) * hucre[0], (i // sutun) * hucre[1]
        denetim.paste(murekkep, (x + (hucre[0] - kucuk.width) // 2, y + 22 + (hucre[1] - 40 - kucuk.height) // 2), murekkep)
        ciz.text((x + 6, y + 4), kod(kisi), fill=(90, 40, 40))
    denetim.save(HAM / denetim_adi, quality=88)
    print(f"{dosya.name}: {sum(1 for k in kisiler if k is not None)} imza")


def main() -> None:
    HEDEF.mkdir(parents=True, exist_ok=True)
    # müdür, muhtarlar ve veznedar
    if (HAM / "imzalar.png").exists():
        sayfa_isle(HAM / "imzalar.png", KISILER, 4, 4, "imza_denetim.jpg")
    # vatandaşlar ve hikâye kişileri: sıra tools/sanat/kadro.py'den gelir (sayfa başına 25 imza)
    sira = kadro.imza_sirasi()
    for no in range(4):
        dosya = HAM / f"imzalar_{no + 1}.png"
        if not dosya.exists():
            continue
        kisiler = [OZEL_KODLAR.get(k, k) for k in sira[no * 25:(no + 1) * 25]]
        sayfa_isle(dosya, kisiler, 5, 5, f"imza_denetim_{no + 1}.jpg")


if __name__ == "__main__":
    main()
