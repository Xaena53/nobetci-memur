extends Control
## Oyun sonu. (Geçici hâl: Aşama 4'te gazete kupürü olarak yeniden yazılacak.)


func _ready() -> void:
	var zemin := ColorRect.new()
	zemin.color = Stil.GECE
	zemin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(zemin)

	var s := Oyun.son
	var baslik := Stil.etiket(Stil.buyuk(str(s.get("tur", "son"))), 44, Stil.KAGIT, Stil.daktilo_kalin())
	baslik.position = Vector2(0, 220)
	baslik.size = Vector2(1280, 60)
	baslik.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(baslik)

	var neden := Stil.etiket(str(s.get("neden", "")), 20, Stil.KAGIT_ESKI)
	neden.position = Vector2(0, 300)
	neden.size = Vector2(1280, 30)
	neden.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(neden)

	var menu := Button.new()
	menu.name = "AnaMenu"
	menu.text = "Ana Menü"
	menu.custom_minimum_size = Vector2(220, 46)
	menu.position = Vector2(530, 470)
	menu.pressed.connect(func() -> void: Oyun.sahneye_gec("menu"))
	add_child(menu)
