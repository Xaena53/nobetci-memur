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
	size = Vector2(100, 90) if tur == "onay" else Vector2(112, 59)
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


## Elde tutulan (büyütülmüş) bir belgenin altında kalan araç tıklanamaz: tık belgeye gider.
func _has_point(nokta: Vector2) -> bool:
	if not Rect2(Vector2.ZERO, size).has_point(nokta):
		return false
	if _surukleniyor:
		return true
	var ekranda := get_global_transform() * nokta
	for d in get_tree().get_nodes_in_group("elde_belge"):
		var b := d as Control
		if b != null and Rect2(Vector2.ZERO, b.size).has_point(b.get_global_transform().affine_inverse() * ekranda):
			return false
	return true


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


## Fiş koçanı: başlığı ve yazısıyla boyalı görsel (koçanın üst bölümü). Havale pusulasında kalan hak yazılır.
func _fis_ciz() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var doku := Serit.doku("fis_" + tur)
	if _surukleniyor:
		draw_rect(Rect2(r.position + Vector2(7, 11), r.size), Color(0, 0, 0, 0.22))
	else:
		draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0, 0, 0, 0.26))
	if doku != null:
		var b := doku.get_size()
		draw_texture_rect_region(doku, r, Rect2(0, 0, b.x, b.x * size.y / size.x))
	else:
		Kagit.parca_ciz(self, r, "sayfa", Stil.KAGIT_BEYAZ)
		draw_string(Stil.daktilo_kalin(), Vector2(0, 14), BASLIKLAR.get(tur, ""), HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, Stil.MUREKKEP)
	if tur == "havale" and kalan >= 0:
		draw_string(Stil.daktilo(), Vector2(0, size.y * 0.66), "kalan hak: %d" % kalan, HORIZONTAL_ALIGNMENT_CENTER, size.x, 12,
			Stil.MUREKKEP_SOLUK)
