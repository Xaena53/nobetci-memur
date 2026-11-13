class_name Gazete
extends Control
## "Ardıçlı Postası"ndan kesilmiş bir haber kupürü: başlık bandı, tarih, manşet, (varsa) fotoğraf
## ve haber metni. Yüksekliğini içeriğe göre kendi belirler.

const FOTO_GOLGELEYICI := preload("res://assets/shader/foto.gdshader")
const KENAR := 22.0
const KAGIT_TONU := Color(0.93, 0.91, 0.84)
const FOTO := Vector2(104, 126)


## Kupürü kurar. haber: {manset, metin, foto, foto_alt}; tarih: "09.01.1984" biçiminde.
func kur(genislik: float, tarih: String, haber: Dictionary) -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	var w := genislik - 2.0 * KENAR
	var y := 16.0

	var ad := Stil.etiket(Hikaye.GAZETE_ADI, 25, Stil.MUREKKEP, Stil.serif_kalin())
	ad.position = Vector2(0, y)
	ad.size = Vector2(genislik, 32)
	ad.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(ad)
	y += 34.0
	_cizgi(y, w, 2.0)
	_cizgi(y + 4.0, w, 1.0)
	y += 9.0
	var kunye := Stil.etiket(Dil.c("%s  •  Sayı %d  •  Fiyatı 25 TL") % [Tarih.uzun(tarih), 4107 + Tarih.gun_no(tarih) % 30],
		10, Stil.MUREKKEP_SOLUK, Stil.serif_italik())
	kunye.position = Vector2(0, y)
	kunye.size = Vector2(genislik, 14)
	kunye.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(kunye)
	y += 17.0
	_cizgi(y, w, 1.0)
	y += 10.0

	y = _blok(str(haber.get("manset", "")), 23, Stil.serif_kalin(), Stil.MUREKKEP, KENAR, y, w, true, -3) + 9.0

	var metin := str(haber.get("metin", ""))
	var foto := str(haber.get("foto", ""))
	if foto != "":
		# "foto_tur": "aranan" ise emniyetin dosyasındaki eski resim basılır (şahıs bugün öyle görünmez)
		var doku: Texture2D = Portreler.aranan_resmi(foto) if str(haber.get("foto_tur", "")) == "aranan" else null
		foto_ekle(self, foto, Rect2(KENAR, y + 2.0, FOTO.x, FOTO.y), str(haber.get("foto_alt", "")), doku)
		var alt := _blok(metin, 14, Stil.serif(), Stil.MUREKKEP, KENAR + FOTO.x + 12.0, y, w - FOTO.x - 12.0, false, 1)
		y = maxf(alt, y + FOTO.y + 30.0)
	else:
		y = _blok(metin, 15, Stil.serif(), Stil.MUREKKEP, KENAR, y, w, false, 1)
	size = Vector2(genislik, y + 18.0)
	pivot_offset = size / 2.0
	queue_redraw()


func _draw() -> void:
	Kagit.ciz(self, Rect2(Vector2.ZERO, size), "sayfa", Stil.KAGIT_ESKI, 12.0, 3.0, KAGIT_TONU)


func _cizgi(y: float, w: float, kalinlik: float) -> void:
	var c := ColorRect.new()
	c.color = Color(Stil.MUREKKEP, 0.82)
	c.position = Vector2(KENAR, y)
	c.size = Vector2(w, kalinlik)
	c.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(c)


## Sarılı bir metin bloğu ekler; alt kenarının y değerini döndürür.
func _blok(metin: String, punto: int, font: Font, renk: Color, x: float, y: float, w: float, ortali: bool,
		satir_arasi: int) -> float:
	return blok_ekle(self, metin, punto, font, renk, Rect2(x, y, w, 0), ortali, satir_arasi)


## Bir ebeveyne sarılı metin bloğu ekler (yükseklik metne göre hesaplanır); alt kenarı döndürür.
static func blok_ekle(ebeveyn: Control, metin: String, punto: int, font: Font, renk: Color, alan: Rect2,
		ortali: bool = false, satir_arasi: int = 0) -> float:
	var l := Stil.etiket(metin, punto, renk, font)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_constant_override("line_spacing", satir_arasi)
	if ortali:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var satirlar := font.get_multiline_string_size(Dil.c(metin), HORIZONTAL_ALIGNMENT_LEFT, alan.size.x, punto)
	var satir_sayisi := maxi(1, roundi(satirlar.y / font.get_height(punto)))
	var yukseklik := satirlar.y + (satir_sayisi - 1) * satir_arasi + 4.0
	l.position = alan.position
	l.size = Vector2(alan.size.x, yukseklik)
	ebeveyn.add_child(l)
	return alan.position.y + yukseklik


## Siyah-beyaz baskı fotoğraf (portreden) ve altına italik açıklama ekler.
static func foto_ekle(ebeveyn: Control, portre: String, alan: Rect2, aciklama: String = "",
		doku: Texture2D = null) -> void:
	var zemin := ColorRect.new()
	zemin.color = Color(0.20, 0.19, 0.17)
	zemin.position = alan.position
	zemin.size = alan.size
	zemin.mouse_filter = MOUSE_FILTER_IGNORE
	ebeveyn.add_child(zemin)
	var foto := TextureRect.new()
	foto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	foto.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	foto.texture = doku if doku != null else Portreler.doku(portre)
	foto.position = alan.position + Vector2(2, 2)
	foto.size = alan.size - Vector2(4, 4)
	foto.mouse_filter = MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = FOTO_GOLGELEYICI
	m.set_shader_parameter("ton", Color(0.86, 0.84, 0.78))
	m.set_shader_parameter("kontrast", 1.35)
	foto.material = m
	ebeveyn.add_child(foto)
	if aciklama != "":
		var l := Stil.etiket(aciklama, 10, Stil.MUREKKEP_SOLUK, Stil.serif_italik())
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.position = Vector2(alan.position.x, alan.end.y + 2.0)
		l.size = Vector2(alan.size.x, 26)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_constant_override("line_spacing", -2)
		ebeveyn.add_child(l)
