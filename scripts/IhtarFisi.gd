class_name IhtarFisi
extends Control
## Müdürlükten masaya düşen pusula: pembe "İHTAR", sarı "UYARI" ya da kurşuni "NOT".
## Masaya perspektifle yatar; tıklanınca (ya da bir süre sonra) iğneye doğru süzülüp kaybolur.

signal kapandi

var tutucu: MasaNesnesi

const GENISLIK := 292.0
const OMUR := 9.0

var _baslik := "İHTAR"
var _metin := ""
var _alt := ""
var _zemin := Color("f2c4c4")
var _kenar := Stil.BORDO
var _kalan := OMUR
var _kapaniyor := false
var _cikis := Vector2.ZERO


## Pusulayı kurar ve müdürün odasından masaya süzülerek indirir.
## `cesit`: "ihtar" | "uyari" | "not". `no`: o günkü kaçıncı ihtar. `baslangic` ve `cikis` ekran koordinatı,
## `yer` pusulanın masada konacağı nokta (masa koordinatı).
func goster(metin: String, no: int, cesit: String, katman: Node, baslangic: Vector2, yer: Vector2, cikis: Vector2) -> void:
	_metin = metin
	_cikis = cikis
	match cesit:
		"uyari":
			_baslik = "UYARI"
			_alt = "İhtar sayılmaz; prim de yazılmaz."
			_zemin = Color("f0e0a4")
			_kenar = Color("8a6a1c")
		"not":
			_baslik = "NOT"
			_alt = "Bilginize."
			_zemin = Color("e7e3d3")
			_kenar = Stil.MAVI_MUREKKEP
		_:
			_baslik = "İHTAR  %d" % no
			_alt = "Günde üçüncü ihtardan itibaren maaş kesilir."
	mouse_filter = MOUSE_FILTER_STOP
	mouse_default_cursor_shape = CURSOR_POINTING_HAND

	var govde := Stil.daktilo().get_multiline_string_size(metin, HORIZONTAL_ALIGNMENT_LEFT, GENISLIK - 28.0, 13).y
	size = Vector2(GENISLIK, 42.0 + govde + 46.0)
	pivot_offset = size / 2.0

	var yazi := Stil.etiket(metin, 13)
	yazi.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	yazi.position = Vector2(14, 40)
	yazi.size = Vector2(GENISLIK - 28.0, govde)
	add_child(yazi)

	tutucu = MasaNesnesi.new()
	tutucu.name = "Tutucu_ihtar"
	katman.add_child(tutucu)
	tutucu.add_child(self)
	tutucu.ortala()
	tutucu.masa_konumu = yer
	tutucu.ekran_konumu = baslangic
	tutucu.yatis_acisi = deg_to_rad(randf_range(-4.0, 2.5))
	tutucu.kalkis = 1.0
	scale = Vector2(0.4, 0.4)
	modulate.a = 0.0
	var t := create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.08)
	t.parallel().tween_property(tutucu, "kalkis", 0.0, 0.46).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "scale", Vector2.ONE, 0.46).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## İğneye doğru süzülüp kaybolur.
func kapat() -> void:
	if _kapaniyor:
		return
	_kapaniyor = true
	mouse_filter = MOUSE_FILTER_IGNORE
	tutucu.gecisi_durdur()
	tutucu.ekran_konumu = _cikis
	var t := create_tween()
	t.tween_property(tutucu, "kalkis", 1.0, 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(self, "scale", Vector2(0.12, 0.12), 0.34)
	t.parallel().tween_property(self, "modulate:a", 0.0, 0.34)
	t.tween_callback(func() -> void:
		kapandi.emit()
		tutucu.queue_free())


func _process(delta: float) -> void:
	if _kapaniyor:
		return
	_kalan -= delta
	if _kalan <= 0.0:
		kapat()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		kapat()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(Rect2(r.position + Vector2(3, 5), r.size), Color(0, 0, 0, 0.30))
	draw_rect(r, _zemin)
	draw_rect(r, Color(_kenar, 0.9), false, 1.5)
	# koçandan koparılmış üst kenar
	var x := 6.0
	while x < size.x - 4.0:
		draw_circle(Vector2(x, 0), 2.2, Color(Stil.MASA_KOYU, 0.9))
		x += 9.0
	var f := Stil.daktilo_kalin()
	draw_string(f, Vector2(14, 25), _baslik, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, _kenar)
	draw_string(Stil.serif_italik(), Vector2(0, 24), "Müdürlük Makamından", HORIZONTAL_ALIGNMENT_RIGHT, size.x - 14.0, 11,
		Color(_kenar, 0.85))
	draw_line(Vector2(14, 34), Vector2(size.x - 14.0, 34), Color(_kenar, 0.7), 1.0)
	var alt_y := size.y - 14.0
	draw_string(Stil.daktilo(), Vector2(14, alt_y), _alt, HORIZONTAL_ALIGNMENT_LEFT, size.x - 28.0, 10, Color(Stil.MUREKKEP, 0.6))
	# müdürün parafı
	var p := PackedVector2Array()
	for i in 22:
		var u := i / 21.0
		p.append(Vector2(size.x - 86.0 + 62.0 * u, alt_y - 22.0 + 7.0 * sin(u * 17.0) * (1.0 - 0.5 * u) - 5.0 * u))
	draw_polyline(p, Stil.MAVI_MUREKKEP, 1.3, true)
