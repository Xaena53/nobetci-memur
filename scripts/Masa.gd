extends Control
## Masa — mesai sahnesi. Gişe camı, masadaki belgeler, genelge defteri ve karar araçları.
##
## Akış: vatandaş cama gelir → belgeleri yarıktan masaya kayar → oyuncu inceler ve bir araç
## (mühür / eksik evrak fişi / havale pusulası) bırakarak karar verir → Dogrulayici kararı
## değerlendirir → doğruysa prim yazılır, yanlışsa müdürün ihtarı teleksten satır satır çıkar.

const ARKA_PLAN := "res://assets/img/masa_arkaplan.webp"
const BUYUTEC := "res://assets/img/nesne/buyutec.webp"
const IGNE := "res://assets/img/nesne/igne.webp"
const MESAI_BASI := 9 * 60     ## 09:00 (dakika)
const MESAI_SONU := 17 * 60    ## 17:00
const KARAR_ADLARI := {"onay": "ONAY", "eksik": "EKSİK EVRAK", "havale": "MÜDÜRE HAVALE"}

var gun: Dictionary = {}                ## günün genelgesi ve kuralları (data/gunler)
var dakika := float(MESAI_BASI)
var mesai_acik := false                 ## sabah genelgesi okunup gişe açılınca true olur
var gun_bitti := false
var vatandas: Dictionary = {}           ## şu an camdaki vatandaş (yoksa boş)
var belgeler: Array[Belge] = []
var kuyruk: Array[Dictionary] = []      ## sırada bekleyenler
var kararlar: Array[Dictionary] = []    ## günün karar dökümü
var tespitler: Array[String] = []       ## incelemede yakalanan gerekçeler (camdaki vatandaş için)
var ozet: Dictionary = {}               ## günün sayaçları (Gün Sonu ekranına gider)
var havale_kalan := 2
var gunluk_ihtar := 0

var gise: Gise
var balon: KonusmaBalonu
var saat: DuvarSaati
var kural_kitabi: KuralKitabi
var inceleme: IncelemeKatmani
var teleks: Teleks
var araclar: Dictionary = {}            ## tür -> Arac

var _tepsi_katmani: Node2D
var _belge_katmani: Node2D
var _fis_katmani: Node2D
var _arac_katmani: Node2D
var _ust_katman: Control
var _incele_dugmesi: Button
var _incele_seridi: Label
var _ihtar_seridi: Label
var _igne: Control
var _igne_dokusu: Texture2D             ## çizim komutu dokuyu tutmaz; başvuru burada yaşamalı
var _bekleyen_fis: Dictionary = {}
var _mesgul := true                     ## vatandaş gelip giderken karar verilemez


func _ready() -> void:
	gun = Veri.gun(Oyun.gun)
	havale_kalan = int(gun.get("havale_hakki", 2))
	ozet = {"islenen": 0, "dogru": 0, "yanlis": 0, "yarim": 0, "havale": 0, "yarida": 0, "kazanc": 0, "ihtar": 0,
		"ihtarlar": []}
	_sahneyi_kur()
	inceleme.karsilastir = _karsilastir
	kural_kitabi.yukle(gun)
	saat.tarih_ayarla(str(gun.get("tarih", "")))
	saat.dakika = dakika
	_kuyrugu_kur()
	_araclari_ayarla()
	_genelgeyi_goster()


func _process(delta: float) -> void:
	if not mesai_acik:
		return
	# Ayarlardaki saat hızı: bir oyun dakikasının kaç gerçek saniye sürdüğü.
	dakika += delta / maxf(0.05, float(Oyun.ayar("saat_hizi")))
	if dakika >= MESAI_SONU:
		dakika = MESAI_SONU
		mesaiyi_bitir()
	saat.dakika = dakika


