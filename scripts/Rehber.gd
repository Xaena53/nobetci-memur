class_name Rehber
extends Control
## Öğretici: masanın bir parçasını aydınlatıp (çevresi kararır) yanına kısa bir not kâğıdı koyar.
## Adımlar sırayla gösterilir; "İleri" sonrakine geçer, "Geç" hepsini kapatır.
##
## Masa iki yerde kullanır (bkz. Masa._rehberi_goster):
##  - ilk gün, gişe açılmadan önce: masanın baştan sona tanıtımı;
##  - yeni bir sayfa ya da araç geldiği gün (tarife, arananlar, yasak eşya, bilgi defteri): onu gösteren tek adım.
## Görülen dersler bir daha gösterilmez (Oyun.ogretici_gordu). Ayarlardan öğretici yeniden açılınca
## dersler baştan gösterilir.

signal bitti

const NOT_ENI := 330.0
const PAY := 8.0                ## aydınlık alanın hedefin çevresine taşan payı

## adim: {ders, baslik, metin, hedef: Callable -> Rect2}
var adimlar: Array[Dictionary] = []
var sira := 0

var _alan := Rect2()            ## aydınlatılan yer (ekran koordinatı)
var _not: PanelContainer
var _baslik: Label
var _metin: Label
var _sayac: Label
var _ileri: Button
var _nabiz := 0.0
var _kapaniyor := false


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	_not = PanelContainer.new()
	_not.name = "RehberNotu"
	_not.add_theme_stylebox_override("panel", Stil.bosluklu(Stil.kutu(Stil.KAGIT, Stil.MUREKKEP, 2, 3), 16, 12))
	_not.custom_minimum_size = Vector2(NOT_ENI, 0)
	add_child(_not)
	var dikey := VBoxContainer.new()
	dikey.add_theme_constant_override("separation", 8)
	_not.add_child(dikey)
	_baslik = Stil.etiket("", 15, Stil.BORDO, Stil.daktilo_kalin())
	dikey.add_child(_baslik)
	_metin = Stil.etiket("", 13, Stil.MUREKKEP, Stil.daktilo())
	_metin.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_metin.custom_minimum_size = Vector2(NOT_ENI - 32.0, 0)
	_metin.add_theme_constant_override("line_spacing", 1)
	dikey.add_child(_metin)
	var alt := HBoxContainer.new()
	alt.add_theme_constant_override("separation", 10)
	dikey.add_child(alt)
	_sayac = Stil.etiket("", 11, Stil.MUREKKEP_SOLUK, Stil.daktilo())
	_sayac.size_flags_horizontal = SIZE_EXPAND_FILL
	_sayac.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	alt.add_child(_sayac)
	var gec := Button.new()
	gec.name = "RehberiGec"
	gec.text = "Geç"
	gec.focus_mode = FOCUS_NONE
	gec.pressed.connect(_kapat)
	alt.add_child(gec)
	_ileri = Button.new()
	_ileri.name = "RehberIleri"
	_ileri.text = "İleri"
	_ileri.focus_mode = FOCUS_NONE
	_ileri.custom_minimum_size = Vector2(96, 0)
	_ileri.pressed.connect(ileri)
	alt.add_child(_ileri)


## Adımları gösterir. Hedefi bulunamayan (boş dikdörtgen veren) adımlar atlanır.
func baslat(liste: Array[Dictionary]) -> void:
	adimlar = liste.filter(func(a: Dictionary) -> bool: return _hedef(a).has_area())
	if adimlar.is_empty():
		_kapat()
		return
	sira = 0
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.25)
	_goster()


func ileri() -> void:
	if _kapaniyor or sira >= adimlar.size():
		return
	Oyun.ogretici_gordu(str(adimlar[sira].get("ders", "")))
	sira += 1
	if sira >= adimlar.size():
		_kapat()
		return
	Ses.cal("kagit", 1.1, -14.0, 0.05)
	_goster()


func _hedef(a: Dictionary) -> Rect2:
	var c: Callable = a.get("hedef", Callable())
	return (c.call() as Rect2) if c.is_valid() else Rect2()


func _goster() -> void:
	var a := adimlar[sira]
	_alan = _hedef(a).grow(PAY).intersection(Yerlesim.EKRAN)
	_baslik.text = Dil.c(str(a.baslik))
	_metin.text = Dil.c(str(a.metin))
	_sayac.text = "%d / %d" % [sira + 1, adimlar.size()] if adimlar.size() > 1 else ""
	_ileri.text = Dil.c("Tamam" if sira == adimlar.size() - 1 else "İleri")
	_not.reset_size()
	_not.size = _not.get_combined_minimum_size()
	_not.position = _not_yeri(_not.size)
	queue_redraw()


## Not kâğıdı aydınlık alanın yanına (sağına, soluna, altına ya da üstüne; sığan ilk yere) konur.
func _not_yeri(boyut: Vector2) -> Vector2:
	var ekran := Yerlesim.EKRAN.grow(-12.0)
	var orta_y := _alan.get_center().y - boyut.y / 2.0
	var orta_x := _alan.get_center().x - boyut.x / 2.0
	var adaylar := [
		Vector2(_alan.end.x + 18.0, orta_y),
		Vector2(_alan.position.x - 18.0 - boyut.x, orta_y),
		Vector2(orta_x, _alan.end.y + 18.0),
		Vector2(orta_x, _alan.position.y - 18.0 - boyut.y),
	]
	for p: Vector2 in adaylar:
		var r := Rect2(p.clamp(ekran.position, ekran.end - boyut), boyut)
		if not r.intersects(_alan):
			return r.position
	# hiçbir yana sığmıyorsa (alan çok büyük) ekranın alt ortasına
	return Vector2((Yerlesim.EKRAN.size.x - boyut.x) / 2.0, ekran.end.y - boyut.y)


func _process(delta: float) -> void:
	_nabiz += delta
	queue_redraw()


func _draw() -> void:
	var e := Yerlesim.EKRAN
	var karanlik := Color(0.04, 0.035, 0.03, 0.66)
	# aydınlık alanın çevresi kararır (dört dikdörtgen)
	draw_rect(Rect2(e.position, Vector2(e.size.x, _alan.position.y)), karanlik)
	draw_rect(Rect2(0, _alan.end.y, e.size.x, e.size.y - _alan.end.y), karanlik)
	draw_rect(Rect2(0, _alan.position.y, _alan.position.x, _alan.size.y), karanlik)
	draw_rect(Rect2(_alan.end.x, _alan.position.y, e.size.x - _alan.end.x, _alan.size.y), karanlik)
	# nabız gibi atan bordo çerçeve
	var parlak := 0.55 + 0.45 * sin(_nabiz * 4.0)
	draw_rect(_alan, Color(Stil.BORDO, 0.55 + 0.45 * parlak), false, 3.0)
	draw_rect(_alan.grow(3.0 + 2.0 * parlak), Color(Stil.BORDO, 0.25 * parlak), false, 2.0)


func _gui_input(event: InputEvent) -> void:
	# kararan yere tıklamak bir şey yapmaz; aydınlık alana tıklamak da ileri götürür
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if _alan.has_point(event.position):
			ileri()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE):
		get_viewport().set_input_as_handled()
		ileri()


func _kapat() -> void:
	if _kapaniyor:
		return
	_kapaniyor = true
	for a in adimlar:
		Oyun.ogretici_gordu(str(a.get("ders", "")))
	mouse_filter = MOUSE_FILTER_IGNORE
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.2)
	t.tween_callback(func() -> void:
		bitti.emit()
		queue_free())
