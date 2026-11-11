extends Control
## Akşam — ev. Soba, sofra ve aile solda; akşam hesabı defteri sağda.
## Oyuncu eldeki parayla neyi ödeyeceğini seçer: kira, kömür, yiyecek, ilaç, okul masrafı.
## Seçim anında odaya yansır (soba yanar, sofraya ekmek gelir); ödenmeyenlerin bedeli gece ödenir.

const ARKA_PLAN := "res://assets/img/ev_arkaplan.webp"
const NESNE := "res://assets/img/nesne/%s.webp"
const MASA_UST := 412.0                       ## sofranın üst kenarı (ekran y)
const MASA_ONU := Rect2(20, 412, 548, 210)    ## büstlerin önünü kapatan sofra parçası
const SOBA_CAMI := Rect2(602, 442, 64, 37)
const UYE_YERI := {"anne": 150.0, "elif": 302.0, "can": 438.0}
const DEFTER := Rect2(772, 24, 460, 672)

var kalemler: Array[Dictionary] = []
var secili: Dictionary = {}                   ## kod -> bool
var gece: Dictionary = {}

var _soguk: ColorRect
var _soba: Control
var _sofra: Control
var _satirlar: Dictionary = {}                ## kod -> Control
var _toplam_yazi: Label
var _kalan_yazi: Label
var _yat: Button
var _portreler: Dictionary = {}
var _dokular: Dictionary = {}


func _ready() -> void:
	kalemler = AileDurumu.masraflar(Oyun.aile, Oyun.gun)
	for k in kalemler:
		secili[str(k.kod)] = false
	_odayi_kur()
	_defteri_kur()
	_guncelle()


func toplam() -> int:
	var t := 0
	for k in kalemler:
		if bool(secili.get(str(k.kod), false)):
			t += int(k.tutar)
	return t


## Bir kalemi işaretler ya da işareti kaldırır (para yetmiyorsa işaretlenmez).
func sec(kod: String, acik: bool) -> bool:
	if not secili.has(kod):
		return false
	if acik and not bool(secili[kod]):
		var tutar := 0
		for k in kalemler:
			if str(k.kod) == kod:
				tutar = int(k.tutar)
		if toplam() + tutar > maxi(0, Oyun.para):
			return false
	secili[kod] = acik
	_guncelle()
	return true


func _tikla(kod: String) -> void:
	sec(kod, not bool(secili.get(kod, false)))


# --- Gece ---

func _lambayi_sondur() -> void:
	_yat.disabled = true
	var odenen: Array = []
	for kod: String in secili:
		if bool(secili[kod]):
			odenen.append(kod)
	Oyun.para -= toplam()
	gece = AileDurumu.geceyi_gecir(Oyun.aile, Oyun.gun, odenen)
	_geceyi_goster()


func _geceyi_goster() -> void:
	var perde := ColorRect.new()
	perde.name = "Gece"
	perde.color = Color(0.04, 0.035, 0.05, 0.0)
	perde.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(perde)
	var t := create_tween()
	t.tween_property(perde, "color:a", 0.94, 0.7)

	var baslik := Stil.etiket("GECE", 30, Color("d9cfb4"), Stil.daktilo_kalin())
	baslik.position = Vector2(0, 150)
	baslik.size = Vector2(1280, 40)
	baslik.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	perde.add_child(baslik)

	var metin := "\n\n".join(PackedStringArray(gece.get("satirlar", [])))
	var yazi := Stil.etiket(metin, 19, Color("e8dfc8"), Stil.daktilo())
	yazi.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	yazi.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	yazi.position = Vector2(240, 220)
	yazi.size = Vector2(800, 300)
	yazi.modulate.a = 0.0
	perde.add_child(yazi)
	t.tween_property(yazi, "modulate:a", 1.0, 0.6)

	var sabah := Button.new()
	sabah.name = "SabahOldu"
	sabah.text = "Sabah Oldu" if str(gece.get("son", "")) == "" else "Devam"
	sabah.focus_mode = FOCUS_NONE
	sabah.custom_minimum_size = Vector2(210, 46)
	sabah.position = Vector2(535, 590)
	sabah.pressed.connect(_sabah)
	perde.add_child(sabah)