## Gün, müdürün genelgesiyle başlar; "Gişeyi Aç" denince saat işlemeye ve vatandaş gelmeye başlar.
func _genelgeyi_goster() -> void:
	var g := GenelgeEkrani.new()
	g.name = "GenelgeEkrani"
	_ust_katman.add_child(g)
	g.ac(gun, Oyun.gun)
	g.kapandi.connect(giseyi_ac)


func giseyi_ac() -> void:
	if mesai_acik or gun_bitti:
		return
	mesai_acik = true
	get_tree().create_timer(0.8).timeout.connect(_sonraki_vatandas)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		inceleme.aktif = not inceleme.aktif
		get_viewport().set_input_as_handled()


# --- Vatandaş akışı ---

func _kuyrugu_kur() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = Oyun.gun_tohumu()
	for i in int(gun.get("vatandas_sayisi", 8)):
		kuyruk.append(VatandasUretici.uret(gun, rng, Oyun.gorulen_portreler))


func _sonraki_vatandas() -> void:
	if not mesai_acik:
		return
	if kuyruk.is_empty():
		balon.sus()
		get_tree().create_timer(1.0).timeout.connect(mesaiyi_bitir)
		return
	vatandas = kuyruk.pop_front()
	tespitler.clear()
	gise.gelsin(str(vatandas.portre))
	await get_tree().create_timer(Gise.GELIS_SURESI + 0.1).timeout
	if not mesai_acik:
		return
	balon.soyle(str(vatandas.konusma.giris))
	_belgeleri_getir()
	_mesgul = false
	_araclari_ayarla()


func _belgeleri_getir() -> void:
	var i := 0
	for v: Dictionary in vatandas.belgeler:
		var b := Belge.olustur(v)
		if b == null:
			continue
		b.masaya_koy(_belge_katmani)
		b.hedef_tiklandi.connect(inceleme.hedef_tiklandi)
		b.inceleme_ac(inceleme.aktif)
		var yer: Vector2 = Yerlesim.BELGE_YERI.get(b.tur, Vector2(450, 230))
		yer += Vector2(randf_range(-4, 4), randf_range(-2, 2))
		b.tutucu.yatis_acisi = deg_to_rad(randf_range(-1.0, 1.0))
		b.gel(Yerlesim.GISE_YARIK, yer, 0.15 + i * 0.2)
		belgeler.append(b)
		i += 1


func _vatandasi_ugurla(karar: String) -> void:
	_mesgul = true
	_araclari_ayarla()
	gise.tepki(karar)
	for b in belgeler:
		b.kilitli = true
	await get_tree().create_timer(0.7).timeout
	balon.soyle(str(vatandas.konusma.get(karar, "")), 1.4)
	inceleme.temizle()
	kural_kitabi.isaretleri_temizle()
	var i := 0
	for b in belgeler:
		b.git(Yerlesim.GISE_YARIK, 0.25 + i * 0.12)
		i += 1
	belgeler.clear()
	await get_tree().create_timer(1.0).timeout
	gise.gitsin()
	vatandas = {}
	_fisi_goster()
	await get_tree().create_timer(1.3).timeout
	_sonraki_vatandas()


# --- Kararlar ---

func _arac_birakildi(arac: Arac, konum: Vector2) -> void:
	var b := _konumdaki_belge(konum)
	if b == null or _mesgul or vatandas.is_empty():
		arac.eve_don()
		return
	if arac.tur == "eksik":
		arac.eve_don()
		_gerekce_sor(b, konum)
		return
	karar_ver(arac.tur, b, konum)
	get_tree().create_timer(0.16).timeout.connect(arac.eve_don)


## "Eksik evrak" için gerekçe penceresini açar; seçilince karar verilir.
func _gerekce_sor(belge: Belge, konum: Vector2) -> void:
	_mesgul = true
	_araclari_ayarla()
	var p := GerekcePenceresi.new()
	p.name = "GerekcePenceresi"
	_ust_katman.add_child(p)
	p.ac(Dogrulayici.gunun_gerekceleri(gun), tespitler, konum)
	p.secildi.connect(func(gerekce: String) -> void:
		_mesgul = false
		karar_ver("eksik", belge, konum, gerekce))
	p.vazgecildi.connect(func() -> void:
		_mesgul = false
		_araclari_ayarla())


