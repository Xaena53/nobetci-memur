extends Belge
## Bilgi defteri: emniyetin gönderdiği başvuru kitabı. Masada kapalı durur; çift tıklanınca ele alınır ve
## açılır. İçinde gerçek mühür, imza ve kaşe örnekleri ile sık görülen sahtecilikler vardır; çalışma vizesi
## kuralı yürürlüğe girince vize sayfası da eklenir.
##
## Defter cevap vermez, yalnızca gösterir: belgedeki mührü örnekle karşılaştırmak memurun işidir. İnceleme
## modunda örnekler tıklanabilir hedeflerdir ("ornek"); ipucu veren kiplerde belgeyle karşılaştırılabilirler.
##
## veri: {tur: "bilgi_defteri", gun: günün verisi}

const KAPAK := "res://assets/img/nesne/defter_kapak.webp"
const KAPALI := Vector2(104, 154)
const ACIK := Vector2(452, 300)
const SOL := 16.0            ## sol sayfanın yazı başlangıcı
const SAG := 238.0           ## sağ sayfanın yazı başlangıcı
const EN := 198.0            ## bir sayfanın yazı eni
const BASLIK := Color("3d2a1c")

var yaprak := 0              ## açık olan çift sayfa
var _acik := false
var _inceleme := false
var _kapak: Texture2D
var _imzalar: Array[Dictionary] = []    ## bu yaprakta çizilecek imzalar: {alan: Rect2, kisi}


## O günün kurallarına göre defterdeki yapraklar: [kod, sekme adı]
func yapraklar() -> Array:
	var gun: Dictionary = veri.get("gun", {})
	var liste := [["muhur", "MÜHÜR"], ["imza", "İMZA"], ["kase", "KAŞE"]]
	if not Veri.kural(gun, "vize").is_empty():
		liste.append(["vize", "VİZE"])
	return liste


func _kur() -> void:
	_imzalar.clear()
	if _kapak == null and ResourceLoader.exists(KAPAK):
		_kapak = load(KAPAK)
	if not _acik:
		_taban = KAPALI      # kapak, yazısıyla birlikte boyalı görseldir
		return
	_taban = ACIK
	var liste := yapraklar()
	yaprak = clampi(yaprak, 0, liste.size() - 1)
	# sekmeler (sayfanın üst kenarında)
	var x := SOL
	for i in liste.size():
		var d := Button.new()
		d.name = "DefterSekme_" + str(liste[i][0])
		d.text = str(liste[i][1])
		d.toggle_mode = true
		d.button_pressed = i == yaprak
		d.focus_mode = FOCUS_NONE
		d.mouse_default_cursor_shape = CURSOR_POINTING_HAND
		d.add_theme_font_override("font", Stil.daktilo_kalin())
		d.add_theme_color_override("font_color", Stil.MUREKKEP)
		d.add_theme_color_override("font_pressed_color", Stil.BORDO)
		d.add_theme_color_override("font_hover_color", Stil.BORDO)
		d.add_theme_color_override("font_hover_pressed_color", Stil.BORDO)
		d.add_theme_stylebox_override("normal", Stil.kutu(Stil.KAGIT_ESKI, Color(0.4, 0.35, 0.28), 1, 2))
		d.add_theme_stylebox_override("hover", Stil.kutu(Stil.KAGIT, Stil.BORDO, 1, 2))
		d.add_theme_stylebox_override("pressed", Stil.kutu(Stil.KAGIT, Stil.BORDO, 2, 2))
		d.add_theme_stylebox_override("hover_pressed", Stil.kutu(Stil.KAGIT, Stil.BORDO, 2, 2))
		d.pressed.connect(yapraga_gec.bind(i))
		add_child(d)
		_ogeler.append({"d": d, "r": Rect2(x, 9, 44, 15), "p": 7.5})
		x += 47.0
	_yazi("%d / %d" % [yaprak + 1, liste.size()], Rect2(SAG, 11, EN, 12), 7.5, Stil.MUREKKEP_SOLUK, Stil.daktilo(), HORIZONTAL_ALIGNMENT_RIGHT)
	match str(liste[yaprak][0]):
		"muhur":
			_muhur_yapragi()
		"imza":
			_imza_yapragi()
		"kase":
			_kase_yapragi()
		"vize":
			_vize_yapragi()


