class_name KonusmaBalonu
extends Control
## Gişe camının yanındaki konuşma balonu. Metni harf harf yazar; kuyruğu cama bakar.

signal basladi          ## yazmaya başladı (vatandaşın ağzı oynar)
signal harf_yazildi
signal bitti            ## yazı tamamlandı (çok sayfalı sözde son sayfa)
signal duraksadi        ## bir sayfa bitti, sıradaki bekleniyor (ağız durur)

const HIZ := 42.0            ## saniyede harf
const PUNTO := 15
const IC_BOSLUK := Vector2(14, 11)
const EN_KUCUK_PUNTO := 12  ## tek sayfada bundan küçük punto kullanılmaz; sığmayan söz sayfalara bölünür
const SAYFA_PUNTO := 13     ## sayfalara bölünen sözün puntosu
const SAYFA_ARASI := 1.5    ## bir sayfa bittikten sonra sıradakine geçmeden önceki bekleme (sn)

var _yazi: Label
var _gorunen := 0.0
var _toplam := 0
var _yaziyor := false
var _kalan_sure := 0.0
var _kutu := Rect2()
var _sayfalar := PackedStringArray()   ## yazılmayı bekleyen sayfalar
var _bekleme := 0.0                    ## sayfa arası beklemenin kalanı
var _punto := PUNTO


func _ready() -> void:
	position = Yerlesim.BALON.position
	size = Yerlesim.BALON.size
	mouse_filter = MOUSE_FILTER_IGNORE
	visible = false
	_yazi = Stil.etiket("", PUNTO)
	_yazi.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# satırlar bütün metne göre kırılır, harfler sonra açılır: yazarken kelime satır değiştirmez ve
	# ölçüm, o an görünen harflere göre değil bütün söze göre yapılır
	_yazi.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_yazi.add_theme_constant_override("line_spacing", 1)
	add_child(_yazi)


## Metni yazmaya başlar. `sure` > 0 ise yazı bittikten o kadar saniye sonra balon kapanır.
## Söz balona sığmıyorsa önce punto küçülür (en çok EN_KUCUK_PUNTO'ya); yine sığmıyorsa cümle cümle
## sayfalara bölünür: her sayfa yazılır, kısa bir duraksamadan sonra sıradaki gelir. `bitti` yalnızca
## son sayfa yazılınca yayılır.
func soyle(metin: String, sure: float = 0.0) -> void:
	metin = Dil.c(metin).strip_edges()
	_sayfalar.clear()
	_bekleme = 0.0
	var punto := PUNTO
	while punto > EN_KUCUK_PUNTO and not _sigar_mi(metin, punto):
		punto -= 1
	if _sigar_mi(metin, punto):
		_sayfalar.append(metin)
	else:
		punto = SAYFA_PUNTO
		_sayfalar = _sayfala(metin, punto)
	_punto = punto
	_kalan_sure = sure
	_sayfayi_ac(true)


## Metin bu puntoyla balonun en geniş alanına sığar mı?
func _sigar_mi(metin: String, punto: int) -> bool:
	_yazi.add_theme_font_size_override("font_size", punto)
	_yazi.text = metin
	return Stil.sarili_yukseklik(_yazi, _yazi_eni()) <= _yazi_boyu()


## Metni cümle sınırlarından (gerekirse sözcük sınırlarından) balona sığan sayfalara böler.
func _sayfala(metin: String, punto: int) -> PackedStringArray:
	var parcalar := PackedStringArray()
	var rx := RegEx.new()
	rx.compile("[^.!?…;:]+[.!?…;:]*[\"»”']*\\s*")
	for m in rx.search_all(metin):
		var c := m.get_string().strip_edges()
		if c == "":
			continue
		if _sigar_mi(c, punto):
			parcalar.append(c)
		else:
			# tek cümle bile sığmıyor: sözcük sözcük böl
			var satir := ""
			for k in c.split(" ", false):
				var aday := (satir + " " + k).strip_edges()
				if satir != "" and not _sigar_mi(aday, punto):
					parcalar.append(satir)
					satir = k
				else:
					satir = aday
			if satir != "":
				parcalar.append(satir)
	var sayfalar := PackedStringArray()
	var sayfa := ""
	for c in parcalar:
		var aday := (sayfa + " " + c).strip_edges()
		if sayfa != "" and not _sigar_mi(aday, punto):
			sayfalar.append(sayfa)
			sayfa = c
		else:
			sayfa = aday
	if sayfa != "":
		sayfalar.append(sayfa)
	return sayfalar


