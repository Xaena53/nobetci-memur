"""Oyundaki çevrilecek metinleri (betiklerdeki ve verideki Türkçe dizgileri) toplar.

Kaynaklar:
  - scripts/**/*.gd  : çift tırnaklı dizgiler (yorum satırları, yollar ve tanımlayıcılar hariç)
  - data/**/*.json   : dizgi değerleri (ATLANAN_DOSYALAR ve ATLANAN_ALANLAR hariç: kişi adları,
                       mahalle ve şehir adları çevrilmez)

Bir dizginin "insan metni" sayılması için: içinde boşluk ve küçük harfli bir sözcük ya da Türkçeye özgü
bir harf bulunmalı, ya da tek sözcüklük bir başlık olmalıdır (Baş harfi büyük ya da tümü büyük).

Çıktı: tools/dil/kaynak.json  →  [{"no": 1, "metin": "...", "yer": "scripts/Masa.gd"}, ...]
Sıra kararlıdır: var olan numaralar korunur, yeni metinler sona eklenir (çeviri dosyaları numarayla eşlenir).

Kullanım: python tools/dil/cikar.py [--ozet]
"""
import json
import re
import sys
from pathlib import Path

KOK = Path(__file__).resolve().parents[2]
CIKTI = Path(__file__).resolve().parent / "kaynak.json"
TURKCE = set("çğıöşüÇĞİÖŞÜâîû")
ATLANAN_DOSYALAR = {"vatandaslar.json", "portreler.json", "varliklar.json", "figur_videolari.json"}
## Verideki bu alanların değerleri çevrilmez (kimlik, yol, kişi ve yer adları).
ATLANAN_ALANLAR = {"ad", "soyad", "baba", "ana", "dogum_yeri", "mahalle", "adres", "muhtar", "portre", "kimlik",
                   "gorsel", "tur", "kod", "alan", "belge", "islem_kodu", "aciklama", "imza", "kategori", "benzer",
                   "karar", "sonuc", "foto", "tarih", "seri", "no", "id", "bayrak", "kosul", "ses", "baba_adi", "ana_adi", "vize_no"}
## "ad" bu dosyalarda kişi adı değil, görünen addır (eşya, kasaba sahnesi)
AD_CEVRILEN = ("esyalar", "ara_ekran")
## adlar.json içinde çevrilecek havuzlar: vatandaşın cümleleri, ülke ve meslek adları
ADLARDAN_ALINAN = {"selam", "selam_yasli", "laf", "onay", "onay_yasli", "eksik", "eksik_yasli", "havale", "alarm",
                   "alarm_bos", "ulkeler", "meslekler"}
HARF = re.compile(r"[A-Za-zçğıöşüÇĞİÖŞÜ]")
KUCUK_SOZCUK = re.compile(r"[a-zçğıöşü]{2}")
BASLIK = re.compile(r"[A-ZÇĞİÖŞÜ][a-zçğıöşüâ]{2,}")
BUYUK = re.compile(r"[A-ZÇĞİÖŞÜ]{3,}")
DIZGI = re.compile(r'"((?:[^"\\]|\\.)*)"')
SATIR_YORUMU = re.compile(r"\s##?\s.*$")


def insan_metni(s: str) -> bool:
    if len(s) < 2 or s.startswith(("res://", "user://")):
        return False
    if not HARF.search(s):
        return False
    if " " in s.strip() and KUCUK_SOZCUK.search(s):
        return True
    # tümü büyük harfli çok sözcüklü başlık (gazete manşeti): ASCII de olsa insan metnidir
    if " " in s.strip() and all(BUYUK.fullmatch(k) or len(k) <= 2 for k in s.split()) and BUYUK.search(s):
        return True
    if any(c in TURKCE for c in s):
        return True
    return bool(BASLIK.fullmatch(s)) or bool(BUYUK.fullmatch(s))


def betik_metinleri() -> dict:
    bulunan = {}
    for f in sorted((KOK / "scripts").rglob("*.gd")):
        if "UreticiTesti" in f.name:
            continue
        for satir in f.read_text(encoding="utf-8").splitlines():
            if satir.strip().startswith("#"):
                continue
            satir = SATIR_YORUMU.sub("", satir)
            # düğüm adları ve çevrilmemesi gereken çağrılar
            if re.search(r"\.name\s*=|get_node|find_child|has_method|push_error|push_warning|printerr|print\(|assert\(|set_meta|get_meta|has_meta", satir):
                continue
            for m in DIZGI.finditer(satir):
                ham = m.group(1)
                metin = ham.replace("\\n", "\n").replace('\\"', '"').replace("\\\\", "\\")
                if insan_metni(metin):
                    bulunan.setdefault(metin, f.relative_to(KOK).as_posix())
    return bulunan


def veri_metinleri() -> dict:
    bulunan = {}

    def gez(v, alan: str, yer: str) -> None:
        if isinstance(v, dict):
            for k, x in v.items():
                gez(x, k.split(".")[-1], yer)
        elif isinstance(v, list):
            for x in v:
                gez(x, alan, yer)
        elif isinstance(v, str) and not alan.startswith("_") and (alan not in ATLANAN_ALANLAR or (alan == "ad" and any(d in yer for d in AD_CEVRILEN))) and insan_metni(v):
            bulunan.setdefault(v, f"{yer}:{alan}")

    for f in sorted((KOK / "data").rglob("*.json")):
        if f.name in ATLANAN_DOSYALAR or f.parent.name == "dil":
            continue
        veri = json.loads(f.read_text(encoding="utf-8"))
        if f.name == "adlar.json":
            veri = {k: v for k, v in veri.items() if k in ADLARDAN_ALINAN}
        gez(veri, "", f.relative_to(KOK).as_posix())
    return bulunan


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    betik = betik_metinleri()
    veri = veri_metinleri()
    hepsi = dict(betik)
    for k, v in veri.items():
        hepsi.setdefault(k, v)
    # kuralın yakalayamadığı kısa sözcükler (küçük harfli tek sözcük, kesme işaretli ad) elle eklenir
    ek = Path(__file__).resolve().parent / "ek_metinler.json"
    if ek.exists():
        for k in json.loads(ek.read_text(encoding="utf-8")):
            hepsi.setdefault(k, "tools/dil/ek_metinler.json")
    if "--ozet" in sys.argv:
        from collections import Counter
        sayac = Counter(v.split(":")[0] for v in hepsi.values())
        for yer, adet in sorted(sayac.items(), key=lambda x: -x[1]):
            print(f"{adet:5d}  {yer}")
        print(f"toplam {len(hepsi)} metin, {sum(len(k) for k in hepsi)} harf (betik {len(betik)}, veri {len(veri)})")
        return
    eski = json.loads(CIKTI.read_text(encoding="utf-8")) if CIKTI.exists() else []
    bilinen = {e["metin"]: e["no"] for e in eski}
    sonraki = max(bilinen.values(), default=0) + 1
    liste = []
    for metin, yer in hepsi.items():
        if metin in bilinen:
            liste.append({"no": bilinen[metin], "metin": metin, "yer": yer})
        else:
            liste.append({"no": sonraki, "metin": metin, "yer": yer})
            sonraki += 1
    liste.sort(key=lambda e: e["no"])
    artik = sorted(set(bilinen) - set(hepsi))
    CIKTI.write_text(json.dumps(liste, ensure_ascii=False, indent=1) + "\n", encoding="utf-8", newline="\n")
    print(f"{len(liste)} metin yazıldı ({len(liste) - len([e for e in liste if e['metin'] in bilinen])} yeni, {len(artik)} artık kullanılmıyor)")


if __name__ == "__main__":
    main()
