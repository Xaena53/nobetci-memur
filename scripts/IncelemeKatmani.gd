class_name IncelemeKatmani
extends Control
## İnceleme modu: oyuncu iki hedef (belge alanı, kural, yüz, takvim, defterdeki örnek) seçer; aralarına
## çizgi çekilir. Karşılaştırmanın kendisi dışarıdan verilen `karsilastir` çağrısıyla yapılır.
##
## Sonucun söylenip söylenmeyeceği görev şekline bağlıdır (`kip`):
##  - "acik"  : her karşılaştırmada "Uyuşmazlık: ..." ya da "Sorun yok" balonu çıkar (kolay).
##  - "hak"   : balon "ipucu ister misiniz?" diye sorar; tıklanırsa bir hak harcanır ve sonuç açılır (orta).
##  - "kapali": yalnızca çizgi çekilir; karar memurundur (zor).

signal bulgu(sonuc: Dictionary)
signal mod_degisti(acik: bool)
signal ipucu_kullanildi(kalan: int)

const NOTR := "Yan yana kondu. Karar sizin."

const BALON_GENISLIK := 270.0
const BALON_PUNTO := 14
const BALON_BOSLUK := Vector2(12, 8)

var karsilastir: Callable   ## func(a: Hedef, b: Hedef) -> {durum, mesaj, gerekce}
var kip := "acik"
var ipucu_kalan := 0        ## "hak" kipinde kalan ipucu hakkı

var aktif := false:
	set(a):
		if aktif == a:
			return
		aktif = a
		if not a:
			_secimi_birak()
		mod_degisti.emit(a)

var _ilk: Hedef
var _cizgiler: Array[Dictionary] = []   ## {a, b, renk, omur}  (omur < 0: kalıcı)
var _balon: Panel
var _balon_yazi: Label
var _balon_omru := 0.0
var _bekleyen: Dictionary = {}          ## ipucu sorulan karşılaştırma: {a, b, sonuc}


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	_balon = Panel.new()
	_balon.name = "IncelemeBalonu"
	_balon.mouse_filter = MOUSE_FILTER_IGNORE
	_balon.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	_balon.gui_input.connect(_balona_basildi)
	_balon.visible = false
	_balon_yazi = Stil.etiket("", BALON_PUNTO, Stil.MUREKKEP, Stil.daktilo_kalin())
	_balon_yazi.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_balon_yazi.position = BALON_BOSLUK
	_balon_yazi.size = Vector2(BALON_GENISLIK, 20)
	_balon.add_child(_balon_yazi)
	add_child(_balon)


func hedef_tiklandi(h: Hedef) -> void:
	if not aktif:
		return
	if _ilk == null or not is_instance_valid(_ilk):
		_ilk = h
		if h.durum != Hedef.Durum.UYUSMAZ:
			h.durum = Hedef.Durum.SECILI
		return
	if _ilk == h:
		_secimi_birak()
		return
	var a := _ilk
	_secimi_birak()
	var sonuc: Dictionary = karsilastir.call(a, h) if karsilastir.is_valid() else {"durum": "ilgisiz", "mesaj": ""}
	var durum := str(sonuc.get("durum", "ilgisiz"))
	var hukum := durum == "uyumlu" or durum == "uyusmaz"
	_bekleyen = {}
	if kip == "kapali":
		_goster(a, h, {"durum": "notr", "mesaj": NOTR})
		return
	if kip == "hak" and hukum:
		if ipucu_kalan <= 0:
			_goster(a, h, {"durum": "notr", "mesaj": "İpucu hakkınız kalmadı. Karar sizin."})
			return
		_bekleyen = {"a": a, "b": h, "sonuc": sonuc}
		_goster(a, h, {"durum": "soru", "mesaj": "İpucu ister misiniz? Bu kâğıda tıklayın (kalan hak: %d)." % ipucu_kalan})
		return
	_sonucu_ac(a, h, sonuc)


## Bekleyen karşılaştırmanın sonucunu bir ipucu hakkı harcayarak açar ("hak" kipi).
func ipucunu_kullan() -> bool:
	if _bekleyen.is_empty() or ipucu_kalan <= 0:
		return false
	var a := _bekleyen.a as Hedef
	var b := _bekleyen.b as Hedef
	var sonuc: Dictionary = _bekleyen.sonuc
	_bekleyen = {}
	if not is_instance_valid(a) or not is_instance_valid(b):
		return false
	ipucu_kalan -= 1
	# soru çizgisini kaldır, gerçek sonucu göster
	for i in range(_cizgiler.size() - 1, -1, -1):
		if _cizgiler[i].a == a and _cizgiler[i].b == b:
			_cizgiler.remove_at(i)
	_sonucu_ac(a, b, sonuc)
	ipucu_kullanildi.emit(ipucu_kalan)
	return true


func _sonucu_ac(a: Hedef, h: Hedef, sonuc: Dictionary) -> void:
	_goster(a, h, sonuc)
	sonuc["a"] = a
	sonuc["b"] = h
	bulgu.emit(sonuc)


