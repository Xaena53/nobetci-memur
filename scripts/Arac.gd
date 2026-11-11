class_name Arac
extends Control
## Tepsideki sürüklenebilir karar araçları: onay mührü, "eksik evrak" fişi, "müdüre havale" pusulası.
## Bir belgenin üstüne bırakılınca karar verilir; boşa bırakılırsa tepsideki yerine döner.
## Araç tepside masa perspektifiyle yatar; ele alınınca düzleşip imleci izler (MasaNesnesi).

signal alindi(arac: Arac)
signal birakildi(arac: Arac, konum: Vector2)

const BASLIKLAR := {"eksik": "EKSİK EVRAK", "havale": "MÜDÜRE HAVALE"}
const MUHUR_DOKUSU := "res://assets/img/nesne/muhur.webp"

var tur := "onay"            ## "onay" | "eksik" | "havale"
var tutucu: MasaNesnesi
var kalan := -1:             ## kalan hak (−1: sınırsız)
	set(k):
		kalan = k
		queue_redraw()
var etkin := true:
	set(e):
		etkin = e
		modulate.a = 1.0 if e else 0.45
		mouse_default_cursor_shape = CURSOR_DRAG if e else CURSOR_ARROW

var _surukleniyor := false
var _doku: Texture2D


## Aracı kurar ve tepsideki yerine (masa koordinatı, ortası) koyar.
func kur(arac_turu: String, yer: Vector2, katman: Node) -> void:
	tur = arac_turu
	name = "Arac_" + tur
	size = Vector2(100, 90) if tur == "onay" else Vector2(136, 44)
	pivot_offset = size / 2.0
	mouse_default_cursor_shape = CURSOR_DRAG
	if tur == "onay" and ResourceLoader.exists(MUHUR_DOKUSU):
		_doku = load(MUHUR_DOKUSU)
	tutucu = MasaNesnesi.new()
	tutucu.name = "Tutucu_" + tur
	katman.add_child(tutucu)
	tutucu.add_child(self)
	tutucu.ortala()
	tutucu.masa_konumu = yer
	queue_redraw()


func kullanilabilir() -> bool:
	return etkin and kalan != 0


func _gui_input(event: InputEvent) -> void:
	if not kullanilabilir():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var fare: Vector2 = get_global_transform() * event.position
		if event.pressed:
			_surukleniyor = true
			tutucu.gecisi_durdur()
			tutucu.ekran_konumu = fare
			tutucu.kalkis = 1.0
			tutucu.move_to_front()
			scale = Vector2.ONE * 1.1
			queue_redraw()
			alindi.emit(self)
		elif _surukleniyor:
			_surukleniyor = false
			scale = Vector2.ONE
			queue_redraw()
			birakildi.emit(self, fare)
		accept_event()
	elif event is InputEventMouseMotion and _surukleniyor:
		tutucu.ekran_konumu = get_global_transform() * event.position
		accept_event()


## Tepsideki yerine döner. `aninda` ise canlandırma yapmaz.
func eve_don(aninda: bool = false) -> void:
	_surukleniyor = false
	scale = Vector2.ONE
	queue_redraw()
	if aninda:
		tutucu.gecisi_durdur()
		tutucu.kalkis = 0.0
	else:
		tutucu.kalkisa_gec(0.0, 0.26)


func _draw() -> void:
	if tur == "onay":
		_muhur_ciz()
	else:
		_fis_ciz()


func _muhur_ciz() -> void:
	var alan := Rect2(Vector2.ZERO, size)
	if _surukleniyor:
		draw_circle(size / 2.0 + Vector2(10, 16), size.x * 0.34, Color(0, 0, 0, 0.20))
	if _doku != null:
		draw_texture_rect(_doku, alan, false)
	else:
		draw_rect(Rect2(20, 50, 58, 26), Stil.BORDO)
		draw_rect(Rect2(40, 10, 18, 44), Stil.MASA_KOYU)
		draw_circle(Vector2(49, 12), 13, Stil.MASA_KOYU)


func _fis_ciz() -> void:
	var kenar := Stil.KIRMIZI if tur == "eksik" else Stil.MAVI_MUREKKEP
	var r := Rect2(Vector2.ZERO, size)
	if not _surukleniyor:
		# koçan: alttaki fişlerin kenarları
		draw_rect(Rect2(r.position + Vector2(4, 5), r.size), Color(0, 0, 0, 0.28))
		Kagit.parca_ciz(self, Rect2(r.position + Vector2(3, 3), r.size), "sayfa", Stil.KAGIT_ESKI, Color(0.86, 0.86, 0.86))
		Kagit.parca_ciz(self, Rect2(r.position + Vector2(1.5, 1.5), r.size), "sayfa", Stil.KAGIT, Color(0.93, 0.93, 0.93))
	else:
		draw_rect(Rect2(r.position + Vector2(7, 11), r.size), Color(0, 0, 0, 0.22))
	Kagit.parca_ciz(self, r, "sayfa", Stil.KAGIT_BEYAZ)
	draw_rect(Rect2(0, 0, size.x, 18), Color(kenar, 0.92))
	draw_rect(r, Color(kenar, 0.9), false, 1.5)
	draw_string(Stil.daktilo_kalin(), Vector2(0, 14), BASLIKLAR.get(tur, ""), HORIZONTAL_ALIGNMENT_CENTER, size.x, 13,
		Stil.KAGIT_BEYAZ)
	var alt := "belgeye bırak"
	if tur == "havale" and kalan >= 0:
		alt = "kalan hak: %d" % kalan
	draw_string(Stil.daktilo(), Vector2(0, 35), alt, HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, Stil.MUREKKEP_SOLUK)
