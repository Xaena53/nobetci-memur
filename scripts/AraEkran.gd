class_name AraEkran
extends Control
## Güne başlarken görünen geçiş ekranı: kasabadan canlı sahneler (kar yağar, bacalar tüter, lambalar
## titrer), altta daktiloyla yazılmış ipuçları.
##
## Sahneler ve ipuçları `data/ara_ekran.json` dosyasından gelir; oyuncu ekranda kaldıkça ikisi de
## değişir. Oyuncu tıklayınca (ya da "kısa" ayarında birkaç saniye sonra) `bitti` yayılır.
## Sahne geçişini `Oyun.sahneye_gec` yönetir; bu düğüm yalnızca görünümdür.

signal bitti

const VERI := "res://data/ara_ekran.json"
const DEGISIM := 6.5            ## bir ipucunun ekranda kalma süresi (sn)
const SAHNE_SURESI := 13.0      ## bir sahnenin ekranda kalma süresi (sn)
const KISA_SURE := 5.0          ## "kısa" ayarında ekranın toplam süresi (sn)
const GECIS := 1.4              ## iki sahne arasındaki erime (sn)
const TIK_BEKLEME := 0.45       ## ekran açıldıktan sonra tıklamanın sayılmaya başladığı an (sn)

var gun := 1
var kisa := false               ## tıklama beklemeden kendiliğinden geçer

var _sahneler: Array = []
var _ipuclari: Array = []
var _sahne_no := -1
var _ipucu_no := -1
var _sahne: KasabaSahnesi
var _sahne_katmani: Control
var _kar: Kar
var _kunye: Control
var _yer_adi: Label
var _ipucu: Label
var _devam: Label
var _ipucu_sayaci := 0.0
var _sahne_sayaci := 0.0
var _gecen := 0.0
var _calisiyor := false
var _bitti := false
var _zar := RandomNumberGenerator.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_zar.randomize()
	_veriyi_oku()
	_kur()
	_sonraki_sahne(true)
	_sonraki_ipucu(true)


func _veriyi_oku() -> void:
	var veri: Variant = Veri.oku(VERI)
	if typeof(veri) != TYPE_DICTIONARY:
		return
	for s: Variant in veri.get("sahneler", []):
		if typeof(s) == TYPE_DICTIONARY and ResourceLoader.exists(str(s.get("gorsel", ""))):
			_sahneler.append(s)
	for i: Variant in veri.get("ipuclari", []):
		if typeof(i) == TYPE_DICTIONARY and int(i.get("gun", 1)) <= gun and str(i.get("metin", "")) != "":
			_ipuclari.append(str(i.metin))
	# sıra her açılışta başka olsun
	_karistir(_sahneler)
	_karistir(_ipuclari)


func _karistir(dizi: Array) -> void:
	for i in range(dizi.size() - 1, 0, -1):
		var j := _zar.randi_range(0, i)
		var gecici: Variant = dizi[i]
		dizi[i] = dizi[j]
		dizi[j] = gecici


func _kur() -> void:
	var zemin := ColorRect.new()
	zemin.color = Stil.GECE
	zemin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	zemin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(zemin)
	_sahne_katmani = Control.new()
	_sahne_katmani.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sahne_katmani.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sahne_katmani.clip_contents = true
	add_child(_sahne_katmani)
	if not _sahneler.is_empty():
		_kar = Kar.new()
		_kar.name = "Kar"
		add_child(_kar)

	# sol üstte künye: kaçıncı gün, tarih, sahnenin adı
	var kunye := PanelContainer.new()
	kunye.add_theme_stylebox_override("panel", Stil.bosluklu(Stil.kutu(Stil.KAGIT, Stil.MUREKKEP_SOLUK, 1, 2, 8), 18, 10))
	kunye.position = Vector2(44, 40)
	kunye.rotation_degrees = -1.2
	kunye.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(kunye)
	_kunye = kunye
	var dizi := VBoxContainer.new()
	dizi.add_theme_constant_override("separation", 0)
	kunye.add_child(dizi)
	dizi.add_child(Stil.etiket(Dil.c("%d. GÜN") % gun, 30, Stil.BORDO, Stil.daktilo_kalin()))
	dizi.add_child(Stil.etiket(_tarih_metni(), 15, Stil.MUREKKEP, Stil.daktilo()))
	_yer_adi = Stil.etiket("", 14, Stil.MUREKKEP_SOLUK, Stil.daktilo_italik())
	dizi.add_child(_yer_adi)

	# altta ipucu kâğıdı: daktilo şeridi
	var serit := PanelContainer.new()
	serit.add_theme_stylebox_override("panel", Stil.bosluklu(Stil.kutu(Stil.KAGIT, Stil.MUREKKEP_SOLUK, 1, 2, 10), 24, 10))
	serit.position = Vector2(130, 622)
	serit.custom_minimum_size = Vector2(1020, 74)
	serit.size = Vector2(1020, 74)
	serit.rotation_degrees = 0.4
	serit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(serit)
	var satir := HBoxContainer.new()
	satir.add_theme_constant_override("separation", 22)
	serit.add_child(satir)
	var baslik := Stil.etiket("İPUCU", 17, Stil.BORDO, Stil.daktilo_kalin())
	baslik.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	satir.add_child(baslik)
	_ipucu = Stil.etiket("", 18, Stil.MUREKKEP, Stil.daktilo())
	_ipucu.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ipucu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ipucu.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_ipucu.custom_minimum_size = Vector2(860, 0)
	satir.add_child(_ipucu)

	_devam = Stil.etiket("devam etmek için tıklayın", 15, Stil.KAGIT, Stil.daktilo_italik())
	_devam.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_devam.add_theme_constant_override("shadow_offset_x", 1)
	_devam.add_theme_constant_override("shadow_offset_y", 2)
	_devam.add_theme_constant_override("shadow_outline_size", 6)
	_devam.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_devam.position = Vector2(936, 28)
	_devam.size = Vector2(300, 24)
	_devam.modulate.a = 0.0
	_devam.visible = not kisa
	add_child(_devam)