func _balona_basildi(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_balon.accept_event()
		ipucunu_kullan()


## Vatandaş giderken: bütün çizgiler ve seçimler silinir.
func temizle() -> void:
	_secimi_birak()
	_cizgiler.clear()
	_bekleyen = {}
	_balon.visible = false
	_balon.mouse_filter = MOUSE_FILTER_IGNORE
	queue_redraw()


func _secimi_birak() -> void:
	if _ilk != null and is_instance_valid(_ilk) and _ilk.durum == Hedef.Durum.SECILI:
		_ilk.durum = Hedef.Durum.BOS
	_ilk = null


func _goster(a: Hedef, b: Hedef, sonuc: Dictionary) -> void:
	var durum := str(sonuc.get("durum", "ilgisiz"))
	var renk := Stil.KIRMIZI
	var omur := -1.0
	match durum:
		"uyusmaz":
			a.durum = Hedef.Durum.UYUSMAZ
			b.durum = Hedef.Durum.UYUSMAZ
		"uyumlu":
			renk = Stil.YESIL
			omur = 1.6
			for h: Hedef in [a, b]:
				if h.durum != Hedef.Durum.UYUSMAZ:
					h.durum = Hedef.Durum.UYUMLU
			# Düğümleri değil kimliklerini yakala: belge bu arada masadan kalkmış olabilir.
			var kimlikler := [a.get_instance_id(), b.get_instance_id()]
			Oyun.bekle(1.6).connect(func() -> void:
				for k: int in kimlikler:
					var h := instance_from_id(k) as Hedef
					if h != null and h.durum == Hedef.Durum.UYUMLU:
						h.durum = Hedef.Durum.BOS)
		"soru":
			renk = Stil.MAVI_MUREKKEP
			omur = 6.0
		"notr":
			renk = Color(Stil.MUREKKEP, 0.7)
			omur = 3.2
		_:
			renk = Color(Stil.MUREKKEP, 0.55)
			omur = 1.2
	_cizgiler.append({"a": a, "b": b, "renk": renk, "omur": omur})
	_balonu_ac(str(sonuc.get("mesaj", "")), renk, (a.merkez() + b.merkez()) / 2.0, durum == "uyusmaz")
	# ipucu sorusu: balon tıklanabilir olur ve daha uzun kalır
	_balon.mouse_filter = MOUSE_FILTER_STOP if durum == "soru" else MOUSE_FILTER_IGNORE
	if durum == "soru":
		_balon_omru = 6.0
	queue_redraw()


func _balonu_ac(mesaj: String, renk: Color, orta: Vector2, kalin_kenar: bool) -> void:
	if mesaj == "":
		_balon.visible = false
		return
	_balon.add_theme_stylebox_override("panel", Stil.kutu(Stil.KAGIT_BEYAZ, renk, 3 if kalin_kenar else 2, 3, 6))
	_balon_yazi.add_theme_color_override("font_color", renk.darkened(0.25) if kalin_kenar else Stil.MUREKKEP)
	_balon_yazi.text = mesaj
	# Sarılan etiketin boyutu elle hesaplanır (kapsayıcılar sarılı metni baştan yanlış ölçer).
	var metin_boyutu := Stil.daktilo_kalin().get_multiline_string_size(mesaj, HORIZONTAL_ALIGNMENT_LEFT,
		BALON_GENISLIK, BALON_PUNTO)
	_balon_yazi.size = Vector2(BALON_GENISLIK, metin_boyutu.y)
	var boyut := Vector2(minf(BALON_GENISLIK, metin_boyutu.x + 2.0), metin_boyutu.y) + 2.0 * BALON_BOSLUK
	_balon.size = boyut
	_balon.visible = true
	var p := orta - Vector2(boyut.x / 2.0, boyut.y + 14.0)
	var ekran := Yerlesim.EKRAN.size
	p.x = clampf(p.x, 8.0, ekran.x - boyut.x - 8.0)
	p.y = clampf(p.y, 8.0, ekran.y - boyut.y - 8.0)
	_balon.position = p
	_balon_omru = 3.4 if kalin_kenar else 2.0
	_balon.modulate.a = 1.0


func _process(delta: float) -> void:
	if _balon.visible:
		_balon_omru -= delta
		if _balon_omru <= 0.0:
			_balon.visible = false
			_balon.mouse_filter = MOUSE_FILTER_IGNORE
			_bekleyen = {}
		elif _balon_omru < 0.4:
			_balon.modulate.a = _balon_omru / 0.4
	if _cizgiler.is_empty():
		return
	for i in range(_cizgiler.size() - 1, -1, -1):
		var c := _cizgiler[i]
		if not is_instance_valid(c.a) or not is_instance_valid(c.b):
			_cizgiler.remove_at(i)
			continue
		if c.omur > 0.0:
			c.omur -= delta
			if c.omur <= 0.0:
				_cizgiler.remove_at(i)
	queue_redraw()


func _draw() -> void:
	for c in _cizgiler:
		if not is_instance_valid(c.a) or not is_instance_valid(c.b):
			continue
		var p1: Vector2 = (c.a as Hedef).merkez()
		var p2: Vector2 = (c.b as Hedef).merkez()
		var renk: Color = c.renk
		if c.omur > 0.0 and c.omur < 0.4:
			renk.a *= c.omur / 0.4
		draw_line(p1, p2, Color(0, 0, 0, 0.18 * renk.a), 5.0, true)
		draw_line(p1, p2, renk, 2.6, true)
		draw_circle(p1, 4.5, renk)
		draw_circle(p2, 4.5, renk)
