class_name KasabaSahnesi
extends Control
## Kasabadan boyalı bir sahneyi ana menüdeki gibi canlandırır: bacalar tüter, sokak lambası ve
## ışıklı pencereler hafifçe titrer, resim çok ağır ağır yaklaşır. Kar yağışını bu düğüm çizmez;
## üstüne bir `Kar` konur ve `ana_lamba()` onun ışık kaynağı olur.
##
## Tanım (data/ara_ekran.json → "sahneler"), bütün ölçüler 1280×720 ekran biriminde:
##   gorsel      : resmin yolu (16:9)
##   ad          : künyede görünen yer adı
##   bacalar     : [[x, y, ölçek], ...]      baca ağzının yeri; ölçek 1 yakın, 0.2 uzak
##   lambalar    : [[x, y, yarıçap], ...]    ampulün yeri; ilki ana lambadır (karı aydınlatır)
##   pencereler  : [[x, y, en, boy], ...]    içeriden ışık vuran pencereler

const SURE := 16.0              ## yaklaşmanın sürdüğü süre (sn)
const YAKLASMA := 0.045         ## bu sürede resmin büyüme oranı

static var _duman_doku: Texture2D
static var _duman_buyume: Curve
static var _duman_renk: Gradient
static var _hale_doku: Texture2D

var tanim: Dictionary = {}
var ruzgar := 0.0               ## dışarıdan verilir (Kar.ruzgar): duman buna göre yatar

var _tuval: Control             ## resim, duman ve ışık: birlikte yaklaşır
var _isik: Control
var _dumanlar: Array[CPUParticles2D] = []
var _zaman := 0.0
var _duzey := -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tuval = Control.new()
	_tuval.size = Yerlesim.EKRAN.size
	_tuval.pivot_offset = Yerlesim.EKRAN.size * Vector2(0.5, 0.56)
	_tuval.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tuval)
	var resim := TextureRect.new()
	resim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	resim.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	resim.size = Yerlesim.EKRAN.size
	resim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	resim.texture = Gorsel.yukle(str(tanim.get("gorsel", "")))
	_tuval.add_child(resim)
	for b: Variant in tanim.get("bacalar", []):
		if typeof(b) == TYPE_ARRAY and b.size() >= 3:
			var d := duman(Vector2(float(b[0]), float(b[1])), float(b[2]))
			_tuval.add_child(d)
			_dumanlar.append(d)
	_isik = Control.new()
	_isik.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ekle := CanvasItemMaterial.new()
	ekle.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_isik.material = ekle
	_isik.draw.connect(_isigi_ciz)
	_tuval.add_child(_isik)
	_dumani_ayarla()
	Oyun.ayarlar_degisti.connect(_dumani_ayarla)


func _process(delta: float) -> void:
	_zaman += delta
	for d in _dumanlar:
		d.gravity = Vector2((3.0 + ruzgar * 0.42) * d.scale.x, -3.0 * d.scale.x)
	if Oyun.efekt_duzeyi() > 0:
		var t := clampf(_zaman / SURE, 0.0, 1.0)
		_tuval.scale = Vector2.ONE * (1.0 + YAKLASMA * (t * t * (3.0 - 2.0 * t)))
	if bool(Oyun.ayar("titreme")):
		_isik.queue_redraw()


## Ana lambanın yeri (karı aydınlatan ışık); lamba yoksa ekran dışında bir nokta.
func ana_lamba() -> Vector2:
	var l: Array = tanim.get("lambalar", [])
	if l.is_empty() or typeof(l[0]) != TYPE_ARRAY or l[0].size() < 2:
		return Vector2(-1000, -1000)
	return Vector2(float(l[0][0]), float(l[0][1]))


## Ana lambanın o anki parlaklığı (0..1).
func lamba_gucu() -> float:
	return _titreme(0.0)


func _titreme(evre: float) -> float:
	if not bool(Oyun.ayar("titreme")):
		return 1.0
	return 0.93 + 0.07 * sin(_zaman * 27.0 + evre) * sin(_zaman * 6.1 + evre * 0.7)


