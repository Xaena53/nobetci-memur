"""Mühür ve kaşe sayfasını (tools/sanat/ham/damgalar.png: beyaz üstüne siyah ıstampa, 5x4) tek tek keser.

Her damga beyaz renkli bir saydamlık maskesi olarak saklanır; mürekkebin rengi (mor, kırmızı, mavi) oyunda
verilir. Böylece "yanlış renkli" sahte damga, gerçeğinin başka renkle basılmış hâlidir.

Ayrıca yazılı ofis eşyalarını (tools/sanat/ham/yazili_esya.png, saydam zeminli 4x4) dilimler: müdür plaketi,
bilgi defterinin kapağı, karar fişleri, röntgen cihazının etiketleri, "KAPALI" levhası, şerit etiketler.

Çıktı: assets/img/damga/<ad>.webp, assets/img/nesne/<ad>.webp      Denetim: tools/sanat/ham/damga_denetim.jpg
Kullanım: python tools/sanat/damgalar.py
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

sys.path.insert(0, str(Path(__file__).resolve().parent))
from dilimle import kaydet  # noqa: E402

KOK = Path(__file__).resolve().parents[2]
HAM = Path(__file__).resolve().parent / "ham"
DAMGA = KOK / "assets" / "img" / "damga"
NESNE = KOK / "assets" / "img" / "nesne"

# sayfadaki sıra (satır satır): <çeşit>_<gerçek ya da sahtecilik türü>
DAMGALAR = ["muhtar_gercek", "muhtar_oval", "muhtar_tek_halka", "muhtar_yildizsiz", "muhtar_ic_halkasiz",
            "muhtar_yazim", "muhtar_baska_mahalle", "vezne_gercek", "vezne_cift_cerceve", "vezne_alt_satirsiz",
            "vezne_yazim", "vize_gercek", "vize_oval", "vize_tek_halka", "vize_ortasiz",
            "vize_ic_halkasiz", "vize_yazim", "daire", "onay", "gorulmustur"]
ESYALAR = ["plaket_mudur", "defter_kapak", "fis_eksik", "fis_havale",
           "etiket_gecir", "etiket_alarm", "etiket_olagan", "etiket_negatif",
           "etiket_yogun", "plaka_rontgen", "levha_kapali", "serit_mudur_izliyor",
           "serit_canta", "serit_inceleme_acik", "serit_incele", "serit_bos"]


def hucre_kutulari(maske: np.ndarray, sutun: int, satir: int, en_az: int = 30) -> list:
    """Izgaradaki her hücre için, merkezi o hücreye düşen parçaların ortak kutusu."""
    etiket, n = ndimage.label(maske)
    dilimler = ndimage.find_objects(etiket)
    alanlar = ndimage.sum(maske, etiket, range(1, n + 1))
    h, w = maske.shape
    kutular = [None] * (sutun * satir)
    for i in range(n):
        if alanlar[i] < en_az:
            continue
        ys, xs = dilimler[i]
        cx, cy = (xs.start + xs.stop) / 2, (ys.start + ys.stop) / 2
        k = min(satir - 1, int(cy / h * satir)) * sutun + min(sutun - 1, int(cx / w * sutun))
        kutu = (xs.start, ys.start, xs.stop, ys.stop)
        o = kutular[k]
        kutular[k] = kutu if o is None else (min(o[0], kutu[0]), min(o[1], kutu[1]), max(o[2], kutu[2]), max(o[3], kutu[3]))
    return kutular


def damgalar(denetim: list) -> None:
    yol = HAM / "damgalar.png"
    if not yol.exists():
        return
    DAMGA.mkdir(parents=True, exist_ok=True)
    a = np.array(Image.open(yol).convert("RGB")).astype(np.float32) / 255.0
    koyuluk = 1.0 - a.max(axis=2)
    alfa = np.clip((koyuluk - 0.08) / 0.70, 0.0, 1.0)
    h, w = alfa.shape
    for ad, kutu in zip(DAMGALAR, hucre_kutulari(alfa > 0.3, 5, 4)):
        if kutu is None:
            print(f"  {ad}: BULUNAMADI")
            continue
        pay = 8
        x0, y0 = max(0, kutu[0] - pay), max(0, kutu[1] - pay)
        x1, y1 = min(w, kutu[2] + pay), min(h, kutu[3] + pay)
        maske = (alfa[y0:y1, x0:x1] * 255).astype(np.uint8)
        parca = Image.fromarray(np.dstack([np.full_like(maske, 255)] * 3 + [maske]), "RGBA")
        yol_cikti = DAMGA / f"{ad}.webp"
        parca.save(yol_cikti, quality=92, method=4, alpha_quality=100)
        # kutu komşu damgaya taştıysa onun kesik parçası da girmiştir: at (bkz. kirpik_tara.py)
        from kirpik_tara import incele, temizle
        if any(tur == "kenarda kesik" for tur, _alan, _kutu, _temas in incele(yol_cikti)):
            temizle(yol_cikti)
            parca = Image.open(yol_cikti)
        denetim.append((ad, parca, (91, 58, 130)))
        print(f"  {ad}: {parca.width}x{parca.height}")


def esyalar(denetim: list) -> None:
    yol = HAM / "yazili_esya.png"
    if not yol.exists():
        return
    ham = np.array(Image.open(yol).convert("RGBA"))
    # üretimden kalan soluk hücre izlerini ve zemine düşen gölgeleri at: yalnızca nesnenin kendisi kalsın
    temiz = np.clip((ham[..., 3].astype(np.float32) - 90.0) / 150.0, 0.0, 1.0)
    ham[..., 3] = (temiz * 255).astype(np.uint8)
    im = Image.fromarray(ham, "RGBA")
    alfa = ham[..., 3]
    for ad, kutu in zip(ESYALAR, hucre_kutulari(alfa > 60, 4, 4, 400)):
        if kutu is None:
            print(f"  {ad}: BULUNAMADI")
            continue
        w, h = kaydet(im, kutu, 1.0, NESNE / f"{ad}.webp")
        denetim.append((ad, Image.open(NESNE / f"{ad}.webp").convert("RGBA"), None))
        print(f"  {ad}: {w}x{h}")


def main() -> None:
    denetim = []
    damgalar(denetim)
    esyalar(denetim)
    if not denetim:
        return
    hucre = (260, 230)
    sutun = 6
    satir = (len(denetim) + sutun - 1) // sutun
    sayfa = Image.new("RGB", (sutun * hucre[0], satir * hucre[1]), (236, 226, 200))
    ciz = ImageDraw.Draw(sayfa)
    for i, (ad, g, renk) in enumerate(denetim):
        g = g.copy()
        g.thumbnail((hucre[0] - 16, hucre[1] - 30))
        if renk is not None:
            boya = Image.new("RGBA", g.size, renk + (255,))
            boya.putalpha(g.getchannel("A"))
            g = boya
        x, y = (i % sutun) * hucre[0], (i // sutun) * hucre[1]
        sayfa.paste(g, (x + (hucre[0] - g.width) // 2, y + 22 + (hucre[1] - 30 - g.height) // 2), g)
        ciz.text((x + 5, y + 4), ad, fill=(90, 30, 30))
    sayfa.save(HAM / "damga_denetim.jpg", quality=90)


if __name__ == "__main__":
    main()
