class_name DuvarSaati
extends Control
## Duvardaki saat, yapraklı takvim ve çevirmeli (kartlı) masa saati.
##
##  - Kadran arka plan resmindedir; üstüne boyalı akrep ve yelkovan döner, rakamları basılır.
##  - Takvim: günün boyalı yaprağı (assets/img/nesne/takvim_<gün>.webp). Yaprağı olmayan bir tarih
##    gelirse aynı düzen yazıyla kurulur. Takvim, inceleme modunda bir hedeftir.
##  - Çevirmeli saat: saat ve dakika, boyalı rakam kartlarıyla gösterilir; dakika değişince kart döner.
## Ölçüler `data/varliklar.json` dosyasından gelir (tools/sanat/yeni_varliklar.py yazar).

signal hedef_tiklandi(hedef: Hedef)

const NESNE := "res://assets/img/nesne/%s.webp"
const VARLIKLAR := "res://data/varliklar.json"

var dakika := 540.0:   ## gece yarısından beri geçen oyun dakikası
	set(d):
		dakika = d
		# ibre ancak gözle görülür kadar ilerleyince yeniden çizilir (her karede değil)
		var adim := int(d * 6.0)
		if adim != _son_adim:
			_son_adim = adim
			_guncelle()

var takvim: Hedef
var _son_adim := -1
var _son_dakika := -1

var _yaprak: TextureRect
var _yedek_yazilar: Array[Label] = []
var _kartlar: Array[TextureRect] = []      ## SS:DD → dört rakam kartı
var _rakamlar: Array[Texture2D] = []
var _akrep: Texture2D
var _yelkovan: Texture2D
var _eksenler: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	var bilgi: Variant = Veri.oku(VARLIKLAR)
	_eksenler = bilgi if typeof(bilgi) == TYPE_DICTIONARY else {}
	_akrep = _doku("saat_akrep")
	_yelkovan = _doku("saat_yelkovan")
	var y := Yerlesim.TAKVIM_YAPRAK

	# yaprağın duvara düşen ince gölgesi ve yaprak
	var golge := ColorRect.new()
	golge.color = Color(0, 0, 0, 0.16)
	golge.position = y.position + Vector2(2, 3)
	golge.size = y.size
	golge.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(golge)
	_yaprak = TextureRect.new()
	_yaprak.name = "TakvimYapragi"
	_yaprak.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_yaprak.stretch_mode = TextureRect.STRETCH_SCALE
	_yaprak.position = y.position
	_yaprak.size = y.size
	_yaprak.pivot_offset = Vector2(y.size.x / 2.0, 0.0)
	_yaprak.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_yaprak)
	# yaprağı olmayan tarihler için yazıyla kurulan yedek düzen
	_yedek_yazilar = [
		_yazi("", Rect2(y.position.x, y.position.y + 2, y.size.x, 15), 9, Stil.KAGIT_BEYAZ, Stil.serif_kalin()),
		_yazi("", Rect2(y.position.x, y.position.y + 18, y.size.x, 40), 34, Stil.MUREKKEP, Stil.serif_kalin()),
		_yazi("", Rect2(y.position.x, y.position.y + 58, y.size.x, 13), 9, Stil.MUREKKEP, Stil.serif_kalin()),
	]

	takvim = Hedef.new()
	takvim.tip = "takvim"
	takvim.etiket = "Bugünün tarihi"
	takvim.position = y.position
	takvim.size = y.size
	takvim.tiklandi.connect(func(h: Hedef) -> void: hedef_tiklandi.emit(h))
	add_child(takvim)

	# takvimin altında çevirmeli saat
	var s := Yerlesim.SAAT_ETIKETI
	var govde := TextureRect.new()
	govde.name = "CevirmeliSaat"
	govde.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	govde.stretch_mode = TextureRect.STRETCH_SCALE
	govde.texture = _doku("saat_govde")
	govde.position = s.position
	govde.size = s.size
	govde.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(govde)
	for i in 10:
		_rakamlar.append(_doku("saat_rakam_%d" % i))
	var p: Array = _eksenler.get("saat_pencere", [0.11, 0.32, 0.78, 0.43])
	var pencere := Rect2(s.position + Vector2(float(p[0]), float(p[1])) * s.size, Vector2(float(p[2]), float(p[3])) * s.size).grow(-1.0)
	# dört kart ve ortada iki nokta: kartlar pencerenin yüksekliğine oturur
	var kart_boyu := pencere.size.y
	var kart_eni := kart_boyu * 72.0 / 105.0
	var ara := 1.0
	var nokta_eni := kart_eni * 0.55
	var toplam := kart_eni * 4.0 + nokta_eni + ara * 4.0
	var x := pencere.position.x + (pencere.size.x - toplam) / 2.0
	for i in 5:
		var kart := TextureRect.new()
		kart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		kart.mouse_filter = MOUSE_FILTER_IGNORE
		if i == 2:
			kart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			kart.texture = _doku("saat_iki_nokta")
			kart.position = Vector2(x, pencere.position.y)
			kart.size = Vector2(nokta_eni, kart_boyu)
			kart.clip_contents = true
			x += nokta_eni + ara
		else:
			kart.stretch_mode = TextureRect.STRETCH_SCALE
			kart.position = Vector2(x, pencere.position.y)
			kart.size = Vector2(kart_eni, kart_boyu)
			kart.pivot_offset = kart.size / 2.0
			_kartlar.append(kart)
			x += kart_eni + ara
		add_child(kart)
	_guncelle()


