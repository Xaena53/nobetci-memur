extends Belge
## Harç makbuzu: veznede ödenen işlem harcının pembe karbon kopyası.
## Alanlar: ad, soyad, islem, tutar (TL, tam sayı), tarih, makbuz_no.


func _kur() -> void:
	_taban = Vector2(306, 176)

	_yazi("HARÇ MAKBUZU", Rect2(38, 9, 170, 20), 14.5, Stil.MUREKKEP, Stil.serif_kalin())
	_yazi("Ardıçlı Malmüdürlüğü Veznesi", Rect2(38, 28, 190, 12), 8.5, BASLIK_RENGI, Stil.serif())
	_yazi("No", Rect2(216, 10, 20, 12), 8.5, BASLIK_RENGI, Stil.serif())
	_yazi(metin("makbuz_no"), Rect2(232, 8, 66, 18), 13, Stil.KIRMIZI, Stil.daktilo_kalin())

	_satir("ad", "Adı", 38, 46, 120)
	_satir("soyad", "Soyadı", 168, 46, 126)
	_satir("islem", "İşlem", 38, 80, 256, 13)
	_satir("tutar", "Tutar", 38, 114, 116, 16, Stil.MUREKKEP, true)
	_satir("tarih", "Tarih", 168, 114, 110)


func _draw() -> void:
	_kagit_ciz(Stil.KAGIT_PEMBE, Color(0.55, 0.40, 0.38))
	# koçan payı ve delikli yırtma çizgisi
	draw_rect(_r(0, 0, 28, 176), Color(0, 0, 0, 0.05))
	for i in 15:
		draw_circle(_v(28, 8.0 + i * 11.5), 1.6 * _k, Color(0.30, 0.20, 0.18, 0.55))
	for i in 3:
		draw_circle(_v(13, 34.0 + i * 54.0), 4.2 * _k, Color(Stil.MASA_KOYU, 0.8))
	draw_line(_v(38, 42), _v(296, 42), Color(0.3, 0.2, 0.2, 0.6), maxf(1.0, _k))
	_noktali(38, 158, 74)
	_noktali(168, 294, 74)
	_noktali(38, 294, 107)
	_noktali(38, 154, 144)
	_noktali(168, 278, 144)

	# "TAHSİL EDİLMİŞTİR" kaşesi ve veznedar parafı
	var renk := Color(Stil.MOR_MUHUR, 0.62)
	draw_set_transform(_v(222, 160), deg_to_rad(-4.0), Vector2.ONE)
	draw_rect(Rect2(Vector2(-58, -10) * _k, Vector2(116, 19) * _k), renk, false, 1.4 * _k)
	draw_string(Stil.daktilo_kalin(), Vector2(-58, 4) * _k, "TAHSİL EDİLMİŞTİR", HORIZONTAL_ALIGNMENT_CENTER,
		116.0 * _k, roundi(9.5 * _k), renk)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_imza_ciz(Rect2(52, 148, 70, 24), hash(metin("makbuz_no")), Color(Stil.MAVI_MUREKKEP, 0.85))
