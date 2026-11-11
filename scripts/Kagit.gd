class_name Kagit
extends RefCounted
## Boyama kâğıt dokuları (assets/img/kagit/*.webp) ve onlarla kâğıt çizme yardımcıları.
## Belgeler, fişler ve genelge sayfası düz renk yerine bu dokuların üstüne yazılır.

const KLASOR := "res://assets/img/kagit/"

static var _dokular: Dictionary = {}


## "sayfa" | "makbuz" | "cuzdan_mavi" | "cuzdan_pembe" | "teleks" | "daktilo_sayfa"
static func doku(ad: String) -> Texture2D:
	if not _dokular.has(ad):
		var yol := KLASOR + ad + ".webp"
		_dokular[ad] = load(yol) if ResourceLoader.exists(yol) else null
	return _dokular[ad]


## Kâğıdı gölgesiyle çizer. Doku yoksa `yedek` renkte düz kâğıt çizer.
## `tasma`: dokunun yıpranmış kenarı için dikdörtgenin dışına taşma payı.
static func ciz(tuval: CanvasItem, alan: Rect2, ad: String, yedek: Color, golge: float = 4.0,
		tasma: float = 2.0, ton: Color = Color.WHITE) -> void:
	var g := StyleBoxFlat.new()
	g.bg_color = Color(0, 0, 0, 0)
	g.draw_center = false
	g.shadow_color = Color(0, 0, 0, 0.36)
	g.shadow_size = roundi(golge)
	g.shadow_offset = Vector2(golge * 0.7, golge * 1.1)
	tuval.draw_style_box(g, alan.grow(-2.0))
	var d := doku(ad)
	if d != null:
		tuval.draw_texture_rect(d, alan.grow(tasma), false, ton)
	else:
		tuval.draw_rect(alan, yedek * ton)


## Dokunun ortasından alınmış bir parçayla küçük bir kâğıt (fiş, etiket) çizer.
static func parca_ciz(tuval: CanvasItem, alan: Rect2, ad: String, yedek: Color, ton: Color = Color.WHITE) -> void:
	var d := doku(ad)
	if d == null:
		tuval.draw_rect(alan, yedek * ton)
		return
	var b := d.get_size()
	var oran := alan.size.x / maxf(1.0, alan.size.y)
	var kaynak_g := b.x * 0.8
	var kaynak_y := minf(b.y * 0.8, kaynak_g / oran)
	var kaynak := Rect2((b - Vector2(kaynak_g, kaynak_y)) / 2.0, Vector2(kaynak_g, kaynak_y))
	tuval.draw_texture_rect_region(d, alan, kaynak, ton)
