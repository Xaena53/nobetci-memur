"""Kamerası yakınlaşmış bir figür klibini özgün çerçevesine geri oturtur.

Üretilen klipte kamera bazen ilk saniyede figüre yaklaşır ve orada kalır: figürün alt bölümü kadrajdan
çıkar, ölçeği değişir. Bu betik yakın çekimin ölçeğini ve yerini bulur (ilk karedeki durağan bir bölgeyi,
örneğin tabureyi, yakın karelerde çok ölçekli eşlemeyle arar), her yakın kareyi küçültüp ilk karenin
üstüne yerine koyar; kadrajın dışında kalan bölüm ilk kareden gelir. Çıktı yalnızca yakınlaşma
tamamlandıktan sonraki kareleri içerir.

Kullanım: python tools/sanat/klip_duzelt.py <ad> <şablon x0 y0 x1 y1> [ilk_yakın_kare]
  şablon: ilk karede, klip boyunca kıpırdamayan bir bölge (piksel)
Çıktı: tools/sanat/ham/video/<ad>.mp4 (özgünü <ad>_ham.mp4 olarak saklanır)
"""
import shutil
import subprocess
import sys
from pathlib import Path

import cv2
import numpy as np

HAM = Path(__file__).resolve().parent / "ham" / "video"


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    ad = sys.argv[1]
    x0, y0, x1, y1 = (int(v) for v in sys.argv[2:6])
    asil = HAM / f"{ad}_ham.mp4"
    if not asil.exists():
        shutil.copy2(HAM / f"{ad}.mp4", asil)
    oku = cv2.VideoCapture(str(asil))
    kareler = []
    while True:
        tamam, kare = oku.read()
        if not tamam:
            break
        kareler.append(kare)
    hiz = oku.get(cv2.CAP_PROP_FPS)
    ilk = kareler[0]
    h, w = ilk.shape[:2]
    sablon = cv2.cvtColor(ilk[y0:y1, x0:x1], cv2.COLOR_BGR2GRAY)

    def esle(kare: np.ndarray) -> tuple:
        """(benzerlik, ölçek, yakın karede şablonun yeri)"""
        gri = cv2.cvtColor(kare, cv2.COLOR_BGR2GRAY)
        en_iyi = (-1.0, 1.0, (0, 0))
        for s in np.arange(1.0, 2.81, 0.02):
            buyuk = cv2.resize(sablon, None, fx=s, fy=s, interpolation=cv2.INTER_LINEAR)
            if buyuk.shape[0] >= gri.shape[0] or buyuk.shape[1] >= gri.shape[1]:
                break
            sonuc = cv2.matchTemplate(gri, buyuk, cv2.TM_CCOEFF_NORMED)
            _a, deger, _b, yer = cv2.minMaxLoc(sonuc)
            if deger > en_iyi[0]:
                en_iyi = (deger, float(s), yer)
        return en_iyi

    # yakınlaşmanın bittiği kare: ölçek artık değişmiyor
    olcumler = [esle(kareler[i]) for i in range(0, len(kareler), 6)]
    for i, (deger, s, yer) in zip(range(0, len(kareler), 6), olcumler):
        print(f"  kare {i:3d}: benzerlik {deger:.2f}, ölçek {s:.2f}, yer {yer}")
    son_olcek = float(np.median([o[1] for o in olcumler[len(olcumler) // 2:]]))
    baslangic = int(sys.argv[6]) if len(sys.argv) > 6 else next(i for i, o in zip(range(0, len(kareler), 6), olcumler) if abs(o[1] - son_olcek) < 0.03)
    print(f"yakın çekim ölçeği {son_olcek:.2f}; {baslangic}. kareden itibaren kullanılacak")

    gecici = HAM / f"{ad}_duz"
    shutil.rmtree(gecici, ignore_errors=True)
    gecici.mkdir()
    yazilan = 0
    for i in range(baslangic, len(kareler)):
        deger, s, yer = esle(kareler[i]) if (i - baslangic) % 12 == 0 else (deger, s, yer)
        s = son_olcek
        # yakın karedeki (yer) noktası, ilk karedeki (x0, y0) noktasıdır
        kucuk = cv2.resize(kareler[i], (round(w / s), round(h / s)), interpolation=cv2.INTER_AREA)
        ox, oy = round(x0 - yer[0] / s), round(y0 - yer[1] / s)
        tuval = ilk.copy()
        kh, kw = kucuk.shape[:2]
        # kenarlarda yumuşak geçiş (özellikle alt kenar: figürün gövdesinden geçer)
        maske = np.ones((kh, kw), np.float32)
        pay = 14
        rampa = np.linspace(0.0, 1.0, pay, dtype=np.float32)
        maske[-pay:, :] *= rampa[::-1][:, None]
        maske[:pay, :] *= rampa[:, None]
        maske[:, :pay] *= rampa[None, :]
        maske[:, -pay:] *= rampa[::-1][None, :]
        # tuvalin dışına taşan bölüm kırpılır
        ax, ay = max(0, -ox), max(0, -oy)
        bx, by = min(kw, w - ox), min(kh, h - oy)
        bolge = tuval[oy + ay:oy + by, ox + ax:ox + bx].astype(np.float32)
        m = maske[ay:by, ax:bx, None]
        tuval[oy + ay:oy + by, ox + ax:ox + bx] = (bolge * (1 - m) + kucuk[ay:by, ax:bx].astype(np.float32) * m).astype(np.uint8)
        cv2.imwrite(str(gecici / f"d_{yazilan:03d}.png"), tuval)
        yazilan += 1
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(hiz), "-i", str(gecici / "d_%03d.png"),
                    "-c:v", "libx264", "-crf", "10", "-pix_fmt", "yuv444p", str(HAM / f"{ad}.mp4")], check=True)
    shutil.rmtree(gecici, ignore_errors=True)
    print(f"{yazilan} kare yazıldı → {ad}.mp4 (yer {ox},{oy}, küçültülmüş kare {kw}x{kh})")


if __name__ == "__main__":
    main()
