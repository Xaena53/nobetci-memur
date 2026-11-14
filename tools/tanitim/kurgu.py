# -*- coding: utf-8 -*-
"""Tanıtım filminin kurgusu.

Kullanım:  python tools/tanitim/kurgu.py <kayıt klasörü> <çıktı klasörü> [bicim=yatay]

Kayıt klasöründe `bash tools/tanitim/cek.sh <sahne> <klasör>` ile alınmış gise, rontgen, ev ve menu
kayıtları bulunmalıdır. Betik sırasıyla:
  1. çekimleri müziğin vuruşlarına göre kesip tek bir taban görüntüsü yapar (ffmpeg),
  2. yazı katmanını başsız Chrome'da kare kare çizer (katman.html; pencere açılmaz),
  3. müziği, çekimlerin kendi seslerini ve daktilo tuşlarını karıştırır,
  4. hepsini birleştirip tanitim.mp4 ve kapak karesini yazar.

Müzik: "Harman Dalı", Turku, Nomads of the Silk Road (CC BY 4.0); paylaşımda atıf verilmelidir.
"""
import asyncio
import base64
import functools
import http.server
import json
import shutil
import subprocess
import sys
import tempfile
import threading
import time
import urllib.request
from pathlib import Path

import numpy as np
import websockets

KOK = Path(__file__).resolve().parents[2]
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
KAPI, HATA_KAPISI = 8793, 9346
FPS = 30
HIZ = 48000                      # ses örnekleme hızı

# --- Müzik ızgarası (tools/tanitim/kurgu.py içindeki sayılar harman_dali.ogg ölçümünden gelir) ---
VURUS = 0.2894                   # sekizlik vuruş aralığı (sn)
MUZIK_ILK = 11.076               # ana bölümün ilk vuruşu (parçadaki an)
MUZIK_GIRIS = 9.5                # parçadan alınan ilk an (ana bölümden önceki kısa giriş)
T0 = 3.8                         # ana bölümün filmdeki başlangıcı: ondan öncesi açılış
SON_SURE = 5.0                   # kapanış kartının süresi

KAYNAK_EN, KAYNAK_BOY = 1872, 1053
TAM = (0, 0, 1872, 1053)
SOL_UST = (0, 0, 1536, 864)
SOL_ALT = (0, 189, 1536, 864)


def v(k):
    """k. vuruşun filmdeki kare numarası."""
    return round((T0 + k * VURUS) * FPS)


# Çekimler: (ad, kayıt, kayıttaki ilk kare, başlangıç vuruşu, bitiş vuruşu, kırpma)
CEKIMLER = [
    ("acilis", "menu", 60, None, 0, TAM),
    ("gise", "gise", 92, 0, 8, SOL_UST),
    ("inceleme", "gise", 213, 8, 20, SOL_ALT),
    ("muhur_al", "gise", 358, 20, 24, SOL_ALT),
    ("muhur", "gise", 416, 24, 28, SOL_ALT),
    ("rontgen", "rontgen", 258, 28, 34, TAM),
    ("alarm", "rontgen", 363, 34, 40, TAM),
    ("kolluk", "rontgen", 424, 40, 44, SOL_UST),
    ("ev", "ev", 80, 44, 56, TAM),
    ("kasaba", None, 0, 56, 70, TAM),
    ("kapanis", "menu", 313, 70, None, TAM),
]


