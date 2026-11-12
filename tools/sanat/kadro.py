"""Vatandaş kadrosu: havuzdaki her yüze kalıcı bir kimlik (ad, soyad, ana-baba adı, doğum yeri ve
tarihi) atar ve imza sayfalarının sırasını üretir.

Aynı yüz her oyunda aynı kişidir: adı, soyadı ve imzası değişmez. Hikâye karakterlerinin kimliği
data/karakterler.json içindedir; burada yalnızca imza listesine girerler.

Çıktı: data/vatandaslar.json            Kullanım: python tools/sanat/kadro.py
"""
import json
import random
from pathlib import Path

KOK = Path(__file__).resolve().parents[2]

# havuz_e.png: sonradan eklenen 25 kişi (5x5), satır satır: cinsiyet + yaş
YENI_HAVUZ = "E52 K33 E24 K67 E41 K27 E63 K45 E30 K58 E19 K38 E47 K22 E71 K50 E35 K73 E56 K30 E44 K41 E28 K62 E66"
ILK_YENI = 65
# hikâyede sabit kimliği olan havuz yüzleri (savcı, bavullu genç, arananlar)
HIKAYE_YUZLERI = {"v07", "v11", "v22", "v27"}
# imzası üretilecek hikâye kişileri (cüzdanlarında yazan adla)
HIKAYE_IMZALARI = ["Hüsnü Karaca", "Nermin Aksu", "Kenan Dalgıç", "İzzet Bakırcı", "Selim Aktuğ", "Nail Duru",
                   "Hikmet Altay", "Halil Toprak", "Münevver Özer", "Muammer Aksu", "Erdal Yıldırım"]
# kimsenin soyadı bunlarla çakışmasın (muhtarlar ve hikâye kişileri)
AYRILMIS_SOYADLAR = {"Aksoy", "Türkmen", "Bozkurt", "Ersoy", "Güneş", "Akın", "Sezer", "Tuna", "Çınar", "Erdem",
                     "Balcı", "Ayaz", "Kökten", "Sarıkaya", "Karaca", "Aksu", "Dalgıç", "Bakırcı", "Aktuğ", "Duru",
                     "Altay", "Toprak", "Özer", "Yaman", "Saraç", "Yıldırım", "Terzi"}
BUYUK = str.maketrans("abcçdefgğhıijklmnoöprsştuüvyzâîû", "ABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZÂÎÛ")


def buyuk(s: str) -> str:
    return s.translate(BUYUK)


def havuz() -> list:
    """[(kimlik, cinsiyet, yaş)]: eski 64 kişi künyeden, yeni 25 kişi YENI_HAVUZ'dan."""
    kunye = json.loads((KOK / "data" / "portreler.json").read_text(encoding="utf-8"))
    liste = []
    for no in range(1, ILK_YENI):
        k = f"v{no:02d}"
        liste.append((k, kunye[k]["cinsiyet"], int(kunye[k]["yas"])))
    for i, kisi in enumerate(YENI_HAVUZ.split()):
        liste.append((f"v{ILK_YENI + i:02d}", kisi[0], int(kisi[1:])))
    return liste


def kimlikler() -> dict:
    adlar = json.loads((KOK / "data" / "adlar.json").read_text(encoding="utf-8"))
    rng = random.Random(1984)
    erkek, kadin = adlar["erkek"][:], adlar["kadin"][:]
    soyad = [s for s in adlar["soyad"] if s not in AYRILMIS_SOYADLAR]
    rng.shuffle(erkek)
    rng.shuffle(kadin)
    rng.shuffle(soyad)
    sonuc = {}
    for kimlik, cins, yas in havuz():
        if kimlik in HIKAYE_YUZLERI:
            continue
        ad = (erkek if cins == "E" else kadin).pop()
        s = soyad.pop()
        ay = rng.randint(1, 12)
        gun = rng.randint(1, 28)
        yil = 1984 - yas - (0 if (ay, gun) <= (1, 9) else 1)      # 9 Ocak 1984'te yaşı tutsun
        sonuc[kimlik] = {
            "ad": buyuk(ad), "soyad": buyuk(s),
            "baba_adi": buyuk(rng.choice(adlar["erkek"])), "ana_adi": buyuk(rng.choice(adlar["kadin"])),
            "dogum_yeri": buyuk(rng.choice(adlar["il"])),
            "dogum_tarihi": f"{gun:02d}.{ay:02d}.{yil}",
            "imza": f"{ad} {s}",
        }
    return sonuc


def imza_sirasi() -> list:
    """İmza sayfalarındaki sıra: önce havuz (kimlik sırasıyla), sonra hikâye kişileri ve vize memuru."""
    k = kimlikler()
    return [k[kimlik]["imza"] for kimlik in sorted(k)] + HIKAYE_IMZALARI + ["J. Hoffmann", "Tarık Ersoy", "A. Keller", "Cevdet"]


def main() -> None:
    k = kimlikler()
    (KOK / "data" / "vatandaslar.json").write_text(
        json.dumps({"_aciklama": "Havuzdaki her yüzün kalıcı kimliği (tools/sanat/kadro.py üretir). 'imza': imza görselinin sahibi; dosyası assets/img/imza/ altındadır.",
                    "kisiler": k}, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8")
    sira = imza_sirasi()
    print(len(k), "kimlik;", len(sira), "imza")
    for i in range(0, len(sira), 25):
        print(f"--- sayfa {i // 25 + 1}")
        for j in range(i, min(i + 25, len(sira)), 5):
            print("   " + "; ".join(sira[j:j + 5]))


if __name__ == "__main__":
    main()
