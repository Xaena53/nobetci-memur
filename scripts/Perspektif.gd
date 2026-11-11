class_name Perspektif
extends RefCounted
## Masa düzleminin perspektifi (2,5B görünüm).
##
## Masadaki her şeyin yeri düz "masa koordinatları"yla (u: soldan sağa, v: duvardan oyuncuya)
## tutulur; bu, masanın kuş bakışı planıdır. Ekrana bir homografi ile taşınır: plan dikdörtgeni,
## duvara doğru daralan bir yamuğa dönüşür. Dört köşe eşlemesi Yerlesim.MASA_DUZ / MASA_EKRAN'dadır.

static var _h := PackedFloat64Array()    ## 3x3, satır satır: masa → ekran
static var _t := PackedFloat64Array()    ## tersi: ekran → masa


static func _hazirla() -> void:
	if _h.is_empty():
		kur(Yerlesim.MASA_DUZ, Yerlesim.MASA_EKRAN)


## Dört nokta eşlemesinden homografiyi çözer (8 bilinmeyenli doğrusal sistem).
static func kur(duz: Array, ekran: Array) -> void:
	var a: Array = []
	for i in 4:
		var p: Vector2 = duz[i]
		var q: Vector2 = ekran[i]
		a.append([p.x, p.y, 1.0, 0.0, 0.0, 0.0, -p.x * q.x, -p.y * q.x, q.x])
		a.append([0.0, 0.0, 0.0, p.x, p.y, 1.0, -p.x * q.y, -p.y * q.y, q.y])
	# Gauss eleme (kısmi pivotlu)
	for s in 8:
		var pivot := s
		for r in range(s + 1, 8):
			if absf(a[r][s]) > absf(a[pivot][s]):
				pivot = r
		var gecici: Array = a[s]
		a[s] = a[pivot]
		a[pivot] = gecici
		var bolen: float = a[s][s]
		if is_zero_approx(bolen):
			push_error("Perspektif: köşe noktaları homografi tanımlamıyor.")
			return
		for c in range(s, 9):
			a[s][c] /= bolen
		for r in 8:
			if r != s:
				var kat: float = a[r][s]
				if kat != 0.0:
					for c in range(s, 9):
						a[r][c] -= kat * a[s][c]
	_h = PackedFloat64Array([a[0][8], a[1][8], a[2][8], a[3][8], a[4][8], a[5][8], a[6][8], a[7][8], 1.0])
	_t = _ters(_h)


## Masa koordinatı → ekran.
static func ekrana(p: Vector2) -> Vector2:
	_hazirla()
	return _uygula(_h, p)


## Ekran → masa koordinatı.
static func masaya(p: Vector2) -> Vector2:
	_hazirla()
	return _uygula(_t, p)


## Masadaki p noktasında perspektifin yerel doğrusal karşılığı: bu dönüşümü taşıyan bir düğümün
## içine konan düz nesne, masanın o noktasında yatıyormuş gibi görünür (ölçek, basıklık, eğim).
static func yerel(p: Vector2) -> Transform2D:
	_hazirla()
	var w := _h[6] * p.x + _h[7] * p.y + _h[8]
	var x := (_h[0] * p.x + _h[1] * p.y + _h[2]) / w
	var y := (_h[3] * p.x + _h[4] * p.y + _h[5]) / w
	return Transform2D(
		Vector2((_h[0] - x * _h[6]) / w, (_h[3] - y * _h[6]) / w),
		Vector2((_h[1] - x * _h[7]) / w, (_h[4] - y * _h[7]) / w),
		Vector2(x, y))


## p noktasındaki yatay ölçek (uzaktaki nesne ne kadar küçülüyor).
static func olcek(p: Vector2) -> float:
	return yerel(p).x.length()


static func _uygula(m: PackedFloat64Array, p: Vector2) -> Vector2:
	var w := m[6] * p.x + m[7] * p.y + m[8]
	return Vector2((m[0] * p.x + m[1] * p.y + m[2]) / w, (m[3] * p.x + m[4] * p.y + m[5]) / w)


static func _ters(m: PackedFloat64Array) -> PackedFloat64Array:
	var d := m[0] * (m[4] * m[8] - m[5] * m[7]) - m[1] * (m[3] * m[8] - m[5] * m[6]) + m[2] * (m[3] * m[7] - m[4] * m[6])
	return PackedFloat64Array([
		(m[4] * m[8] - m[5] * m[7]) / d, (m[2] * m[7] - m[1] * m[8]) / d, (m[1] * m[5] - m[2] * m[4]) / d,
		(m[5] * m[6] - m[3] * m[8]) / d, (m[0] * m[8] - m[2] * m[6]) / d, (m[2] * m[3] - m[0] * m[5]) / d,
		(m[3] * m[7] - m[4] * m[6]) / d, (m[1] * m[6] - m[0] * m[7]) / d, (m[0] * m[4] - m[1] * m[3]) / d,
	])
