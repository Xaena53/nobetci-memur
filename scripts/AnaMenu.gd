extends Control
## Ana menü: kar altındaki nüfus müdürlüğü binası. Başlık daktiloyla yazılır gibi belirir;
## seçenekler gökyüzüne, başlığın altına dizilir: Yeni Oyun, Devam, Ayarlar, Çıkış.

const ARKA_PLAN := "res://assets/img/menu_arkaplan.webp"
const BASLIK := "NÖBETÇİ MEMUR"
const TABELA := Rect2(840, 352, 165, 46)       ## binanın kapısı üstündeki boş tabela
const LAMBA := Vector2(563, 355)               ## sokak lambasının ampulü
const YAZI_HIZI := 9.0                         ## başlık: saniyede harf
const SOL := 66.0

var _baslik: Label
var _gorunen := 0.0
var _yaziyor := true
var _sonrakiler: Array[Control] = []           ## başlık bitince sırayla beliren öğeler
var _yeni: Button
var _devam: Button
var _isik: Control
var _onay_bekliyor := false


func _ready() -> void:
	Ses.yalniz(["ruzgar"])
	Ses.ortam("ruzgar", -9.0, 2.0)

	var zemin := TextureRect.new()
	zemin.name = "ArkaPlan"
	zemin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	zemin.size = Yerlesim.EKRAN.size
	zemin.mouse_filter = MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(ARKA_PLAN):
		zemin.texture = load(ARKA_PLAN)
	else:
		zemin.modulate = Stil.DUVAR_KOYU
	add_child(zemin)

	# sokak lambasının titreyen ışığı
	_isik = Control.new()
	_isik.mouse_filter = MOUSE_FILTER_IGNORE
	_isik.draw.connect(_isigi_ciz)
	add_child(_isik)

	# tabela
	var ust := Stil.etiket("T.C. ARDIÇLI İLÇESİ", 9, Color("5a3a22"), Stil.serif_kalin())
	ust.position = TABELA.position + Vector2(0, 5)
	ust.size = Vector2(TABELA.size.x, 12)
	ust.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(ust)
	var tabela := Stil.etiket("NÜFUS MÜDÜRLÜĞÜ", 14, Color("4a2a18"), Stil.serif_kalin())
	tabela.position = TABELA.position + Vector2(0, 18)
	tabela.size = Vector2(TABELA.size.x, 20)
	tabela.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(tabela)

	_kar_yagdir()

	# başlık: daktilo harfleri
	_baslik = Stil.etiket(BASLIK, 62, Stil.MUREKKEP, Stil.daktilo_kalin())
	_baslik.name = "Baslik"
	_baslik.position = Vector2(SOL - 4.0, 44)
	_baslik.visible_characters = 0
	add_child(_baslik)

	var cizgi := ColorRect.new()
	cizgi.color = Color(Stil.MUREKKEP, 0.8)
	cizgi.position = Vector2(SOL, 122)
	cizgi.size = Vector2(486, 2)
	cizgi.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(cizgi)
	_sonrakiler.append(cizgi)
	var alt := Stil.etiket("Ardıçlı İlçesi Nüfus Müdürlüğü  —  Ocak 1984", 19, Stil.MUREKKEP, Stil.serif_italik())
	alt.position = Vector2(SOL, 130)
	add_child(alt)
	_sonrakiler.append(alt)

	var y := 192.0
	_yeni = _secenek("YeniOyun", "Yeni Oyun", y)
	_yeni.pressed.connect(_yeni_oyun)
	y += 42.0
	_devam = _secenek("Devam", "Devam", y)
	_devam.disabled = not Oyun.kayit_var_mi()
	_devam.pressed.connect(_devam_et)
	y += 42.0
	_secenek("Ayarlar", "Ayarlar", y).pressed.connect(_ayarlari_ac)
	y += 42.0
	if not OS.has_feature("web"):
		_secenek("Cikis", "Çıkış", y).pressed.connect(func() -> void: Oyun.cik())

	var kunye := Stil.etiket("Sürüm %s  ·  Bütün kişi, kurum ve olaylar kurmacadır." % str(ProjectSettings.get_setting("application/config/version", "1.0")),
		13, Color(0.97, 0.95, 0.89), Stil.daktilo())
	kunye.add_theme_color_override("font_outline_color", Color(0.12, 0.10, 0.09, 0.85))
	kunye.add_theme_constant_override("outline_size", 5)
	kunye.position = Vector2(18, 694)
	add_child(kunye)

	for s in _sonrakiler:
		s.modulate.a = 0.0


func _process(delta: float) -> void:
	_isik.queue_redraw()
	if not _yaziyor:
		return
	var once := int(_gorunen)
	_gorunen += YAZI_HIZI * delta
	_baslik.visible_characters = mini(BASLIK.length(), int(_gorunen))
	if int(_gorunen) != once and int(_gorunen) <= BASLIK.length() and BASLIK[int(_gorunen) - 1] != " ":
		Ses.cal("daktilo", 1.0, -3.0, 0.08)
	if _gorunen >= BASLIK.length():
		_basligi_bitir()