## Başka bir çift sayfaya geçer.
func yapraga_gec(no: int) -> void:
	if no == yaprak and get_child_count() > 0:
		# aynı sekmeye basıldı: düğme basılı kalsın
		for c in get_children():
			if c is Button and str(c.name).begins_with("DefterSekme_"):
				(c as Button).set_pressed_no_signal(str(c.name) == "DefterSekme_" + str(yapraklar()[yaprak][0]))
		return
	yaprak = no
	Ses.cal("sayfa", 1.0, -4.0, 0.06)
	doldur(veri)
	inceleme_ac(_inceleme)


func inceleme_ac(acik: bool) -> void:
	_inceleme = acik
	super.inceleme_ac(acik)


## Çift tıklayınca defter ele alınır ve açılır; yeniden çift tıklayınca kapanıp masaya döner.
func buyut(b: bool) -> void:
	if b == buyuk or tutucu == null:
		return
	_acik = b
	doldur(veri)
	inceleme_ac(_inceleme)
	super.buyut(b)
	if b:
		Ses.cal("sayfa", 0.85, -3.0, 0.05)


# --- Yapraklar ---

func _muhur_yapragi() -> void:
	_baslik(SOL, "MUHTARLIK MÜHRÜ", "Gerçek mührün özellikleri")
	_oge(_ornek_damga("muhtar", ""), Rect2(SOL + 2, 56, 98, 98))
	_ornek_hedefi("muhur", "Mühür örneği", Rect2(SOL, 54, 102, 102))
	_yazi("· Çift dış halka\n· İç halka\n· Üstte MAHALLE\n  MUHTARLIĞI\n· Altta ARDIÇLI\n· Yıldız ve T.C.\n· Mor mürekkep",
		Rect2(SOL + 106, 58, 94, 100), 7.6, Stil.MUREKKEP, Stil.daktilo(), HORIZONTAL_ALIGNMENT_LEFT, true)
	_yazi("Mühür bütün mahallelerde aynıdır; muhtarı imzasından tanırsınız. Mühür belgeye hafif yamuk ya da silik "
		+ "basılmış olabilir; bunlar sahtelik sayılmaz.", Rect2(SOL, 166, EN, 60), 7.6, Stil.MUREKKEP_SOLUK, Stil.daktilo_italik(),
		HORIZONTAL_ALIGNMENT_LEFT, true)
	_yazi("Örneğe uymayan mühür sahtedir: evrak müdüre havale edilir.", Rect2(SOL, 236, EN, 30), 8, Stil.BORDO,
		Stil.daktilo_kalin(), HORIZONTAL_ALIGNMENT_LEFT, true)

	_baslik(SAG, "SAHTE ÖRNEKLERİ", "Emniyetin ele geçirdiği mühürlerden")
	_sahte_izgara("muhtar", SAG, 56, 3, Vector2(62, 62), Vector2(68, 94))


