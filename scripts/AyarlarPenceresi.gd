class_name AyarlarPenceresi
extends Control
## Ayarlar: daktilo sayfasına yazılmış, sekmeli bir form. Dört yaprağı vardır: SES, GÖRÜNTÜ, OYUN ve
## KONTROLLER. Düzeyler kutucuklu kademelerle, seçenekler köşeli ayraçlı daktilo yazısıyla, açık/kapalı
## ayarlar işaret kutusuyla gösterilir. Ana menüden ve mola menüsünden açılır; oyun dururken de çalışır.
##
## Yapraklar ve satırları aşağıdaki SAYFALAR tablosundan kurulur; yeni bir ayar eklemek için tabloya bir
## satır, Oyun.VARSAYILAN_AYARLAR'a bir varsayılan yazmak yeter.

signal kapandi

const KAGIT := Vector2(640, 640)
const SOL := 58.0                ## satır adlarının başladığı yer
const DEGER_X := 250.0           ## kademelerin ve seçeneklerin başladığı yer
const SATIR := 37.0
## tur: "kademe" (0..1 düzey) | "secenek" (birkaç değerden biri) | "isaret" (açık/kapalı)
## masaustu: tarayıcıda gösterilmez (pencere, dikey eşleme ve imleç tarayıcının elindedir)
const SAYFALAR := [
	{"kod": "ses", "ad": "SES", "satirlar": [
		{"tur": "kademe", "ad": "Genel ses", "anahtar": "ses_genel"},
		{"tur": "kademe", "ad": "Efektler", "anahtar": "ses_efekt"},
		{"tur": "kademe", "ad": "Konuşma", "anahtar": "ses_konusma"},
		{"tur": "kademe", "ad": "Müzik", "anahtar": "ses_muzik"},
		{"tur": "kademe", "ad": "Ortam", "anahtar": "ses_ortam", "not": "soba, rüzgâr"},
		{"tur": "isaret", "ad": "Müzik çalsın", "anahtar": "muzik_acik", "not": "radyo ve menü müziği"},
	]},
	{"kod": "goruntu", "ad": "GÖRÜNTÜ", "satirlar": [
		{"tur": "isaret", "ad": "Tam ekran", "anahtar": "tam_ekran", "masaustu": true, "not": "F11"},
		{"tur": "secenek", "ad": "Pencere boyutu", "anahtar": "pencere_boyutu", "masaustu": true,
			"secenekler": [["1280×720", "1280x720"], ["1600×900", "1600x900"], ["1920×1080", "1920x1080"]]},
		{"tur": "isaret", "ad": "Dikey eşleme", "anahtar": "dikey_esleme", "masaustu": true, "not": "görüntü yırtılmasını önler"},
		{"tur": "secenek", "ad": "Kare sınırı", "anahtar": "kare_siniri", "not": "düşük sınır pili ve fanı korur",
			"secenekler": [["30", 30], ["60", 60], ["120", 120], ["yok", 0]]},
		{"tur": "secenek", "ad": "Efekt kalitesi", "anahtar": "efekt_kalitesi", "not": "kar ve duman yoğunluğu",
			"secenekler": [["düşük", "dusuk"], ["orta", "orta"], ["yüksek", "yuksek"]]},
		{"tur": "isaret", "ad": "Ekran sarsıntısı", "anahtar": "ekran_sarsintisi", "not": "mühür inince"},
		{"tur": "isaret", "ad": "Titreyen ışıklar", "anahtar": "titreme", "not": "lamba, uyarı ışıkları"},
	]},
	{"kod": "oyun", "ad": "OYUN", "satirlar": [
		{"tur": "secenek", "ad": "Mesai saati", "anahtar": "saat_hizi", "onek": "Hiz", "not": "günün ne kadar sürdüğü",
			"secenekler": [["Sakin", 1.4], ["Olağan", 1.0], ["Telaşlı", 0.7]]},
		{"tur": "secenek", "ad": "Yazı hızı", "anahtar": "yazi_hizi", "not": "genelge, konuşma, teleks",
			"secenekler": [["yavaş", 0.6], ["olağan", 1.0], ["hızlı", 2.0], ["anında", 100.0]]},
		{"tur": "isaret", "ad": "Arka planda mola", "anahtar": "odakta_mola", "not": "pencereden çıkınca oyun durur"},
		{"tur": "secenek", "ad": "Fare hassasiyeti", "anahtar": "fare_hassasiyeti", "masaustu": true, "not": "imlecin hızı",
			"secenekler": [["0,5×", 0.5], ["0,75×", 0.75], ["1×", 1.0], ["1,5×", 1.5], ["2×", 2.0]]},
	]},
	{"kod": "kontrol", "ad": "KONTROLLER", "satirlar": []},
]
const KONTROLLER := [
	["Fare ile sürükle", "belgeyi masada taşır"],
	["Çift tık", "belgeyi ya da bilgi defterini büyütür"],
	["BOŞLUK", "inceleme: iki bilgiye tıkla, karşılaştır"],
	["Mührü bırak", "belgenin üstüne: yeşil onaylar, kırmızı reddeder"],
	["Havale pusulasını bırak", "şüpheli evrakı müdüre yollar"],
	["1 – 9", "gerekçe penceresinde gerekçeyi seçer"],
	["ENTER", "genelgeyi tamamlar, gişeyi açar"],
	["ESC", "mola; açık pencereyi kapatır"],
	["F11", "tam ekran"],
	["F12", "ekran görüntüsü"],
]