## "09.01.1984" → "9 Ocak 1984, Pazartesi"
func _tarih_metni() -> String:
	var parca := str(Veri.gun(gun).get("tarih", "")).split(".")
	if parca.size() != 3:
		return "Ardıçlı"
	const AYLAR := ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"]
	const GUNLER := ["Pazar", "Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi"]
	var ay := clampi(int(parca[1]), 1, 12)
	var an := Time.get_unix_time_from_datetime_dict({"year": int(parca[2]), "month": ay, "day": int(parca[0]), "hour": 12})
	var haftanin_gunu := int(Time.get_datetime_dict_from_unix_time(an).get("weekday", 0))
	return "%d %s %s, %s" % [int(parca[0]), Dil.c(AYLAR[ay - 1]), parca[2], Dil.c(GUNLER[haftanin_gunu])]


## Ekran tam görünür olunca çağrılır: süre işlemeye, tıklama sayılmaya başlar.
func basla() -> void:
	_calisiyor = true
	if not kisa:
		var t := create_tween()
		t.tween_interval(0.9)
		t.tween_property(_devam, "modulate:a", 0.9, 0.5)


func _process(delta: float) -> void:
	if is_instance_valid(_sahne) and _kar != null:
		_sahne.ruzgar = _kar.ruzgar
		_kar.isik_gucu = _sahne.lamba_gucu()
	if not _calisiyor or _bitti:
		return
	_gecen += delta
	_ipucu_sayaci += delta
	_sahne_sayaci += delta
	if kisa and _gecen >= KISA_SURE:
		_bitir()
		return
	if _ipucu_sayaci >= DEGISIM:
		_sonraki_ipucu(false)
	if _sahne_sayaci >= SAHNE_SURESI and _sahneler.size() > 1:
		_sonraki_sahne(false)


func _sonraki_ipucu(ilk: bool) -> void:
	_ipucu_sayaci = 0.0
	if _ipuclari.is_empty():
		return
	_ipucu_no = (_ipucu_no + 1) % _ipuclari.size()
	var metin := str(_ipuclari[_ipucu_no])
	if ilk:
		_ipucu.text = metin
		return
	var t := create_tween()
	t.tween_property(_ipucu, "modulate:a", 0.0, 0.25)
	t.tween_callback(func() -> void: _ipucu.text = metin)
	t.tween_property(_ipucu, "modulate:a", 1.0, 0.35)


## Sıradaki sahneyi getirir: yenisi eskisinin üstünde belirir, eskisi sonra kaldırılır.
func _sonraki_sahne(ilk: bool) -> void:
	_sahne_sayaci = 0.0
	if _sahneler.is_empty():
		return
	_sahne_no = (_sahne_no + 1) % _sahneler.size()
	var eski := _sahne
	_sahne = KasabaSahnesi.new()
	_sahne.tanim = _sahneler[_sahne_no]
	_sahne_katmani.add_child(_sahne)
	_yer_adi.text = Dil.c(str(_sahne.tanim.get("ad", "")))
	_kar.isik = _sahne.ana_lamba()
	_kunyeyi_yerlestir.call_deferred(str(_sahne.tanim.get("kunye", "sol")))
	if ilk or eski == null:
		return
	_sahne.modulate.a = 0.0
	var g := create_tween()
	g.tween_property(_sahne, "modulate:a", 1.0, GECIS)
	g.tween_callback(eski.queue_free)


## Künye sahnenin boş köşesine oturur: "sol" (varsayılan), "orta" ya da "sag".
func _kunyeyi_yerlestir(yer: String) -> void:
	var en := _kunye.get_combined_minimum_size().x
	_kunye.size = _kunye.get_combined_minimum_size()
	match yer:
		"orta":
			_kunye.position = Vector2((Yerlesim.EKRAN.size.x - en) / 2.0, 34)
		"sag":
			_kunye.position = Vector2(Yerlesim.EKRAN.size.x - en - 44, 70)
		_:
			_kunye.position = Vector2(44, 40)


func _input(event: InputEvent) -> void:
	if not _calisiyor or _bitti or _gecen < TIK_BEKLEME:
		return
	var tik: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var tus: bool = event is InputEventKey and event.pressed and not event.echo \
		and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]
	if tik or tus:
		get_viewport().set_input_as_handled()
		_bitir()


func _bitir() -> void:
	if _bitti:
		return
	_bitti = true
	bitti.emit()


## Testler ve çekimler için: ekranda görünen ipucu ve yer adı.
func gorunen() -> Dictionary:
	return {"ipucu": _ipucu.text, "yer": _yer_adi.text, "ipucu_sayisi": _ipuclari.size(), "sahne_sayisi": _sahneler.size()}
