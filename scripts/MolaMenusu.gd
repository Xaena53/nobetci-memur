class_name MolaMenusu
extends Control
## Mola: ESC ile açılan duraklatma menüsü. Oyun durur; devam edilir, ayarlar açılır ya da
## ana menüye dönülür (gün içindeki ilerleme kaydedilmez; sabahki kayıt durur).

signal devam_edildi
signal menuye_donuldu

const KAGIT := Vector2(380, 372)

var _ayarlar: AyarlarPenceresi


func _ready() -> void:
	name = "MolaMenusu"
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = Stil.tema()     # üst katmanda (CanvasLayer altında) kök tema kendiliğinden gelmez
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP

	var perde := ColorRect.new()
	perde.color = Color(0.07, 0.06, 0.05, 0.96)      # saat dururken masadaki evrak okunamasın
	perde.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	perde.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(perde)

	var kagit := Control.new()
	kagit.name = "Kagit"
	kagit.size = KAGIT
	kagit.position = (Yerlesim.EKRAN.size - KAGIT) / 2.0
	kagit.pivot_offset = KAGIT / 2.0
	kagit.rotation = deg_to_rad(1.0)
	kagit.mouse_filter = MOUSE_FILTER_IGNORE
	kagit.draw.connect(func() -> void: Kagit.ciz(kagit, Rect2(Vector2.ZERO, KAGIT), "sayfa", Stil.KAGIT, 14.0, 4.0))
	add_child(kagit)

	var baslik := Stil.etiket("ÇAY MOLASI", 24, Stil.MUREKKEP, Stil.daktilo_kalin())
	baslik.position = Vector2(0, 40)
	baslik.size = Vector2(KAGIT.x, 30)
	baslik.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kagit.add_child(baslik)
	var alt := Stil.etiket("Kuyruk bekler. Çay beklemez.", 12, Stil.MUREKKEP_SOLUK, Stil.daktilo_italik())
	alt.position = Vector2(0, 72)
	alt.size = Vector2(KAGIT.x, 16)
	alt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kagit.add_child(alt)

	var y := 112.0
	for d: Array in [["MolaDevam", "Gişeye Dön", _devam], ["MolaAyarlar", "Ayarlar", _ayarlari_ac], ["MolaMenu", "Ana Menüye Dön", _menu]]:
		var dugme := Button.new()
		dugme.name = str(d[0])
		dugme.text = str(d[1])
		dugme.focus_mode = FOCUS_NONE
		dugme.custom_minimum_size = Vector2(250, 44)
		dugme.position = Vector2((KAGIT.x - 250.0) / 2.0, y)
		dugme.pressed.connect(d[2])
		kagit.add_child(dugme)
		y += 58.0
	var uyari := Stil.etiket("Ana menüye dönerseniz bugünkü mesai\nsabahtan yeniden başlar.", 11, Stil.BORDO, Stil.daktilo_italik())
	uyari.position = Vector2(0, y - 2.0)
	uyari.size = Vector2(KAGIT.x, 34)
	uyari.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kagit.add_child(uyari)

	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.15)


## ESC'ye yeniden basılınca: önce ayarlar kapanır, sonra mola biter.
func geri() -> void:
	if is_instance_valid(_ayarlar):
		_ayarlar.kapat()
	else:
		_devam()


func _devam() -> void:
	devam_edildi.emit()


func _ayarlari_ac() -> void:
	if is_instance_valid(_ayarlar):
		return
	_ayarlar = AyarlarPenceresi.new()
	add_child(_ayarlar)


func _menu() -> void:
	menuye_donuldu.emit()
