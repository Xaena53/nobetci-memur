"""Betiklerdeki biçimli ve elle çizilen Türkçe metinleri `Dil.c()` ile sarar.

Label ve Button metinleri kendiliğinden çevrilir; ama `"%d. GÜN" % gun` gibi biçimli metinlerde ekrana
çıkan sonuç sözlükteki anahtarla eşleşmez. Bu betik şu kalıpları bulur ve sarar:
  1. "…%s…" % …                 → Dil.c("…%s…") % …
  2. draw_string(…, "metin", …) → draw_string(…, Dil.c("metin"), …)
  3. "metin" + …  ve  … + "metin" (insan metni olan dizgiler)
Zaten sarılmış olanlara, `const` satırlarına (sabitlerde işlev çağrılamaz), yorumlara, yollara ve düğüm
adlarına dokunmaz. Değişen satırları yazdırır; `--yaz` verilmezse dosyalara dokunmaz.

Kullanım: python tools/dil/sar.py [--yaz]
"""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from cikar import DIZGI, KOK, SATIR_YORUMU, insan_metni  # noqa: E402

ATLA = re.compile(r"\.name\s*=|get_node|find_child|has_method|push_error|push_warning|printerr|print\(|assert\(|set_meta|get_meta|has_meta|load\(|preload\(|\.connect\(|emit\(")


## Art arda eklenen iki dizgi: "a" + "b" (araya satır sonu girebilir)
BIRLESIK = re.compile(r'"((?:[^"\\]|\\.)*)"[ \t]*\n?[ \t]*\+[ \t]*\n?[ \t]*"((?:[^"\\]|\\.)*)"')


def birlestir(metin: str) -> str:
    """Art arda eklenen dizgileri tek dizgi yapar: cümle, çeviride tek anahtar olarak kalsın."""
    while True:
        yeni = BIRLESIK.sub(lambda m: '"' + m.group(1) + m.group(2) + '"', metin)
        if yeni == metin:
            return metin
        metin = yeni


def sar(satir: str) -> str:
    govde = satir
    yorum = ""
    m = SATIR_YORUMU.search(satir)
    if m:
        govde, yorum = satir[:m.start()], satir[m.start():]
    if govde.strip().startswith(("#", "const ")) or ATLA.search(govde):
        return satir
    cikti = []
    son = 0
    for m in DIZGI.finditer(govde):
        ham = m.group(1)
        metin = ham.replace("\\n", "\n").replace('\\"', '"')
        once = govde[:m.start()]
        sonra = govde[m.end():]
        sarili = once.rstrip().endswith(("Dil.c(", "Dil.buyuk(", "Dil.kucuk(", "Stil.buyuk(", "Stil.kucuk("))
        bicimli = re.match(r"\s*%\s", sonra) is not None and "%" in ham
        birlesik = re.match(r"\s*\+", sonra) is not None or re.search(r"\+\s*$", once) is not None
        # tek sözcüklük düz ASCII önek ("Zorluk" + kod) düğüm adı kurar: çevrilmez
        if birlesik and re.fullmatch(r"[A-Za-z_]+", ham):
            birlesik = False
        cizim = re.search(r"draw_(multiline_)?string\([^)]*$", once) is not None
        # sözlük anahtarı (":" ile biten ya da "[" içinde) çevrilmez
        anahtar = re.match(r"\s*[:\]]", sonra) is not None and not birlesik
        if insan_metni(metin) and not sarili and not anahtar and (bicimli or birlesik or cizim):
            cikti.append(govde[son:m.start()] + 'Dil.c("' + ham + '")')
            son = m.end()
    cikti.append(govde[son:])
    return "".join(cikti) + yorum


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    yaz = "--yaz" in sys.argv
    toplam = 0
    for f in sorted((KOK / "scripts").rglob("*.gd")):
        if f.name in ("Dil.gd", "UreticiTesti.gd"):
            continue
        asil = f.read_text(encoding="utf-8")
        satirlar = asil.split("\n")
        birlesik_metin = birlestir(asil)
        if birlesik_metin != asil:
            print(f"{f.name}: art arda dizgiler birleştirildi")
            satirlar = birlesik_metin.split("\n")
            if yaz:
                f.write_text(birlesik_metin, encoding="utf-8", newline="\n")
        yeni = [sar(s) for s in satirlar]
        degisen = [(i + 1, a, b) for i, (a, b) in enumerate(zip(satirlar, yeni)) if a != b]
        toplam += len(degisen)
        if degisen and not yaz:
            for no, _a, b in degisen:
                print(f"{f.name}:{no}: {b.strip()[:150]}")
        if degisen and yaz:
            f.write_text("\n".join(yeni), encoding="utf-8", newline="\n")
    print(f"{toplam} satır {'sarıldı' if yaz else 'sarılacak'}")


if __name__ == "__main__":
    main()
