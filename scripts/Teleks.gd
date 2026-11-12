class_name Teleks
extends Node2D
## Müdürlük hattına bağlı teleks cihazı. Müdürün ihtarlarını, uyarılarını ve notlarını
## kâğıda satır satır basar: kâğıt, cihazın ön yüzündeki yarıktan her vuruşta bir satır
## ilerleyerek masaya doğru uzar; basım bitince kopar ve cihazın önünde kalır.
##
## Cihazın kendisi arka plan görselinin parçasıdır; burada yalnızca yarıktan çıkan kâğıt,
## yanıp sönen lamba ve basım sırası yönetilir.

signal basim_basladi
signal satir_basildi            ## her vuruşta (ses için)
signal fis_koptu(fis: IhtarFisi)

const VURUS_ARASI := 0.30       ## iki satır arası bekleme (sn)
const SURME_SURESI := 0.11      ## kâğıdın bir satır ilerleme süresi (sn)

var basiyor := false

var _sira: Array[Dictionary] = []
var _cikis: Node2D              ## yarığın masa düzlemindeki yerel uzayı
var _kirpma: Control            ## kâğıdın yarıktan sonra göründüğü pencere
var _fis_katmani: Node
var _igne_yeri := Vector2.ZERO
var _yarik_masa := Vector2.ZERO
var _masadaki: IhtarFisi
var _lamba := 0.0


## `fis_katmani`: kopan pusulaların masada duracağı katman. `igne_yeri`: kapanınca süzülecekleri yer (ekran).
func kur(fis_katmani: Node, igne_yeri: Vector2) -> void:
	_fis_katmani = fis_katmani
	_igne_yeri = igne_yeri
	var y := Yerlesim.TELEKS_YARIK
	_yarik_masa = Perspektif.masaya(Vector2(y.get_center().x, y.end.y - 4.0))
	_cikis = Node2D.new()
	_cikis.name = "Cikis"
	_cikis.transform = Perspektif.yerel(_yarik_masa)
	add_child(_cikis)
	_kirpma = Control.new()
	_kirpma.name = "Kirpma"
	_kirpma.clip_contents = true
	_kirpma.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kirpma.position = Vector2(-IhtarFisi.GENISLIK / 2.0 - 10.0, 0)
	_kirpma.size = Vector2(IhtarFisi.GENISLIK + 20.0, 320)
	_cikis.add_child(_kirpma)


## Bir pusulayı basım sırasına koyar. `cesit`: "ihtar" | "uyari" | "not".
func yazdir(metin: String, no: int, cesit: String) -> void:
	_sira.append({"metin": metin, "no": no, "cesit": cesit})
	if not basiyor:
		_siradakini_bas()


func _siradakini_bas() -> void:
	if _sira.is_empty():
		basiyor = false
		return
	basiyor = true
	basim_basladi.emit()
	# Yarığın önü dolu ise eski pusula iğneye gider.
	if _masadaki != null and is_instance_valid(_masadaki):
		_masadaki.kapat()
	_masadaki = null

	var is_emri: Dictionary = _sira.pop_front()
	var fis := IhtarFisi.new()
	fis.hazirla(str(is_emri.metin), int(is_emri.no), str(is_emri.cesit))
	_kirpma.add_child(fis)
	fis.position = Vector2(10.0, -fis.size.y)

	await Oyun.bekle(0.35)
	for adim: float in fis.adimlar:
		if not is_instance_valid(fis):
			break
		satir_basildi.emit()
		_fisi_sur(fis, adim)
		await Oyun.bekle(VURUS_ARASI)
	if not is_instance_valid(fis):
		_siradakini_bas()
		return
	# Kopar: pusula masada kendi yerine geçer.
	await Oyun.bekle(0.25)
	var orta := _yarik_masa + Vector2(0, fis.position.y + fis.size.y / 2.0)
	fis.masaya_birak(_fis_katmani, orta, _igne_yeri)
	_masadaki = fis
	fis_koptu.emit(fis)
	await Oyun.bekle(0.4)
	_siradakini_bas()


## Kâğıdı bir satır aşağı sürer. (Geçiş nesnesi, bekleyen işlevin yerel değişkeninde tutulmaz.)
func _fisi_sur(fis: IhtarFisi, adim: float) -> void:
	var t := create_tween()
	t.tween_property(fis, "position:y", fis.position.y + adim, SURME_SURESI)


func _process(delta: float) -> void:
	var hedef := 1.0 if basiyor else 0.0
	if _lamba != hedef or basiyor:
		_lamba = move_toward(_lamba, hedef, delta * 4.0)
		queue_redraw()


## Basım sırasında yanıp sönen kırmızı lamba.
func _draw() -> void:
	if _lamba <= 0.01:
		return
	var m := Yerlesim.TELEKS_LAMBA
	var nabiz := 0.55 + 0.45 * sin(Time.get_ticks_msec() / 90.0)
	var guc := _lamba * nabiz
	draw_circle(m, 15.0, Color(1.0, 0.25, 0.15, 0.10 * guc))
	draw_circle(m, 9.5, Color(1.0, 0.30, 0.18, 0.22 * guc))
	draw_circle(m, 5.5, Color(1.0, 0.55, 0.40, 0.75 * guc))
	draw_circle(m + Vector2(-1.5, -1.5), 2.0, Color(1.0, 0.95, 0.85, 0.8 * guc))
