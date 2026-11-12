"""Ölü kod taraması: hiç çağrılmayan işlevler, yayılmayan ya da bağlanmayan sinyaller, kodun okumadığı veri alanları.

Kullanım: python tools/olu_kod.py        (bulgu yoksa her başlığın altı boş kalır)
Sonuçlar ipucudur: adı metin olarak kurulan çağrılar (call("_bolum_" + ad) gibi) burada görünmez.
"""
import glob
import json
import re
import sys
from pathlib import Path

KOK = Path(__file__).resolve().parents[1]
YERLESIK = {"_ready", "_process", "_draw", "_input", "_gui_input", "_unhandled_input", "_unhandled_key_input",
            "_notification", "_init", "_exit_tree", "_enter_tree", "_physics_process", "_has_point",
            "_get_minimum_size", "_to_string", "_kur"}


def oku(desen: str) -> dict:
    return {Path(f).as_posix(): Path(f).read_text(encoding="utf-8") for f in glob.glob(str(KOK / desen), recursive=True)}


def anahtarlar(v, yol: str, out: dict) -> None:
    if isinstance(v, dict):
        for k, x in v.items():
            out.setdefault(k, set()).add(yol)
            anahtarlar(x, yol, out)
    elif isinstance(v, list):
        for x in v:
            anahtarlar(x, yol, out)


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    kaynak = oku("scripts/**/*.gd")
    hepsi = "\n".join(kaynak.values())
    araclarla = hepsi + "\n".join(oku("tools/*.gd").values())

    print("== hiç çağrılmayan işlevler ==")
    for f, s in kaynak.items():
        for m in re.finditer(r"^(?:static )?func (\w+)\(", s, re.M):
            ad = m.group(1)
            if ad in YERLESIK:
                continue
            if len(re.findall(r"\b" + re.escape(ad) + r"\b", hepsi)) <= 1:
                n = len(re.findall(r"\b" + re.escape(ad) + r"\b", araclarla)) - 1
                print(f"  {Path(f).name}: {ad}" + (f"  (yalnız testlerde, {n} yerde)" if n > 0 else ""))

    print("== yayılmayan ya da bağlanmayan sinyaller ==")
    for f, s in kaynak.items():
        for m in re.finditer(r"^signal (\w+)", s, re.M):
            ad = m.group(1)
            yayim = len(re.findall(r"\b" + ad + r"\.emit\(", hepsi))
            baglanti = len(re.findall(r"\b" + ad + r"\.connect\(", araclarla)) + len(re.findall(r"await [\w.]*\b" + ad + r"\b", araclarla))
            if yayim == 0 or baglanti == 0:
                print(f"  {Path(f).name}: {ad}  (yayım {yayim}, bağlantı {baglanti})")

    print("== kodun okumadığı veri alanları ==")
    out: dict = {}
    for f in glob.glob(str(KOK / "data/**/*.json"), recursive=True):
        d = json.loads(Path(f).read_text(encoding="utf-8"))
        ad = Path(f).name
        if ad == "portreler.json":
            d = list(d.values())[:3]
        anahtarlar(d, ad, out)
    for k, yer in sorted(out.items()):
        if k.startswith("_") or re.fullmatch(r"v\d+|[A-ZÇĞİÖŞÜÂ]+", k):
            continue
        if not re.search(r'["\.]' + re.escape(k) + r"\b", hepsi):
            print(f"  {k}: {sorted(yer)[:3]}")


if __name__ == "__main__":
    main()
