"""Oyunun seslerini gerçek kayıtlardan derler.

Kaynaklar tools/ses/kaynaklar.json içinde sayılıdır: Freesound'daki CC0 (kamu malı) efekt kayıtları ile
Wikimedia Commons'taki kamu malı ve CC BY 4.0 lisanslı Türk çalgı müziği. Betik her kaydı indirir
(tools/ses/ham/ altında saklar), tarifine göre keser, temizler, düzeyini ayarlar ve assets/ses/ altına yazar;
kullanılan her kaydın künyesini assets/ses/KAYNAKLAR.md dosyasına döker.

Tarifler ("islem"):
  tek      en güçlü tek olay (vuruş, çıt): öncesinden biraz pay bırakıp `sure` kadar alınır
  olaylar  art arda `adet` ayrı olay: ad.wav, ad_2.wav, ad_3.wav ... (oyun rastgele birini çalar)
  kesit    `bas`..`bas+sure` arası
  taneler  konuşma heceleri: mırıltı kaydındaki en dolgun `adet` yerden kısa taneler (Papers Please tarzı)
  dongu    kesintisiz dönen ortam sesi (.ogg)
  muzik    parça: sessizlik kırpılır, düzey eşitlenir, sonu söndürülür (.ogg, assets/ses/muzik/)
  karisim  birden çok kesitin üst üste bindirilmesi ("parcalar")

Kullanım: python tools/ses/topla.py [ad ...]      (ad verilmezse hepsi)
Gerekenler: ffmpeg, numpy, scipy.
"""
import html
import json
import re
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np
from scipy import signal

SR = 44100
KOK = Path(__file__).resolve().parents[2]
HAM = Path(__file__).resolve().parent / "ham"
CIKTI = KOK / "assets" / "ses"
MUZIK = CIKTI / "muzik"
TARIF = Path(__file__).resolve().parent / "kaynaklar.json"
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36"


# ---------- indirme ----------

def indir(adres: str, hedef: Path) -> None:
    if hedef.exists() and hedef.stat().st_size > 2000:
        return
    # Wikimedia, tarayıcı gibi görünen betikleri geri çevirir: oraya kendini betik olarak tanıtan bir kimlikle gidilir
    kimlik = "asset-fetch/1.0 (generic client)" if "wikimedia.org" in adres else UA
    subprocess.run(["curl", "-sL", "-A", kimlik, "-o", str(hedef), adres], check=True)


def freesound(kimlik: int) -> dict:
    """Kaydın sayfasından künyesini ve dinleme dosyasının adresini okur; CC0 olduğunu doğrular."""
    kunye_yolu = HAM / f"fs_{kimlik}.json"
    if kunye_yolu.exists():
        return json.loads(kunye_yolu.read_text(encoding="utf-8"))
    r = subprocess.run(["curl", "-sL", "-A", UA, f"https://freesound.org/s/{kimlik}/"], capture_output=True)
    s = r.stdout.decode("utf-8", "ignore")
    ogg = re.search(r'(https://cdn\.freesound\.org/previews/\d+/%d_\d+)-[lh]q\.(?:mp3|ogg)' % kimlik, s)
    baslik = re.search(r'<meta property="og:title" content="([^"]*)"', s)
    yazar = re.search(r'/people/([^/"]+)/sounds/%d' % kimlik, s)
    cc0 = "publicdomain/zero/1.0" in s
    if not ogg:
        raise SystemExit(f"freesound {kimlik}: dinleme dosyası bulunamadı")
    if not cc0:
        raise SystemExit(f"freesound {kimlik}: CC0 değil, kullanılmaz")
    kunye = {"adres": ogg.group(1) + "-hq.ogg", "baslik": html.unescape(baslik.group(1)) if baslik else str(kimlik),
             "yazar": yazar.group(1) if yazar else "?", "lisans": "CC0 1.0", "sayfa": f"https://freesound.org/s/{kimlik}/"}
    kunye_yolu.write_text(json.dumps(kunye, ensure_ascii=False), encoding="utf-8")
    return kunye