var sayfa := 0

var _kagit: Control
var _yapraklar: Array[Control] = []
var _sekmeler: Array[Button] = []
var _guncelleyiciler: Array[Callable] = []     ## her satırın görünümünü ayara göre tazeleyen işlevler


func _ready() -> void:
	name = "AyarlarPenceresi"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP

	var perde := ColorRect.new()
	perde.color = Color(0.07, 0.06, 0.05, 0.66)
	perde.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	perde.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(perde)

	_kagit = Control.new()
	_kagit.name = "Kagit"
	_kagit.size = KAGIT
	_kagit.position = (Yerlesim.EKRAN.size - KAGIT) / 2.0
	_kagit.pivot_offset = KAGIT / 2.0
	_kagit.rotation = deg_to_rad(-0.5)
	_kagit.mouse_filter = MOUSE_FILTER_IGNORE
	_kagit.draw.connect(func() -> void: Kagit.ciz(_kagit, Rect2(Vector2.ZERO, KAGIT), "daktilo_sayfa", Stil.KAGIT, 14.0, 4.0))
	add_child(_kagit)

	var w := KAGIT.x - 2.0 * SOL
	var baslik := Stil.etiket("AYARLAR", 22, Stil.BORDO, Stil.daktilo_kalin())
	baslik.position = Vector2(0, 58)
	baslik.size = Vector2(KAGIT.x, 28)
	baslik.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_kagit.add_child(baslik)

	# sekmeler: başlığın altında, daktiloyla yazılmış yaprak adları
	var sx := SOL
	for i in SAYFALAR.size():
		var d := _dugme("  %s  " % str(SAYFALAR[i].ad), 14, true)
		d.name = "AyarSekme_" + str(SAYFALAR[i].kod)
		d.position = Vector2(sx, 96.0)
		d.pressed.connect(sayfaya_gec.bind(i))
		_kagit.add_child(d)
		_sekmeler.append(d)
		sx += d.size.x + 6.0
	_cizgi(_kagit, SOL, 128.0, w)

	for s: Dictionary in SAYFALAR:
		var yaprak := Control.new()
		yaprak.name = "Yaprak_" + str(s.kod)
		yaprak.mouse_filter = MOUSE_FILTER_IGNORE
		yaprak.size = KAGIT
		_kagit.add_child(yaprak)
		_yapraklar.append(yaprak)
		if str(s.kod) == "kontrol":
			_kontrolleri_yaz(yaprak)
		else:
			_satirlari_kur(yaprak, s.satirlar)

	_cizgi(_kagit, SOL, KAGIT.y - 104.0, w)
	var sifirla := _dugme("[ varsayılana dön ]", 14)
	sifirla.name = "AyarSifirla"
	sifirla.position = Vector2(SOL, KAGIT.y - 92.0)
	sifirla.pressed.connect(func() -> void:
		Oyun.ayarlari_sifirla()
		Ses.cal("yirt", 1.0, -6.0)
		_guncelle())
	_kagit.add_child(sifirla)

	var tamam := Button.new()
	tamam.name = "AyarKapat"
	tamam.text = "Tamam"
	tamam.focus_mode = FOCUS_NONE
	tamam.custom_minimum_size = Vector2(170, 40)
	tamam.size = Vector2(170, 40)
	tamam.position = Vector2(KAGIT.x - SOL - 170.0, KAGIT.y - 96.0)
	tamam.pressed.connect(kapat)
	_kagit.add_child(tamam)

	sayfaya_gec(0, false)
	_guncelle()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.18)


