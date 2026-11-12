"""Tek "ağzı açık" çeşitlemesi olan yüzler için "hafif açık" konuşma karesini üretir.

Eski havuzdaki yüzlerin iki ayrı çeşitlemesi vardır (hafif açık, açık). Son eklenen 25 yüzde yalnızca "açık"
çeşitleme boyandı; ara kare olarak onun yarı saydam hâli kullanılıyordu: kapalı dudaklarla açık ağız üst üste
biniyor, konuşurken "hayalet" bir çift dudak görünüyordu.

Bu betik ara kareyi açık kareden büker: ağız boşluğunu (dişler ve karanlık iç) sütun sütun bulur, boşluğu
dikeyde daraltır ve alt dudakla çeneyi o kadar yukarı çeker. Sonuç gerçek bir yarı açık ağızdır. Ayrıca iki
karenin de maskesini ağız çevresine daraltır: çene kenarındaki dikiş izleri ana portrede kalır.

Kullanım: python tools/sanat/agiz_ara_kare.py            (v65..v89)
          python tools/sanat/agiz_ara_kare.py v70 v71    (yalnız adı verilenler)
Denetim sayfası: tools/sanat/ham/agiz_ara_denetim.jpg  (kapalı | hafif açık | açık)
Kaynak olarak ham açık kareler tools/sanat/ham/agiz_acik/ altında saklanır (betik yeniden çalıştırılabilsin).
"""
import json
import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

KOK = Path(__file__).resolve().parents[2]
PORTRE = KOK / "assets" / "img" / "portre"
AGIZ = PORTRE / "agiz"
KUNYE = KOK / "data" / "portreler.json"
HAM = Path(__file__).resolve().parent / "ham"
YEDEK = HAM / "agiz_acik"
DOLGU = 3            # agiz_kareleri.py ile aynı: atlasta kareler arası saydam pay
ARALIK = 0.40          # ara karede ağız boşluğu, açık karedekinin bu kadarı


def yumusat(dizi: np.ndarray, sigma: float) -> np.ndarray:
    return cv2.GaussianBlur(dizi.astype(np.float32).reshape(1, -1), (0, 0), sigma).reshape(-1)


def bosluk_bul(acik: np.ndarray, kapali: np.ndarray, mx: float, my: float, gen: float):
    """Açık ağzın boşluğunu sütun sütun bulur: (üst sınır, yükseklik) dizileri (piksel)."""
    ph, pw = acik.shape[:2]
    lab_a = cv2.cvtColor(acik.astype(np.uint8), cv2.COLOR_RGB2LAB).astype(np.float32)
    hsv = cv2.cvtColor(acik.astype(np.uint8), cv2.COLOR_RGB2HSV).astype(np.float32)
    isik = lab_a[..., 0]
    isik_k = cv2.cvtColor(kapali.astype(np.uint8), cv2.COLOR_RGB2LAB).astype(np.float32)[..., 0]
    ten = float(np.median(isik_k))
    # ağzın içi, kapalı hâle göre YENİ kararan yerdir (bıyık ve sakal iki karede de koyudur, sayılmaz)
    koyu = (isik < ten * 0.64) & (isik < isik_k - 22.0)
    dis = (isik > isik_k + 10.0) & (hsv[..., 1] < 85)          # dişler: kapalı dudaktan açık ve soluk
    yy, xx = np.mgrid[0:ph, 0:pw]
    bolge = (np.abs(xx - mx) < gen * 0.62) & (yy > my - gen * 0.30) & (yy < my + gen * 0.95)
    koyu &= bolge
    koyu = cv2.morphologyEx(koyu.astype(np.uint8), cv2.MORPH_OPEN, np.ones((2, 2), np.uint8)).astype(bool)
    # dişler yalnız karanlık bölgeye komşuysa ağzın içidir (yanaktaki parlamalar sayılmaz)
    yakin = cv2.dilate(koyu.astype(np.uint8), np.ones((9, 5), np.uint8)).astype(bool)
    ic = koyu | (dis & yakin & bolge)
    ic = cv2.morphologyEx(ic.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((5, 3), np.uint8))
    # en büyük parça
    adet, etiket, istat, _ = cv2.connectedComponentsWithStats(ic, connectivity=8)
    if adet <= 1:
        return None
    en_buyuk = 1 + int(np.argmax(istat[1:, cv2.CC_STAT_AREA]))
    ic = etiket == en_buyuk
    ust = np.full(pw, my, np.float32)
    alt = np.full(pw, my, np.float32)
    dolu = np.zeros(pw, bool)
    for x in range(pw):
        satirlar = np.flatnonzero(ic[:, x])
        if satirlar.size >= 2:
            ust[x] = satirlar[0]
            alt[x] = satirlar[-1] + 1
            dolu[x] = True
    if dolu.sum() < 6 or (alt - ust).max() < 3:
        return None
    # boşluğun olmadığı sütunlarda sınırlar komşulardan sürer; sütundan sütuna zıplama süzülür
    xs = np.arange(pw)
    ust = np.interp(xs, xs[dolu], ust[dolu]).astype(np.float32)
    alt = np.interp(xs, xs[dolu], alt[dolu]).astype(np.float32)
    ust = yumusat(cv2.medianBlur(ust.reshape(1, -1), 5).reshape(-1), 3.0)
    alt = yumusat(cv2.medianBlur(alt.reshape(1, -1), 5).reshape(-1), 3.0)
    boy = np.maximum(alt - ust, 0.0) * yumusat(dolu.astype(np.float32), 2.5)
    return ust, boy


