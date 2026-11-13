class_name Dil
extends RefCounted
## Oyunun dili: Türkçe (kaynak), İngilizce, Rusça.
##
## Oyunun bütün metinleri kaynakta Türkçedir ve mantık (kurallar, karşılaştırmalar, kayıt) Türkçe
## değerlerle çalışır. Çeviri yalnızca ekrana çıkarken yapılır:
##   - Label ve Button metinleri, çeviri sözlüğünde birebir karşılığı varsa motor tarafından kendiliğinden
##     çevrilir (kaynak Türkçe metin anahtardır);
##   - biçimli (%s, %d) ve elle çizilen metinler `Dil.c()` ile çevrilir: `Dil.c("%d. GÜN") % gun`.
## Sözlükler `data/dil/<kod>.json` dosyalarıdır: {"Türkçe metin": "çevirisi"} (tools/dil/derle.py üretir).
## Görsellerin dile özgü hâli varsa (`.../<kod>/<dosya>`) `Dil.yol()` onu döndürür.

const DILLER := ["tr", "en", "ru"]
const ADLAR := {"tr": "Türkçe", "en": "English", "ru": "Русский"}
const SOZLUK := "res://data/dil/%s.json"

static var kod := "tr"
static var _yuklu := false


## Sözlükleri motora tanıtır (bir kez).
static func _yukle() -> void:
	if _yuklu:
		return
	_yuklu = true
	for d: String in DILLER:
		if d == "tr":
			continue
		var veri: Variant = Veri.oku(SOZLUK % d)
		if typeof(veri) != TYPE_DICTIONARY:
			continue
		var ceviri := Translation.new()
		ceviri.locale = d
		for kaynak: String in veri:
			var hedef := str(veri[kaynak])
			if hedef != "":
				ceviri.add_message(kaynak, hedef)
		TranslationServer.add_translation(ceviri)


## Dili seçer. Boş ya da tanınmayan kod verilirse işletim sisteminin diline bakılır
## (Türkçe ve Rusça dışındaki her dil için İngilizce).
static func sec(yeni: String) -> void:
	_yukle()
	if yeni not in DILLER:
		yeni = sistem_dili()
	kod = yeni
	TranslationServer.set_locale(yeni)


static func sistem_dili() -> String:
	var d := OS.get_locale_language()
	return d if d in ["tr", "ru"] else "en"


## Türkçe kaynak metnin seçili dildeki karşılığı (yoksa kendisi).
static func c(metin: String) -> String:
	if kod == "tr" or metin == "":
		return metin
	return str(TranslationServer.translate(metin))


## Büyük harf: Türkçede "i" → "İ", "ı" → "I"; öbür dillerde olağan dönüşüm. Metin önce çevrilir.
static func buyuk(metin: String) -> String:
	if kod == "tr":
		return metin.replace("i", "İ").replace("ı", "I").to_upper()
	return c(metin).to_upper()


## Küçük harf: Türkçede "I" → "ı", "İ" → "i". Metin önce çevrilir.
static func kucuk(metin: String) -> String:
	if kod == "tr":
		return metin.replace("I", "ı").replace("İ", "i").to_lower()
	return c(metin).to_lower()


## Bir görselin dile özgü hâli varsa onun yolu, yoksa kendisi.
## "res://assets/img/nesne/etiket_alarm.webp" → "res://assets/img/nesne/en/etiket_alarm.webp"
static func yol(asil: String) -> String:
	if kod == "tr":
		return asil
	var yerel := asil.get_base_dir().path_join(kod).path_join(asil.get_file())
	return yerel if ResourceLoader.exists(yerel) else asil
