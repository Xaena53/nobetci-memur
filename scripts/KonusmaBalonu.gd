class_name KonusmaBalonu
extends Control
## Gişe camının yanındaki konuşma balonu. Metni harf harf yazar; kuyruğu cama bakar.

signal basladi          ## yazmaya başladı (vatandaşın ağzı oynar)
signal harf_yazildi
signal bitti            ## yazı tamamlandı

const HIZ := 42.0            ## saniyede harf
const PUNTO := 15
const IC_BOSLUK := Vector2(14, 11)

var _yazi: Label
var _gorunen := 0.0
var _toplam := 0
var _yaziyor := false
var _kalan_sure := 0.0
var _kutu := Rect2()


func _ready() -> void:
	position = Yerlesim.BALON.position
	size = Yerlesim.BALON.size
	mouse_filter = MOUSE_FILTER_IGNORE
	visible = false
	_yazi = Stil.etiket("", PUNTO)
	_yazi.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_yazi.add_theme_constant_override("line_spacing", 1)
	add_child(_yazi)


## Metni yazmaya başlar. `sure` > 0 ise yazı bittikten o kadar saniye sonra balon kapanır.
func soyle(metin: String, sure: float = 0.0) -> void:
	var genislik := size.x - 2.0 * IC_BOSLUK.x
	# Uzun söz balona sığmıyorsa punto küçülür.
	var punto := PUNTO
	var boyut := Stil.daktilo().get_multiline_string_size(metin, HORIZONTAL_ALIGNMENT_LEFT, genislik, punto)
	while punto > 11 and boyut.y + 2.0 * IC_BOSLUK.y + 6.0 + punto > size.y:
		punto -= 1
		boyut = Stil.daktilo().get_multiline_string_size(metin, HORIZONTAL_ALIGNMENT_LEFT, genislik, punto)
	_yazi.add_theme_font_size_override("font_size", punto)
	var yukseklik := minf(size.y, boyut.y + 2.0 * IC_BOSLUK.y + 4.0)
	_kutu = Rect2(0, 0, minf(size.x, maxf(120.0, boyut.x + 2.0 * IC_BOSLUK.x + 6.0)), yukseklik)
	_yazi.position = IC_BOSLUK
	_yazi.size = Vector2(genislik, yukseklik - 2.0 * IC_BOSLUK.y)
	_yazi.text = metin
	_yazi.visible_characters = 0
	_gorunen = 0.0
	_toplam = metin.length()
	_yaziyor = true
	_kalan_sure = sure
	visible = true
	modulate.a = 1.0
	queue_redraw()
	basladi.emit()


func sus() -> void:
	if _yaziyor:
		bitti.emit()
	_yaziyor = false
	visible = false


func konusuyor_mu() -> bool:
	return visible


func _process(delta: float) -> void:
	if not visible:
		return
	if _yaziyor:
		var once := int(_gorunen)
		_gorunen += HIZ * delta
		_yazi.visible_characters = mini(_toplam, int(_gorunen))
		if int(_gorunen) != once and int(_gorunen) % 2 == 0:
			harf_yazildi.emit()
		if _gorunen >= _toplam:
			_yaziyor = false
			_yazi.visible_characters = -1
			bitti.emit()
	elif _kalan_sure > 0.0:
		_kalan_sure -= delta
		if _kalan_sure <= 0.0:
			visible = false
		elif _kalan_sure < 0.3:
			modulate.a = _kalan_sure / 0.3


func _draw() -> void:
	var sb := Stil.kutu(Stil.KAGIT_BEYAZ, Stil.MUREKKEP, 2, 9, 5)
	draw_style_box(sb, _kutu)
	# cama bakan kuyruk
	var y := minf(_kutu.size.y - 24.0, 46.0)
	var uc := PackedVector2Array([Vector2(1, y), Vector2(-20, y + 13), Vector2(1, y + 18)])
	draw_colored_polygon(uc, Stil.KAGIT_BEYAZ)
	draw_polyline(PackedVector2Array([uc[0] + Vector2(0, -1), uc[1], uc[2] + Vector2(0, 1)]), Stil.MUREKKEP, 2.0, true)