def plan_kur():
    """Çekimlerin film karelerini ve yazı katmanının planını üretir."""
    cekimler = []
    for ad, kayit, ilk, k0, k1, kirp in CEKIMLER:
        a = 0 if k0 is None else v(k0)
        b = v(70) + round(SON_SURE * FPS) if k1 is None else v(k1)
        cekimler.append({"ad": ad, "kayit": kayit, "ilk": ilk, "a": a, "b": b, "kirp": kirp})
    toplam = cekimler[-1]["b"]
    z = {c["ad"]: (c["a"] / FPS, c["b"] / FPS) for c in cekimler}
    son = toplam / FPS

    def serit(t0, t1, x, y, satirlar, aci=-1.2, hiz=30, gecikme=0.12, punto=None):
        return {"tur": "serit", "t0": t0, "t1": t1, "x": x, "y": y, "aci": aci, "hiz": hiz, "gecikme": gecikme,
                "punto": punto, "satirlar": [s if isinstance(s, dict) else {"metin": s} for s in satirlar]}

    kb = z["kasaba"]
    ks = (kb[1] - kb[0]) / 14.0          # kasaba bölümünde bir vuruş
    kp = z["kapanis"][0]
    yazilar = [
        {"tur": "yil", "t0": 0.35, "t1": z["acilis"][1], "x": 430, "y": 300, "hiz": 5.5, "gecikme": 0.0,
         "satirlar": [{"metin": "1984"}]},
        serit(1.35, z["acilis"][1], 545, 985, ["Kuyruk kapıya kadar uzanıyor."], punto=54),
        serit(z["gise"][0] + 0.1, z["gise"][1], 960, 968, ["2 numaralı gişe sizin."], aci=1.0),
        serit(z["inceleme"][0] + 0.1, z["inceleme"][1], 1330, 968, ["Okuyun. Karşılaştırın."]),
        serit(z["muhur_al"][0] + 0.05, z["muhur"][1], 1420, 968, ["Karar verin."], aci=1.2),
        serit(z["rontgen"][0] + 0.1, z["alarm"][1], 1400, 915, ["Çantada ne var?"], aci=-1.6),
        serit(z["ev"][0] + 0.15, z["ev"][1], 1510, 775, ["Maaş hepsine yetmez."], aci=-2.0, punto=46),
        serit(kb[0] + 0.08, kb[0] + 8 * ks, 960, 930, ["Yedi iş günü."], aci=-1.0, punto=76),
        serit(kb[0] + 8 * ks + 0.05, kb[1], 960, 930, [{"metin": "Yedi farklı son.", "vurgu": True}], aci=1.0, punto=76),
        serit(kp + 2.25, son, 470, 792, [{"metin": "Tarayıcıda oynayın:", "kucuk": True},
                                        {"metin": "xaena53.github.io/nobetci-memur", "vurgu": True},
                                        {"metin": "Müzik: Harman Dalı · Turku, Nomads of the Silk Road · CC BY 4.0", "not": True}],
              aci=-0.8, hiz=34, punto=44),
    ]
    resimler = [
        {"yol": "/assets/img/kasaba/carsi.webp", "t0": kb[0], "t1": kb[0] + 4 * ks, "olcek": [1.05, 1.09], "kay": [0, 0, -14, 0]},
        {"yol": "/assets/img/kasaba/istasyon.webp", "t0": kb[0] + 4 * ks, "t1": kb[0] + 8 * ks, "olcek": [1.09, 1.05], "kay": [-10, 0, 10, 0]},
        {"yol": "/assets/img/kasaba/gece.webp", "t0": kb[0] + 8 * ks, "t1": kb[1], "olcek": [1.04, 1.10], "kay": [0, 0, 0, -8]},
    ]
    kararmalar = [{"t0": son - 0.45, "t1": son, "yon": 1}]
    return {"cekimler": cekimler, "toplam": toplam, "yazilar": yazilar, "resimler": resimler, "kararmalar": kararmalar}


def ff(*arg, **kw):
    r = subprocess.run(["ffmpeg", "-v", "error", "-y", *map(str, arg)], capture_output=True, **kw)
    if r.returncode != 0:
        print(r.stderr.decode("utf-8", "replace")[-2000:])
        raise SystemExit("ffmpeg hatası")
    return r


# --- 1. Taban görüntüsü ---

