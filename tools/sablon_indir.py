"""Godot 4.3 dışa aktarma şablonlarından yalnızca gerekenleri indirir (Windows ve Web, sürüm yapıları).

Resmî şablon paketi (.tpz) yaklaşık 1 GB'lık bir zip dosyasıdır. Bu betik paketin tamamını indirmez:
zip dizinini okuyup yalnızca gereken dosyaları HTTP aralık istekleriyle çeker (~100 MB) ve Godot'un
şablon klasörüne yerleştirir.

Kullanım: python tools/sablon_indir.py
"""
import os
import sys
import urllib.request
import zipfile
from pathlib import Path

SURUM = "4.3.stable"
ADRES = "https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_export_templates.tpz"
GEREKEN = ["version.txt", "windows_release_x86_64.exe", "windows_release_x86_64_console.exe",
           "web_nothreads_release.zip", "web_release.zip"]
PARCA = 8 * 1024 * 1024


class UzakDosya:
    """Uzak bir dosyayı, aralık istekleriyle okunan dosya benzeri bir nesne olarak sunar."""

    def __init__(self, adres: str) -> None:
        istek = urllib.request.Request(adres, method="HEAD", headers={"User-Agent": "godot-sablon-indirici"})
        with urllib.request.urlopen(istek) as yanit:
            self.adres = yanit.geturl()            # yönlendirmeden sonraki asıl adres
            self.boyut = int(yanit.headers["Content-Length"])
        self.konum = 0
        self._on_bas = -1
        self._on = b""
        self.inen = 0

    def seekable(self) -> bool:
        return True

    def readable(self) -> bool:
        return True

    def tell(self) -> int:
        return self.konum

    def seek(self, uzaklik: int, nereden: int = 0) -> int:
        if nereden == 0:
            self.konum = uzaklik
        elif nereden == 1:
            self.konum += uzaklik
        else:
            self.konum = self.boyut + uzaklik
        return self.konum

    def _getir(self, bas: int, son: int) -> bytes:
        istek = urllib.request.Request(self.adres, headers={"Range": f"bytes={bas}-{son}", "User-Agent": "godot-sablon-indirici"})
        for deneme in range(4):
            try:
                with urllib.request.urlopen(istek, timeout=120) as yanit:
                    veri = yanit.read()
                self.inen += len(veri)
                return veri
            except Exception as hata:  # ağ kesintisi: birkaç kez yeniden dene
                if deneme == 3:
                    raise
                print(f"  yeniden deneniyor ({hata})", flush=True)
        return b""

    def read(self, adet: int = -1) -> bytes:
        if adet < 0:
            adet = self.boyut - self.konum
        adet = min(adet, self.boyut - self.konum)
        if adet <= 0:
            return b""
        cikti = bytearray()
        while adet > 0:
            if not (self._on_bas <= self.konum < self._on_bas + len(self._on)):
                # zip dizini dosyanın sonundadır: sona yakın okumalarda geriye doğru tamponla
                bas = max(0, self.konum - 65536) if self.konum > self.boyut - 2 * PARCA else self.konum
                self._on = self._getir(bas, min(self.boyut - 1, bas + PARCA - 1))
                self._on_bas = bas
            i = self.konum - self._on_bas
            parca = self._on[i:i + adet]
            cikti += parca
            self.konum += len(parca)
            adet -= len(parca)
        return bytes(cikti)


def main() -> None:
    kok = Path(os.environ.get("APPDATA", Path.home() / ".local/share")) / "Godot" / "export_templates" / SURUM
    if sys.platform != "win32":
        kok = Path.home() / ".local/share/godot/export_templates" / SURUM
    kok.mkdir(parents=True, exist_ok=True)
    eksik = [ad for ad in GEREKEN if not (kok / ad).exists()]
    if not eksik:
        print("Şablonlar zaten kurulu:", kok)
        return
    uzak = UzakDosya(ADRES)
    print(f"paket: {uzak.boyut / 1e6:.0f} MB; yalnızca gerekenler indirilecek", flush=True)
    with zipfile.ZipFile(uzak) as paket:
        for ad in eksik:
            bilgi = paket.getinfo("templates/" + ad)
            print(f"  {ad}: {bilgi.file_size / 1e6:.1f} MB", flush=True)
            with paket.open(bilgi) as kaynak, open(kok / (ad + ".kismi"), "wb") as hedef:
                while True:
                    parca = kaynak.read(1024 * 1024)
                    if not parca:
                        break
                    hedef.write(parca)
            (kok / (ad + ".kismi")).replace(kok / ad)
    print(f"bitti: {uzak.inen / 1e6:.0f} MB indirildi → {kok}")


if __name__ == "__main__":
    main()
