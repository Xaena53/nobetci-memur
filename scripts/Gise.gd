class_name Gise
extends Control
## Gişe camı: vatandaşın büstü camın ardında yürüyerek gelir, bekler, konuşur, işi bitince çekilir.
## Büst CanliPortre ile canlandırılır; bekledikçe sabrı taşar ve öfleyip pöfler.
## İnceleme modunda yüz, nüfus cüzdanındaki fotoğrafla karşılaştırılabilen bir hedeftir.

signal hedef_tiklandi(hedef: Hedef)
signal efekt(ad: String)        ## portreden gelen ses olayları ("adim", "hece", "ofle")

const OLCEK := 0.46             ## portre dokusunun camdaki ölçeği
const GELIS_SURESI := 0.85
const ILK_SABIR := Vector2(24.0, 36.0)     ## ilk öflemeye kadar geçen süre aralığı (sn)
const SONRAKI_SABIR := Vector2(15.0, 26.0)

var yuz: Hedef
var portre: CanliPortre
var kimlik := ""

var kepenk := 0.0:              ## 0 açık .. 1 tamamen inik
	set(k):
		kepenk = clampf(k, 0.0, 1.0)
		if _kepenk_cizimi != null:
			_kepenk_cizimi.queue_redraw()

var _hareket: Tween
var _sabir := 30.0
var _kepenk_cizimi: Control


func _ready() -> void:
	position = Yerlesim.GISE_ACIKLIK.position
	size = Yerlesim.GISE_ACIKLIK.size
	clip_contents = true
	mouse_filter = MOUSE_FILTER_IGNORE

	portre = CanliPortre.new()
	portre.name = "Portre"
	portre.visible = false
	portre.efekt.connect(func(ad: String) -> void: efekt.emit(ad))
	add_child(portre)

	var cam := Control.new()
	cam.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	cam.mouse_filter = MOUSE_FILTER_IGNORE
	cam.draw.connect(_cam_ciz.bind(cam))
	add_child(cam)

	_kepenk_cizimi = Control.new()
	_kepenk_cizimi.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_kepenk_cizimi.mouse_filter = MOUSE_FILTER_IGNORE
	_kepenk_cizimi.draw.connect(_kepenk_ciz)
	add_child(_kepenk_cizimi)

	yuz = Hedef.new()
	yuz.tip = "yuz"
	yuz.etiket = "Vatandaşın yüzü"
	yuz.visible = false
	yuz.tiklandi.connect(func(h: Hedef) -> void: hedef_tiklandi.emit(h))
	add_child(yuz)


func bos_mu() -> bool:
	return kimlik == ""


## Vatandaş soldan yürüyerek cama gelir.
func gelsin(portre_kimligi: String) -> void:
	kimlik = portre_kimligi
	portre.ayarla(portre_kimligi, OLCEK)
	var boyut := portre.size
	var yer := Vector2((size.x - boyut.x) / 2.0, size.y - boyut.y + 3.0)
	portre.position = Vector2(-boyut.x - 14.0, yer.y)
	portre.modulate = Color(0.74, 0.77, 0.78)
	portre.visible = true
	portre.yuruyor = true
	yuz.deger = portre_kimligi
	yuz.position = Vector2(yer.x + boyut.x * 0.18, maxf(4.0, yer.y))
	yuz.size = Vector2(boyut.x * 0.64, minf(boyut.y * 0.74, size.y - yuz.position.y - 8.0))
	yuz.durum = Hedef.Durum.BOS
	yuz.visible = false
	_sabir = randf_range(ILK_SABIR.x, ILK_SABIR.y)
	if _hareket != null:
		_hareket.kill()
	_hareket = create_tween()
	_hareket.tween_property(portre, "position:x", yer.x, GELIS_SURESI).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_hareket.parallel().tween_property(portre, "modulate", Color.WHITE, GELIS_SURESI)
	_hareket.tween_callback(func() -> void:
		portre.yuruyor = false
		yuz.visible = true)


