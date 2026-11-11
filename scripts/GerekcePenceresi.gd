class_name GerekcePenceresi
extends Control
## "Eksik Evrak" fişi bir belgeye bırakılınca açılır: geri çevirme gerekçesi seçilir.
## İnceleme modunda bulunan uyuşmazlıklar listede işaretli gelir.

signal secildi(gerekce: String)
signal vazgecildi

const GENISLIK := 330.0
const SATIR := 30.0

var _kodlar: Array[String] = []
var _kutu: Panel


## `gerekceler`: o gün geçerli gerekçe kodları; `bulunanlar`: incelemede yakalananlar.
func ac(gerekceler: Array[String], bulunanlar: Array, yakin: Vector2) -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	_kodlar = gerekceler

	var perde := ColorRect.new()
	perde.color = Color(0.06, 0.05, 0.04, 0.34)
	perde.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	perde.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(perde)

	var yukseklik := 40.0 + gerekceler.size() * SATIR + 46.0
	_kutu = Panel.new()
	_kutu.add_theme_stylebox_override("panel", Stil.kutu(Stil.KAGIT_BEYAZ, Stil.KIRMIZI, 2, 2, 10))
	_kutu.size = Vector2(GENISLIK, yukseklik)
	var p := yakin - Vector2(GENISLIK / 2.0, yukseklik / 2.0)
	p.x = clampf(p.x, 12.0, Yerlesim.EKRAN.size.x - GENISLIK - 12.0)
	p.y = clampf(p.y, 12.0, Yerlesim.EKRAN.size.y - yukseklik - 12.0)
	_kutu.position = p
	add_child(_kutu)

	var serit := ColorRect.new()
	serit.color = Stil.KIRMIZI
	serit.position = Vector2(2, 2)
	serit.size = Vector2(GENISLIK - 4.0, 28)
	serit.mouse_filter = MOUSE_FILTER_IGNORE
	_kutu.add_child(serit)
	var baslik := Stil.etiket("EKSİK EVRAK — GEREKÇESİ", 15, Stil.KAGIT_BEYAZ, Stil.daktilo_kalin())
	baslik.position = Vector2(0, 5)
	baslik.size = Vector2(GENISLIK, 22)
	baslik.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_kutu.add_child(baslik)

	var y := 38.0
	for i in gerekceler.size():
		var kod := gerekceler[i]
		var bulundu := bulunanlar.has(kod)
		var d := Button.new()
		d.name = "Gerekce_" + kod
		d.text = "%d. %s%s" % [i + 1, Dogrulayici.GEREKCELER.get(kod, kod), "  «" if bulundu else ""]
		d.alignment = HORIZONTAL_ALIGNMENT_LEFT
		d.focus_mode = FOCUS_NONE
		d.position = Vector2(10, y)
		d.size = Vector2(GENISLIK - 20.0, SATIR - 3.0)
		d.add_theme_font_size_override("font_size", 14)
		d.add_theme_font_override("font", Stil.daktilo_kalin() if bulundu else Stil.daktilo())
		d.add_theme_color_override("font_color", Stil.BORDO if bulundu else Stil.MUREKKEP)
		d.add_theme_stylebox_override("normal", Stil.bosluklu(Stil.kutu(Color(0, 0, 0, 0)), 8, 2))
		d.add_theme_stylebox_override("hover", Stil.bosluklu(Stil.kutu(Color(Stil.KIRMIZI, 0.14), Stil.KIRMIZI, 1), 8, 2))
		d.add_theme_stylebox_override("pressed", Stil.bosluklu(Stil.kutu(Color(Stil.KIRMIZI, 0.26), Stil.KIRMIZI, 1), 8, 2))
		d.pressed.connect(_sec.bind(kod))
		_kutu.add_child(d)
		y += SATIR

	var not_yazisi := Stil.etiket("« : incelemede bulduğunuz kusur", 10, Stil.MUREKKEP_SOLUK)
	not_yazisi.position = Vector2(14, y + 4.0)
	not_yazisi.visible = not bulunanlar.is_empty()
	_kutu.add_child(not_yazisi)

	var vazgec := Button.new()
	vazgec.name = "Vazgec"
	vazgec.text = "Vazgeç"
	vazgec.focus_mode = FOCUS_NONE
	vazgec.add_theme_font_size_override("font_size", 13)
	vazgec.size = Vector2(96, 28)
	vazgec.position = Vector2(GENISLIK - 108.0, y + 8.0)
	vazgec.pressed.connect(_vazgec)
	_kutu.add_child(vazgec)

	_kutu.pivot_offset = _kutu.size / 2.0
	_kutu.scale = Vector2(0.86, 0.86)
	modulate.a = 0.0
	var t := create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.10)
	t.parallel().tween_property(_kutu, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _gui_input(event: InputEvent) -> void:
	# kutunun dışına tıklamak vazgeçmektir
	if event is InputEventMouseButton and event.pressed:
		accept_event()
		_vazgec()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_vazgec()
	elif event.keycode >= KEY_1 and event.keycode <= KEY_9:
		var i: int = event.keycode - KEY_1
		if i < _kodlar.size():
			get_viewport().set_input_as_handled()
			_sec(_kodlar[i])


func _sec(kod: String) -> void:
	secildi.emit(kod)
	queue_free()


func _vazgec() -> void:
	vazgecildi.emit()
	queue_free()
