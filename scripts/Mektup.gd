class_name Mektup
extends Control
## Çizgili defter yaprağına dolma kalemle yazılmış mektup (Hüsnü Amca'nın mektubu).

const BOYUT := Vector2(360, 408)


func kur(metin: String) -> void:
	name = "Mektup"
	size = BOYUT
	pivot_offset = BOYUT / 2.0
	mouse_filter = MOUSE_FILTER_IGNORE
	var l := Stil.etiket(metin, 17, Stil.MAVI_MUREKKEP, Stil.el_yazisi())
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_constant_override("line_spacing", -1)
	l.position = Vector2(30, 26)
	l.size = Vector2(BOYUT.x - 60.0, BOYUT.y - 44.0)
	add_child(l)
	queue_redraw()


func _draw() -> void:
	Kagit.ciz(self, Rect2(Vector2.ZERO, BOYUT), "sayfa", Stil.KAGIT_BEYAZ, 12.0, 3.0, Color(0.97, 0.96, 0.99))
	var y := 46.0
	while y < BOYUT.y - 20.0:
		draw_line(Vector2(22, y), Vector2(BOYUT.x - 22, y), Color(0.35, 0.45, 0.70, 0.22), 1.0)
		y += 21.0
