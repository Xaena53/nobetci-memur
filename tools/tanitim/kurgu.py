# -*- coding: utf-8 -*-
"""Tanıtım filminin kurgusu.

Kullanım:  python tools/tanitim/kurgu.py <kayıt klasörü> <çıktı klasörü> [bicim=yatay|dikey] [dil=tr|en] [adim=taban,katman,ses,birlestir]

Kayıt klasöründe `bash tools/tanitim/cek.sh <sahne> <klasör>` ile alınmış gise, rontgen, ev ve menu
kayıtları bulunmalıdır. Betik sırasıyla:
  1. çekimleri müziğin vuruşlarına göre kesip tek bir taban görüntüsü yapar (ffmpeg),
  2. yazı katmanını başsız Chrome'da kare kare çizer (katman.html; pencere açılmaz),
  3. müziği, çekimlerin kendi seslerini ve daktilo tuşlarını karıştırır,
  4. hepsini birleştirip tanitim.mp4 ve kapak karesini yazar.

Biçimler: yatay 1920x1080; dikey 1080x1920 (çekimler 4:5 kırpılır, yazılar Instagram'ın alt ve üst
arayüzünün dışında kalan alana oturur).

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
ZEMIN = "0x1a1613"               # çekimlerin dışında kalan alanın rengi

# --- Müzik ızgarası (sayılar harman_dali.ogg ölçümünden gelir) ---
VURUS = 0.2894                   # sekizlik vuruş aralığı (sn)
MUZIK_ILK = 11.076               # ana bölümün ilk vuruşu (parçadaki an)
MUZIK_GIRIS = 9.5                # parçadan alınan ilk an (ana bölümden önceki kısa giriş)
T0 = 3.8                         # ana bölümün filmdeki başlangıcı: ondan öncesi açılış
SON_SURE = 5.0                   # kapanış kartının süresi

# Kayıtlar 1872x1053'tür. Kırpma: (x, y, en, boy).
TAM = (0, 0, 1872, 1053)
SOL_UST = (0, 0, 1536, 864)
SOL_ALT = (0, 189, 1536, 864)

# Çekimler: (ad, kayıt, kayıttaki işaret, işaretten sonraki kare, başlangıç vuruşu, bitiş vuruşu)
# İlk kare kaydın <sahne>.json dosyasındaki işarete göre bulunur: yeniden çekilen kayıtta kaymaz.
CEKIMLER = [
    ("acilis", "menu", "bos", 24, None, 0),
    ("gise", "gise", "acilis", 15, 0, 8),
    ("inceleme", "gise", "inceleme", 13, 8, 20),
    ("muhur_al", "gise", "muhur_al", 2, 20, 24),
    ("muhur", "gise", "muhur", -9, 24, 28),         # darbe bir vuruş sonra iner
    ("rontgen", "rontgen", "ekran", 22, 28, 34),
    ("alarm", "rontgen", "alarm", -9, 34, 40),
    ("kolluk", "rontgen", "alarm", 52, 40, 44),
    ("ev", "ev", "basla", 15, 44, 56),
    ("kasaba", None, "", 0, 56, 70),
    ("kapanis", "menu", "baslik", -11, 70, None),
]

# Her biçimde çekimin tuvale nasıl yerleştiği: [(kırpma, hedef dikdörtgen), ...]
YATAY = {"tuval": (1920, 1080), "alan": (0, 0, 1920, 1080)}
YATAY["parcalar"] = {
    "acilis": [(TAM, YATAY["alan"])], "gise": [(SOL_UST, YATAY["alan"])], "inceleme": [(SOL_ALT, YATAY["alan"])],
    "muhur_al": [(SOL_ALT, YATAY["alan"])], "muhur": [(SOL_ALT, YATAY["alan"])], "rontgen": [(TAM, YATAY["alan"])],
    "alarm": [(TAM, YATAY["alan"])], "kolluk": [(SOL_UST, YATAY["alan"])], "ev": [(TAM, YATAY["alan"])],
    "kapanis": [(TAM, YATAY["alan"])],
}
# Dikeyde çekim alanı 1080x1350'dir (4:5); üstte başlık, altta Instagram arayüzüne ayrılan boşluk kalır.
DIKEY = {"tuval": (1080, 1920), "alan": (0, 200, 1080, 1350)}
_SOL = (0, 0, 842, 1053)
_BELGE = (105, 0, 842, 1053)
_MUHUR = (250, 53, 800, 1000)
_CIHAZ = (140, 0, 842, 1053)
DIKEY["parcalar"] = {
    "acilis": [((600, 0, 842, 1053), DIKEY["alan"])], "gise": [(_SOL, DIKEY["alan"])], "inceleme": [(_BELGE, DIKEY["alan"])],
    "muhur_al": [(_MUHUR, DIKEY["alan"])], "muhur": [(_MUHUR, DIKEY["alan"])], "rontgen": [(_CIHAZ, DIKEY["alan"])],
    "alarm": [(_CIHAZ, DIKEY["alan"])], "kolluk": [(_SOL, DIKEY["alan"])],
    # ev: üstte oda (aile ve soba), altta akşam defteri
    "ev": [((0, 450, 1130, 516), (0, 200, 1080, 493)), ((1140, 60, 668, 530), (0, 693, 1080, 857))],
    "kapanis": [(_SOL, DIKEY["alan"])],
}
BICIMLER = {"yatay": YATAY, "dikey": DIKEY}


def v(k):
    """k. vuruşun filmdeki kare numarası."""
    return round((T0 + k * VURUS) * FPS)


def serit(t0, t1, x, y, satirlar, aci=-1.2, hiz=30, gecikme=0.12, punto=None):
    return {"tur": "serit", "t0": t0, "t1": t1, "x": x, "y": y, "aci": aci, "hiz": hiz, "gecikme": gecikme,
            "punto": punto, "satirlar": [s if isinstance(s, dict) else {"metin": s} for s in satirlar]}


def duz(t0, t1, y, metin, punto, font="Daktilo", renk="#f4efe0", aralik=0):
    """Ortalanmış, yazılmayan düz satır (başlık, künye)."""
    return {"tur": "duz", "t0": t0, "t1": t1, "y": y, "hiz": 0, "punto": punto, "font": font, "renk": renk,
            "aralik": aralik, "satirlar": [{"metin": metin}]}


METINLER = {
    "tr": {"kuyruk": "Kuyruk kapıya kadar uzanıyor.", "kuyruk2": ["Kuyruk kapıya kadar", "uzanıyor."], "gise": "2 numaralı gişe sizin.",
           "oku": "Okuyun. Karşılaştırın.", "karar": "Karar verin.", "canta": "Çantada ne var?", "maas": "Maaş hepsine yetmez.",
           "yedi1": "Yedi iş günü.", "yedi2": "Yedi farklı son.", "oyna": "Tarayıcıda oynayın:",
           "muzik": "Müzik: Harman Dalı · Turku, Nomads of the Silk Road · CC BY 4.0", "kurum": "T.C. ARDIÇLI İLÇESİ NÜFUS MÜDÜRLÜĞÜ"},
    "en": {"kuyruk": "The queue reaches the door.", "kuyruk2": ["The queue reaches", "the door."], "gise": "Window 2 is yours.",
           "oku": "Read. Compare.", "karar": "Decide.", "canta": "What's in the bag?", "maas": "The pay won't cover it all.",
           "yedi1": "Seven working days.", "yedi2": "Seven endings.", "oyna": "Play in your browser:",
           "muzik": "Music: Harman Dalı · Turku, Nomads of the Silk Road · CC BY 4.0", "kurum": "ARDIÇLI DISTRICT REGISTRY OFFICE"},
}


def plan_kur(bicim, dil, kayitlar):
    """Çekimlerin film karelerini ve yazı katmanının planını üretir."""
    b = BICIMLER[bicim]
    m = METINLER[dil]
    KART = [{"metin": m["oyna"], "kucuk": True}, {"metin": "xaena53.github.io/nobetci-memur", "vurgu": True},
            {"metin": m["muzik"], "not": True}]
    izler = {}
    cekimler = []
    for ad, kayit, iz, fark, k0, k1 in CEKIMLER:
        ilk = 0
        if kayit is not None:
            if kayit not in izler:
                izler[kayit] = json.loads((kayitlar / (kayit + ".json")).read_text(encoding="utf-8"))
            ilk = int(izler[kayit][iz]) + fark
        bas = 0 if k0 is None else v(k0)
        bit = v(70) + round(SON_SURE * FPS) if k1 is None else v(k1)
        cekimler.append({"ad": ad, "kayit": kayit, "ilk": ilk, "a": bas, "b": bit, "parcalar": b["parcalar"].get(ad, [])})
    toplam = cekimler[-1]["b"]
    z = {c["ad"]: (c["a"] / FPS, c["b"] / FPS) for c in cekimler}
    son = toplam / FPS
    kb = z["kasaba"]
    ks = (kb[1] - kb[0]) / 14.0          # kasaba bölümünde bir vuruş
    kp = z["kapanis"][0]
    kasaba = [("carsi", kb[0], kb[0] + 4 * ks, [1.05, 1.09], [0, 0, -14, 0]),
              ("istasyon", kb[0] + 4 * ks, kb[0] + 8 * ks, [1.09, 1.05], [-10, 0, 10, 0]),
              ("gece", kb[0] + 8 * ks, kb[1], [1.04, 1.10], [0, 0, 0, -8])]

    if bicim == "yatay":
        odak = {"carsi": "50% 50%", "istasyon": "50% 50%", "gece": "50% 50%"}
        yazilar = [
            {"tur": "yil", "t0": 0.35, "t1": z["acilis"][1], "x": 430, "y": 300, "hiz": 5.5, "gecikme": 0.0,
             "satirlar": [{"metin": "1984"}]},
            serit(1.35, z["acilis"][1], 545, 985, [m["kuyruk"]], punto=54),
            serit(z["gise"][0] + 0.1, z["gise"][1], 960, 968, [m["gise"]], aci=1.0),
            serit(z["inceleme"][0] + 0.1, z["inceleme"][1], 1330, 968, [m["oku"]]),
            serit(z["muhur_al"][0] + 0.05, z["muhur"][1], 1420, 968, [m["karar"]], aci=1.2),
            serit(z["rontgen"][0] + 0.1, z["alarm"][1], 1400, 915, [m["canta"]], aci=-1.6),
            serit(z["ev"][0] + 0.15, z["ev"][1], 1500, 775, [m["maas"]], aci=-2.0, punto=46 if len(m["maas"]) <= 20 else 38),
            serit(kb[0] + 0.08, kb[0] + 8 * ks, 960, 930, [m["yedi1"]], aci=-1.0, punto=76),
            serit(kb[0] + 8 * ks + 0.05, kb[1], 960, 930, [{"metin": m["yedi2"], "vurgu": True}], aci=1.0, punto=76),
            serit(kp + 2.25, son, 470, 792, KART, aci=-0.8, hiz=34, punto=44),
        ]
    else:
        odak = {"carsi": "42% 50%", "istasyon": "68% 50%", "gece": "40% 50%"}
        yazilar = [
            duz(0, son, 66, m["kurum"], 25, font="Serif", renk="#b9ad92", aralik=2),
            duz(0, son, 100, "NÖBETÇİ MEMUR", 74),
            duz(0, son, 1606, "xaena53.github.io/nobetci-memur", 30, renk="#8d8371"),
            {"tur": "yil", "t0": 0.35, "t1": z["acilis"][1], "x": 300, "y": 365, "hiz": 5.5, "gecikme": 0.0, "punto": 230,
             "satirlar": [{"metin": "1984"}]},
            serit(1.35, z["acilis"][1], 520, 1440, m["kuyruk2"], punto=54),
            serit(z["gise"][0] + 0.1, z["gise"][1], 520, 1470, [m["gise"]], aci=1.0, punto=54),
            serit(z["inceleme"][0] + 0.1, z["inceleme"][1], 520, 1470, [m["oku"]], punto=54),
            serit(z["muhur_al"][0] + 0.05, z["muhur"][1], 520, 1470, [m["karar"]], aci=1.2, punto=58),
            serit(z["rontgen"][0] + 0.1, z["alarm"][1], 560, 778, [m["canta"]], aci=-1.6, punto=54),
            serit(z["ev"][0] + 0.15, z["ev"][1], 540, 668, [m["maas"]], aci=-1.4, punto=52),
            serit(kb[0] + 0.08, kb[0] + 8 * ks, 520, 1400, [m["yedi1"]], aci=-1.0, punto=66),
            serit(kb[0] + 8 * ks + 0.05, kb[1], 520, 1400, [{"metin": m["yedi2"], "vurgu": True}], aci=1.0, punto=66),
            serit(kp + 2.25, son, 520, 1130, KART, aci=-0.8, hiz=34, punto=40),
        ]
    resimler = [{"yol": f"/assets/img/kasaba/{ad}.webp", "t0": t0, "t1": t1, "olcek": olcek, "kay": kay,
                 "kutu": list(b["alan"]), "odak": odak[ad]} for ad, t0, t1, olcek, kay in kasaba]
    kararmalar = [{"t0": son - 0.45, "t1": son, "yon": 1}]
    return {"bicim": bicim, "tuval": list(b["tuval"]), "cekimler": cekimler, "toplam": toplam, "yazilar": yazilar,
            "resimler": resimler, "kararmalar": kararmalar}


def ff(*arg, **kw):
    r = subprocess.run(["ffmpeg", "-v", "error", "-y", *map(str, arg)], capture_output=True, **kw)
    if r.returncode != 0:
        print(r.stderr.decode("utf-8", "replace")[-2000:])
        raise SystemExit("ffmpeg hatası")
    return r


# --- 1. Taban görüntüsü ---

def taban_yap(plan, kayitlar, cikti):
    en, boy = plan["tuval"]
    girdiler, suzgec, uclar = [], [], []
    for i, c in enumerate(plan["cekimler"]):
        n = c["b"] - c["a"]
        sure = n / FPS
        if c["kayit"] is None:
            girdiler += ["-f", "lavfi", "-t", f"{sure:.4f}", "-i", f"color=c={ZEMIN}:s={en}x{boy}:r={FPS}"]
            suzgec.append(f"[{i}:v]trim=end_frame={n},setsar=1,format=yuv420p[v{i}]")
            suzgec.append(f"anullsrc=r={HIZ}:cl=stereo,atrim=duration={sure:.4f}[a{i}]")
        else:
            girdiler += ["-ss", f"{c['ilk'] / FPS:.4f}", "-t", f"{sure + 0.2:.4f}", "-i", kayitlar / (c["kayit"] + ".avi")]
            p = c["parcalar"]
            suzgec.append(f"[{i}:v]fps={FPS},trim=end_frame={n},setpts=PTS-STARTPTS,split={len(p)}" + "".join(f"[k{i}_{j}]" for j in range(len(p))))
            suzgec.append(f"color=c={ZEMIN}:s={en}x{boy}:r={FPS},trim=end_frame={n}[z{i}_0]")
            for j, (kirp, hedef) in enumerate(p):
                x, y, w, h = kirp
                hx, hy, hw, hh = hedef
                suzgec.append(f"[k{i}_{j}]crop={w}:{h}:{x}:{y},scale={hw}:{hh}:flags=lanczos,setsar=1[p{i}_{j}]")
                suzgec.append(f"[z{i}_{j}][p{i}_{j}]overlay={hx}:{hy}:shortest=1[z{i}_{j + 1}]")
            suzgec.append(f"[z{i}_{len(p)}]format=yuv420p[v{i}]")
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


async def katman_ciz(ws_adresi, plan, klasor):
    no = 0
    en, boy = plan["tuval"]
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
        await gonder("Emulation.setDeviceMetricsOverride", width=en, height=boy, deviceScaleFactor=1, mobile=False)
        await gonder("Emulation.setDefaultBackgroundColorOverride", color={"r": 0, "g": 0, "b": 0, "a": 0})
        await gonder("Page.navigate", url=f"http://127.0.0.1:{KAPI}/tools/tanitim/katman.html")
        await asyncio.sleep(1.5)
        r = await gonder("Runtime.evaluate", expression="kur()", awaitPromise=True, returnByValue=True)
        print("katman:", r.get("result", {}).get("value"))
        onceki_imza, onceki_veri, cizilen = None, None, 0
        for k in range(plan["toplam"]):
            r = await gonder("Runtime.evaluate", expression=f"kare({k / FPS:.6f})", returnByValue=True)
            imza = r.get("result", {}).get("value")
            if imza != onceki_imza or onceki_veri is None:
                s = await gonder("Page.captureScreenshot", format="png")
                onceki_veri = base64.b64decode(s["data"])
                onceki_imza = imza
                cizilen += 1
            (klasor / f"{k:05d}.png").write_bytes(onceki_veri)
        print(f"katman: {plan['toplam']} kare ({cizilen} ayrı çizim)")


def katman_yap(plan, cikti):
    klasor = cikti / "katman"
    if klasor.exists():
        shutil.rmtree(klasor)
    klasor.mkdir(parents=True)
    en, boy = plan["tuval"]
    Sunucu.plan_metni = json.dumps({k: plan[k] for k in ("bicim", "tuval", "yazilar", "resimler", "kararmalar")},
                                   ensure_ascii=False).encode("utf-8")
    sunucu = http.server.ThreadingHTTPServer(("127.0.0.1", KAPI), functools.partial(Sunucu, directory=str(KOK)))
    threading.Thread(target=sunucu.serve_forever, daemon=True).start()
    profil = tempfile.mkdtemp(prefix="nm_tanitim_")
    surec = subprocess.Popen([CHROME, "--headless=new", "--no-first-run", f"--user-data-dir={profil}",
                              f"--remote-debugging-port={HATA_KAPISI}", f"--window-size={en},{boy}", "--mute-audio",
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
        asyncio.run(katman_ciz(ws, plan, klasor))
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
    secenek = dict(a.split("=", 1) for a in sys.argv[3:] if "=" in a)
    bicim = secenek.get("bicim", "yatay")
    dil = secenek.get("dil", "tr")
    adimlar = secenek.get("adim", "taban,katman,ses,birlestir").split(",")
    cikti.mkdir(parents=True, exist_ok=True)
    plan = plan_kur(bicim, dil, kayitlar)
    print(f"film ({bicim}, {dil}): {plan['toplam']} kare, {plan['toplam'] / FPS:.2f} sn")
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
