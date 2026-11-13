extends Control
## Ana menü: kar altındaki nüfus müdürlüğü binası. Menünün kendisi gökyüzüne iliştirilmiş bir müdürlük
## yazısıdır: antet, daktiloyla harf harf yazılan başlık, konu ve sayı satırı, numaralı seçenekler
## (Yeni Oyun, Devam, Ayarlar, Çıkış), altta müdürün imzası ve dairenin mührü. Üstüne gelinen seçeneğin
## kutusuna işaret konur. Sürüm bilgisi, masadaki etiketler gibi kabartma bir şerittedir.
##
## Sahne canlıdır: kar üç katman hâlinde rüzgârla savrulur (Kar.gd), bacalardan duman tüter ve
## rüzgâra göre yatar, sokak lambası arada bir cızırdayıp titrer; ışığından geçen kar taneleri parlar.
## Kapının üstündeki işlemeli tabela arka plan görselinin parçasıdır.

const ARKA_PLAN := "res://assets/img/menu_arkaplan.webp"
const BASLIK_TR := "NÖBETÇİ MEMUR"
var BASLIK := ""                               ## başlığın seçili dildeki hâli (harf harf yazılır)
const LAMBA := Vector2(564, 363)               ## sokak lambasının ampulü
const LAMBA_DIBI := Vector2(548, 664)          ## direğin dibinde, karın üstündeki ışık gölü
## Bacalar: [ağzın yeri, ölçek]. İlk ikisi müdürlük binasının, ötekiler uzaktaki evlerin bacaları.
const BACALAR := [
	[Vector2(754, 127), 1.0], [Vector2(1047, 76), 1.0],
	[Vector2(238, 481), 0.26], [Vector2(442, 496), 0.24], [Vector2(133, 485), 0.2], [Vector2(545, 483), 0.2],
]
const YAZI_HIZI := 9.0                         ## başlık: saniyede harf
const KAGIT := Vector2(452, 420)               ## menü kâğıdının boyutu
const KAGIT_YERI := Vector2(36, 12)
const KENAR := 52.0                            ## kâğıdın yazı kenar boşluğu
const SATIR := Vector2(364, 32)                ## bir seçenek satırının boyutu

var _baslik: Label
var _kagit: Control
var _konu: Label
var _aciklama: Label
var _ana_satirlar: Array[Button] = []          ## Yeni Oyun, Devam, Ayarlar, Çıkış
var _kip_satirlari: Array[Button] = []         ## Kolay, Orta, Zor, Vazgeç
var _gorunen := 0.0
var _yaziyor := true
var _sonrakiler: Array[Control] = []           ## başlık bitince sırayla beliren öğeler
var _yeni: Button
var _devam: Button
var _isik: Control
var _golge: Control                            ## lamba sönükken ampulü ve çevresini karartır
var _kar: Kar
var _dumanlar: Array[CPUParticles2D] = []
var _duman_duzeyi := -1
var _parlaklik := 1.0                          ## lambanın o anki parlaklığı (0 sönük .. 1 yanıyor)
var _cizirti_kalan := 0.0                      ## süren cızırtının kalan süresi
var _cizirtiya := 2.6                          ## bir sonraki cızırtıya kalan süre
var _titreme := 0.0
var _hale_dokusu: Texture2D
var _onay_bekliyor := false


func _ready() -> void:
	Ses.yalniz(["ruzgar"])
	Ses.ortam("ruzgar", -12.0, 2.0)
	Ses.muzik(["ney", "taksim"], -4.0, false, 3.0)

	var zemin := TextureRect.new()
	zemin.name = "ArkaPlan"
	zemin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	zemin.size = Yerlesim.EKRAN.size
	zemin.mouse_filter = MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(ARKA_PLAN):
		zemin.texture = Gorsel.yukle(ARKA_PLAN)
	else:
		zemin.modulate = Stil.DUVAR_KOYU
	add_child(zemin)

	_dumani_kur()
	_hale_dokusu = _hale_uret()

	# sokak lambası: sönükken ampulü karartan katman ve yanarken ışığı ekleyen katman
	_golge = Control.new()
	_golge.mouse_filter = MOUSE_FILTER_IGNORE
	_golge.draw.connect(_golgeyi_ciz)
	add_child(_golge)
	_isik = Control.new()
	_isik.mouse_filter = MOUSE_FILTER_IGNORE
	var ekle := CanvasItemMaterial.new()
	ekle.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_isik.material = ekle
	_isik.draw.connect(_isigi_ciz)
	add_child(_isik)

	_kar = Kar.new()
	_kar.name = "Kar"
	_kar.isik = LAMBA
	add_child(_kar)

	_kagidi_kur()
	_kunyeyi_kur()
	for s in _sonrakiler:
		s.modulate.a = 0.0


