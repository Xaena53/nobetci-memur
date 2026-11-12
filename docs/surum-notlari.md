# Sürüm notları

## 1.2.0 — görev şekilleri, bilgi defteri, çalışma vizesi, gerçek sesler

### Görev şekli

- **Yeni oyunda Kolay, Orta ya da Zor seçilir.** Kolayda inceleme modu her karşılaştırmanın sonucunu
  söyler ve saat ağır işler. Ortada günde üç ipucu hakkı vardır: çizgi çekilir, balona tıklanınca
  sonuç açılır. Zorda ipucu yoktur ve sahtecilikler bir kademe daha incedir. Seçim kayıtla saklanır.

### Bilgi defteri ve sahte evrak

- **4. günden itibaren masada bir bilgi defteri durur.** Çift tıklanınca açılır; dört yaprağı vardır:
  muhtarlık mührü, muhtarların imza sirküleri, vezne ve konsolosluk kaşeleri, çalışma vizesi. Her
  yaprakta gerçek örnek ve emniyetin ele geçirdiği sahteler yan yana durur.
- **Yeni kusurlar:** sahte muhtar mührü (yedi çeşit: yanlış mürekkep, oval baskı, tek halka, yıldızsız,
  iç halkasız, yazım hatası, başka ilçe), başkasının attığı imza, sahte vezne kaşesi.
- Defterdeki örnekler inceleme modunda evraktaki mühür, imza ve kaşeyle karşılaştırılabilir.
- Sahte evrakta doğru karar müdüre havaledir.

### Çalışma vizesi

- **6. günden itibaren yeni işlem:** yurt dışı çıkış kaydı (harcı 2.000 TL). Dördüncü bir belge
  aranır: çalışma vizesi. Numarası, konsolosluk kaşesi, süresi, cüzdanla eşleşen seri numarası,
  doğum tarihi ve hamilin imzası denetlenir.
- Kesici alet yasağı 7. güne alındı.
- Hikâyeye iki kişi eklendi: tarlasını satıp sahte vize alan genç ve vizesi bir gün önce dolan
  dökümcü ustası. İkisinin akıbeti son gazetede yan haber olarak çıkar.

### Kadro

- **89 ayrı yüz.** 25 yeni portre; her birinin eski vesikalığı ve konuşma kareleri var.
- **Her yüz kalıcı bir kişi:** adı, ana ve baba adı, doğum yeri ve tarihi her oynanışta aynıdır.
- **115 imza.** Bütün vatandaşların, muhtarların, veznedarın, vize memurunun ve müdürün kendi
  imzası var; cüzdanda sahibinin imzası durur.

### Görünüm

- Mühür ve kaşeler boyalı ıstampa izleri oldu (gerçek ve sahte çeşitleriyle); karar mührü,
  "GÖRÜLMÜŞTÜR" ve dairenin mührü de.
- Müdür plaketi, defter kapağı, karar fişleri, röntgen cihazının etiketleri, "KAPALI" levhası ve
  şerit etiketler yazılarıyla birlikte boyalı görsel.
- Ele alınan belge ve defter araç tepsisinin üstünde çizilir; altında kalan araçlar tıklanmaz.

### Sesler

- **Bütün sesler gerçek kayıtlardan.** Sentezlenmiş seslerin hepsi kaldırıldı; efektler Freesound'daki
  kamu malı (CC0) kayıtlardan kesildi: ıstampa mührü, kâğıt, sayfa, resepsiyon zili, daktilo, tahta
  zeminde ayak sesleri, iç çekiş, kepenk, jaluzi, bozuk para, duvar saati, dolma kalem, uzak patlama
  ve silah sesi, taşıma bandı, alarm, floresan cızırtısı, soba, kış rüzgârı.
- **Çalgı müziği.** Masadaki radyo sırayla Hüseyni Saz Semaisi (kemençe ve ud, eski bir taş plak
  kaydı), Harman Dalı, bir bağlama kaydı ve bir taksim çalar; her gün listenin başka bir parçasından
  açılır. Menüde ve akşam evde ney duyulur.
- **Konuşma kısa bir mırıltı.** Gerçek bir mırıltı kaydından kesilmiş on hece, kişinin yaşına ve
  cinsiyetine göre inceltilerek çalınır.
- Ayak sesi, hece, kâğıt, sayfa ve daktilo her seferinde başka bir kayıttan çalar.
- Genelgenin yazısı bitince müdür imzasını atar; imzanın sesi duyulur.
- Ana çıkışa sınırlayıcı eklendi: üst üste binen sesler taşmaz.
- Kaynakların künyesi `assets/ses/KAYNAKLAR.md` dosyasında.

### Teknik

- Duman testi 408 denetime çıktı.
- Yeni betikler: `tools/ses/topla.py` (sesleri kaynaklarından derler), `tools/sanat/damgalar.py`,
  `tools/sanat/yeni_havuz.py`, `tools/sanat/kadro.py`.
- `godot --headless --path . res://tools/Cekim.tscn -- ses` oyunun ses çıkışını dosyaya kaydeder.

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