def ara_kare(acik: np.ndarray, ust: np.ndarray, boy: np.ndarray) -> np.ndarray:
    """Açık görüntüyü büker: boşluk `ARALIK` oranına iner, altı o kadar yukarı çekilir (aşağıya doğru söner)."""
    ph, pw = acik.shape[:2]
    yy, xx = np.mgrid[0:ph, 0:pw].astype(np.float32)
    t = ust[None, :]
    h = boy[None, :]
    h2 = h * ARALIK
    kayma = h - h2
    alt = t + h2                                              # ara karede alt dudağın başladığı satır
    # boşluğun içi: kaynak satır daha hızlı ilerler
    ic = t + (yy - t) / ARALIK
    # boşluğun altı: yukarı çekilir; karenin altına doğru çekme sıfıra iner
    oran = np.clip((yy - alt) / np.maximum(ph - 1 - alt, 1.0), 0.0, 1.0)
    sonme = 1.0 - oran * oran * (3.0 - 2.0 * oran)
    asagi = yy + kayma * sonme
    kaynak_y = np.where(yy <= t, yy, np.where(yy <= alt, ic, asagi)).astype(np.float32)
    return cv2.remap(acik.astype(np.float32), xx, kaynak_y, cv2.INTER_CUBIC, borderMode=cv2.BORDER_REPLICATE)


def dar_maske(pw: int, ph: int, mx: float, my: float) -> np.ndarray:
    """Ağız çevresine oturan yumuşak elips: çene kenarları ana portreden gelir."""
    yy, xx = np.mgrid[0:ph, 0:pw].astype(np.float32)
    r = np.sqrt(((xx - mx) / (pw * 0.40)) ** 2 + ((yy - (my + ph * 0.10)) / (ph * 0.50)) ** 2)
    m = np.clip((1.0 - r) / 0.38, 0.0, 1.0)
    return m * m * (3 - 2 * m)


