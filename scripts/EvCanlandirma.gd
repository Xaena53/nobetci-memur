class_name EvCanlandirma
extends Control
## Akşam odasını canlandırır.
##
##  - Pencerenin ardında kar yağar (camların içinde kalır; çerçeve ve perde üstüne taşmaz).
##  - Soba yanıyorsa camındaki alev oynar, kıvılcım sıçrar, çevresi alevin ışığıyla aydınlanır.
##  - Sobanın üstünde tencere ya da çaydanlık varsa buharı tüter.
## Ailenin hareketleri (örgü, yazı, kamyon) burada değildir: onlar gerçek canlandırma videolarıdır
## (bkz. VideoFigur).
##
## Düğüm iki katman kurar: `arka` figürlerin arkasında (kar, ateş, tencere), `on` önlerinde (buhar,
## ışık). Aile sahnesi bunları kendi sırasına yerleştirir.

## Camlar (ekran): sol üst, sağ üst, sol alt, sağ alt. tools/sanat/ev_pencere.py ile aynı.
const CAMLAR := [Rect2(143, 129, 62, 86), Rect2(218, 129, 67, 86), Rect2(143, 228, 62, 111), Rect2(218, 228, 67, 111)]
const PENCERE := Rect2(143, 129, 142, 210)
const SOBA_CAMI := Rect2(602, 442, 64, 37)
const SOBA_USTU := Vector2(634, 392)            ## sobanın üst tablasının ortası: tencerenin oturduğu yer
const ATES := preload("res://assets/shader/soba_atesi.gdshader")
const NESNE := "res://assets/img/nesne/%s.webp"

var soba_yaniyor := false: set = _soba_degisti
var ocakta := "": set = _ocak_degisti           ## "" | "tencere" | "caydanlik"
var arka: Control                               ## figürlerin arkasına konacak katman
var on: Control                                 ## figürlerin önüne konacak katman

var _zaman := 0.0
var _taneler := PackedFloat32Array()            ## pencere karı: [x, y, çap, hız, evre] ...
var _kar: Control
var _ates: ColorRect
var _kivilcim: CPUParticles2D
var _isik: Control
var _kap: TextureRect
var _buhar: CPUParticles2D
var _nokta: Texture2D
var _zar := RandomNumberGenerator.new()


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_zar.seed = 1984
	arka = Control.new()
	arka.name = "EvArka"
	arka.mouse_filter = MOUSE_FILTER_IGNORE
	on = Control.new()
	on.name = "EvOn"
	on.mouse_filter = MOUSE_FILTER_IGNORE


