class_name Portreler
extends RefCounted
## Vatandaş ve hikâye karakteri portreleri. Görseller assets/img/portre/<kimlik>.webp,
## künyeleri (cinsiyet, yaş) data/portreler.json içindedir.

const KLASOR := "res://assets/img/portre/"
const KUNYE_YOLU := "res://data/portreler.json"

static var _kunye: Dictionary = {}
static var _yuklendi := false
static var _onbellek: Dictionary = {}
static var _yedek: Texture2D


static func kunye() -> Dictionary:
	if not _yuklendi:
		_yuklendi = true
		if FileAccess.file_exists(KUNYE_YOLU):
			var veri: Variant = JSON.parse_string(FileAccess.get_file_as_string(KUNYE_YOLU))
			if typeof(veri) == TYPE_DICTIONARY:
				_kunye = veri
	return _kunye


static func bilgi(kimlik: String) -> Dictionary:
	return kunye().get(kimlik, {})


## Rastgele vatandaşlara dağıtılabilen portreler (hikâye karakterleri hariç).
static func havuz(cinsiyet: String = "") -> Array[String]:
	var sonuc: Array[String] = []
	var k := kunye()
	for kimlik: String in k:
		var b: Dictionary = k[kimlik]
		if bool(b.get("ozel", false)):
			continue
		if cinsiyet == "" or str(b.get("cinsiyet", "")) == cinsiyet:
			sonuc.append(kimlik)
	sonuc.sort()
	return sonuc


static func doku(kimlik: String) -> Texture2D:
	if kimlik == "":
		return _yedek_doku()
	if not _onbellek.has(kimlik):
		var yol := KLASOR + kimlik + ".webp"
		_onbellek[kimlik] = load(yol) if ResourceLoader.exists(yol) else _yedek_doku()
	return _onbellek[kimlik]


## Konuşma kareleri (hafif açık / açık ağız, yan yana); yoksa null.
static func agiz_dokusu(kimlik: String) -> Texture2D:
	var anahtar := "agiz/" + kimlik
	if not _onbellek.has(anahtar):
		var yol := KLASOR + "agiz/" + kimlik + ".webp"
		_onbellek[anahtar] = load(yol) if ResourceLoader.exists(yol) else null
	return _onbellek[anahtar]


## Görseli bulunmayan kimlikler için düz bir siluet.
static func _yedek_doku() -> Texture2D:
	if _yedek == null:
		var svg := """<svg xmlns="http://www.w3.org/2000/svg" width="240" height="260" viewBox="0 0 240 260">
<ellipse cx="120" cy="92" rx="52" ry="62" fill="#5c6a62"/>
<path d="M18 260 C18 190 70 164 120 164 C170 164 222 190 222 260 Z" fill="#4a564f"/></svg>"""
		var goruntu := Image.new()
		goruntu.load_svg_from_string(svg, 1.0)
		_yedek = ImageTexture.create_from_image(goruntu)
	return _yedek
