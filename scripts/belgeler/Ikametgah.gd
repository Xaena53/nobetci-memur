extends Belge
## İkametgâh ilmühaberi: muhtarlıktan alınan, kişinin nerede oturduğunu gösteren belge.
## Alanlar: ad, soyad, baba_adi, mahalle, adres, tarih, muhtar, muhtar_imza (bool), muhtar_muhur (bool).


func _kur() -> void:
	_taban = Vector2(292, 378)
	var orta := HORIZONTAL_ALIGNMENT_CENTER

	_yazi("ARDIÇLI İLÇESİ", Rect2(14, 15, 264, 12), 8.5, BASLIK_RENGI, Stil.serif(), orta)
	_yazi("İKAMETGÂH İLMÜHABERİ", Rect2(14, 27, 264, 20), 14.5, Stil.MUREKKEP, Stil.serif_kalin(), orta)

	_satir("mahalle", "Mahallesi", 22, 56, 248)
	_satir("ad", "Adı", 22, 92, 118)
	_satir("soyad", "Soyadı", 152, 92, 118)
	_satir("baba_adi", "Baba Adı", 22, 128, 118)
	_satir("adres", "Adresi", 22, 164, 248, 13)

	_yazi("Yukarıda kimliği yazılı şahsın mahallemizde ikamet ettiği tasdik olunur.",
		Rect2(22, 204, 248, 30), 9.5, Stil.MUREKKEP_SOLUK, Stil.serif_italik(), HORIZONTAL_ALIGNMENT_LEFT, true)

	_satir("tarih", "Tarih", 22, 240, 118)

	_yazi("Mahalle Muhtarı", Rect2(22, 284, 130, 12), 8.5, BASLIK_RENGI, Stil.serif())
	_yazi(metin("muhtar"), Rect2(22, 295, 150, 16), 11, Stil.MUREKKEP)
	_hedef("muhtar_imza", "Muhtar imzası", al("muhtar_imza"), Rect2(19, 283, 150, 78))

	_yazi("Mühür", Rect2(186, 284, 84, 12), 8.5, BASLIK_RENGI, Stil.serif(), orta)
	_hedef("muhtar_muhur", "Muhtar mührü", al("muhtar_muhur"), Rect2(186, 283, 84, 84))


func _draw() -> void:
	_kagit_ciz("sayfa", Stil.KAGIT_BEYAZ, 3.0)
	# basılı çift çerçeve
	var cizgi := Color(0.25, 0.24, 0.22, 0.75)
	draw_rect(_r(8, 8, 276, 362), cizgi, false, maxf(1.0, 1.4 * _k))
	draw_rect(_r(11, 11, 270, 356), Color(cizgi, 0.45), false, maxf(1.0, 0.7 * _k))
	draw_line(_v(70, 50), _v(222, 50), cizgi, maxf(1.0, _k))
	# doldurma çizgileri
	_noktali(22, 270, 84)
	_noktali(22, 140, 120)
	_noktali(152, 270, 120)
	_noktali(22, 140, 156)
	_noktali(22, 270, 191)
	_noktali(22, 140, 268)

	var tohum := hash(metin("muhtar") + metin("mahalle"))
	if bool(al("muhtar_imza")):
		_imza_ciz(Rect2(26, 312, 120, 44), tohum, Stil.MAVI_MUREKKEP)
	else:
		_noktali(26, 150, 348, Color(0, 0, 0, 0.3))

	var merkez := _v(228, 330)
	if bool(al("muhtar_muhur")):
		_muhur_ciz(merkez, tohum)
	else:
		# boş mühür yeri: silik kesikli daire
		var adim := 28
		for i in adim:
			if i % 2 == 0:
				draw_arc(merkez, 30.0 * _k, TAU * i / adim, TAU * (i + 1) / adim, 4, Color(0, 0, 0, 0.22), maxf(1.0, 0.8 * _k), true)


## Mor ıstampalı yuvarlak muhtarlık mührü (hafif yamuk, yer yer silik).
func _muhur_ciz(merkez: Vector2, tohum: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = tohum
	var renk := Color(Stil.MOR_MUHUR, rng.randf_range(0.62, 0.80))
	var aci := deg_to_rad(rng.randf_range(-14.0, 14.0))
	draw_set_transform(merkez, aci, Vector2.ONE)
	draw_arc(Vector2.ZERO, 31.0 * _k, 0.0, TAU, 56, renk, 2.0 * _k, true)
	draw_arc(Vector2.ZERO, 26.5 * _k, 0.0, TAU, 56, renk, 0.9 * _k, true)
	draw_arc(Vector2.ZERO, 14.5 * _k, 0.0, TAU, 40, renk, 0.9 * _k, true)
	# halka içindeki yazıyı andıran kısa çentikler
	for i in 22:
		var a := TAU * i / 22.0
		var yon := Vector2(cos(a), sin(a))
		if i % 11 == 0:
			draw_circle(yon * 20.5 * _k, 1.4 * _k, renk)
		else:
			draw_line(yon * 18.0 * _k, yon * 23.0 * _k, renk, 1.5 * _k, true)
	var f := Stil.daktilo_kalin()
	draw_string(f, Vector2(-14.5 * _k, 3.5 * _k), "MUH.", HORIZONTAL_ALIGNMENT_CENTER, 29.0 * _k, roundi(9.0 * _k), renk)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