## Katmanları kurar. `zemin` odanın arka plan dokusudur (alev onun üstünde oynar).
func kur(zemin: Texture2D) -> void:
	_nokta = KasabaSahnesi.hale_dokusu()

	# pencere karı
	_kar = Control.new()
	_kar.name = "PencereKari"
	_kar.mouse_filter = MOUSE_FILTER_IGNORE
	_kar.draw.connect(_kari_ciz)
	arka.add_child(_kar)
	_taneleri_kur()
	Oyun.ayarlar_degisti.connect(_taneleri_kur)

	# soba ateşi
	_ates = ColorRect.new()
	_ates.name = "SobaAtesi"
	_ates.mouse_filter = MOUSE_FILTER_IGNORE
	_ates.position = SOBA_CAMI.position
	_ates.size = SOBA_CAMI.size
	var m := ShaderMaterial.new()
	m.shader = ATES
	m.set_shader_parameter("zemin", zemin)
	var e := Yerlesim.EKRAN.size
	m.set_shader_parameter("bolge", Vector4(SOBA_CAMI.position.x / e.x, SOBA_CAMI.position.y / e.y, SOBA_CAMI.size.x / e.x, SOBA_CAMI.size.y / e.y))
	_ates.material = m
	_ates.visible = false
	arka.add_child(_ates)
	var kirpici := Control.new()
	kirpici.name = "Kivilcimlar"
	kirpici.mouse_filter = MOUSE_FILTER_IGNORE
	kirpici.position = SOBA_CAMI.position
	kirpici.size = SOBA_CAMI.size
	kirpici.clip_contents = true
	arka.add_child(kirpici)
	_kivilcim = CPUParticles2D.new()
	_kivilcim.texture = _nokta
	_kivilcim.position = Vector2(SOBA_CAMI.size.x / 2.0, SOBA_CAMI.size.y - 2.0)
	_kivilcim.amount = 9
	_kivilcim.lifetime = 0.9
	_kivilcim.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_kivilcim.emission_rect_extents = Vector2(SOBA_CAMI.size.x / 2.0 - 6.0, 2.0)
	_kivilcim.direction = Vector2(0, -1)
	_kivilcim.spread = 28.0
	_kivilcim.gravity = Vector2(0, -34)
	_kivilcim.initial_velocity_min = 16.0
	_kivilcim.initial_velocity_max = 44.0
	_kivilcim.scale_amount_min = 0.018
	_kivilcim.scale_amount_max = 0.04
	_kivilcim.color = Color(1.0, 0.78, 0.36, 0.95)
	var ekle := CanvasItemMaterial.new()
	ekle.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_kivilcim.material = ekle
	_kivilcim.emitting = false
	kirpici.add_child(_kivilcim)

	# ocaktaki kap
	_kap = TextureRect.new()
	_kap.name = "Ocaktaki"
	_kap.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_kap.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_kap.mouse_filter = MOUSE_FILTER_IGNORE
	_kap.visible = false
	arka.add_child(_kap)

	# önde: alevin çevreye vuran ışığı ve buhar
	_isik = Control.new()
	_isik.name = "AtesIsigi"
	_isik.mouse_filter = MOUSE_FILTER_IGNORE
	_isik.material = ekle
	_isik.draw.connect(_isigi_ciz)
	on.add_child(_isik)
	_buhar = KasabaSahnesi.duman(SOBA_USTU, 0.5)
	_buhar.name = "Buhar"
	_buhar.amount = 26
	_buhar.lifetime = 3.6
	_buhar.preprocess = 3.6
	_buhar.initial_velocity_min = 14.0
	_buhar.initial_velocity_max = 24.0
	_buhar.spread = 14.0
	_buhar.direction = Vector2(0.05, -1.0)
	_buhar.gravity = Vector2(2, -6)
	_buhar.emission_sphere_radius = 9.0
	var beyaz := Gradient.new()
	beyaz.offsets = PackedFloat32Array([0.0, 0.12, 0.55, 1.0])
	beyaz.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.34), Color(1, 1, 1, 0.16), Color(1, 1, 1, 0.0)])
	_buhar.color_ramp = beyaz
	_buhar.modulate.a = 1.0
	_buhar.emitting = false
	_buhar.visible = false
	on.add_child(_buhar)
	_soba_degisti(soba_yaniyor)
	_ocak_degisti(ocakta)


func _soba_degisti(yaniyor: bool) -> void:
	soba_yaniyor = yaniyor
	if _ates == null:
		return
	_ates.visible = yaniyor
	_kivilcim.emitting = yaniyor and Oyun.efekt_duzeyi() > 0
	_buhari_ayarla()


func _ocak_degisti(ad: String) -> void:
	ocakta = ad
	if _kap == null:
		return
	var yol := NESNE % ad
	_kap.visible = ad != "" and ResourceLoader.exists(yol)
	if _kap.visible:
		_kap.texture = load(yol)
		# tencere tablanın üstüne oturur; çaydanlık daha dar ve uzundur
		var boyut := Vector2(62, 49) if ad == "tencere" else Vector2(46, 50)
		_kap.size = boyut
		_kap.position = Vector2(SOBA_USTU.x - boyut.x / 2.0, SOBA_USTU.y - boyut.y + 4.0)
		_buhar.position = Vector2(SOBA_USTU.x + (0.0 if ad == "tencere" else -14.0), _kap.position.y + (6.0 if ad == "tencere" else 12.0))
	_buhari_ayarla()


