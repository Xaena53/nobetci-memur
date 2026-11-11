extends Belge
## Harç makbuzu: veznede ödenen işlem harcının pembe karbon kopyası.
## Alanlar: ad, soyad, islem, tutar (TL, tam sayı), tarih, makbuz_no.


func _kur() -> void:
	_taban = Vector2(326, 180)

	_yazi("HARÇ MAKBUZU", Rect2(58, 10, 170, 20), 14.5, Stil.MUREKKEP, Stil.serif_kalin())
	_yazi("Ardıçlı Malmüdürlüğü Veznesi", Rect2(58, 29, 190, 12), 8.5, BASLIK_RENGI, Stil.serif())
	_yazi("No", Rect2(236, 11, 20, 12), 8.5, BASLIK_RENGI, Stil.serif())
	_yazi(metin("makbuz_no"), Rect2(252, 9, 66, 18), 13, Stil.KIRMIZI, Stil.daktilo_kalin())

	_satir("ad", "Adı", 58, 48, 118)
	_satir("soyad", "Soyadı", 186, 48, 126)
	_satir("islem", "İşlem", 58, 82, 254, 13)
	_satir("tutar", "Tutar", 58, 116, 118, 16, Stil.MUREKKEP, true)
	_satir("tarih", "Tarih", 186, 116, 110)


func _draw() -> void:
	_kagit_ciz("makbuz", Stil.KAGIT_PEMBE, 1.0)
	draw_line(_v(58, 44), _v(314, 44), Color(0.3, 0.2, 0.2, 0.6), maxf(1.0, _k))
	_noktali(58, 176, 76)
	_noktali(186, 312, 76)
	_noktali(58, 312, 109)
	_noktali(58, 172, 146)
	_noktali(186, 296, 146)

	# "TAHSİL EDİLMİŞTİR" kaşesi ve veznedar parafı
	var renk := Color(Stil.MOR_MUHUR, 0.62)
	draw_set_transform(_v(244, 163), deg_to_rad(-4.0), Vector2.ONE)
	draw_rect(Rect2(Vector2(-58, -10) * _k, Vector2(116, 19) * _k), renk, false, 1.4 * _k)
	draw_string(Stil.daktilo_kalin(), Vector2(-58, 4) * _k, "TAHSİL EDİLMİŞTİR", HORIZONTAL_ALIGNMENT_CENTER,
		116.0 * _k, roundi(9.5 * _k), renk)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_imza_ciz(Rect2(70, 150, 70, 24), hash(metin("makbuz_no")), Color(Stil.MAVI_MUREKKEP, 0.85))