## Kararı kaydeder, belgeye izini bırakır ve doğruluğunu değerlendirir. `konum` ekran koordinatıdır.
func karar_ver(karar: String, belge: Belge, konum: Vector2, gerekce: String = "") -> void:
	if _mesgul or vatandas.is_empty() or not is_instance_valid(belge):
		return
	_mesgul = true
	var yerel := belge.get_global_transform().affine_inverse() * konum
	match karar:
		"onay":
			belge.iz_birak("onay", yerel, PackedStringArray(["ONAYLANMIŞTIR", "Ardıçlı Nüfus Md.", str(gun.get("tarih", ""))]))
		"eksik":
			belge.iz_birak("eksik", yerel, _fis_satirlari(str(Dogrulayici.GEREKCELER.get(gerekce, "Eksik evrak"))))
		"havale":
			belge.iz_birak("havale", yerel, PackedStringArray(["MÜDÜRE HAVALE", "Müdürlük makamına", "arz olunur."]))
			havale_kalan -= 1
			(araclar["havale"] as Arac).kalan = havale_kalan

	var sonuc := Dogrulayici.kontrol(vatandas, gun)
	var degerlendirme := Dogrulayici.degerlendir(karar, gerekce, sonuc)
	_sonucu_isle(karar, degerlendirme)
	kararlar.append({"karar": karar, "gerekce": gerekce, "sonuc": degerlendirme.sonuc, "dogru_karar": sonuc.karar,
		"vatandas": vatandas})
	_vatandasi_ugurla(karar)


func _sonucu_isle(karar: String, d: Dictionary) -> void:
	ozet.islenen += 1
	if karar == "havale":
		ozet.havale += 1
	match str(d.sonuc):
		"dogru":
			ozet.dogru += 1
			ozet.kazanc += Oyun.PRIM
			if bool(d.get("supheli_yakalandi", false)):
				ozet.kazanc += Oyun.SUPHELI_PRIMI
				_bekleyen_fis = {"cesit": "not", "metin": "Şüpheniz yerindeymiş; evrak sahte çıktı. Dikkatiniz sicilinize işlendi."}
		"yanlis":
			ozet.yanlis += 1
			gunluk_ihtar += 1
			ozet.ihtar = gunluk_ihtar
			(ozet.ihtarlar as Array).append(str(d.mesaj))
			_bekleyen_fis = {"cesit": "ihtar", "metin": str(d.mesaj)}
		"yarim":
			ozet.yarim += 1
			_bekleyen_fis = {"cesit": "uyari", "metin": str(d.mesaj)}
		_:
			if str(d.get("mesaj", "")) != "":
				_bekleyen_fis = {"cesit": "not", "metin": str(d.mesaj)}


## Bekleyen pusulayı (ihtar / uyarı / not) teleksten bastırır.
func _fisi_goster() -> void:
	if _bekleyen_fis.is_empty():
		return
	teleks.yazdir(str(_bekleyen_fis.metin), gunluk_ihtar, str(_bekleyen_fis.cesit))
	_bekleyen_fis = {}


func _fis_satirlari(gerekce: String) -> PackedStringArray:
	# gerekçeyi fişe sığacak kısa satırlara böl
	var satirlar := PackedStringArray(["EKSİK EVRAK"])
	var satir := ""
	for k in gerekce.split(" "):
		if (satir + " " + k).strip_edges().length() > 22 and satir != "":
			satirlar.append(satir)
			satir = k
		else:
			satir = (satir + " " + k).strip_edges()
	if satir != "":
		satirlar.append(satir)
	return satirlar


