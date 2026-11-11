extends Control
## Akşam aile ekranı. (Aşama 0: yer tutucu.)


func _ready() -> void:
	var zemin := ColorRect.new()
	zemin.color = Stil.GECE
	zemin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(zemin)

	var baslik := Stil.etiket("AKŞAM — EV", 44, Stil.KAGIT, Stil.daktilo_kalin())
	baslik.position = Vector2(0, 120)
	baslik.size = Vector2(1280, 60)
	baslik.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(baslik)

	var bilgi := Stil.etiket("Eldeki para: %s\n(Kira, kömür, ekmek, ilaç ve okul masrafı burada seçilecek.)" % Stil.tl(Oyun.para), 20, Stil.KAGIT_ESKI)
	bilgi.position = Vector2(0, 250)
	bilgi.size = Vector2(1280, 80)
	bilgi.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(bilgi)

	var yat := Button.new()
	yat.name = "Yat"
	yat.text = "Yat — Sonraki Gün" if Oyun.gun < Oyun.TOPLAM_GUN else "Yat — Demo Sonu"
	yat.position = Vector2(500, 460)
	yat.custom_minimum_size = Vector2(280, 48)
	yat.pressed.connect(_yat)
	add_child(yat)


func _yat() -> void:
	if Oyun.sonraki_gun():
		Oyun.sahneye_gec("masa")
	else:
		Oyun.sahneye_gec("menu")