def kaynagi_getir(k: dict) -> tuple:
    """(yerel dosya, künye) döndürür."""
    HAM.mkdir(parents=True, exist_ok=True)
    (HAM / ".gdignore").touch()        # ham kayıtlar proje varlığı sayılmasın
    if "freesound" in k:
        kunye = freesound(int(k["freesound"]))
        yol = HAM / f"fs_{k['freesound']}.ogg"
        indir(kunye["adres"], yol)
        return yol, kunye
    yol = HAM / k["dosya"]
    indir(k["adres"], yol)
    return yol, {"baslik": k.get("baslik", k["dosya"]), "yazar": k.get("yazar", "?"), "lisans": k.get("lisans", "?"),
                 "sayfa": k.get("sayfa", k["adres"])}


# ---------- ses işleme ----------

def oku(yol: Path, kanal: int = 1) -> np.ndarray:
    r = subprocess.run(["ffmpeg", "-v", "error", "-i", str(yol), "-ac", str(kanal), "-ar", str(SR), "-f", "f32le", "-"],
                       capture_output=True, check=True)
    x = np.frombuffer(r.stdout, np.float32).astype(np.float64)
    return x if kanal == 1 else x.reshape(-1, kanal)


def zarf(x: np.ndarray, ms: float = 8.0) -> np.ndarray:
    b, a = signal.butter(2, (1000.0 / ms) / (SR / 2), btype="low")
    return np.maximum(signal.filtfilt(b, a, np.abs(x)), 0.0)


def olaylar(x: np.ndarray, aralik: float, esik: float = 0.22) -> list:
    """Ayrı olayların başlangıç örnekleri (en güçlüden bağımsız, zaman sırasıyla)."""
    e = zarf(x)
    tepe = e.max() + 1e-12
    ust = e > tepe * esik
    baslar = np.flatnonzero(ust[1:] & ~ust[:-1]) + 1
    if ust[0]:
        baslar = np.concatenate([[0], baslar])
    secilen = []
    for b in baslar:
        if not secilen or (b - secilen[-1]) / SR >= aralik:
            secilen.append(int(b))
    return secilen


def kes(x: np.ndarray, bas: int, sure: float, on_pay: float = 0.012, sonum: float = 0.35) -> np.ndarray:
    a = max(0, bas - int(on_pay * SR))
    y = x[a:a + int(sure * SR)].copy()
    n = len(y)
    g = min(n, int(0.004 * SR))
    c = min(n, max(1, int(n * sonum)))
    y[:g] *= np.linspace(0, 1, g)
    y[-c:] *= np.linspace(1, 0, c) ** 1.5
    return y


def duzle(y: np.ndarray, tepe_db: float = -1.5) -> np.ndarray:
    t = np.abs(y).max()
    return y if t < 1e-9 else y * (10 ** (tepe_db / 20.0) / t)


def suz(y: np.ndarray, alt: float = 0.0, ust: float = 0.0) -> np.ndarray:
    if alt > 0:
        b, a = signal.butter(2, alt / (SR / 2), btype="high")
        y = signal.filtfilt(b, a, y)
    if ust > 0:
        b, a = signal.butter(2, ust / (SR / 2), btype="low")
        y = signal.filtfilt(b, a, y)
    return y


def wav_yaz(yol: Path, y: np.ndarray) -> None:
    veri = (np.clip(y, -1, 1) * 32767).astype("<i2")
    with wave.open(str(yol), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(veri.tobytes())


def ogg_yaz(yol: Path, y: np.ndarray, kalite: int = 4) -> None:
    kanal = 1 if y.ndim == 1 else y.shape[1]
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", str(kanal), "-i", "-",
                    "-c:a", "libvorbis", "-q:a", str(kalite), str(yol)], input=y.astype("<f4").tobytes(), check=True)


def olc(y: np.ndarray) -> str:
    tek = y if y.ndim == 1 else y.mean(axis=1)
    rms = 20 * np.log10(np.sqrt((tek ** 2).mean()) + 1e-9)
    f, p = signal.welch(tek, SR, nperseg=min(4096, len(tek)))
    agirlik = float((f * p).sum() / (p.sum() + 1e-12))
    return f"{len(tek) / SR:6.2f} sn  rms {rms:6.1f} dB  ağırlık merkezi {agirlik:6.0f} Hz"


