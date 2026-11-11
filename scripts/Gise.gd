class_name Gise
extends Control
## Gişe camı: vatandaşın büstü camın ardında belirir, işi bitince çekilir.
## İnceleme modunda yüz, nüfus cüzdanındaki fotoğrafla karşılaştırılabilen bir hedeftir.

signal hedef_tiklandi(hedef: Hedef)

const OLCEK := 0.46          ## portre dokusunun camdaki ölçeği
const GELIS_SURESI := 0.6

var yuz: Hedef
var kimlik := ""

var _portre: TextureRect
var _hareket: Tween


func _ready() -> void:
	position = Yerlesim.GISE_ACIKLIK.position
	size = Yerlesim.GISE_ACIKLIK.size
	clip_contents = true
	mouse_filter = MOUSE_FILTER_IGNORE

	_portre = TextureRect.new()
	_portre.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portre.stretch_mode = TextureRect.STRETCH_SCALE
	_portre.mouse_filter = MOUSE_FILTER_IGNORE
	_portre.visible = false
	add_child(_portre)

	var cam := Control.new()
	cam.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	cam.mouse_filter = MOUSE_FILTER_IGNORE
	cam.draw.connect(_cam_ciz.bind(cam))
	add_child(cam)

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
	var doku := Portreler.doku(portre_kimligi)
	var boyut := doku.get_size() * OLCEK
	var yer := Vector2((size.x - boyut.x) / 2.0, size.y - boyut.y + 3.0)
	_portre.texture = doku
	_portre.size = boyut
	_portre.position = Vector2(-boyut.x - 12.0, yer.y)
	_portre.modulate = Color(0.78, 0.80, 0.80)
	_portre.visible = true
	yuz.deger = portre_kimligi
	yuz.position = Vector2(yer.x + boyut.x * 0.18, maxf(4.0, yer.y))
	yuz.size = Vector2(boyut.x * 0.64, minf(boyut.y * 0.74, size.y - yuz.position.y - 8.0))
	yuz.durum = Hedef.Durum.BOS
	yuz.visible = false
	_yuru(yer, GELIS_SURESI, true)


## İşi biten vatandaş sağa doğru çekilir.
func gitsin() -> void:
	if kimlik == "":
		return
	kimlik = ""
	yuz.visible = false
	yuz.durum = Hedef.Durum.BOS
	_yuru(Vector2(size.x + 14.0, _portre.position.y), GELIS_SURESI * 0.9, false)


func _yuru(hedef: Vector2, sure: float, gelis: bool) -> void:
	if _hareket != null:
		_hareket.kill()
	var taban_y := hedef.y
	_hareket = create_tween()
	_hareket.tween_property(_portre, "position:x", hedef.x, sure) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT if gelis else Tween.EASE_IN)
	# adım atarken hafif inip kalkma
	_hareket.parallel().tween_method(func(t: float) -> void:
		_portre.position.y = taban_y + absf(sin(t * PI * 3.0)) * 5.0 * (1.0 - t if gelis else t), 0.0, 1.0, sure)
	if gelis:
		_hareket.parallel().tween_property(_portre, "modulate", Color.WHITE, sure)
		_hareket.tween_callback(func() -> void: yuz.visible = true)
	else:
		_hareket.tween_callback(func() -> void: _portre.visible = false)


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
