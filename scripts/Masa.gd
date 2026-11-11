extends Control
## Masa — mesai sahnesi. Gişe camı, masadaki belgeler, genelge defteri ve karar araçları.
## (Aşama 1: belge sistemi. Vatandaşlar şimdilik sabit örneklerdir.)

const ARKA_PLAN := "res://assets/img/masa_arkaplan.webp"
const BUYUTEC := "res://assets/img/nesne/buyutec.webp"
const MESAI_BASI := 9 * 60     ## 09:00 (dakika)
const MESAI_SONU := 17 * 60    ## 17:00
const DAKIKA_SURESI := 1.0     ## gerçek 1 sn = oyun 1 dk

const SABIT_GUN := {
	"tarih": "09.01.1984",
	"kurallar": [
		{"id": "ad_soyad", "tur": "alan_esit", "metin": "Ad ve soyad bütün belgelerde aynı olmalıdır."},
		{"id": "ikametgah_sure", "tur": "tarih_sure", "metin": "İkametgâh ilmühaberi son 6 ay içinde alınmış olmalıdır."},
		{"id": "muhur", "tur": "muhur_zorunlu", "metin": "İkametgâhta muhtar mührü bulunmalıdır."},
	],
}

const ORNEK_VATANDASLAR := [
	{
		"portre": "v01",
		"konusma": {"giris": "Hayırlı işler efendim. Nüfus kayıt örneği alacaktım.",
			"onay": "Allah razı olsun.", "eksik": "Yine mi eksik? Peki, tamamlayıp gelirim.",
			"havale": "Müdür Bey'e mi? Peki efendim."},
		"belgeler": [
			{"tur": "nufus_cuzdani", "foto": "v01", "alanlar": {"ad": "MEHMET", "soyad": "YILMAZ",
				"baba_adi": "HASAN", "ana_adi": "EMİNE", "dogum_yeri": "KASTAMONU",
				"dogum_tarihi": "14.03.1939", "seri_no": "A-214503", "cinsiyet": "E"}},
			{"tur": "ikametgah", "alanlar": {"ad": "MEHMET", "soyad": "YILDIZ", "baba_adi": "HASAN",
				"mahalle": "Çarşı Mahallesi", "adres": "Değirmen Sok. No: 14", "tarih": "02.11.1983",
				"muhtar": "Rıza Aksoy", "muhtar_imza": true, "muhtar_muhur": true}},
			{"tur": "harc_makbuzu", "alanlar": {"ad": "MEHMET", "soyad": "YILMAZ", "islem": "kayit_ornegi",
				"tutar": 250, "tarih": "09.01.1984", "makbuz_no": "004512"}},
		],
	},
	{
		"portre": "v02",
		"konusma": {"giris": "Kolay gelsin evladım. Adres naklimi yaptıracaktım.",
			"onay": "Eline sağlık evladım.", "eksik": "Neresi eksikmiş ki? Muhtara sorayım bari.",
			"havale": "Hayırdır inşallah."},
		"belgeler": [
			{"tur": "nufus_cuzdani", "foto": "v02", "alanlar": {"ad": "HATİCE", "soyad": "DEMİRCİ",
				"baba_adi": "İSMAİL", "ana_adi": "ZEHRA", "dogum_yeri": "ÇANKIRI",
				"dogum_tarihi": "02.06.1924", "seri_no": "A-118236", "cinsiyet": "K"}},
			{"tur": "ikametgah", "alanlar": {"ad": "HATİCE", "soyad": "DEMİRCİ", "baba_adi": "İSMAİL",
				"mahalle": "Yukarı Mahalle", "adres": "Çeşme Sok. No: 3", "tarih": "21.12.1983",
				"muhtar": "Kâzım Türkmen", "muhtar_imza": true, "muhtar_muhur": false}},
			{"tur": "harc_makbuzu", "alanlar": {"ad": "HATİCE", "soyad": "DEMİRCİ", "islem": "nakil",
				"tutar": 750, "tarih": "09.01.1984", "makbuz_no": "004519"}},
		],
	},
]

var dakika := float(MESAI_BASI)
var mesai_acik := true
var vatandas: Dictionary = {}
var belgeler: Array[Belge] = []
var kararlar: Array[Dictionary] = []

var gise: Gise
var balon: KonusmaBalonu
var saat: DuvarSaati
var kural_kitabi: KuralKitabi
var inceleme: IncelemeKatmani
var araclar: Dictionary = {}    ## tür -> Arac

var _belge_katmani: Control
var _arac_katmani: Control
var _incele_dugmesi: Button
var _incele_seridi: Label
var _durum: Label
var _sira := 0
var _mesgul := true             ## vatandaş gelip giderken karar verilemez


func _ready() -> void:
	_sahneyi_kur()
	inceleme.karsilastir = _karsilastir
	kural_kitabi.yukle(SABIT_GUN)
	saat.tarih_ayarla(SABIT_GUN.tarih)
	saat.dakika = dakika
	_araclari_ayarla()
	get_tree().create_timer(0.9).timeout.connect(_sonraki_vatandas)


