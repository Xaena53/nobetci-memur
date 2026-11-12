class_name Kar
extends Control
## Kar yağışı: üç derinlik katmanı. Uzaktaki taneler küçük, soluk ve ağırdır; yakındakiler iri, bulanık
## ve hızlıdır. Bütün taneler aynı rüzgârla savrulur (rüzgâr ağır ağır kabarıp diner), her biri ayrıca
## kendi salınımıyla süzülür. `isik` verilirse o noktanın çevresinden geçen taneler ışıkta parlar.

## Katmanlar: [tane sayısı, en küçük çap, en büyük çap, en düşük hız, en yüksek hız, saydamlık, rüzgâr payı]
const KATMANLAR := [
	[260, 1.8, 3.0, 26.0, 44.0, 0.62, 0.55],
	[170, 2.8, 4.8, 46.0, 74.0, 0.88, 1.0],
	[44, 6.5, 12.0, 96.0, 142.0, 0.46, 1.7],
]
const KENAR := 40.0

var isik := Vector2(-1000, -1000)     ## ışık kaynağının yeri (sokak lambası)
var isik_gucu := 0.0                  ## 0 sönük .. 1 yanıyor
var isik_yaricapi := 150.0
var ruzgar := 0.0                     ## o anki yatay rüzgâr (px/sn); duman da bunu kullanır

var _taneler: Array[PackedFloat32Array] = []    ## katman başına: [x, y, çap, hız, evre, salınım] ...
var _doku: Texture2D
var _bulanik: Texture2D
var _zaman := 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_doku = _nokta(16, 1.6)
	_bulanik = _nokta(32, 0.9)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1984
	var alan := Yerlesim.EKRAN.size
	for k: Array in KATMANLAR:
		var t := PackedFloat32Array()
		for i in int(k[0]):
			t.append(rng.randf_range(-KENAR, alan.x + KENAR))
			t.append(rng.randf_range(-KENAR, alan.y + KENAR))
			t.append(rng.randf_range(float(k[1]), float(k[2])))
			t.append(rng.randf_range(float(k[3]), float(k[4])))
			t.append(rng.randf_range(0.0, TAU))
			t.append(rng.randf_range(0.5, 1.5))
		_taneler.append(t)


func _process(delta: float) -> void:
	_zaman += delta
	# rüzgâr: iki ağır dalganın toplamı; arada bir sert eser
	ruzgar = 16.0 + 13.0 * sin(_zaman * 0.23) + 8.0 * sin(_zaman * 0.61 + 1.3) + 5.0 * sin(_zaman * 1.37 + 0.4)
	var alan := Yerlesim.EKRAN.size
	for ki in _taneler.size():
		var t := _taneler[ki]
		var pay := float(KATMANLAR[ki][6])
		var i := 0
		while i < t.size():
			var salinim := sin(_zaman * (0.7 + t[i + 5] * 0.6) + t[i + 4]) * 9.0 * t[i + 5]
			t[i] += (ruzgar * pay + salinim) * delta
			t[i + 1] += t[i + 3] * delta
			if t[i + 1] > alan.y + KENAR:
				t[i + 1] = -KENAR
				t[i] = randf_range(-KENAR, alan.x + KENAR)
			if t[i] > alan.x + KENAR:
				t[i] -= alan.x + 2.0 * KENAR
			elif t[i] < -KENAR:
				t[i] += alan.x + 2.0 * KENAR
			i += 6
	queue_redraw()


func _draw() -> void:
	for ki in _taneler.size():
		var t := _taneler[ki]
		var saydamlik := float(KATMANLAR[ki][5])
		var doku := _bulanik if ki == 2 else _doku
		var i := 0
		while i < t.size():
			var yer := Vector2(t[i], t[i + 1])
			var cap := t[i + 2]
			var renk := Color(1, 1, 1, saydamlik)
			# lambanın ışığından geçen tane sarımsı parlar
			if isik_gucu > 0.01:
				var uzaklik := yer.distance_to(isik + Vector2(0, 46))
				if uzaklik < isik_yaricapi:
					var g := (1.0 - uzaklik / isik_yaricapi) * isik_gucu
					renk = Color(1.0, 0.93 - 0.05 * g, 0.80 - 0.22 * g, minf(1.0, saydamlik + 0.55 * g))
					cap *= 1.0 + 0.35 * g
			draw_texture_rect(doku, Rect2(yer - Vector2(cap, cap) * 0.5, Vector2(cap, cap)), false, renk)
			i += 6


## Yumuşak kenarlı beyaz nokta.
static func _nokta(boyut: int, keskinlik: float) -> Texture2D:
	var g := Image.create(boyut, boyut, false, Image.FORMAT_RGBA8)
	var orta := (boyut - 1) / 2.0
	for y in boyut:
		for x in boyut:
			var u := Vector2(x - orta, y - orta).length() / (boyut / 2.0)
			g.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - u, 0.0, 1.0) ** keskinlik))
	return ImageTexture.create_from_image(g)