## Buhar yalnızca kap ocaktayken ve soba yanarken tüter.
func _buhari_ayarla() -> void:
	if _buhar == null:
		return
	var tuter := soba_yaniyor and _kap.visible and Oyun.efekt_duzeyi() > 0
	_buhar.visible = tuter
	_buhar.emitting = tuter


# --- Pencere karı ---

func _taneleri_kur() -> void:
	var adet: int = [26, 48, 70][Oyun.efekt_duzeyi()]
	_taneler.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 84
	for i in adet:
		_taneler.append(rng.randf_range(PENCERE.position.x, PENCERE.end.x))
		_taneler.append(rng.randf_range(PENCERE.position.y, PENCERE.end.y))
		_taneler.append(rng.randf_range(1.3, 2.9))        # çap
		_taneler.append(rng.randf_range(13.0, 30.0))      # düşme hızı (px/sn): uzakta, ağır
		_taneler.append(rng.randf_range(0.0, TAU))
	if _kivilcim != null:
		_kivilcim.emitting = soba_yaniyor and Oyun.efekt_duzeyi() > 0
		_buhari_ayarla()


func _kari_ciz() -> void:
	var ruzgar := 5.0 * sin(_zaman * 0.23) + 3.0 * sin(_zaman * 0.61 + 1.3)
	var i := 0
	while i < _taneler.size():
		var cap := _taneler[i + 2]
		var x := _taneler[i] + sin(_zaman * 1.1 + _taneler[i + 4]) * 2.2 + ruzgar * (cap / 2.9)
		var y := _taneler[i + 1]
		var yer := Vector2(x, y)
		for cam: Rect2 in CAMLAR:
			if cam.has_point(yer):
				# büyük taneler yakındadır: daha parlak
				_kar.draw_texture_rect(_nokta, Rect2(yer - Vector2(cap, cap), Vector2(cap, cap) * 2.0), false,
					Color(0.93, 0.95, 1.0, 0.42 + 0.16 * cap))
				break
		i += 5


# --- Ateşin ışığı ---

func _isigi_ciz() -> void:
	if not soba_yaniyor:
		return
	var titrer := bool(Oyun.ayar("titreme"))
	var n := 1.0
	if titrer:
		n = 0.78 + 0.22 * (0.5 + 0.5 * sin(_zaman * 9.1)) * (0.6 + 0.4 * sin(_zaman * 3.7 + 1.0)) + 0.06 * sin(_zaman * 23.0)
	var m := SOBA_CAMI.get_center()
	# camın çevresindeki hale ve yere vuran ışık gölü
	_isik.draw_texture_rect(_nokta, Rect2(m - Vector2(96, 70), Vector2(192, 140)), false, Color(1.0, 0.56, 0.20, 0.16 * n))
	_isik.draw_texture_rect(_nokta, Rect2(m - Vector2(46, 34), Vector2(92, 68)), false, Color(1.0, 0.66, 0.26, 0.20 * n))
	_isik.draw_texture_rect(_nokta, Rect2(Vector2(m.x - 150, 566), Vector2(300, 74)), false, Color(1.0, 0.52, 0.18, 0.13 * n))


func _process(delta: float) -> void:
	_zaman += delta
	if _ates != null and _ates.visible:
		(_ates.material as ShaderMaterial).set_shader_parameter("zaman", _zaman)
		_isik.queue_redraw()
	# kar taneleri düşer; alttan çıkan üstten girer
	var i := 0
	while i < _taneler.size():
		_taneler[i + 1] += _taneler[i + 3] * delta
		if _taneler[i + 1] > PENCERE.end.y + 3.0:
			_taneler[i + 1] = PENCERE.position.y - 3.0
			_taneler[i] = _zar.randf_range(PENCERE.position.x, PENCERE.end.x)
		i += 5
	if _kar != null:
		_kar.queue_redraw()
