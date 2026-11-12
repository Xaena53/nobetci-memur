extends Control
## Gün sonu: müdürün imzaladığı "günlük puantaj". İşlenen vatandaş, doğru/yanlış, ihtarlar,
## yevmiye + prim − kesinti ve eldeki para satır satır daktilo edilir.

const ARKA_PLAN := "res://assets/img/masa_arkaplan.webp"
const KAGIT := Vector2(500, 640)
const SATIR_ARASI := 0.11      ## satırların belirme aralığı (sn)
const SATIR_HARFI := 38

var _satirlar: Array[Control] = []


func _ready() -> void:
	Ses.yalniz([])
	var o := Oyun.gun_ozeti
	var maas: Dictionary = o.get("maas", Oyun.maas_hesapla(o))
	var gun := Veri.gun(Oyun.gun)

	if ResourceLoader.exists(ARKA_PLAN):
		var zemin := TextureRect.new()
		zemin.texture = load(ARKA_PLAN)
		zemin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		zemin.size = Yerlesim.EKRAN.size
		zemin.modulate = Color(0.30, 0.28, 0.26)
		zemin.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(zemin)

	var kagit := Control.new()
	kagit.name = "Kagit"
	kagit.size = KAGIT
	kagit.position = Vector2((Yerlesim.EKRAN.size.x - KAGIT.x) / 2.0, 34)
	kagit.rotation = deg_to_rad(-0.8)
	kagit.pivot_offset = KAGIT / 2.0
	kagit.mouse_filter = MOUSE_FILTER_IGNORE
	kagit.draw.connect(func() -> void: Kagit.ciz(kagit, Rect2(Vector2.ZERO, KAGIT), "sayfa", Stil.KAGIT, 14.0, 4.0))
	add_child(kagit)

	var x := 50.0
	var y := 38.0
	_baslik(kagit, "ARDIÇLI İLÇESİ NÜFUS MÜDÜRLÜĞÜ", y, 11, Stil.MUREKKEP_SOLUK, Stil.serif_kalin())
	y += 18.0
	_baslik(kagit, "GÜNLÜK PUANTAJ", y, 22, Stil.MUREKKEP, Stil.daktilo_kalin())
	y += 30.0
	_baslik(kagit, "%d. gün — %s" % [Oyun.gun, Tarih.uzun(str(gun.get("tarih", "")))], y, 12, Stil.MUREKKEP_SOLUK,
		Stil.daktilo_italik())
	y += 30.0

	var dogru := int(o.get("dogru", 0))
	y = _satir(kagit, "İşlem gören vatandaş", str(int(o.get("islenen", 0))), x, y)
	y = _satir(kagit, "Doğru işlem", str(dogru), x, y)
	y = _satir(kagit, "İhtar", str(int(o.get("ihtar", 0))), x, y, Stil.BORDO if int(o.get("ihtar", 0)) > 0 else Stil.MUREKKEP)
	y = _satir(kagit, "Uyarı (gerekçe yanlış)", str(int(o.get("yarim", 0))), x, y)
	y = _satir(kagit, "Müdüre havale", str(int(o.get("havale", 0))), x, y)
	if int(o.get("yarida", 0)) > 0:
		y = _satir(kagit, "Kapanışta yarıda kalan", str(int(o.get("yarida", 0))), x, y)
	y += 14.0
	y = _satir(kagit, "Yevmiye", Stil.tl(int(maas.yevmiye)), x, y)
	y = _satir(kagit, "Prim", Stil.tl(int(maas.prim)), x, y)
	y = _satir(kagit, "İhtar kesintisi", "-" + Stil.tl(int(maas.kesinti)) if int(maas.kesinti) > 0 else Stil.tl(0), x, y,
		Stil.BORDO if int(maas.kesinti) > 0 else Stil.MUREKKEP)
	y = _cizgi(kagit, x, y)
	y = _satir(kagit, "GÜNÜN KAZANCI", Stil.tl(int(maas.net)), x, y, Stil.MUREKKEP, true)
	y = _satir(kagit, "Eldeki para", Stil.tl(Oyun.para), x, y, Stil.BORDO if Oyun.para < 0 else Stil.MUREKKEP, true)
	if int(o.get("zarf", 0)) > 0:
		# puantajda yeri olmayan para: kenara kurşun kalemle düşülmüş not
		var zarf := Stil.etiket("(çekmecedeki zarf: %s — bunu kimse bilmiyor)" % Stil.tl(int(o.zarf)), 17, Stil.MAVI_MUREKKEP, Stil.el_yazisi())
		zarf.position = Vector2(x + 8.0, y - 6.0)
		zarf.rotation = deg_to_rad(-1.2)
		kagit.add_child(zarf)
		_satirlar.append(zarf)
		y += 16.0
	y += 12.0

	var notu := Stil.etiket(_mudur_notu(o), 12, Stil.MAVI_MUREKKEP, Stil.daktilo_italik())
	notu.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notu.position = Vector2(x, y)
	notu.size = Vector2(KAGIT.x - 2.0 * x, 64)
	kagit.add_child(notu)
	_satirlar.append(notu)

	var damga := Control.new()
	damga.position = Vector2(KAGIT.x - 190.0, KAGIT.y - 150.0)
	damga.size = Vector2(150, 60)
	damga.mouse_filter = MOUSE_FILTER_IGNORE
	damga.draw.connect(func() -> void:
		var renk := Color(Stil.BORDO, 0.82)
		damga.draw_set_transform(damga.size / 2.0, deg_to_rad(-9.0), Vector2.ONE)
		damga.draw_rect(Rect2(-70, -24, 140, 48), renk, false, 2.6)
		damga.draw_rect(Rect2(-66, -20, 132, 40), renk, false, 1.0)
		damga.draw_string(Stil.daktilo_kalin(), Vector2(-70, -2), "GÖRÜLMÜŞTÜR", HORIZONTAL_ALIGNMENT_CENTER, 140, 15, renk)
		damga.draw_string(Stil.daktilo_kalin(), Vector2(-70, 14), "Müdür", HORIZONTAL_ALIGNMENT_CENTER, 140, 11, renk)
		damga.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE))
	kagit.add_child(damga)
	_satirlar.append(damga)

	var bitecek := not Oyun.son_denetle().is_empty()
	var eve := Button.new()
	eve.name = "EveGit"
	eve.text = "Müdür Çağırıyor" if bitecek else "Eve Git"
	eve.focus_mode = FOCUS_NONE
	eve.custom_minimum_size = Vector2(200, 46)
	eve.position = Vector2((KAGIT.x - 200.0) / 2.0, KAGIT.y - 74.0)
	eve.pressed.connect(_devam)
	kagit.add_child(eve)
	_satirlar.append(eve)

	# satırlar daktilodan çıkar gibi sırayla belirir
	for i in _satirlar.size():
		var s := _satirlar[i]
		s.modulate.a = 0.0
		var t := create_tween()
		t.tween_interval(0.35 + i * SATIR_ARASI)
		if s == damga:
			t.tween_callback(Ses.cal.bind("muhur", 1.0, -2.0))
		elif not s is Button:
			t.tween_callback(Ses.cal.bind("daktilo", 1.0, -9.0, 0.1))
		t.tween_property(s, "modulate:a", 1.0, 0.06)


