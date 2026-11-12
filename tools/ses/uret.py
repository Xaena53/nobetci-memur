"""Oyunun bütün seslerini sentezler (dış kaynak kullanılmaz; üretilen dosyalar CC0'dır).

Efektler assets/ses/*.wav (22,05 kHz, tek kanal), döngülü ortam sesleri assets/ses/*.ogg olarak yazılır.
Ortam sesleri için ffmpeg gerekir (yoksa .wav olarak bırakılır).

Kullanım: python tools/ses/uret.py
"""
import shutil
import subprocess
import wave
from pathlib import Path

import numpy as np
from scipy import signal

SR = 22050
KOK = Path(__file__).resolve().parents[2]
CIKTI = KOK / "assets" / "ses"
rng = np.random.default_rng(1984)


# ---------- yardımcılar ----------

def t(sure: float) -> np.ndarray:
    return np.arange(int(SR * sure)) / SR


def gurultu(sure: float) -> np.ndarray:
    return rng.uniform(-1, 1, int(SR * sure))


def bant(x: np.ndarray, alt: float, ust: float, derece: int = 2) -> np.ndarray:
    b, a = signal.butter(derece, [alt / (SR / 2), min(0.99, ust / (SR / 2))], btype="band")
    return signal.lfilter(b, a, x)


def alcak(x: np.ndarray, kesim: float, derece: int = 2) -> np.ndarray:
    b, a = signal.butter(derece, kesim / (SR / 2), btype="low")
    return signal.lfilter(b, a, x)


def yuksek(x: np.ndarray, kesim: float, derece: int = 2) -> np.ndarray:
    b, a = signal.butter(derece, kesim / (SR / 2), btype="high")
    return signal.lfilter(b, a, x)


def sonum(sure: float, hiz: float) -> np.ndarray:
    return np.exp(-t(sure) * hiz)


def kenar(x: np.ndarray, giris: float = 0.003, cikis: float = 0.01) -> np.ndarray:
    x = x.copy()
    g, c = int(SR * giris), int(SR * cikis)
    if g > 0:
        x[:g] *= np.linspace(0, 1, g)
    if c > 0:
        x[-c:] *= np.linspace(1, 0, c)
    return x


def ekle(hedef: np.ndarray, parca: np.ndarray, an: float, kazanc: float = 1.0) -> None:
    i = int(SR * an)
    n = min(len(parca), len(hedef) - i)
    if n > 0:
        hedef[i:i + n] += parca[:n] * kazanc


def duzle(x: np.ndarray, tepe: float = 0.9) -> np.ndarray:
    m = np.max(np.abs(x))
    return x / m * tepe if m > 0 else x


def yaz(ad: str, x: np.ndarray, tepe: float = 0.9) -> None:
    x = np.clip(duzle(x, tepe), -1, 1)
    with wave.open(str(CIKTI / f"{ad}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())


def dongu_yaz(ad: str, x: np.ndarray, tepe: float = 0.8, gecis: float = 0.6) -> None:
    """Başı ile sonu birbirine karıştırılarak kesintisiz dönen bir kayıt yazar (ogg)."""
    g = int(SR * gecis)
    govde = x[:-g].copy()
    egri = np.linspace(0, 1, g)
    govde[:g] = govde[:g] * egri + x[-g:] * (1 - egri)
    yaz(ad, govde, tepe)
    wav = CIKTI / f"{ad}.wav"
    if shutil.which("ffmpeg"):
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "3",
                        str(CIKTI / f"{ad}.ogg")], check=True)
        wav.unlink()


# ---------- efektler ----------

