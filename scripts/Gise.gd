class_name Gise
extends Control
## Gişe camı: vatandaşın büstü camın ardında yürüyerek gelir, bekler, konuşur, işi bitince çekilir.
## Büst CanliPortre ile canlandırılır; bekledikçe sabrı taşar ve öfleyip pöfler.
## İnceleme modunda yüz, nüfus cüzdanındaki fotoğrafla karşılaştırılabilen bir hedeftir.

signal hedef_tiklandi(hedef: Hedef)
signal efekt(ad: String)        ## portreden gelen ses olayları ("adim", "hece", "ofle")
signal canta_tiklandi           ## eşikteki çantaya tıklandı (röntgene alınacak)

const OLCEK := 0.46             ## portre dokusunun camdaki ölçeği
const GELIS_SURESI := 0.85
const ILK_SABIR := Vector2(24.0, 36.0)     ## ilk öflemeye kadar geçen süre aralığı (sn)
const SONRAKI_SABIR := Vector2(15.0, 26.0)

var yuz: Hedef
var portre: CanliPortre
var kimlik := ""

var kepenk := 0.0:              ## 0 açık .. 1 tamamen inik
	set(k):
		kepenk = clampf(k, 0.0, 1.0)
		if _kepenk_cizimi != null:
			_kepenk_cizimi.queue_redraw()

var _hareket: Tween
var _sabir := 30.0
var _kepenk_cizimi: Control
var _canta: TextureRect             ## vatandaşın eşiğe koyduğu çanta
var _canta_dugmesi: Button
var _canta_hareketi: Tween
var _canta_isigi: Tween
var _canta_yeri := Vector2.ZERO
var eller: VatandasElleri           ## vatandaşın elleri (duruma göre poz değiştirir)
var _kolluk: Array[TextureRect] = []    ## yakalamada cama gelen iki görevli
var _yakalaniyor := false
var _el_donusu := 0.0               ## bu süre dolunca eller eşiğe döner


func _ready() -> void:
	position = Yerlesim.GISE_ACIKLIK.position
	size = Yerlesim.GISE_ACIKLIK.size
	clip_contents = true
	mouse_filter = MOUSE_FILTER_IGNORE

	portre = CanliPortre.new()
	portre.name = "Portre"
	portre.visible = false
	portre.efekt.connect(func(ad: String) -> void: efekt.emit(ad))
	add_child(portre)

	eller = VatandasElleri.new()
	eller.name = "Eller"
	eller.size = size
	add_child(eller)

	for i in 2:
		var k := TextureRect.new()
		k.name = "Kolluk%d" % (i + 1)
		k.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		k.stretch_mode = TextureRect.STRETCH_SCALE
		k.mouse_filter = MOUSE_FILTER_IGNORE
		k.visible = false
		add_child(k)
		_kolluk.append(k)

	_canta = TextureRect.new()
	_canta.name = "Canta"
	_canta.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_canta.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_canta.mouse_filter = MOUSE_FILTER_IGNORE
	_canta.visible = false
	add_child(_canta)
	_canta_dugmesi = Button.new()
	_canta_dugmesi.name = "CantayiTara"
	_canta_dugmesi.flat = true
	_canta_dugmesi.focus_mode = FOCUS_NONE
	_canta_dugmesi.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	for durum: String in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
		_canta_dugmesi.add_theme_stylebox_override(durum, StyleBoxEmpty.new())
	_canta_dugmesi.visible = false
	_canta_dugmesi.pressed.connect(func() -> void: canta_tiklandi.emit())
	add_child(_canta_dugmesi)

	var cam := Control.new()
	cam.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	cam.mouse_filter = MOUSE_FILTER_IGNORE
	cam.draw.connect(_cam_ciz.bind(cam))
	add_child(cam)

	_kepenk_cizimi = Control.new()
	_kepenk_cizimi.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_kepenk_cizimi.mouse_filter = MOUSE_FILTER_IGNORE
	_kepenk_cizimi.draw.connect(_kepenk_ciz)
	add_child(_kepenk_cizimi)

	yuz = Hedef.new()
	yuz.tip = "yuz"
	yuz.etiket = "Vatandaşın yüzü"
	yuz.visible = false
	yuz.tiklandi.connect(func(h: Hedef) -> void: hedef_tiklandi.emit(h))
	add_child(yuz)


