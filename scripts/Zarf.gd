class_name Zarf
extends Control
## Gişe yarığından masaya itilen rüşvet zarfı. Altında iki seçenek durur: çekmeceye atmak ya da
## geri itmek. Oyuncu hiçbirini seçmezse zarf sahibiyle birlikte geri gider.

signal alindi(tutar: int)
signal geri_itildi

const DOKU := "res://assets/img/nesne/zarf.webp"
const BOYUT := Vector2(112, 115)

var tutar := 0
var tutucu: MasaNesnesi
var sonuclandi := false      ## oyuncu seçimini yaptı ya da zarf geri gitti

var _doku: Texture2D
var _secenekler: Control


## Zarfı kurar. `katman`: masadaki nesnelerin katmanı; `ust_katman`: düğmelerin duracağı ekran katmanı.
func kur(zarf_tutari: int, katman: Node, ust_katman: Control) -> void:
	tutar = zarf_tutari
	name = "Zarf"
	size = BOYUT
	pivot_offset = BOYUT / 2.0
	mouse_filter = MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(DOKU):
		_doku = load(DOKU)
	tutucu = MasaNesnesi.new()
	tutucu.name = "Tutucu_Zarf"
	katman.add_child(tutucu)
	tutucu.add_child(self)
	tutucu.ortala()

	_secenekler = Control.new()
	_secenekler.name = "ZarfSecenekleri"
	_secenekler.mouse_filter = MOUSE_FILTER_IGNORE
	_secenekler.visible = false
	ust_katman.add_child(_secenekler)
	_dugme("ZarfAl", "ÇEKMECEYE AT", Stil.BORDO, 0.0).pressed.connect(al)
	_dugme("ZarfGeri", "GERİ İT", Color("1d1b19"), 126.0).pressed.connect(geri_it)


func _dugme(ad: String, yazi: String, zemin: Color, x: float) -> Button:
	var d := Button.new()
	d.name = ad
	d.text = yazi
	d.focus_mode = FOCUS_NONE
	d.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	d.add_theme_font_override("font", Stil.daktilo_kalin())
	d.add_theme_font_size_override("font_size", 11)
	d.add_theme_color_override("font_color", Stil.KAGIT_BEYAZ)
	d.add_theme_color_override("font_hover_color", Color("ffd9a0"))
	d.add_theme_color_override("font_pressed_color", Color("ffd9a0"))
	d.add_theme_stylebox_override("normal", Stil.bosluklu(Stil.kutu(zemin, Color(0, 0, 0, 0.45), 1, 2, 2), 6, 3))
	d.add_theme_stylebox_override("hover", Stil.bosluklu(Stil.kutu(zemin.lightened(0.12), Color("ffd9a0"), 1, 2, 2), 6, 3))
	d.add_theme_stylebox_override("pressed", Stil.bosluklu(Stil.kutu(zemin.darkened(0.15), Color("ffd9a0"), 1, 2, 2), 6, 3))
	d.position = Vector2(x, 0)
	d.size = Vector2(120, 22)
	_secenekler.add_child(d)
	return d


## Zarf yarıktan masadaki yerine kayar; durunca seçenekler belirir.
func gel(yarik: Vector2, hedef_masa: Vector2, gecikme: float = 0.0) -> void:
	tutucu.ekran_konumu = yarik
	tutucu.masa_konumu = hedef_masa
	tutucu.yatis_acisi = deg_to_rad(-7.0)
	tutucu.kalkis = 1.0
	scale = Vector2(0.30, 0.08)
	modulate.a = 0.0
	var t := create_tween()
	t.tween_interval(gecikme)
	t.tween_property(self, "modulate:a", 1.0, 0.06)
	t.parallel().tween_property(tutucu, "kalkis", 0.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "scale", Vector2.ONE, 0.44).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_callback(func() -> void:
		if sonuclandi:
			return
		var m := Perspektif.ekrana(hedef_masa)
		_secenekler.position = Vector2(m.x - 123.0, m.y + 52.0)
		_secenekler.modulate.a = 0.0
		_secenekler.visible = true
		_secenekler.create_tween().tween_property(_secenekler, "modulate:a", 1.0, 0.2))


## Oyuncu zarfı çekmecesine atar: zarf masanın alt kenarından kayıp gider.
func al() -> void:
	if sonuclandi:
		return
	sonuclandi = true
	_secenekleri_kaldir()
	alindi.emit(tutar)
	var t := create_tween()
	t.tween_property(tutucu, "masa_konumu", tutucu.masa_konumu + Vector2(40, 330), 0.42) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(self, "modulate:a", 0.0, 0.42)
	t.tween_callback(tutucu.queue_free)


## Oyuncu zarfı geri iter.
func geri_it() -> void:
	if sonuclandi:
		return
	geri_itildi.emit()
	geri_git()


## Zarf yarıktan geri çıkar (oyuncu itti ya da sahibi alıp gitti).
func geri_git() -> void:
	if sonuclandi:
		return
	sonuclandi = true
	_secenekleri_kaldir()
	tutucu.ekran_konumu = Yerlesim.GISE_YARIK
	var t := create_tween()
	t.tween_property(tutucu, "kalkis", 1.0, 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(self, "scale", Vector2(0.30, 0.08), 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_property(self, "modulate:a", 0.0, 0.05)
	t.tween_callback(tutucu.queue_free)


func _secenekleri_kaldir() -> void:
	if is_instance_valid(_secenekler):
		_secenekler.queue_free()


func _exit_tree() -> void:
	_secenekleri_kaldir()


func _draw() -> void:
	if _doku != null:
		draw_texture_rect(_doku, Rect2(Vector2.ZERO, size), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Stil.KAGIT_ESKI)
		draw_rect(Rect2(Vector2.ZERO, size), Stil.MUREKKEP_SOLUK, false, 1.5)
