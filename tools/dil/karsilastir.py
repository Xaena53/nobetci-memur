"""Çevrilmeden kalan metinleri bulur: aynı çekim senaryolarını Türkçe ve başka bir dilde çalıştırıp
ekrandaki yazıları karşılaştırır.

Her senaryo `bash tools/cek.sh <senaryo> dil=<kod> metinler=1` ile çalıştırılır; çekim sürücüsü her
karede görünen bütün Label ve Button metinlerini döker. İki dilde de aynı görünen, içinde harf bulunan
metinler çevrilmemiş sayılır. Çevrilmiş koşuda alanına sığmayan tek satırlık yazılar da dökülür. Kişi ve yer adları, belge numaraları gibi doğal olarak aynı kalanlar da
listeye girer; onlar gözle ayıklanır (IZINLI ile başlayanlar kendiliğinden atlanır).

Kullanım: python tools/dil/karsilastir.py <dil> [senaryo ...]
"""
import os
import re
import subprocess
import sys
from pathlib import Path

KOK = Path(__file__).resolve().parents[2]
SENARYOLAR = ["akis", "masa", "hikaye", "rontgen", "defter", "sinir", "genelge", "ayarlar", "ev", "eller", "ara"]
HARF = re.compile(r"[A-Za-zçğıöşüÇĞİÖŞÜ]{3}")
## Çevrilmesi beklenmeyenler: numaralar, tuş adları, dil adları
## Windows'ta düz "bash" WSL'e gidebilir: Git Bash'in kendisi kullanılır (EXEPATH onun klasörüdür)
_git_bash = Path(os.environ.get("EXEPATH", "")) / "bash.exe"
KABUK = str(_git_bash) if _git_bash.exists() else "bash"
IZINLI = re.compile(r"^(ÇV-|[A-Z]-\d|ESC|ENTER|F\d+|\[?(Türkçe|English|Русский)\]?|T\.C\.|TL|ALARM)")


TASANLAR = set()        # çevrilmiş koşuda alanına sığmayan yazılar


def dokum(dil: str, senaryo: str) -> set:
    cikti = subprocess.run([KABUK, "tools/cek.sh", senaryo, f"dil={dil}", "metinler=1"], cwd=KOK, capture_output=True,
                           text=True, encoding="utf-8", errors="replace", timeout=900).stdout
    for satir in cikti.splitlines():
        if "SCRIPT ERROR" in satir or satir.startswith("ERROR"):
            print("  !!", satir[:160])
    if dil != "tr":
        TASANLAR.update(s.split("] ", 1)[1].strip() for s in cikti.splitlines() if "  TAS [" in s)
    return {s.split("TXT ", 1)[1].strip() for s in cikti.splitlines() if "  TXT " in s}


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    dil = sys.argv[1]
    senaryolar = sys.argv[2:] or SENARYOLAR
    ayni = set()
    for s in senaryolar:
        tr = dokum("tr", s)
        diger = dokum(dil, s)
        ortak = {m for m in tr & diger if HARF.search(m) and not IZINLI.search(m)}
        print(f"{s}: Türkçe {len(tr)} metin, {dil} {len(diger)} metin, aynı kalan {len(ortak)}", flush=True)
        ayni |= ortak
    print(f"--- iki dilde de aynı görünen {len(ayni)} metin ---")
    for m in sorted(ayni):
        print(m[:140])
    print(f"--- alanına sığmayan {len(TASANLAR)} yazı ---")
    for m in sorted(TASANLAR):
        print(m[:160])


if __name__ == "__main__":
    main()
