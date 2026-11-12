# Ekran görüntüleri

itch.io sayfası için en az üç ekran görüntüsü gerekir. Önerilen üç kare ve nasıl alınacakları
aşağıdadır. Görüntüler 1280 × 720 (ya da tam ekranda 1920 × 1080) PNG olmalıdır.

## Oyunun içinden almak (F12)

Oyun açıkken **F12**'ye basın. Görüntü şu klasöre kaydedilir ve yolu konsola yazılır:

- Windows: `%APPDATA%\Godot\app_userdata\Nöbetçi Memur\ekran_goruntuleri\`
- Linux: `~/.local/share/godot/app_userdata/Nöbetçi Memur/ekran_goruntuleri/`

Tam ekran (F11) daha keskin kareler verir.

## Önerilen üç kare

### 1. Masa: inceleme çizgisi

Oyunun ne olduğunu tek bakışta anlatan kare.

1. 4. güne ya da sonrasına gelin (genelge defterinde ARANANLAR sayfası açılmış olur).
2. Camda bir vatandaş ve masada üç belge varken BOŞLUK'a basın.
3. Uyuşmayan iki bilgiyi (örneğin cüzdandaki ve ilmühaberdeki soyadı) tıklayın: kırmızı çizgi ve
   "Uyuşmazlık" balonu görünürken F12.

İyi olur: müdürün jaluzisi açıkken ("MÜDÜR İZLİYOR") çekmek, vatandaşın ağzı açıkken yakalamak.

### 2. Ev: akşam defteri

Oyunun öbür yarısını gösteren kare.

1. Bir günü bitirip eve gelin.
2. Kömürü ve yiyeceği işaretleyin (soba yanar, sofraya ekmek gelir).
3. Defterin üstündeki el yazısı not ve aile görünürken F12.

### 3. Gazete: sabah kupürü ya da son sayfa

Hikâyeyi gösteren kare.

- Sabah: 4. günün başında gazete kupürü ile genelge yan yanayken F12 ("ADLİYE ARŞİVİNDE PATLAMA").
- Ya da oyunun sonunda gazetenin birinci sayfası, sicil özeti ve (varsa) mektupla birlikte.

Kapak görseli (630 × 500) için ana menü ekranı uygundur: başlık, bina ve kuyruk aynı karededir.

## Kodla almak (geliştirici düzeneği)

Aynı kareler elle oynamadan da üretilebilir. Düzenek pencereyi ekran dışında, odak almadan açar;
kareler `tools/cikti/` altına yazılır.

```bash
bash tools/cek.sh hikaye   # sabah gazetesi, arananlar, zarf, ev, gece, sonlar  (h_*.png)
bash tools/cek.sh cila     # ana menü, ayarlar, mola                            (c_*.png)
bash tools/cek.sh masa     # masa, inceleme, büyütülmüş belge, teleks           (1*.png)
bash tools/cek.sh akis     # menüden geceye bir günün tamamı                    (0*.png)
```

README'deki görseller bu düzenekle alınmıştır (`docs/img/`).