func _konumdaki_belge(konum: Vector2) -> Belge:
	for i in range(_belge_katmani.get_child_count() - 1, -1, -1):
		var t := _belge_katmani.get_child(i) as MasaNesnesi
		if t == null:
			continue
		var b := t.icerik() as Belge
		if b == null or b.kilitli:
			continue
		var yerel := b.get_global_transform().affine_inverse() * konum
		if Rect2(Vector2.ZERO, b.size).has_point(yerel):
			return b
	return null


func _araclari_ayarla() -> void:
	var acik := mesai_acik and not _mesgul and not vatandas.is_empty()
	for a: Arac in araclar.values():
		a.etkin = acik and a.kalan != 0


## Mesai biter (saat 17:00 oldu ya da kuyruk tükendi): gişe kapanır, camdaki vatandaş yarıda kalır.
func mesaiyi_bitir() -> void:
	if gun_bitti:
		return
	gun_bitti = true
	mesai_acik = false
	_mesgul = true
	_araclari_ayarla()
	inceleme.aktif = false
	inceleme.temizle()
	if not vatandas.is_empty():
		ozet.yarida += 1
		balon.soyle("Saat beş mi oldu? Ama daha işim bitmemişti!", 1.6)
		gise.tepki("eksik")
		var i := 0
		for b in belgeler:
			b.git(Yerlesim.GISE_YARIK, 0.3 + i * 0.12)
			i += 1
		belgeler.clear()
		vatandas = {}
		await get_tree().create_timer(1.3).timeout
		gise.gitsin()
	gise.kepengi_indir()
	await get_tree().create_timer(1.9).timeout
	ozet.ihtar = gunluk_ihtar
	Oyun.mesaiyi_kapat(ozet)
	Oyun.sahneye_gec("gun_sonu")


# --- İnceleme modu ---

func _karsilastir(a: Hedef, b: Hedef) -> Dictionary:
	return Dogrulayici.karsilastir(a.ozet(), b.ozet(), vatandas, gun)


func _bulgu(sonuc: Dictionary) -> void:
	var gerekce := str(sonuc.get("gerekce", ""))
	if str(sonuc.get("durum", "")) == "uyusmaz" and gerekce != "" and not tespitler.has(gerekce):
		tespitler.append(gerekce)


func _inceleme_degisti(acik: bool) -> void:
	for b in belgeler:
		b.inceleme_ac(acik)
	kural_kitabi.inceleme_ac(acik)
	gise.yuz.aktif = acik
	saat.takvim.aktif = acik
	_incele_dugmesi.set_pressed_no_signal(acik)
	_incele_dugmesi.modulate = Color(1.25, 1.2, 1.05) if acik else Color.WHITE
	_incele_seridi.text = "İNCELEME AÇIK" if acik else "İNCELE [BOŞLUK]"
	_incele_seridi.add_theme_color_override("font_color", Color("ffd9a0") if acik else Stil.KAGIT_BEYAZ)


# --- Sahne kurulumu ---

