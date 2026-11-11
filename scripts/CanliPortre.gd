class_name CanliPortre
extends Control
## Tek görselden canlandırılan büst: nefes alır, göz kırpar, konuşurken ağzı oynar, başını
## sallar, yürürken sallanır, sabrı taşınca öfleyip pöfler.
##
## Hareketlerin hepsi assets/shader/portre.gdshader ile, portrenin yüz noktalarından
## (data/portreler.json: göz, ağız, çene) hesaplanır; ek görsel gerekmez.

signal efekt(ad: String)   ## "ofle", "adim", "hece" — ses için

const GOLGELEYICI := preload("res://assets/shader/portre.gdshader")
const DOLGU := 0.08
const OFLEMELER := ["Öf...", "Pöf!", "Hıh!", "Offf...", "Cık cık...", "Ay ay..."]

var kimlik := ""
var konusuyor := false        ## true iken ağız heceler hâlinde açılıp kapanır
var yuruyor := false          ## true iken adım atar gibi sallanır

var _gorsel: TextureRect
var _malzeme: ShaderMaterial
var _efekt_katmani: Control
var _nida: Label
var _goz_var := true

var _zaman := 0.0
var _faz := 0.0
var _kirpma := 0.0
var _kirpma_bekleme := 2.0
var _kirpma_suresi := -1.0
var _agiz := 0.0
var _agiz_hedef := 0.0
var _hece_kalan := 0.0
var _yurume := 0.0
var _adim := 0.0

# Tepkilerin (sevinç, üzüntü, öfleme) geçici katkıları; tween ile sürülür.
var ek_bas := Vector2.ZERO
var ek_egim := 0.0
var ek_kas := 0.0
var ek_yanak := 0.0
var ek_nefes := 0.0
var ek_agiz := 0.0

var _tepki: Tween
var _pufler: Array[Dictionary] = []


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_malzeme = ShaderMaterial.new()
	_malzeme.shader = GOLGELEYICI
	_malzeme.set_shader_parameter("dolgu", DOLGU)
	_gorsel = TextureRect.new()
	_gorsel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_gorsel.stretch_mode = TextureRect.STRETCH_SCALE
	_gorsel.mouse_filter = MOUSE_FILTER_IGNORE
	_gorsel.material = _malzeme
	add_child(_gorsel)
	_efekt_katmani = Control.new()
	_efekt_katmani.mouse_filter = MOUSE_FILTER_IGNORE
	_efekt_katmani.draw.connect(_pufleri_ciz)
	add_child(_efekt_katmani)
	_nida = Stil.etiket("", 22, Color(0.97, 0.95, 0.88), Stil.el_yazisi())
	_nida.add_theme_color_override("font_outline_color", Color(0.10, 0.08, 0.07, 0.85))
	_nida.add_theme_constant_override("outline_size", 5)
	_nida.visible = false
	add_child(_nida)


## Portreyi yükler; `olcek` dokunun ekrandaki ölçeğidir. Düğümün boyutu büstün boyutu olur.
func ayarla(portre_kimligi: String, olcek: float) -> void:
	kimlik = portre_kimligi
	var doku := Portreler.doku(kimlik)
	var bilgi := Portreler.bilgi(kimlik)
	size = doku.get_size() * olcek
	pivot_offset = Vector2(size.x / 2.0, size.y)
	_gorsel.texture = doku
	_gorsel.position = -size * DOLGU
	_gorsel.size = size * (1.0 + 2.0 * DOLGU)
	var oran := float(bilgi.get("oran", size.x / size.y))
	var goz: Array = bilgi.get("goz", [[0.42, 0.31], [0.56, 0.31]])
	var goz_arasi := float(bilgi.get("goz_arasi", 0.15))
	var agiz: Array = bilgi.get("agiz", [0.5, 0.47])
	_goz_var = not bool(bilgi.get("gozu_kapali", false))
	_malzeme.set_shader_parameter("oran", oran)
	_malzeme.set_shader_parameter("goz_a", Vector2(goz[0][0], goz[0][1]))
	_malzeme.set_shader_parameter("goz_b", Vector2(goz[1][0], goz[1][1]))
	_malzeme.set_shader_parameter("goz_boyut", Vector2(goz_arasi * 0.21, goz_arasi * 0.11 * oran))
	_malzeme.set_shader_parameter("agiz", Vector2(agiz[0], agiz[1]))
	_malzeme.set_shader_parameter("agiz_yari", float(bilgi.get("agiz_gen", 0.12)) * 0.5)
	_malzeme.set_shader_parameter("cene", float(bilgi.get("cene", 0.58)))
	_faz = randf() * TAU
	_kirpma_bekleme = randf_range(0.8, 2.5)
	sifirla()


