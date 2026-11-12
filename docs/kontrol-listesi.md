# Yayın öncesi kontrol listesi

Yayından önce oyunun baştan sona oynanıp aşağıdaki maddelerin işaretlenmesi beklenir.
Önce kodla yapılan denetimler, sonra elle oynanış listesi gelir.

## 1. Kodla denetim

```bash
godot --headless --path . --import                              # varlıklar içe aktarılır
godot --headless --path . res://tools/DumanTesti.tscn           # 294 denetim: sahne akışı, kurallar, hikâye, menü
godot --headless --path . res://scenes/UreticiTesti.tscn -- --cik   # 7 gün x 100 vatandaş: üretici ile doğrulayıcı tutarlı mı
godot --headless --path . res://tools/TamOyun.tscn              # yedi gün baştan sona, iki ayrı memurla
```

- [ ] Duman testi "BAŞARILI" yazıyor.
- [ ] Üretici testi "her vatandaşta aynı fikirde" yazıyor.
- [ ] Tam oyun testi "BAŞARILI" yazıyor: titiz memur terfi ediyor, savruk memurun sonu kötü.
- [ ] Üçünde de konsolda hata ya da uyarı yok.

## 2. Elle oynanış: yedi gün

Her gün için: genelge okunuyor, gişe açılıyor, kuyruk işleniyor, gün sonu puantajı ve ev ekranı geliyor.

### Her gün bakılacaklar

- [ ] Sabah genelgesi kâğıda sığıyor; daktilo sesiyle yazılıyor; tıklayınca tamamı görünüyor.
- [ ] Vatandaş yürüyerek geliyor, zil çalıyor, konuşurken ağzı oynuyor.
- [ ] Belgeler sürükleniyor, çift tıkla büyüyüp küçülüyor, teleksin altına girmiyor.
- [ ] İnceleme modunda (BOŞLUK) iki bilgi seçilince çizgi ve sonuç balonu çıkıyor.
- [ ] Mühür: "BAM" sesi ve kısa sarsıntı. Fiş: gerekçe penceresi açılıyor.
- [ ] Yanlış kararda teleks ihtarı satır satır basıyor; pusula iğneye takılıyor.
- [ ] Saat 17:00'de ya da kuyruk bitince kepenk iniyor.
- [ ] Gün sonu puantajındaki sayılar gün içinde olanlarla tutuyor.
- [ ] Evde seçilen kalem odaya yansıyor (soba, ekmek, ilaç, defter); "Lambayı Söndür" geceyi getiriyor.
- [ ] ESC molası oyunu durduruyor; "Gişeye Dön" kaldığı yerden sürdürüyor.

### Gün gün

| Gün | Yeni kural | Hikâye | Bakılacak |
|---|---|---|---|
| 1 | Cüzdan + ilmühaber, ad-soyad, 6 ay | Hüsnü Amca (eski ilmühaber) | [ ] Gazete: banka soygunu |
| 2 | Mühür ve imza, baba adı | Nermin Hanım "aramızda kalsın"; gözlüklü adam | [ ] Müdür denetimi: jaluzi açılıyor, "MÜDÜR İZLİYOR" |
| 3 | Harç makbuzu ve tarife | Kenan Bey ve zarf | [ ] Zarf: "Çekmeceye At" / "Geri İt". [ ] Gece: patlama |
| 4 | Seri numarası, fotoğraf, arananlar | Ev sahibi İzzet Bey; gözlüklü adam başka adla | [ ] ARANANLAR sayfası açıldı |
| 5 | Harç zammı, makbuz 3 gün | Kenan Bey'in büyük zarfı, "Kasap", Savcı | [ ] Aranan havale edilince resmine YAKALANDI damgası |
| 6 | Mahalle listesi, B serisi | "Terzi", Nermin Hanım'ın dönüşü | [ ] Gece: savcının akıbeti |
| 7 | İlmühaber 3 ay | Hüsnü Amca ya da Yusuf ve mektup; Başkomiser | [ ] Son: gazetenin birinci sayfası |

### Sonlar

- [ ] **Terfi:** en çok 6 ihtar, şüphe düşük, yedi gün tamam.
- [ ] **Yerinde:** yedi gün tamam ama ihtar ya da şüphe fazla.
- [ ] **Sürgün (ihtar):** toplam 14 ihtar.
- [ ] **Açığa alınma (şüphe):** zarflar ve kayırmalarla şüphe 4'e varınca.
- [ ] **İflas:** para eksiye düşünce.
- [ ] **Hastalık:** aileden biri ağır hastalanınca.
- [ ] **Tahliye:** kira üç akşam üst üste ödenmeyince.
- [ ] Hüsnü Amca'ya onay verildiyse sonda mektup duruyor.

## 3. Menü ve ayarlar

- [ ] Ana menüde başlık daktiloyla yazılıyor; kar yağıyor; tabelada "NÜFUS MÜDÜRLÜĞÜ" yazıyor.
- [ ] Kayıt yokken "Devam" soluk; bir gün oynandıktan sonra açık.
- [ ] Kayıt varken "Yeni Oyun" bir kez daha soruyor.
- [ ] Ayarlar: üç ses kademesi duyulur biçimde değişiyor; mesai saati hızı; tam ekran (F11).
- [ ] Ayarlar oyunu kapatıp açınca korunuyor.

## 4. Kulakla dinlenecekler

Sesler kodla sentezlendi ve yalnızca sayısal olarak (süre, düzey) denetlendi. Yayından önce
kulaklıkla bir tur dinlenmeli:

- [ ] Radyo çok öne çıkmıyor; konuşma heceleri rahatsız etmiyor.
- [ ] Mühür, zil ve ihtar vızıltısı birbirini bastırmıyor.
- [ ] Soba çıtırtısı ve rüzgâr döngüsünde kesinti ("tık") duyulmuyor.

Beğenilmeyen ses `tools/ses/uret.py` içindeki işlevi değiştirilip yeniden üretilebilir:
`python tools/ses/uret.py`

## 5. Dışa aktarma

```bash
python tools/sablon_indir.py        # dışa aktarma şablonları (bir kez)
bash tools/disa_aktar.sh            # build/ altına Windows ve Web yapıları + zip dosyaları
```

- [ ] `build/NobetciMemur-windows.zip` açılıyor, `.exe` çalışıyor, ilk gün oynanıyor.
- [ ] `build/NobetciMemur-web.zip` yerel sunucuda açılıyor (`python -m http.server` ile `build/web`).
- [ ] itch.io'ya yüklenince tarayıcıda açılıyor; tam ekran düğmesi çalışıyor.
