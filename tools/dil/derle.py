"""Çeviri parçalarını (tools/dil/ceviri/*.json) oyunun sözlüklerine derler.

Kaynak listesi tools/dil/kaynak.json dosyasıdır (tools/dil/cikar.py üretir); çeviri parçaları
{"numara": ["İngilizce", "Rusça"]} biçimindedir. Boş çeviri "çevrilmez" demektir (düğüm adı, özel ad).

Çıktı: data/dil/en.json ve data/dil/ru.json  →  {"Türkçe metin": "çevirisi"}

Denetimler (hata varsa sözlük yazılmaz):
  - her kaynak metnin bir kaydı olmalı (çevrilmeyecekse boş);
  - biçim yer tutucuları (%s, %d, %02d …) kaynakla aynı sırada ve sayıda olmalı;
  - satır sonu sayısı kaynakla aynı olmalı (elle bölünmüş, sabit yerleşimli metinler bozulmasın);
  - kaynakta baştaki ve sondaki boşluk çeviride de korunmalı.

Kullanım: python tools/dil/derle.py
"""
import json
import re
import sys
from pathlib import Path

KOK = Path(__file__).resolve().parents[2]
BURASI = Path(__file__).resolve().parent
DILLER = ["en", "ru"]
YER_TUTUCU = re.compile(r"%[-0-9.]*[sdf]")


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    kaynak = json.loads((BURASI / "kaynak.json").read_text(encoding="utf-8"))
    ceviriler = {}
    for f in sorted((BURASI / "ceviri").glob("*.json")):
        for no, cift in json.loads(f.read_text(encoding="utf-8")).items():
            ceviriler[int(no)] = cift
    hatalar = []
    sozlukler = {d: {} for d in DILLER}
    bos = 0
    for e in kaynak:
        no, metin = e["no"], e["metin"]
        if no not in ceviriler:
            hatalar.append(f"{no}: çevirisi yok → {metin[:50]!r}")
            continue
        for i, d in enumerate(DILLER):
            hedef = ceviriler[no][i]
            if hedef == "":
                bos += 1 if i == 0 else 0
                continue
            if YER_TUTUCU.findall(metin) != YER_TUTUCU.findall(hedef):
                hatalar.append(f"{no} [{d}]: yer tutucular farklı → {YER_TUTUCU.findall(metin)} / {YER_TUTUCU.findall(hedef)}")
            if metin.count("\n") != hedef.count("\n"):
                hatalar.append(f"{no} [{d}]: satır sayısı farklı ({metin.count(chr(10))} / {hedef.count(chr(10))})")
            if (metin[:1] == " ") != (hedef[:1] == " ") or (metin[-1:] == " ") != (hedef[-1:] == " "):
                hatalar.append(f"{no} [{d}]: baştaki ya da sondaki boşluk farklı")
            sozlukler[d][metin] = hedef
    artik = sorted(set(ceviriler) - {e["no"] for e in kaynak})
    if hatalar:
        print("\n".join(hatalar))
        raise SystemExit(f"{len(hatalar)} hata; sözlükler yazılmadı")
    hedef_klasor = KOK / "data" / "dil"
    hedef_klasor.mkdir(parents=True, exist_ok=True)
    for d in DILLER:
        (hedef_klasor / f"{d}.json").write_text(json.dumps(sozlukler[d], ensure_ascii=False, indent="\t") + "\n", encoding="utf-8", newline="\n")
        print(f"{d}: {len(sozlukler[d])} metin")
    print(f"{len(kaynak)} kaynak metin; {bos} tanesi çevrilmez (boş); {len(artik)} çeviri artık kullanılmıyor")


if __name__ == "__main__":
    main()