## Bütün tepkileri keser, yüzü dinlenme hâline döndürür.
func sifirla() -> void:
	if _tepki != null:
		_tepki.kill()
	ek_bas = Vector2.ZERO
	ek_egim = 0.0
	ek_kas = 0.0
	ek_yanak = 0.0
	ek_nefes = 0.0
	ek_agiz = 0.0
	konusuyor = false
	_agiz = 0.0
	_nida.visible = false
	_pufler.clear()


## Ağzın ekrandaki yeri (düğümün kendi koordinatında): puf ve nida buradan çıkar.
func agiz_yeri() -> Vector2:
	var agiz: Array = Portreler.bilgi(kimlik).get("agiz", [0.5, 0.47])
	return Vector2(float(agiz[0]) * size.x, float(agiz[1]) * size.y)


# --- Tepkiler ---

## Onay: memnun, iki kez baş sallar.
func sevin() -> void:
	var t := _yeni_tepki()
	t.tween_property(self, "ek_kas", 0.8, 0.12)
	for i in 2:
		t.tween_property(self, "ek_bas:y", 0.013, 0.11).set_trans(Tween.TRANS_SINE)
		t.tween_property(self, "ek_bas:y", -0.002, 0.13).set_trans(Tween.TRANS_SINE)
	t.tween_property(self, "ek_bas:y", 0.0, 0.1)
	t.parallel().tween_property(self, "ek_kas", 0.0, 0.3)


## Geri çevrilme: omuzlar düşer, baş iki yana sallanır.
func uzul() -> void:
	var t := _yeni_tepki()
	t.tween_property(self, "ek_kas", -0.9, 0.15)
	t.parallel().tween_property(self, "ek_nefes", -0.9, 0.3)
	t.parallel().tween_property(self, "ek_bas:y", 0.010, 0.3)
	for i in 3:
		t.tween_property(self, "ek_bas:x", 0.010, 0.13).set_trans(Tween.TRANS_SINE)
		t.tween_property(self, "ek_bas:x", -0.010, 0.16).set_trans(Tween.TRANS_SINE)
	t.tween_property(self, "ek_bas:x", 0.0, 0.1)
	t.tween_interval(0.5)
	t.tween_property(self, "ek_bas:y", 0.0, 0.4)
	t.parallel().tween_property(self, "ek_nefes", 0.0, 0.4)
	t.parallel().tween_property(self, "ek_kas", 0.0, 0.4)


## Müdüre havale: kaşlar kalkar, baş yana eğilir.
func sas() -> void:
	var t := _yeni_tepki()
	t.tween_property(self, "ek_kas", 1.0, 0.12)
	t.parallel().tween_property(self, "ek_egim", 0.045, 0.2)
	t.parallel().tween_property(self, "ek_bas:y", -0.006, 0.2)
	t.tween_interval(0.9)
	t.tween_property(self, "ek_kas", 0.0, 0.3)
	t.parallel().tween_property(self, "ek_egim", 0.0, 0.3)
	t.parallel().tween_property(self, "ek_bas:y", 0.0, 0.3)


## Sabrı taşınca: derin nefes alır, yanaklarını şişirir, "Öf..." diye üfler.
func ofle() -> void:
	if konusuyor or yuruyor:
		return
	var t := _yeni_tepki()
	# nefes al
	t.tween_property(self, "ek_nefes", 1.9, 0.45).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(self, "ek_bas:y", -0.007, 0.45)
	t.parallel().tween_property(self, "ek_kas", -0.7, 0.3)
	# yanakları şişir
	t.tween_property(self, "ek_yanak", 1.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.12)
	# üfle
	t.tween_callback(_ufle)
	t.tween_property(self, "ek_yanak", 0.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "ek_agiz", 0.5, 0.10)
	t.parallel().tween_property(self, "ek_nefes", -0.8, 0.55)
	t.parallel().tween_property(self, "ek_bas:y", 0.008, 0.5)
	t.tween_property(self, "ek_agiz", 0.0, 0.25)
	# toparlan
	t.tween_property(self, "ek_nefes", 0.0, 0.5)
	t.parallel().tween_property(self, "ek_bas:y", 0.0, 0.5)
	t.parallel().tween_property(self, "ek_kas", 0.0, 0.5)


func _yeni_tepki() -> Tween:
	if _tepki != null:
		_tepki.kill()
	ek_yanak = 0.0
	ek_agiz = 0.0
	_tepki = create_tween()
	return _tepki