func _sahneyi_kur() -> void:
	if ResourceLoader.exists(ARKA_PLAN):
		var zemin := TextureRect.new()
		zemin.name = "ArkaPlan"
		zemin.texture = load(ARKA_PLAN)
		zemin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		zemin.stretch_mode = TextureRect.STRETCH_SCALE
		zemin.size = Yerlesim.EKRAN.size
		zemin.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(zemin)
	else:
		var duz := ColorRect.new()
		duz.color = Stil.MASA
		duz.size = Yerlesim.EKRAN.size
		duz.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(duz)

	gise = Gise.new()
	gise.name = "Gise"
	add_child(gise)

	saat = DuvarSaati.new()
	saat.name = "DuvarSaati"
	add_child(saat)

	_mudur_bolmesini_kur()

	balon = KonusmaBalonu.new()
	balon.name = "Balon"
	add_child(balon)
	balon.basladi.connect(gise.konus.bind(true))
	balon.bitti.connect(gise.konus.bind(false))

	kural_kitabi = KuralKitabi.new()
	kural_kitabi.name = "KuralKitabi"
	kural_kitabi.position = Yerlesim.PANO.position
	kural_kitabi.size = Yerlesim.PANO.size
	add_child(kural_kitabi)

	_tepsi_katmani = _katman("Tepsi")
	_belge_katmani = _katman("Belgeler")
	_fis_katmani = _katman("Fisler")
	teleks = Teleks.new()
	teleks.name = "Teleks"
	add_child(teleks)
	_arac_katmani = _katman("Araclar")
	_tepsiyi_kur()
	teleks.kur(_fis_katmani, Perspektif.ekrana(Yerlesim.IGNE_YERI) + Vector2(0, -30))
	teleks.fis_koptu.connect(func(_f: IhtarFisi) -> void: _igneyi_guncelle())
	var yerler := {"onay": Yerlesim.MUHUR_YERI, "eksik": Yerlesim.EKSIK_YERI, "havale": Yerlesim.HAVALE_YERI}
	for tur: String in yerler:
		var a := Arac.new()
		a.kur(tur, yerler[tur], _arac_katmani)
		a.birakildi.connect(_arac_birakildi)
		araclar[tur] = a
	(araclar["havale"] as Arac).kalan = havale_kalan

	inceleme = IncelemeKatmani.new()
	inceleme.name = "Inceleme"
	add_child(inceleme)
	inceleme.mod_degisti.connect(_inceleme_degisti)
	inceleme.bulgu.connect(_bulgu)
	gise.hedef_tiklandi.connect(inceleme.hedef_tiklandi)
	saat.hedef_tiklandi.connect(inceleme.hedef_tiklandi)
	kural_kitabi.hedef_tiklandi.connect(inceleme.hedef_tiklandi)

	_ust_katman = Control.new()
	_ust_katman.name = "UstKatman"
	_ust_katman.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_ust_katman.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_ust_katman)


func _katman(ad: String) -> Node2D:
	var k := Node2D.new()
	k.name = ad
	add_child(k)
	return k


## Müdür odasının camlı bölmesi: plaket yazısı ve inik jaluzi.
func _mudur_bolmesini_kur() -> void:
	var p := Yerlesim.MUDUR_PLAKET
	var yazi := Stil.etiket("MÜDÜR", 12, Color("3a2a14"), Stil.serif_kalin())
	yazi.position = p.position
	yazi.size = p.size
	yazi.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	yazi.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(yazi)

	var jaluzi := Control.new()
	jaluzi.name = "Jaluzi"
	jaluzi.position = Yerlesim.MUDUR_CAMI.position
	jaluzi.size = Yerlesim.MUDUR_CAMI.size
	jaluzi.mouse_filter = MOUSE_FILTER_IGNORE
	jaluzi.draw.connect(func() -> void:
		var y := 0.0
		while y < jaluzi.size.y:
			jaluzi.draw_rect(Rect2(0, y, jaluzi.size.x, 7.0), Color("b9b6a2"))
			jaluzi.draw_rect(Rect2(0, y + 5.5, jaluzi.size.x, 1.5), Color("8f8c7a"))
			jaluzi.draw_rect(Rect2(0, y + 7.0, jaluzi.size.x, 2.0), Color(0.08, 0.10, 0.10, 0.85))
			y += 9.0
		for x: float in [jaluzi.size.x * 0.22, jaluzi.size.x * 0.78]:
			jaluzi.draw_line(Vector2(x, 0), Vector2(x, jaluzi.size.y), Color(0.25, 0.24, 0.20, 0.7), 1.0))
	add_child(jaluzi)