# ---------- tarifler ----------

def isle(k: dict, x: np.ndarray) -> dict:
    """Tarife göre {dosya adı: ses} döndürür."""
    ad = k["ad"]
    islem = k["islem"]
    x = suz(x, float(k.get("alt", 0)), float(k.get("ust", 0)))
    tepe = float(k.get("tepe", -1.5))
    sonuc = {}
    if islem == "kesit":
        y = kes(x, int(float(k["bas"]) * SR), float(k["sure"]), 0.0, float(k.get("sonum", 0.3)))
        sonuc[f"{ad}.wav"] = duzle(y, tepe)
    elif islem == "tek":
        e = zarf(x)
        en_guclu = int(e.argmax())
        baslar = [b for b in olaylar(x, 0.05, float(k.get("esik", 0.2))) if b <= en_guclu]
        bas = baslar[-1] if baslar else en_guclu
        sonuc[f"{ad}.wav"] = duzle(kes(x, bas, float(k["sure"]), 0.012, float(k.get("sonum", 0.35))), tepe)
    elif islem == "olaylar":
        baslar = olaylar(x, float(k.get("aralik", 0.3)), float(k.get("esik", 0.25)))
        atla = int(k.get("atla", 0))
        for i, b in enumerate(baslar[atla:atla + int(k["adet"])]):
            sonuc[f"{ad}.wav" if i == 0 else f"{ad}_{i + 1}.wav"] = duzle(
                kes(x, b, float(k["sure"]), 0.012, float(k.get("sonum", 0.35))), tepe)
    elif islem == "taneler":
        # konuşma heceleri: enerjinin en dolgun olduğu yerlerden kısa taneler
        e = zarf(x, 25.0)
        adet = int(k["adet"])
        uzunluk = float(k.get("sure", 0.085))
        aday = signal.find_peaks(e, distance=int(0.16 * SR), height=e.max() * 0.3)[0]
        aday = sorted(aday, key=lambda i: -e[i])[:adet]
        for i, orta in enumerate(sorted(aday)):
            a = max(0, int(orta - uzunluk * SR * 0.4))
            y = x[a:a + int(uzunluk * SR)].copy()
            pencere = np.ones(len(y))
            kenar = int(0.012 * SR)
            pencere[:kenar] = np.hanning(kenar * 2)[:kenar]
            pencere[-kenar * 2:] = np.hanning(kenar * 4)[-kenar * 2:]
            sonuc[f"{ad}.wav" if i == 0 else f"{ad}_{i + 1}.wav"] = duzle(y * pencere, tepe)
    elif islem == "dongu":
        bas = int(float(k.get("bas", 0)) * SR)
        n = int(float(k["sure"]) * SR)
        gecis = int(float(k.get("gecis", 1.5)) * SR)
        y = x[bas:bas + n + gecis].copy()
        if len(y) < n + gecis:
            raise SystemExit(f"{ad}: kaynak döngü için kısa")
        egri = np.linspace(0, 1, gecis)
        y[:gecis] = y[:gecis] * np.sqrt(egri) + y[n:n + gecis] * np.sqrt(1 - egri)
        y = duzle(y[:n], 0.0)
        if float(k.get("sikistir", 0)) > 0:      # seyrek çıtırtılı kayıtlarda zemini yükseltir
            g = float(k["sikistir"])
            y = np.tanh(y * g) / np.tanh(g)
        sonuc[f"{ad}.ogg"] = duzle(y, float(k.get("tepe", -3.0)))
    elif islem == "muzik":
        raise RuntimeError("müzik ayrı işlenir")
    else:
        raise SystemExit(f"{ad}: bilinmeyen işlem {islem}")
    return sonuc


