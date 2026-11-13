class_name GenelgeEkrani
extends Control
## Sabah: masada günün gazetesinden bir kupür ve müdürün daktiloyla yazılmış genelgesi durur.
## Genelge daktilo gibi harf harf belirir; tıklayınca tamamı görünür. Okununca gişe açılır.

signal kapandi
signal harf_yazildi

const KAGIT := Vector2(520, 596)
const HIZ := 70.0      ## saniyede harf

var _govde: Label
var _imza: Control                      ## müdürün imzası: yazı bitince atılır
var _dugme: Button
var _gorunen := 0.0
var _toplam := 0
var _yaziyor := true


## gun: günün verisi (data/gunler); gun_no: kaçıncı gün.
func ac(gun: Dictionary, gun_no: int) -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP

	var perde := ColorRect.new()
	perde.color = Color(0.07, 0.06, 0.05, 0.62)
	perde.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	perde.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(perde)

	var kagit := Control.new()
	kagit.name = "Kagit"
	kagit.size = KAGIT
	kagit.position = (Yerlesim.EKRAN.size - KAGIT) / 2.0 + Vector2(0, -8)
	var haber := Hikaye.gazete(gun_no, Oyun.bayraklar)
	if not haber.is_empty():
		kagit.position.x = 652.0
		var gazete := Gazete.new()
		gazete.name = "Gazete"
		add_child(gazete)
		gazete.kur(424.0, str(gun.get("tarih", "")), haber)
		gazete.position = Vector2(118.0, (Yerlesim.EKRAN.size.y - gazete.size.y) / 2.0 - 10.0)
		gazete.rotation = deg_to_rad(-2.4)
	kagit.mouse_filter = MOUSE_FILTER_IGNORE
	kagit.draw.connect(func() -> void: Kagit.ciz(kagit, Rect2(Vector2.ZERO, KAGIT), "daktilo_sayfa", Stil.KAGIT, 14.0, 4.0))
	add_child(kagit)

	var g: Dictionary = gun.get("genelge", {})
	var tarih := str(gun.get("tarih", ""))
	var x := 56.0
	var w := KAGIT.x - 2.0 * x
	_yaz(kagit, "T.C.", Rect2(0, 62, KAGIT.x, 16), 12, Stil.MUREKKEP_SOLUK, Stil.serif_kalin(), true)
	_yaz(kagit, "ARDIÇLI İLÇESİ NÜFUS MÜDÜRLÜĞÜ", Rect2(0, 78, KAGIT.x, 20), 15, Stil.MUREKKEP, Stil.serif_kalin(), true)
	var cizgi := ColorRect.new()
	cizgi.color = Color(Stil.MUREKKEP, 0.75)
	cizgi.position = Vector2(x, 104)
	cizgi.size = Vector2(w, 1.5)
	cizgi.mouse_filter = MOUSE_FILTER_IGNORE
	kagit.add_child(cizgi)
	_yaz(kagit, "GENELGE", Rect2(x, 116, 200, 22), 18, Stil.BORDO, Stil.daktilo_kalin())
	_yaz(kagit, Dil.c("Sayı : %s\nTarih: %s") % [str(g.get("sayi", "")), tarih], Rect2(x + w - 150, 114, 150, 36), 12, Stil.MUREKKEP)
	_yaz(kagit, Dil.c("Konu : %s") % Dil.c(str(g.get("konu", ""))), Rect2(x, 146, w, 18), 13, Stil.MUREKKEP, Stil.daktilo_kalin())
	_yaz(kagit, Dil.c("%d. gün — %s") % [gun_no, Tarih.uzun(tarih)], Rect2(x, 166, w, 16), 11, Stil.MUREKKEP_SOLUK, Stil.daktilo_italik())

	var metin := Dil.c(str(g.get("metin", "")))
	_govde = _yaz(kagit, metin, Rect2(x, 198, w, 250), 14, Stil.MUREKKEP, null, false, true)
	_govde.add_theme_constant_override("line_spacing", 3)
	_govde.visible_characters = 0
	_govde.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING   # yazarken kelimeler satır değiştirmesin
	_toplam = metin.length()

	_yaz(kagit, "Müdür", Rect2(x + w - 150, 492, 150, 16), 12, Stil.MUREKKEP, Stil.daktilo_kalin(), true)
	var imza := Control.new()
	imza.position = Vector2(x + w - 160, 428)
	imza.size = Vector2(160, 66)
	imza.mouse_filter = MOUSE_FILTER_IGNORE
	imza.draw.connect(func() -> void:
		Imza.ciz(imza, Rect2(Vector2.ZERO, imza.size), "mudur", Stil.MAVI_MUREKKEP))
	kagit.add_child(imza)
	imza.modulate.a = 0.0          # yazı bitince müdür imzalar
	_imza = imza

	_dugme = Button.new()
	_dugme.name = "GiseyiAc"
	_dugme.text = "Gişeyi Aç"
	_dugme.focus_mode = FOCUS_NONE
	_dugme.custom_minimum_size = Vector2(190, 44)
	_dugme.position = Vector2((KAGIT.x - 190.0) / 2.0, KAGIT.y - 70.0)
	_dugme.pressed.connect(_kapat)
	kagit.add_child(_dugme)

	kagit.pivot_offset = KAGIT / 2.0
	kagit.scale = Vector2(0.92, 0.92)
	kagit.rotation = deg_to_rad(-1.5)
	modulate.a = 0.0
	var t := create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.25)
	t.parallel().tween_property(kagit, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(kagit, "rotation", deg_to_rad(0.6), 0.3)


func _process(delta: float) -> void:
	if not _yaziyor or _govde == null:
		return
	var once := int(_gorunen)
	_gorunen += HIZ * float(Oyun.ayar("yazi_hizi")) * delta
	_govde.visible_characters = mini(_toplam, int(_gorunen))
	if int(_gorunen) != once:
		harf_yazildi.emit()
	if _gorunen >= _toplam:
		_tamamla()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and _yaziyor:
		accept_event()
		_tamamla()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE):
		get_viewport().set_input_as_handled()
		if _yaziyor:
			_tamamla()
		else:
			_kapat()


func _tamamla() -> void:
	if not _yaziyor:
		return
	_yaziyor = false
	_govde.visible_characters = -1
	if _imza != null:
		Ses.cal("imza", 1.0, -4.0)
		create_tween().tween_property(_imza, "modulate:a", 1.0, 0.9).set_delay(0.15)


func _kapat() -> void:
	if _dugme.disabled:
		return
	_dugme.disabled = true
	_yaziyor = false
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.2)
	t.tween_callback(func() -> void:
		kapandi.emit()
		queue_free())


func _yaz(ebeveyn: Control, metin: String, alan: Rect2, punto: int, renk: Color, font: Font = null,
		ortali: bool = false, sar: bool = false) -> Label:
	var l := Stil.etiket(metin, punto, renk, font)
	if sar:
		# Sarma, boyuttan ÖNCE açılmalı; yoksa etiket tek satırın genişliğine yayılır.
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = alan.position
	l.size = alan.size
	if ortali:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ebeveyn.add_child(l)
	return l
