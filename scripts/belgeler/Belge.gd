class_name Belge
extends Control
## Masadaki bir evrakın ortak davranışı: sözlükten dolma, sürükleme, çift tıkla büyütme,
## gişe yarığından kayarak gelme ve inceleme modunda tıklanabilir alanlar.
##
## Alt sınıflar _kur() içinde öğelerini TABAN ölçüde (k = 1) tanımlar; büyütülünce yazılar
## bulanmasın diye öğeler ölçeklenmez, yeni puntoyla yeniden yerleştirilir (_olcekle).

signal alindi(belge: Belge)
signal birakildi(belge: Belge)
signal hedef_tiklandi(hedef: Hedef)

const BUYUTME := 1.6
const SAHNELER := {
	"nufus_cuzdani": "res://scenes/belgeler/NufusCuzdani.tscn",
	"ikametgah": "res://scenes/belgeler/Ikametgah.tscn",
	"harc_makbuzu": "res://scenes/belgeler/HarcMakbuzu.tscn",
}
const ADLAR := {
	"nufus_cuzdani": "Nüfus cüzdanı",
	"ikametgah": "İkametgâh ilmühaberi",
	"harc_makbuzu": "Harç makbuzu",
}
const BASLIK_RENGI := Color("5a5f66")

var tur := ""
var veri: Dictionary = {}
var alanlar: Dictionary = {}          ## anahtar -> Hedef
var sinir: Rect2 = Yerlesim.MASA_ALANI  ## normal boyutta gezebildiği alan (ebeveyn koordinatı)
var buyuk := false
var kilitli := false                   ## karar verildikten sonra yerinden oynamaz

var _taban := Vector2(300, 200)
var _ogeler: Array[Dictionary] = []    ## {d: Control, r: Rect2 (taban), p: punto}
var _k := 1.0
var _surukleniyor := false
var _tutma := Vector2.ZERO
var _gecis: Tween


static func olustur(v: Dictionary) -> Belge:
	var yol: String = SAHNELER.get(str(v.get("tur", "")), "")
	if yol == "":
		push_warning("Bilinmeyen belge türü: %s" % str(v.get("tur", "")))
		return null
	var b: Belge = (load(yol) as PackedScene).instantiate()
	b.doldur(v)
	return b


static func tur_adi(t: String) -> String:
	return ADLAR.get(t, t)


## Belgeyi sözlükten doldurur: {tur, alanlar: {...}, ...}
func doldur(v: Dictionary) -> void:
	veri = v
	tur = str(v.get("tur", tur))
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_ogeler.clear()
	alanlar.clear()
	_kur()
	_olcekle(_k)


## Alt sınıflar öğelerini burada kurar.
func _kur() -> void:
	pass


func al(anahtar: String) -> Variant:
	return (veri.get("alanlar", {}) as Dictionary).get(anahtar, "")


func metin(anahtar: String) -> String:
	return str(al(anahtar))


func inceleme_ac(acik: bool) -> void:
	for h: Hedef in alanlar.values():
		h.aktif = acik


func isaretleri_temizle() -> void:
	for h: Hedef in alanlar.values():
		h.durum = Hedef.Durum.BOS


# --- Kurulum yardımcıları (taban koordinatlarıyla) ---

func _yazi(yazi: String, alan: Rect2, punto: float, renk: Color = Stil.MUREKKEP,
		font: Font = null, hiza: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, sar: bool = false) -> Label:
	var l := Label.new()
	l.text = yazi
	l.add_theme_color_override("font_color", renk)
	l.add_theme_font_override("font", font if font != null else Stil.daktilo())
	l.horizontal_alignment = hiza
	l.mouse_filter = MOUSE_FILTER_IGNORE
	if sar:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_constant_override("line_spacing", 0)
	add_child(l)
	_ogeler.append({"d": l, "r": alan, "p": punto})
	return l


func _hedef(anahtar: String, etiket: String, deger: Variant, alan: Rect2) -> Hedef:
	var h := Hedef.new()
	h.tip = "alan"
	h.anahtar = anahtar
	h.etiket = etiket
	h.deger = deger
	h.belge_turu = tur
	h.tiklandi.connect(func(x: Hedef) -> void: hedef_tiklandi.emit(x))
	add_child(h)
	alanlar[anahtar] = h
	_ogeler.append({"d": h, "r": alan, "p": 0.0})
	return h


## Basılı başlık + daktilo değeri + tıklanabilir alan.
func _satir(anahtar: String, baslik: String, x: float, y: float, w: float,
		punto: float = 14.0, renk: Color = Stil.MUREKKEP, kalin: bool = false) -> Hedef:
	_yazi(baslik, Rect2(x, y, w, 12), 8.5, BASLIK_RENGI, Stil.serif())
	_yazi(_deger_metni(anahtar), Rect2(x, y + 10, w, punto + 7), punto, renk,
		Stil.daktilo_kalin() if kalin else Stil.daktilo())
	return _hedef(anahtar, baslik, al(anahtar), Rect2(x - 3, y, w + 6, punto + 17))