def muzik_isle(k: dict, yol: Path) -> None:
    """Parçayı düzeyi eşitlenmiş OGG olarak yazar (ffmpeg loudnorm); baş ve sondaki sessizliği kırpar."""
    MUZIK.mkdir(parents=True, exist_ok=True)
    hedef = MUZIK / f"{k['ad']}.ogg"
    suzgec = ["silenceremove=start_periods=1:start_threshold=-50dB:start_silence=0.2"]
    komut = ["ffmpeg", "-v", "error", "-y"]
    if "bas" in k:
        komut += ["-ss", str(k["bas"])]
    komut += ["-i", str(yol)]
    if "sure" in k:
        komut += ["-t", str(k["sure"])]
        suzgec.append(f"afade=t=out:st={float(k['sure']) - 6.0}:d=6")
    if float(k.get("alt", 0)) > 0:
        suzgec.append(f"highpass=f={k['alt']}")
    suzgec.append("loudnorm=I=-18:TP=-1.5:LRA=11")
    komut += ["-af", ",".join(suzgec), "-ar", str(SR), "-ac", str(k.get("kanal", 2)), "-c:a", "libvorbis", "-q:a",
              str(k.get("kalite", 4)), str(hedef)]
    subprocess.run(komut, check=True)
    print(f"  muzik/{hedef.name:28} {olc(oku(hedef))}  ({hedef.stat().st_size // 1024} KB)")


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    tarif = json.loads(TARIF.read_text(encoding="utf-8"))
    istenen = set(sys.argv[1:])
    CIKTI.mkdir(parents=True, exist_ok=True)
    kunyeler = []
    for k in tarif["sesler"]:
        if "parcalar" in k:
            kaynaklar = [kaynagi_getir(p) for p in k["parcalar"]]
        else:
            kaynaklar = [kaynagi_getir(k)]
        for _, kunye in kaynaklar:
            kunyeler.append((k["ad"], kunye))
        if istenen and k["ad"] not in istenen:
            continue
        if k["islem"] == "muzik":
            muzik_isle(k, kaynaklar[0][0])
            continue
        if k["islem"] == "karisim":
            toplam = np.zeros(int(float(k["sure"]) * SR))
            for p, (yol, _) in zip(k["parcalar"], kaynaklar):
                parca = dict(p, ad="_", islem=p.get("islem", "tek"))
                y = list(isle(parca, oku(yol)).values())[0] * float(p.get("kazanc", 1.0))
                a = int(float(p.get("an", 0)) * SR)
                y = y[:max(0, len(toplam) - a)]
                toplam[a:a + len(y)] += y
            cikti = {f"{k['ad']}.wav": duzle(toplam, float(k.get("tepe", -1.5)))}
        else:
            cikti = isle(k, oku(kaynaklar[0][0]))
        if not cikti:
            print(f"  {k['ad']}: OLAY BULUNAMADI")
        for dosya, y in cikti.items():
            if dosya.endswith(".ogg"):
                ogg_yaz(CIKTI / dosya, y)
            else:
                wav_yaz(CIKTI / dosya, y)
            print(f"  {dosya:22} {olc(y)}")

    # künye dosyası
    satirlar = ["# Ses kaynakları", "",
                "Oyundaki bütün sesler gerçek kayıtlardan derlenmiştir (`tools/ses/topla.py`). Efektler Freesound'daki",
                "CC0 (kamu malı) kayıtlardan kesilmiştir; müzikler Wikimedia Commons ve Freesound'dan alınmıştır.", "",
                "| Oyundaki ses | Kayıt | Kaydeden | Lisans |", "|---|---|---|---|"]
    gorulen = set()
    for ad, kunye in kunyeler:
        anahtar = (ad, kunye["sayfa"])
        if anahtar in gorulen:
            continue
        gorulen.add(anahtar)
        satirlar.append(f"| `{ad}` | [{kunye['baslik']}]({kunye['sayfa']}) | {kunye['yazar']} | {kunye['lisans']} |")
    (CIKTI / "KAYNAKLAR.md").write_text("\n".join(satirlar) + "\n", encoding="utf-8")
    print(f"{len(gorulen)} kaynak; künye: assets/ses/KAYNAKLAR.md")


if __name__ == "__main__":
    main()