## İşi biten vatandaş sağa doğru yürüyüp çekilir.
func gitsin() -> void:
	if kimlik == "":
		return
	kimlik = ""
	yuz.visible = false
	yuz.durum = Hedef.Durum.BOS
	portre.konusuyor = false
	portre.yuruyor = true
	if _hareket != null:
		_hareket.kill()
	_hareket = create_tween()
	_hareket.tween_property(portre, "position:x", size.x + 16.0, GELIS_SURESI * 0.9) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_hareket.parallel().tween_property(portre, "modulate", Color(0.74, 0.77, 0.78), GELIS_SURESI * 0.9)
	_hareket.tween_callback(func() -> void:
		portre.visible = false
		portre.yuruyor = false
		portre.sifirla())


## Konuşma balonu yazarken ağız oynar.
func konus(acik: bool) -> void:
	if kimlik != "":
		portre.konusuyor = acik


## Karara verilen tepki: "onay" sevinir, "eksik" üzülür, "havale" şaşırır.
func tepki(karar: String) -> void:
	if kimlik == "":
		return
	match karar:
		"onay":
			portre.sevin()
		"eksik":
			portre.uzul()
		"havale":
			portre.sas()


## Sabır sayacını baştan kurar (oyuncu vatandaşla ilgilenince).
func sabri_tazele() -> void:
	_sabir = maxf(_sabir, randf_range(SONRAKI_SABIR.x, SONRAKI_SABIR.y) * 0.6)


func _process(delta: float) -> void:
	if kimlik == "" or portre.yuruyor or portre.konusuyor:
		return
	_sabir -= delta
	if _sabir <= 0.0:
		_sabir = randf_range(SONRAKI_SABIR.x, SONRAKI_SABIR.y)
		portre.ofle()


## Mesai bitince ahşap kepenk iner.
func kepengi_indir(sure: float = 1.1) -> void:
	var t := create_tween()
	t.tween_property(self, "kepenk", 1.0, sure).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## İnen kepenk: yatay ahşap latalar ve altında tutamak çıtası.
func _kepenk_ciz() -> void:
	if kepenk <= 0.001:
		return
	var w := size.x
	var alt := size.y * kepenk
	var y := alt
	var i := 0
	while y > -14.0:
		var ust := y - 13.0
		var ton := Color("7a5334") if i % 2 == 0 else Color("71492d")
		_kepenk_cizimi.draw_rect(Rect2(0, ust, w, 13.0), ton)
		_kepenk_cizimi.draw_rect(Rect2(0, ust, w, 2.0), Color(1, 0.9, 0.7, 0.10))
		_kepenk_cizimi.draw_rect(Rect2(0, y - 2.5, w, 2.5), Color(0, 0, 0, 0.30))
		y -= 13.0
		i += 1
	_kepenk_cizimi.draw_rect(Rect2(0, alt - 7.0, w, 7.0), Color("4a3222"))
	_kepenk_cizimi.draw_rect(Rect2(0, alt, w, 9.0), Color(0, 0, 0, 0.22))
	if kepenk > 0.96:
		var levha := Rect2(w / 2.0 - 52.0, size.y * 0.44, 104.0, 30.0)
		_kepenk_cizimi.draw_rect(levha, Color("efe6cd"))
		_kepenk_cizimi.draw_rect(levha, Color("4a3222"), false, 2.0)
		_kepenk_cizimi.draw_string(Stil.daktilo_kalin(), levha.position + Vector2(0, 21), "KAPALI",
			HORIZONTAL_ALIGNMENT_CENTER, levha.size.x, 18, Stil.BORDO)


## Camın yansıması: iki çapraz ışık şeridi ve üstte çerçeve gölgesi.
func _cam_ciz(cam: Control) -> void:
	var w := cam.size.x
	var h := cam.size.y
	cam.draw_colored_polygon(PackedVector2Array([Vector2(w * 0.10, 0), Vector2(w * 0.30, 0),
		Vector2(w * 0.02, h * 0.78), Vector2(0, h * 0.62), Vector2(0, h * 0.30)]), Color(1, 1, 1, 0.055))
	cam.draw_colored_polygon(PackedVector2Array([Vector2(w * 0.40, 0), Vector2(w * 0.47, 0),
		Vector2(w * 0.10, h), Vector2(w * 0.02, h)]), Color(1, 1, 1, 0.04))
	cam.draw_rect(Rect2(0, 0, w, 10), Color(0, 0, 0, 0.16))
	cam.draw_rect(Rect2(0, 10, w, 8), Color(0, 0, 0, 0.07))