## Araç tepsisi: büyüteç (inceleme modu düğmesi), ihtar iğnesi ve şerit etiketler.
func _tepsiyi_kur() -> void:
	_incele_dugmesi = Button.new()
	_incele_dugmesi.name = "Incele"
	_incele_dugmesi.toggle_mode = true
	_incele_dugmesi.focus_mode = FOCUS_NONE
	_incele_dugmesi.flat = true
	_incele_dugmesi.size = Vector2(124, 78)
	_incele_dugmesi.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	for durum: String in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		_incele_dugmesi.add_theme_stylebox_override(durum, StyleBoxEmpty.new())
	if ResourceLoader.exists(BUYUTEC):
		var resim := TextureRect.new()
		resim.texture = load(BUYUTEC)
		resim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		resim.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		resim.size = Vector2(58, 108)
		resim.position = Vector2(33, -15)
		resim.pivot_offset = resim.size / 2.0
		resim.rotation = deg_to_rad(58.0)
		resim.mouse_filter = MOUSE_FILTER_IGNORE
		_incele_dugmesi.add_child(resim)
	_incele_dugmesi.toggled.connect(func(acik: bool) -> void: inceleme.aktif = acik)
	_masaya_yerlestir(_incele_dugmesi, Yerlesim.BUYUTEC_YERI)
	_incele_seridi = _serit("İNCELE [BOŞLUK]", Yerlesim.BUYUTEC_YERI + Vector2(-8, 58), Color("1d1b19"), 118)

	if ResourceLoader.exists(IGNE):
		_igne_dokusu = load(IGNE)
	_igne = Control.new()
	_igne.name = "Igne"
	_igne.size = Vector2(52, 78)
	_igne.mouse_filter = MOUSE_FILTER_IGNORE
	_igne.draw.connect(_igne_ciz)
	_masaya_yerlestir(_igne, Yerlesim.IGNE_YERI + Vector2(0, -22))
	_ihtar_seridi = _serit("İHTAR 0", Yerlesim.IGNE_YERI + Vector2(8, 30), Stil.BORDO, 64)


## İğne ve ona takılmış günün ihtar pusulaları.
func _igne_ciz() -> void:
	var s := _igne.size
	if _igne_dokusu != null:
		_igne.draw_texture_rect(_igne_dokusu, Rect2(Vector2.ZERO, s), false)
	else:
		_igne.draw_line(Vector2(s.x / 2.0, 4), Vector2(s.x / 2.0, s.y - 12), Color("8f9498"), 2.0)
		_igne.draw_circle(Vector2(s.x / 2.0, s.y - 8), 14, Stil.MASA_KOYU)
	for i in mini(gunluk_ihtar, 6):
		var y := s.y - 30.0 - i * 5.0
		var kayma := 3.0 if i % 2 == 0 else -2.0
		var kose := PackedVector2Array([Vector2(6 + kayma, y), Vector2(s.x - 8 + kayma, y - 3),
			Vector2(s.x - 5 + kayma, y + 5), Vector2(9 + kayma, y + 8)])
		_igne.draw_colored_polygon(kose, Color("f2c4c4"))
		kose.append(kose[0])
		_igne.draw_polyline(kose, Color(Stil.BORDO, 0.7), 1.0, true)


func _igneyi_guncelle() -> void:
	_igne.queue_redraw()
	_ihtar_seridi.text = "İHTAR %d" % gunluk_ihtar


## Bir denetimi (düğme, etiket, gösterge) tepsideki yerine, masa perspektifiyle yerleştirir.
func _masaya_yerlestir(d: Control, yer: Vector2) -> MasaNesnesi:
	var t := MasaNesnesi.new()
	t.name = "Tutucu_" + str(d.name)
	_tepsi_katmani.add_child(t)
	t.add_child(d)
	t.ortala()
	t.masa_konumu = yer
	return t


## Dymo tarzı kabartma şerit etiket (masa düzleminde; `yer` ortasıdır).
func _serit(metin: String, yer: Vector2, zemin: Color, genislik: float = 128.0) -> Label:
	var l := Stil.etiket(metin, 11, Stil.KAGIT_BEYAZ, Stil.daktilo_kalin())
	l.add_theme_stylebox_override("normal", Stil.bosluklu(Stil.kutu(zemin, Color(0, 0, 0, 0.45), 1, 2, 2), 4, 2))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.size = Vector2(genislik, 18)
	_masaya_yerlestir(l, yer)
	return l