func kapat() -> void:
	kapandi.emit()
	queue_free()


func sayfaya_gec(no: int, sesli: bool = true) -> void:
	sayfa = clampi(no, 0, _yapraklar.size() - 1)
	for i in _yapraklar.size():
		_yapraklar[i].visible = i == sayfa
		_sekmeler[i].add_theme_color_override("font_color", Stil.BORDO if i == sayfa else Stil.MUREKKEP_SOLUK)
		_sekmeler[i].add_theme_stylebox_override("normal",
			Stil.bosluklu(Stil.kutu(Color(Stil.BORDO, 0.10) if i == sayfa else Color(0, 0, 0, 0), Stil.BORDO if i == sayfa else Color(0, 0, 0, 0), 1, 2), 5, 4))
	if sesli:
		Ses.cal("sayfa", 1.0, -6.0, 0.05)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		kapat()


# --- Satırlar ---

func _satirlari_kur(yaprak: Control, satirlar: Array) -> void:
	var y := 150.0
	var tarayici := OS.has_feature("web")
	for s: Dictionary in satirlar:
		if tarayici and bool(s.get("masaustu", false)):
			continue
		var anahtar := str(s.anahtar)
		var ad := Stil.etiket(str(s.ad), 15, Stil.MUREKKEP)
		ad.position = Vector2(SOL, y)
		yaprak.add_child(ad)
		if s.has("not"):
			var aciklama := Stil.etiket(str(s["not"]), 10, Stil.MUREKKEP_SOLUK, Stil.daktilo_italik())
			aciklama.position = Vector2(SOL, y + 18.0)
			yaprak.add_child(aciklama)
		match str(s.tur):
			"kademe":
				var k := Kademe.new()
				k.name = "Kademe_" + anahtar
				k.position = Vector2(DEGER_X, y - 1.0)
				k.degisti.connect(_duzey_degisti.bind(anahtar))
				yaprak.add_child(k)
				var yuzde := Stil.etiket("", 12, Stil.MUREKKEP_SOLUK)
				yuzde.position = Vector2(DEGER_X + k.size.x + 8.0, y + 2.0)
				yaprak.add_child(yuzde)
				_guncelleyiciler.append(func() -> void:
					k.deger = float(Oyun.ayar(anahtar))
					yuzde.text = "%%%d" % roundi(float(Oyun.ayar(anahtar)) * 100.0))
			"isaret":
				var d := _dugme("[ ] kapalı", 15)
				d.name = "TamEkran" if anahtar == "tam_ekran" else "Isaret_" + anahtar
				d.position = Vector2(DEGER_X - 5.0, y - 5.0)
				d.pressed.connect(func() -> void:
					Oyun.ayar_degistir(anahtar, not bool(Oyun.ayar(anahtar)))
					Ses.cal("tik", 1.0, -4.0)
					_guncelle())
				yaprak.add_child(d)
				_guncelleyiciler.append(func() -> void:
					var acik := bool(Oyun.ayar(anahtar))
					d.text = "[x] açık" if acik else "[ ] kapalı"
					d.add_theme_color_override("font_color", Stil.BORDO if acik else Stil.MUREKKEP))
			"secenek":
				var x := DEGER_X - 5.0
				var onek := str(s.get("onek", "Sec_" + anahtar))
				for secenek: Array in s.secenekler:
					var deger: Variant = secenek[1]
					var yazi := str(secenek[0])
					var d := _dugme(" %s " % yazi, 15)
					d.name = "%s_%s" % [onek, yazi]
					d.position = Vector2(x, y - 5.0)
					d.pressed.connect(func() -> void:
						Oyun.ayar_degistir(anahtar, deger)
						Ses.cal("tik", 1.0, -4.0)
						_guncelle())
					yaprak.add_child(d)
					x += d.size.x + 1.0
					_guncelleyiciler.append(func() -> void:
						var secili := _ayni(Oyun.ayar(anahtar), deger)
						d.text = ("[%s]" if secili else " %s ") % yazi
						d.add_theme_color_override("font_color", Stil.BORDO if secili else Stil.MUREKKEP))
		y += SATIR + (9.0 if s.has("not") else 0.0)


