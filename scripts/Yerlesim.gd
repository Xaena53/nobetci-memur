class_name Yerlesim
extends RefCounted
## Masa sahnesinin sabit yerleşimi (1280x720 tasarım çözünürlüğü).
## Koordinatlar arka plan görselinden (assets/img/masa_arkaplan.webp) ölçüldü; görsel
## değişirse yalnızca buradaki değerler güncellenir (ölçmek için: tools/sanat/olc.py).

const EKRAN := Rect2(0, 0, 1280, 720)

# Duvar
const GISE_ACIKLIK := Rect2(40, 31, 273, 229)   ## vatandaşın göründüğü cam
const GISE_YARIK := Vector2(176, 280)           ## belgelerin çıktığı yarığın ortası
const BALON := Rect2(354, 16, 276, 176)         ## konuşma balonunun en geniş alanı
const SAAT_MERKEZ := Vector2(676.5, 60)
const SAAT_YARICAP := 30.0                      ## kadranın yarıçapı
const TAKVIM_YAPRAK := Rect2(647, 124, 60, 69)
const SAAT_ETIKETI := Rect2(646, 199, 62, 17)   ## takvimin altındaki dijital saat şeridi
const MUDUR_CAMI := Rect2(731, 50, 145, 140)
const MUDUR_PLAKET := Rect2(762, 14, 84, 21)
const RADYO := Rect2(385, 233, 155, 57)

# Masa
const MASA_ALANI := Rect2(4, 308, 888, 408)     ## belgelerin gezebildiği alan
const SUMEN := Rect2(28, 330, 838, 364)

# Sağ yan dolap
const PANO := Rect2(916, 16, 344, 405)          ## mantar pano: genelge defteri
const TEPSI := Rect2(920, 451, 340, 244)        ## çuha kaplı araç tepsisi
const ISTAMPA := Rect2(940, 501, 108, 50)       ## ıstampanın mürekkepli yüzü
const CAY := Vector2(1206, 639)                 ## çay bardağının ortası

## Belgelerin gişeden gelince kondukları yerler.
const BELGE_YERI := {
	"nufus_cuzdani": Vector2(46, 322),
	"harc_makbuzu": Vector2(62, 538),
	"ikametgah": Vector2(410, 324),
}
