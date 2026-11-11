class_name Yerlesim
extends RefCounted
## Masa sahnesinin sabit yerleşimi (1280x720 tasarım çözünürlüğü).
## Koordinatlar arka plan görselinden (assets/img/masa_arkaplan.webp) ölçüldü; görsel
## değişirse yalnızca buradaki değerler güncellenir (ölçmek için: tools/sanat/olc.py).
##
## İki koordinat takımı vardır:
##  - EKRAN: duvardaki ve dolaptaki cepheden görünen öğeler (gişe, saat, pano).
##  - MASA: masanın kuş bakışı planı (u, v). Ekrana Perspektif ile taşınır; masadaki her şey
##    (belgeler, tepsideki araçlar) bu koordinatlarla yerleştirilir.

const EKRAN := Rect2(0, 0, 1280, 720)

# --- Duvar (ekran koordinatı) ---
const GISE_ACIKLIK := Rect2(40, 32, 273, 230)   ## vatandaşın göründüğü cam
const GISE_YARIK := Vector2(175.5, 296.5)       ## belgelerin çıktığı yarığın ortası
const BALON := Rect2(354, 16, 276, 176)         ## konuşma balonunun en geniş alanı
const SAAT_MERKEZ := Vector2(677.5, 57.5)
const SAAT_YARICAP := 30.5                      ## kadranın yarıçapı
const TAKVIM_YAPRAK := Rect2(648, 124, 60, 70)
const SAAT_ETIKETI := Rect2(647, 200, 62, 17)   ## takvimin altındaki dijital saat şeridi
const MUDUR_CAMI := Rect2(733, 50, 143, 140)
const MUDUR_PLAKET := Rect2(762, 13, 84, 21)
const RADYO := Rect2(382, 236, 162, 64)

# --- Sağdaki evrak dolabı (ekran koordinatı) ---
const PANO := Rect2(933, 21, 326, 369)          ## mantar pano: genelge defteri

# --- Masa düzlemi: plan dikdörtgeni ↔ ekrandaki yamuk (yeşil sümenin dört köşesi) ---
const MASA_DUZ := [Vector2(30, 22), Vector2(905, 22), Vector2(905, 436), Vector2(30, 436)]
const MASA_EKRAN := [Vector2(83, 339.4), Vector2(863.6, 339.4), Vector2(903, 704), Vector2(32, 704)]

# --- Masa (masa koordinatı) ---
const MASA_BELGE_ALANI := Rect2(24, 4, 884, 448)   ## belgelerin gezebildiği alan
## Belgelerin gişeden gelince kondukları yerler (ortaları).
const BELGE_YERI := {
	"nufus_cuzdani": Vector2(215, 122),
	"harc_makbuzu": Vector2(205, 350),
	"ikametgah": Vector2(560, 236),
}
const IHTAR_YERI := Vector2(690, 150)           ## müdürden gelen pusulanın düştüğü yer

# --- Araç tepsisi (masa koordinatı) ---
const TEPSI := Rect2(968, 142, 297, 273)
const MUHUR_YERI := Vector2(1047, 222)          ## ıstampanın üstü
const EKSIK_YERI := Vector2(1188, 178)
const HAVALE_YERI := Vector2(1185, 234)
const BUYUTEC_YERI := Vector2(1036, 343)
const IGNE_YERI := Vector2(1118, 372)           ## ihtarların takıldığı iğne
