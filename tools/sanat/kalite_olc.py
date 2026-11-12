"""Görsellerin kayıplı yeniden kodlanmasının kaliteye etkisini ölçer (PSNR) ve boyut kazancını verir.

Görseller kayıplı WebP olarak saklanır; Godot onları kayıpsız içe aktarırsa paket iki üç kat büyür.
Bu betik, içe aktarmanın "kayıplı" kipe alınması hâlinde neyin kaybedileceğini sayıyla gösterir.

Kullanım: python tools/sanat/kalite_olc.py [kalite] [her_kacinci]      (varsayılan 92, her 3 dosyadan biri)
"""
import io
import sys
from pathlib import Path

import numpy as np
from PIL import Image

KOK = Path(__file__).resolve().parents[2]
KLASORLER = ["assets/img/portre", "assets/img/portre/vesika", "assets/img/portre/agiz", "assets/img",
             "assets/img/nesne", "assets/img/kagit"]


def psnr(a: np.ndarray, b: np.ndarray) -> float:
    m = ((a.astype(float) - b.astype(float)) ** 2).mean()
    return 99.0 if m == 0 else float(10 * np.log10(255 ** 2 / m))


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    kalite = int(sys.argv[1]) if len(sys.argv) > 1 else 92
    adim = int(sys.argv[2]) if len(sys.argv) > 2 else 3
    print(f"kalite {kalite}, her {adim} dosyadan biri")
    for klasor in KLASORLER:
        dosyalar = sorted((KOK / klasor).glob("*.webp"))[::adim]
        degerler, boyut, kaynak, alfa_farki = [], 0, 0, 0
        for f in dosyalar:
            im = Image.open(f).convert("RGBA")
            buf = io.BytesIO()
            im.save(buf, "WEBP", quality=kalite, method=3)
            boyut += buf.tell()
            kaynak += f.stat().st_size
            yeni = np.array(Image.open(io.BytesIO(buf.getvalue())).convert("RGBA"))
            eski = np.array(im)
            gorunen = eski[..., 3] > 8
            degerler.append(psnr(eski[..., :3][gorunen], yeni[..., :3][gorunen]))
            alfa_farki = max(alfa_farki, int(np.abs(eski[..., 3].astype(int) - yeni[..., 3].astype(int)).max()))
        if degerler:
            print(f"  {klasor:28} {len(degerler):4d} dosya  PSNR en düşük {min(degerler):5.1f}  ortalama {sum(degerler) / len(degerler):5.1f} dB"
                  f"  boyut {boyut / 1e6:5.2f} MB (kaynak {kaynak / 1e6:5.2f})  alfa farkı {alfa_farki}", flush=True)


if __name__ == "__main__":
    main()
