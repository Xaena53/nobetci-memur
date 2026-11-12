class_name MasaNesnesi
extends Node2D
## Masanın üstünde duran bir nesnenin (belge, fiş, mühür) taşıyıcısı.
##
## Nesnenin masadaki yeri düz masa koordinatlarıyla tutulur; ekrandaki yeri, basıklığı ve eğimi
## perspektiften hesaplanır. `kalkis` 0 iken nesne masada yatar; 1 iken oyuncuya dönük ve dümdüzdür
## (elde tutuluyor). Aradaki değerler iki duruş arasında yumuşak geçiş sağlar.
## İçerik (bir Control) taşıyıcının ortasına hizalanır.

var masa_konumu := Vector2.ZERO:      ## nesnenin ortası, masa koordinatında
	set(k):
		masa_konumu = k
		_guncelle()

var ekran_konumu := Vector2.ZERO:     ## kalkmışken ortasının ekrandaki yeri
	set(k):
		ekran_konumu = k
		_guncelle()

var kalkis := 0.0:
	set(k):
		kalkis = clampf(k, 0.0, 1.0)
		_guncelle()

var yatis_acisi := 0.0:               ## masada dururkenki hafif dönüklük (radyan)
	set(a):
		yatis_acisi = a
		_guncelle()

const ELDE_KATMANI := 30

var _gecis: Tween


func icerik() -> Control:
	return get_child(0) as Control if get_child_count() > 0 else null


## İçeriği taşıyıcının ortasına hizalar (içeriğin boyutu değişince çağrılır).
func ortala() -> void:
	var c := icerik()
	if c != null:
		c.position = -c.size / 2.0


## Masadan kaldırır / masaya bırakır (yumuşak geçişle).
func kalkisa_gec(hedef: float, sure: float = 0.18) -> Tween:
	if _gecis != null:
		_gecis.kill()
	_gecis = create_tween()
	_gecis.tween_property(self, "kalkis", hedef, sure).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return _gecis


func gecisi_durdur() -> void:
	if _gecis != null:
		_gecis.kill()
		_gecis = null


func _guncelle() -> void:
	# elde tutulan nesne tepsinin ve masadaki öbür nesnelerin üstünde çizilir
	z_index = ELDE_KATMANI if kalkis > 0.01 else 0
	var yatik := Perspektif.yerel(masa_konumu)
	if yatis_acisi != 0.0:
		yatik = yatik * Transform2D(yatis_acisi, Vector2.ZERO)
	if kalkis <= 0.0:
		transform = yatik
		return
	var duz := Transform2D(0.0, ekran_konumu)
	if kalkis >= 1.0:
		transform = duz
		return
	transform = Transform2D(yatik.x.lerp(duz.x, kalkis), yatik.y.lerp(duz.y, kalkis),
		yatik.origin.lerp(duz.origin, kalkis))
