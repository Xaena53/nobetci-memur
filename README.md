# Nöbetçi Memur

1984, Ardıçlı İlçesi Nüfus Müdürlüğü. Gişe memurusunuz: gelen vatandaşın evrakını günün
genelgesine göre kontrol eder, **onaylar**, **eksik evrak** diye geri çevirir ya da **amire havale**
edersiniz. Akşam eve dönünce maaşla kira, kömür, ekmek ve okul masrafı arasında seçim yaparsınız.

Evrak kontrolü türünde, Godot 4.3 (GDScript) ile yazılmış 2D bir oyundur. Tüm arayüz Türkçedir.

## Açma ve çalıştırma

1. [Godot 4.3 (standart sürüm)](https://godotengine.org/download/archive/4.3-stable/) indirin.
2. Godot'u açın → **İçe Aktar (Import)** → bu klasördeki `project.godot` dosyasını seçin.
3. İlk açılışta Godot varlıkları içe aktarır (birkaç saniye). Sonra **F5** ile oyunu başlatın.

Komut satırından:

```bash
godot --path . --import      # ilk kurulumda bir kez (varlıkları içe aktarır)
godot --path .               # oyunu başlatır
```

## Klasör yapısı

| Klasör | İçerik |
|---|---|
| `scenes/` | Sahneler: `AnaMenu`, `Masa`, `GunSonu`, `Aile` |
| `scripts/` | GDScript dosyaları. `Oyun.gd` autoload'dur (gün, para, ihtar, kayıt/yükleme, sahne geçişi) |
| `data/` | Günlerin genelgeleri ve karakterler (JSON) |
| `assets/img`, `assets/ses`, `assets/font` | Görseller, sesler, yazı tipleri |
| `tools/` | Geliştirme araçları: duman testi ve ekran görüntüsü düzeneği |

Sahnelerin `.tscn` dosyaları yalnızca kök düğümü ve betiği taşır; arayüz `_ready()` içinde kodla
kurulur. Renkler, yazı tipleri ve kutu stilleri tek yerden, `scripts/Stil.gd` dosyasından gelir.

## Sahne akışı

`Ana Menü → Masa (mesai 09:00–17:00) → Gün Sonu → Aile → ertesi gün Masa`

Her gün başında oyun `user://kayit.json` dosyasına otomatik kaydedilir.

## Testler

```bash
# Oyunu kodla baştan sona yürüten duman testi (pencere açmaz)
godot --headless --path . res://tools/DumanTesti.tscn

# Ekran görüntüsü senaryosu (kareler tools/cikti/ altına yazılır)
bash tools/cek.sh akis
```

## Yazı tipleri

`assets/font/` altındaki Courier Prime, Old Standard TT ve Caveat, SIL Open Font License 1.1 ile
dağıtılır; lisans metinleri aynı klasördedir.