func _yazi_eni() -> float:
	return size.x - 2.0 * IC_BOSLUK.x


func _yazi_boyu() -> float:
	return size.y - 2.0 * IC_BOSLUK.y - 4.0


## Sıradaki sayfayı balona koyar ve yazmaya başlar.
func _sayfayi_ac(ilk: bool) -> void:
	var metin := _sayfalar[0]
	_sayfalar.remove_at(0)
	_yazi.add_theme_font_size_override("font_size", _punto)
	_yazi.text = metin
	var en := _yazi_eni()
	var yukseklik := Stil.sarili_yukseklik(_yazi, en)
	var font := _yazi.get_theme_font("font")
	var genislik := 0.0
	for satir in _yazi.text.split("\n"):
		genislik = maxf(genislik, font.get_string_size(satir, HORIZONTAL_ALIGNMENT_LEFT, -1, _punto).x)
	if _yazi.get_line_count() > 1:
		genislik = en                       # sarılan yazı balonun bütün enini kullanır
	_kutu = Rect2(0, 0, minf(size.x, maxf(120.0, genislik + 2.0 * IC_BOSLUK.x + 6.0)),
		minf(size.y, yukseklik + 2.0 * IC_BOSLUK.y + 4.0))
	_yazi.position = IC_BOSLUK
	_yazi.size = Vector2(en, _kutu.size.y - 2.0 * IC_BOSLUK.y)
	_yazi.visible_characters = 0
	_gorunen = 0.0
	_toplam = metin.length()
	_yaziyor = true
	visible = true
	modulate.a = 1.0
	queue_redraw()
	basladi.emit()
	if not ilk:
		Ses.cal("kagit", 1.2, -18.0, 0.05)


## Ekranda kaç sayfa daha bekliyor (testler için).
func kalan_sayfa() -> int:
	return _sayfalar.size()


func sus() -> void:
	_sayfalar.clear()
	_bekleme = 0.0
	if _yaziyor:
		bitti.emit()
	_yaziyor = false
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	if _yaziyor:
		var once := int(_gorunen)
		_gorunen += HIZ * float(Oyun.ayar("yazi_hizi")) * delta
		_yazi.visible_characters = mini(_toplam, int(_gorunen))
		if int(_gorunen) != once and int(_gorunen) % 2 == 0:
			harf_yazildi.emit()
		if _gorunen >= _toplam:
			_yaziyor = false
			_yazi.visible_characters = -1
			if _sayfalar.is_empty():
				bitti.emit()
			else:
				_bekleme = SAYFA_ARASI
				duraksadi.emit()
	elif _bekleme > 0.0:
		_bekleme -= delta
		if _bekleme <= 0.0 and not _sayfalar.is_empty():
			_sayfayi_ac(false)
	elif _kalan_sure > 0.0:
		_kalan_sure -= delta
		if _kalan_sure <= 0.0:
			visible = false
		elif _kalan_sure < 0.3:
			modulate.a = _kalan_sure / 0.3


func _draw() -> void:
	var sb := Stil.kutu(Stil.KAGIT_BEYAZ, Stil.MUREKKEP, 2, 9, 5)
	draw_style_box(sb, _kutu)
	# cama bakan kuyruk
	var y := minf(_kutu.size.y - 24.0, 46.0)
	var uc := PackedVector2Array([Vector2(1, y), Vector2(-20, y + 13), Vector2(1, y + 18)])
	draw_colored_polygon(uc, Stil.KAGIT_BEYAZ)
	draw_polyline(PackedVector2Array([uc[0] + Vector2(0, -1), uc[1], uc[2] + Vector2(0, 1)]), Stil.MUREKKEP, 2.0, true)
