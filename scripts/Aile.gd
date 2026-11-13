extends Control
## Akşam — ev. Solda oda: soba, sofra ve kilimin üstünde aile (anne örgü örer, Elif ödev yapar,
## Can kamyonuyla oynar). Sağda akşam defteri: o akşam evde olanlar ve günün hesabı.
## Oyuncu eldeki parayla neyi ödeyeceğini seçer: kira, kömür, yiyecek, ilaç, okul masrafı.
## Seçim anında odaya yansır (soba yanar, sofraya ekmek gelir); ödenmeyenlerin bedeli gece ödenir.

const ARKA_PLAN := "res://assets/img/ev_arkaplan.webp"
const NESNE := "res://assets/img/nesne/%s.webp"
const MASA_UST := 412.0                       ## sofranın üst kenarı (ekran y)
const SOBA_CAMI := Rect2(602, 442, 64, 37)
const DEFTER := Rect2(772, 24, 460, 672)
const FIGUR_OLCEGI := 0.4875                  ## tam boy figür dokularının ekrandaki ölçeği
## Aile üyelerinin odadaki yeri: figürün yatay ortası ve ayaklarının bastığı yer (ekran).
## Sıra, çizim sırasıdır: arkadaki önce.
const FIGURLER := [
	{"uye": "anne", "kimlik": "anne_boy", "orta": 480.0, "alt": 698.0},
	{"uye": "elif", "kimlik": "elif_boy", "orta": 276.0, "alt": 706.0},
	{"uye": "can", "kimlik": "can_boy", "orta": 102.0, "alt": 712.0},
]

var kalemler: Array[Dictionary] = []
var secili: Dictionary = {}                   ## kod -> bool
var gece: Dictionary = {}
var _gece_basladi := false           ## ışık söndürüldü mü (masraflar bir kez düşülür)
var _sabah_oldu := false             ## sabaha geçildi mi (gün bir kez ilerler)

var _soguk: ColorRect
var _soba: Control
var _ev: EvCanlandirma
var _sofra: Control
var _satirlar: Dictionary = {}                ## kod -> Control
var _toplam_yazi: Label
var _kalan_yazi: Label
var _yat: Button
var _figurler: Dictionary = {}                ## üye -> CanliPortre
var _videolar: Dictionary = {}                ## üye -> VideoFigur (canlandırması olanlar)
var _dokular: Dictionary = {}


func _ready() -> void:
	kalemler = AileDurumu.masraflar(Oyun.aile, Oyun.gun)
	for k in kalemler:
		# bedelsiz kalem (komşunun getirdiği yemek, ev sahibinin istemediği kira) kendiliğinden işaretlidir
		secili[str(k.kod)] = int(k.tutar) == 0
	Ses.yalniz(["soba", "ruzgar"])
	Ses.muzik(["ney"], -13.0, false, 3.0)      # akşam: uzaktan bir ney
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
	if not secili.has(kod) or _gece_basladi:
		return false
	var tutar := 0
	for k in kalemler:
		if str(k.kod) == kod:
			tutar = int(k.tutar)
	if not acik and tutar == 0:
		return false                    # bedelsiz kalemin işareti kaldırılamaz
	if acik and not bool(secili[kod]):
		if toplam() + tutar > maxi(0, Oyun.para):
			return false
	secili[kod] = acik
	_guncelle()
	return true


func _tikla(kod: String) -> void:
	if sec(kod, not bool(secili.get(kod, false))):
		Ses.cal("kalem", 1.0, -3.0, 0.08)


# --- Gece ---

