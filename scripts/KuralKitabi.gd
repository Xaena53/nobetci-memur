class_name KuralKitabi
extends Control
## Genelge defteri: mantar panoya iğnelenmiş daktilo sayfaları. İlk sayfalarda günün kuralları,
## son sayfada tarife ve listeler (harç, seri aralıkları, mahalleler) bulunur. İnceleme modunda
## her satır tıklanabilir bir hedeftir.

signal hedef_tiklandi(hedef: Hedef)
signal sayfa_cevrildi

const KAGIT_YERI := Rect2(6, 24, 314, 342)
const KENAR := 14.0
const PUNTO := 12
const BASLIK_PUNTO := 13

var hedefler: Array[Hedef] = []
var sayfa := 0

var _sayfalar: Array[Control] = []
var _sekmeler: Array[Button] = []
var _basliklar: Array[String] = []
var _inceleme := false


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


## gun: {tarih, kurallar: [{id, tur, metin, yeni, ...}]}
func yukle(gun: Dictionary) -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_sayfalar.clear()
	_sekmeler.clear()
	_basliklar.clear()
	hedefler.clear()

	var kurallar: Array = gun.get("kurallar", [])
	var genislik := KAGIT_YERI.size.x - 2.0 * KENAR
	var alt_sinir := KAGIT_YERI.size.y - 14.0

	# --- Kural sayfaları ---
	var s := _yeni_sayfa("KURALLAR")
	var y := _baslik_yaz(s, "GENELGE DEFTERİ", Tarih.uzun(str(gun.get("tarih", "")), false))
	var no := 0
	for k: Dictionary in kurallar:
		if str(k.get("metin", "")) == "":
			continue
		no += 1
		var yazi := "%d. %s" % [no, str(k.metin)]
		var yuk := _yukseklik(yazi, genislik, Stil.daktilo(), PUNTO)
		if y + yuk > alt_sinir:
			s = _yeni_sayfa("KURALLAR-%d" % (_sayfalar.size() + 1))
			y = _baslik_yaz(s, "GENELGE DEFTERİ", "(devam)")
		var yeni := bool(k.get("yeni", false))
		_satir_yaz(s, yazi, y, genislik, yuk, k, Stil.BORDO if yeni else Stil.MUREKKEP)
		if yeni:
			var isaret := Stil.etiket("YENİ", 9, Stil.BORDO, Stil.daktilo_kalin())
			isaret.position = Vector2(KAGIT_YERI.size.x - 40.0, y - 8.0)
			isaret.rotation = deg_to_rad(-8.0)
			s.add_child(isaret)
		y += yuk + 7.0

	# --- Tarife ve listeler ---
	var tablolar: Array[Dictionary] = []
	for k: Dictionary in kurallar:
		if str(k.get("tur", "")) in ["harc_tutar", "seri_aralik", "mahalle_listesi"]:
			tablolar.append(k)
	if not tablolar.is_empty():
		s = _yeni_sayfa("TARİFE")
		y = _baslik_yaz(s, "TARİFE VE LİSTELER", "")
		for k in tablolar:
			y = _tablo_yaz(s, k, y, genislik) + 10.0

	_sekmeleri_kur()
	sayfaya_gec(0, false)
	inceleme_ac(_inceleme)


func inceleme_ac(acik: bool) -> void:
	_inceleme = acik
	for h in hedefler:
		h.aktif = acik


func isaretleri_temizle() -> void:
	for h in hedefler:
		h.durum = Hedef.Durum.BOS


func sayfaya_gec(no: int, sesli: bool = true) -> void:
	if _sayfalar.is_empty():
		return
	sayfa = clampi(no, 0, _sayfalar.size() - 1)
	for i in _sayfalar.size():
		_sayfalar[i].visible = i == sayfa
		if i < _sekmeler.size():
			_sekmeler[i].button_pressed = i == sayfa
	if sesli:
		sayfa_cevrildi.emit()


## Belirli bir kuralın yazılı olduğu sayfayı açar (ihtar sonrası göstermek için).
func kurali_goster(kural_id: String) -> void:
	for i in _sayfalar.size():
		for c in _sayfalar[i].get_children():
			if c is Hedef and str((c as Hedef).kural.get("id", "")) == kural_id:
				sayfaya_gec(i)
				return


# --- Kurulum ---

func _yeni_sayfa(baslik: String) -> Control:
	var s := Control.new()
	s.position = KAGIT_YERI.position
	s.size = KAGIT_YERI.size
	s.mouse_filter = MOUSE_FILTER_IGNORE
	s.draw.connect(_sayfa_ciz.bind(s))
	add_child(s)
	_sayfalar.append(s)
	_basliklar.append(baslik)
	return s


func _sayfa_ciz(s: Control) -> void:
	var r := Rect2(Vector2.ZERO, s.size)
	s.draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0, 0, 0, 0.28))
	s.draw_rect(r, Stil.KAGIT)
	s.draw_rect(r, Color(0.45, 0.40, 0.30, 0.8), false, 1.0)
	# delgeç delikleri ve raptiyeler
	for x: float in [18.0, r.size.x - 18.0]:
		s.draw_circle(Vector2(x, 12), 5.5, Color(0, 0, 0, 0.25))
		s.draw_circle(Vector2(x - 0.6, 10.6), 5.0, Stil.BORDO)
		s.draw_circle(Vector2(x - 1.8, 9.2), 1.6, Color(1, 1, 1, 0.45))


