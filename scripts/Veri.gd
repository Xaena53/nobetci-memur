class_name Veri
extends RefCounted
## data/ altındaki JSON dosyalarını okur ve önbellekte tutar.
## Not: JSON'dan gelen bütün sayılar float'tır; kullanırken int() ile çevrilir.

const GUN_YOLU := "res://data/gunler/gun%d.json"
const ADLAR_YOLU := "res://data/adlar.json"
const VATANDAS_YOLU := "res://data/vatandaslar.json"

static var _onbellek: Dictionary = {}


static func oku(yol: String) -> Variant:
	if _onbellek.has(yol):
		return _onbellek[yol]
	if not FileAccess.file_exists(yol):
		push_warning("Veri dosyası yok: " + yol)
		return null
	var json := JSON.new()
	var hata := json.parse(FileAccess.get_file_as_string(yol))
	if hata != OK:
		push_error("%s okunamadı (satır %d): %s" % [yol, json.get_error_line(), json.get_error_message()])
		return null
	_onbellek[yol] = json.data
	return json.data


static func gun_var_mi(no: int) -> bool:
	return FileAccess.file_exists(GUN_YOLU % no)


## O günün genelgesi, kuralları ve ayarları. Bulunamazsa boş sözlük.
static func gun(no: int) -> Dictionary:
	var v: Variant = oku(GUN_YOLU % no)
	return v if typeof(v) == TYPE_DICTIONARY else {}


static func adlar() -> Dictionary:
	var v: Variant = oku(ADLAR_YOLU)
	return v if typeof(v) == TYPE_DICTIONARY else {}


## Havuzdaki bir yüzün kalıcı kimliği: {ad, soyad, baba_adi, ana_adi, dogum_yeri, dogum_tarihi, imza}.
## Aynı yüz her gelişinde aynı kişidir. Kimliği olmayan yüz için boş sözlük.
static func vatandas(portre: String) -> Dictionary:
	var v: Variant = oku(VATANDAS_YOLU)
	if typeof(v) != TYPE_DICTIONARY:
		return {}
	return ((v as Dictionary).get("kisiler", {}) as Dictionary).get(portre, {})


## Gündeki belirli türden ilk kural (yoksa boş sözlük).
static func kural(gun_verisi: Dictionary, tur: String, belge: String = "") -> Dictionary:
	for k: Dictionary in gun_verisi.get("kurallar", []):
		if str(k.get("tur", "")) == tur and (belge == "" or str(k.get("belge", "")) == belge):
			return k
	return {}


static func onbellegi_bosalt() -> void:
	_onbellek.clear()