func _doku(ad: String) -> Texture2D:
	var yol := Dil.yol(NESNE % ad)
	return load(yol) if ResourceLoader.exists(yol) else null


@warning_ignore("integer_division")
func _guncelle() -> void:
	queue_redraw()
	var d := int(dakika)
	if d == _son_dakika or _kartlar.size() != 4:
		return
	var eski := _son_dakika
	_son_dakika = d
	var haneler := [(d / 60) / 10 % 10, (d / 60) % 10, (d % 60) / 10, (d % 60) % 10]
	var eski_haneler := [(eski / 60) / 10 % 10, (eski / 60) % 10, (eski % 60) / 10, (eski % 60) % 10] if eski >= 0 else [-1, -1, -1, -1]
	for i in 4:
		var kart := _kartlar[i]
		var doku: Texture2D = _rakamlar[haneler[i]]
		if eski < 0 or haneler[i] == eski_haneler[i] or not is_inside_tree():
			kart.texture = doku
			continue
		# kart döner: düşeyde kapanır, yeni rakamla açılır
		var t := create_tween()
		t.tween_property(kart, "scale:y", 0.08, 0.07)
		t.tween_callback(func() -> void: kart.texture = doku)
		t.tween_property(kart, "scale:y", 1.0, 0.09)


func tarih_ayarla(tarih: String) -> void:
	var t := Tarih.coz(tarih)
	if t.is_empty():
		return
	takvim.deger = tarih
	var yaprak := _doku("takvim_%02d" % int(t.gun)) if int(t.ay) == 1 and int(t.yil) == 1984 else null
	_yaprak.texture = yaprak if yaprak != null else _doku("takvim_bos")
	var yedek := yaprak == null
	_yaprak.self_modulate = Color.WHITE if not yedek or _yaprak.texture != null else Color(0, 0, 0, 0)
	_yedek_yazilar[0].text = Stil.buyuk(Tarih.AYLAR[t.ay - 1]) + " " + str(t.yil) if yedek else ""
	_yedek_yazilar[1].text = str(t.gun) if yedek else ""
	_yedek_yazilar[2].text = Stil.buyuk(Tarih.haftanin_gunu(tarih)) if yedek else ""


func _yazi(metin: String, alan: Rect2, punto: int, renk: Color, font: Font) -> Label:
	var l := Stil.etiket(metin, punto, renk, font)
	l.position = alan.position
	l.size = alan.size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	add_child(l)
	return l


func _draw() -> void:
	var m := Yerlesim.SAAT_MERKEZ
	var r := Yerlesim.SAAT_YARICAP
	# kadranın rakamları: 12, 3, 6, 9 (çentiklerin iç yanında)
	var font := Stil.serif_kalin()
	var koyu := Color("2a2420")
	for i in 4:
		var metin: String = ["12", "3", "6", "9"][i]
		var yer := m + Vector2(0, -1).rotated(i * PI / 2.0) * (r * 0.60)
		var boyut := font.get_string_size(metin, HORIZONTAL_ALIGNMENT_LEFT, -1, 9)
		draw_string(font, yer + Vector2(-boyut.x / 2.0, boyut.y * 0.30), metin, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(koyu, 0.86))
	var saat_acisi := (fmod(dakika, 720.0) / 720.0) * TAU - PI / 2.0
	var dakika_acisi := (fmod(dakika, 60.0) / 60.0) * TAU - PI / 2.0
	_ibre(_akrep, "saat_akrep", m, saat_acisi, r * 0.52, koyu, 3.4)
	_ibre(_yelkovan, "saat_yelkovan", m, dakika_acisi, r * 0.80, koyu, 2.2)
	# göbek: pirinç başlıklı vida
	draw_circle(m + Vector2(0.6, 0.8), 3.4, Color(0, 0, 0, 0.25))
	draw_circle(m, 3.0, Color("3a2f26"))
	draw_circle(m, 1.7, Color("b08d4f"))
	draw_circle(m + Vector2(-0.5, -0.5), 0.7, Color("e6cf95"))


## Boyalı ibreyi (doku yatayda sağa bakar, ekseni solundaki halkadadır) merkezin çevresinde döndürür;
## önce kadrana düşen gölgesi, sonra kendisi çizilir. Doku yoksa düz çizgi çizilir.
func _ibre(doku: Texture2D, ad: String, m: Vector2, aci: float, boy: float, renk: Color, kalinlik: float) -> void:
	if doku == null:
		var yon := Vector2(cos(aci), sin(aci))
		draw_line(m - yon * 4.0, m + yon * boy, renk, kalinlik, true)
		return
	var eksen: Array = _eksenler.get(ad, [0.06, 0.5])
	var b := doku.get_size()
	var en := boy / (1.0 - float(eksen[0]))
	var boyut := Vector2(en, en * b.y / b.x)
	var kutu := Rect2(-Vector2(float(eksen[0]), float(eksen[1])) * boyut, boyut)
	draw_set_transform(m + Vector2(1.3, 1.8), aci, Vector2.ONE)
	draw_texture_rect(doku, kutu, false, Color(0, 0, 0, 0.22))
	draw_set_transform(m, aci, Vector2.ONE)
	draw_texture_rect(doku, kutu, false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