def muhur() -> np.ndarray:
    """Mührün kâğıda inişi: tok bir vuruş, ahşap sapın tıkırtısı ve ıstampanın ıslak sesi."""
    x = np.zeros(int(SR * 0.42))
    z = t(0.30)
    ekle(x, np.sin(2 * np.pi * (95 * np.exp(-z * 9) + 48) * z) * np.exp(-z * 16), 0.0, 1.0)
    ekle(x, bant(gurultu(0.05), 900, 4200) * sonum(0.05, 85), 0.0, 0.8)
    ekle(x, np.sin(2 * np.pi * 310 * t(0.09)) * sonum(0.09, 46), 0.004, 0.35)
    ekle(x, alcak(gurultu(0.16), 700) * sonum(0.16, 24), 0.01, 0.5)
    return kenar(x, 0.001, 0.05)


def kagit(sure: float = 0.26, parlak: float = 1.0) -> np.ndarray:
    """Kâğıt hışırtısı: düzensiz dalgalanan yüksek bantlı gürültü."""
    n = int(SR * sure)
    zarf = np.abs(alcak(rng.normal(0, 1, n), 38)) ** 1.4
    zarf = zarf / zarf.max() * np.hanning(n) ** 0.6
    return kenar(bant(gurultu(sure), 1800, 7500 * parlak) * zarf, 0.004, 0.03)


def kagit_kay() -> np.ndarray:
    """Belgenin yarıktan masaya kayışı ve durunca çıkan hafif tık."""
    n = int(SR * 0.34)
    zarf = np.sin(np.linspace(0, np.pi, n)) ** 0.7
    x = bant(gurultu(0.34), 1200, 5200) * zarf * (0.7 + 0.3 * np.abs(alcak(rng.normal(0, 1, n), 60)))
    ekle(x, bant(gurultu(0.03), 500, 2500) * sonum(0.03, 120), 0.29, 1.4)
    return kenar(x, 0.01, 0.02)