func _devam() -> void:
	var sonuc := Oyun.son_denetle()
	if sonuc.is_empty():
		Oyun.sahneye_gec("aile")
	else:
		Oyun.oyunu_bitir(sonuc)


func _mudur_notu(o: Dictionary) -> String:
	var ihtar := int(o.get("ihtar", 0))
	var dogru := int(o.get("dogru", 0))
	if ihtar >= Oyun.IHTAR_ESIGI:
		return "Müdürün notu: %d ihtar. Kesintiyi yaptım; canı yanan memurun gözü açılır." % ihtar
	if ihtar == 0 and dogru >= 6:
		return "Müdürün notu: Bugün gişenizden şikâyet gelmedi. Buna alışabilirim."
	if dogru <= 2:
		return "Müdürün notu: Gişede çay demlenmez, vatandaşın işi görülür. Yarın daha çok işlem bekliyorum."
	if ihtar == 0:
		return "Müdürün notu: Hatasız, ama ağır. Kuyruk kapıya kadar uzadı."
	return "Müdürün notu: İdare eder. Yarın genelgeyi iki kere okuyun."


func _baslik(kagit: Control, metin: String, y: float, punto: int, renk: Color, font: Font) -> void:
	var l := Stil.etiket(metin, punto, renk, font)
	l.position = Vector2(0, y)
	l.size = Vector2(KAGIT.x, punto + 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kagit.add_child(l)
	_satirlar.append(l)


## "Etiket ............ değer" biçiminde noktalı satır.
func _satir(kagit: Control, etiket: String, deger: String, x: float, y: float, renk: Color = Stil.MUREKKEP,
		kalin: bool = false) -> float:
	var nokta := maxi(2, SATIR_HARFI - etiket.length() - deger.length() - 2)
	var l := Stil.etiket("%s %s %s" % [etiket, ".".repeat(nokta), deger], 15, renk,
		Stil.daktilo_kalin() if kalin else Stil.daktilo())
	l.position = Vector2(x, y)
	kagit.add_child(l)
	_satirlar.append(l)
	return y + 27.0


func _cizgi(kagit: Control, x: float, y: float) -> float:
	var c := ColorRect.new()
	c.color = Color(Stil.MUREKKEP, 0.75)
	c.position = Vector2(x, y + 2.0)
	c.size = Vector2(KAGIT.x - 2.0 * x, 1.5)
	c.mouse_filter = MOUSE_FILTER_IGNORE
	kagit.add_child(c)
	_satirlar.append(c)
	return y + 12.0
