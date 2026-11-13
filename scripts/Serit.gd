class_name Serit
extends Control
## Kabartma şerit etiket (masadaki araçların, uyarıların üstündeki plastik bant). Yazısı sabit olanlar
## boyanmış görseldir ("MÜDÜR İZLİYOR", "İNCELE"...); sayı taşıyanlar boş şeridin üstüne kabartma harflerle
## yazılır ("İHTAR 2", "İPUCU 3").

const KLASOR := "res://assets/img/nesne/"

static var _dokular: Dictionary = {}

var doku_adi := "serit_bos":         ## KLASOR altındaki görselin adı
	set(a):
		doku_adi = a
		queue_redraw()
var metin := "":                     ## boş şeridin üstüne yazılacak yazı (boşsa görseldeki yazı görünür)
	set(m):
		metin = Dil.c(m)
		queue_redraw()
var parlak := false:                 ## yazı sıcak sarıya döner (açık durumu)
	set(p):
		parlak = p
		queue_redraw()


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


static func olustur(ad: String, boyut: Vector2, yazi: String = "") -> Serit:
	var s := Serit.new()
	s.doku_adi = ad
	s.metin = yazi
	s.size = boyut
	return s


static func doku(ad: String) -> Texture2D:
	# yazılı görsellerin dile özgü hâli varsa o yüklenir (bkz. Dil.yol); önbellek dile göre tutulur
	var anahtar := Dil.kod + "/" + ad
	if not _dokular.has(anahtar):
		var yol := Dil.yol(KLASOR + ad + ".webp")
		_dokular[anahtar] = load(yol) if ResourceLoader.exists(yol) else null
	return _dokular[anahtar]


func _draw() -> void:
	var d := doku(doku_adi)
	if d != null:
		draw_texture_rect(d, Rect2(Vector2.ZERO, size), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color("1d1b19"))
	if metin == "":
		return
	# kabartma harf: altta koyu gölge, üstte açık yazı
	var font := Stil.daktilo_kalin()
	var punto := maxi(7, roundi(size.y * 0.58))
	while punto > 6 and font.get_string_size(metin, HORIZONTAL_ALIGNMENT_LEFT, -1, punto).x > size.x - 12.0:
		punto -= 1
	var taban := size.y * 0.5 + punto * 0.36
	draw_string(font, Vector2(0, taban + 1.0), metin, HORIZONTAL_ALIGNMENT_CENTER, size.x, punto, Color(0, 0, 0, 0.55))
	draw_string(font, Vector2(0, taban), metin, HORIZONTAL_ALIGNMENT_CENTER, size.x, punto,
		Color("ffd9a0") if parlak else Color(0.96, 0.95, 0.90))
