extends Control
## Ana menü. (Aşama 0: yer tutucu kutular ve etiketler.)

var _devam: Button


func _ready() -> void:
	var zemin := ColorRect.new()
	zemin.color = Stil.DUVAR_KOYU
	zemin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(zemin)

	var baslik := Stil.etiket("NÖBETÇİ MEMUR", 64, Stil.MUREKKEP, Stil.daktilo_kalin())
	baslik.position = Vector2(0, 130)
	baslik.size = Vector2(1280, 80)
	baslik.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(baslik)

	var alt := Stil.etiket("Ardıçlı İlçesi Nüfus Müdürlüğü — 1984", 20, Stil.MUREKKEP_SOLUK)
	alt.position = Vector2(0, 215)
	alt.size = Vector2(1280, 30)
	alt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(alt)

	var kutu := VBoxContainer.new()
	kutu.position = Vector2(500, 320)
	kutu.size = Vector2(280, 0)
	kutu.add_theme_constant_override("separation", 16)
	add_child(kutu)

	var yeni := _dugme("Yeni Oyun", kutu)
	yeni.name = "YeniOyun"
	yeni.pressed.connect(_yeni_oyun)
	_devam = _dugme("Devam", kutu)
	_devam.name = "Devam"
	_devam.disabled = not Oyun.kayit_var_mi()
	_devam.pressed.connect(_devam_et)
	var cikis := _dugme("Çıkış", kutu)
	cikis.name = "Cikis"
	cikis.pressed.connect(func() -> void: get_tree().quit())


func _dugme(metin: String, ebeveyn: Control) -> Button:
	var d := Button.new()
	d.text = metin
	d.custom_minimum_size = Vector2(280, 48)
	ebeveyn.add_child(d)
	return d


func _yeni_oyun() -> void:
	Oyun.yeni_oyun()
	Oyun.sahneye_gec("masa")


func _devam_et() -> void:
	if Oyun.yukle():
		Oyun.sahneye_gec("masa")
