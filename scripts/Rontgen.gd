class_name Rontgen
extends Control
## Röntgen cihazının kumanda masası. Çantayla gelen vatandaşın eşyası banttan geçer; cihaz masanın
## önüne yükselir ve çantanın içini tüplü ekranda gösterir. Memur ekrana bakarak karar verir:
## yeşil düğme çantayı geçirir, kırmızı düğme alarm verir (bekçi çantayı açar).
##
## Ekrandaki görüntü ayrı bir görünümde (SubViewport) kurulur: çantanın kabuğu ve eşyalar birer
## yoğunluk haritasıdır, beyaz zemine çarpılarak üst üste biner; ekran gölgelendiricisi sonucu fosfor
## rengine boyar. Üç görüntü kipi vardır: olağan, negatif ve yalnızca yoğun (maden) parçalar.
## Cihaz neyin yasak olduğunu söylemez; bakıp tanımak memurun işidir.

signal karar_verildi(karar: String)     ## "gecir" | "alarm"
signal efekt(ad: String)                ## ses olayları: "bant", "dugme", "alarm"

const KONSOL := "res://assets/img/rontgen/konsol.webp"
const ESYA_GOLGELEYICI := preload("res://assets/shader/rontgen_esya.gdshader")
const EKRAN_GOLGELEYICI := preload("res://assets/shader/rontgen_ekran.gdshader")

const TUVAL := Vector2(380, 290)              ## ekranın tasarım ölçüsü (çanta bu alana kurulur)
const BOYUT := Vector2(690, 384)              ## kumanda masasının ekrandaki boyutu
const ACIK_YER := Vector2(22, 338)
const KAPALI_YER := Vector2(22, 736)
# Görseldeki yerler (kumanda masasına oranlı 0..1; tools/sanat/rontgen.py çıktısından ölçüldü)
const EKRAN := Rect2(0.076, 0.102, 0.549, 0.755)
const DUGME_YERI := {"gecir": Vector2(0.764, 0.384), "alarm": Vector2(0.895, 0.384)}
const DUGME_YARICAPI := 0.036
const DUGME_ETIKETI := {"gecir": Rect2(0.719, 0.460, 0.092, 0.054), "alarm": Rect2(0.851, 0.460, 0.091, 0.054)}
const DUGME_YAZISI := {"gecir": "GEÇİR", "alarm": "ALARM"}
const TUS_YERI := [Vector2(0.7425, 0.596), Vector2(0.8318, 0.596), Vector2(0.9172, 0.596)]
const TUS_YARISI := 0.027
const TUS_ETIKETI := [Rect2(0.7116, 0.658, 0.0692, 0.0534), Rect2(0.7978, 0.658, 0.0696, 0.0534), Rect2(0.8841, 0.658, 0.0685, 0.0534)]
const KIPLER := ["OLAĞAN", "NEGATİF", "YOĞUN"]
const LAMBA := Vector2(0.7397, 0.826)
const PLAKA := Rect2(0.7895, 0.7656, 0.1623, 0.1218)

var acik := false                 ## cihaz masanın önünde mi
var karar_bekliyor := false       ## görüntü ekrana geldi, düğmeler açık
var kip := 0:
	set(k):
		kip = clampi(k, 0, KIPLER.size() - 1)
		if _ekran_malzemesi != null:
			_ekran_malzemesi.set_shader_parameter("kip", kip)
		if _isaretler != null:
			_isaretler.queue_redraw()