def sayfa() -> np.ndarray:
    """Defter sayfasının çevrilişi."""
    n = int(SR * 0.30)
    x = gurultu(0.30)
    cikti = np.zeros(n)
    parca = n // 6
    for i in range(6):
        alt = 900 + i * 500
        cikti[i * parca:(i + 1) * parca] = bant(x, alt, alt + 3200)[i * parca:(i + 1) * parca]
    zarf = np.concatenate([np.linspace(0, 1, n // 3), np.linspace(1, 0.15, n - n // 3)])
    ekle(cikti, bant(gurultu(0.04), 700, 3000) * sonum(0.04, 90), 0.24, 1.2)
    return kenar(cikti * zarf, 0.005, 0.03)


def zil() -> np.ndarray:
    """Gişe zili: tek vuruşluk, uzun sönen madenî ses."""
    z = t(1.5)
    x = np.zeros(len(z))
    for f, k, s in [(2093, 1.0, 3.2), (4219, 0.5, 4.6), (5650, 0.32, 6.5), (8372, 0.18, 9.0), (1046, 0.12, 5.0)]:
        x += k * np.sin(2 * np.pi * f * z) * np.exp(-z * s)
    ekle(x, bant(gurultu(0.012), 2500, 9000) * sonum(0.012, 300), 0.0, 0.7)
    return kenar(x, 0.0005, 0.2)


def teleks() -> np.ndarray:
    """Teleks kafasının tek vuruşu."""
    x = np.zeros(int(SR * 0.075))
    ekle(x, bant(gurultu(0.016), 1500, 6500) * sonum(0.016, 260), 0.0, 1.0)
    ekle(x, np.sin(2 * np.pi * 170 * t(0.05)) * sonum(0.05, 70), 0.002, 0.55)
    ekle(x, bant(gurultu(0.03), 300, 1400) * sonum(0.03, 110), 0.004, 0.5)
    return kenar(x, 0.0005, 0.01)


def daktilo() -> np.ndarray:
    """Daktilo tuşu: tuşun inişi ve harf kolunun merdaneye vuruşu."""
    x = np.zeros(int(SR * 0.085))
    ekle(x, bant(gurultu(0.01), 2000, 7500) * sonum(0.01, 380), 0.0, 0.55)
    ekle(x, bant(gurultu(0.02), 900, 5000) * sonum(0.02, 200), 0.014, 1.0)
    ekle(x, np.sin(2 * np.pi * 240 * t(0.04)) * sonum(0.04, 85), 0.014, 0.45)
    return kenar(x, 0.0005, 0.01)


def yirt() -> np.ndarray:
    """Teleks kâğıdının tırtıklı ağızdan koparılışı."""
    n = int(SR * 0.28)
    x = bant(gurultu(0.28), 1500, 8000)
    citirti = (rng.random(n) > 0.86).astype(float)
    citirti = signal.lfilter([1.0], [1.0, -0.72], citirti)
    zarf = np.linspace(0.25, 1.0, n) ** 1.5
    return kenar(x * citirti * zarf, 0.003, 0.012)


def hece() -> np.ndarray:
    """Konuşma hecesi: gırtlak titreşimi iki biçimlendirici süzgeçten geçer (anlamsız, sıcak bir "a")."""
    sure = 0.085
    z = t(sure)
    f0 = 150 * (1 + 0.06 * np.sin(2 * np.pi * 9 * z)) * (1.04 - 0.5 * z)
    faz = 2 * np.pi * np.cumsum(f0) / SR
    kaynak = signal.sawtooth(faz) * 0.7 + 0.3 * np.sin(faz)
    x = bant(kaynak, 520, 900, 1) * 1.0 + bant(kaynak, 1000, 1500, 1) * 0.55 + bant(kaynak, 2300, 2900, 1) * 0.12
    return kenar(x * np.hanning(len(z)) ** 0.5, 0.008, 0.03)


def adim() -> np.ndarray:
    """Tahta zeminde ayak sesi."""
    x = np.zeros(int(SR * 0.16))
    z = t(0.12)
    ekle(x, np.sin(2 * np.pi * (120 * np.exp(-z * 20) + 62) * z) * np.exp(-z * 34), 0.0, 1.0)
    ekle(x, alcak(gurultu(0.07), 900) * sonum(0.07, 60), 0.0, 0.5)
    ekle(x, bant(gurultu(0.02), 1200, 3000) * sonum(0.02, 200), 0.002, 0.18)
    return kenar(x, 0.001, 0.03)


def ofle() -> np.ndarray:
    """Öfleme: ağızdan üflenen nefes."""
    n = int(SR * 0.62)
    zarf = np.concatenate([np.linspace(0, 1, n // 5) ** 2, np.linspace(1, 0, n - n // 5) ** 1.6])
    x = bant(gurultu(0.62), 250, 2400, 1) + 0.4 * bant(gurultu(0.62), 2400, 5200, 1)
    return kenar(x * zarf, 0.01, 0.05)


def kepenk() -> np.ndarray:
    """Ahşap kepengin inişi: hızlanan lata tıkırtıları ve tok kapanış."""
    x = np.zeros(int(SR * 1.5))
    an = 0.0
    aralik = 0.085
    while an < 1.05:
        tik = bant(gurultu(0.03), 500, 2600) * sonum(0.03, 150) + 0.6 * np.sin(2 * np.pi * rng.uniform(160, 230) * t(0.03)) * sonum(0.03, 110)
        ekle(x, tik, an, rng.uniform(0.45, 0.8))
        an += aralik
        aralik *= 0.955
    ekle(x, alcak(gurultu(1.1), 500) * np.linspace(0.2, 0.5, int(SR * 1.1)), 0.0, 0.35)
    z = t(0.34)
    ekle(x, np.sin(2 * np.pi * (85 * np.exp(-z * 8) + 44) * z) * np.exp(-z * 13), 1.08, 1.3)
    ekle(x, bant(gurultu(0.06), 300, 2500) * sonum(0.06, 60), 1.08, 0.9)
    return kenar(x, 0.002, 0.08)


def ihtar() -> np.ndarray:
    """Teleksin ihtar öncesi kısa, sevimsiz vızıltısı."""
    z = t(0.34)
    x = signal.square(2 * np.pi * 172 * z, duty=0.38) * 0.6 + signal.square(2 * np.pi * 258 * z) * 0.25
    x = alcak(x, 1900) * (0.75 + 0.25 * signal.square(2 * np.pi * 21 * z))
    return kenar(x, 0.004, 0.02)


def prim() -> np.ndarray:
    """Doğru işlem: bozuk paranın masaya düşüşü gibi iki parlak çınlama."""
    x = np.zeros(int(SR * 0.5))
    for an, f in [(0.0, 2637), (0.075, 3520)]:
        z = t(0.4)
        ekle(x, (np.sin(2 * np.pi * f * z) + 0.4 * np.sin(2 * np.pi * f * 2.41 * z)) * np.exp(-z * 13), an, 0.8)
    return kenar(x, 0.001, 0.05)


def tik() -> np.ndarray:
    """Arayüz tıkı: küçük, kuru."""
    x = np.zeros(int(SR * 0.04))
    ekle(x, bant(gurultu(0.012), 1200, 5000) * sonum(0.012, 300), 0.0, 1.0)
    ekle(x, np.sin(2 * np.pi * 620 * t(0.03)) * sonum(0.03, 140), 0.0, 0.5)
    return kenar(x, 0.0005, 0.008)


def saat() -> np.ndarray:
    """Duvar saatinin tek tıkı."""
    x = np.zeros(int(SR * 0.06))
    ekle(x, bant(gurultu(0.008), 2500, 7000) * sonum(0.008, 420), 0.0, 1.0)
    ekle(x, np.sin(2 * np.pi * 1850 * t(0.03)) * sonum(0.03, 160), 0.0, 0.35)
    return kenar(x, 0.0003, 0.01)


def jaluzi() -> np.ndarray:
    """Jaluzinin çekilişi: art arda ince madenî tıkırtılar."""
    x = np.zeros(int(SR * 0.6))
    for i in range(16):
        f = rng.uniform(2200, 3600)
        tikir = (np.sin(2 * np.pi * f * t(0.03)) * 0.5 + bant(gurultu(0.03), 1800, 6000)) * sonum(0.03, 170)
        ekle(x, tikir, 0.02 + i * 0.032 + rng.uniform(-0.006, 0.006), rng.uniform(0.4, 0.9))
    return kenar(x, 0.002, 0.04)


def zarf() -> np.ndarray:
    """Zarfın çekmeceye atılışı: kâğıt hışırtısı ve çekmecenin kapanışı."""
    x = np.zeros(int(SR * 0.7))
    ekle(x, kagit(0.24, 0.8), 0.0, 0.8)
    ekle(x, alcak(gurultu(0.2), 600) * np.hanning(int(SR * 0.2)), 0.22, 0.6)
    z = t(0.2)
    ekle(x, np.sin(2 * np.pi * (110 * np.exp(-z * 14) + 60) * z) * np.exp(-z * 20), 0.42, 1.2)
    ekle(x, bant(gurultu(0.04), 400, 2400) * sonum(0.04, 100), 0.42, 0.7)
    return kenar(x, 0.003, 0.05)


def kalem() -> np.ndarray:
    """Dolma kalemin deftere attığı işaret."""
    n = int(SR * 0.2)
    zarf_egrisi = np.concatenate([np.hanning(n // 2), 0.8 * np.hanning(n - n // 2)])
    return kenar(bant(gurultu(0.2), 2200, 6500) * zarf_egrisi * (0.6 + 0.4 * np.abs(alcak(rng.normal(0, 1, n), 90))), 0.004, 0.02)


def patlama() -> np.ndarray:
    """Uzaktaki patlama: boğuk vuruş, uzun gümbürtü ve zangırdayan camlar."""
    n = int(SR * 3.4)
    x = np.zeros(n)
    z = t(1.2)
    ekle(x, np.sin(2 * np.pi * (70 * np.exp(-z * 3) + 30) * z) * np.exp(-z * 3.2), 0.0, 1.4)
    ekle(x, alcak(gurultu(3.3), 240, 3) * np.exp(-t(3.3) * 1.5), 0.02, 2.2)
    ekle(x, alcak(gurultu(1.0), 1400) * np.exp(-t(1.0) * 6), 0.0, 0.8)
    for i in range(22):  # camların zangırtısı
        f = rng.uniform(1700, 3200)
        ekle(x, np.sin(2 * np.pi * f * t(0.05)) * sonum(0.05, 80), 0.35 + rng.uniform(0, 1.1), rng.uniform(0.02, 0.07))
    return kenar(x, 0.002, 0.4)


def silah() -> np.ndarray:
    """Uzaktan duyulan tek el silah sesi ve sokaktaki yankısı."""
    n = int(SR * 1.5)
    x = np.zeros(n)
    patlak = alcak(gurultu(0.09), 2600) * sonum(0.09, 55)
    ekle(x, patlak, 0.0, 1.5)
    z = t(0.2)
    ekle(x, np.sin(2 * np.pi * (140 * np.exp(-z * 18) + 50) * z) * np.exp(-z * 22), 0.0, 0.9)
    for an, k in [(0.19, 0.34), (0.37, 0.2), (0.61, 0.11), (0.9, 0.06)]:
        ekle(x, alcak(patlak, 1400 - an * 900), an, k)
    ekle(x, alcak(gurultu(1.3), 420) * np.exp(-t(1.3) * 3.4), 0.03, 0.5)
    return kenar(x, 0.0008, 0.3)


# ---------- döngülü ortam sesleri ----------

def soba(sure: float = 9.0) -> np.ndarray:
    """Sobanın çıtırtısı: alçak bir uğultunun üstünde düzensiz çıtlamalar."""
    n = int(SR * sure)
    x = alcak(gurultu(sure), 320, 2) * 0.5 * (0.8 + 0.2 * np.sin(2 * np.pi * 0.31 * t(sure)))
    x += bant(gurultu(sure), 400, 1500, 1) * 0.07
    an = 0.1
    while an < sure - 0.2:
        siddet = rng.uniform(0.15, 1.0) ** 2
        cit = bant(gurultu(0.012), 1800, 8000) * sonum(0.012, rng.uniform(250, 600))
        ekle(x, cit, an, siddet * 1.3)
        if rng.random() < 0.35:
            ekle(x, cit[::-1] * 0.5, an + rng.uniform(0.015, 0.05), siddet)
        an += rng.exponential(0.22)
    return x[:n]


def ruzgar(sure: float = 12.0) -> np.ndarray:
    """Kış rüzgârı: ağır ağır kabarıp alçalan uğultu."""
    z = t(sure)
    yavas = 0.5 + 0.5 * np.sin(2 * np.pi * z / sure * 2 + 1.0) * np.sin(2 * np.pi * z / sure * 3)
    x = alcak(gurultu(sure), 420, 2) * (0.45 + 0.55 * yavas)
    islik = bant(gurultu(sure), 600, 950, 2) * (0.12 + 0.5 * np.clip(yavas - 0.45, 0, 1) ** 2)
    return x + islik * 0.8


def bant_sesi() -> np.ndarray:
    """Röntgen cihazının bandı: motorun uğultusu, makaraların tıkırtısı; çalışıp yavaşlayarak durur."""
    sure = 1.9
    z = t(sure)
    hiz = np.clip(z / 0.25, 0, 1) * np.clip((sure - z) / 0.45, 0, 1)
    faz = 2 * np.pi * np.cumsum(92 * (0.55 + 0.45 * hiz)) / SR
    x = (np.sin(faz) * 0.5 + signal.sawtooth(faz * 2.0) * 0.16) * hiz
    x += bant(gurultu(sure), 250, 1800) * 0.22 * hiz
    for i in range(22):                                   # makara tıkırtısı
        an = 0.12 + i * 0.075
        if an < sure - 0.25:
            ekle(x, bant(gurultu(0.012), 900, 3200) * sonum(0.012, 260), an, 0.25)
    return kenar(alcak(x, 2600), 0.02, 0.12)


def dugme() -> np.ndarray:
    """Cihazın iri düğmesi: yaylı, tok bir çıt."""
    x = np.zeros(int(SR * 0.12))
    ekle(x, bant(gurultu(0.02), 500, 3000) * sonum(0.02, 170), 0.0, 1.0)
    ekle(x, np.sin(2 * np.pi * 210 * t(0.07)) * sonum(0.07, 55), 0.0, 0.7)
    ekle(x, bant(gurultu(0.012), 1500, 5000) * sonum(0.012, 300), 0.055, 0.45)
    return kenar(x, 0.0005, 0.02)


def alarm() -> np.ndarray:
    """Röntgen alarmı: iki perdeli, cırtlak bir vızıltı (üç kez)."""
    x = np.zeros(int(SR * 0.95))
    for i in range(3):
        z = t(0.2)
        f = 740 if i % 2 == 0 else 590
        v = signal.square(2 * np.pi * f * z, duty=0.45) * 0.5 + np.sin(2 * np.pi * f * 2 * z) * 0.2
        ekle(x, kenar(alcak(v, 3200), 0.004, 0.02), i * 0.28, 0.9)
    return kenar(x, 0.002, 0.03)


def cizirti() -> np.ndarray:
    """Sokak lambasının cızırtısı: şebeke uğultusu kesik kesik gelir, üstünde ince çıtırtılar."""
    sure = 0.95
    z = t(sure)
    vizilti = np.abs(np.sin(2 * np.pi * 50 * z)) ** 3 * 0.55 + signal.sawtooth(2 * np.pi * 100 * z) * 0.18
    vizilti = bant(vizilti + gurultu(sure) * 0.25, 90, 3400, 2)
    kapi = np.zeros(len(z))
    an = 0.0
    while an < sure - 0.05:                                   # düzensiz yanıp sönme
        uzun = rng.uniform(0.02, 0.11)
        if rng.random() < 0.62:
            kapi[int(an * SR):int((an + uzun) * SR)] = rng.uniform(0.5, 1.0)
        an += uzun
    kapi = alcak(kapi, 180)
    x = vizilti * kapi
    for _ in range(26):                                       # kıvılcım çıtırtıları
        ekle(x, yuksek(gurultu(0.004), 2500) * sonum(0.004, 700), rng.uniform(0.0, sure - 0.02), rng.uniform(0.25, 0.8))
    return kenar(x, 0.004, 0.06)


def tel(frekans: float, sure: float, parlaklik: float = 0.5) -> np.ndarray:
    """Mızrapla çekilen tel (Karplus-Strong): gürültüyle dolu bir gecikme hattı her turda yumuşar."""
    uzunluk = max(2, int(round(SR / frekans)))
    tur = rng.uniform(-1, 1, uzunluk)
    tur = alcak(tur, 1200 + 5000 * parlaklik, 1)
    adet = int(SR * sure / uzunluk) + 1
    cikti = np.empty(adet * uzunluk)
    sonme = 0.996 - 0.0012 * (frekans / 200.0)
    for i in range(adet):
        cikti[i * uzunluk:(i + 1) * uzunluk] = tur
        tur = 0.5 * (tur + np.roll(tur, 1)) * sonme
    return cikti[:int(SR * sure)]


def radyo(sure_olcu: int = 16) -> np.ndarray:
    """Kısık sesli radyoda çalan bağlama: Hicaz dizisinde, dokuz zamanlı (2+2+2+3) özgün bir ezgi.

    Ezgi kurallarla üretilir (sabit tohum): dizi içinde adım adım yürür, cümle sonlarında karara iner.
    Sonra dar bir bantta süzülüp cızırtı ve hafif dalgalanma eklenir; hoparlörden gelir gibi duyulur.
    """
    karar = 146.83  # re
    # Hicaz: re, mi bemol, fa diyez, sol, la, si bemol, do, re (yarım ses adımlarıyla)
    dizi = [0, 1, 4, 5, 7, 8, 10, 12, 13, 16]
    vurus = 0.36               # sekizlik nota süresi
    kalip = [2, 2, 2, 3]       # dokuz sekizlik aksak
    n = int(SR * vurus * 9 * sure_olcu) + SR
    x = np.zeros(n)
    ezgi_rng = np.random.default_rng(84)
    derece = 4
    an = 0.0
    for olcu in range(sure_olcu):
        cumle_sonu = olcu % 4 == 3
        for i, uz in enumerate(kalip):
            son_vurus = cumle_sonu and i == len(kalip) - 1
            if son_vurus:
                derece = 0 if olcu % 8 == 7 else 4
            else:
                adim = ezgi_rng.choice([-2, -1, -1, 1, 1, 2, 0])
                derece = int(np.clip(derece + adim, 0, len(dizi) - 1))
                if cumle_sonu:
                    derece = max(0, derece - 1)
            f = karar * 2 ** (dizi[derece] / 12)
            nota = tel(f * 2, vurus * uz * 1.6, 0.6) + 0.5 * tel(f, vurus * uz * 1.6, 0.4)
            ekle(x, nota, an, 0.9)
            # aksak vuruşun ortasında tek mızraplık süsleme
            if uz == 3 and not son_vurus:
                komsu = int(np.clip(derece + 1, 0, len(dizi) - 1))
                ekle(x, tel(karar * 2 * 2 ** (dizi[komsu] / 12), vurus * 0.9, 0.7), an + vurus * 2, 0.5)
            # dem teli: her ölçü başında karar sesi
            if i == 0:
                ekle(x, tel(karar, vurus * 5, 0.25), an, 0.45)
            an += vurus * uz
    x = x[:int(SR * vurus * 9 * sure_olcu)]
    z = np.arange(len(x)) / SR
    x = duzle(x, 0.9)
    x = np.tanh(bant(x, 380, 2700, 2) * 2.2)                                # küçük hoparlör
    x *= 0.82 + 0.18 * np.sin(2 * np.pi * 0.13 * z) * np.sin(2 * np.pi * 0.071 * z)   # yayın dalgalanması
    cizirti = bant(rng.uniform(-1, 1, len(x)), 1500, 6000, 1) * 0.035
    cizirti += (rng.random(len(x)) > 0.9994) * rng.uniform(-0.5, 0.5, len(x))
    ugultu = 0.012 * np.sin(2 * np.pi * 50 * z)
    return x * 0.8 + bant(cizirti, 800, 5000, 1) + ugultu


def main() -> None:
    CIKTI.mkdir(parents=True, exist_ok=True)
    efektler = {
        "muhur": muhur, "kagit": kagit, "kagit_kay": kagit_kay, "sayfa": sayfa, "zil": zil, "teleks": teleks,
        "daktilo": daktilo, "yirt": yirt, "hece": hece, "adim": adim, "ofle": ofle, "kepenk": kepenk,
        "ihtar": ihtar, "prim": prim, "tik": tik, "saat": saat, "jaluzi": jaluzi, "zarf": zarf, "kalem": kalem,
        "patlama": patlama, "silah": silah, "bant": bant_sesi, "dugme": dugme, "alarm": alarm,
        "cizirti": cizirti,
    }
    for ad, uretici in efektler.items():
        yaz(ad, uretici())
    dongu_yaz("soba", soba())
    dongu_yaz("ruzgar", ruzgar(), 0.7, 1.2)
    dongu_yaz("radyo", radyo(), 0.75, 0.05)
    toplam = sum(p.stat().st_size for p in CIKTI.iterdir() if p.suffix in (".wav", ".ogg"))
    print(f"{len(efektler)} efekt + 3 ortam sesi yazıldı: {toplam / 1024:.0f} KB")


if __name__ == "__main__":
    main()
