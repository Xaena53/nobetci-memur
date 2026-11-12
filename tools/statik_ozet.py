"""Statik denetimin çıktısını özetler: her uyarı bir kez, dosya ve satırıyla."""
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")
satirlar = sys.stdin.buffer.read().decode("utf-8", "replace").splitlines()
gorulen = set()
for i, s in enumerate(satirlar):
    m = re.match(r"SCRIPT ERROR: Parse Error: (.*)", s)
    if m and i + 1 < len(satirlar):
        yer = re.search(r"[(](res://[^)]*)[)]", satirlar[i + 1])
        anahtar = (m.group(1), yer.group(1) if yer else "?")
        if anahtar not in gorulen:
            gorulen.add(anahtar)
            print(f"{anahtar[1]}: {anahtar[0].replace(' (Warning treated as error.)', '')}")
    elif s.startswith("STATİK DENETİM") or s.startswith("DERLENMEDİ"):
        print(s)