var _govde: Control
var _gorunum: SubViewport
var _bant: Node2D                 ## çantanın ekranda kaydığı taşıyıcı
var _ekran: TextureRect
var _ekran_malzemesi: ShaderMaterial
var _isaretler: Control           ## düğmelerin basılı/üzerinde hâli ve lamba
var _durum: Label
var _dugmeler: Dictionary = {}    ## ad -> Button
var _hareket: Tween
var _kayma: Tween
var _basili := ""
var _lamba_acik := false


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE

	_gorunum = SubViewport.new()
	_gorunum.name = "RontgenGorunumu"
	_gorunum.size = Vector2i(TUVAL * 2.0)
	_gorunum.disable_3d = true
	_gorunum.transparent_bg = false
	_gorunum.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_gorunum)
	var zemin := ColorRect.new()
	zemin.color = Color.WHITE
	zemin.size = TUVAL * 2.0
	_gorunum.add_child(zemin)
	_bant = Node2D.new()
	_bant.scale = Vector2(2, 2)
	_gorunum.add_child(_bant)

	_govde = Control.new()
	_govde.name = "Govde"
	_govde.size = BOYUT
	_govde.position = KAPALI_YER
	_govde.mouse_filter = MOUSE_FILTER_STOP      # arkasındaki masaya tıklanmasın
	_govde.visible = false
	add_child(_govde)

	# cihazın masaya düşen yumuşak gölgesi (gövdenin arkasında, köşeleri yuvarlak bir kutu)
	var golge := Panel.new()
	var kutu := StyleBoxFlat.new()
	kutu.bg_color = Color(0.12, 0.10, 0.08, 0.55)
	kutu.set_corner_radius_all(22)
	kutu.shadow_color = Color(0, 0, 0, 0.42)
	kutu.shadow_size = 16
	kutu.shadow_offset = Vector2(5, 7)
	golge.add_theme_stylebox_override("panel", kutu)
	golge.position = Vector2(8, 8)
	golge.size = BOYUT - Vector2(16, 12)
	golge.mouse_filter = MOUSE_FILTER_IGNORE
	_govde.add_child(golge)

	var resim := TextureRect.new()
	resim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	resim.stretch_mode = TextureRect.STRETCH_SCALE
	resim.size = BOYUT
	resim.mouse_filter = MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(KONSOL):
		resim.texture = load(KONSOL)
	_govde.add_child(resim)

	_ekran = TextureRect.new()
	_ekran.name = "Ekran"
	_ekran.texture = _gorunum.get_texture()
	_ekran.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ekran.stretch_mode = TextureRect.STRETCH_SCALE
	_ekran.position = EKRAN.position * BOYUT
	_ekran.size = EKRAN.size * BOYUT
	_ekran.mouse_filter = MOUSE_FILTER_IGNORE
	_ekran_malzemesi = ShaderMaterial.new()
	_ekran_malzemesi.shader = EKRAN_GOLGELEYICI
	_ekran_malzemesi.set_shader_parameter("oran", _ekran.size)
	_ekran_malzemesi.set_shader_parameter("guc", 0.0)
	_ekran.material = _ekran_malzemesi
	_govde.add_child(_ekran)

	_durum = Stil.etiket("", 10, Color(0.72, 1.0, 0.80, 0.85), Stil.daktilo_kalin())
	_durum.position = _ekran.position + Vector2(16, 10)
	_durum.size = Vector2(_ekran.size.x - 32, 14)
	_durum.mouse_filter = MOUSE_FILTER_IGNORE
	_govde.add_child(_durum)

	_isaretler = Control.new()
	_isaretler.size = BOYUT
	_isaretler.mouse_filter = MOUSE_FILTER_IGNORE
	_isaretler.draw.connect(_isaretleri_ciz)
	_govde.add_child(_isaretler)

	for ad: String in DUGME_YERI:
		var cap := DUGME_YARICAPI * BOYUT.x * 2.0
		var d := _dugme("Rontgen" + ad.capitalize(), DUGME_YERI[ad] * BOYUT - Vector2(cap, cap) / 2.0, Vector2(cap, cap))
		d.pressed.connect(_karar.bind(ad))
		d.button_down.connect(_basildi.bind(ad))
		d.button_up.connect(_basildi.bind(""))
		_dugmeler[ad] = d
		_plaka_yazisi(DUGME_YAZISI[ad], DUGME_ETIKETI[ad], 11, Stil.BORDO if ad == "alarm" else Color("2f4a36"))
	for i in TUS_YERI.size():
		var kenar := TUS_YARISI * BOYUT.x * 2.0
		var d := _dugme("RontgenKip%d" % i, TUS_YERI[i] * BOYUT - Vector2(kenar, kenar) / 2.0, Vector2(kenar, kenar))
		d.pressed.connect(_kip_sec.bind(i))
		_dugmeler["kip%d" % i] = d
		_plaka_yazisi(KIPLER[i], TUS_ETIKETI[i], 8, Stil.MUREKKEP)
	var plaka := _plaka_yazisi("RÖNTGEN CİHAZI\nARDIÇLI NÜFUS MD.\nDEMİRBAŞ No 84/17", PLAKA, 7, Color("4a3712"))
	plaka.add_theme_constant_override("line_spacing", -1)
	set_process(false)


func _dugme(ad: String, yer: Vector2, boyut: Vector2) -> Button:
	var d := Button.new()
	d.name = ad
	d.flat = true
	d.focus_mode = FOCUS_NONE
	d.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	for durum: String in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
		d.add_theme_stylebox_override(durum, StyleBoxEmpty.new())
	d.position = yer
	d.size = boyut
	d.mouse_entered.connect(_isaretler.queue_redraw)
	d.mouse_exited.connect(_isaretler.queue_redraw)
	_govde.add_child(d)
	return d


