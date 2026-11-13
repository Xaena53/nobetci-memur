"""Dairenin yuvarlak mührünü (assets/img/damga/daire.webp) düzeltir.

Üretilen görselde halkadaki yazı "ARDIÇLI NÜFUS MÜDÜRLÜĞ" diye bitiyordu: sondaki "Ü" eksikti.
Bu betik halkadaki harfleri bağlantılı parçalar olarak ayırır, sondan bir önceki harfi ("Ü") kopyalayıp "Ğ"nin
ardına koyar ve yazının tamamını yarım harf kadar geri çevirir (yazı iki noktanın arasında ortalı
kalsın diye). Her parça yalnızca bir kez döndürülür.

Görsel zaten düzeltilmişse (yazı 205 dereceden geniş bir yay tutuyorsa) dokunmaz.

Kullanım: python tools/sanat/daire_muhru.py [çıktı.webp]
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage
from scipy.ndimage import binary_dilation

KOK = Path(__file__).resolve().parents[2]
YOL = KOK / "assets" / "img" / "damga" / "daire.webp"
KAYMA = 140.0          # açı ölçeğinin başlangıcı: yazı soldan başlayıp tepeden sağa döner
BAND = (0.635, 0.888)  # yazının durduğu halka (dış yarıçapın oranı): iç dairenin dışı, çift halkanın içi
ARALIK = (14.0, 247.0) # yazının açı aralığı: iki yandaki noktalar dışarıda kalır


def harfler(alfa: np.ndarray, t: np.ndarray, bant: np.ndarray) -> tuple:
    """Banttaki harfleri bağlantılı parçalar olarak ayırır.

    (etiket haritası, [(harf no, ağırlık merkezinin açısı), ...] açıya göre sıralı) döner. Noktalar ve
    şapkalar (küçük parçalar) açıca en yakın harfe katılır.
    """
    etiket, adet = ndimage.label(bant & (alfa > 60))
    alanlar = ndimage.sum(np.ones_like(alfa), etiket, range(1, adet + 1))
    acilar = ndimage.mean(t, etiket, range(1, adet + 1))
    buyuk = [no for no in range(1, adet + 1) if alanlar[no - 1] >= 0.35 * np.median(alanlar[alanlar > 30])]
    for no in range(1, adet + 1):
        if no in buyuk:
            continue
        yakin = min(buyuk, key=lambda b: abs(acilar[b - 1] - acilar[no - 1]))
        etiket[etiket == no] = yakin
    return etiket, sorted(((no, float(acilar[no - 1])) for no in buyuk), key=lambda x: x[1])


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    im = Image.open(YOL).convert("RGBA")
    a = np.array(im)
    alfa = a[..., 3].astype(np.float32)
    kutu = im.getchannel("A").point(lambda v: 255 if v > 40 else 0).getbbox()
    cx, cy = (kutu[0] + kutu[2] - 1) / 2.0, (kutu[1] + kutu[3] - 1) / 2.0
    dis = max(kutu[2] - kutu[0], kutu[3] - kutu[1]) / 2.0
    yy, xx = np.mgrid[0:a.shape[0], 0:a.shape[1]].astype(np.float32)
    r = np.hypot(xx - cx, yy - cy) / dis
    t = (np.degrees(np.arctan2(yy - cy, xx - cx)) - KAYMA) % 360.0
    bant = (r > BAND[0]) & (r < BAND[1]) & (t > ARALIK[0]) & (t < ARALIK[1])
    etiket, h = harfler(alfa, t, bant)
    yazili = t[bant & (alfa > 60)]
    genislik = float(yazili.max() - yazili.min())
    print(f"merkez ({cx:.1f}, {cy:.1f}), dış yarıçap {dis:.1f}, halkada {len(h)} parça, yazı {genislik:.1f} derece")
    if genislik > 205.0:
        print("yazı zaten tam (eksik harfli hâli 200 derece tutar); dokunulmadı")
        return
    (u_no, u_aci), (_g_no, g_aci) = h[-2], h[-1]      # Ü ve Ğ
    delta = 2.0 * (g_aci - u_aci)                     # Ü'nün kopyası Ğ'nin bir harf ötesine gider
    print(f"Ü {u_aci:.1f}, Ğ {g_aci:.1f} derecede; kopya {delta:.1f} derece ileri, yazı {delta / 2:.1f} derece geri")

    def katman(maske: np.ndarray) -> Image.Image:
        k = np.zeros(alfa.shape, np.uint8)
        k[maske] = alfa[maske].astype(np.uint8)
        return Image.fromarray(k, "L")

    yazi = katman(bant)
    u_harfi = katman(binary_dilation(etiket == u_no, iterations=2) & bant)
    merkez = (cx, cy)
    # PIL'de artı açı saat yönünün tersidir: yazı geri (ters yöne), kopya ileri (saat yönüne) döner
    yazi_d = yazi.rotate(delta / 2.0, resample=Image.BICUBIC, center=merkez)
    kopya_d = u_harfi.rotate(-delta / 2.0, resample=Image.BICUBIC, center=merkez)
    yeni = alfa.copy()
    yeni[bant] = 0.0
    yeni = np.maximum(yeni, np.maximum(np.array(yazi_d, np.float32), np.array(kopya_d, np.float32)))
    a[..., 3] = np.clip(yeni, 0, 255).astype(np.uint8)
    cikti = Path(sys.argv[1]) if len(sys.argv) > 1 else YOL
    Image.fromarray(a, "RGBA").save(cikti, quality=92, method=4, alpha_quality=100)
    print("yazıldı:", cikti)


if __name__ == "__main__":
    main()
