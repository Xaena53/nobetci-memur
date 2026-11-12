extends Control
## Oyun sonu: "Ardıçlı Postası"nın ertesi sabahki birinci sayfası. Manşet oyunun nasıl bittiğini,
## alttaki haberler hikâyedeki öbür kişilerin akıbetini anlatır. Sağda memurun sicil özeti ve
## (yazıldıysa) Hüsnü Amca'nın mektubu durur.

const ARKA_PLAN := "res://assets/img/masa_arkaplan.webp"
const SAYFA := Rect2(44, 22, 772, 676)
const KENAR := 34.0
const SICIL := Rect2(856, 26, 380, 218)
const MEKTUP := Rect2(866, 252, 360, 408)

var son: Dictionary = {}


func _ready() -> void:
	son = Hikaye.son(Oyun.son, Oyun.bayraklar)
	Ses.yalniz(["ruzgar"])
	Ses.ortam("ruzgar", -16.0, 2.0)
	Ses.muzik(["ney"], -7.0, false, 3.0)
	if ResourceLoader.exists(ARKA_PLAN):
		var zemin := TextureRect.new()
		zemin.texture = load(ARKA_PLAN)
		zemin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		zemin.size = Yerlesim.EKRAN.size
		zemin.modulate = Color(0.20, 0.19, 0.18)
		zemin.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(zemin)
	else:
		var duz := ColorRect.new()
		duz.color = Stil.GECE
		duz.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		add_child(duz)

	var sayfa := _gazeteyi_kur()
	var mektup := str(son.get("mektup", ""))
	var sicil := _sicili_kur(mektup == "")
	var kagitlar: Array[Control] = [sayfa, sicil]
	if mektup != "":
		kagitlar.append(_mektubu_kur(mektup))

	var menu := Button.new()
	menu.name = "AnaMenu"
	menu.text = "Ana Menü"
	menu.focus_mode = FOCUS_NONE
	menu.custom_minimum_size = Vector2(220, 42)
	menu.position = Vector2(SICIL.position.x + (SICIL.size.x - 220.0) / 2.0, 668.0 if mektup != "" else 470.0)
	menu.pressed.connect(func() -> void: Oyun.sahneye_gec("menu"))
	add_child(menu)
	kagitlar.append(menu)

	# kâğıtlar masaya sırayla bırakılır
	for i in kagitlar.size():
		var k := kagitlar[i]
		var hedef := k.position
		k.position = hedef + Vector2(0, 26)
		k.modulate.a = 0.0
		var t := create_tween()
		t.tween_interval(0.25 + i * 0.45)
		if not k is Button:
			t.tween_callback(Ses.cal.bind("kagit", 0.9, -6.0, 0.08))
		t.tween_property(k, "modulate:a", 1.0, 0.3)
		t.parallel().tween_property(k, "position", hedef, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# --- Gazetenin birinci sayfası ---

func _gazeteyi_kur() -> Control:
	var sayfa := Control.new()
	sayfa.name = "Gazete"
	sayfa.position = SAYFA.position
	sayfa.size = SAYFA.size
	sayfa.pivot_offset = SAYFA.size / 2.0
	sayfa.rotation = deg_to_rad(-0.7)
	sayfa.mouse_filter = MOUSE_FILTER_IGNORE
	sayfa.draw.connect(func() -> void:
		Kagit.ciz(sayfa, Rect2(Vector2.ZERO, SAYFA.size), "sayfa", Stil.KAGIT_ESKI, 16.0, 4.0, Gazete.KAGIT_TONU))
	add_child(sayfa)

	var w := SAYFA.size.x - 2.0 * KENAR
	var ad := Stil.etiket(Hikaye.GAZETE_ADI, 50, Stil.MUREKKEP, Stil.serif_kalin())
	ad.position = Vector2(0, 22)
	ad.size = Vector2(SAYFA.size.x, 60)
	ad.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sayfa.add_child(ad)
	_cizgi(sayfa, 88.0, w, 2.5)
	_cizgi(sayfa, 93.0, w, 1.0)
	var kunye := Stil.etiket("%s   •   Sayı 4125   •   Fiyatı 25 TL" % str(son.get("tarih", "")), 12, Stil.MUREKKEP_SOLUK,
		Stil.serif_italik())
	kunye.position = Vector2(0, 98)
	kunye.size = Vector2(SAYFA.size.x, 16)
	kunye.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sayfa.add_child(kunye)
	_cizgi(sayfa, 119.0, w, 1.0)

	var y := Gazete.blok_ekle(sayfa, str(son.get("manset", "")), 40, Stil.serif_kalin(), Stil.MUREKKEP,
		Rect2(KENAR, 128, w, 0), true, -6) + 10.0

	var metin := str(son.get("metin", ""))
	var foto := str(son.get("foto", ""))
	var alt := y
	if foto != "":
		var kutu := Vector2(150, 180)
		Gazete.foto_ekle(sayfa, foto, Rect2(KENAR, y + 3.0, kutu.x, kutu.y), str(son.get("foto_alt", "")))
		alt = Gazete.blok_ekle(sayfa, metin, 17, Stil.serif(), Stil.MUREKKEP, Rect2(KENAR + kutu.x + 18.0, y, w - kutu.x - 18.0, 0), false, 2)
		alt = maxf(alt, y + kutu.y + 34.0)
	else:
		alt = Gazete.blok_ekle(sayfa, metin, 18, Stil.serif(), Stil.MUREKKEP, Rect2(KENAR, y, w, 0), false, 3)
	var ana_alt := alt

	# yan haberler: sütunlar hâlinde
	var ilan_ust := SAYFA.size.y - 118.0
	var yan: Array = son.get("yan", [])
	if not yan.is_empty():
		y = alt + 12.0
		_cizgi(sayfa, y, w, 1.5)
		y += 12.0
		var adet := mini(3, yan.size())
		var bosluk := 22.0
		var sutun := (w - bosluk * (adet - 1)) / adet
		for i in adet:
			var haber: Dictionary = yan[i]
			var x := KENAR + i * (sutun + bosluk)
			var b := Gazete.blok_ekle(sayfa, str(haber.get("baslik", "")), 17, Stil.serif_kalin(), Stil.MUREKKEP,
				Rect2(x, y, sutun, 0), false, -2)
			Gazete.blok_ekle(sayfa, str(haber.get("metin", "")), 14, Stil.serif(), Stil.MUREKKEP, Rect2(x, b + 4.0, sutun, 0), false, 1)
			if i > 0:
				var ayrac := ColorRect.new()
				ayrac.color = Color(Stil.MUREKKEP, 0.5)
				ayrac.position = Vector2(x - bosluk / 2.0, y)
				ayrac.size = Vector2(1.0, ilan_ust - y - 14.0)
				ayrac.mouse_filter = MOUSE_FILTER_IGNORE
				sayfa.add_child(ayrac)

	# sayfanın dibi: küçük ilanlar
	var ilanlar: Array = son.get("ilanlar", [])
	if not ilanlar.is_empty():
		_cizgi(sayfa, ilan_ust, w, 1.5)
		var ilan_basligi := Stil.etiket("KÜÇÜK İLANLAR", 11, Stil.MUREKKEP_SOLUK, Stil.serif_kalin())
		ilan_basligi.position = Vector2(KENAR, ilan_ust + 4.0)
		sayfa.add_child(ilan_basligi)
		var ilan_bosluk := 18.0
		var ilan_sutun := (w - ilan_bosluk * (ilanlar.size() - 1)) / ilanlar.size()
		for i in ilanlar.size():
			var ilan: Dictionary = ilanlar[i]
			var x := KENAR + i * (ilan_sutun + ilan_bosluk)
			var kutu := Rect2(x, ilan_ust + 22.0, ilan_sutun, 68.0)
			var cerceve := Panel.new()
			cerceve.add_theme_stylebox_override("panel", Stil.kutu(Color(0, 0, 0, 0), Color(Stil.MUREKKEP, 0.6), 1))
			cerceve.position = kutu.position
			cerceve.size = kutu.size
			cerceve.mouse_filter = MOUSE_FILTER_IGNORE
			sayfa.add_child(cerceve)
			var ib := Gazete.blok_ekle(sayfa, str(ilan.get("baslik", "")), 12, Stil.serif_kalin(), Stil.MUREKKEP,
				Rect2(x + 8.0, kutu.position.y + 4.0, ilan_sutun - 16.0, 0), true, 0)
			Gazete.blok_ekle(sayfa, str(ilan.get("metin", "")), 11, Stil.serif(), Stil.MUREKKEP,
				Rect2(x + 8.0, ib - 1.0, ilan_sutun - 16.0, 0), false, -1)

	# sonun adı: ana haberin boş köşesine vurulmuş damga
	var damga_yazisi := str(son.get("damga", ""))
	if damga_yazisi != "":
		var damga := Stil.etiket(damga_yazisi, 26, Color(Stil.BORDO, 0.86), Stil.daktilo_kalin())
		damga.name = "Damga"
		damga.add_theme_stylebox_override("normal", Stil.bosluklu(Stil.kutu(Color(0, 0, 0, 0), Color(Stil.BORDO, 0.86), 3, 3), 12, 3))
		sayfa.add_child(damga)
		damga.size = damga.get_combined_minimum_size()
		damga.pivot_offset = damga.size / 2.0
		damga.position = Vector2(SAYFA.size.x - damga.size.x - 44.0, ana_alt - damga.size.y - 16.0)
		damga.rotation = deg_to_rad(-7.0)
	return sayfa


func _cizgi(ebeveyn: Control, y: float, w: float, kalinlik: float) -> void:
	var c := ColorRect.new()
	c.color = Color(Stil.MUREKKEP, 0.85)
	c.position = Vector2(KENAR, y)
	c.size = Vector2(w, kalinlik)
	c.mouse_filter = MOUSE_FILTER_IGNORE
	ebeveyn.add_child(c)


# --- Sicil özeti ---

func _sicili_kur(ortada: bool) -> Control:
	var kart := Control.new()
	kart.name = "Sicil"
	kart.position = SICIL.position + (Vector2(0, 190) if ortada else Vector2.ZERO)
	kart.size = SICIL.size
	kart.pivot_offset = SICIL.size / 2.0
	kart.rotation = deg_to_rad(1.1)
	kart.mouse_filter = MOUSE_FILTER_IGNORE
	kart.draw.connect(func() -> void:
		Kagit.ciz(kart, Rect2(Vector2.ZERO, SICIL.size), "daktilo_sayfa", Stil.KAGIT, 12.0, 3.0))
	add_child(kart)

	var baslik := Stil.etiket("SİCİL ÖZETİ", 17, Stil.BORDO, Stil.daktilo_kalin())
	baslik.position = Vector2(0, 40)
	baslik.size = Vector2(SICIL.size.x, 22)
	baslik.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kart.add_child(baslik)
	var t: Dictionary = Oyun.toplam
	var suphe := "yok" if Oyun.suphe <= 0 else ("az" if Oyun.suphe <= Oyun.TERFI_SUPHESI else ("var" if Oyun.suphe < Oyun.SURGUN_SUPHESI else "çok"))
	var satirlar := [
		["Çalışılan gün", str(Oyun.gun)],
		["İşlem gören vatandaş", str(int(t.get("islenen", 0)))],
		["Doğru işlem", str(int(t.get("dogru", 0)))],
		["Toplam ihtar", str(Oyun.ihtar)],
		["Hakkındaki şüphe", suphe],
		["Eldeki para", Stil.tl(Oyun.para)],
	]
	var y := 70.0
	for s: Array in satirlar:
		var nokta := maxi(2, 36 - str(s[0]).length() - str(s[1]).length())
		var l := Stil.etiket("%s %s %s" % [s[0], ".".repeat(nokta), s[1]], 13, Stil.MUREKKEP)
		l.position = Vector2(38, y)
		kart.add_child(l)
		y += 21.0
	return kart


# --- Hüsnü Amca'nın mektubu ---

func _mektubu_kur(metin: String) -> Control:
	var kagit := Mektup.new()
	add_child(kagit)
	kagit.kur(metin)
	kagit.position = MEKTUP.position
	kagit.rotation = deg_to_rad(-1.6)
	return kagit
