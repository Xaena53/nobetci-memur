class_name Stil
extends RefCounted
## Ortak görsel dil: renk paleti, yazı tipleri, kutu stilleri ve metin yardımcıları.
## Sahneler arayüzü kodla kurar; hepsi rengini ve yazı tipini buradan alır.

# --- Palet (1984 devlet dairesi) ---
const DUVAR := Color("b9c9b0")          # soluk yeşil badana
const DUVAR_KOYU := Color("8fa78a")     # belden aşağı yağlı boya
const DUVAR_SERIT := Color("6e8a6b")
const MASA := Color("6b4a32")           # kahverengi masa
const MASA_ACIK := Color("7d5a3e")
const MASA_KOYU := Color("4a3222")
const SUMEN := Color("3f5345")          # masa üstü yeşil sümen
const KAGIT := Color("f1e7cc")          # krem kâğıt
const KAGIT_ESKI := Color("e6d7b0")
const KAGIT_BEYAZ := Color("f4efe0")
const KAGIT_PEMBE := Color("f0d6cf")    # karbon kopya makbuz
const MUREKKEP := Color("2a2622")       # daktilo şeridi siyahı
const MUREKKEP_SOLUK := Color("5c544b")
const BORDO := Color("7a1f2b")          # mühür
const KIRMIZI := Color("c0392b")        # uyuşmazlık çizgisi
const YESIL := Color("3d6b4a")
const MAVI_MUREKKEP := Color("2b3a7a")  # dolma kalem
const MOR_MUHUR := Color("5b3a82")      # muhtar mührü ıstampası
const GECE := Color("1f1b17")

const FONT_KLASORU := "res://assets/font/"

static var _fontlar := {}
static var _tema: Theme


static func _font(dosya: String) -> Font:
	if not _fontlar.has(dosya):
		var yol := FONT_KLASORU + dosya
		_fontlar[dosya] = load(yol) if ResourceLoader.exists(yol) else ThemeDB.fallback_font
	return _fontlar[dosya]


static func daktilo() -> Font:
	return _font("CourierPrime-Regular.ttf")


static func daktilo_kalin() -> Font:
	return _font("CourierPrime-Bold.ttf")


static func daktilo_italik() -> Font:
	return _font("CourierPrime-Italic.ttf")


static func serif() -> Font:
	return _font("OldStandard-Regular.ttf")


static func serif_kalin() -> Font:
	return _font("OldStandard-Bold.ttf")


static func serif_italik() -> Font:
	return _font("OldStandard-Italic.ttf")


static func el_yazisi() -> Font:
	return _font("Caveat.ttf")


## Kenarlıklı, gölgeli düz kutu (kâğıt, etiket, düğme) üretir.
static func kutu(zemin: Color, kenar: Color = Color(0, 0, 0, 0), kenar_kalinlik: int = 0,
		kose: int = 2, golge: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = zemin
	s.border_color = kenar
	s.set_border_width_all(kenar_kalinlik)
	s.set_corner_radius_all(kose)
	s.anti_aliasing = true
	if golge > 0:
		s.shadow_color = Color(0, 0, 0, 0.35)
		s.shadow_size = golge
		s.shadow_offset = Vector2(2, 3)
	return s


static func bosluklu(s: StyleBoxFlat, yatay: float, dikey: float) -> StyleBoxFlat:
	s.content_margin_left = yatay
	s.content_margin_right = yatay
	s.content_margin_top = dikey
	s.content_margin_bottom = dikey
	return s


## Bütün sahnelerin paylaştığı tema: daktilo yazısı, kâğıt düğmeler.
static func tema() -> Theme:
	if _tema != null:
		return _tema
	var t := Theme.new()
	t.default_font = daktilo()
	t.default_font_size = 16

	t.set_color("font_color", "Label", MUREKKEP)

	t.set_font("font", "Button", daktilo_kalin())
	t.set_font_size("font_size", "Button", 18)
	t.set_color("font_color", "Button", MUREKKEP)
	t.set_color("font_hover_color", "Button", BORDO)
	t.set_color("font_pressed_color", "Button", BORDO)
	t.set_color("font_focus_color", "Button", MUREKKEP)
	t.set_color("font_disabled_color", "Button", Color(MUREKKEP, 0.35))
	t.set_stylebox("normal", "Button", bosluklu(kutu(KAGIT, MUREKKEP, 2, 2, 3), 18, 8))
	t.set_stylebox("hover", "Button", bosluklu(kutu(KAGIT_BEYAZ, BORDO, 2, 2, 4), 18, 8))
	t.set_stylebox("pressed", "Button", bosluklu(kutu(KAGIT_ESKI, BORDO, 2, 2, 1), 18, 8))
	t.set_stylebox("disabled", "Button", bosluklu(kutu(Color(KAGIT_ESKI, 0.55), Color(MUREKKEP, 0.3), 2, 2, 0), 18, 8))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())

	t.set_color("default_color", "RichTextLabel", MUREKKEP)
	t.set_font("normal_font", "RichTextLabel", daktilo())
	t.set_font("bold_font", "RichTextLabel", daktilo_kalin())
	t.set_font("italics_font", "RichTextLabel", daktilo_italik())
	_tema = t
	return t


## Türkçe kurallarıyla büyük harf ("i" → "İ", "ı" → "I").
static func buyuk(metin: String) -> String:
	return metin.replace("i", "İ").replace("ı", "I").to_upper()


## Türkçe kurallarıyla küçük harf ("I" → "ı", "İ" → "i").
static func kucuk(metin: String) -> String:
	return metin.replace("I", "ı").replace("İ", "i").to_lower()


## 1250 → "1.250 TL"
static func tl(tutar: int) -> String:
	return binlik(tutar) + " TL"


static func binlik(sayi: int) -> String:
	var eksi := sayi < 0
	var ham := str(absi(sayi))
	var sonuc := ""
	while ham.length() > 3:
		sonuc = "." + ham.substr(ham.length() - 3) + sonuc
		ham = ham.substr(0, ham.length() - 3)
	sonuc = ham + sonuc
	return ("-" if eksi else "") + sonuc


## Etiket üretmek için kısa yol.
static func etiket(metin: String, boyut: int = 16, renk: Color = MUREKKEP, font: Font = null) -> Label:
	var l := Label.new()
	l.text = metin
	l.add_theme_font_size_override("font_size", boyut)
	l.add_theme_color_override("font_color", renk)
	if font != null:
		l.add_theme_font_override("font", font)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