func _kontrolleri_yaz(yaprak: Control) -> void:
	var y := 152.0
	for satir: Array in KONTROLLER:
		var tus := Stil.etiket(str(satir[0]), 14, Stil.BORDO, Stil.daktilo_kalin())
		tus.position = Vector2(SOL, y)
		yaprak.add_child(tus)
		var is_ := Stil.etiket(str(satir[1]), 13, Stil.MUREKKEP)
		is_.position = Vector2(DEGER_X + 12.0, y + 1.0)
		yaprak.add_child(is_)
		y += 30.0


func _duzey_degisti(deger: float, anahtar: String) -> void:
	Oyun.ayar_degistir(anahtar, deger)
	# ayarlanan düzeyin örneği duyulsun
	match anahtar:
		"ses_muzik", "ses_ortam":
			Ses.cal("zil", 1.0, -10.0)
		"ses_konusma":
			Ses.cal("hece", 1.5, -6.0)
		_:
			Ses.cal("muhur", 1.0, -5.0)
	_guncelle()


func _guncelle() -> void:
	for g in _guncelleyiciler:
		g.call()


## Ayar değeri seçenekle aynı mı? (Sayılar değerce, metinler birebir karşılaştırılır.)
static func _ayni(a: Variant, b: Variant) -> bool:
	var a_sayi := typeof(a) == TYPE_INT or typeof(a) == TYPE_FLOAT
	var b_sayi := typeof(b) == TYPE_INT or typeof(b) == TYPE_FLOAT
	if a_sayi and b_sayi:
		return is_equal_approx(float(a), float(b))
	return typeof(a) == typeof(b) and a == b


func _cizgi(ebeveyn: Control, x: float, y: float, w: float) -> void:
	var c := ColorRect.new()
	c.color = Color(Stil.MUREKKEP, 0.7)
	c.position = Vector2(x, y)
	c.size = Vector2(w, 1.5)
	c.mouse_filter = MOUSE_FILTER_IGNORE
	ebeveyn.add_child(c)


## Daktiloyla yazılmış gibi duran, çerçevesiz düğme (seçenekler, işaret kutuları, sekmeler).
func _dugme(metin: String, punto: int, kalin: bool = false) -> Button:
	var d := Button.new()
	d.text = metin
	d.focus_mode = FOCUS_NONE
	d.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	d.add_theme_font_override("font", Stil.daktilo_kalin() if kalin else Stil.daktilo())
	d.add_theme_font_size_override("font_size", punto)
	d.add_theme_color_override("font_hover_color", Stil.BORDO)
	for durum: String in ["normal", "pressed", "focus", "disabled"]:
		d.add_theme_stylebox_override(durum, Stil.bosluklu(Stil.kutu(Color(0, 0, 0, 0)), 5, 4))
	d.add_theme_stylebox_override("hover", Stil.bosluklu(Stil.kutu(Color(Stil.BORDO, 0.08)), 5, 4))
	d.size = d.get_combined_minimum_size()
	return d


## On kutucuklu kademe: ses düzeyi gibi 0..1 arası bir değeri tıklayarak ya da sürükleyerek ayarlar.
class Kademe extends Control:
	signal degisti(deger: float)

	const ADET := 10
	const KUTU := Vector2(19, 18)
	const ARALIK := 4.0

	var deger := 1.0:
		set(d):
			deger = clampf(d, 0.0, 1.0)
			queue_redraw()

	var _suruyor := false

	func _init() -> void:
		size = Vector2(ADET * (KUTU.x + ARALIK), KUTU.y + 4.0)
		custom_minimum_size = size
		mouse_default_cursor_shape = CURSOR_POINTING_HAND

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			_suruyor = event.pressed
			if event.pressed:
				_ayarla(event.position.x)
			accept_event()
		elif event is InputEventMouseMotion and _suruyor:
			_ayarla(event.position.x)
			accept_event()

	func _ayarla(x: float) -> void:
		var yeni := clampf(ceilf(x / (KUTU.x + ARALIK)), 0.0, ADET) / ADET
		if x < 5.0:
			yeni = 0.0
		if not is_equal_approx(yeni, deger):
			deger = yeni
			degisti.emit(deger)

	func _draw() -> void:
		var dolu := roundi(deger * ADET)
		for i in ADET:
			var r := Rect2(i * (KUTU.x + ARALIK), 2.0, KUTU.x, KUTU.y)
			if i < dolu:
				draw_rect(r, Color(Stil.MUREKKEP, 0.88))
			draw_rect(r, Stil.MUREKKEP, false, 1.4)