func _sabah() -> void:
	var son := str(gece.get("son", ""))
	if son != "":
		Oyun.oyunu_bitir({"tur": "kotu", "neden": son, "kritik": str(gece.get("kritik", ""))})
	elif Oyun.sonraki_gun():
		Oyun.sahneye_gec("masa")
	else:
		Oyun.oyunu_bitir(Oyun.son_denetle(true))


# --- Oda ---

func _odayi_kur() -> void:
	var zemin := TextureRect.new()
	zemin.name = "Oda"
	zemin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	zemin.size = Yerlesim.EKRAN.size
	zemin.mouse_filter = MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(ARKA_PLAN):
		zemin.texture = load(ARKA_PLAN)
	add_child(zemin)

	# sofranın arkasında oturan aile (ağır hasta olan yataktadır, sofrada görünmez)
	for uye: String in AileDurumu.UYELER:
		var saglik := AileDurumu.saglik(Oyun.aile, uye)
		if saglik <= 0:
			continue
		var p := CanliPortre.new()
		p.name = "Uye_" + uye
		add_child(p)
		p.ayarla(uye, 0.42)
		p.position = Vector2(float(UYE_YERI[uye]) - p.size.x / 2.0, MASA_UST + 44.0 - p.size.y)
		_portreler[uye] = p

	# büstlerin önünü kapatan sofra: arka plan görselinin aynı parçası
	if zemin.texture != null:
		var parca := AtlasTexture.new()
		parca.atlas = zemin.texture
		var olcek := zemin.texture.get_size() / Yerlesim.EKRAN.size
		parca.region = Rect2(MASA_ONU.position * olcek, MASA_ONU.size * olcek)
		var on := TextureRect.new()
		on.name = "SofraOnu"
		on.texture = parca
		on.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		on.position = MASA_ONU.position
		on.size = MASA_ONU.size
		on.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(on)

	_sofra = Control.new()
	_sofra.name = "Sofra"
	_sofra.mouse_filter = MOUSE_FILTER_IGNORE
	_sofra.draw.connect(_sofrayi_ciz)
	add_child(_sofra)

	_soba = Control.new()
	_soba.name = "Soba"
	_soba.mouse_filter = MOUSE_FILTER_IGNORE
	_soba.draw.connect(_sobayi_ciz)
	add_child(_soba)

	_soguk = ColorRect.new()
	_soguk.name = "Soguk"
	_soguk.color = Color(0.10, 0.18, 0.34, 0.0)
	_soguk.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_soguk.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_soguk)

	# aile üyelerinin durumu: sofra örtüsünün önündeki etiketler
	for uye: String in AileDurumu.UYELER:
		var saglik := AileDurumu.saglik(Oyun.aile, uye)
		var renk := Color("1d1b19") if saglik >= 3 else (Color("6b4a12") if saglik == 2 else Stil.BORDO)
		var l := Stil.etiket(Stil.buyuk(AileDurumu.durum_metni(Oyun.aile, uye)), 11, Stil.KAGIT_BEYAZ, Stil.daktilo_kalin())
		l.add_theme_stylebox_override("normal", Stil.bosluklu(Stil.kutu(renk, Color(0, 0, 0, 0.45), 1, 2, 2), 6, 2))
		add_child(l)
		l.size = l.get_combined_minimum_size()
		l.position = Vector2(float(UYE_YERI[uye]) - l.size.x / 2.0, MASA_UST + 62.0)

	for ad: String in ["ekmek", "ilac", "defter"]:
		var yol := NESNE % ad
		if ResourceLoader.exists(yol):
			_dokular[ad] = load(yol)


func _process(_delta: float) -> void:
	if _soba != null:
		_soba.queue_redraw()


## Sobanın camı: kömür alınmadıysa söner (boyalı alevin üstü kararır), alındıysa parlar.
func _sobayi_ciz() -> void:
	if bool(secili.get("komur", false)):
		var nabiz := 0.75 + 0.25 * sin(Time.get_ticks_msec() / 230.0)
		var m := SOBA_CAMI.get_center()
		_soba.draw_circle(m, 62.0, Color(1.0, 0.55, 0.20, 0.07 * nabiz))
		_soba.draw_circle(m, 38.0, Color(1.0, 0.60, 0.22, 0.10 * nabiz))
		_soba.draw_rect(SOBA_CAMI, Color(1.0, 0.70, 0.30, 0.16 * nabiz))
	else:
		_soba.draw_rect(SOBA_CAMI.grow(2.0), Color(0.07, 0.06, 0.06, 0.86))


