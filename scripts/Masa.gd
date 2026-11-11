extends Control
## Masa — mesai sahnesi. (Aşama 0: bölgeler yer tutucu kutu, saat akıyor.)

const MESAI_BASI := 9 * 60     ## 09:00 (dakika)
const MESAI_SONU := 17 * 60    ## 17:00
const DAKIKA_SURESI := 1.0     ## gerçek 1 sn = oyun 1 dk

var dakika: float = MESAI_BASI
var mesai_acik := true

var _saat: Label


func _ready() -> void:
	_kutu("Duvar", Rect2(0, 0, 1280, 304), Stil.DUVAR, "")
	_kutu("Gise", Rect2(20, 20, 312, 272), Stil.DUVAR_KOYU, "GİŞE CAMI\n(vatandaş portresi)")
	_kutu("Balon", Rect2(346, 30, 296, 150), Stil.KAGIT_BEYAZ, "KONUŞMA BALONU")
	_kutu("MasaUstu", Rect2(0, 304, 896, 416), Stil.MASA, "MASA\n(sürüklenebilir belgeler)")
	_kutu("YanSehpa", Rect2(896, 0, 384, 720), Stil.MASA_KOYU, "")
	_kutu("KuralKitabi", Rect2(908, 12, 360, 424), Stil.KAGIT, "KURAL KİTABI\n(genelgeler)")
	_kutu("Araclar", Rect2(908, 448, 360, 260), Stil.KAGIT_ESKI, "MÜHÜR  ·  EKSİK EVRAK FİŞİ")

	var gun := Stil.etiket("%d. GÜN" % Oyun.gun, 22, Stil.MUREKKEP, Stil.daktilo_kalin())
	gun.position = Vector2(660, 40)
	add_child(gun)

	_saat = Stil.etiket("09:00", 40, Stil.MUREKKEP, Stil.daktilo_kalin())
	_saat.name = "Saat"
	_saat.position = Vector2(660, 76)
	add_child(_saat)

	var bitir := Button.new()
	bitir.name = "MesaiyiBitir"
	bitir.text = "Mesaiyi Bitir (deneme)"
	bitir.position = Vector2(660, 150)
	bitir.pressed.connect(mesaiyi_bitir)
	add_child(bitir)


func _process(delta: float) -> void:
	if not mesai_acik:
		return
	dakika += delta / DAKIKA_SURESI
	if dakika >= MESAI_SONU:
		dakika = MESAI_SONU
		mesaiyi_bitir()
	_saat.text = saat_metni(int(dakika))


static func saat_metni(dk: int) -> String:
	return "%02d:%02d" % [dk / 60, dk % 60]


func mesaiyi_bitir() -> void:
	if not mesai_acik:
		return
	mesai_acik = false
	var kazanc := 400
	Oyun.para += kazanc
	Oyun.gun_ozeti = {"islenen": 0, "dogru": 0, "yanlis": 0, "kazanc": kazanc, "ihtar": 0}
	Oyun.sahneye_gec("gun_sonu")


func _kutu(ad: String, alan: Rect2, renk: Color, yazi: String) -> void:
	var k := ColorRect.new()
	k.name = ad
	k.color = renk
	k.position = alan.position
	k.size = alan.size
	k.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(k)
	if yazi != "":
		var e := Stil.etiket(yazi, 16, Color(Stil.MUREKKEP, 0.7))
		e.set_anchors_preset(PRESET_FULL_RECT)
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		e.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		k.add_child(e)
