class_name IhtarFisi
extends Control
## Teleksten çıkan pusula: pembe "İHTAR", sarımsı "UYARI" ya da kurşuni "NOT".
## Teleks onu satır satır basar (bkz. Teleks.gd); koptuktan sonra masada, cihazın önünde durur.
## Tıklanınca (ya da bir süre sonra) ihtar iğnesine doğru süzülüp kaybolur.

signal kapandi

const GENISLIK := 194.0       ## kâğıdın eni (masa koordinatı)
const KENAR := 31.0           ## iki yandaki dişli delikleri için pay
const SATIR := 15.0
const PUNTO := 12
const SATIR_HARFI := 18       ## bir satıra sığan harf sayısı
const OMUR := 14.0            ## masada kalma süresi (sn)

var tutucu: MasaNesnesi
var cesit := "ihtar"
var adimlar: Array[float] = []   ## teleksin her vuruşta kâğıdı ne kadar süreceği

var _baslik := "İHTAR"
var _satirlar := PackedStringArray()
var _renk := Stil.BORDO
var _ton := Color.WHITE
var _kalan := OMUR
var _masada := false
var _kapaniyor := false
var _cikis := Vector2.ZERO


## Pusulanın içeriğini kurar; boyutunu ve basım adımlarını hesaplar.
func hazirla(metin: String, no: int, cesidi: String) -> void:
	cesit = cesidi
	match cesit:
		"uyari":
			_baslik = "UYARI"
			_renk = Color("7a5a12")
			_ton = Color(1.0, 1.10, 0.78)
		"not":
			_baslik = "NOT"
			_renk = Stil.MAVI_MUREKKEP
			_ton = Color(0.90, 1.06, 1.12)
		_:
			_baslik = "İHTAR %d" % no
	_satirlar = sar(metin, SATIR_HARFI)
	var govde := _satirlar.size() * SATIR
	size = Vector2(GENISLIK, 16.0 + 20.0 + 8.0 + govde + 8.0 + 14.0 + 16.0)
	pivot_offset = size / 2.0
	mouse_filter = MOUSE_FILTER_IGNORE
	# önce başlık, sonra her satır, en sonda imza ve koparma payı
	adimlar = [36.0, 8.0]
	for i in _satirlar.size():
		adimlar.append(SATIR)
	adimlar.append(22.0)
	adimlar.append(size.y - 66.0 - govde)


## Teleksten koptuktan sonra: pusula masada kendi taşıyıcısına geçer ve tıklanabilir olur.
func masaya_birak(katman: Node, masa_konumu: Vector2, cikis: Vector2) -> void:
	_cikis = cikis
	if get_parent() != null:
		get_parent().remove_child(self)
	position = Vector2.ZERO
	tutucu = MasaNesnesi.new()
	tutucu.name = "Tutucu_fis"
	katman.add_child(tutucu)
	tutucu.add_child(self)
	tutucu.ortala()
	tutucu.masa_konumu = masa_konumu
	_masada = true
	mouse_filter = MOUSE_FILTER_STOP
	mouse_default_cursor_shape = CURSOR_POINTING_HAND
	# koparken hafifçe öne kayıp yan yatar
	var t := create_tween().set_parallel(true)
	t.tween_property(tutucu, "masa_konumu", masa_konumu + Vector2(randf_range(-8.0, 8.0), 16.0), 0.22) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(tutucu, "yatis_acisi", deg_to_rad(randf_range(-4.0, 4.0)), 0.22)


## İğneye doğru süzülüp kaybolur.
func kapat() -> void:
	if _kapaniyor or tutucu == null:
		return
	_kapaniyor = true
	mouse_filter = MOUSE_FILTER_IGNORE
	tutucu.gecisi_durdur()
	tutucu.ekran_konumu = _cikis
	var t := create_tween()
	t.tween_property(tutucu, "kalkis", 1.0, 0.36).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(self, "scale", Vector2(0.14, 0.14), 0.36)
	t.parallel().tween_property(self, "modulate:a", 0.0, 0.36)
	t.tween_callback(func() -> void:
		kapandi.emit()
		tutucu.queue_free())


func _process(delta: float) -> void:
	if not _masada or _kapaniyor:
		return
	_kalan -= delta
	if _kalan <= 0.0:
		kapat()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		kapat()


func _draw() -> void:
	_kagit_ciz()
	var x := KENAR
	var genislik := size.x - 2.0 * KENAR
	draw_string(Stil.daktilo_kalin(), Vector2(x, 31.0), _baslik, HORIZONTAL_ALIGNMENT_LEFT, genislik, 15, _renk)
	draw_line(Vector2(x, 38.0), Vector2(size.x - KENAR, 38.0), Color(_renk, 0.75), 1.0)
	var y := 44.0 + PUNTO
	for satir in _satirlar:
		draw_string(Stil.daktilo(), Vector2(x, y), satir, HORIZONTAL_ALIGNMENT_LEFT, -1, PUNTO, Stil.MUREKKEP)
		y += SATIR
	draw_string(Stil.daktilo_kalin(), Vector2(x, y + 9.0), "— MÜDÜR", HORIZONTAL_ALIGNMENT_RIGHT, genislik, 10,
		Color(_renk, 0.9))


## Dişli delikli teleks kâğıdı: doku, boyu uzadıkça delik aralığı bozulmasın diye iki parça çizilir.
func _kagit_ciz() -> void:
	var d := Kagit.doku("teleks")
	if d == null:
		draw_rect(Rect2(Vector2.ZERO, size), Color("f2c4c4") * _ton)
		return
	var b := d.get_size()
	var oran := b.x / size.x
	var alt := 16.0
	draw_rect(Rect2(Vector2(3, 5), size), Color(0, 0, 0, 0.22))
	draw_texture_rect_region(d, Rect2(0, 0, size.x, size.y - alt), Rect2(0, 0, b.x, (size.y - alt) * oran), _ton)
	draw_texture_rect_region(d, Rect2(0, size.y - alt, size.x, alt), Rect2(0, b.y - alt * oran, b.x, alt * oran), _ton)


## Metni, kelimeleri bölmeden en çok `en` harflik satırlara sarar.
static func sar(metin: String, en: int) -> PackedStringArray:
	var satirlar := PackedStringArray()
	var satir := ""
	for kelime in metin.split(" ", false):
		if satir == "":
			satir = kelime
		elif satir.length() + 1 + kelime.length() <= en:
			satir += " " + kelime
		else:
			satirlar.append(satir)
			satir = kelime
	if satir != "":
		satirlar.append(satir)
	return satirlar