def isle(kimlik: str, bilgi: dict, denetim: list) -> bool:
    ana = np.array(Image.open(PORTRE / f"{kimlik}.webp").convert("RGBA"))
    H, W = ana.shape[:2]
    YEDEK.mkdir(parents=True, exist_ok=True)
    yedek = YEDEK / f"{kimlik}.png"
    if not yedek.exists():
        # ilk çalıştırma: atlasın ikinci (açık) karesi kaynak olarak saklanır
        atlas0 = np.array(Image.open(AGIZ / f"{kimlik}.webp").convert("RGBA"))
        gen0 = atlas0.shape[1] // 2
        Image.fromarray(atlas0[:, gen0:], "RGBA").save(yedek)
    kare = np.array(Image.open(yedek).convert("RGBA"))
    ph, pw = kare.shape[0] - 2 * DOLGU, kare.shape[1] - 2 * DOLGU
    kare = kare[DOLGU:DOLGU + ph, DOLGU:DOLGU + pw]
    x0 = int(round(bilgi["agiz_kare"][0] * W))
    y0 = int(round(bilgi["agiz_kare"][1] * H))
    kapali = ana[y0:y0 + ph, x0:x0 + pw, :3].astype(np.float32)
    if kapali.shape[:2] != (ph, pw):
        print(f"  {kimlik}: kare portreye oturmuyor, atlandı")
        return False
    alfa = kare[..., 3:4].astype(np.float32) / 255.0
    acik = kapali * (1 - alfa) + kare[..., :3].astype(np.float32) * alfa
    mx = bilgi["agiz"][0] * W - x0
    my = bilgi["agiz"][1] * H - y0
    gen = bilgi["agiz_gen"] * W
    bulunan = bosluk_bul(acik, kapali, mx, my, gen)
    if bulunan is None:
        print(f"  {kimlik}: ağız boşluğu bulunamadı, atlandı")
        return False
    ust, boy = bulunan
    ara = ara_kare(acik, ust, boy)
    maske = np.minimum(alfa[..., 0], dar_maske(pw, ph, mx, my))
    atlas = np.zeros((ph + 2 * DOLGU, 2 * (pw + 2 * DOLGU), 4), np.uint8)
    for i, goruntu in enumerate((ara, acik)):
        ox = i * (pw + 2 * DOLGU) + DOLGU
        atlas[DOLGU:DOLGU + ph, ox:ox + pw] = np.dstack([np.clip(goruntu, 0, 255), maske * 255.0]).astype(np.uint8)
    Image.fromarray(atlas, "RGBA").save(AGIZ / f"{kimlik}.webp", quality=92, method=4, alpha_quality=100)

    # denetim: alt yüz — kapalı | hafif açık | açık (oyundaki gibi maskeyle bindirilmiş)
    cene = int(bilgi["cene"] * H)
    kx0, kx1 = max(0, x0 - 24), min(W, x0 + pw + 24)
    ky0, ky1 = max(0, y0 - 40), min(H, cene + 30)
    kareler = []
    for goruntu in (None, ara, acik):
        tam = ana[..., :3].astype(np.float32).copy()
        if goruntu is not None:
            tam[y0:y0 + ph, x0:x0 + pw] = tam[y0:y0 + ph, x0:x0 + pw] * (1 - maske[..., None]) + goruntu * maske[..., None]
        kareler.append(cv2.resize(np.clip(tam[ky0:ky1, kx0:kx1], 0, 255).astype(np.uint8), (190, 170), interpolation=cv2.INTER_AREA))
    serit = np.hstack(kareler)
    cv2.putText(serit, f"{kimlik} {boy.max():.0f}px", (4, 14), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (255, 255, 0), 1)
    denetim.append(serit)
    return True


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    kunye = json.loads(KUNYE.read_text(encoding="utf-8"))
    kimlikler = sys.argv[1:] or [f"v{n}" for n in range(65, 90)]
    denetim, tamam = [], 0
    for kimlik in kimlikler:
        if kimlik in kunye and "agiz_kare" in kunye[kimlik] and (AGIZ / f"{kimlik}.webp").exists():
            tamam += isle(kimlik, kunye[kimlik], denetim)
    print(f"ara kare üretildi: {tamam}/{len(kimlikler)}")
    for i in range(0, len(denetim), 12):
        parca = denetim[i:i + 12]
        satirlar = [np.hstack(parca[j:j + 2] + [np.zeros_like(parca[0])] * (2 - len(parca[j:j + 2]))) for j in range(0, len(parca), 2)]
        ad = "agiz_ara_denetim.jpg" if i == 0 else f"agiz_ara_denetim_{i // 12 + 1}.jpg"
        cv2.imwrite(str(HAM / ad), cv2.cvtColor(np.vstack(satirlar), cv2.COLOR_RGB2BGR), [cv2.IMWRITE_JPEG_QUALITY, 92])


if __name__ == "__main__":
    main()
