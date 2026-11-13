"""Dilimlenmiş görsellerde komşu görselden kalmış kırpıkları arar.

Bir sayfadan dilimlenen görselde (damga, imza, nesne, eşya) dilim kutusu komşusuna taşarsa, komşunun
bir parçası görselin kenarında kesik olarak kalır. Bu betik saydamlığı olan her görselde bağlantılı
parçaları çıkarır ve şunları bildirir:
  - kenara yaslı, düz kesilmiş parça (kenar boyunca uzun bir temas) ve asıl gövdeden ayrı duruyor;
  - asıl gövdeden uzakta duran, gövdenin en az %1,5'i büyüklüğünde ayrı parça.

Kullanım: python tools/sanat/kirpik_tara.py [--goster çıktı.png | --temizle assets/img/.../ad.webp]
  --goster   bulunan görselleri yan yana tek bir sayfaya döker (gözle bakmak için)
  --temizle  görseldeki kenarda kesik parçaları siler, görseli asıl gövdeye yeniden kırpar
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

KOK = Path(__file__).resolve().parents[2]
KLASORLER = ["assets/img/damga", "assets/img/imza", "assets/img/nesne", "assets/img/rontgen/esya",
             "assets/img/rontgen/kabuk", "assets/img/kagit"]


def incele(yol: Path) -> list:
    im = Image.open(yol)
    if im.mode != "RGBA":
        return []
    alfa = np.array(im.getchannel("A")) > 40
    if alfa.all() or not alfa.any():
        return []
    # yakın parçalar tek gövde sayılsın (harfler, noktalar): maskeyi biraz şişir
    sisik = ndimage.binary_dilation(alfa, iterations=max(2, min(alfa.shape) // 60))
    etiket, adet = ndimage.label(sisik)
    if adet < 2:
        return []
    alanlar = ndimage.sum(alfa, etiket, range(1, adet + 1))
    govde = int(np.argmax(alanlar)) + 1
    h, w = alfa.shape
    bulgular = []
    for no, dilim in enumerate(ndimage.find_objects(etiket), 1):
        if no == govde or alanlar[no - 1] < max(40.0, alanlar[govde - 1] * 0.015):
            continue
        parca = (etiket == no) & alfa
        temas = max(parca[0, :].sum(), parca[-1, :].sum(), parca[:, 0].sum(), parca[:, -1].sum())
        y0, y1, x0, x1 = dilim[0].start, dilim[0].stop, dilim[1].start, dilim[1].stop
        tur = "kenarda kesik" if temas >= 6 else "ayrı parça"
        if tur == "ayrı parça" and yol.parent.name == "imza":
            continue                                  # imzalar zaten ayrık kalem darbelerinden oluşur
        bulgular.append((tur, int(alanlar[no - 1]), (x0, y0, x1, y1), int(temas)))
    return bulgular


def temizle(yol: Path, pay: int = 8) -> None:
    """Kenarda kesik kalmış komşu parçalarını siler ve görseli asıl gövdeye yeniden kırpar."""
    im = Image.open(yol).convert("RGBA")
    a = np.array(im)
    alfa = a[..., 3] > 40
    sisik = ndimage.binary_dilation(alfa, iterations=max(2, min(alfa.shape) // 60))
    etiket, adet = ndimage.label(sisik)
    silinen = 0
    for no in range(1, adet + 1):
        parca = etiket == no
        temas = max(parca[0, :].sum(), parca[-1, :].sum(), parca[:, 0].sum(), parca[:, -1].sum())
        govde = ndimage.sum(alfa, etiket, no) == max(ndimage.sum(alfa, etiket, range(1, adet + 1)))
        if temas >= 6 and not govde:
            a[parca] = 0
            silinen += 1
    kalan = Image.fromarray(a, "RGBA")
    kutu = kalan.getchannel("A").point(lambda v: 255 if v > 12 else 0).getbbox()
    kalan = kalan.crop((max(0, kutu[0] - pay), max(0, kutu[1] - pay), min(im.width, kutu[2] + pay), min(im.height, kutu[3] + pay)))
    kalan.save(yol, quality=92, method=4, alpha_quality=100)
    print(f"{yol.name}: {silinen} parça silindi, {im.size} -> {kalan.size}")


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    if len(sys.argv) >= 3 and sys.argv[1] == "--temizle":
        temizle(KOK / sys.argv[2])
        return
    bulunan = []
    for klasor in KLASORLER:
        for yol in sorted((KOK / klasor).glob("*.webp")):
            b = incele(yol)
            if b:
                bulunan.append(yol)
                ozet = "; ".join(f"{tur} {kutu} alan {alan} temas {temas}" for tur, alan, kutu, temas in b)
                print(f"{yol.relative_to(KOK).as_posix()}: {ozet}")
    print(f"{len(bulunan)} görselde kuşkulu parça var")
    if len(sys.argv) >= 3 and sys.argv[1] == "--goster" and bulunan:
        kare = 300
        sutun = 5
        satir = (len(bulunan) + sutun - 1) // sutun
        sayfa = Image.new("RGB", (sutun * kare, satir * kare), (240, 232, 214))
        for i, yol in enumerate(bulunan):
            im = Image.open(yol).convert("RGBA")
            im.thumbnail((kare - 16, kare - 16))
            zemin = Image.new("RGBA", im.size, (120, 150, 130, 255))
            zemin.alpha_composite(im)
            sayfa.paste(zemin.convert("RGB"), ((i % sutun) * kare + 8, (i // sutun) * kare + 8))
        sayfa.save(sys.argv[2])


if __name__ == "__main__":
    main()