func _process(delta: float) -> void:
	if not mesai_acik:
		return
	dakika += delta / DAKIKA_SURESI
	if dakika >= MESAI_SONU:
		dakika = MESAI_SONU
		mesaiyi_bitir()
	saat.dakika = dakika


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		inceleme.aktif = not inceleme.aktif
		get_viewport().set_input_as_handled()


# --- Vatandaş akışı ---

func _sonraki_vatandas() -> void:
	if not mesai_acik:
		return
	vatandas = (ORNEK_VATANDASLAR[_sira % ORNEK_VATANDASLAR.size()] as Dictionary).duplicate(true)
	_sira += 1
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
		_belge_katmani.add_child(b)
		b.hedef_tiklandi.connect(inceleme.hedef_tiklandi)
		b.inceleme_ac(inceleme.aktif)
		var yer: Vector2 = Yerlesim.BELGE_YERI.get(b.tur, Vector2(300, 400))
		yer += Vector2(randf_range(-8, 8), randf_range(-2, 2))
		b.gel(Yerlesim.GISE_YARIK, yer, 0.15 + i * 0.2)
		belgeler.append(b)
		i += 1


func _vatandasi_ugurla(karar: String) -> void:
	_mesgul = true
	_araclari_ayarla()
	for b in belgeler:
		b.kilitli = true
	await get_tree().create_timer(0.7).timeout
	balon.soyle(str(vatandas.konusma.get(karar, "")), 1.4)
	inceleme.temizle()
	kural_kitabi.isaretleri_temizle()
	var i := 0
	for b in belgeler:
		if b.buyuk:
			b.buyut(false)
		b.git(Yerlesim.GISE_YARIK, 0.25 + i * 0.12)
		i += 1
	belgeler.clear()
	await get_tree().create_timer(1.0).timeout
	gise.gitsin()
	vatandas = {}
	await get_tree().create_timer(1.3).timeout
	_sonraki_vatandas()


# --- Kararlar ---

func _arac_birakildi(arac: Arac, konum: Vector2) -> void:
	var b := _konumdaki_belge(konum)
	if b == null or _mesgul or vatandas.is_empty():
		arac.eve_don()
		return
	karar_ver(arac.tur, b, konum)
	get_tree().create_timer(0.16).timeout.connect(arac.eve_don)


## Kararı kaydeder ve belgeye izini bırakır. `konum` ekran koordinatıdır.
func karar_ver(karar: String, belge: Belge, konum: Vector2) -> void:
	if _mesgul or vatandas.is_empty():
		return
	var yerel := belge.get_global_transform().affine_inverse() * konum
	match karar:
		"onay":
			belge.iz_birak("onay", yerel, PackedStringArray(["ONAYLANMIŞTIR", "Ardıçlı Nüfus Md.", str(SABIT_GUN.tarih)]))
		"eksik":
			belge.iz_birak("eksik", yerel, PackedStringArray(["EKSİK EVRAK", "Tamamlayıp yeniden", "başvurunuz."]))
		"havale":
			belge.iz_birak("havale", yerel, PackedStringArray(["MÜDÜRE HAVALE", "Müdürlük makamına", "arz olunur."]))
	kararlar.append({"karar": karar, "vatandas": vatandas})
	_durum.text = "SON KARAR: %s" % {"onay": "ONAY", "eksik": "EKSİK EVRAK", "havale": "AMİRE HAVALE"}.get(karar, karar)
	_vatandasi_ugurla(karar)


func _konumdaki_belge(konum: Vector2) -> Belge:
	for i in range(_belge_katmani.get_child_count() - 1, -1, -1):
		var b := _belge_katmani.get_child(i) as Belge
		if b != null and not b.kilitli and b.get_global_rect().has_point(konum):
			return b
	return null


func _araclari_ayarla() -> void:
	var acik := mesai_acik and not _mesgul and not vatandas.is_empty()
	for a: Arac in araclar.values():
		a.etkin = acik


func mesaiyi_bitir() -> void:
	if not mesai_acik:
		return
	mesai_acik = false
	var kazanc := 400
	Oyun.para += kazanc
	Oyun.gun_ozeti = {"islenen": kararlar.size(), "dogru": 0, "yanlis": 0, "kazanc": kazanc, "ihtar": 0}
	Oyun.sahneye_gec("gun_sonu")


# --- İnceleme modu ---

## İki hedefi karşılaştırır. (Aşama 1: yalnızca iki farklı belgedeki aynı alan.)
func _karsilastir(a: Hedef, b: Hedef) -> Dictionary:
	if a.tip != "alan" or b.tip != "alan":
		return {"durum": "ilgisiz", "mesaj": "Bu ikisi arasında bir bağ yok."}
	if a.belge_turu == b.belge_turu:
		return {"durum": "ilgisiz", "mesaj": "İki ayrı belgeden birer alan seçin."}
	if a.anahtar != b.anahtar:
		return {"durum": "ilgisiz", "mesaj": "Bu iki bilgi birbiriyle karşılaştırılmaz."}
	if str(a.deger) == str(b.deger):
		return {"durum": "uyumlu", "mesaj": "Sorun yok: %s iki belgede de aynı." % a.etiket}
	return {"durum": "uyusmaz", "mesaj": "Uyuşmazlık: %s tutmuyor (%s ≠ %s)." % [a.etiket, str(a.deger), str(b.deger)]}


