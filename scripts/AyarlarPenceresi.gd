class_name AyarlarPenceresi
extends Control
## Ayarlar: daktilo sayfasına yazılmış bir form. Ses düzeyleri kutucuklu kademelerle, mesai
## saatinin hızı üç seçenekle, tam ekran bir işaret kutusuyla ayarlanır; altta kontroller yazar.
## Ana menüden ve mola (duraklatma) menüsünden açılır; oyun duraklatılmışken de çalışır.

signal kapandi

const KAGIT := Vector2(540, 600)
const HIZLAR := [["Sakin", 1.4], ["Olağan", 1.0], ["Telaşlı", 0.7]]
const KONTROLLER := [
	"Belgeyi sürükle; çift tıkla, büyüsün.",
	"BOŞLUK: inceleme. İki bilgiye tıkla, karşılaştır.",
	"Mührü ya da fişi belgenin üstüne bırak.",
	"ESC: mola.  F11: tam ekran.  F12: ekran görüntüsü.",
]

var _hiz_dugmeleri: Array[Button] = []
var _tam_ekran: Button


func _ready() -> void:
	name = "AyarlarPenceresi"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP

	var perde := ColorRect.new()
	perde.color = Color(0.07, 0.06, 0.05, 0.66)
	perde.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	perde.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(perde)

	var kagit := Control.new()
	kagit.name = "Kagit"
	kagit.size = KAGIT
	kagit.position = (Yerlesim.EKRAN.size - KAGIT) / 2.0
	kagit.pivot_offset = KAGIT / 2.0
	kagit.rotation = deg_to_rad(-0.6)
	kagit.mouse_filter = MOUSE_FILTER_IGNORE
	kagit.draw.connect(func() -> void: Kagit.ciz(kagit, Rect2(Vector2.ZERO, KAGIT), "daktilo_sayfa", Stil.KAGIT, 14.0, 4.0))
	add_child(kagit)

	var x := 62.0
	var w := KAGIT.x - 2.0 * x
	var baslik := Stil.etiket("AYARLAR", 22, Stil.BORDO, Stil.daktilo_kalin())
	baslik.position = Vector2(0, 64)
	baslik.size = Vector2(KAGIT.x, 28)
	baslik.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kagit.add_child(baslik)
	_cizgi(kagit, x, 100.0, w)

	var y := 120.0
	for satir: Array in [["Genel ses", "ses_genel"], ["Efektler", "ses_efekt"], ["Radyo ve ortam", "ses_radyo"]]:
		_etiket(kagit, str(satir[0]), x, y)
		var k := Kademe.new()
		k.name = "Kademe_" + str(satir[1])
		k.position = Vector2(x + 168.0, y - 1.0)
		k.deger = float(Oyun.ayar(str(satir[1])))
		k.degisti.connect(_ses_degisti.bind(str(satir[1])))
		kagit.add_child(k)
		y += 38.0

	y += 8.0
	_etiket(kagit, "Mesai saati", x, y)
	var hx := x + 168.0
	for h: Array in HIZLAR:
		var d := _secenek(str(h[0]))
		d.name = "Hiz_" + str(h[0])
		d.position = Vector2(hx, y - 5.0)
		d.pressed.connect(_hiz_secildi.bind(float(h[1])))
		kagit.add_child(d)
		_hiz_dugmeleri.append(d)
		hx += d.size.x + 2.0
	y += 40.0

	_etiket(kagit, "Tam ekran", x, y)
	_tam_ekran = _secenek("")
	_tam_ekran.name = "TamEkran"
	_tam_ekran.position = Vector2(x + 168.0, y - 5.0)
	_tam_ekran.pressed.connect(func() -> void:
		Oyun.ayar_degistir("tam_ekran", not bool(Oyun.ayar("tam_ekran")))
		_guncelle())
	kagit.add_child(_tam_ekran)
	y += 46.0

	_cizgi(kagit, x, y, w)
	y += 14.0
	var kb := Stil.etiket("KONTROLLER", 13, Stil.MUREKKEP_SOLUK, Stil.daktilo_kalin())
	kb.position = Vector2(x, y)
	kagit.add_child(kb)
	y += 24.0
	for satir: String in KONTROLLER:
		var l := Stil.etiket("- " + satir, 13, Stil.MUREKKEP)
		l.position = Vector2(x, y)
		kagit.add_child(l)
		y += 21.0

	var tamam := Button.new()
	tamam.name = "AyarKapat"
	tamam.text = "Tamam"
	tamam.focus_mode = FOCUS_NONE
	tamam.custom_minimum_size = Vector2(180, 42)
	tamam.position = Vector2((KAGIT.x - 180.0) / 2.0, KAGIT.y - 76.0)
	tamam.pressed.connect(kapat)
	kagit.add_child(tamam)

	_guncelle()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.18)