def taban_yap(plan, kayitlar, cikti):
    girdiler, suzgec, uclar = [], [], []
    for i, c in enumerate(plan["cekimler"]):
        n = c["b"] - c["a"]
        sure = n / FPS
        if c["kayit"] is None:
            girdiler += ["-f", "lavfi", "-t", f"{sure:.4f}", "-i", f"color=c=0x14100c:s=1920x1080:r={FPS}"]
            suzgec.append(f"[{i}:v]trim=end_frame={n},setsar=1,format=yuv420p[v{i}]")
            suzgec.append(f"anullsrc=r={HIZ}:cl=stereo,atrim=duration={sure:.4f}[a{i}]")
        else:
            girdiler += ["-ss", f"{c['ilk'] / FPS:.4f}", "-t", f"{sure + 0.2:.4f}", "-i", kayitlar / (c["kayit"] + ".avi")]
            x, y, w, h = c["kirp"]
            suzgec.append(f"[{i}:v]crop={w}:{h}:{x}:{y},scale=1920:1080:flags=lanczos,setsar=1,fps={FPS},"
                          f"trim=end_frame={n},setpts=PTS-STARTPTS,format=yuv420p[v{i}]")
            suzgec.append(f"[{i}:a]aresample={HIZ},aformat=channel_layouts=stereo,atrim=duration={sure:.4f},asetpts=PTS-STARTPTS,"
                          f"afade=t=in:d=0.012,afade=t=out:st={sure - 0.015:.4f}:d=0.015[a{i}]")
        uclar.append(f"[v{i}][a{i}]")
    suzgec.append("".join(uclar) + f"concat=n={len(uclar)}:v=1:a=1[v][a]")
    ff(*girdiler, "-filter_complex", ";".join(suzgec), "-map", "[v]", "-map", "[a]",
       "-c:v", "libx264", "-preset", "fast", "-crf", "8", "-c:a", "pcm_s16le", cikti / "taban.mkv")


# --- 2. Yazı katmanı ---

class Sunucu(http.server.SimpleHTTPRequestHandler):
    plan_metni = b"{}"

    def log_message(self, *a):
        pass

    def do_GET(self):
        if self.path.split("?")[0] == "/plan.json":
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(self.plan_metni)))
            self.end_headers()
            self.wfile.write(self.plan_metni)
            return
        super().do_GET()


async def katman_ciz(ws_adresi, toplam, klasor):
    no = 0
    async with websockets.connect(ws_adresi, max_size=256 * 1024 * 1024) as ws:
        async def gonder(yontem, **p):
            nonlocal no
            no += 1
            await ws.send(json.dumps({"id": no, "method": yontem, "params": p}))
            hedef = no
            while True:
                m = json.loads(await ws.recv())
                if m.get("id") == hedef:
                    if "error" in m:
                        print("CDP hatası:", m["error"])
                    return m.get("result", {})
                if m.get("method") == "Runtime.exceptionThrown":
                    print("SAYFA HATASI", json.dumps(m["params"]["exceptionDetails"])[:400])

        await gonder("Runtime.enable")
        await gonder("Page.enable")
        await gonder("Emulation.setDeviceMetricsOverride", width=1920, height=1080, deviceScaleFactor=1, mobile=False)
        await gonder("Emulation.setDefaultBackgroundColorOverride", color={"r": 0, "g": 0, "b": 0, "a": 0})
        await gonder("Page.navigate", url=f"http://127.0.0.1:{KAPI}/tools/tanitim/katman.html")
        await asyncio.sleep(1.5)
        r = await gonder("Runtime.evaluate", expression="kur()", awaitPromise=True, returnByValue=True)
        print("katman:", r.get("result", {}).get("value"))
        onceki_imza, onceki_veri, cizilen = None, None, 0
        for k in range(toplam):
            r = await gonder("Runtime.evaluate", expression=f"kare({k / FPS:.6f})", returnByValue=True)
            imza = r.get("result", {}).get("value")
            if imza != onceki_imza or onceki_veri is None:
                s = await gonder("Page.captureScreenshot", format="png")
                onceki_veri = base64.b64decode(s["data"])
                onceki_imza = imza
                cizilen += 1
            (klasor / f"{k:05d}.png").write_bytes(onceki_veri)
        print(f"katman: {toplam} kare ({cizilen} ayrı çizim)")