## Tıklayınca ya da bir tuşa basınca başlık beklemeden tamamlanır.
func _unhandled_input(event: InputEvent) -> void:
	if _yaziyor and ((event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed)):
		_basligi_bitir()


func _basligi_bitir() -> void:
	if not _yaziyor:
		return
	_yaziyor = false
	_baslik.visible_characters = -1
	for i in _sonrakiler.size():
		var s := _sonrakiler[i]
		var hedef := 0.4 if s is Button and (s as Button).disabled else 1.0
		var t := create_tween()
		t.tween_interval(0.12 + i * 0.09)
		t.tween_property(s, "modulate:a", hedef, 0.25)


## Çerçevesiz, daktilo yazısı görünümünde menü seçeneği; üstüne gelince öne kayar.
func _secenek(ad: String, metin: String, y: float) -> Button:
	var d := Button.new()
	d.name = ad
	d.text = metin
	d.focus_mode = FOCUS_NONE
	d.alignment = HORIZONTAL_ALIGNMENT_LEFT
	d.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	d.add_theme_font_override("font", Stil.daktilo_kalin())
	d.add_theme_font_size_override("font_size", 25)
	d.add_theme_color_override("font_color", Stil.MUREKKEP)
	d.add_theme_color_override("font_hover_color", Stil.BORDO)
	d.add_theme_color_override("font_pressed_color", Stil.BORDO)
	d.add_theme_color_override("font_disabled_color", Stil.MUREKKEP)
	for durum: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		d.add_theme_stylebox_override(durum, StyleBoxEmpty.new())
	d.position = Vector2(SOL, y)
	d.size = Vector2(430, 38)
	add_child(d)
	var ok := Stil.etiket("›", 27, Stil.BORDO, Stil.daktilo_kalin())
	ok.name = "Ok"
	ok.position = Vector2(-22, -1)
	ok.modulate.a = 0.0
	d.add_child(ok)
	d.mouse_entered.connect(func() -> void:
		if d.disabled:
			return
		Ses.cal("tik", 1.25, -12.0)
		var t := d.create_tween().set_parallel()
		t.tween_property(d, "position:x", SOL + 16.0, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(ok, "modulate:a", 1.0, 0.1))
	d.mouse_exited.connect(func() -> void:
		var t := d.create_tween().set_parallel()
		t.tween_property(d, "position:x", SOL, 0.14)
		t.tween_property(ok, "modulate:a", 0.0, 0.1))
	_sonrakiler.append(d)
	return d


func _isigi_ciz() -> void:
	var nabiz := 0.86 + 0.14 * sin(Time.get_ticks_msec() / 410.0) * sin(Time.get_ticks_msec() / 173.0)
	for i in 5:
		_isik.draw_circle(LAMBA, 14.0 + i * 17.0, Color(1.0, 0.86, 0.52, 0.055 * nabiz))


## İnce, ağır ağır yağan kar.
func _kar_yagdir() -> void:
	var nokta := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for py in 8:
		for px in 8:
			var u := Vector2(px - 3.5, py - 3.5).length() / 4.0
			nokta.set_pixel(px, py, Color(1, 1, 1, clampf(1.0 - u, 0.0, 1.0) ** 1.5))
	var kar := CPUParticles2D.new()
	kar.name = "Kar"
	kar.texture = ImageTexture.create_from_image(nokta)
	kar.amount = 150
	kar.lifetime = 13.0
	kar.preprocess = 13.0
	kar.position = Vector2(640, -12)
	kar.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	kar.emission_rect_extents = Vector2(700, 4)
	kar.direction = Vector2(0.18, 1.0)
	kar.spread = 9.0
	kar.gravity = Vector2(4, 3)
	kar.initial_velocity_min = 42.0
	kar.initial_velocity_max = 78.0
	kar.scale_amount_min = 0.35
	kar.scale_amount_max = 0.95
	kar.color = Color(1, 1, 1, 0.85)
	add_child(kar)


# --- Seçenekler ---

func _yeni_oyun() -> void:
	# Kayıt varsa üstüne yazmadan önce bir kez daha sorulur.
	if Oyun.kayit_var_mi() and not _onay_bekliyor:
		_onay_bekliyor = true
		_yeni.text = "Yeni Oyun — eski kayıt silinsin mi?"
		_yeni.add_theme_font_size_override("font_size", 21)
		Oyun.bekle(4.0).connect(func() -> void:
			_onay_bekliyor = false
			_yeni.text = "Yeni Oyun"
			_yeni.add_theme_font_size_override("font_size", 25))
		return
	Oyun.yeni_oyun()
	Oyun.sahneye_gec("masa")


func _devam_et() -> void:
	if Oyun.yukle():
		Oyun.sahneye_gec("masa")


func _ayarlari_ac() -> void:
	if find_child("AyarlarPenceresi", false, false) != null:
		return
	add_child(AyarlarPenceresi.new())
