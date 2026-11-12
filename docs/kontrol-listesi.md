# Yayın öncesi kontrol listesi

Yayından önce oyunun baştan sona oynanıp aşağıdaki maddelerin işaretlenmesi beklenir.
Önce kodla yapılan denetimler, sonra elle oynanış listesi gelir.

## 1. Kodla denetim

```bash
godot --headless --path . --import                              # varlıklar içe aktarılır
godot --headless --path . res://tools/DumanTesti.tscn           # 408 denetim: sahne akışı, kurallar, hikâye, menü, röntgen, defter, vize, sesler
godot --headless --path . res://scenes/UreticiTesti.tscn -- --cik   # 7 gün x 100 vatandaş: üretici ile doğrulayıcı tutarlı mı
godot --headless --path . res://tools/TamOyun.tscn              # yedi gün baştan sona, iki ayrı memurla
```

- [ ] `bash tools/statik_denetim.sh` "0 sorunlu" yazıyor.
- [ ] `bash tools/saglamlik.sh` "BAŞARILI" yazıyor ve konsolda hata satırı yok.
- [ ] `bash tools/cek.sh sinir` ve `bash tools/cek.sh genelge` karelerinde taşan yazı yok.
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
- [ ] Cüzdandaki vesikalık camdaki kişinin eski bir resmi: kıyafeti ve saçı başka, yüzü aynı.
- [ ] İlmühaberde muhtarın kendi imzası var (adıyla aynı); makbuzda veznedarın parafı, genelgede müdürün imzası.

### Röntgen cihazı (5.–7. gün)

- [ ] Çantalı vatandaş gelince çanta eşikte parlıyor, "ÇANTAYI RÖNTGENE ALIN" şeridi çıkıyor; evrak henüz gelmiyor.
- [ ] Çantaya tıklayınca cihaz masanın önüne yükseliyor, bant sesi geliyor, görüntü sağdan kayarak oturuyor.
- [ ] OLAĞAN / NEGATİF / YOĞUN tuşları görüntüyü değiştiriyor; seçili tuşta yeşil ışık yanıyor.
- [ ] GEÇİR: cihaz iniyor, çanta eşiğe dönüyor, evrak geliyor.
- [ ] ALARM (yasak eşya varken): ekran kızarıyor, alarm çalıyor, vatandaş götürülüyor, teleksten not çıkıyor.
- [ ] ALARM (temiz çantada): saat 12 dakika ileri gidiyor, teleksten uyarı çıkıyor; ikincisinde ihtar.
- [ ] Yasak eşyalı çanta geçirilirse vatandaş ayrılırken ihtar geliyor.
- [ ] Genelge defterinde YASAK sayfası günün yasaklarını gösteriyor (7. gün kesici aletler de).
- [ ] Yasak eşyalar tanınabiliyor; yanıltıcı eşyalar (saç kurutma makinesi, sucuk, mum) haksız yere zorlamıyor.

### Gün gün

| Gün | Yeni kural | Hikâye | Bakılacak |
|---|---|---|---|
| 1 | Cüzdan + ilmühaber, ad-soyad, 6 ay | Hüsnü Amca (eski ilmühaber) | [ ] Gazete: banka soygunu |
| 2 | Mühür ve imza, baba adı | Nermin Hanım "aramızda kalsın"; gözlüklü adam | [ ] Müdür denetimi: jaluzi açılıyor, "MÜDÜR İZLİYOR" |
| 3 | Harç makbuzu ve tarife | Kenan Bey ve zarf | [ ] Zarf: "Çekmeceye At" / "Geri İt". [ ] Gece: patlama |
| 4 | Seri numarası, fotoğraf, sahte mühür-imza-kaşe, arananlar | Ev sahibi İzzet Bey; gözlüklü adam başka adla | [ ] ARANANLAR sayfası açıldı. [ ] Bilgi defteri masada, çift tıkla açılıyor |
| 5 | Harç zammı, makbuz 3 gün, röntgen | Kenan Bey'in büyük zarfı, "Kasap" (torbasında satır), Savcı | [ ] Aranan havale edilince resmine YAKALANDI damgası |
| 6 | Mahalle listesi, B serisi, çalışma vizesi | "Terzi" (el çantasında tabanca), Nermin Hanım'ın dönüşü, sahte vizeli genç | [ ] Yurt dışı çıkış kaydında dördüncü belge: vize. [ ] Gece: savcının akıbeti |
| 7 | İlmühaber 3 ay | Hüsnü Amca ya da Yusuf ve mektup; Başkomiser; bavullu genç | [ ] Bavul yakalanırsa ya da kaçarsa son gazetede haberi var |

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

- [ ] Ana menü kâğıdı yukarıdan süzülüp oturuyor; başlık daktiloyla yazılıyor; satırın üstüne gelince kutusuna işaret konuyor.
- [ ] Sahne canlı: kar rüzgârla savruluyor, bacalar tütüyor, sokak lambası arada bir cızırdayıp titriyor.
- [ ] Kapının üstündeki işlemeli tabelada "T.C. ARDIÇLI İLÇESİ / NÜFUS MÜDÜRLÜĞÜ" yazıyor.
- [ ] Kayıt yokken "Devam" soluk; bir gün oynandıktan sonra açık.
- [ ] Kayıt varken "Yeni Oyun" bir kez daha soruyor.
- [ ] Ayarlar: üç ses kademesi duyulur biçimde değişiyor; mesai saati hızı; tam ekran (F11).
- [ ] Ayarlar oyunu kapatıp açınca korunuyor.

## 4. Kulakla dinlenecekler

Sesler gerçek kayıtlardan kesildi; kesim yerleri spektrogramla, düzeyler oyunun ses çıkışı
kaydedilerek (`tools/Cekim.tscn -- ses`) denetlendi. Kulakla dinlenmedi; yayından önce kulaklıkla
bir tur dinlenmeli:

- [ ] Radyo çok öne çıkmıyor; dört parçanın dördü de çalgısal (söz yok) ve odaya yakışıyor.
- [ ] Konuşma mırıltısı rahatsız etmiyor; kadın, erkek, yaşlı ve çocuk sesleri ayırt ediliyor.
- [ ] Mühür, zil ve ihtar vızıltısı birbirini bastırmıyor; kâğıt kayması fazla hışırdamıyor.
- [ ] Ayak sesleri camın ardındaki yürüyüşe oturuyor.
- [ ] Soba çıtırtısı ve rüzgâr döngüsünde kesinti ("tık") duyulmuyor.
- [ ] Menüde ney, rüzgâr ve lamba cızırtısı dengeli.

Beğenilmeyen sesin kaynağı ya da kesim yeri `tools/ses/kaynaklar.json` içinde değiştirilir:
`python tools/ses/topla.py <ad>`. Parça çıkarmak için `Masa.gd` içindeki `RADYO_LISTESI` yeter.

## 5. Dışa aktarma

```bash
python tools/sablon_indir.py        # dışa aktarma şablonları (bir kez)
bash tools/disa_aktar.sh            # build/ altına Windows ve Web yapıları + zip dosyaları
```

- [ ] `build/NobetciMemur-windows.zip` açılıyor, `.exe` çalışıyor, ilk gün oynanıyor.
- [ ] `build/NobetciMemur-web.zip` yerel sunucuda açılıyor (`python -m http.server` ile `build/web`).
- [ ] itch.io'ya yüklenince tarayıcıda açılıyor; tam ekran düğmesi çalışıyor.
