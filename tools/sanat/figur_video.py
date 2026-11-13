"""Yeşil zeminde üretilmiş bir figür klibini oyunda saydam oynatılacak videoya çevirir.

Klip (tools/sanat/ham/video/<ad>.mp4), figürün boyalı resminden başlayıp aynı resimde biten kısa bir
canlandırmadır (döngüye girer). Bu betik:
  1. kareleri çıkarır (saniyede 15 kare) ve klibi döngüye sokar: son bölümde ilk kareye en çok benzeyen
     karede keser, son beş kareyi ilk kareye eritir,
  2. yeşil zemini ayıklar (saydamlık haritası), kenarlardaki yeşil yansımayı giderir,
  3. bütün karelerdeki figürün ortak kutusuna kırpar,
  4. her kareyi "renk | saydamlık" biçiminde yan yana koyup Theora videosu olarak yazar
     (assets/video/<ad>.ogv); Godot'ta VideoFigur bu ikisini birleştirir; rengin figür dışında kalan
     yeri en yakın figür rengiyle doldurulur (kenarda saçak olmasın),
  5. videonun figür resmine göre yerini data/figur_videolari.json dosyasına yazar.

Kullanım: python tools/sanat/figur_video.py <ad> <figür_x> <figür_y> <ölçek> [tuval_eni] [gidiş_dönüş_başı] [hız_çarpanı]
  figür_x, figür_y, ölçek: figür resminin klibin ilk karesindeki yeri ve büyütme oranı
  (başlangıç karesi hazırlanırken kullanılan değerler; kare klipte küçüldüyse betik oranlar).
  gidiş_dönüş_başı verilirse klip o kareden başlar, ileri oynayıp geri sarar (poz başa dönmüyorsa).
  hız_çarpanı (örn. 0.5) hareketi yavaşlatır: klibin 24 karesi de alınır, saniyede 24×çarpan kare oynatılır.
"""
import json
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

KOK = Path(__file__).resolve().parents[2]
HAM = Path(__file__).resolve().parent / "ham" / "video"
HEDEF = KOK / "assets" / "video"
BILGI = KOK / "data" / "figur_videolari.json"
KARE_HIZI = 15
EN_BUYUK_BOY = 620          # videodaki figürün en büyük yüksekliği (piksel)


