extends Belge
## Çalışma vizesi: yurt dışına işçi gidenlerin konsolosluktan aldığı belge. Yurt dışı çıkış kaydında aranır.
## Alanlar: ad, soyad, dogum_tarihi, seri_no (cüzdanın seri numarası), ulke, meslek, vize_no ("ÇV-84-03127"),
##          verilis, bitis (son geçerlilik günü), kase_turu ("" gerçek; doluysa sahtecilik türü), imza (hamilin imzası).
##
## Gerçek vizenin numarası verilmiş aralıktadır, kaşesi kırmızı ve çift halkalıdır, seri numarası, doğum tarihi
## ve imzası cüzdandakiyle aynıdır. Örnekleri bilgi defterindedir.

const ZEMIN := Color(0.86, 0.93, 0.83)
const DESEN := Color(0.22, 0.42, 0.30)


func _kur() -> void:
	_taban = Vector2(318, 214)

	_yazi("ÇALIŞMA VİZESİ", Rect2(14, 11, 180, 20), 14.5, Color("21402d"), Stil.serif_kalin())
	_yazi("Konsolosluk Çalışma Şubesi — Ankara", Rect2(14, 30, 190, 12), 8.5, BASLIK_RENGI, Stil.serif())
	_yazi("No", Rect2(204, 8, 14, 12), 8.5, BASLIK_RENGI, Stil.serif())
	_yazi(metin("vize_no"), Rect2(204, 17, 106, 18), 12.5, Stil.KIRMIZI, Stil.daktilo_kalin())
	_hedef("vize_no", "Vize numarası", al("vize_no"), Rect2(200, 6, 112, 32))

	_satir("soyad", "Soyadı", 14, 48, 92, 12)
	_satir("ad", "Adı", 114, 48, 92, 12)
	_satir("dogum_tarihi", "Doğum Tarihi", 14, 82, 92, 12)
	_satir("seri_no", "Cüzdan Seri No", 114, 82, 92, 12)
	_satir("ulke", "Gideceği Ülke", 14, 116, 92, 12)
	_satir("meslek", "Mesleği", 114, 116, 92, 12)
	_satir("verilis", "Veriliş Tarihi", 14, 150, 92, 12)
	_satir("bitis", "Son Geçerlilik Günü", 114, 150, 92, 12, Stil.MUREKKEP, true)

	# konsolosluk kaşesi (kırmızı ıstampa)
	_oge(Damga.olustur("vize", metin("kase_turu"), hash(metin("vize_no"))), Rect2(219, 40, 88, 88))
	_hedef("vize_kase", "Konsolosluk kaşesi", al("kase_turu"), Rect2(218, 40, 90, 88))

	_yazi("Hamilin İmzası", Rect2(214, 131, 96, 11), 8, BASLIK_RENGI, Stil.serif(), HORIZONTAL_ALIGNMENT_CENTER)
	_hedef("imza", "Hamilin imzası", al("imza"), Rect2(212, 130, 100, 44))
	_yazi("Vize Memuru", Rect2(14, 184, 60, 11), 8, BASLIK_RENGI, Stil.serif())


func _draw() -> void:
	var havada := _surukleniyor or buyuk
	Kagit.ciz(self, Rect2(Vector2.ZERO, size), "sayfa", ZEMIN, (11.0 if havada else 4.0) * _k, 2.0 * _k, ZEMIN)
	# üstte koyu yeşil şerit ve emniyet deseni: ince dalgalı çizgiler
	draw_rect(_r(8, 6, 302, 2.2), Color(DESEN, 0.85))
	draw_rect(_r(8, 43.5, 302, 0.9), Color(DESEN, 0.6))
	for i in 9:
		var noktalar := PackedVector2Array()
		var y0 := 54.0 + i * 17.0
		for j in 52:
			noktalar.append(_v(10.0 + j * 5.85, y0 + 2.6 * sin(j * 0.8 + i * 1.3)))
		draw_polyline(noktalar, Color(DESEN, 0.13), maxf(1.0, 0.7 * _k), true)
	draw_rect(_r(8, 8, 302, 198), Color(DESEN, 0.55), false, maxf(1.0, _k))
	# doldurma çizgileri
	for satir in 4:
		var y := 48.0 + satir * 34.0 + 27.0
		_noktali(14, 106, y)
		_noktali(114, 206, y)
	# hamilin imzası ve vize memurunun imzası
	_noktali(216, 308, 172)
	_imza_ciz(Rect2(214, 142, 96, 30), hash(metin("imza")), Color(Stil.MAVI_MUREKKEP, 0.95), metin("imza"))
	_imza_ciz(Rect2(70, 176, 96, 30), 7, Color(0.10, 0.10, 0.12, 0.9), "vize_memuru")