def katman_yap(plan, cikti):
    klasor = cikti / "katman"
    if klasor.exists():
        shutil.rmtree(klasor)
    klasor.mkdir(parents=True)
    Sunucu.plan_metni = json.dumps({k: plan[k] for k in ("yazilar", "resimler", "kararmalar")}, ensure_ascii=False).encode("utf-8")
    sunucu = http.server.ThreadingHTTPServer(("127.0.0.1", KAPI), functools.partial(Sunucu, directory=str(KOK)))
    threading.Thread(target=sunucu.serve_forever, daemon=True).start()
    profil = tempfile.mkdtemp(prefix="nm_tanitim_")
    surec = subprocess.Popen([CHROME, "--headless=new", "--no-first-run", f"--user-data-dir={profil}",
                              f"--remote-debugging-port={HATA_KAPISI}", "--window-size=1920,1080", "--mute-audio",
                              "--hide-scrollbars", "--force-device-scale-factor=1", "about:blank"],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        ws = ""
        for _ in range(40):
            try:
                with urllib.request.urlopen(f"http://127.0.0.1:{HATA_KAPISI}/json", timeout=2) as y:
                    s = [x for x in json.load(y) if x.get("type") == "page"]
                if s:
                    ws = s[0]["webSocketDebuggerUrl"]
                    break
            except Exception:
                pass
            time.sleep(0.5)
        if not ws:
            raise SystemExit("Chrome'a bağlanılamadı")
        asyncio.run(katman_ciz(ws, plan["toplam"], klasor))
    finally:
        surec.terminate()
        try:
            surec.wait(timeout=10)
        except subprocess.TimeoutExpired:
            surec.kill()
        sunucu.shutdown()
        shutil.rmtree(profil, ignore_errors=True)


# --- 3. Ses ---

def ses_oku(yol, bas=None, sure=None):
    arg = []
    if bas is not None:
        arg += ["-ss", f"{bas:.4f}"]
    if sure is not None:
        arg += ["-t", f"{sure:.4f}"]
    ham = subprocess.run(["ffmpeg", "-v", "error", *arg, "-i", str(yol), "-vn", "-ac", "2", "-ar", str(HIZ), "-f", "f32le", "-"],
                         capture_output=True).stdout
    return np.frombuffer(ham, dtype=np.float32).reshape(-1, 2).copy()


def ekle(hedef, parca, an, kazanc=1.0):
    i = int(round(an * HIZ))
    if i >= len(hedef) or i < 0:
        return
    n = min(len(parca), len(hedef) - i)
    hedef[i:i + n] += parca[:n] * kazanc


def ses_yap(plan, cikti):
    toplam_sn = plan["toplam"] / FPS
    mix = np.zeros((int(round(toplam_sn * HIZ)), 2), dtype=np.float32)
    # çekimlerin kendi sesleri (mühür, kâğıt, alarm, daktilo, soba)
    ekle(mix, ses_oku(cikti / "taban.mkv"), 0.0, 0.9)
    # müzik: ana bölümün ilk vuruşu T0'a denk gelir
    muzik_an = T0 - (MUZIK_ILK - MUZIK_GIRIS)
    muzik = ses_oku(KOK / "assets/ses/muzik/harman_dali.ogg", MUZIK_GIRIS, toplam_sn - muzik_an + 0.1)
    giris = int(0.25 * HIZ)
    muzik[:giris] *= np.linspace(0.0, 1.0, giris)[:, None]
    cikis = int(1.4 * HIZ)
    son = int(round((toplam_sn - muzik_an) * HIZ))
    muzik = muzik[:son]
    muzik[-cikis:] *= np.linspace(1.0, 0.0, cikis)[:, None] ** 1.5
    ekle(mix, muzik, muzik_an, 1.25)
    # yazı şeritleri yazılırken daktilo tuşları
    tuslar = [ses_oku(KOK / "assets/ses" / ad) for ad in ("daktilo.wav", "daktilo_2.wav")]
    rng = np.random.default_rng(1984)
    for y in plan["yazilar"]:
        if y.get("hiz", 0) <= 0:
            continue
        i = 0
        for s in y["satirlar"]:
            if s.get("not"):
                continue                      # künye satırı yazılmaz, şeritle birlikte görünür
            for h in s["metin"]:
                if h != " ":
                    an = y["t0"] + y.get("gecikme", 0) + i / y["hiz"]
                    if an < y["t1"]:
                        guc = 0.5 if y["tur"] == "yil" else 0.2
                        ekle(mix, tuslar[int(rng.integers(0, 2))], an, guc * float(rng.uniform(0.8, 1.0)))
                i += 1
    tepe = float(np.abs(mix).max())
    print(f"ses: tepe {20 * np.log10(tepe + 1e-9):.1f} dB")
    if tepe > 0.98:
        mix *= 0.98 / tepe
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(HIZ), "-ac", "2", "-i", "-",
                    "-c:a", "pcm_s16le", str(cikti / "ses.wav")], input=mix.tobytes(), check=True)