func _imza_yapragi() -> void:
	_baslik(SOL, "İMZA SİRKÜLERİ", "Mahalle muhtarlarının tatbik imzaları")
	_baslik(SAG, "İMZA SİRKÜLERİ", "(devam)")
	var muhtarlar: Array = Veri.adlar().get("mahalleler", [])
	for i in mini(muhtarlar.size(), 10):
		var m: Dictionary = muhtarlar[i]
		var x := SOL if i < 5 else SAG
		var y := 52.0 + (i % 5) * 47.0
		_yazi(str(m.muhtar), Rect2(x, y + 6, 86, 12), 8.4, Stil.MUREKKEP, Stil.daktilo_kalin())
		_yazi("%s Mah." % str(m.ad), Rect2(x, y + 18, 86, 11), 7.4, Stil.MUREKKEP_SOLUK, Stil.daktilo_italik())
		var alan := Rect2(x + 86, y, 110, 42)
		_imzalar.append({"alan": alan, "kisi": str(m.muhtar)})
		_ornek_hedefi("imza:" + str(m.muhtar), "İmza örneği", alan.grow(1.0))


func _kase_yapragi() -> void:
	_baslik(SOL, "VEZNE KAŞESİ", "Harç makbuzundaki tahsil kaşesi")
	_oge(_ornek_damga("vezne", ""), Rect2(SOL + 38, 53, 122, 53))
	_ornek_hedefi("kase_vezne", "Vezne kaşesi örneği", Rect2(SOL + 34, 51, 130, 57))
	_yazi("· Tek çerçeve, mor mürekkep\n· Üstte TAHSİL EDİLMİŞTİR\n· Altta ARDIÇLI MALMÜDÜRLÜĞÜ", Rect2(SOL, 112, EN, 40), 7.6,
		Stil.MUREKKEP, Stil.daktilo(), HORIZONTAL_ALIGNMENT_LEFT, true)
	_yazi("Sahte örnekleri", Rect2(SOL, 152, EN, 12), 8.2, Stil.BORDO, Stil.daktilo_kalin())
	_sahte_izgara("vezne", SOL, 166, 2, Vector2(92, 40), Vector2(101, 60))

	if Veri.kural(veri.get("gun", {}), "vize").is_empty():
		_baslik(SAG, "NASIL BAKILIR", "Sahte evrak ayrıntıda belli olur")
		_yazi("1. Belgeyi çift tıklayıp elinize alın; yazılar büyür.\n\n2. Mührü ve kaşeyi örnekle yan yana getirin: "
			+ "halka sayısı, yazı, mürekkep rengi, yıldız.\n\n3. İmzayı sirkülerdeki imzayla karşılaştırın: baş harfler, "
			+ "eğim, alttaki çizgi.\n\n4. Sahte evrak geri çevrilmez; müdüre havale edilir.",
			Rect2(SAG, 54, EN, 220), 7.8, Stil.MUREKKEP, Stil.daktilo(), HORIZONTAL_ALIGNMENT_LEFT, true)
		return
	_baslik(SAG, "KONSOLOSLUK KAŞESİ", "Çalışma vizesindeki kaşe")
	_oge(_ornek_damga("vize", ""), Rect2(SAG, 52, 84, 84))
	_ornek_hedefi("kase_vize", "Konsolosluk kaşesi örneği", Rect2(SAG - 2, 50, 88, 88))
	_yazi("· Kırmızı mürekkep\n· Çift dış halka\n· İç halka\n· Üstte KONSOLOSLUK\n  ÇALIŞMA ŞUBESİ\n· Altta ANKARA\n· Ortada VİZE",
		Rect2(SAG + 90, 54, 110, 90), 7.4, Stil.MUREKKEP, Stil.daktilo(), HORIZONTAL_ALIGNMENT_LEFT, true)
	_yazi("Sahte örnekleri", Rect2(SAG, 142, EN, 12), 8.2, Stil.BORDO, Stil.daktilo_kalin())
	_sahte_izgara("vize", SAG, 156, 3, Vector2(50, 50), Vector2(68, 68))


