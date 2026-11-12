# Sürüm notları

## 1.1.0 — vesikalıklar ve röntgen cihazı

### Fotoğraflar

- **Vesikalıklar yenilendi.** Nüfus cüzdanındaki fotoğraf artık yıllar önce çekilmiş ayrı bir
  resimdir: kıyafet, saç, bıyık, şapka başkadır. Fotoğrafın sahibini yüz hatlarından tanımak gerekir.
- **Sahte cüzdandaki fotoğraf benzer birine ait.** Yüz benzerliği ölçülerek her kişi için "en çok
  benzeyenler" listesi çıkarıldı; zorluk arttıkça daha benzeri seçilir.
- **Arananlar listesi eski dosya resimlerini gösterir.** Aranan şahıslar gişeye kılık değiştirmiş
  gelir. Arada bir, listedeki resme benzeyen masum bir vatandaş da gelir.
- Gazetedeki "aranıyor" fotoğrafı da eski resimdir.

### Röntgen cihazı

- **5. günden itibaren** çantayla gelenin eşyası evrakından önce röntgenden geçer.
- Dört çanta türü (bavul, bez çanta, evrak çantası, el çantası), otuz altı eşya.
- Üç görüntü kipi: olağan, negatif, yalnızca yoğun parçalar.
- Yasaklar genelgeyle gelir: 5. gün ateşli silah, mermi ve patlayıcı; 6. günden itibaren bıçak,
  kama ve satır da. Genelge defterine **YASAK** sayfası eklendi.
- Yanıltıcı eşyalar: saç kurutma makinesi, el matkabı, sucuk, mum, çalar saat, terzi makası.
- Yerinde alarm prim getirir; kaçan yasak eşya ihtar, boş alarm zaman kaybıdır.
- Hikâyeye bağlandı: Hüsnü Amca'nın torbası, "Kasap"ın satırı, "Terzi"nin el çantası ve son gün
  gelen bavul. Bavulun akıbeti son gazetede bir haber olarak çıkar.
- Gün sonu puantajına röntgen satırı eklendi.
- Yeni sesler: bant, düğme, alarm.

### Ana menü

- **Menü bir müdürlük yazısı oldu:** antet, daktiloyla yazılan başlık, konu ve sayı satırı, numaralı
  seçenekler, imza ve mühür. Üstüne gelinen satırın kutusuna işaret konur.
- **Sahne canlandı:** üç katmanlı, rüzgârla savrulan kar; rüzgâra göre yatan baca dumanı; arada bir
  cızırdayıp titreyen sokak lambası ve ışığında parlayan kar taneleri.
- Kapının üstündeki tabela işlemeli ahşap bir levha; yazısı görselin parçası olduğu için eğri durmuyor.
- Sürüm bilgisi kabartma şerit etiketinde.

### İmzalar

- **Herkesin kendi imzası var.** Müdür, on dört mahalle muhtarı ve veznedar için dolma kalemle atılmış
  ayrı ayrı imzalar: ilmühaberde muhtarın, makbuzda veznedarın, genelgede ve menü kâğıdında müdürün imzası.

### Teknik

- Duman testi 330 denetime çıktı; tam oyun testindeki memurlar çanta kararlarını da veriyor.
- Yeni üretim betikleri: `tools/sanat/vesikalik.py`, `tools/sanat/rontgen.py`, `tools/sanat/imzalar.py`.

## 1.0.0 — ilk yayın

Nöbetçi Memur'un ilk tam sürümü: yedi günlük hikâyenin tamamı, yedi ayrı sonla oynanabilir.

### İçerik

- **Yedi iş günü** (9–17 Ocak 1984). Her sabah müdürün yeni genelgesi ve "Ardıçlı Postası"ndan bir kupür.
- **Üç belge:** nüfus cüzdanı, ikametgâh ilmühaberi, harç makbuzu.
- **Dokuz kusur türü:** eksik belge, uyuşmayan ad-soyad, uyuşmayan baba adı, süresi geçmiş belge,
  eksik mühür ya da imza, yanlış harç, geçersiz seri numarası, başkasına ait fotoğraf, ilçeye bağlı
  olmayan mahalle.
- **Üç karar:** onay mührü, gerekçeli "eksik evrak" fişi, "müdüre havale" pusulası (günde iki hak).
- **İnceleme modu:** iki bilgiyi karşılaştırır; belge–belge, fotoğraf–yüz, tarih–takvim, tutar–tarife,
  yüz–arananlar listesi.
- **Hikâye karakterleri:** Hüsnü Amca ve torunu Yusuf, komşu Nermin Hanım, ev sahibi İzzet Bey,
  müteahhit Kenan Bey, Savcı Hikmet Altay, sivil Başkomiser Tarık Ersoy, arananlar "Kasap" ve "Terzi".
- **Müdür denetimi:** jaluzi açıkken yapılan hata çift ihtar sayılır; o sırada alınan rüşvet müsadere edilir.
- **Ev:** her akşam kira, kömür, yiyecek, ilaç ve okul masrafı; ailenin sağlığı ve gece olayları.
- **Yedi son:** terfi, yerinde kalma, ihtar yüzünden sürgün, şüphe yüzünden açığa alınma, iflas,
  aileden birinin ağır hastalanması, tahliye. Yan haberler oyuncunun seçimlerine göre değişir.

### Sunum

- Hafif perspektifli masa; belgeler masada yatar, ele alınınca düzleşir ve büyür.
- Canlı portreler: nefes, göz kırpma, boyalı ağız kareleriyle konuşma, yürüyüş, öfleme.
- İhtar, uyarı ve notlar teleksten satır satır basılır.
- Tamamı kodla sentezlenmiş sesler: mühür, kâğıt, zil, teleks, daktilo, radyo, soba, rüzgâr.
- Ayarlar: genel ses, efektler, radyo ve ortam, mesai saatinin hızı, tam ekran.

### Teknik

- Godot 4.3, Compatibility (OpenGL / WebGL 2) çizici; 1280 × 720 tasarım çözünürlüğü, her boyuta ölçeklenir.
- Windows (tek .exe) ve Web (iş parçacıksız şablon; özel sunucu başlığı gerektirmez) yapıları.
- Her günün sabahında otomatik kayıt (`user://kayit.json`).

### Bilinen sınırlar

- Oyun yalnızca Türkçedir.
- Fare ile oynanır; dokunmatik ekran ve oyun kolu desteklenmez.
- Kayıt gün başında alınır: gün ortasında çıkılırsa o günün mesaisi sabahtan yeniden başlar.
- Windows .exe dosyası Godot'un varsayılan simgesini taşır (simgeyi gömmek için `rcedit` gerekir).
- Web sürümünde tarayıcı, ilk tıklamadan önce ses çalmaz.
