"""Web yapısını gerçek bir tarayıcıda dener: build/web klasörünü yerelde sunar, başsız Chrome'da açar,
ana menünün ve ilk günün ekran görüntüsünü alır, tarayıcı konsolundaki hataları yazar.

Pencere açılmaz (başsız kip, ayrı ve geçici bir profil). Görüntüler tools/cikti/web_*.png olur.

Kullanım: python tools/web_dene.py        (önce: bash tools/disa_aktar.sh)
Gerekenler: Google Chrome, Python "websockets" paketi.
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

import websockets

KOK = Path(__file__).resolve().parents[1]
WEB = KOK / "build" / "web"
CIKTI = KOK / "tools" / "cikti"
KAPI = 8765
HATA_AYIKLAMA_KAPISI = 9333
CHROME_YOLLARI = [
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
    "/usr/bin/google-chrome", "/usr/bin/chromium",
]


class Sessiz(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *a) -> None:
        pass


async def calistir(ws_adresi: str) -> int:
    konsol = []
    no = 0
    async with websockets.connect(ws_adresi, max_size=64 * 1024 * 1024) as ws:
        bekleyen = {}

        async def gonder(yontem: str, **parametreler):
            nonlocal no
            no += 1
            await ws.send(json.dumps({"id": no, "method": yontem, "params": parametreler}))
            hedef = no
            while True:
                m = json.loads(await ws.recv())
                if m.get("id") == hedef:
                    return m.get("result", {})
                olay(m)

        def olay(m: dict) -> None:
            y = m.get("method", "")
            if y == "Runtime.consoleAPICalled":
                metin = " ".join(str(a.get("value", a.get("description", ""))) for a in m["params"]["args"])
                konsol.append((m["params"]["type"], metin))
            elif y == "Runtime.exceptionThrown":
                konsol.append(("exception", json.dumps(m["params"]["exceptionDetails"])[:400]))
            elif y == "Log.entryAdded":
                e = m["params"]["entry"]
                konsol.append((e.get("level", "log"), e.get("text", "")))

        async def bekle(saniye: float) -> None:
            bitis = time.time() + saniye
            while time.time() < bitis:
                try:
                    olay(json.loads(await asyncio.wait_for(ws.recv(), timeout=max(0.05, bitis - time.time()))))
                except asyncio.TimeoutError:
                    pass

        async def cek(ad: str) -> None:
            sonuc = await gonder("Page.captureScreenshot", format="png")
            (CIKTI / f"{ad}.png").write_bytes(base64.b64decode(sonuc["data"]))
            print("çekildi:", CIKTI / f"{ad}.png")

        async def tikla(x: float, y: float) -> None:
            for tur in ("mousePressed", "mouseReleased"):
                await gonder("Input.dispatchMouseEvent", type=tur, x=x, y=y, button="left", clickCount=1)

        await gonder("Runtime.enable")
        await gonder("Log.enable")
        await gonder("Page.enable")
        await gonder("Emulation.setDeviceMetricsOverride", width=1280, height=720, deviceScaleFactor=1, mobile=False)
        await gonder("Page.navigate", url=f"http://127.0.0.1:{KAPI}/index.html")
        await bekle(22.0)                     # wasm derlenir, paket açılır, başlık yazılır
        await cek("web_1_menu")
        await tikla(133, 209)                 # "Yeni Oyun"
        await bekle(7.0)
        await cek("web_2_sabah")
        await tikla(909, 601)                 # "Gişeyi Aç" (4. günden önce genelge ortada değil: 1. günde gazete var)
        await bekle(6.0)
        await cek("web_3_masa")

    hatalar = [k for k in konsol if k[0] in ("error", "exception")]
    print(f"konsol: {len(konsol)} satır, {len(hatalar)} hata")
    for tur, metin in konsol[:40]:
        print(f"  [{tur}] {metin[:200]}")
    return len(hatalar)


def main() -> int:
    if not (WEB / "index.html").exists():
        print("build/web yok; önce: bash tools/disa_aktar.sh")
        return 2
    chrome = next((p for p in CHROME_YOLLARI if Path(p).exists()), shutil.which("chrome"))
    if not chrome:
        print("Chrome bulunamadı")
        return 2
    CIKTI.mkdir(parents=True, exist_ok=True)
    sunucu = http.server.ThreadingHTTPServer(("127.0.0.1", KAPI), functools.partial(Sessiz, directory=str(WEB)))
    threading.Thread(target=sunucu.serve_forever, daemon=True).start()
    profil = tempfile.mkdtemp(prefix="nm_chrome_")
    surec = subprocess.Popen([chrome, "--headless=new", "--no-first-run", f"--user-data-dir={profil}",
                              f"--remote-debugging-port={HATA_AYIKLAMA_KAPISI}", "--use-angle=swiftshader",
                              "--enable-unsafe-swiftshader", "--window-size=1280,720", "--mute-audio",
                              "--autoplay-policy=no-user-gesture-required", "about:blank"],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        ws_adresi = ""
        for _ in range(40):
            try:
                with urllib.request.urlopen(f"http://127.0.0.1:{HATA_AYIKLAMA_KAPISI}/json", timeout=2) as y:
                    sayfalar = [s for s in json.load(y) if s.get("type") == "page"]
                if sayfalar:
                    ws_adresi = sayfalar[0]["webSocketDebuggerUrl"]
                    break
            except Exception:
                pass
            time.sleep(0.5)
        if not ws_adresi:
            print("Chrome'a bağlanılamadı")
            return 2
        return 1 if asyncio.run(calistir(ws_adresi)) > 0 else 0
    finally:
        surec.terminate()
        try:
            surec.wait(timeout=10)
        except subprocess.TimeoutExpired:
            surec.kill()
        sunucu.shutdown()
        shutil.rmtree(profil, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