func _lambayi_sondur() -> void:
	if _gece_basladi:
		return                          # ikinci kez basılırsa masraf iki kez düşmesin
	_gece_basladi = true
	_yat.disabled = true
	var odenen: Array = []
	for kod: String in secili:
		if bool(secili[kod]):
			odenen.append(kod)
	Oyun.para -= toplam()
	gece = AileDurumu.geceyi_gecir(Oyun.aile, Oyun.gun, odenen)
	# Savcının akıbeti, altıncı günün gecesinde belli olur.
	if Oyun.gun == 6:
		Oyun.bayraklar["savci"] = Hikaye.savci_akibeti(Oyun.bayraklar)
	gece["olay"] = Hikaye.gece(Oyun.gun, Oyun.bayraklar) if str(gece.get("son", "")) == "" else ""
	# Gecenin sonucu hemen kaydedilir: gece ekranında oyundan çıkıp akşamı baştan oynamak işe yaramaz.
	if str(gece.get("son", "")) != "":
		Oyun.sonu_kaydet({"tur": "kotu", "neden": str(gece.son), "kritik": str(gece.get("kritik", ""))})
	elif Oyun.gun >= Oyun.TOPLAM_GUN:
		Oyun.sonu_kaydet(Oyun.son_denetle(true))
	else:
		Oyun.sabahi_kaydet()
	Ses.ortami_kes("soba", 1.5)
	Ses.muzigi_kes(1.5)
	Ses.ortam("ruzgar", -13.0, 1.5)
	if str(gece.olay) != "":
		# gecenin sesi: üçüncü gece (ve bavul kaçtıysa yedinci gece) patlama, altıncı gece silah sesleri
		if Oyun.gun == 3 or Oyun.gun == 7:
			Ses.gecikmeli("patlama", 1.1, 1.0 if Oyun.gun == 3 else 1.12, 0.0)
		elif Oyun.gun == 6 and str(Oyun.bayrak("savci", "")) != "sag":
			var el := 3 if str(Oyun.bayrak("savci", "")) == "oldu" else 2
			for i in el:
				Ses.gecikmeli("silah", 1.1 + i * 0.62, 1.0 - i * 0.03, -2.0)
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
	baslik.position = Vector2(0, 130)
	baslik.size = Vector2(1280, 40)
	baslik.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	perde.add_child(baslik)

	var icerik := Control.new()
	icerik.mouse_filter = MOUSE_FILTER_IGNORE
	icerik.modulate.a = 0.0
	perde.add_child(icerik)
	var y := 200.0
	var olay := str(gece.get("olay", ""))
	if olay != "":
		y = Gazete.blok_ekle(icerik, olay, 19, Stil.daktilo_italik(), Color("e6b98a"), Rect2(240, y, 800, 0), true, 3) + 26.0
	var cevrili := PackedStringArray()
	for satir: Variant in gece.get("satirlar", []):
		cevrili.append(Dil.c(str(satir)))
	var metin := "\n\n".join(cevrili)
	Gazete.blok_ekle(icerik, metin, 19, Stil.daktilo(), Color("e8dfc8"), Rect2(240, y, 800, 0), true, 3)
	t.tween_property(icerik, "modulate:a", 1.0, 0.6)

	var sabah := Button.new()
	sabah.name = "SabahOldu"
	sabah.text = "Sabah Oldu" if str(gece.get("son", "")) == "" else "Devam"
	sabah.focus_mode = FOCUS_NONE
	sabah.custom_minimum_size = Vector2(210, 46)
	sabah.position = Vector2(535, 610)
	sabah.pressed.connect(_sabah)
	perde.add_child(sabah)


