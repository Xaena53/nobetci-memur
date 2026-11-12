class_name Portreler
extends RefCounted
## Vatandaş ve hikâye karakteri portreleri. Görseller assets/img/portre/<kimlik>.webp,
## künyeleri (cinsiyet, yaş) data/portreler.json içindedir.
##
## Her kişinin üç ayrı görünüşü olabilir:
##  - büst (portre/<kimlik>.webp): gişeye bugün geldiği hâli; canlandırılır.
##  - vesikalık (portre/vesika/<kimlik>.webp): nüfus cüzdanındaki yıllar önce çekilmiş fotoğrafı;
##    kıyafeti, saçı, bıyığı başkadır. Yüzü aynıdır: kimlik, yüz hatlarından doğrulanır.
##  - aranan resmi (portre/aranan/<kimlik>.webp): emniyetin dosyasındaki eski resim.
## Künyedeki "benzer" listesi, o kişiye en çok benzeyen başka kişileri verir (tools/sanat/vesikalik.py).

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
				_kunye = Veri.dondur(veri)
	return _kunye


## Yüklenmiş portre görsellerini bırakır (künye kalır). Gün başında çağrılır: önceki günün yüzleri
## bellekte birikmez; doku belleği bir günün kuyruğuyla sınırlı kalır.
static func bosalt() -> void:
	_onbellek.clear()


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


## Nüfus cüzdanındaki vesikalık fotoğraf; ayrı bir vesikalığı yoksa büstün kendisi.
static func vesikalik(kimlik: String) -> Texture2D:
	return _ek_doku("vesika/", kimlik)


## Arananlar listesindeki eski dosya resmi; yoksa vesikalığı.
static func aranan_resmi(kimlik: String) -> Texture2D:
	if ResourceLoader.exists(KLASOR + "aranan/" + kimlik + ".webp"):
		return _ek_doku("aranan/", kimlik)
	return vesikalik(kimlik)


static func _ek_doku(alt_klasor: String, kimlik: String) -> Texture2D:
	if kimlik == "":
		return _yedek_doku()
	var anahtar := alt_klasor + kimlik
	if not _onbellek.has(anahtar):
		var yol := KLASOR + alt_klasor + kimlik + ".webp"
		_onbellek[anahtar] = load(yol) if ResourceLoader.exists(yol) else doku(kimlik)
	return _onbellek[anahtar]


## Bu kişiye en çok benzeyen başka kişiler (en benzeri başta). `alan`: "benzer" ya da "aranan_benzer".
static func benzerler(kimlik: String, alan: String = "benzer") -> Array[String]:
	var sonuc: Array[String] = []
	for b: Variant in bilgi(kimlik).get(alan, []):
		sonuc.append(str(b))
	return sonuc


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
