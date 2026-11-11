"""Ölçüm yardımcısı: 1280x720 görselden bir bölgeyi büyütüp cetvel ızgarasıyla kaydeder.
Kullanım: python olc.py <girdi> <x0> <y0> <x1> <y1> <çıktı> [büyütme]
"""
import sys
from PIL import Image, ImageDraw, ImageFont

girdi, x0, y0, x1, y1, cikti = sys.argv[1], *map(int, sys.argv[2:6]), sys.argv[6]
z = int(sys.argv[7]) if len(sys.argv) > 7 else 3
im = Image.open(girdi).convert("RGB").crop((x0, y0, x1, y1))
im = im.resize((im.width * z, im.height * z), Image.LANCZOS)
d = ImageDraw.Draw(im)
try:
    f = ImageFont.truetype("arial.ttf", 11)
except OSError:
    f = ImageFont.load_default()
for x in range((x0 // 10) * 10, x1 + 1, 10):
    if x < x0:
        continue
    px = (x - x0) * z
    buyuk = x % 50 == 0
    d.line([px, 0, px, im.height], fill=(255, 255, 0) if buyuk else (255, 255, 255), width=1)
    if x % 20 == 0:
        d.text((px + 2, 2), str(x), fill=(255, 255, 0), font=f, stroke_width=2, stroke_fill=(0, 0, 0))
for y in range((y0 // 10) * 10, y1 + 1, 10):
    if y < y0:
        continue
    py = (y - y0) * z
    buyuk = y % 50 == 0
    d.line([0, py, im.width, py], fill=(255, 255, 0) if buyuk else (255, 255, 255), width=1)
    if y % 20 == 0:
        d.text((2, py + 2), str(y), fill=(0, 255, 255), font=f, stroke_width=2, stroke_fill=(0, 0, 0))
im.save(cikti)
print(cikti, im.size)
