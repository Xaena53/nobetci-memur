extends Belge
## İkametgâh ilmühaberi: muhtarlıktan alınan, kişinin nerede oturduğunu gösteren belge.
## Alanlar: ad, soyad, baba_adi, mahalle, adres, tarih, muhtar, muhtar_imza (bool), muhtar_muhur (bool),
##          muhur_turu ("" gerçek; doluysa sahtecilik türü, bkz. Damga), imza_sahibi (imzayı atan; sahte
##          belgede muhtardan başkası).


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
	if bool(al("muhtar_muhur")):
		_oge(Damga.olustur("muhtar", metin("muhur_turu"), hash(metin("muhtar") + metin("mahalle"))),
			Rect2(182, 285, 92, 92))
	_hedef("muhtar_muhur", "Muhtar mührü", al("muhtar_muhur"), Rect2(184, 283, 88, 92))


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
		var imzalayan := metin("imza_sahibi") if metin("imza_sahibi") != "" else metin("muhtar")
		_imza_ciz(Rect2(22, 308, 136, 52), tohum, Color(Stil.MAVI_MUREKKEP, 0.95), imzalayan)
	else:
		_noktali(26, 150, 348, Color(0, 0, 0, 0.3))

	var merkez := _v(228, 331)
	if not bool(al("muhtar_muhur")):
		# boş mühür yeri: silik kesikli daire
		var adim := 28
		for i in adim:
			if i % 2 == 0:
				draw_arc(merkez, 30.0 * _k, TAU * i / adim, TAU * (i + 1) / adim, 4, Color(0, 0, 0, 0.22), maxf(1.0, 0.8 * _k), true)