func kapat() -> void:
	kapandi.emit()
	queue_free()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		kapat()


func _ses_degisti(deger: float, anahtar: String) -> void:
	Oyun.ayar_degistir(anahtar, deger)
	if anahtar == "ses_radyo":
		Ses.cal("zil", 1.0, -10.0)
	else:
		Ses.cal("muhur", 1.0, -5.0)


func _hiz_secildi(hiz: float) -> void:
	Oyun.ayar_degistir("saat_hizi", hiz)
	_guncelle()


func _guncelle() -> void:
	var hiz := float(Oyun.ayar("saat_hizi"))
	for i in HIZLAR.size():
		var secili := is_equal_approx(float(HIZLAR[i][1]), hiz)
		_hiz_dugmeleri[i].text = ("[%s]" if secili else " %s ") % str(HIZLAR[i][0])
		_hiz_dugmeleri[i].add_theme_color_override("font_color", Stil.BORDO if secili else Stil.MUREKKEP)
	var tam := bool(Oyun.ayar("tam_ekran"))
	_tam_ekran.text = "[x] açık" if tam else "[ ] kapalı"
	_tam_ekran.add_theme_color_override("font_color", Stil.BORDO if tam else Stil.MUREKKEP)


func _etiket(ebeveyn: Control, metin: String, x: float, y: float) -> void:
	var l := Stil.etiket(metin, 15, Stil.MUREKKEP)
	l.position = Vector2(x, y)
	ebeveyn.add_child(l)


func _cizgi(ebeveyn: Control, x: float, y: float, w: float) -> void:
	var c := ColorRect.new()
	c.color = Color(Stil.MUREKKEP, 0.7)
	c.position = Vector2(x, y)
	c.size = Vector2(w, 1.5)
	c.mouse_filter = MOUSE_FILTER_IGNORE
	ebeveyn.add_child(c)


## Daktiloyla yazılmış gibi duran, çerçevesiz seçenek düğmesi.
func _secenek(metin: String) -> Button:
	var d := Button.new()
	d.text = metin if metin != "" else "[ ] kapalı"
	d.focus_mode = FOCUS_NONE
	d.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	d.add_theme_font_override("font", Stil.daktilo())
	d.add_theme_font_size_override("font_size", 15)
	d.add_theme_color_override("font_hover_color", Stil.BORDO)
	for durum: String in ["normal", "pressed", "focus", "disabled"]:
		d.add_theme_stylebox_override(durum, Stil.bosluklu(Stil.kutu(Color(0, 0, 0, 0)), 5, 4))
	d.add_theme_stylebox_override("hover", Stil.bosluklu(Stil.kutu(Color(Stil.BORDO, 0.08)), 5, 4))
	d.text = "[%s]" % metin if metin != "" else d.text
	d.size = d.get_combined_minimum_size()
	return d


## On kutucuklu kademe: ses düzeyi gibi 0..1 arası bir değeri tıklayarak ya da sürükleyerek ayarlar.
class Kademe extends Control:
	signal degisti(deger: float)

	const ADET := 10
	const KUTU := Vector2(19, 18)
	const ARALIK := 4.0

	var deger := 1.0:
		set(d):
			deger = clampf(d, 0.0, 1.0)
			queue_redraw()

	var _suruyor := false

	func _init() -> void:
		size = Vector2(ADET * (KUTU.x + ARALIK), KUTU.y + 4.0)
		custom_minimum_size = size
		mouse_default_cursor_shape = CURSOR_POINTING_HAND

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			_suruyor = event.pressed
			if event.pressed:
				_ayarla(event.position.x)
			accept_event()
		elif event is InputEventMouseMotion and _suruyor:
			_ayarla(event.position.x)
			accept_event()

	func _ayarla(x: float) -> void:
		var yeni := clampf(ceilf(x / (KUTU.x + ARALIK)), 0.0, ADET) / ADET
		if x < 5.0:
			yeni = 0.0
		if not is_equal_approx(yeni, deger):
			deger = yeni
			degisti.emit(deger)

	func _draw() -> void:
		var dolu := roundi(deger * ADET)
		for i in ADET:
			var r := Rect2(i * (KUTU.x + ARALIK), 2.0, KUTU.x, KUTU.y)
			if i < dolu:
				draw_rect(r, Color(Stil.MUREKKEP, 0.88))
			draw_rect(r, Stil.MUREKKEP, false, 1.4)
