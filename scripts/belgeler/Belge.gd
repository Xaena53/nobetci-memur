class_name Belge
extends Control
## Masadaki bir evrakın ortak davranışı: sözlükten dolma, sürükleme, çift tıkla büyütme,
## gişe yarığından kayarak gelme ve inceleme modunda tıklanabilir alanlar.
##
## Belge masada bir MasaNesnesi taşıyıcısının içinde durur: masadayken perspektife uyup hafifçe
## yatık görünür; çift tıklanınca oyuncunun eline kalkar, düzleşir ve büyür.
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
var tutucu: MasaNesnesi               ## masadaki taşıyıcısı (masaya_koy ile kurulur)
var sinir: Rect2 = Yerlesim.MASA_BELGE_ALANI  ## masada gezebildiği alan (masa koordinatı)
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


## Belgeyi bir taşıyıcıya koyup verilen katmana (masaya) ekler.
func masaya_koy(katman: Node) -> MasaNesnesi:
	tutucu = MasaNesnesi.new()
	tutucu.name = "Tutucu_" + tur
	katman.add_child(tutucu)
	tutucu.add_child(self)
	tutucu.ortala()
	return tutucu


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
	if tutucu != null:
		tutucu.ortala()
	queue_redraw()


# --- Çizim yardımcıları (taban koordinatı → ekran) ---

func _r(x: float, y: float, w: float, h: float) -> Rect2:
	return Rect2(x * _k, y * _k, w * _k, h * _k)


func _v(x: float, y: float) -> Vector2:
	return Vector2(x, y) * _k


## Belgenin kâğıdını (boyama doku + gölge) çizer. Elde ya da sürüklenirken gölge büyür.
func _kagit_ciz(doku_adi: String, yedek: Color, tasma: float = 2.0) -> void:
	var havada := _surukleniyor or buyuk
	Kagit.ciz(self, Rect2(Vector2.ZERO, size), doku_adi, yedek, (11.0 if havada else 4.0) * _k, tasma * _k)


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
	if kilitli or tutucu == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var fare: Vector2 = get_global_transform() * event.position
		if event.pressed:
			if event.double_click:
				_surukleniyor = false
				buyut(not buyuk)
			else:
				_surukleniyor = true
				_tutma = (fare - tutucu.ekran_konumu) if buyuk else (Perspektif.masaya(fare) - tutucu.masa_konumu)
				tutucu.move_to_front()
				queue_redraw()
				alindi.emit(self)
		elif _surukleniyor:
			_surukleniyor = false
			queue_redraw()
			birakildi.emit(self)
		accept_event()
	elif event is InputEventMouseMotion and _surukleniyor:
		var fare: Vector2 = get_global_transform() * event.position
		if buyuk:
			tutucu.ekran_konumu = _ekranda_sinirla(fare - _tutma)
		else:
			tutucu.masa_konumu = _masada_sinirla(Perspektif.masaya(fare) - _tutma)
		accept_event()


## Belgenin ortasını masadaki gezinme alanının içinde tutar (masa koordinatı).
func _masada_sinirla(p: Vector2) -> Vector2:
	var yari := _taban / 2.0
	var en_az := sinir.position + yari
	var en_cok := sinir.end - yari
	var q := Vector2(clampf(p.x, en_az.x, maxf(en_az.x, en_cok.x)), clampf(p.y, en_az.y, maxf(en_az.y, en_cok.y)))
	# Teleks cihazının altına girmesin: en az yer değiştirmeyle aşağı ya da sola it.
	var engel: Rect2 = Yerlesim.TELEKS_ENGEL
	var kutu := Rect2(q - yari, _taban)
	if kutu.intersects(engel):
		var asagi := engel.end.y - kutu.position.y
		var sola := kutu.end.x - engel.position.x
		var asagi_olur := q.y + asagi <= en_cok.y
		var sola_olur := q.x - sola >= en_az.x
		if asagi_olur and (asagi <= sola or not sola_olur):
			q.y += asagi
		elif sola_olur:
			q.x -= sola
	return q


## Elde tutulan (büyütülmüş) belgenin ortasını ekranın içinde tutar.
func _ekranda_sinirla(p: Vector2) -> Vector2:
	var e: Rect2 = Yerlesim.EKRAN
	var yari := size / 2.0
	var x := e.get_center().x if size.x >= e.size.x else clampf(p.x, e.position.x + yari.x, e.end.x - yari.x)
	var y := e.get_center().y if size.y >= e.size.y else clampf(p.y, e.position.y + yari.y, e.end.y - yari.y)
	return Vector2(x, y)


## Çift tıklayınca: belge masadan kalkar, düzleşir ve büyür (yazılar yeni puntoyla keskin kalır).
func buyut(b: bool) -> void:
	if b == buyuk or tutucu == null:
		return
	buyuk = b
	var eski := _k
	var yeni := BUYUTME if b else 1.0
	if b:
		var simdi := Perspektif.ekrana(tutucu.masa_konumu)
		_olcekle(yeni)
		tutucu.ekran_konumu = _ekranda_sinirla(simdi + Vector2(0, -30))
		tutucu.kalkisa_gec(1.0)
	else:
		_olcekle(yeni)
		tutucu.masa_konumu = _masada_sinirla(Perspektif.masaya(tutucu.ekran_konumu))
		tutucu.kalkisa_gec(0.0)
	tutucu.move_to_front()
	scale = Vector2.ONE * (eski / yeni)
	if _gecis != null:
		_gecis.kill()
	_gecis = create_tween()
	_gecis.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# --- Gişe yarığından geliş / gidiş ---

## `yarik`: yarığın ekrandaki yeri; `hedef`: belgenin ortasının masada konacağı yer (masa koordinatı).
func gel(yarik: Vector2, hedef: Vector2, gecikme: float = 0.0) -> void:
	tutucu.ekran_konumu = yarik
	tutucu.masa_konumu = _masada_sinirla(hedef)
	tutucu.kalkis = 1.0
	scale = Vector2(0.30, 0.08)
	modulate.a = 0.0
	var t := create_tween()
	t.tween_interval(gecikme)
	t.tween_property(self, "modulate:a", 1.0, 0.06)
	t.parallel().tween_property(tutucu, "kalkis", 0.0, 0.46).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "scale", Vector2.ONE, 0.40) 		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func git(yarik: Vector2, gecikme: float = 0.0) -> void:
	kilitli = true
	_surukleniyor = false
	tutucu.gecisi_durdur()
	if _gecis != null:
		_gecis.kill()
	if buyuk:
		buyuk = false
		_olcekle(1.0)
	var t := create_tween()
	t.tween_interval(gecikme)
	if tutucu.kalkis >= 0.5:        # eldeyse doğrudan yarığa süzülür
		tutucu.kalkis = 1.0
		t.tween_property(tutucu, "ekran_konumu", yarik, 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	else:
		tutucu.kalkis = 0.0
		tutucu.ekran_konumu = yarik
		t.tween_property(tutucu, "kalkis", 1.0, 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(self, "scale", Vector2(0.30, 0.08), 0.34) 		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_property(self, "modulate:a", 0.0, 0.05)
	t.tween_callback(tutucu.queue_free)


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