func _baslik_yaz(s: Control, baslik: String, alt: String) -> float:
	var b := Stil.etiket(baslik, BASLIK_PUNTO, Stil.MUREKKEP, Stil.daktilo_kalin())
	b.position = Vector2(KENAR + 22.0, 5.0)
	s.add_child(b)
	if alt != "":
		var a := Stil.etiket(alt, 10, Stil.MUREKKEP_SOLUK)
		a.position = Vector2(KENAR + 22.0, 22.0)
		s.add_child(a)
	var cizgi := ColorRect.new()
	cizgi.color = Color(Stil.MUREKKEP, 0.7)
	cizgi.position = Vector2(KENAR, 39.0)
	cizgi.size = Vector2(KAGIT_YERI.size.x - 2.0 * KENAR, 1.0)
	cizgi.mouse_filter = MOUSE_FILTER_IGNORE
	s.add_child(cizgi)
	return 48.0


func _satir_yaz(s: Control, yazi: String, y: float, genislik: float, yuk: float, kural: Dictionary,
		renk: Color = Stil.MUREKKEP, anahtar: String = "", girinti: float = 0.0) -> Hedef:
	var l := Stil.etiket(yazi, PUNTO, renk)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_constant_override("line_spacing", 0)
	l.position = Vector2(KENAR + girinti, y)
	l.size = Vector2(genislik - girinti, yuk)
	s.add_child(l)
	var h := Hedef.new()
	h.tip = "kural"
	h.anahtar = anahtar if anahtar != "" else str(kural.get("id", ""))
	h.kural = kural
	h.etiket = "Kural"
	h.position = Vector2(KENAR - 4.0 + girinti, y - 1.0)
	h.size = Vector2(genislik + 8.0 - girinti, yuk + 2.0)
	h.aktif = _inceleme
	h.tiklandi.connect(func(x: Hedef) -> void: hedef_tiklandi.emit(x))
	s.add_child(h)
	hedefler.append(h)
	return h


func _tablo_yaz(s: Control, k: Dictionary, y: float, genislik: float) -> float:
	var satir_yuk := 16.0
	match str(k.get("tur", "")):
		"harc_tutar":
			y = _ara_baslik(s, "HARÇ TARİFESİ", y)
			var tutarlar: Dictionary = k.get("tutarlar", {})
			for islem: String in tutarlar:
				var ad: String = Islemler.adi(islem)
				var tutar := Stil.tl(int(tutarlar[islem]))
				var nokta := maxi(2, 38 - ad.length() - tutar.length())
				_satir_yaz(s, ad + " " + ".".repeat(nokta) + " " + tutar, y, genislik, satir_yuk, k, Stil.MUREKKEP, islem)
				y += satir_yuk + 2.0
		"seri_aralik":
			y = _ara_baslik(s, "GEÇERLİ CÜZDAN SERİLERİ", y)
			for a: Dictionary in k.get("araliklar", []):
				var yazi := "%s-%06d  —  %s-%06d" % [str(a.onek), int(a.min), str(a.onek), int(a.max)]
				_satir_yaz(s, yazi, y, genislik, satir_yuk, k)
				y += satir_yuk + 2.0
		"mahalle_listesi":
			y = _ara_baslik(s, "İLÇEMİZE BAĞLI MAHALLELER", y)
			var liste: Array = k.get("mahalleler", [])
			var yazi := ", ".join(PackedStringArray(liste)) + "."
			var yuk := _yukseklik(yazi, genislik, Stil.daktilo(), PUNTO)
			_satir_yaz(s, yazi, y, genislik, yuk, k)
			y += yuk + 2.0
	return y


func _ara_baslik(s: Control, yazi: String, y: float) -> float:
	var l := Stil.etiket(yazi, 11, Stil.BORDO, Stil.daktilo_kalin())
	l.position = Vector2(KENAR, y)
	s.add_child(l)
	return y + 18.0


func _yukseklik(yazi: String, genislik: float, font: Font, punto: int) -> float:
	return font.get_multiline_string_size(yazi, HORIZONTAL_ALIGNMENT_LEFT, genislik, punto).y


func _sekmeleri_kur() -> void:
	if _sayfalar.size() < 2:
		return
	var x := KAGIT_YERI.position.x + 6.0
	for i in _sayfalar.size():
		var d := Button.new()
		d.text = _basliklar[i]
		d.toggle_mode = true
		d.focus_mode = FOCUS_NONE
		d.add_theme_font_size_override("font_size", 11)
		d.add_theme_stylebox_override("normal", Stil.bosluklu(Stil.kutu(Stil.KAGIT_ESKI, Color(0.4, 0.35, 0.28), 1, 3), 9, 3))
		d.add_theme_stylebox_override("hover", Stil.bosluklu(Stil.kutu(Stil.KAGIT, Stil.BORDO, 1, 3), 9, 3))
		d.add_theme_stylebox_override("pressed", Stil.bosluklu(Stil.kutu(Stil.KAGIT, Stil.MUREKKEP, 2, 3), 9, 3))
		d.position = Vector2(x, 2.0)
		d.pressed.connect(sayfaya_gec.bind(i))
		add_child(d)
		move_child(d, 0)
		_sekmeler.append(d)
		x += d.get_combined_minimum_size().x + 4.0