func _inceleme_degisti(acik: bool) -> void:
	for b in belgeler:
		b.inceleme_ac(acik)
	kural_kitabi.inceleme_ac(acik)
	gise.yuz.aktif = acik
	saat.takvim.aktif = acik
	_incele_dugmesi.set_pressed_no_signal(acik)
	_incele_dugmesi.modulate = Color(1.25, 1.2, 1.05) if acik else Color.WHITE
	_incele_seridi.text = "İNCELEME AÇIK: İKİ BİLGİYE TIKLA" if acik else "İNCELE  [BOŞLUK]"
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

	kural_kitabi = KuralKitabi.new()
	kural_kitabi.name = "KuralKitabi"
	kural_kitabi.position = Yerlesim.PANO.position
	kural_kitabi.size = Yerlesim.PANO.size
	add_child(kural_kitabi)

	_tepsiyi_kur()

	_belge_katmani = Control.new()
	_belge_katmani.name = "Belgeler"
	_belge_katmani.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_belge_katmani.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_belge_katmani)

	_arac_katmani = Control.new()
	_arac_katmani.name = "Araclar"
	_arac_katmani.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_arac_katmani.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_arac_katmani)
	var t := Yerlesim.TEPSI.position
	_arac_ekle("onay", Yerlesim.ISTAMPA.get_center() - Vector2(49, 62))
	_arac_ekle("eksik", t + Vector2(156, 12))
	_arac_ekle("havale", t + Vector2(156, 74))

	inceleme = IncelemeKatmani.new()
	inceleme.name = "Inceleme"
	add_child(inceleme)
	inceleme.mod_degisti.connect(_inceleme_degisti)
	gise.hedef_tiklandi.connect(inceleme.hedef_tiklandi)
	saat.hedef_tiklandi.connect(inceleme.hedef_tiklandi)
	kural_kitabi.hedef_tiklandi.connect(inceleme.hedef_tiklandi)

	_durum = _serit("SON KARAR: —", Vector2(12, 309), Color("1d1b19"))

	var bitir := Button.new()
	bitir.name = "MesaiyiBitir"
	bitir.text = "Mesaiyi Bitir (deneme)"
	bitir.add_theme_font_size_override("font_size", 12)
	bitir.position = Vector2(700, 309)
	bitir.focus_mode = FOCUS_NONE
	bitir.pressed.connect(mesaiyi_bitir)
	add_child(bitir)


func _arac_ekle(tur: String, yer: Vector2) -> void:
	var a := Arac.new()
	a.name = "Arac_" + tur
	_arac_katmani.add_child(a)
	a.kur(tur, yer)
	a.birakildi.connect(_arac_birakildi)
	araclar[tur] = a


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


## Araç tepsisi: büyüteç (inceleme modu düğmesi) ve şerit etiketler.
func _tepsiyi_kur() -> void:
	var t := Yerlesim.TEPSI
	_serit("ONAY MÜHRÜ", Vector2(t.position.x + 26, t.position.y + 116), Color("7a1f2b"))

	_incele_dugmesi = Button.new()
	_incele_dugmesi.name = "Incele"
	_incele_dugmesi.toggle_mode = true
	_incele_dugmesi.focus_mode = FOCUS_NONE
	_incele_dugmesi.flat = true
	_incele_dugmesi.position = t.position + Vector2(10, 140)
	_incele_dugmesi.size = Vector2(120, 74)
	_incele_dugmesi.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	for durum: String in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		_incele_dugmesi.add_theme_stylebox_override(durum, StyleBoxEmpty.new())
	if ResourceLoader.exists(BUYUTEC):
		var resim := TextureRect.new()
		resim.texture = load(BUYUTEC)
		resim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		resim.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		resim.size = Vector2(56, 104)
		resim.position = Vector2(34, -14)
		resim.pivot_offset = resim.size / 2.0
		resim.rotation = deg_to_rad(58.0)
		resim.mouse_filter = MOUSE_FILTER_IGNORE
		_incele_dugmesi.add_child(resim)
	_incele_dugmesi.toggled.connect(func(acik: bool) -> void: inceleme.aktif = acik)
	add_child(_incele_dugmesi)
	_incele_seridi = _serit("İNCELE  [BOŞLUK]", t.position + Vector2(8, 218), Color("1d1b19"))


## Dymo tarzı kabartma şerit etiket.
func _serit(metin: String, konum: Vector2, zemin: Color) -> Label:
	var l := Stil.etiket(metin, 11, Stil.KAGIT_BEYAZ, Stil.daktilo_kalin())
	l.add_theme_stylebox_override("normal", Stil.bosluklu(Stil.kutu(zemin, Color(0, 0, 0, 0.45), 1, 2, 2), 7, 2))
	l.position = konum
	add_child(l)
	return l