func _sabah() -> void:
	if _sabah_oldu:
		return                          # ikinci kez basılırsa gün iki kez ilerlemesin
	_sabah_oldu = true
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
		zemin.texture = Gorsel.yukle(ARKA_PLAN)
	add_child(zemin)

	# canlandırma: pencere karı, soba ateşi, ocaktaki kap (figürlerin arkasında)
	_ev = EvCanlandirma.new()
	_ev.name = "EvCanlandirma"
	add_child(_ev)
	add_child(_ev.arka)

	# sofradakiler figürlerin arkasında kalır
	_sofra = Control.new()
	_sofra.name = "Sofra"
	_sofra.mouse_filter = MOUSE_FILTER_IGNORE
	_sofra.draw.connect(_sofrayi_ciz)
	add_child(_sofra)

	var golgeler := Control.new()
	golgeler.name = "Golgeler"
	golgeler.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(golgeler)

	# aile: tam boy figürler (ağır hasta olan yataktadır, odada görünmez)
	var etiket_yerleri: Dictionary = {}
	for f: Dictionary in FIGURLER:
		var uye := str(f.uye)
		var p := CanliPortre.new()
		p.name = "Uye_" + uye
		add_child(p)
		p.ayarla(str(f.kimlik), FIGUR_OLCEGI)
		p.position = Vector2(float(f.orta) - p.size.x / 2.0, float(f.alt) - p.size.y)
		var bas_x := p.position.x + float((Portreler.bilgi(str(f.kimlik)).get("agiz", [0.5, 0.2]) as Array)[0]) * p.size.x
		if AileDurumu.saglik(Oyun.aile, uye) <= 0:
			p.visible = false
			etiket_yerleri[uye] = Vector2(float(f.orta), float(f.alt) - 54.0)
		else:
			_figurler[uye] = p
			etiket_yerleri[uye] = Vector2(bas_x, p.position.y - 21.0)
			# gerçek canlandırma: figürün videosu varsa boyalı resmin tam üstünde o oynar
			# (efekt kalitesi düşükken video açılmaz; durağan resim kalır)
			if Oyun.efekt_duzeyi() > 0 and VideoFigur.var_mi(str(f.kimlik)):
				var v := VideoFigur.new()
				v.name = "Video_" + uye
				add_child(v)
				v.kur(str(f.kimlik), p.position, FIGUR_OLCEGI)
				_videolar[uye] = v
				p.visible = false
	golgeler.draw.connect(func() -> void:
		# figürlerin yere düşen yumuşak gölgesi
		for f: Dictionary in FIGURLER:
			if not _figurler.has(str(f.uye)):
				continue
			var p: CanliPortre = _figurler[str(f.uye)]
			var m := Vector2(float(f.orta), float(f.alt) - 5.0)
			for i in 4:
				var r := p.size.x * (0.50 - i * 0.07)
				golgeler.draw_set_transform(m, 0.0, Vector2(1.0, 0.16))
				golgeler.draw_circle(Vector2.ZERO, r, Color(0, 0, 0, 0.075))
			golgeler.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE))

	_soba = Control.new()
	_soba.name = "Soba"
	_soba.mouse_filter = MOUSE_FILTER_IGNORE
	_soba.draw.connect(_sobayi_ciz)
	add_child(_soba)
	# ateşin ışığı ve buhar figürlerin önünde; nine, Elif ve Can'ın el hareketleri de buradan yürür
	add_child(_ev.on)
	_ev.kur(zemin.texture)

	_soguk = ColorRect.new()
	_soguk.name = "Soguk"
	_soguk.color = Color(0.10, 0.18, 0.34, 0.0)
	_soguk.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_soguk.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_soguk)

	# aile üyelerinin durumu: başlarının üstündeki şerit etiketler
	for uye: String in AileDurumu.UYELER:
		var saglik := AileDurumu.saglik(Oyun.aile, uye)
		var renk := Color("1d1b19") if saglik >= 3 else (Color("6b4a12") if saglik == 2 else Stil.BORDO)
		var yazi := AileDurumu.durum_metni(Oyun.aile, uye) if saglik > 0 else Dil.c("%s: yatakta") % Dil.c(str(AileDurumu.BILGI[uye].hitap))
		var l := Stil.etiket(Stil.buyuk(yazi), 11, Stil.KAGIT_BEYAZ, Stil.daktilo_kalin())
		l.name = "Durum_" + uye
		l.add_theme_stylebox_override("normal", Stil.bosluklu(Stil.kutu(renk, Color(0, 0, 0, 0.45), 1, 2, 2), 6, 2))
		add_child(l)
		l.size = l.get_combined_minimum_size()
		var yer: Vector2 = etiket_yerleri.get(uye, Vector2(200, 400))
		l.position = Vector2(clampf(yer.x - l.size.x / 2.0, 6.0, DEFTER.position.x - l.size.x - 8.0), yer.y)

	for ad: String in ["ekmek", "ilac", "defter"]:
		var yol := NESNE % ad
		if ResourceLoader.exists(yol):
			_dokular[ad] = load(yol)


## Sobanın ve ocağın durumu seçilen kalemlere uyar: kömür alındıysa soba yanar; yemek varsa ocakta
## tencere, yoksa (soba yanıyorsa) çaydanlık durur.
func _evi_guncelle() -> void:
	if _ev == null:
		return
	var yaniyor := bool(secili.get("komur", false))
	_ev.soba_yaniyor = yaniyor
	_ev.ocakta = "tencere" if bool(secili.get("yemek", false)) else ("caydanlik" if yaniyor else "")
	if _soba != null:
		_soba.queue_redraw()


## Sobanın camı: kömür alınmadıysa söner (boyalı alevin üstü kararır). Yanan sobanın alevini,
## kıvılcımını ve ışığını EvCanlandirma çizer.
func _sobayi_ciz() -> void:
	if not bool(secili.get("komur", false)):
		_soba.draw_rect(SOBA_CAMI.grow(2.0), Color(0.07, 0.06, 0.06, 0.86))