func _ufle() -> void:
	efekt.emit("ofle")
	var m := agiz_yeri()
	for i in 7:
		_pufler.append({
			"p": m + Vector2(randf_range(2, 10), randf_range(-3, 3)),
			"v": Vector2(randf_range(30, 70), randf_range(-20, 4)),
			"r": randf_range(2.5, 4.5),
			"omur": -i * 0.035,
			"sure": randf_range(0.7, 1.15),
		})
	_nida.text = OFLEMELER[randi() % OFLEMELER.size()]
	_nida.reset_size()
	_nida.position = Vector2(clampf(m.x + 26.0, 0.0, maxf(0.0, size.x - _nida.size.x)), maxf(2.0, m.y - 46.0))
	_nida.modulate.a = 0.0
	_nida.visible = true
	var t := create_tween()
	t.tween_property(_nida, "modulate:a", 1.0, 0.12)
	t.parallel().tween_property(_nida, "position:y", _nida.position.y - 16.0, 1.3)
	t.tween_property(_nida, "modulate:a", 0.0, 0.4).set_delay(0.5)
	t.tween_callback(func() -> void: _nida.visible = false)


# --- Sürekli hareket ---

func _process(delta: float) -> void:
	if kimlik == "":
		return
	_zaman += delta

	# Göz kırpma: rastgele aralıklarla, kısa.
	if _kirpma_suresi >= 0.0:
		_kirpma_suresi += delta
		var u := _kirpma_suresi / 0.16
		_kirpma = sin(clampf(u, 0.0, 1.0) * PI)
		if u >= 1.0:
			_kirpma_suresi = -1.0
			_kirpma = 0.0
			_kirpma_bekleme = 0.22 if randf() < 0.18 else randf_range(1.8, 5.2)
	else:
		_kirpma_bekleme -= delta
		if _kirpma_bekleme <= 0.0 and _goz_var:
			_kirpma_suresi = 0.0

	# Konuşma: heceler hâlinde açılıp kapanan ağız.
	if konusuyor:
		_hece_kalan -= delta
		if _hece_kalan <= 0.0:
			_hece_kalan = randf_range(0.07, 0.14)
			_agiz_hedef = 0.0 if _agiz_hedef > 0.2 else randf_range(0.30, 0.78)
			if _agiz_hedef > 0.2:
				efekt.emit("hece")
	else:
		_agiz_hedef = 0.0
	_agiz = lerpf(_agiz, _agiz_hedef, clampf(delta * 26.0, 0.0, 1.0))

	# Yürüme: adım atarken inip kalkma ve iki yana sallanma.
	_yurume = move_toward(_yurume, 1.0 if yuruyor else 0.0, delta * 5.0)
	if _yurume > 0.0:
		var onceki := sin(_adim)
		_adim += delta * 10.0
		if onceki < 0.0 and sin(_adim) >= 0.0:
			efekt.emit("adim")

	var nefes := 0.5 + 0.5 * sin(_zaman * 1.45 + _faz)
	var bas := Vector2(0.0034 * sin(_zaman * 0.63 + _faz * 2.0), 0.0018 * sin(_zaman * 0.9 + _faz))
	var egim := 0.011 * sin(_zaman * 0.41 + _faz * 1.7)
	var kas := 0.0
	if konusuyor:
		bas.y += 0.0045 * _agiz
		egim += 0.008 * sin(_zaman * 5.3)
		kas += 0.35 * sin(_zaman * 2.1)
	bas.y += 0.007 * absf(sin(_adim)) * _yurume
	egim += 0.035 * sin(_adim) * _yurume
	rotation = 0.022 * sin(_adim) * _yurume

	_malzeme.set_shader_parameter("kirpma", _kirpma)
	_malzeme.set_shader_parameter("agiz_acik", clampf(_agiz + ek_agiz, 0.0, 1.0))
	_malzeme.set_shader_parameter("yanak", ek_yanak)
	_malzeme.set_shader_parameter("bas", bas + ek_bas)
	_malzeme.set_shader_parameter("bas_egim", egim + ek_egim)
	_malzeme.set_shader_parameter("nefes", nefes + ek_nefes)
	_malzeme.set_shader_parameter("kas", kas + ek_kas)

	if not _pufler.is_empty():
		for i in range(_pufler.size() - 1, -1, -1):
			var p := _pufler[i]
			p.omur += delta
			if p.omur < 0.0:
				continue
			p.p += p.v * delta
			p.v *= 1.0 - 1.6 * delta
			p.r += 9.0 * delta
			if p.omur >= p.sure:
				_pufler.remove_at(i)
		_efekt_katmani.queue_redraw()


## Soğuk salonda üflenen nefes: büyüyüp solan beyaz bulutçuklar.
func _pufleri_ciz() -> void:
	for p in _pufler:
		if p.omur < 0.0:
			continue
		var u: float = p.omur / p.sure
		var alfa := sin(u * PI) * 0.17
		_efekt_katmani.draw_circle(p.p, p.r, Color(1, 1, 1, alfa))
		_efekt_katmani.draw_circle(p.p + Vector2(-1, -1), p.r * 0.62, Color(1, 1, 1, alfa * 0.8))
