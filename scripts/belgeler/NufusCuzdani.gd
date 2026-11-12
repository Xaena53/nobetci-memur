extends Belge
## Nüfus cüzdanı: açık defter. Solda fotoğraf ve seri no, sağda kimlik bilgileri.
## Alanlar: ad, soyad, baba_adi, ana_adi, dogum_yeri, dogum_tarihi, seri_no, cinsiyet, imza (+ foto).
## Fotoğrafın altında sahibinin imzası durur; çalışma vizesindeki imza bununla karşılaştırılır.

const KAPAK_ERKEK := Color("5d7d9c")
const KAPAK_KADIN := Color("c48a7c")
const SAYFA := Color("efe6cd")
const FOTO_GOLGELEYICI := preload("res://assets/shader/foto.gdshader")


func _kur() -> void:
	_taban = Vector2(336, 212)

	_yazi("T.C.", Rect2(10, 11, 154, 13), 9.5, BASLIK_RENGI, Stil.serif_kalin(), HORIZONTAL_ALIGNMENT_CENTER)
	_yazi("NÜFUS CÜZDANI", Rect2(10, 23, 154, 15), 11, BASLIK_RENGI, Stil.serif_kalin(), HORIZONTAL_ALIGNMENT_CENTER)

	# Vesikalık fotoğraf: yıllar önce çekilmiş, siyah-beyaz baskı. Sahibi bugün başka giyinir, saçı
	# başkadır; aynı kişi olup olmadığı yüz hatlarından anlaşılır.
	var fon := ColorRect.new()
	fon.color = Color("c5c8c0")
	_oge(fon, Rect2(53, 41, 68, 86))
	var foto := TextureRect.new()
	foto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	foto.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	foto.texture = Portreler.vesikalik(str(veri.get("foto", "")))
	var m := ShaderMaterial.new()
	m.shader = FOTO_GOLGELEYICI
	foto.material = m
	_oge(foto, Rect2(53, 41, 68, 86))
	_hedef("foto", "Fotoğraf", veri.get("foto", ""), Rect2(51, 39, 72, 90))

	# sahibinin imzası (fotoğrafın altında)
	_hedef("imza", "İmza", al("imza"), Rect2(28, 130, 118, 27))

	_yazi("Seri No", Rect2(10, 158, 154, 12), 8.5, BASLIK_RENGI, Stil.serif(), HORIZONTAL_ALIGNMENT_CENTER)
	_yazi(metin("seri_no"), Rect2(10, 168, 154, 22), 15, Stil.BORDO, Stil.daktilo_kalin(),
		HORIZONTAL_ALIGNMENT_CENTER)
	_hedef("seri_no", "Seri no", al("seri_no"), Rect2(38, 158, 98, 34))

	var x := 181.0
	var w := 140.0
	_satir("soyad", "Soyadı", x, 12, w)
	_satir("ad", "Adı", x, 44, w)
	_satir("baba_adi", "Baba Adı", x, 76, w)
	_satir("ana_adi", "Ana Adı", x, 108, w)
	_satir("dogum_yeri", "Doğum Yeri", x, 140, w)
	_satir("dogum_tarihi", "Doğum Tarihi", x, 172, w)


func _draw() -> void:
	var kadin := metin("cinsiyet") == "K"
	var kapak := KAPAK_KADIN if kadin else KAPAK_ERKEK
	_kagit_ciz("cuzdan_pembe" if kadin else "cuzdan_mavi", SAYFA, 1.0)
	# emniyet deseni: ince dalgalı çizgiler
	var desen := Color(kapak, 0.16)
	for sayfa_x: float in [12.0, 176.0]:
		for i in 8:
			var noktalar := PackedVector2Array()
			var y0 := 26.0 + i * 22.0
			for j in 25:
				var px := sayfa_x + 2.0 + j * 5.9
				noktalar.append(_v(px, y0 + 3.2 * sin(j * 0.85 + i)))
			draw_polyline(noktalar, desen, maxf(1.0, 0.7 * _k), true)
	# fotoğraf çerçevesi ve köşesine taşan soğuk damga
	draw_rect(_r(52, 40, 70, 88), Color(0.2, 0.2, 0.2, 0.75), false, maxf(1.0, _k))
	var damga := Color(Stil.MOR_MUHUR, 0.42)
	draw_arc(_v(121, 124), 18.0 * _k, 0.0, TAU, 40, damga, 1.4 * _k, true)
	draw_arc(_v(121, 124), 13.5 * _k, 0.0, TAU, 40, damga, 0.8 * _k, true)
	# imza
	_noktali(30, 144, 155.5, Color(0, 0, 0, 0.22))
	_imza_ciz(Rect2(30, 130, 114, 26), hash(metin("imza")), Color(Stil.MAVI_MUREKKEP, 0.95), metin("imza"))
	# değerlerin altındaki basılı çizgiler
	for i in 6:
		_noktali(181, 319, 12.0 + i * 32.0 + 28.0, Color(0, 0, 0, 0.22))
