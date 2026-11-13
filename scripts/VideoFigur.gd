class_name VideoFigur
extends Control
## Bir figürün gerçek canlandırmasını (kısa, döngülü video) saydam zeminle oynatır.
##
## Video `assets/video/<ad>.ogv` dosyasıdır; renk ve saydamlık yan yana kodlanmıştır
## (tools/sanat/figur_video.py), video_figur.gdshader ikisini birleştirir. Videonun, figürün boyalı
## resmine göre yeri `data/figur_videolari.json` dosyasındadır: düğüm, aynı resmi çizen CanliPortre'nin
## tam üstüne oturtulur.

const GOLGELEYICI := preload("res://assets/shader/video_figur.gdshader")
const BILGI := "res://data/figur_videolari.json"
const VIDEO := "res://assets/video/%s.ogv"

var _oynatici: VideoStreamPlayer


## Figürün videosu var mı?
static func var_mi(ad: String) -> bool:
	var bilgi: Variant = Veri.oku(BILGI)
	return typeof(bilgi) == TYPE_DICTIONARY and bilgi.has(ad) and ResourceLoader.exists(VIDEO % ad)


## Videoyu kurar. `resim_yeri` figür resminin ekrandaki sol üst köşesi, `olcek` resmin ekrandaki ölçeğidir.
func kur(ad: String, resim_yeri: Vector2, olcek: float) -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	var kutu: Array = (Veri.oku(BILGI) as Dictionary)[ad].kutu
	position = resim_yeri + Vector2(float(kutu[0]), float(kutu[1])) * olcek
	size = Vector2(float(kutu[2]), float(kutu[3])) * olcek
	_oynatici = VideoStreamPlayer.new()
	_oynatici.stream = load(VIDEO % ad)
	_oynatici.expand = true
	_oynatici.loop = true
	_oynatici.volume_db = -80.0
	_oynatici.mouse_filter = MOUSE_FILTER_IGNORE
	_oynatici.size = size
	var m := ShaderMaterial.new()
	m.shader = GOLGELEYICI
	_oynatici.material = m
	add_child(_oynatici)
	_oynatici.play()


## Figür durur (hasta, bitkin) ya da yeniden hareketlenir.
func durdur(dursun: bool) -> void:
	if _oynatici != null:
		_oynatici.paused = dursun