# --- 4. Birleştirme ---

def birlestir(plan, cikti):
    sure = plan["toplam"] / FPS
    # ses düzeyi ayrı adımda eşitlenir: tek komutta yapılınca süzgecin gecikmesi yüzünden sesin sonu kesiliyor
    ff("-i", cikti / "ses.wav", "-af", f"loudnorm=I=-15:TP=-1.5:LRA=11,aresample={HIZ}", "-c:a", "pcm_s16le", cikti / "ses_esit.wav")
    ff("-i", cikti / "taban.mkv", "-framerate", FPS, "-i", cikti / "katman" / "%05d.png", "-i", cikti / "ses_esit.wav",
       "-filter_complex", "[0:v][1:v]overlay=format=auto,format=yuv420p[v]",
       "-map", "[v]", "-map", "2:a", "-c:v", "libx264", "-preset", "slow", "-crf", "17", "-pix_fmt", "yuv420p",
       "-profile:v", "high", "-c:a", "aac", "-b:a", "192k", "-ar", HIZ, "-movflags", "+faststart",
       "-t", f"{sure:.4f}", cikti / "tanitim.mp4")
    # kapak karesi: kapanış kartının oturduğu an
    ff("-ss", f"{sure - 1.2:.3f}", "-i", cikti / "tanitim.mp4", "-frames:v", "1", "-q:v", "2", cikti / "tanitim_kapak.jpg")


def main():
    kayitlar, cikti = Path(sys.argv[1]), Path(sys.argv[2])
    adimlar = sys.argv[3].split(",") if len(sys.argv) > 3 else ["taban", "katman", "ses", "birlestir"]
    cikti.mkdir(parents=True, exist_ok=True)
    plan = plan_kur()
    print(f"film: {plan['toplam']} kare, {plan['toplam'] / FPS:.2f} sn")
    for c in plan["cekimler"]:
        print(f"  {c['ad']:<10} {c['a'] / FPS:6.2f} - {c['b'] / FPS:6.2f} sn  ({c['b'] - c['a']} kare)")
    (cikti / "plan.json").write_text(json.dumps(plan, ensure_ascii=False, indent=1), encoding="utf-8")
    if "taban" in adimlar:
        taban_yap(plan, kayitlar, cikti)
    if "katman" in adimlar:
        katman_yap(plan, cikti)
    if "ses" in adimlar:
        ses_yap(plan, cikti)
    if "birlestir" in adimlar:
        birlestir(plan, cikti)
        print("yazıldı:", cikti / "tanitim.mp4")


if __name__ == "__main__":
    main()