## Vatandaş soldan yürüyerek cama gelir.
func gelsin(portre_kimligi: String) -> void:
	kimlik = portre_kimligi
	portre.ayarla(portre_kimligi, OLCEK)
	var boyut := portre.size
	var yer := Vector2((size.x - boyut.x) / 2.0, size.y - boyut.y + 3.0)
	portre.position = Vector2(-boyut.x - 14.0, yer.y)
	portre.modulate = Color(0.74, 0.77, 0.78)
	portre.visible = true
	portre.yuruyor = true
	yuz.deger = portre_kimligi
	yuz.position = Vector2(yer.x + boyut.x * 0.18, maxf(4.0, yer.y))
	yuz.size = Vector2(boyut.x * 0.64, minf(boyut.y * 0.74, size.y - yuz.position.y - 8.0))
	yuz.durum = Hedef.Durum.BOS
	yuz.visible = false
	_sabir = randf_range(ILK_SABIR.x, ILK_SABIR.y)
	eller.hazirla(portre_kimligi)
	if _hareket != null:
		_hareket.kill()
	_hareket = create_tween()
	_hareket.tween_property(portre, "position:x", yer.x, GELIS_SURESI).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_hareket.parallel().tween_property(portre, "modulate", Color.WHITE, GELIS_SURESI)
	_hareket.tween_callback(func() -> void:
		portre.yuruyor = false
		yuz.visible = true
		# cama gelince evrakını uzatır, sonra ellerini eşiğe koyar
		eller.goster("uzat")
		_el_donusu = 1.6)


## İşi biten vatandaş sağa doğru yürüyüp çekilir.
func gitsin() -> void:
	if kimlik == "":
		return
	kimlik = ""
	yuz.visible = false
	yuz.durum = Hedef.Durum.BOS
	canta_kaldir()
	eller.gizle()
	portre.konusuyor = false
	portre.yuruyor = true
	if _hareket != null:
		_hareket.kill()
	_hareket = create_tween()
	_hareket.tween_property(portre, "position:x", size.x + 16.0, GELIS_SURESI * 0.9) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_hareket.parallel().tween_property(portre, "modulate", Color(0.74, 0.77, 0.78), GELIS_SURESI * 0.9)
	_hareket.tween_callback(func() -> void:
		portre.visible = false
		portre.yuruyor = false
		portre.sifirla())


# --- Çanta ---

## Vatandaş çantasını eşiğe koyar; çanta tıklanınca röntgene gider.
func canta_goster(tur: String) -> void:
	var doku := Canta.dis_doku(tur)
	if doku == null:
		return
	_canta.texture = doku
	var boyut := doku.get_size() * (96.0 / maxf(1.0, doku.get_width()))
	if boyut.y > 86.0:
		boyut *= 86.0 / boyut.y
	_canta.size = boyut
	_canta_yeri = Vector2(size.x - boyut.x - 8.0, size.y - boyut.y + 5.0)
	_canta.position = _canta_yeri + Vector2(0, boyut.y + 12.0)
	_canta.modulate = Color.WHITE
	_canta.visible = true
	_canta_dugmesi.position = _canta_yeri - Vector2(6, 6)
	_canta_dugmesi.size = boyut + Vector2(12, 12)
	_canta_dugmesi.visible = true
	_cantayi_oynat(_canta_yeri, 0.32, GELIS_SURESI * 0.2)
	# tıklanmayı beklerken hafifçe parlayıp söner
	if _canta_isigi != null:
		_canta_isigi.kill()
	_canta_isigi = create_tween().set_loops()
	_canta_isigi.tween_property(_canta, "modulate", Color(1.28, 1.24, 1.12), 0.55).set_trans(Tween.TRANS_SINE)
	_canta_isigi.tween_property(_canta, "modulate", Color.WHITE, 0.55).set_trans(Tween.TRANS_SINE)


## Çanta eşikten aşağı, banda iner.
func canta_gonder() -> void:
	_canta_dugmesi.visible = false
	if _canta_isigi != null:
		_canta_isigi.kill()
	_canta.modulate = Color.WHITE
	_cantayi_oynat(_canta_yeri + Vector2(0, _canta.size.y + 12.0), 0.28)


## Röntgenden geçen çanta eşiğe geri gelir; vatandaş giderken yanında götürür.
func canta_donsun() -> void:
	if _canta.visible:
		_cantayi_oynat(_canta_yeri, 0.3)


