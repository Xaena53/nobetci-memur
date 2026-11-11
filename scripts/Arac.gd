class_name Arac
extends Control
## Tepsideki sürüklenebilir karar araçları: onay mührü, "eksik evrak" fişi, "amire havale" pusulası.
## Bir belgenin üstüne bırakılınca karar verilir; boşa bırakılırsa yerine döner.

signal alindi(arac: Arac)
signal birakildi(arac: Arac, konum: Vector2)

const BASLIKLAR := {"eksik": "EKSİK EVRAK", "havale": "MÜDÜRE HAVALE"}
const MUHUR_DOKUSU := "res://assets/img/nesne/muhur.webp"

var tur := "onay"            ## "onay" | "eksik" | "havale"
var ev := Vector2.ZERO       ## tepsideki yeri
var kalan := -1:             ## kalan hak (−1: sınırsız)
	set(k):
		kalan = k
		queue_redraw()
var etkin := true:
	set(e):
		etkin = e
		modulate.a = 1.0 if e else 0.42
		mouse_default_cursor_shape = CURSOR_DRAG if e else CURSOR_ARROW

var _surukleniyor := false
var _donus: Tween
var _doku: Texture2D


func kur(arac_turu: String, yer: Vector2) -> void:
	tur = arac_turu
	ev = yer
	position = yer
	size = Vector2(98, 98) if tur == "onay" else Vector2(172, 50)
	pivot_offset = size / 2.0
	mouse_default_cursor_shape = CURSOR_DRAG
	if tur == "onay" and ResourceLoader.exists(MUHUR_DOKUSU):
		_doku = load(MUHUR_DOKUSU)
	queue_redraw()


func kullanilabilir() -> bool:
	return etkin and kalan != 0


func _gui_input(event: InputEvent) -> void:
	if not kullanilabilir():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_surukleniyor = true
			if _donus != null:
				_donus.kill()
			move_to_front()
			scale = Vector2.ONE * 1.08
			queue_redraw()
			alindi.emit(self)
		elif _surukleniyor:
			_surukleniyor = false
			scale = Vector2.ONE
			queue_redraw()
			birakildi.emit(self, get_global_transform() * event.position)
		accept_event()
	elif event is InputEventMouseMotion and _surukleniyor:
		global_position = get_global_transform() * event.position - size / 2.0
		accept_event()


## Yerine döner. `aninda` ise canlandırma yapmaz (karar verildikten sonra).
func eve_don(aninda: bool = false) -> void:
	_surukleniyor = false
	scale = Vector2.ONE
	if _donus != null:
		_donus.kill()
	if aninda:
		position = ev
		return
	_donus = create_tween()
	_donus.tween_property(self, "position", ev, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	if tur == "onay":
		_muhur_ciz()
	else:
		_fis_ciz()


func _muhur_ciz() -> void:
	var alan := Rect2(Vector2.ZERO, size)
	if _surukleniyor:
		draw_circle(size / 2.0 + Vector2(8, 12), size.x * 0.36, Color(0, 0, 0, 0.18))
	if _doku != null:
		draw_texture_rect(_doku, alan, false)
	else:
		draw_rect(Rect2(20, 54, 58, 26), Stil.BORDO)
		draw_rect(Rect2(40, 12, 18, 44), Stil.MASA_KOYU)
		draw_circle(Vector2(49, 14), 14, Stil.MASA_KOYU)


func _fis_ciz() -> void:
	var kenar := Stil.KIRMIZI if tur == "eksik" else Stil.MAVI_MUREKKEP
	var r := Rect2(Vector2.ZERO, size)
	if not _surukleniyor:
		# koçan: alttaki fişlerin kenarları
		draw_rect(Rect2(r.position + Vector2(4, 5), r.size), Color(0, 0, 0, 0.25))
		draw_rect(Rect2(r.position + Vector2(3, 3), r.size), Stil.KAGIT_ESKI)
		draw_rect(Rect2(r.position + Vector2(1.5, 1.5), r.size), Stil.KAGIT)
	else:
		draw_rect(Rect2(r.position + Vector2(6, 9), r.size), Color(0, 0, 0, 0.22))
	draw_rect(r, Stil.KAGIT_BEYAZ)
	draw_rect(Rect2(0, 0, size.x, 19), kenar)
	draw_rect(r, kenar, false, 2.0)
	var f := Stil.daktilo_kalin()
	draw_string(f, Vector2(0, 14), BASLIKLAR.get(tur, ""), HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, Stil.KAGIT_BEYAZ)
	var alt := "Belgenin üstüne bırakın"
	if tur == "havale" and kalan >= 0:
		alt = "Bugün kalan hak: %d" % kalan
	draw_string(Stil.daktilo(), Vector2(0, 38), alt, HORIZONTAL_ALIGNMENT_CENTER, size.x, 11, Stil.MUREKKEP_SOLUK)
