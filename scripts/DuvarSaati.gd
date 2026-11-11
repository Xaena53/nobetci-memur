class_name DuvarSaati
extends Control
## Duvardaki saat ve yapraklı takvim. Arka plandaki boş kadrana akrep-yelkovan çizer,
## takvim yaprağına günün tarihini yazar. Takvim, inceleme modunda bir hedeftir.

signal hedef_tiklandi(hedef: Hedef)

var dakika := 540.0:   ## gece yarısından beri geçen oyun dakikası
	set(d):
		dakika = d
		_guncelle()

var takvim: Hedef

var _dijital: Label
var _gun_no: Label
var _ay: Label
var _gun_adi: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	var y := Yerlesim.TAKVIM_YAPRAK

	_ay = _yazi("", Rect2(y.position.x, y.position.y + 3, y.size.x, 12), 9, Stil.MUREKKEP, Stil.serif_kalin())
	_gun_no = _yazi("", Rect2(y.position.x, y.position.y + 10, y.size.x, 40), 32, Stil.BORDO, Stil.serif_kalin())
	_gun_adi = _yazi("", Rect2(y.position.x, y.position.y + 50, y.size.x, 12), 8, Stil.MUREKKEP, Stil.serif())

	takvim = Hedef.new()
	takvim.tip = "takvim"
	takvim.etiket = "Bugünün tarihi"
	takvim.position = y.position
	takvim.size = y.size
	takvim.tiklandi.connect(func(h: Hedef) -> void: hedef_tiklandi.emit(h))
	add_child(takvim)

	# takvimin altında, duvara yapıştırılmış şerit etiket: dijital saat
	var s := Yerlesim.SAAT_ETIKETI
	var serit := Panel.new()
	serit.position = s.position
	serit.size = s.size
	serit.mouse_filter = MOUSE_FILTER_IGNORE
	serit.add_theme_stylebox_override("panel", Stil.kutu(Color("1d1b19"), Color(0, 0, 0, 0.5), 1, 2, 2))
	add_child(serit)
	_dijital = _yazi("09:00", Rect2(s.position + Vector2(0, -1), s.size), 14, Stil.KAGIT_BEYAZ, Stil.daktilo_kalin())
	_guncelle()


@warning_ignore("integer_division")
func _guncelle() -> void:
	queue_redraw()
	if _dijital != null:
		_dijital.text = "%02d:%02d" % [int(dakika) / 60, int(dakika) % 60]


func tarih_ayarla(tarih: String) -> void:
	var t := Tarih.coz(tarih)
	if t.is_empty():
		return
	_gun_no.text = str(t.gun)
	_ay.text = Stil.buyuk(Tarih.AYLAR[t.ay - 1]) + " " + str(t.yil)
	_gun_adi.text = Stil.buyuk(Tarih.haftanin_gunu(tarih))
	takvim.deger = tarih


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
	var saat_acisi := (fmod(dakika, 720.0) / 720.0) * TAU - PI / 2.0
	var dakika_acisi := (fmod(dakika, 60.0) / 60.0) * TAU - PI / 2.0
	var koyu := Color("26211c")
	_ibre(m, saat_acisi, r * 0.50, 3.4, koyu)
	_ibre(m, dakika_acisi, r * 0.76, 2.2, koyu)
	draw_circle(m, 3.0, koyu)
	draw_circle(m, 1.2, Color("8a6a44"))


func _ibre(m: Vector2, aci: float, boy: float, kalinlik: float, renk: Color) -> void:
	var yon := Vector2(cos(aci), sin(aci))
	draw_line(m + Vector2(1.2, 1.6) - yon * 4.0, m + Vector2(1.2, 1.6) + yon * boy, Color(0, 0, 0, 0.22), kalinlik, true)
	draw_line(m - yon * 4.0, m + yon * boy, renk, kalinlik, true)
