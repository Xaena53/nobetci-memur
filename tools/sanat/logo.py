"""Oyunun logosunu ham görselden (tools/sanat/ham/logo/logo_ham.png) hazırlar ve tanıtım görsellerini kurar.

Ham görselde iki kusur giderilir:
  - yuvarlak mührün içi beyazımsı bir dolguyla kaplıdır (koyu zeminde çıkartma gibi durur): dolgu saydamlaştırılır,
    mor mürekkep ve altında kalan kırmızı çerçeve ile harf ayrı ayrı yeniden kurulur ("mühür üstüne mühür");
  - iki satırın arasındaki yıldız alttaki M harfine çok yakındır, küçük boyda harfe yapışık görünür: küçültülür.

Çıktılar:
  docs/img/logo.png                     saydam, tam çözünürlük
  docs/img/logo_kagit.png               krem kâğıt üstünde
  docs/img/kapak_920x430.jpg            mağaza başlık görseli (menü sahnesinin üstünde logo)
  docs/img/kapak_630x500.jpg            itch.io kapak görseli
  assets/img/acilis.png                 oyun açılırken görünen logo (kâğıt etiket)
  icon.png, icon.ico                    uygulama simgesi: logonun harflerinden "NM", köşesinde mor mühür

Kullanım: python tools/sanat/logo.py
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

KOK = Path(__file__).resolve().parents[2]
HAM = Path(__file__).resolve().parent / "ham" / "logo" / "logo_ham.png"
KAGIT = (240, 232, 214)
MUHUR = {}          # muhru_temizle doldurur: {"katman": yalnız mor mürekkep (RGBA), "kutu": (x0, y0, x1, y1)}


def hsv(rgb: np.ndarray) -> tuple:
    h = np.array(Image.fromarray(rgb.astype(np.uint8)).convert("HSV")).astype(np.float32)
    return h[..., 0] / 255.0 * 360.0, h[..., 1] / 255.0, h[..., 2] / 255.0


def muhru_temizle(a: np.ndarray) -> np.ndarray:
    """Yuvarlak mührün içindeki beyazımsı dolguyu atar; mor mürekkebi ve altındaki kırmızıyı ayrı ayrı kurar."""
    ton, doy, par = hsv(a[..., :3])
    alfa = a[..., 3].astype(np.float32) / 255.0
    mor = (ton > 225) & (ton < 300) & (doy > 0.30) & (par < 0.62) & (alfa > 0.5)
    ys, xs = np.nonzero(mor)
    cx, cy = (xs.min() + xs.max()) / 2.0, (ys.min() + ys.max()) / 2.0
    r = max(xs.max() - xs.min(), ys.max() - ys.min()) / 2.0 + 4.0
    yy, xx = np.mgrid[0:a.shape[0], 0:a.shape[1]].astype(np.float32)
    disk = (xx - cx) ** 2 + (yy - cy) ** 2 <= r * r
    print(f"mühür: merkez ({cx:.0f}, {cy:.0f}), yarıçap {r:.0f}")

    kirmizi_renk = np.median(a[..., :3][(ton < 12) & (doy > 0.8) & (par < 0.62) & (alfa > 0.95) & ~disk], axis=0)
    mor_renk = np.percentile(a[..., :3][mor], 20, axis=0)
    isik = a[..., :3].astype(np.float32) @ np.array([0.299, 0.587, 0.114], np.float32)

    # mor mürekkep: mor tonda ve dolgudan belirgin koyu
    mor_mu = (ton > 215) & (ton < 310)
    w_mor = np.where(mor_mu, np.clip((200.0 - isik) / 95.0, 0.0, 1.0) * np.clip((doy - 0.10) / 0.25, 0.0, 1.0), 0.0)
    # altta kalan kırmızı (dolgunun altından pembe görünür): kırmızı tonda ve az da olsa doygun
    kirmizi_mi = (ton < 22) | (ton > 335)
    w_kirmizi = np.where(kirmizi_mi, np.clip((doy - 0.07) / 0.30, 0.0, 1.0), 0.0)
    w_mor = np.where(disk, w_mor, 0.0)
    w_kirmizi = np.where(disk, w_kirmizi, 0.0)
    w_kirmizi = np.array(Image.fromarray((w_kirmizi * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2))).astype(np.float32) / 255.0
    w_kirmizi = np.clip(w_kirmizi * 1.5, 0.0, 1.0)

    cikti = a.astype(np.float32).copy()
    # disk içinde: önce kırmızı katman, üstüne mor (üst üste gelen yerde mor baskın, kırmızıyla koyulaşır)
    alt_alfa = w_kirmizi
    ust_alfa = w_mor * 0.94
    renk = kirmizi_renk[None, None, :] * (1.0 - ust_alfa[..., None]) + (mor_renk * 0.82)[None, None, :] * ust_alfa[..., None]
    renk = np.where((alt_alfa > 0.05)[..., None], renk, mor_renk[None, None, :])
    toplam = ust_alfa + alt_alfa * (1.0 - ust_alfa)
    cikti[..., :3] = np.where(disk[..., None], renk, cikti[..., :3])
    cikti[..., 3] = np.where(disk, toplam * 255.0, cikti[..., 3])
    # simge için: mührün yalnız mor mürekkebi (altındaki kırmızı olmadan)
    katman = np.zeros(a.shape, np.float32)
    katman[..., :3] = (mor_renk * 0.82)[None, None, :]
    katman[..., 3] = ust_alfa * 255.0
    MUHUR["katman"] = np.clip(katman, 0, 255).astype(np.uint8)
    MUHUR["kutu"] = (int(cx - r), int(cy - r), int(cx + r) + 1, int(cy + r) + 1)
    return np.clip(cikti, 0, 255).astype(np.uint8)


def yildizi_kucult(a: np.ndarray, oran: float = 0.72) -> np.ndarray:
    """İki satırın arasındaki yıldızı merkezi çevresinde küçültür. Yıldız, görselin orta bölgesindeki
    kareye yakın, orta boy bağlı parçadır (harfler ve çizgiler ya çok büyük ya çok yassıdır)."""
    from scipy import ndimage
    h, w = a.shape[:2]
    bolge = (slice(int(h * 0.30), int(h * 0.55)), slice(int(w * 0.30), int(w * 0.60)))
    etiket, adet = ndimage.label(a[bolge][..., 3] > 128)
    aday = None
    for no, dilim in enumerate(ndimage.find_objects(etiket), start=1):
        boy, en = dilim[0].stop - dilim[0].start, dilim[1].stop - dilim[1].start
        # bölgenin kenarına değen parça bir harfin kesilmiş ucudur, yıldız olamaz
        kenarda = dilim[0].start == 0 or dilim[1].start == 0 or dilim[0].stop == etiket.shape[0] or dilim[1].stop == etiket.shape[1]
        if kenarda or not (90 <= en <= 260 and 90 <= boy <= 260 and 0.75 <= en / boy <= 1.35):
            continue
        doluluk = float((etiket[dilim] == no).mean())
        if not 0.28 <= doluluk <= 0.62:          # yıldız, kutusunun yarısından azını doldurur
            continue
        uzaklik = abs((dilim[1].start + dilim[1].stop) / 2.0 - etiket.shape[1] * 0.42)
        if aday is None or uzaklik < aday[0]:
            aday = (uzaklik, no, dilim)
    if aday is None:
        print("yıldız bulunamadı; olduğu gibi bırakıldı")
        return a
    _, no, dilim = aday
    y0, y1 = dilim[0].start + bolge[0].start, dilim[0].stop + bolge[0].start
    x0, x1 = dilim[1].start + bolge[1].start, dilim[1].stop + bolge[1].start
    print(f"yıldız: x {x0}..{x1}, y {y0}..{y1}")
    maske = etiket[dilim] == no
    parca = a[y0:y1, x0:x1].copy()
    parca[~maske] = 0
    kucuk = Image.fromarray(parca).resize((int((x1 - x0) * oran), int((y1 - y0) * oran)), Image.LANCZOS)
    cikti = a.copy()
    # yıldızı, yumuşak kenarının izi kalmasın diye birkaç piksel payla sil (çizgi uçları daha uzakta)
    pay = 8
    genis = np.zeros((y1 - y0 + 2 * pay, x1 - x0 + 2 * pay), bool)
    genis[pay:-pay, pay:-pay] = maske
    genis = ndimage.binary_dilation(genis, iterations=6)
    bolge_tam = cikti[y0 - pay:y1 + pay, x0 - pay:x1 + pay]
    bolge_tam[genis] = 0
    tuval = Image.fromarray(cikti)
    tuval.alpha_composite(kucuk, (x0 + ((x1 - x0) - kucuk.width) // 2, y0 + ((y1 - y0) - kucuk.height) // 2))
    return np.array(tuval)


def kirp(im: Image.Image, pay: int = 60) -> Image.Image:
    kutu = im.getchannel("A").point(lambda v: 255 if v > 12 else 0).getbbox()
    return im.crop((max(0, kutu[0] - pay), max(0, kutu[1] - pay), min(im.width, kutu[2] + pay), min(im.height, kutu[3] + pay)))


def kagit_dokusu(im: Image.Image, guc: float = 3.0) -> Image.Image:
    """Düz renkli kâğıda hafif bir pürüz verir (saydamlık korunur)."""
    e = np.array(im.convert("RGBA")).astype(np.float32)
    e[..., :3] = np.clip(e[..., :3] + np.random.default_rng(1984).normal(0, guc, (im.height, im.width, 1)), 0, 255)
    return Image.fromarray(e.astype(np.uint8), "RGBA")


def kagit_etiket(lg: Image.Image, egim: float) -> tuple:
    """Logoyu krem bir kâğıt etiketin üstüne koyar. (etiket, gölgesi) döner; ikisi aynı boydadır."""
    en = lg.width
    pay = int(en * 0.045)
    etiket = Image.new("RGBA", (lg.width + 2 * pay, lg.height + 2 * pay), (0, 0, 0, 0))
    ImageDraw.Draw(etiket).rounded_rectangle((0, 0, etiket.width - 1, etiket.height - 1), radius=max(3, pay // 3), fill=KAGIT + (255,))
    etiket = kagit_dokusu(etiket)
    etiket.alpha_composite(lg, (pay, pay))
    etiket = etiket.rotate(egim, resample=Image.BICUBIC, expand=True)
    gol = Image.new("RGBA", etiket.size, (0, 0, 0, 0))
    gol.putalpha(etiket.getchannel("A").point(lambda v: int(v * 0.55)))
    gol = gol.filter(ImageFilter.GaussianBlur(max(4, en // 70)))
    return etiket, gol


def acilis(logo: Image.Image, en: int = 640) -> Image.Image:
    """Açılış görseli: koyu zeminin ortasında duracak kâğıt etiket (saydam zemin, gölgesiyle)."""
    lg = logo.resize((en, int(en * logo.height / logo.width)), Image.LANCZOS)
    etiket, gol = kagit_etiket(lg, -1.6)
    pay = 28
    tuval = Image.new("RGBA", (etiket.width + 2 * pay, etiket.height + 2 * pay), (0, 0, 0, 0))
    tuval.alpha_composite(gol, (pay + 5, pay + 7))
    tuval.alpha_composite(etiket, (pay, pay))
    return tuval


def _harfler(logo: Image.Image) -> tuple:
    """Logodaki ilk satırın ilk harfini (N) ve ikinci satırın ilk harfini (M) keser."""
    from scipy import ndimage
    a = np.array(logo)
    ton, doy, _par = hsv(a[..., :3])
    kirmizi = ((ton < 22) | (ton > 335)) & (doy > 0.5) & (a[..., 3] > 128)
    etiketler, adet = ndimage.label(kirmizi)
    h, w = kirmizi.shape
    satir = {0: [], 1: []}
    for no, dilim in enumerate(ndimage.find_objects(etiketler), 1):
        y0, y1, x0, x1 = dilim[0].start, dilim[0].stop, dilim[1].start, dilim[1].stop
        if (x1 - x0) > w * 0.5 or (y1 - y0) < h * 0.15 or (y1 - y0) > h * 0.5:
            continue                                  # çerçeve, çizgi, yıldız, noktalar
        satir[0 if (y0 + y1) / 2 < h / 2 else 1].append((x0, no, dilim))
    cikti = []
    for i in (0, 1):
        _x, no, dilim = min(satir[i])
        parca = a[dilim].copy()
        parca[..., 3] = np.where(etiketler[dilim] == no, parca[..., 3], 0)
        cikti.append(Image.fromarray(parca, "RGBA"))
    return cikti[0], cikti[1]


def simge(logo: Image.Image, boyut: int = 1024) -> Image.Image:
    """Uygulama simgesi: krem kâğıt, kırmızı çift çerçeve, logonun harfleriyle "NM", köşede mor mühür."""
    n, m = _harfler(logo)
    kirmizi = tuple(int(v) for v in np.median(np.array(n)[np.array(n)[..., 3] > 250][:, :3], axis=0))
    b = boyut
    maske = Image.new("L", (b, b), 0)
    ImageDraw.Draw(maske).rounded_rectangle((0, 0, b - 1, b - 1), radius=int(b * 0.19), fill=255)
    tuval = kagit_dokusu(Image.new("RGBA", (b, b), KAGIT + (255,)), 2.5)
    cizim = ImageDraw.Draw(tuval)
    k1, k2 = int(b * 0.075), int(b * 0.118)
    cizim.rounded_rectangle((k1, k1, b - k1, b - k1), radius=int(b * 0.13), outline=kirmizi + (255,), width=int(b * 0.028))
    cizim.rounded_rectangle((k2, k2, b - k2, b - k2), radius=int(b * 0.095), outline=kirmizi + (255,), width=max(2, int(b * 0.008)))
    # harfler: aynı boya getirilir, yan yana, ortanın biraz üstünde
    boy = int(b * 0.33)
    n = n.resize((int(n.width * boy / n.height), boy), Image.LANCZOS)
    m = m.resize((int(m.width * boy / m.height), boy), Image.LANCZOS)
    ara = int(b * 0.035)
    toplam = n.width + ara + m.width
    x = (b - toplam) // 2
    y = int(b * 0.235)
    tuval.alpha_composite(n, (x, y))
    tuval.alpha_composite(m, (x + n.width + ara, y))
    # mühür: sağ alt köşede, çerçevenin üstüne basılmış
    x0, y0, x1, y1 = MUHUR["kutu"]
    muhur = Image.fromarray(MUHUR["katman"], "RGBA").crop((x0, y0, x1, y1))
    cap = int(b * 0.40)
    muhur = muhur.resize((cap, cap), Image.LANCZOS)
    tuval.alpha_composite(muhur, (int(b * 0.545), int(b * 0.545)))
    tuval.putalpha(maske)
    return tuval


def kapak(logo: Image.Image, boyut: tuple, logo_orani: float, yer: tuple) -> Image.Image:
    """Menü sahnesinin üstünde, krem bir kâğıt etiketin içinde logo. `yer`: etiketin ortası (0..1)."""
    arka = Image.open(KOK / "assets" / "img" / "menu_arkaplan.webp").convert("RGB")
    # sahneyi kapağın oranına kırp (bina ve kuyruk görünsün diye sağa yaslı)
    hedef = boyut[0] / boyut[1]
    if arka.width / arka.height > hedef:
        yeni_en = int(arka.height * hedef)
        x0 = int((arka.width - yeni_en) * 0.78)
        arka = arka.crop((x0, 0, x0 + yeni_en, arka.height))
    else:
        yeni_boy = int(arka.width / hedef)
        y0 = int((arka.height - yeni_boy) * 0.5)
        arka = arka.crop((0, y0, arka.width, y0 + yeni_boy))
    arka = arka.resize(boyut, Image.LANCZOS)
    # sol yanı hafifçe karart: logo öne çıksın
    golge = Image.new("L", boyut, 0)
    ImageDraw.Draw(golge).rectangle((0, 0, int(boyut[0] * 0.62), boyut[1]), fill=110)
    golge = golge.filter(ImageFilter.GaussianBlur(boyut[0] * 0.12))
    arka = Image.composite(Image.new("RGB", boyut, (24, 20, 26)), arka, golge)

    en = int(boyut[0] * logo_orani)
    lg = logo.resize((en, int(en * logo.height / logo.width)), Image.LANCZOS)
    etiket, gol = kagit_etiket(lg, -2.2)
    tuval = arka.convert("RGBA")
    x = int(boyut[0] * yer[0] - etiket.width / 2)
    y = int(boyut[1] * yer[1] - etiket.height / 2)
    tuval.alpha_composite(gol, (x + max(3, en // 110), y + max(4, en // 80)))
    tuval.alpha_composite(etiket, (x, y))
    return tuval.convert("RGB")


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    a = np.array(Image.open(HAM).convert("RGBA"))
    a = muhru_temizle(a)
    a = yildizi_kucult(a)
    logo = kirp(Image.fromarray(a, "RGBA"))
    print("logo:", logo.size)
    belgeler = KOK / "docs" / "img"
    logo.save(belgeler / "logo.png")
    kagit = Image.new("RGBA", logo.size, KAGIT + (255,))
    kagit.alpha_composite(logo)
    kagit.convert("RGB").save(belgeler / "logo_kagit.png")
    koyu = Image.new("RGBA", logo.size, (44, 52, 66, 255))
    koyu.alpha_composite(logo)
    koyu.convert("RGB").resize((logo.width // 2, logo.height // 2), Image.LANCZOS).save(HAM.parent / "logo_koyu_denetim.png")
    kapak(logo, (920, 430), 0.50, (0.30, 0.50)).save(belgeler / "kapak_920x430.jpg", quality=93)
    kapak(logo, (630, 500), 0.72, (0.50, 0.40)).save(belgeler / "kapak_630x500.jpg", quality=93)
    kapak(logo, (1280, 720), 0.46, (0.29, 0.44)).save(belgeler / "kapak_1280x720.jpg", quality=93)
    acilis(logo).save(KOK / "assets" / "img" / "acilis.png", optimize=True)
    buyuk = simge(logo)
    buyuk.resize((256, 256), Image.LANCZOS).save(KOK / "icon.png", optimize=True)
    buyuk.resize((256, 256), Image.LANCZOS).save(KOK / "icon.ico", sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    buyuk.save(HAM.parent / "simge_1024.png")


if __name__ == "__main__":
    main()