## Seçilen kalemler sofrada görünür: ekmek, ilaç şişesi, okul defteri.
func _sofrayi_ciz() -> void:
	if bool(secili.get("yemek", false)) and _dokular.has("ekmek"):
		_sofra.draw_texture_rect(_dokular["ekmek"], Rect2(126, MASA_UST - 58.0, 92, 83), false)
	var ilac_var := false
	for kod: String in secili:
		if kod.begins_with("ilac_") and bool(secili[kod]):
			ilac_var = true
	if ilac_var and _dokular.has("ilac"):
		_sofra.draw_texture_rect(_dokular["ilac"], Rect2(64, MASA_UST - 62.0, 34, 70), false)
	if bool(secili.get("okul", false)) and _dokular.has("defter"):
		_sofra.draw_texture_rect(_dokular["defter"], Rect2(262, MASA_UST - 40.0, 46, 62), false)


# --- Akşam defteri ---

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
	var baslik := Stil.etiket("AKŞAM DEFTERİ", 22, Stil.MUREKKEP, Stil.daktilo_kalin())
	baslik.position = Vector2(0, 34)
	baslik.size = Vector2(DEFTER.size.x, 28)
	baslik.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	defter.add_child(baslik)
	var gun := Veri.gun(Oyun.gun)
	var tarih := Stil.etiket(Dil.c("%s akşamı") % Tarih.uzun(str(gun.get("tarih", ""))), 12, Stil.MUREKKEP_SOLUK, Stil.daktilo_italik())
	tarih.position = Vector2(0, 62)
	tarih.size = Vector2(DEFTER.size.x, 16)
	tarih.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	defter.add_child(tarih)

	# o akşam evde olanlar: deftere dolma kalemle düşülmüş not
	var y := 88.0
	var olan := Hikaye.aksam(Oyun.gun, Oyun.bayraklar)
	if olan != "":
		var notu := Stil.etiket(olan, 18, Stil.MAVI_MUREKKEP, Stil.el_yazisi())
		notu.name = "AksamNotu"
		notu.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		notu.add_theme_constant_override("line_spacing", -3)
		var yuk := Stil.el_yazisi().get_multiline_string_size(Dil.c(olan), HORIZONTAL_ALIGNMENT_LEFT, w, 18).y
		var satir := maxi(1, roundi(yuk / Stil.el_yazisi().get_height(18)))
		yuk -= 3.0 * (satir - 1)
		notu.position = Vector2(x, y)
		notu.size = Vector2(w, yuk + 4.0)
		defter.add_child(notu)
		y += yuk + 12.0

	var eldeki := Stil.etiket(Dil.c("Eldeki para: %s") % Stil.tl(Oyun.para), 16, Stil.MUREKKEP, Stil.daktilo_kalin())
	eldeki.position = Vector2(x, y)
	defter.add_child(eldeki)
	y += 30.0

	# kalemler çok olduğunda satırlar sıkışır ki düğmeye yer kalsın
	var dugme_ust := DEFTER.size.y - 82.0
	var notlu := 0
	for k in kalemler:
		if str(k.get("not", "")) != "":
			notlu += 1
	var gereken := notlu * 46.0 + (kalemler.size() - notlu) * 32.0 + kalemler.size() * 6.0 + 64.0
	var sikisma := clampf((dugme_ust - y) / gereken, 0.78, 1.0)
	for k in kalemler:
		var satir := _kalem_satiri(k, w, sikisma)
		satir.position = Vector2(x, y)
		defter.add_child(satir)
		_satirlar[str(k.kod)] = satir
		y += satir.size.y + 6.0 * sikisma

	var cizgi := ColorRect.new()
	cizgi.color = Color(Stil.MUREKKEP, 0.7)
	cizgi.position = Vector2(x, y + 2.0)
	cizgi.size = Vector2(w, 1.5)
	cizgi.mouse_filter = MOUSE_FILTER_IGNORE
	defter.add_child(cizgi)
	_toplam_yazi = Stil.etiket("", 15, Stil.MUREKKEP, Stil.daktilo())
	_toplam_yazi.position = Vector2(x, y + 10.0)
	defter.add_child(_toplam_yazi)
	_kalan_yazi = Stil.etiket("", 16, Stil.MUREKKEP, Stil.daktilo_kalin())
	_kalan_yazi.position = Vector2(x, y + 32.0)
	defter.add_child(_kalan_yazi)

	_yat = Button.new()
	_yat.name = "Yat"
	_yat.text = "Lambayı Söndür"
	_yat.focus_mode = FOCUS_NONE
	_yat.custom_minimum_size = Vector2(220, 46)
	_yat.position = Vector2((DEFTER.size.x - 220.0) / 2.0, dugme_ust)
	_yat.pressed.connect(_lambayi_sondur)
	defter.add_child(_yat)