func _deger_metni(anahtar: String) -> String:
	var d: Variant = al(anahtar)
	if anahtar == "tutar":
		return Stil.tl(int(d))
	if anahtar == "islem":
		return Islemler.adi(str(d))
	return str(d)


func _oge(d: Control, alan: Rect2) -> void:
	d.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(d)
	_ogeler.append({"d": d, "r": alan, "p": 0.0})


func _olcekle(k: float) -> void:
	_k = k
	size = _taban * k
	for o in _ogeler:
		var d: Control = o.d
		var r: Rect2 = o.r
		if o.p > 0.0:
			d.add_theme_font_size_override("font_size", maxi(6, roundi(o.p * k)))
		d.position = r.position * k
		d.size = r.size * k
	pivot_offset = size / 2.0
	queue_redraw()


# --- Çizim yardımcıları (taban koordinatı → ekran) ---

func _r(x: float, y: float, w: float, h: float) -> Rect2:
	return Rect2(x * _k, y * _k, w * _k, h * _k)


func _v(x: float, y: float) -> Vector2:
	return Vector2(x, y) * _k


func _kagit_ciz(renk: Color, kenar: Color, kose: int = 2) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = renk
	sb.border_color = kenar
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(roundi(kose * _k))
	sb.anti_aliasing = true
	sb.shadow_color = Color(0, 0, 0, 0.30 if _surukleniyor or buyuk else 0.38)
	sb.shadow_size = roundi((12 if _surukleniyor or buyuk else 4) * _k)
	sb.shadow_offset = Vector2(3, 5) * _k * (2.0 if _surukleniyor or buyuk else 1.0)
	draw_style_box(sb, Rect2(Vector2.ZERO, size))


## Basılı formlardaki noktalı doldurma çizgisi.
func _noktali(x0: float, x1: float, y: float, renk: Color = Color(0, 0, 0, 0.35)) -> void:
	draw_dashed_line(_v(x0, y), _v(x1, y), renk, maxf(1.0, _k * 0.8), 2.0 * _k)


