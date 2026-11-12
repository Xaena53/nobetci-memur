class_name Damga
extends Control
## Istampa izi: muhtarlık mührü, vezne kaşesi, konsolosluk vize kaşesi ve dairenin kendi damgaları.
## Her damga boyanmış bir görseldir (assets/img/damga/<çeşit>_<tür>.webp; beyaz üstüne saydamlık maskesi);
## mürekkebin rengi çizerken verilir. Sahte damga, gerçeğinin tek bir ayrıntısı bozulmuş hâlidir
## (bkz. SAHTELER); "renk" sahteciliğinde gerçek damga başka mürekkeple basılmıştır.
##
## Aynı çizici belgelerde, bilgi defterindeki örneklerde, karar mühründe ve ana menüde kullanılır.

const KLASOR := "res://assets/img/damga/"
const RENKLER := {"mor": Color("5b3a82"), "kirmizi": Color("a3262c"), "mavi": Color("2b4a8f"), "bordo": Color("7a1f2b")}
## Gerçek damganın mürekkebi ve belgedeki taban boyutu.
const MUREKKEP := {"muhtar": "mor", "vezne": "mor", "vize": "kirmizi", "daire": "mor", "onay": "bordo", "gorulmustur": "bordo"}
const TABAN := {"muhtar": Vector2(84, 84), "vize": Vector2(84, 84), "vezne": Vector2(108, 47), "daire": Vector2(84, 70),
	"onay": Vector2(150, 87), "gorulmustur": Vector2(140, 75)}

## Sahtecilik türleri: [kod, bilgi defterindeki açıklaması]. Baştakiler göze batar, sondakiler incedir.
const SAHTELER := {
	"muhtar": [["renk", "Mürekkep mavi"], ["oval", "Oval basılmış"], ["tek_halka", "Dış halka tek"],
		["yildizsiz", "Yıldız yok"], ["ic_halkasiz", "İç halka yok"], ["yazim", "Yazım hatası"],
		["baska_mahalle", "Başka ilçenin mührü"]],
	"vezne": [["renk", "Mürekkep mavi"], ["cift_cerceve", "Çerçeve çift"], ["alt_satirsiz", "Alt satır yok"],
		["yazim", "Yazım hatası"]],
	"vize": [["renk", "Mürekkep mor"], ["oval", "Oval basılmış"], ["tek_halka", "Dış halka tek"],
		["ortasiz", "Ortası boş"], ["ic_halkasiz", "İç halka yok"], ["yazim", "Yazım hatası"]],
}

static var _dokular: Dictionary = {}

var cesit := "muhtar"
var sahte := ""             ## "" gerçek; doluysa sahtecilik türü
var egik := true            ## elle basılmış gibi hafif yamuk dursun (defterdeki örnekler düz durur)
var tohum := 0:
	set(t):
		tohum = t
		queue_redraw()


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


## Bir damga düğümü kurar. `damga_cesidi`: "muhtar" | "vezne" | "vize" | "daire" | "onay" | "gorulmustur";
## `sahtelik`: "" (gerçek) ya da SAHTELER'deki bir kod.
static func olustur(damga_cesidi: String, sahtelik: String = "", damga_tohumu: int = 0) -> Damga:
	var d := Damga.new()
	d.cesit = damga_cesidi
	d.sahte = sahtelik
	d.tohum = damga_tohumu
	d.size = TABAN.get(damga_cesidi, Vector2(84, 84))
	return d


## Damganın görseli: "renk" sahteciliği gerçek damganın görselini kullanır.
static func doku_adi(damga_cesidi: String, sahtelik: String = "") -> String:
	if not SAHTELER.has(damga_cesidi):
		return damga_cesidi
	return damga_cesidi + "_" + ("gercek" if sahtelik == "" or sahtelik == "renk" else sahtelik)


## Damganın mürekkep rengi ("renk" sahteciliğinde yanlış renk).
static func renk_adi(damga_cesidi: String, sahtelik: String = "") -> String:
	var gercek := str(MUREKKEP.get(damga_cesidi, "mor"))
	if sahtelik == "renk":
		return "mor" if gercek == "kirmizi" else "mavi"
	return gercek


static func doku(ad: String) -> Texture2D:
	if not _dokular.has(ad):
		var yol := KLASOR + ad + ".webp"
		_dokular[ad] = load(yol) if ResourceLoader.exists(yol) else null
	return _dokular[ad]


## Sahteliğin okunur açıklaması (ihtar ve ipucu metinleri için).
static func sahte_aciklamasi(damga_cesidi: String, sahtelik: String) -> String:
	for s: Array in SAHTELER.get(damga_cesidi, []):
		if str(s[0]) == sahtelik:
			return str(s[1])
	return "Örneğe uymuyor"


## Zorluğa göre bir sahtecilik türü seçer: kolay günlerde göze batanlardan, zor günlerde ince olanlardan.
static func sahte_sec(damga_cesidi: String, zorluk: int, rng: RandomNumberGenerator) -> String:
	var liste: Array = SAHTELER.get(damga_cesidi, [])
	if liste.is_empty():
		return ""
	@warning_ignore("integer_division")
	var yari := maxi(1, liste.size() / 2)
	var bas := 0
	var son := liste.size() - 1
	if zorluk <= 1:
		son = yari - 1
	elif zorluk >= 3:
		bas = yari
	return str(liste[rng.randi_range(bas, son)][0])


## Damgayı herhangi bir tuvale çizer: `alan`ın içine, oranını bozmadan, ortalayarak.
static func ciz(tuval: CanvasItem, alan: Rect2, damga_cesidi: String, sahtelik: String = "", aci: float = 0.0,
		saydamlik: float = 0.9) -> void:
	var d := doku(doku_adi(damga_cesidi, sahtelik))
	if d == null:
		return
	var b := d.get_size()
	var olcek := minf(alan.size.x / b.x, alan.size.y / b.y)
	var boyut := b * olcek
	var renk := Color(RENKLER.get(renk_adi(damga_cesidi, sahtelik), RENKLER.mor), saydamlik)
	tuval.draw_set_transform(alan.get_center(), aci, Vector2.ONE)
	tuval.draw_texture_rect(d, Rect2(-boyut / 2.0, boyut), false, renk)
	tuval.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = tohum
	var saydamlik := rng.randf_range(0.80, 0.94)
	var aci := deg_to_rad(rng.randf_range(-9.0, 9.0)) if egik else 0.0
	if cesit == "vezne":
		aci *= 0.45
	Damga.ciz(self, Rect2(Vector2.ZERO, size), cesit, sahte, aci, saydamlik)
