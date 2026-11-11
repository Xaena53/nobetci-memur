extends Belge
## Nüfus hüviyet cüzdanı: açık defter. Solda fotoğraf ve seri no, sağda kimlik bilgileri.
## Alanlar: ad, soyad, baba_adi, ana_adi, dogum_yeri, dogum_tarihi, seri_no, cinsiyet (+ foto).

const KAPAK_ERKEK := Color("5d7d9c")
const KAPAK_KADIN := Color("c48a7c")
const SAYFA := Color("efe6cd")
const FOTO_GOLGELEYICI := preload("res://assets/shader/foto.gdshader")


func _kur() -> void:
	_taban = Vector2(336, 212)

	_yazi("T.C.", Rect2(10, 12, 154, 13), 9.5, BASLIK_RENGI, Stil.serif_kalin(), HORIZONTAL_ALIGNMENT_CENTER)
	_yazi("NÜFUS HÜVİYET CÜZDANI", Rect2(10, 25, 154, 12), 8.5, BASLIK_RENGI, Stil.serif_kalin(),
		HORIZONTAL_ALIGNMENT_CENTER)

	# Vesikalık fotoğraf (siyah-beyaz baskı)
	var fon := ColorRect.new()
	fon.color = Color("c5c8c0")
	_oge(fon, Rect2(49, 44, 76, 96))
	var foto := TextureRect.new()
	foto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	foto.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	foto.texture = Portreler.doku(str(veri.get("foto", "")))
	var m := ShaderMaterial.new()
	m.shader = FOTO_GOLGELEYICI
	foto.material = m
	_oge(foto, Rect2(49, 44, 76, 96))
	_hedef("foto", "Fotoğraf", veri.get("foto", ""), Rect2(47, 42, 80, 100))

	_yazi("Seri No", Rect2(10, 150, 154, 12), 8.5, BASLIK_RENGI, Stil.serif(), HORIZONTAL_ALIGNMENT_CENTER)
	_yazi(metin("seri_no"), Rect2(10, 161, 154, 22), 15, Stil.BORDO, Stil.daktilo_kalin(),
		HORIZONTAL_ALIGNMENT_CENTER)
	_hedef("seri_no", "Seri no", al("seri_no"), Rect2(38, 149, 98, 36))

	var x := 181.0
	var w := 140.0
	_satir("soyad", "Soyadı", x, 12, w)
	_satir("ad", "Adı", x, 44, w)
	_satir("baba_adi", "Baba Adı", x, 76, w)
	_satir("ana_adi", "Ana Adı", x, 108, w)
	_satir("dogum_yeri", "Doğum Yeri", x, 140, w)
	_satir("dogum_tarihi", "Doğum Tarihi", x, 172, w)


func _draw() -> void:
	var kapak := KAPAK_KADIN if metin("cinsiyet") == "K" else KAPAK_ERKEK
	_kagit_ciz(kapak, kapak.darkened(0.35), 5)
	# iki iç sayfa ve sırt
	draw_rect(_r(7, 7, 157, 198), SAYFA)
	draw_rect(_r(172, 7, 157, 198), SAYFA)
	draw_rect(_r(164, 7, 8, 198), kapak.darkened(0.22))
	draw_line(_v(168, 7), _v(168, 205), kapak.darkened(0.45), maxf(1.0, _k))
	# emniyet deseni: ince dalgalı çizgiler
	var desen := Color(kapak, 0.20)
	for sayfa_x: float in [7.0, 172.0]:
		for i in 9:
			var noktalar := PackedVector2Array()
			var y0 := 20.0 + i * 22.0
			for j in 27:
				var px := sayfa_x + 2.0 + j * 5.9
				noktalar.append(_v(px, y0 + 3.2 * sin(j * 0.85 + i)))
			draw_polyline(noktalar, desen, maxf(1.0, 0.7 * _k), true)
	# fotoğraf çerçevesi ve köşesine taşan soğuk damga
	draw_rect(_r(48, 43, 78, 98), Color(0.2, 0.2, 0.2, 0.75), false, maxf(1.0, _k))
	var damga := Color(Stil.MOR_MUHUR, 0.42)
	draw_arc(_v(124, 138), 20.0 * _k, 0.0, TAU, 40, damga, 1.4 * _k, true)
	draw_arc(_v(124, 138), 15.0 * _k, 0.0, TAU, 40, damga, 0.8 * _k, true)
	# değerlerin altındaki basılı çizgiler
	for i in 6:
		_noktali(181, 321, 12.0 + i * 32.0 + 28.0, Color(0, 0, 0, 0.22))