func canta_kaldir() -> void:
	_canta_dugmesi.visible = false
	if _canta_isigi != null:
		_canta_isigi.kill()
	if _canta_hareketi != null:
		_canta_hareketi.kill()
	if not _canta.visible:
		return
	# sahibiyle birlikte sağa doğru çekilir
	_canta_hareketi = create_tween()
	_canta_hareketi.tween_property(_canta, "position:x", size.x + 20.0, GELIS_SURESI * 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_canta_hareketi.parallel().tween_property(_canta, "modulate:a", 0.0, GELIS_SURESI * 0.55)
	_canta_hareketi.tween_callback(_canta.hide)


func _cantayi_oynat(hedef: Vector2, sure: float, gecikme: float = 0.0) -> void:
	if _canta_hareketi != null:
		_canta_hareketi.kill()
	_canta_hareketi = create_tween()
	if gecikme > 0.0:
		_canta_hareketi.tween_interval(gecikme)
	_canta_hareketi.tween_property(_canta, "position", hedef, sure).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Konuşma balonu yazarken ağız oynar.
func konus(acik: bool) -> void:
	if kimlik != "":
		portre.konusuyor = acik
		# konuşurken arada eliyle anlatır
		if acik and eller.poz == "esik" and randf() < 0.55:
			eller.goster("acik")
			_el_donusu = 60.0
		elif not acik and eller.poz == "acik":
			_el_donusu = 0.5


## Karara verilen tepki: "onay" sevinir, "eksik" üzülür, "havale" şaşırır.
func tepki(karar: String) -> void:
	if kimlik == "":
		return
	match karar:
		"onay":
			portre.sevin()
			eller.goster("esik")
		"eksik":
			portre.uzul()
			eller.goster("yalvar")
			_el_donusu = 60.0
		"havale":
			portre.sas()
			eller.goster("acik")
			_el_donusu = 60.0
		"alarm":
			portre.sas()
			eller.goster("teslim")
			_el_donusu = 60.0


## Sabır sayacını baştan kurar (oyuncu vatandaşla ilgilenince).
func sabri_tazele() -> void:
	_sabir = maxf(_sabir, randf_range(SONRAKI_SABIR.x, SONRAKI_SABIR.y) * 0.6)


func _process(delta: float) -> void:
	if kimlik == "" or portre.yuruyor or _yakalaniyor:
		return
	if _el_donusu > 0.0:
		_el_donusu -= delta
		if _el_donusu <= 0.0:
			eller.goster("esik")
	if portre.konusuyor:
		return
	_sabir -= delta
	if _sabir <= 0.0:
		_sabir = randf_range(SONRAKI_SABIR.x, SONRAKI_SABIR.y)
		portre.ofle()
		eller.goster("parmak")          # sabrı taşan parmak sallar
		_el_donusu = 1.7


# --- Yakalama ---

## Şüpheli yakalanır: iki görevli iki yandan dalar, şüpheli ellerini kaldırır, yaka paça yere
## yatırılır, kaldırılıp kolundan sürüklenerek götürülür. Bitince gişe boşalır.
func yakala() -> void:
	if kimlik == "" or _yakalaniyor:
		return
	_yakalaniyor = true
	kimlik = ""
	yuz.visible = false
	yuz.durum = Hedef.Durum.BOS
	canta_kaldir()
	portre.konusuyor = false
	portre.kork()                       # görevlileri görür: korkar, elleri havaya kalkar
	eller.goster("teslim")
	if _hareket != null:
		_hareket.kill()
	var yer := portre.position
	var orta := yer.x + portre.size.x / 2.0
	# görevliler: soldaki sağa, sağdaki sola bakar; şüphelinin omuzlarına biner
	var hedefler: Array[float] = [orta - 118.0, orta + 118.0]
	for i in 2:
		var k := _kolluk[i]
		k.texture = Portreler.doku("kolluk_%d" % (i + 1))
		k.size = k.texture.get_size() * OLCEK
		k.pivot_offset = Vector2(k.size.x / 2.0, k.size.y)
		k.position = Vector2((-k.size.x - 20.0) if i == 0 else (size.x + 20.0), size.y - k.size.y + 6.0)
		k.rotation = 0.0
		k.modulate = Color(0.80, 0.82, 0.84)
		k.visible = true
	await Oyun.bekle(0.35)
	# 1) dalış
	_hareket = create_tween().set_parallel()
	for i in 2:
		var k := _kolluk[i]
		_hareket.tween_property(k, "position:x", hedefler[i] - k.size.x / 2.0, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_hareket.tween_property(k, "modulate", Color.WHITE, 0.26)
	efekt.emit("adim")
	await Oyun.bekle(0.16)
	efekt.emit("adim")
	await Oyun.bekle(0.14)
	# 2) yakalama: görevliler üstüne abanır, şüpheli silkelenir, öfkeyle bağırır
	efekt.emit("yakalama")
	portre.ofkelen()
	_hareket = create_tween().set_parallel()
	_hareket.tween_property(_kolluk[0], "rotation", 0.20, 0.12)
	_hareket.tween_property(_kolluk[1], "rotation", -0.20, 0.12)
	for adim in 6:
		_hareket.tween_property(portre, "position:x", yer.x + (9.0 if adim % 2 == 0 else -9.0), 0.055).set_delay(adim * 0.055)
	await Oyun.bekle(0.75)
	# 3) yaka paça yere: şüpheli öne devrilip eşiğin altına iner, görevliler üstüne çöker
	eller.gizle()
	portre.aci_cek()
	_hareket = create_tween().set_parallel()
	_hareket.tween_property(portre, "ek_donme", 0.62, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_hareket.tween_property(portre, "position", yer + Vector2(26.0, portre.size.y * 0.78), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	for i in 2:
		_hareket.tween_property(_kolluk[i], "position:y", _kolluk[i].position.y + 84.0, 0.24).set_delay(0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_hareket.tween_property(_kolluk[i], "rotation", 0.42 if i == 0 else -0.42, 0.24).set_delay(0.05)
	await Oyun.bekle(0.24)
	efekt.emit("yere_serme")
	# 4) boğuşma: görevliler bastırır
	for tur in 3:
		_hareket = create_tween().set_parallel()
		for i in 2:
			_hareket.tween_property(_kolluk[i], "position:y", _kolluk[i].position.y + (9.0 if tur % 2 == 0 else -9.0), 0.14)
		await Oyun.bekle(0.16)
		if tur == 1:
			efekt.emit("yakalama")
	# 5) kaldırıp götürme: şüpheli iki görevlinin arasında, başı önde, sağa sürüklenir
	_hareket = create_tween().set_parallel()
	_hareket.tween_property(portre, "position", yer + Vector2(8.0, 20.0), 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hareket.tween_property(portre, "ek_donme", 0.20, 0.30)
	portre.ofkelen()                    # kaldırılırken hâlâ direnir
	for i in 2:
		_hareket.tween_property(_kolluk[i], "position:y", size.y - _kolluk[i].size.y + 6.0, 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_hareket.tween_property(_kolluk[i], "rotation", 0.08 if i == 0 else -0.08, 0.30)
	await Oyun.bekle(0.42)
	portre.yuruyor = true
	_hareket = create_tween().set_parallel()
	var yol := size.x + 60.0 - yer.x + 130.0
	_hareket.tween_property(portre, "position:x", portre.position.x + yol, 0.95).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_hareket.tween_property(portre, "modulate", Color(0.74, 0.77, 0.78), 0.95)
	for i in 2:
		_hareket.tween_property(_kolluk[i], "position:x", _kolluk[i].position.x + yol, 0.95).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await Oyun.bekle(1.0)
	portre.visible = false
	portre.yuruyor = false
	portre.sifirla()
	for k in _kolluk:
		k.visible = false
	_yakalaniyor = false


## Mesai bitince ahşap kepenk iner.
func kepengi_indir(sure: float = 1.1) -> void:
	var t := create_tween()
	t.tween_property(self, "kepenk", 1.0, sure).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## İnen kepenk: yatay ahşap latalar ve altında tutamak çıtası.
func _kepenk_ciz() -> void:
	if kepenk <= 0.001:
		return
	var w := size.x
	var alt := size.y * kepenk
	var y := alt
	var i := 0
	while y > -14.0:
		var ust := y - 13.0
		var ton := Color("7a5334") if i % 2 == 0 else Color("71492d")
		_kepenk_cizimi.draw_rect(Rect2(0, ust, w, 13.0), ton)
		_kepenk_cizimi.draw_rect(Rect2(0, ust, w, 2.0), Color(1, 0.9, 0.7, 0.10))
		_kepenk_cizimi.draw_rect(Rect2(0, y - 2.5, w, 2.5), Color(0, 0, 0, 0.30))
		y -= 13.0
		i += 1
	_kepenk_cizimi.draw_rect(Rect2(0, alt - 7.0, w, 7.0), Color("4a3222"))
	_kepenk_cizimi.draw_rect(Rect2(0, alt, w, 9.0), Color(0, 0, 0, 0.22))
	if kepenk > 0.96:
		var levha := Serit.doku("levha_kapali")
		if levha != null:
			var boyut := levha.get_size() * (108.0 / levha.get_width())
			_kepenk_cizimi.draw_texture_rect(levha, Rect2(Vector2(w / 2.0 - boyut.x / 2.0, size.y * 0.30), boyut), false)

## Camın yansıması: iki çapraz ışık şeridi ve üstte çerçeve gölgesi.
func _cam_ciz(cam: Control) -> void:
	var w := cam.size.x
	var h := cam.size.y
	cam.draw_colored_polygon(PackedVector2Array([Vector2(w * 0.10, 0), Vector2(w * 0.30, 0),
		Vector2(w * 0.02, h * 0.78), Vector2(0, h * 0.62), Vector2(0, h * 0.30)]), Color(1, 1, 1, 0.055))
	cam.draw_colored_polygon(PackedVector2Array([Vector2(w * 0.40, 0), Vector2(w * 0.47, 0),
		Vector2(w * 0.10, h), Vector2(w * 0.02, h)]), Color(1, 1, 1, 0.04))
	cam.draw_rect(Rect2(0, 0, w, 10), Color(0, 0, 0, 0.16))
	cam.draw_rect(Rect2(0, 10, w, 8), Color(0, 0, 0, 0.07))