def ayikla(kare: Image.Image) -> tuple:
    """(renk RGB float 0..1, saydamlık 0..1): yeşil zemin saydam, figür mat."""
    a = np.array(kare.convert("RGB")).astype(np.float32) / 255.0
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    fark = g - np.maximum(r, b)
    alfa = 1.0 - np.clip((fark - 0.10) / 0.26, 0.0, 1.0)
    # yeşil yansıma: yeşil, kırmızı ile mavinin büyüğünü geçmesin
    a[..., 1] = np.minimum(g, np.maximum(r, b))
    return a, alfa


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    ad = sys.argv[1]
    fx, fy, olcek = float(sys.argv[2]), float(sys.argv[3]), float(sys.argv[4])
    tuval_eni = float(sys.argv[5]) if len(sys.argv) > 5 else 0.0
    klip = HAM / f"{ad}.mp4"
    gecici = HAM / f"{ad}_kareler"
    shutil.rmtree(gecici, ignore_errors=True)
    gecici.mkdir(parents=True)
    # hız çarpanı verilirse klibin bütün kareleri (saniyede 24) alınır ve daha yavaş oynatılır:
    # hareket yavaşlar ama kare atlamadığı için akıcı kalır
    carpan = float(sys.argv[7]) if len(sys.argv) > 7 else 1.0
    cekim_hizi = KARE_HIZI if carpan == 1.0 else 24
    oynatma_hizi = KARE_HIZI if carpan == 1.0 else max(6, round(24 * carpan))
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(klip), "-vf", f"fps={cekim_hizi}", str(gecici / "k_%03d.png")], check=True)
    yollar = sorted(gecici.glob("k_*.png"))
    kareler = [ayikla(Image.open(y)) for y in yollar]
    h, w = kareler[0][1].shape
    if len(sys.argv) > 6:
        # gidiş-dönüş döngüsü: poz ilk kareye dönmeyen klipler için. Baştaki kareler (poz otururken) atılır,
        # klip ileri oynar, sonra geri sarar.
        kareler = kareler[int(sys.argv[6]):]
        kareler = kareler + kareler[-2:0:-1]
        print(f"döngü: gidiş-dönüş, {len(kareler)} kare")
    else:
        # klibin son bölümünde ilk kareye en çok benzeyen karede kesilir, son kareler ilk kareye eritilir
        gri = [k[0].mean(axis=2) * k[1] for k in kareler]
        aday = range(int(len(kareler) * 0.6), len(kareler))
        son = min(aday, key=lambda i: float(np.abs(gri[i] - gri[0]).mean()))
        print(f"döngü: {len(kareler)} kareden {son}. karede kesildi (ilk kareye fark {np.abs(gri[son] - gri[0]).mean() * 255:.2f})")
        kareler = kareler[:son]
        ERITME = 5
        for j in range(ERITME):
            t = (j + 1) / (ERITME + 1.0)
            i = len(kareler) - ERITME + j
            kareler[i] = (kareler[i][0] * (1 - t) + kareler[0][0] * t, kareler[i][1] * (1 - t) + kareler[0][1] * t)
    # klip, başlangıç karesinden küçük üretilmiş olabilir
    oran = w / tuval_eni if tuval_eni > 0 else 1.0
    fx, fy, olcek = fx * oran, fy * oran, olcek * oran
    birlesik = np.max(np.stack([k[1] for k in kareler]), axis=0) > 0.5
    ys, xs = np.nonzero(birlesik)
    pay = 6
    x0, x1 = max(0, xs.min() - pay), min(w, xs.max() + 1 + pay)
    y0, y1 = max(0, ys.min() - pay), min(h, ys.max() + 1 + pay)
    kucultme = min(1.0, EN_BUYUK_BOY / (y1 - y0))
    en = int(round((x1 - x0) * kucultme / 2.0)) * 2
    boy = int(round((y1 - y0) * kucultme / 2.0)) * 2
    cikti = HAM / f"{ad}_cift"
    shutil.rmtree(cikti, ignore_errors=True)
    cikti.mkdir(parents=True)
    for i, (renk, alfa) in enumerate(kareler):
        renk = renk[y0:y1, x0:x1]
        alfa = alfa[y0:y1, x0:x1]
        # kenarı yarım piksel içeri çek: yeşil saçak kalmasın
        alfa_g = Image.fromarray((alfa * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(5)).filter(ImageFilter.GaussianBlur(0.8))
        alfa = np.array(alfa_g).astype(np.float32) / 255.0
        # figürün dışı, en yakın figür pikselinin rengiyle doldurulur: video sıkıştırması ve yumuşatma
        # kenarda zemin rengini (koyu ya da yeşil saçak) içeri taşımasın
        _uzaklik, (iy, ix) = ndimage.distance_transform_edt(alfa < 0.9, return_indices=True)
        dolgulu = renk[iy, ix]
        on_carpilmis = Image.fromarray((np.clip(dolgulu, 0, 1) * 255).astype(np.uint8)).resize((en, boy), Image.LANCZOS)
        mat = Image.fromarray((alfa * 255).astype(np.uint8)).resize((en, boy), Image.LANCZOS).convert("RGB")
        cift = Image.new("RGB", (en * 2, boy))
        cift.paste(on_carpilmis, (0, 0))
        cift.paste(mat, (en, 0))
        cift.save(cikti / f"c_{i:03d}.png")
    HEDEF.mkdir(parents=True, exist_ok=True)
    hedef = HEDEF / f"{ad}.ogv"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(oynatma_hizi), "-i", str(cikti / "c_%03d.png"),
                    "-c:v", "libtheora", "-q:v", "8", "-pix_fmt", "yuv444p", str(hedef)], check=True)
    bilgi = json.loads(BILGI.read_text(encoding="utf-8")) if BILGI.exists() else {}
    bilgi["aciklama"] = "tools/sanat/figur_video.py üretir. 'kutu': videonun, figürün boyalı resmine göre yeri [x, y, en, boy] (resmin piksel biriminde)."
    bilgi[ad] = {"kutu": [round(float(v), 2) for v in ((x0 - fx) / olcek, (y0 - fy) / olcek, (x1 - x0) / olcek, (y1 - y0) / olcek)],
                 "kare": len(kareler), "hiz": oynatma_hizi}
    BILGI.write_text(json.dumps(bilgi, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8", newline="\n")
    print(f"{ad}: klip {w}x{h}, {len(kareler)} kare, video {en * 2}x{boy}, {hedef.stat().st_size // 1024} KB, kutu {bilgi[ad]['kutu']}")
    shutil.rmtree(gecici, ignore_errors=True)


if __name__ == "__main__":
    main()
