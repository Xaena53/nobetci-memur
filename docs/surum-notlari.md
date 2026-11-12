# Sürüm notları

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