# --- Menü kâğıdı ---

## Kâğıt yukarıdan süzülerek yerine oturur; antet hemen görünür, başlık yazılır, gerisi ardından belirir.
func _kagidi_kur() -> void:
	_kagit = Control.new()
	_kagit.name = "MenuKagidi"
	_kagit.size = KAGIT
	_kagit.pivot_offset = KAGIT / 2.0
	_kagit.mouse_filter = MOUSE_FILTER_IGNORE
	_kagit.draw.connect(func() -> void: Kagit.ciz(_kagit, Rect2(Vector2.ZERO, KAGIT), "daktilo_sayfa", Stil.KAGIT, 6.0, 4.0))
	add_child(_kagit)
	var w := KAGIT.x - 2.0 * KENAR

	_yaz("T.C.", Rect2(0, 47, KAGIT.x, 14), 11, Stil.MUREKKEP_SOLUK, Stil.serif_kalin(), HORIZONTAL_ALIGNMENT_CENTER)
	_yaz("ARDIÇLI İLÇESİ NÜFUS MÜDÜRLÜĞÜ", Rect2(0, 61, KAGIT.x, 18), 13, Stil.MUREKKEP, Stil.serif_kalin(), HORIZONTAL_ALIGNMENT_CENTER)
	_cizgi(Rect2(KENAR, 84, w, 1.5), 0.75)

	BASLIK = Dil.c(BASLIK_TR)
	_baslik = _yaz(BASLIK, Rect2(0, 88, KAGIT.x, 56), 44, Stil.MUREKKEP, Stil.daktilo_kalin(), HORIZONTAL_ALIGNMENT_CENTER)
	_baslik.name = "Baslik"
	_baslik.visible_characters = 0
	_baslik.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING   # yazarken kelimeler satır değiştirmesin

	_konu = _yaz("Konu : Yedi günlük gişe nöbeti", Rect2(KENAR, 148, w, 16), 12, Stil.MUREKKEP, Stil.daktilo_kalin())
	_sonrakiler.append(_konu)
	_sonrakiler.append(_yaz("Sayı : 1984/1", Rect2(KENAR, 148, w, 16), 12, Stil.MUREKKEP, Stil.daktilo(), HORIZONTAL_ALIGNMENT_RIGHT))
	_aciklama = _yaz("Ardıçlı, Ocak 1984", Rect2(KENAR, 165, w, 14), 11, Stil.MUREKKEP_SOLUK, Stil.daktilo_italik())
	_sonrakiler.append(_aciklama)
	_sonrakiler.append(_cizgi(Rect2(KENAR, 184, w, 1.0), 0.4))

	var y := 194.0
	_yeni = _secenek("YeniOyun", "Yeni Oyun", 1, y)
	_yeni.pressed.connect(_yeni_oyun)
	y += 36.0
	_devam = _secenek("Devam", "Devam", 2, y)
	_devam.disabled = not Oyun.kayit_var_mi()
	_devam.pressed.connect(_devam_et)
	y += 36.0
	_secenek("Ayarlar", "Ayarlar", 3, y).pressed.connect(_ayarlari_ac)
	y += 36.0
	if not OS.has_feature("web"):
		_secenek("Cikis", "Çıkış", 4, y).pressed.connect(func() -> void: Oyun.cik())

	# görev şekli satırları: "Yeni Oyun" denince ana satırların yerine gelir
	y = 194.0
	var no := 1
	for kod: String in Oyun.KIPLER:
		var bilgi: Dictionary = Oyun.KIPLER[kod]
		var d := _secenek("Zorluk" + kod.capitalize(), str(bilgi.ad), no, y, true)
		d.pressed.connect(_oyunu_baslat.bind(kod))
		d.mouse_entered.connect(func() -> void: _aciklama.text = str(bilgi.aciklama))
		y += 36.0
		no += 1
	_secenek("ZorlukGeri", "Vazgeç", no, y, true).pressed.connect(_kipleri_goster.bind(false))

	# imza ve mühür
	var alt := Control.new()
	alt.name = "ImzaVeMuhur"
	alt.position = Vector2(KENAR, 334)
	alt.size = Vector2(w, 66)
	alt.mouse_filter = MOUSE_FILTER_IGNORE
	alt.draw.connect(_imzayi_ciz.bind(alt))
	_kagit.add_child(alt)
	_sonrakiler.append(alt)

	# giriş: kâğıt yukarıdan süzülüp hafif yan yatar
	_kagit.position = KAGIT_YERI + Vector2(0, -46)
	_kagit.rotation = deg_to_rad(1.6)
	_kagit.modulate.a = 0.0
	var t := create_tween().set_parallel()
	t.tween_property(_kagit, "position", KAGIT_YERI, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_kagit, "rotation", deg_to_rad(-1.5), 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(_kagit, "modulate:a", 1.0, 0.3)


func _yaz(metin: String, alan: Rect2, punto: int, renk: Color, font: Font = null,
		hiza: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Stil.etiket(metin, punto, renk, font)
	l.horizontal_alignment = hiza
	l.clip_text = true
	_kagit.add_child(l)
	l.position = alan.position
	l.size = alan.size
	return l


func _cizgi(alan: Rect2, koyuluk: float) -> ColorRect:
	var c := ColorRect.new()
	c.color = Color(Stil.MUREKKEP, koyuluk)
	c.position = alan.position
	c.size = alan.size
	c.mouse_filter = MOUSE_FILTER_IGNORE
	_kagit.add_child(c)
	return c


## Müdürün dolma kalem imzası (sağda) ve dairenin mor ıstampa mührü (solda, hafif yamuk basılmış).
func _imzayi_ciz(alt: Control) -> void:
	var b := alt.size
	Imza.ciz(alt, Rect2(b.x - 150.0, -12.0, 136.0, 56.0), "mudur", Stil.MAVI_MUREKKEP)
	alt.draw_string(Stil.daktilo_kalin(), Vector2(b.x - 150.0, 54.0), Dil.c("Müdür"), HORIZONTAL_ALIGNMENT_CENTER, 136.0, 12, Stil.MUREKKEP)
	Damga.ciz(alt, Rect2(2, -12, 92, 78), "daire", "", deg_to_rad(-12.0), 0.78)


## Sürüm ve uyarı: masadaki etiketler gibi kabartma şerit.
func _kunyeyi_kur() -> void:
	var metin := Dil.c("SÜRÜM %s  ·  BÜTÜN KİŞİ, KURUM VE OLAYLAR KURMACADIR") % str(ProjectSettings.get_setting("application/config/version", "1.0"))
	var kunye := Stil.etiket(metin, 11, Stil.KAGIT_BEYAZ, Stil.daktilo_kalin())
	kunye.name = "Kunye"
	kunye.add_theme_stylebox_override("normal", Stil.bosluklu(Stil.kutu(Color("1d1b19"), Color(0, 0, 0, 0.5), 1, 2, 2), 8, 3))
	add_child(kunye)
	kunye.position = Vector2(16, 692)
	kunye.rotation = deg_to_rad(-0.5)


func _process(delta: float) -> void:
	_lambayi_guncelle(delta)
	# duman rüzgâra göre yatar
	for d in _dumanlar:
		d.gravity = Vector2((3.0 + _kar.ruzgar * 0.42) * d.scale.x, -3.0 * d.scale.x)
	if not _yaziyor:
		return
	var once := int(_gorunen)
	_gorunen += YAZI_HIZI * delta
	_baslik.visible_characters = mini(BASLIK.length(), int(_gorunen))
	if int(_gorunen) != once and int(_gorunen) <= BASLIK.length() and BASLIK[int(_gorunen) - 1] != " ":
		Ses.cal("daktilo", 1.0, -10.0, 0.08)
	if _gorunen >= BASLIK.length():
		_basligi_bitir()


## Tıklayınca ya da bir tuşa basınca başlık beklemeden tamamlanır.
func _unhandled_input(event: InputEvent) -> void:
	if _yaziyor and ((event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed)):
		_basligi_bitir()


func _basligi_bitir() -> void:
	if not _yaziyor:
		return
	_yaziyor = false
	_baslik.visible_characters = -1
	for i in _sonrakiler.size():
		var t := create_tween()
		t.tween_interval(0.10 + i * 0.07)
		t.tween_property(_sonrakiler[i], "modulate:a", 1.0, 0.25)


## Yazıdaki numaralı bir satır: "1. Yeni Oyun ........ [ ]". Üstüne gelinince satır bordoya döner ve
## kutusuna işaret konur; kullanılamayan satır soluk yazılır, yanına kurşun kalemle not düşülür.
func _secenek(ad: String, metin: String, no: int, y: float, kip_satiri: bool = false) -> Button:
	var d := Button.new()
	d.name = ad
	d.text = "%d. %s" % [no, Dil.c(metin)]
	d.focus_mode = FOCUS_NONE
	d.alignment = HORIZONTAL_ALIGNMENT_LEFT
	d.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	d.add_theme_font_override("font", Stil.daktilo_kalin())
	d.add_theme_font_size_override("font_size", 20)
	d.add_theme_color_override("font_color", Stil.MUREKKEP)
	d.add_theme_color_override("font_hover_color", Stil.BORDO)
	d.add_theme_color_override("font_pressed_color", Stil.BORDO)
	d.add_theme_color_override("font_hover_pressed_color", Stil.BORDO)
	d.add_theme_color_override("font_disabled_color", Color(Stil.MUREKKEP, 0.42))
	for durum: String in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		var kutu := StyleBoxEmpty.new()
		kutu.content_margin_left = 8.0
		d.add_theme_stylebox_override(durum, kutu)
	_kagit.add_child(d)
	d.position = Vector2(KENAR - 8.0, y)
	d.size = SATIR
	var sus := Control.new()
	sus.name = "Sus"
	sus.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	sus.mouse_filter = MOUSE_FILTER_IGNORE
	sus.draw.connect(_satiri_ciz.bind(d, sus))
	d.add_child(sus)
	d.mouse_entered.connect(func() -> void:
		sus.queue_redraw()
		if not d.disabled:
			Ses.cal("tik", 1.25, -12.0))
	d.mouse_exited.connect(sus.queue_redraw)
	d.button_down.connect(sus.queue_redraw)
	d.button_up.connect(sus.queue_redraw)
	if kip_satiri:
		d.visible = false
		_kip_satirlari.append(d)
	else:
		_ana_satirlar.append(d)
		_sonrakiler.append(d)
	return d


## Satırın süsü: noktalı kılavuz çizgisi, işaret kutusu ve üstüne gelinince konan işaret.
func _satiri_ciz(d: Button, sus: Control) -> void:
	var b := d.size
	var font := Stil.daktilo_kalin()
	var yazi_eni := font.get_string_size(Dil.c(d.text), HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var kutu := Rect2(b.x - 30.0, 7.0, 18.0, 18.0)
	var secili := d.is_hovered() and not d.disabled
	var murekkep := Color(Stil.BORDO if secili else Stil.MUREKKEP, 0.42 if d.disabled else 0.85)
	if secili:
		sus.draw_rect(Rect2(0, 1, b.x, b.y - 2), Color(Stil.BORDO, 0.07))
	var x := 8.0 + yazi_eni + 12.0
	if d.disabled:
		sus.draw_string(Stil.el_yazisi(), Vector2(x, 23.0), Dil.c("(kayıt yok)"), HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(Stil.MAVI_MUREKKEP, 0.85))
		x += 96.0
	while x < kutu.position.x - 8.0:
		sus.draw_circle(Vector2(x, 21.5), 1.0, Color(murekkep, murekkep.a * 0.7))
		x += 7.0
	sus.draw_rect(kutu, murekkep, false, 1.5)
	if secili:
		# kutuya kalemle atılmış işaret; basılıyken mühür gibi dolu
		var isaret := PackedVector2Array([kutu.position + Vector2(3, 9), kutu.position + Vector2(8, 15), kutu.position + Vector2(22, -5)])
		sus.draw_polyline(isaret, Stil.BORDO, 2.6, true)
		if d.button_pressed:
			sus.draw_arc(kutu.get_center(), 16.0, 0.0, TAU, 32, Color(Stil.BORDO, 0.8), 2.0, true)


# --- Sokak lambası ---

## Lamba çoğu zaman hafifçe titreyerek yanar; arada bir cızırdar: kısa bir süre hızla yanıp söner.
func _lambayi_guncelle(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var titrer := bool(Oyun.ayar("titreme"))
	if _cizirti_kalan > 0.0:
		_cizirti_kalan -= delta
		_titreme -= delta
		if not titrer:
			_parlaklik = 1.0            # titreyen ışıklar kapalı: lamba sabit yanar, yalnız sesi duyulur
		elif _titreme <= 0.0:
			_titreme = randf_range(0.025, 0.085)
			_parlaklik = [0.04, 0.12, 0.3, 0.55, 1.0, 1.0][randi() % 6]
		if _cizirti_kalan <= 0.0:
			_parlaklik = 1.0
	else:
		_parlaklik = 0.93 + 0.07 * sin(t * 27.0) * sin(t * 6.1) if titrer else 1.0
		_cizirtiya -= delta
		if _cizirtiya <= 0.0:
			_cizirtiya = randf_range(3.8, 9.5)
			_cizirti_kalan = randf_range(0.4, 1.15)
			_titreme = 0.0
			Ses.cal("cizirti", randf_range(0.92, 1.08), -14.0)
	_kar.isik_gucu = _parlaklik
	_isik.queue_redraw()
	_golge.queue_redraw()


## Yanan lambanın ışığı (eklemeli): ampulün halesi, aşağı doğru yayılan huzme ve karın üstündeki ışık gölü.
func _isigi_ciz() -> void:
	var b := _parlaklik
	_hale(LAMBA, Vector2(190, 190), Color(1.0, 0.78, 0.40, 0.34 * b))
	_hale(LAMBA, Vector2(64, 64), Color(1.0, 0.86, 0.55, 0.50 * b))
	_hale(LAMBA, Vector2(22, 22), Color(1.0, 0.96, 0.80, 0.85 * b))
	# huzme: ampulden yere açılan soluk bir yamuk
	_isik.draw_colored_polygon(PackedVector2Array([LAMBA + Vector2(-12, 4), LAMBA + Vector2(12, 4),
		LAMBA_DIBI + Vector2(118, 0), LAMBA_DIBI + Vector2(-86, 0)]), Color(1.0, 0.82, 0.48, 0.035 * b))
	# yerdeki ışık gölü: karın üstünde basık, yumuşak bir elips
	_hale(LAMBA_DIBI + Vector2(16, 0), Vector2(250, 44), Color(1.0, 0.80, 0.45, 0.30 * b))


## Merkezi parlak, kenara doğru sönen yumuşak ışık lekesi.
func _hale(merkez: Vector2, boyut: Vector2, renk: Color) -> void:
	_isik.draw_texture_rect(_hale_dokusu, Rect2(merkez - boyut / 2.0, boyut), false, renk)


## Sönen lamba: resimdeki yanık ampul ve halesi karartılır.
func _golgeyi_ciz() -> void:
	var s := clampf(1.0 - _parlaklik, 0.0, 1.0)
	if s < 0.02:
		return
	_golge.draw_texture_rect(_hale_dokusu, Rect2(LAMBA + Vector2(-80, -70), Vector2(160, 160)), false, Color(0.30, 0.29, 0.34, 0.50 * s))
	_golge.draw_circle(LAMBA, 8.5, Color(0.30, 0.25, 0.20, 0.78 * s))


# --- Baca dumanı ---

## Her bacanın ağzına bir duman kaynağı konur. Kümeler yükseldikçe büyür, döner ve dağılır.
func _dumani_kur() -> void:
	for b: Array in BACALAR:
		var d := KasabaSahnesi.duman(b[0], float(b[1]))
		add_child(d)
		_dumanlar.append(d)
	_dumani_ayarla()
	Oyun.ayarlar_degisti.connect(_dumani_ayarla)


## Baca dumanının yoğunluğu efekt kalitesine uyar: düşükte uzak bacalar tütmez, yakındakiler seyrelir.
func _dumani_ayarla() -> void:
	var duzey := Oyun.efekt_duzeyi()
	if duzey == _duman_duzeyi:
		return
	_duman_duzeyi = duzey
	for d in _dumanlar:
		var tam := int(d.get_meta("tam_adet", 22))
		d.visible = duzey > 0               # düşükte bacalar tütmez
		d.amount = maxi(6, roundi(tam * [0.4, 0.7, 1.0][duzey]))


# --- Seçenekler ---

func _yeni_oyun() -> void:
	# Kayıt varsa üstüne yazmadan önce bir kez daha sorulur.
	if Oyun.kayit_var_mi() and not _onay_bekliyor:
		_onay_bekliyor = true
		_yeni.text = "1. Eski kayıt silinsin mi?"
		_yeni.add_theme_color_override("font_color", Stil.BORDO)
		Oyun.bekle(4.0).connect(func() -> void:
			_onay_bekliyor = false
			_yeni.text = "1. Yeni Oyun"
			_yeni.add_theme_color_override("font_color", Stil.MUREKKEP))
		return
	_kipleri_goster(true)


## Ana satırların yerine görev şekli satırlarını getirir (ya da geri alır).
func _kipleri_goster(acik: bool) -> void:
	_onay_bekliyor = false
	_yeni.text = "1. Yeni Oyun"
	_yeni.add_theme_color_override("font_color", Stil.MUREKKEP)
	for d in _ana_satirlar:
		d.visible = not acik
	for d in _kip_satirlari:
		d.visible = acik
	_konu.text = "Konu : Görev şekli" if acik else "Konu : Yedi günlük gişe nöbeti"
	_aciklama.text = "Nasıl bir mesai istersiniz?" if acik else "Ardıçlı, Ocak 1984"
	Ses.cal("sayfa", 1.0, -6.0, 0.05)


func _oyunu_baslat(gorev_sekli: String) -> void:
	Oyun.yeni_oyun(gorev_sekli)
	Oyun.sahneye_gec("masa")


func _devam_et() -> void:
	if not Oyun.yukle():
		return
	# kayıt hangi aşamada alındıysa oradan sürer: sabah, kapanmış mesainin puantajı ya da oyunun sonu
	match Oyun.asama:
		"gun_sonu":
			Oyun.sahneye_gec("gun_sonu")
		"son":
			Oyun.oyunu_bitir(Oyun.son)
		_:
			Oyun.sahneye_gec("masa")


func _ayarlari_ac() -> void:
	if find_child("AyarlarPenceresi", false, false) != null:
		return
	add_child(AyarlarPenceresi.new())


static func _hale_uret() -> Texture2D:
	var gecis := Gradient.new()
	gecis.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 1.0])
	gecis.colors = PackedColorArray([Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.42), Color(1, 1, 1, 0.10), Color(1, 1, 1, 0.0)])
	var doku := GradientTexture2D.new()
	doku.gradient = gecis
	doku.fill = GradientTexture2D.FILL_RADIAL
	doku.fill_from = Vector2(0.5, 0.5)
	doku.fill_to = Vector2(1.0, 0.5)
	doku.width = 128
	doku.height = 128
	return doku