## Tohuma bağlı, okunmaz ama akıcı bir imza karalaması.
func _imza_ciz(alan: Rect2, tohum: int, renk: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = tohum
	var faz := rng.randf() * TAU
	var f1 := rng.randf_range(2.4, 4.2)
	var f2 := rng.randf_range(5.0, 8.5)
	var egim := rng.randf_range(-0.18, 0.05)
	var noktalar := PackedVector2Array()
	var adim := 40
	for i in adim + 1:
		var t := float(i) / adim
		var genlik := 0.42 * (1.0 - 0.55 * t)
		var x := alan.position.x + alan.size.x * (0.04 + 0.86 * t + 0.045 * sin(t * f2 * TAU + faz))
		var y := alan.position.y + alan.size.y * (0.52 + egim * (t - 0.5)
			+ genlik * sin(t * f1 * TAU + faz) + 0.10 * sin(t * f2 * TAU))
		noktalar.append(Vector2(x, y) * _k)
	draw_polyline(noktalar, renk, 1.25 * _k, true)
	var son := noktalar[noktalar.size() - 1]
	draw_line(son, son + Vector2(alan.size.x * 0.10, -alan.size.y * 0.30) * _k, renk, 1.1 * _k, true)


# --- Sürükleme ve büyütme ---

func _gui_input(event: InputEvent) -> void:
	if kilitli:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if event.double_click:
				_surukleniyor = false
				buyut(not buyuk)
			else:
				_surukleniyor = true
				_tutma = get_transform() * event.position - position
				move_to_front()
				queue_redraw()
				alindi.emit(self)
		elif _surukleniyor:
			_surukleniyor = false
			queue_redraw()
			birakildi.emit(self)
		accept_event()
	elif event is InputEventMouseMotion and _surukleniyor:
		position = _sinirla(get_transform() * event.position - _tutma)
		accept_event()


func _sinirla(p: Vector2) -> Vector2:
	var alan: Rect2 = Yerlesim.EKRAN if buyuk else sinir
	var maks := alan.end - size
	return Vector2(clampf(p.x, alan.position.x, maxf(alan.position.x, maks.x)),
		clampf(p.y, alan.position.y, maxf(alan.position.y, maks.y)))


## Çift tıklayınca: belge yerinde büyür (yazılar yeni puntoyla keskin kalır).
func buyut(b: bool) -> void:
	if b == buyuk:
		return
	buyuk = b
	var eski := _k
	var yeni := BUYUTME if b else 1.0
	var orta := position + size / 2.0
	_olcekle(yeni)
	position = _sinirla(orta - size / 2.0)
	move_to_front()
	scale = Vector2.ONE * (eski / yeni)
	if _gecis != null:
		_gecis.kill()
	_gecis = create_tween()
	_gecis.tween_property(self, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# --- Gişe yarığından geliş / gidiş ---

func gel(yarik: Vector2, hedef_konum: Vector2, gecikme: float = 0.0) -> void:
	position = yarik - size / 2.0
	scale = Vector2(0.30, 0.08)
	modulate.a = 0.0
	var t := create_tween()
	t.tween_interval(gecikme)
	t.tween_property(self, "modulate:a", 1.0, 0.06)
	t.parallel().tween_property(self, "position", _sinirla(hedef_konum), 0.46) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "scale", Vector2.ONE, 0.40) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func git(yarik: Vector2, gecikme: float = 0.0) -> void:
	kilitli = true
	_surukleniyor = false
	var t := create_tween()
	t.tween_interval(gecikme)
	t.tween_property(self, "position", yarik - size / 2.0, 0.34) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(self, "scale", Vector2(0.30, 0.08), 0.34) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_property(self, "modulate:a", 0.0, 0.05)
	t.tween_callback(queue_free)


# --- Karar izleri (mühür, fiş) ---

## Belgenin üstüne karar izi bırakır. `yerel` belge içi konumdur (ekran ölçeğinde).
func iz_birak(karar: String, yerel: Vector2, satirlar: PackedStringArray) -> void:
	var iz := KararIzi.new()
	iz.karar = karar
	iz.satirlar = satirlar
	iz.belge = self
	var boyut := Vector2(176, 74) if karar == "onay" else Vector2(168, 66)
	var konum := yerel / _k - boyut / 2.0
	konum.x = clampf(konum.x, 4, maxf(4, _taban.x - boyut.x - 4))
	konum.y = clampf(konum.y, 4, maxf(4, _taban.y - boyut.y - 4))
	iz.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(iz)
	_ogeler.append({"d": iz, "r": Rect2(konum, boyut), "p": 0.0})
	_olcekle(_k)
	iz.pivot_offset = iz.size / 2.0
	iz.scale = Vector2.ONE * 1.5
	iz.modulate.a = 0.0
	var t := iz.create_tween()
	t.tween_property(iz, "scale", Vector2.ONE, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(iz, "modulate:a", 1.0, 0.05)


## Onay mührü ya da zımbalı fiş.
class KararIzi extends Control:
	var karar := "onay"
	var satirlar := PackedStringArray()
	var belge: Belge

	func _draw() -> void:
		var k := size.x / (176.0 if karar == "onay" else 168.0)
		if karar == "onay":
			_muhur(k)
		else:
			_fis(k)

	func _muhur(k: float) -> void:
		var renk := Color(Stil.BORDO, 0.86)
		draw_set_transform(size / 2.0, deg_to_rad(-7.0), Vector2.ONE)
		var r := Rect2(-size / 2.0 + Vector2(4, 4) * k, size - Vector2(8, 8) * k)
		draw_rect(r, renk, false, 2.6 * k)
		draw_rect(r.grow(-4.0 * k), renk, false, 1.0 * k)
		var f := Stil.daktilo_kalin()
		var y := -size.y / 2.0 + 27.0 * k
		for i in satirlar.size():
			var punto := roundi((16.0 if i == 0 else 10.0) * k)
			draw_string(f, Vector2(-size.x / 2.0, y), satirlar[i], HORIZONTAL_ALIGNMENT_CENTER, size.x, punto, renk)
			y += (17.0 if i == 0 else 13.5) * k
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _fis(k: float) -> void:
		var kenar := Stil.KIRMIZI if karar == "eksik" else Stil.MAVI_MUREKKEP
		draw_set_transform(size / 2.0, deg_to_rad(3.0), Vector2.ONE)
		var r := Rect2(-size / 2.0, size)
		draw_rect(Rect2(r.position + Vector2(2, 3) * k, r.size), Color(0, 0, 0, 0.25))
		draw_rect(r, Stil.KAGIT_BEYAZ)
		draw_rect(r, kenar, false, 2.0 * k)
		draw_rect(Rect2(r.position, Vector2(r.size.x, 17.0 * k)), kenar)
		var f := Stil.daktilo_kalin()
		var y := r.position.y + 13.0 * k
		for i in satirlar.size():
			var renk := Stil.KAGIT_BEYAZ if i == 0 else Stil.MUREKKEP
			var punto := roundi((11.0 if i == 0 else 10.0) * k)
			draw_string(f if i == 0 else Stil.daktilo(), Vector2(r.position.x + 5.0 * k, y), satirlar[i],
				HORIZONTAL_ALIGNMENT_CENTER if i == 0 else HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 10.0 * k, punto, renk)
			y += (19.0 if i == 0 else 13.0) * k
		# zımba teli
		draw_line(r.position + Vector2(r.size.x / 2.0 - 7.0 * k, -1.0 * k),
			r.position + Vector2(r.size.x / 2.0 + 7.0 * k, -1.0 * k), Color("6f7478"), 2.0 * k)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