## Seçilen kalemler sofrada görünür: ekmek, ilaç şişesi, okul defteri.
func _sofrayi_ciz() -> void:
	if bool(secili.get("yemek", false)) and _dokular.has("ekmek"):
		_sofra.draw_texture_rect(_dokular["ekmek"], Rect2(218, MASA_UST - 58.0, 92, 83), false)
	var ilac_var := false
	for kod: String in secili:
		if kod.begins_with("ilac_") and bool(secili[kod]):
			ilac_var = true
	if ilac_var and _dokular.has("ilac"):
		_sofra.draw_texture_rect(_dokular["ilac"], Rect2(96, MASA_UST - 62.0, 34, 70), false)
	if bool(secili.get("okul", false)) and _dokular.has("defter"):
		_sofra.draw_texture_rect(_dokular["defter"], Rect2(356, MASA_UST - 40.0, 46, 62), false)


# --- Akşam hesabı defteri ---

func _defteri_kur() -> void:
	var defter := Control.new()
	defter.name = "Defter"
	defter.position = DEFTER.position
	defter.size = DEFTER.size
	defter.rotation = deg_to_rad(0.7)
	defter.pivot_offset = DEFTER.size / 2.0
	defter.mouse_filter = MOUSE_FILTER_IGNORE
	defter.draw.connect(func() -> void:
		Kagit.ciz(defter, Rect2(Vector2.ZERO, DEFTER.size), "sayfa", Stil.KAGIT, 14.0, 4.0))
	add_child(defter)

	var x := 44.0
	var w := DEFTER.size.x - 2.0 * x
	var baslik := Stil.etiket("AKŞAM HESABI", 22, Stil.MUREKKEP, Stil.daktilo_kalin())
	baslik.position = Vector2(0, 36)
	baslik.size = Vector2(DEFTER.size.x, 28)
	baslik.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	defter.add_child(baslik)
	var gun := Veri.gun(Oyun.gun)
	var tarih := Stil.etiket("%s akşamı" % Tarih.uzun(str(gun.get("tarih", ""))), 12, Stil.MUREKKEP_SOLUK, Stil.daktilo_italik())
	tarih.position = Vector2(0, 66)
	tarih.size = Vector2(DEFTER.size.x, 16)
	tarih.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	defter.add_child(tarih)

	var eldeki := Stil.etiket("Eldeki para: %s" % Stil.tl(Oyun.para), 16, Stil.MUREKKEP, Stil.daktilo_kalin())
	eldeki.position = Vector2(x, 100)
	defter.add_child(eldeki)

	var y := 138.0
	for k in kalemler:
		var satir := _kalem_satiri(k, w)
		satir.position = Vector2(x, y)
		defter.add_child(satir)
		_satirlar[str(k.kod)] = satir
		y += satir.size.y + 6.0

	var cizgi := ColorRect.new()
	cizgi.color = Color(Stil.MUREKKEP, 0.7)
	cizgi.position = Vector2(x, y + 4.0)
	cizgi.size = Vector2(w, 1.5)
	cizgi.mouse_filter = MOUSE_FILTER_IGNORE
	defter.add_child(cizgi)
	_toplam_yazi = Stil.etiket("", 15, Stil.MUREKKEP, Stil.daktilo())
	_toplam_yazi.position = Vector2(x, y + 14.0)
	defter.add_child(_toplam_yazi)
	_kalan_yazi = Stil.etiket("", 16, Stil.MUREKKEP, Stil.daktilo_kalin())
	_kalan_yazi.position = Vector2(x, y + 38.0)
	defter.add_child(_kalan_yazi)

	_yat = Button.new()
	_yat.name = "Yat"
	_yat.text = "Lambayı Söndür"
	_yat.focus_mode = FOCUS_NONE
	_yat.custom_minimum_size = Vector2(220, 46)
	_yat.position = Vector2((DEFTER.size.x - 220.0) / 2.0, DEFTER.size.y - 82.0)
	_yat.pressed.connect(_lambayi_sondur)
	defter.add_child(_yat)


