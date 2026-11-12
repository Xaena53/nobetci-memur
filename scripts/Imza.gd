class_name Imza
extends RefCounted
## Kişiye özel imzalar. Müdürün, her mahalle muhtarının ve veznedarın dolma kalemle atılmış kendi
## imzası vardır (assets/img/imza/<kod>.webp). Görseller beyaz üstüne saydamlık maskesidir: mürekkebin
## rengi çizerken verilir, kalemin bastırdığı yerler daha koyu çıkar.
##
## `kisi`: "mudur", "veznedar" ya da kişinin adı ("Sabri Güneş"); addan dosya kodu türetilir.

const KLASOR := "res://assets/img/imza/"
const HARFLER := {"ı": "i", "İ": "i", "ş": "s", "Ş": "s", "ğ": "g", "Ğ": "g", "ü": "u", "Ü": "u",
	"ö": "o", "Ö": "o", "ç": "c", "Ç": "c", "â": "a", "Â": "a", "î": "i", "û": "u"}

static var _dokular: Dictionary = {}


## "Kâzım Türkmen" → "kazim_turkmen"
static func kod(kisi: String) -> String:
	var s := ""
	for h in kisi.strip_edges():
		if HARFLER.has(h):
			s += str(HARFLER[h])
		elif h == " " or h == "." or h == "-":
			s += "_"
		else:
			s += h.to_lower()
	while s.contains("__"):
		s = s.replace("__", "_")
	return s.trim_suffix("_")


static func doku(kisi: String) -> Texture2D:
	var k := kod(kisi)
	if not _dokular.has(k):
		var yol := KLASOR + k + ".webp"
		_dokular[k] = load(yol) if ResourceLoader.exists(yol) else null
	return _dokular[k]


## İmzayı `alan`ın içine, oranını bozmadan ve ortalayarak çizer. İmzası olmayan kişi için false döner.
static func ciz(tuval: CanvasItem, alan: Rect2, kisi: String, renk: Color) -> bool:
	var d := doku(kisi)
	if d == null:
		return false
	var b := d.get_size()
	var olcek := minf(alan.size.x / b.x, alan.size.y / b.y)
	var boyut := b * olcek
	tuval.draw_texture_rect(d, Rect2(alan.position + (alan.size - boyut) / 2.0, boyut), false, renk)
	return true