func _plaka_yazisi(metin: String, alan: Rect2, punto: int, renk: Color) -> Label:
	var l := Stil.etiket(metin, punto, renk, Stil.daktilo_kalin())
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true          # en küçük boyut sıfır olsun: etiket plakadan taşıp yazıyı kaydırmasın
	l.mouse_filter = MOUSE_FILTER_IGNORE
	_govde.add_child(l)
	l.position = alan.position * BOYUT
	l.size = alan.size * BOYUT
	return l


# --- Açılış / kapanış ---

## Cihazı masanın önüne çıkarır ve çantayı banttan geçirir. Görüntü ekrana oturunca düğmeler açılır.
func ac(canta: Dictionary) -> void:
	_cantayi_kur(canta)
	acik = true
	karar_bekliyor = false
	kip = 0
	_basili = ""
	_lamba_acik = true
	_govde.visible = true
	_gorunum.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_ekran_malzemesi.set_shader_parameter("alarm", 0.0)
	_durum.text = "BANT ÇALIŞIYOR"
	set_process(true)
	efekt.emit("bant")
	if _hareket != null:
		_hareket.kill()
	_hareket = create_tween()
	_hareket.tween_property(_govde, "position", ACIK_YER, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hareket.parallel().tween_method(_gucu_ayarla, 0.0, 1.0, 0.5)
	if _kayma != null:
		_kayma.kill()
	_bant.position = Vector2(TUVAL.x * 2.0 + 40.0, 0)
	_kayma = create_tween()
	_kayma.tween_interval(0.3)
	_kayma.tween_property(_bant, "position:x", 0.0, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_kayma.tween_callback(_goruntu_oturdu.bind(str(Canta.tur_bilgisi(str(canta.get("tur", ""))).get("ad", "çanta"))))


func _goruntu_oturdu(canta_adi: String) -> void:
	karar_bekliyor = true
	_lamba_acik = false
	_durum.text = Stil.buyuk(canta_adi) + " · KARAR BEKLENİYOR"
	_isaretler.queue_redraw()


## Çanta ekrandan çıkar, cihaz masanın altına iner.
func kapat() -> void:
	if not acik:
		return
	acik = false
	karar_bekliyor = false
	_durum.text = ""
	if _kayma != null:
		_kayma.kill()
	_kayma = create_tween()
	_kayma.tween_property(_bant, "position:x", -TUVAL.x * 2.0 - 40.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if _hareket != null:
		_hareket.kill()
	_hareket = create_tween()
	_hareket.tween_interval(0.35)
	_hareket.tween_method(_gucu_ayarla, 1.0, 0.0, 0.2)
	_hareket.parallel().tween_property(_govde, "position", KAPALI_YER, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_hareket.tween_callback(_kapandi)


func _kapandi() -> void:
	_govde.visible = false
	_gorunum.render_target_update_mode = SubViewport.UPDATE_DISABLED
	set_process(false)
	for c in _bant.get_children():
		c.queue_free()


func _gucu_ayarla(g: float) -> void:
	_ekran_malzemesi.set_shader_parameter("guc", g)


func _process(_delta: float) -> void:
	# bant çalışırken sarı lamba yanıp söner
	if _lamba_acik:
		_isaretler.queue_redraw()


# --- Çantanın görüntüsü ---

func _cantayi_kur(canta: Dictionary) -> void:
	for c in _bant.get_children():
		_bant.remove_child(c)
		c.queue_free()
	var tur := str(canta.get("tur", "bavul"))
	var bilgi := Canta.tur_bilgisi(tur)
	var kabuk_dokusu := Canta.kabuk_dokusu(tur)
	var kabuk_boyutu := kabuk_dokusu.get_size() if kabuk_dokusu != null else Vector2(800, 620)
	var gosterim := Canta.gosterim_boyutu(kabuk_boyutu)
	var kose := (TUVAL - gosterim) / 2.0 + Vector2(0, 6)
	if kabuk_dokusu != null:
		var kabuk := _parca(kabuk_dokusu, 0.92)
		kabuk.position = kose + gosterim / 2.0
		kabuk.scale = gosterim / kabuk_boyutu
	var ic: Array = bilgi.get("ic", [0.1, 0.2, 0.9, 0.9])
	var ic_kose := kose + Vector2(float(ic[0]), float(ic[1])) * gosterim
	var ic_boyut := Vector2(float(ic[2]) - float(ic[0]), float(ic[3]) - float(ic[1])) * gosterim
	var olcek := float(bilgi.get("olcek", 1.0))
	for e: Dictionary in canta.get("esyalar", []):
		var ad := str(e.get("ad", ""))
		var doku := Canta.esya_dokusu(ad)
		if doku == null:
			continue
		var b := Canta.esya(ad)
		var s := _parca(doku, float(b.get("yogun", 1.0)))
		s.position = ic_kose + Vector2(float(e.get("x", 0.5)), float(e.get("y", 0.5))) * ic_boyut
		s.rotation = deg_to_rad(float(e.get("aci", 0.0)))
		s.flip_h = bool(e.get("ayna", false))
		var boy := float(b.get("boy", 20)) * Canta.CM * olcek
		s.scale = Vector2.ONE * (boy / maxf(doku.get_width(), doku.get_height()))


func _parca(doku: Texture2D, yogun: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = doku
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var m := ShaderMaterial.new()
	m.shader = ESYA_GOLGELEYICI
	m.set_shader_parameter("yogun", yogun)
	s.material = m
	_bant.add_child(s)
	return s


# --- Düğmeler ---

func _karar(karar: String) -> void:
	if not karar_bekliyor:
		return
	karar_bekliyor = false
	efekt.emit("dugme")
	if karar == "alarm":
		efekt.emit("alarm")
		_durum.text = "ALARM"
		var t := create_tween()
		t.tween_method(func(a: float) -> void: _ekran_malzemesi.set_shader_parameter("alarm", a), 0.0, 1.0, 0.12)
	else:
		_durum.text = "GEÇTİ"
	_isaretler.queue_redraw()
	karar_verildi.emit(karar)


func _kip_sec(yeni: int) -> void:
	if not acik:
		return
	efekt.emit("dugme")
	kip = yeni


func _basildi(ad: String) -> void:
	_basili = ad
	_isaretler.queue_redraw()


## Düğmelerin üstüne gelindiğini, basıldığını, seçili görüntü kipini ve lambayı gösterir.
func _isaretleri_ciz() -> void:
	for ad: String in DUGME_YERI:
		var m: Vector2 = DUGME_YERI[ad] * BOYUT
		var r := DUGME_YARICAPI * BOYUT.x * 0.72
		var d: Button = _dugmeler[ad]
		if not karar_bekliyor:
			_isaretler.draw_circle(m, r, Color(0, 0, 0, 0.34))      # henüz basılamaz: sönük
		elif _basili == ad:
			_isaretler.draw_circle(m, r, Color(0, 0, 0, 0.30))
		else:
			var parlak := Color(0.55, 1.0, 0.6) if ad == "gecir" else Color(1.0, 0.45, 0.4)
			_isaretler.draw_circle(m, r * 1.9, Color(parlak, 0.10))
			_isaretler.draw_circle(m + Vector2(-r * 0.25, -r * 0.3), r * 0.42, Color(1, 1, 1, 0.16))
			if d.is_hovered():
				_isaretler.draw_arc(m, r * 1.22, 0.0, TAU, 40, Color(1, 0.95, 0.8, 0.9), 2.0, true)
	for i in TUS_YERI.size():
		var m: Vector2 = TUS_YERI[i] * BOYUT
		var yari := TUS_YARISI * BOYUT.x * 0.74
		var kutu := Rect2(m - Vector2(yari, yari), Vector2(yari, yari) * 2.0)
		var d: Button = _dugmeler["kip%d" % i]
		if i == kip:
			_isaretler.draw_rect(kutu, Color(0.10, 0.16, 0.10, 0.34))
			_isaretler.draw_rect(Rect2(kutu.position + Vector2(4, 4), Vector2(6, 6)), Color(0.55, 1.0, 0.62, 0.95 if acik else 0.2))
		elif d.is_hovered():
			_isaretler.draw_rect(kutu.grow(2.0), Color(1, 0.95, 0.8, 0.85), false, 1.5)
	var lamba := LAMBA * BOYUT
	if _lamba_acik and fmod(Time.get_ticks_msec() / 1000.0, 0.5) < 0.3:
		_isaretler.draw_circle(lamba, 20.0, Color(1.0, 0.72, 0.2, 0.22))
		_isaretler.draw_circle(lamba, 9.0, Color(1.0, 0.9, 0.55, 0.55))
	else:
		_isaretler.draw_circle(lamba, 10.0, Color(0, 0, 0, 0.30))