## Defterdeki bir masraf satırı: işaret kutusu, ad, tutar ve (varsa) not.
func _kalem_satiri(k: Dictionary, w: float) -> Control:
	var kod := str(k.kod)
	var notu := str(k.get("not", ""))
	var d := Button.new()
	d.name = "Kalem_" + kod
	d.focus_mode = FOCUS_NONE
	d.size = Vector2(w, 46.0 if notu != "" else 32.0)
	d.custom_minimum_size = d.size
	d.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	d.add_theme_stylebox_override("normal", Stil.kutu(Color(0, 0, 0, 0)))
	d.add_theme_stylebox_override("hover", Stil.kutu(Color(Stil.BORDO, 0.08), Color(Stil.BORDO, 0.5), 1))
	d.add_theme_stylebox_override("pressed", Stil.kutu(Color(Stil.BORDO, 0.14), Color(Stil.BORDO, 0.6), 1))
	d.add_theme_stylebox_override("disabled", Stil.kutu(Color(0, 0, 0, 0)))
	d.pressed.connect(_tikla.bind(kod))

	var kutu := Control.new()
	kutu.name = "Kutu"
	kutu.position = Vector2(6, 6)
	kutu.size = Vector2(20, 20)
	kutu.mouse_filter = MOUSE_FILTER_IGNORE
	kutu.draw.connect(func() -> void:
		kutu.draw_rect(Rect2(0, 0, 20, 20), Stil.MUREKKEP, false, 1.6)
		if bool(secili.get(kod, false)):
			kutu.draw_polyline(PackedVector2Array([Vector2(3, 10), Vector2(8, 16), Vector2(19, -1)]), Stil.MAVI_MUREKKEP, 3.0, true))
	d.add_child(kutu)

	var ad := Stil.etiket(str(k.ad), 15, Stil.MUREKKEP)
	ad.name = "Ad"
	ad.position = Vector2(36, 5)
	d.add_child(ad)
	var tutar := Stil.etiket("ikram" if int(k.tutar) == 0 else Stil.tl(int(k.tutar)), 15, Stil.MUREKKEP, Stil.daktilo_kalin())
	tutar.name = "Tutar"
	tutar.position = Vector2(w - 96.0, 5)
	tutar.size = Vector2(90, 20)
	tutar.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	d.add_child(tutar)
	if notu != "":
		var n := Stil.etiket(notu, 11, Stil.BORDO, Stil.daktilo_italik())
		n.position = Vector2(36, 26)
		d.add_child(n)
	return d


func _guncelle() -> void:
	var harcanan := toplam()
	var kalan := Oyun.para - harcanan
	_toplam_yazi.text = "Bu akşam ödenecek: %s" % Stil.tl(harcanan)
	_kalan_yazi.text = "Yarına kalan: %s" % Stil.tl(kalan)
	for kod: String in _satirlar:
		var s: Button = _satirlar[kod]
		(s.get_node("Kutu") as Control).queue_redraw()
		var tutar := 0
		for k in kalemler:
			if str(k.kod) == kod:
				tutar = int(k.tutar)
		var yetmez := not bool(secili[kod]) and harcanan + tutar > maxi(0, Oyun.para)
		(s.get_node("Ad") as Label).modulate.a = 0.45 if yetmez else 1.0
		(s.get_node("Tutar") as Label).modulate.a = 0.45 if yetmez else 1.0
	_sofra.queue_redraw()
	var isinacak := bool(secili.get("komur", false))
	var hedef := 0.0 if isinacak else 0.20
	var t := create_tween()
	t.tween_property(_soguk, "color:a", hedef, 0.4)
	# hasta ya da üşüyen aile üyesi solgun görünür
	for uye: String in _portreler:
		var saglik := AileDurumu.saglik(Oyun.aile, uye)
		var p: CanliPortre = _portreler[uye]
		p.modulate = Color(0.86, 0.92, 0.90) if saglik <= 1 else (Color(0.94, 0.96, 0.97) if saglik == 2 else Color.WHITE)
