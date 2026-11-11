extends Control
## Gün sonu özeti. (Aşama 0: yer tutucu.)


func _ready() -> void:
	var zemin := ColorRect.new()
	zemin.color = Stil.KAGIT_ESKI
	zemin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(zemin)

	var baslik := Stil.etiket("%d. GÜN SONU" % Oyun.gun, 44, Stil.MUREKKEP, Stil.daktilo_kalin())
	baslik.position = Vector2(0, 120)
	baslik.size = Vector2(1280, 60)
	baslik.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(baslik)

	var o := Oyun.gun_ozeti
	var satirlar := "İşlenen vatandaş : %d\nGünün kazancı    : %s\nKasadaki para    : %s\nToplam ihtar     : %d" % [
		int(o.get("islenen", 0)), Stil.tl(int(o.get("kazanc", 0))), Stil.tl(Oyun.para), Oyun.ihtar]
	var ozet := Stil.etiket(satirlar, 22)
	ozet.position = Vector2(440, 240)
	add_child(ozet)

	var eve := Button.new()
	eve.name = "EveGit"
	eve.text = "Eve Git"
	eve.position = Vector2(540, 480)
	eve.custom_minimum_size = Vector2(200, 48)
	eve.pressed.connect(func() -> void: Oyun.sahneye_gec("aile"))
	add_child(eve)