func _vize_yapragi() -> void:
	var gun: Dictionary = veri.get("gun", {})
	var b: Dictionary = Veri.kural(gun, "vize").get("no", {})
	_baslik(SOL, "ÇALIŞMA VİZESİ", "Yurt dışı çıkış kaydında aranır")
	var ilk := "%s-%02d-%05d" % [str(b.get("onek", "ÇV")), int(b.get("yil", 84)), int(b.get("min", 2000))]
	var son := "%s-%02d-%05d" % [str(b.get("onek", "ÇV")), int(b.get("yil", 84)), int(b.get("max", 6999))]
	_yazi("1. Vize numarası:", Rect2(SOL, 54, EN, 12), 8, Stil.MUREKKEP, Stil.daktilo_kalin())
	_yazi("%s  —  %s" % [ilk, son], Rect2(SOL + 8, 67, EN - 8, 14), 8.6, Stil.BORDO, Stil.daktilo_kalin())
	_ornek_hedefi("vize_no", "Geçerli vize numaraları", Rect2(SOL, 52, EN, 31))
	_yazi("2. Son geçerlilik günü geçmemiş olmalıdır.\n\n3. Cüzdan seri numarası ve doğum tarihi, cüzdandakiyle harfi "
		+ "harfine aynıdır.\n\n4. Hamilin imzası, cüzdandaki imzayla aynı elden çıkmıştır.\n\n5. Konsolosluk kaşesi "
		+ "KAŞE sayfasındaki örneğe uyar.", Rect2(SOL, 88, EN, 130), 7.8, Stil.MUREKKEP, Stil.daktilo(),
		HORIZONTAL_ALIGNMENT_LEFT, true)
	_yazi("6. Vize memurunun imzası:", Rect2(SOL, 222, EN, 12), 7.8, Stil.MUREKKEP, Stil.daktilo())
	_imzalar.append({"alan": Rect2(SOL + 60, 234, 110, 40), "kisi": "vize_memuru", "renk": Color(0.10, 0.10, 0.12, 0.9)})

	_baslik(SAG, "SIK GÖRÜLEN SAHTECİLİKLER", "Emniyetin tespitleri")
	_yazi("· Geçen yılın numarası: %s-%02d-…\n\n· Henüz verilmemiş numara: %05d ve üstü\n\n· Önek harfleri yanlış: CV, ÇY, ÇW\n\n"
		% [str(b.get("onek", "ÇV")), int(b.get("yil", 84)) - 1, int(b.get("max", 6999)) + 1]
		+ "· Kaşe mor, oval ya da tek halkalı\n\n· Seri numarasında ya da doğum tarihinde tek rakam farkı\n\n"
		+ "· Hamilin imzası başkasının eli", Rect2(SAG, 54, EN, 170), 7.8, Stil.MUREKKEP, Stil.daktilo(),
		HORIZONTAL_ALIGNMENT_LEFT, true)
	_yazi("Sahte vizeyi taşıyan çoğu zaman kandırılmıştır: tarlasını satmış, borca girmiştir. Vize yine de sahtedir; "
		+ "evrak müdüre havale edilir.", Rect2(SAG, 228, EN, 50), 7.6, Stil.MUREKKEP_SOLUK, Stil.daktilo_italik(),
		HORIZONTAL_ALIGNMENT_LEFT, true)


# --- Yardımcılar ---

func _baslik(x: float, baslik: String, alt: String) -> void:
	_yazi(baslik, Rect2(x, 28, EN, 14), 9.6, BASLIK, Stil.serif_kalin())
	_yazi(alt, Rect2(x, 40, EN, 11), 7.2, Stil.MUREKKEP_SOLUK, Stil.serif_italik())


func _ornek_damga(cesit: String, sahte: String) -> Damga:
	var d := Damga.olustur(cesit, sahte, 3 if sahte == "" else hash(sahte))
	d.egik = false
	return d