## Defterdeki bir masraf satırı: işaret kutusu, ad, tutar ve (varsa) not.
func _kalem_satiri(k: Dictionary, w: float, sikisma: float = 1.0) -> Control:
	var kod := str(k.kod)
	var notu := str(k.get("not", ""))
	var d := Button.new()
	d.name = "Kalem_" + kod
	d.focus_mode = FOCUS_NONE
	d.size = Vector2(w, roundf((46.0 if notu != "" else 32.0) * sikisma))
	d.custom_minimum_size = d.size
	d.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	d.add_theme_stylebox_override("normal", Stil.kutu(Color(0, 0, 0, 0)))
	d.add_theme_stylebox_override("hover", Stil.kutu(Color(Stil.BORDO, 0.08), Color(Stil.BORDO, 0.5), 1))
	d.add_theme_stylebox_override("pressed", Stil.kutu(Color(Stil.BORDO, 0.14), Color(Stil.BORDO, 0.6), 1))
	d.add_theme_stylebox_override("disabled", Stil.kutu(Color(0, 0, 0, 0)))
	d.pressed.connect(_tikla.bind(kod))

	var ust := 5.0 * sikisma
	var kutu := Control.new()
	kutu.name = "Kutu"
	kutu.position = Vector2(6, ust + 1.0)
	kutu.size = Vector2(20, 20)
	kutu.mouse_filter = MOUSE_FILTER_IGNORE
	kutu.draw.connect(func() -> void:
		kutu.draw_rect(Rect2(0, 0, 20, 20), Stil.MUREKKEP, false, 1.6)
		if bool(secili.get(kod, false)):
			kutu.draw_polyline(PackedVector2Array([Vector2(3, 10), Vector2(8, 16), Vector2(19, -1)]), Stil.MAVI_MUREKKEP, 3.0, true))
	d.add_child(kutu)

	var ad := Stil.etiket(str(k.ad), 15, Stil.MUREKKEP)
	ad.name = "Ad"
	ad.position = Vector2(36, ust)
	d.add_child(ad)
	var tutar := Stil.etiket("—" if int(k.tutar) == 0 else Stil.tl(int(k.tutar)), 15, Stil.MUREKKEP, Stil.daktilo_kalin())
	tutar.name = "Tutar"
	tutar.position = Vector2(w - 96.0, ust)
	tutar.size = Vector2(90, 20)
	tutar.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	d.add_child(tutar)
	if notu != "":
		var n := Stil.etiket(notu, 11, Stil.BORDO, Stil.daktilo_italik())
		n.position = Vector2(36, ust + 20.0 * sikisma)
		d.add_child(n)
	return d


func _guncelle() -> void:
	var harcanan := toplam()
	var kalan := Oyun.para - harcanan
	_toplam_yazi.text = Dil.c("Bu akşam ödenecek: %s") % Stil.tl(harcanan)
	_kalan_yazi.text = Dil.c("Yarına kalan: %s") % Stil.tl(kalan)
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
	_evi_guncelle()
	var isinacak := bool(secili.get("komur", false))
	var hedef := 0.0 if isinacak else 0.20
	if _yat != null and not _yat.disabled:
		# soba yanınca çıtırtı, yanmayınca dışarıdaki rüzgâr duyulur
		if isinacak:
			Ses.ortam("soba", -3.0, 0.8)
			Ses.ortami_kes("ruzgar", 1.2)
		else:
			Ses.ortam("ruzgar", -11.0, 1.2)
			Ses.ortami_kes("soba", 0.6)
	var t := create_tween()
	t.tween_property(_soguk, "color:a", hedef, 0.4)
	# hasta ya da üşüyen aile üyesi solgun ve durgun görünür
	for uye: String in _figurler:
		var saglik := AileDurumu.saglik(Oyun.aile, uye)
		var p: CanliPortre = _figurler[uye]
		p.modulate = Color(0.84, 0.90, 0.89) if saglik <= 1 else (Color(0.93, 0.96, 0.97) if saglik == 2 else Color.WHITE)
		p.canlilik = 0.45 if saglik <= 1 else (0.75 if saglik == 2 else 1.0)
		if _videolar.has(uye):
			var v: VideoFigur = _videolar[uye]
			v.modulate = p.modulate
			v.durdur(saglik <= 1)           # hasta olan elindeki işi bırakır