## Lambaların halesi ve pencerelerden vuran ışık (eklemeli).
func _isigi_ciz() -> void:
	var doku := hale_dokusu()
	var no := 0
	for l: Variant in tanim.get("lambalar", []):
		if typeof(l) != TYPE_ARRAY or l.size() < 3:
			continue
		var yer := Vector2(float(l[0]), float(l[1]))
		var r := float(l[2])
		var b := _titreme(no * 1.7)
		_isik.draw_texture_rect(doku, Rect2(yer - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(1.0, 0.78, 0.40, 0.30 * b))
		_isik.draw_texture_rect(doku, Rect2(yer - Vector2(r, r) * 0.34, Vector2(r, r) * 0.68), false, Color(1.0, 0.86, 0.55, 0.42 * b))
		no += 1
	for p: Variant in tanim.get("pencereler", []):
		if typeof(p) != TYPE_ARRAY or p.size() < 4:
			continue
		var kutu := Rect2(float(p[0]), float(p[1]), float(p[2]), float(p[3])).grow(maxf(float(p[2]), float(p[3])) * 0.35)
		# ocak ışığı gibi ağır ağır soluk alır
		var s := 1.0
		if bool(Oyun.ayar("titreme")):
			s = 0.82 + 0.18 * sin(_zaman * 1.9 + no) * sin(_zaman * 0.83 + no * 2.1)
		_isik.draw_texture_rect(doku, kutu, false, Color(1.0, 0.72, 0.36, 0.16 * s))
		no += 1


## Duman efekt kalitesine uyar: düşükte bacalar tütmez, ortada seyrelir.
func _dumani_ayarla() -> void:
	var duzey := Oyun.efekt_duzeyi()
	if duzey == _duzey:
		return
	_duzey = duzey
	for d in _dumanlar:
		var tam := int(d.get_meta("tam_adet", 22))
		d.visible = duzey > 0
		d.amount = maxi(6, roundi(tam * [0.4, 0.7, 1.0][duzey]))


# --- Ortak parçalar (ana menü de kullanır) ---

## Bir bacanın ağzına konacak duman kaynağı. Kümeler yükseldikçe büyür, döner ve dağılır.
static func duman(yer: Vector2, olcek: float) -> CPUParticles2D:
	if _duman_doku == null:
		_duman_doku = _duman_dokusu()
		_duman_buyume = Curve.new()
		_duman_buyume.add_point(Vector2(0.0, 0.22))
		_duman_buyume.add_point(Vector2(0.35, 0.62))
		_duman_buyume.add_point(Vector2(1.0, 1.0))
		_duman_renk = Gradient.new()
		# bacadan çıkarken koyu ve yoğun; yükseldikçe ağarır ve dağılır
		_duman_renk.offsets = PackedFloat32Array([0.0, 0.05, 0.30, 0.68, 1.0])
		_duman_renk.colors = PackedColorArray([Color(0.52, 0.52, 0.54, 0.0), Color(0.56, 0.56, 0.58, 0.80),
			Color(0.76, 0.76, 0.76, 0.52), Color(0.92, 0.91, 0.89, 0.24), Color(0.96, 0.95, 0.93, 0.0)])
	var d := CPUParticles2D.new()
	d.name = "Duman"
	d.texture = _duman_doku
	d.position = yer
	d.scale = Vector2(olcek, olcek)
	if olcek < 0.5:
		d.modulate.a = 0.7          # uzaktaki bacalar: kasabanın üstünü sis gibi örtmesin
	d.amount = 72 if olcek > 0.5 else 22
	d.set_meta("tam_adet", d.amount)
	d.lifetime = 7.0
	d.preprocess = 7.0
	d.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	d.emission_sphere_radius = 4.0
	d.direction = Vector2(0.25, -1.0)
	d.spread = 9.0
	d.initial_velocity_min = 11.0
	d.initial_velocity_max = 18.0
	d.gravity = Vector2(8, -3)
	d.damping_min = 1.2
	d.damping_max = 2.4
	d.angle_min = 0.0
	d.angle_max = 360.0
	d.angular_velocity_min = -14.0
	d.angular_velocity_max = 14.0
	d.scale_amount_min = 0.85
	d.scale_amount_max = 1.5
	d.scale_amount_curve = _duman_buyume
	d.color_ramp = _duman_renk
	return d


## Duman kümesi: kenarı yumuşak, içi gürültüyle benekli bir yuvar (boya dokusuna uysun diye pürüzlü).
static func _duman_dokusu() -> Texture2D:
	var boyut := 72
	var gurultu := FastNoiseLite.new()
	gurultu.seed = 84
	gurultu.frequency = 0.045
	gurultu.fractal_octaves = 3
	var g := Image.create(boyut, boyut, false, Image.FORMAT_RGBA8)
	var orta := (boyut - 1) / 2.0
	for y in boyut:
		for x in boyut:
			var u := Vector2(x - orta, y - orta).length() / (boyut / 2.0)
			var n := 0.5 + 0.5 * gurultu.get_noise_2d(x, y)
			var kenar := clampf(1.0 - u - 0.28 * (1.0 - n), 0.0, 1.0)
			g.set_pixel(x, y, Color(1, 1, 1, pow(kenar, 1.25) * (0.55 + 0.45 * n)))
	return ImageTexture.create_from_image(g)


## Merkezi parlak, kenara doğru sönen yumuşak ışık lekesi.
static func hale_dokusu() -> Texture2D:
	if _hale_doku == null:
		var gecis := Gradient.new()
		gecis.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 1.0])
		gecis.colors = PackedColorArray([Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.42), Color(1, 1, 1, 0.10), Color(1, 1, 1, 0.0)])
		var doku := GradientTexture2D.new()
		doku.gradient = gecis
		doku.fill = GradientTexture2D.FILL_RADIAL
		doku.fill_from = Vector2(0.5, 0.5)
		doku.fill_to = Vector2(1.0, 0.5)
		doku.width = 128
		doku.height = 128
		_hale_doku = doku
	return _hale_doku