## Bir sahtecilik türleri ızgarası: her hücrede sahte damga ve altında ne olduğu.
func _sahte_izgara(cesit: String, x0: float, y0: float, sutun: int, boyut: Vector2, adim: Vector2) -> void:
	var liste: Array = Damga.SAHTELER.get(cesit, [])
	var adet := mini(liste.size(), sutun * 2)
	for i in adet:
		var hucre := Vector2(x0 + (i % sutun) * adim.x, y0 + floorf(float(i) / sutun) * adim.y)
		_oge(_ornek_damga(cesit, str(liste[i][0])), Rect2(hucre + Vector2((adim.x - boyut.x) / 2.0 - 2.0, 0), boyut))
		_yazi(str(liste[i][1]), Rect2(hucre.x - 2, hucre.y + boyut.y + 1, adim.x, 20), 6.8, Stil.BORDO, Stil.daktilo(),
			HORIZONTAL_ALIGNMENT_CENTER, true)
	if liste.size() > adet:
		_yazi(str(liste[adet][1]) + " da sahtedir.", Rect2(x0, y0 + 2.0 * adim.y + 2.0, EN, 12), 7.2, Stil.BORDO, Stil.daktilo_italik())


## İnceleme modunda tıklanabilen örnek (belgedeki karşılığıyla karşılaştırılır).
func _ornek_hedefi(anahtar: String, etiket: String, alan: Rect2) -> void:
	var h := _hedef(anahtar, etiket, anahtar, alan)
	h.tip = "ornek"


func _draw() -> void:
	if not _acik:
		_kapagi_ciz()
		return
	var havada := _surukleniyor or buyuk
	# cilt: sayfaların arkasından taşan bez kapak
	var cilt := StyleBoxFlat.new()
	cilt.bg_color = Color("3f5063")
	cilt.set_corner_radius_all(roundi(5.0 * _k))
	cilt.shadow_color = Color(0, 0, 0, 0.38)
	cilt.shadow_size = roundi((12.0 if havada else 5.0) * _k)
	cilt.shadow_offset = Vector2(4, 6) * _k
	draw_style_box(cilt, Rect2(Vector2.ZERO, size))
	# iki sayfa
	Kagit.ciz(self, _r(5, 4, 221, 292), "sayfa", Stil.KAGIT_BEYAZ, 0.0, 0.0)
	Kagit.ciz(self, _r(226, 4, 221, 292), "sayfa", Stil.KAGIT_BEYAZ, 0.0, 0.0, Color(0.985, 0.975, 0.95))
	# sırt: ortadaki kıvrımın gölgesi
	for i in 9:
		var a := 0.20 * (1.0 - i / 9.0)
		draw_rect(_r(226.0 - i * 1.6, 4, 1.6, 292), Color(0.2, 0.15, 0.1, a))
		draw_rect(_r(226.0 + i * 1.6, 4, 1.6, 292), Color(0.2, 0.15, 0.1, a * 0.8))
	draw_line(_v(SOL, 52), _v(SOL + EN, 52), Color(Stil.MUREKKEP, 0.35), maxf(1.0, 0.8 * _k))
	draw_line(_v(SAG, 52), _v(SAG + EN, 52), Color(Stil.MUREKKEP, 0.35), maxf(1.0, 0.8 * _k))
	for im in _imzalar:
		var alan: Rect2 = im.alan
		_noktali(alan.position.x, alan.end.x, alan.end.y - 2.0, Color(0, 0, 0, 0.22))
		_imza_ciz(alan, 1, im.get("renk", Color(Stil.MAVI_MUREKKEP, 0.95)), str(im.kisi))


func _kapagi_ciz() -> void:
	var g := StyleBoxFlat.new()
	g.bg_color = Color(0, 0, 0, 0)
	g.draw_center = false
	g.shadow_color = Color(0, 0, 0, 0.36)
	g.shadow_size = roundi(5.0 * _k)
	g.shadow_offset = Vector2(3, 5) * _k
	draw_style_box(g, Rect2(Vector2.ZERO, size).grow(-4.0 * _k))
	if _kapak != null:
		draw_texture_rect(_kapak, Rect2(Vector2.ZERO, size), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color("3f5063"))
