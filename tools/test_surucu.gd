extends Node
## Test sürücüsü: kök düğüme eklenir, sahneler değişse de yaşamaya devam eder.

var _hata := 0
var _adim := 0


func _ready() -> void:
	Oyun.kayit_yolu = "user://test_kayit.json"
	_calistir.call_deferred()


func _calistir() -> void:
	await _akis_testi()
	await _belge_testi()
	print("")
	if _hata == 0:
		print("DUMAN TESTİ: BAŞARILI (%d denetim)" % _adim)
	else:
		print("DUMAN TESTİ: %d HATA (%d denetim)" % [_hata, _adim])
	Oyun.kaydi_sil()
	get_tree().quit(1 if _hata > 0 else 0)


# --- Aşama 0: sahne akışı ve kayıt ---

func _akis_testi() -> void:
	print("== Sahne akışı ==")
	Oyun.kaydi_sil()
	Oyun.sahneye_gec("menu")
	bekle_dogru(await sahneyi_bekle("AnaMenu"), "ana menü açıldı")
	dogru(dugme("Devam").disabled, "kayıt yokken Devam kapalı")

	bas("YeniOyun")
	bekle_dogru(await sahneyi_bekle("Masa"), "Yeni Oyun → Masa")
	esit(Oyun.gun, 1, "ilk gün")
	dogru(Oyun.kayit_var_mi(), "gün başında otomatik kayıt")

	var para_once := Oyun.para
	get_tree().current_scene.mesaiyi_bitir()
	bekle_dogru(await sahneyi_bekle("GunSonu"), "mesai bitti → Gün Sonu")
	dogru(Oyun.para >= para_once, "mesai sonunda para azalmadı")

	bas("EveGit")
	bekle_dogru(await sahneyi_bekle("Aile"), "Gün Sonu → Aile")
	bas("Yat")
	bekle_dogru(await sahneyi_bekle("Masa"), "Aile → ertesi gün Masa")
	esit(Oyun.gun, 2, "ikinci güne geçildi")

	Oyun.gun = 5
	dogru(Oyun.yukle(), "kayıt yüklendi")
	esit(Oyun.gun, 2, "yükleme günü geri getirdi")


# --- Aşama 1: belgeler, inceleme modu, karar araçları ---

func _belge_testi() -> void:
	print("== Belge sistemi ==")
	Oyun.yeni_oyun()
	Oyun.sahneye_gec("masa")
	await sahneyi_bekle("Masa")
	var masa := sahne()
	dogru(await kosulu_bekle(func() -> bool: return masa.belgeler.size() >= 2 and not masa._mesgul), "vatandaş geldi, belgeler masada")
	await bekle(1.0)

	# sürükleme: gerçek fare olaylarıyla
	var b: Belge = masa.belgeler[0]
	var once := b.position
	var tut := b.global_position + Vector2(20, 6)
	fare_bas(tut)
	await kare(2)
	fare_tasi(tut + Vector2(60, 40))
	await kare(2)
	fare_birak(tut + Vector2(60, 40))
	await kare(2)
	dogru(b.position.distance_to(once + Vector2(60, 40)) < 2.0, "belge fareyle sürüklendi")

	# çift tıkla büyütme
	var boyut := b.size
	b.buyut(true)
	await bekle(0.2)
	dogru(b.size.x > boyut.x * 1.4, "belge büyütüldü")
	b.buyut(false)
	await bekle(0.2)
	dogru(is_equal_approx(b.size.x, boyut.x), "belge eski boyutuna döndü")

	# inceleme modu: iki belgede aynı alan
	var sonuclar: Array = []
	masa.inceleme.bulgu.connect(func(s: Dictionary) -> void: sonuclar.append(s))
	masa.inceleme.aktif = true
	await kare(2)
	var cuzdan := _belge(masa, "nufus_cuzdani")
	var ikamet := _belge(masa, "ikametgah")
	dogru(cuzdan != null and ikamet != null, "cüzdan ve ikametgâh var")
	dogru(cuzdan.alanlar["ad"].aktif, "inceleme modunda alanlar tıklanabilir")
	masa.inceleme.hedef_tiklandi(cuzdan.alanlar["ad"])
	masa.inceleme.hedef_tiklandi(ikamet.alanlar["ad"])
	masa.inceleme.hedef_tiklandi(cuzdan.alanlar["soyad"])
	masa.inceleme.hedef_tiklandi(ikamet.alanlar["soyad"])
	await kare(2)
	esit(sonuclar.size(), 2, "iki karşılaştırma yapıldı")
	if sonuclar.size() == 2:
		esit(sonuclar[0].durum, "uyumlu" if cuzdan.metin("ad") == ikamet.metin("ad") else "uyusmaz", "ad karşılaştırması doğru")
		esit(sonuclar[1].durum, "uyumlu" if cuzdan.metin("soyad") == ikamet.metin("soyad") else "uyusmaz", "soyad karşılaştırması doğru")
	masa.inceleme.aktif = false

	# karar: mührü belgeye bırak
	var adet: int = masa.kararlar.size()
	masa.karar_ver("onay", cuzdan, cuzdan.global_position + Vector2(120, 80))
	await kare(3)
	esit(masa.kararlar.size(), adet + 1, "karar kaydedildi")
	dogru(await kosulu_bekle(func() -> bool: return masa.belgeler.size() >= 2 and not masa._mesgul, 12.0), "sıradaki vatandaş geldi")


func _belge(masa: Node, tur: String) -> Belge:
	for b: Belge in masa.belgeler:
		if b.tur == tur:
			return b
	return null


# --- Yardımcılar ---

func kosulu_bekle(kosul: Callable, zaman_asimi: float = 8.0) -> bool:
	var bitis := Time.get_ticks_msec() + int(zaman_asimi * 1000.0)
	while Time.get_ticks_msec() < bitis:
		if kosul.call():
			return true
		await get_tree().process_frame
	return false


## Fare olayları tasarım koordinatlarıyla (1280x720) doğrudan görünüme itilir; başsız kipte
## pencere 64x64 olduğundan ekran dönüşümü atlanır (push_input'un ikinci argümanı).
func fare_bas(konum: Vector2, cift: bool = false) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.double_click = cift
	e.position = konum
	e.global_position = konum
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(e, true)


func fare_birak(konum: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = false
	e.position = konum
	e.global_position = konum
	get_viewport().push_input(e, true)


func fare_tasi(konum: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = konum
	e.global_position = konum
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(e, true)


func sahne() -> Node:
	return get_tree().current_scene


func sahneyi_bekle(ad: String, zaman_asimi: float = 8.0) -> bool:
	var bitis := Time.get_ticks_msec() + int(zaman_asimi * 1000.0)
	while Time.get_ticks_msec() < bitis:
		var s := get_tree().current_scene
		if s != null and s.name == ad and not Oyun.geciste_mi():
			return true
		await get_tree().process_frame
	return false


func bekle(saniye: float) -> void:
	await get_tree().create_timer(saniye).timeout


func kare(adet: int = 1) -> void:
	for i in adet:
		await get_tree().process_frame


func dugme(ad: String) -> Button:
	return sahne().find_child(ad, true, false) as Button


func bas(ad: String) -> void:
	var d := dugme(ad)
	if d == null:
		dogru(false, "düğme bulunamadı: " + ad)
		return
	d.pressed.emit()


func dogru(kosul: bool, aciklama: String) -> void:
	_adim += 1
	if kosul:
		print("  ✓ ", aciklama)
	else:
		_hata += 1
		print("  ✗ HATA: ", aciklama)


func bekle_dogru(kosul: bool, aciklama: String) -> void:
	dogru(kosul, aciklama)


func esit(gercek: Variant, beklenen: Variant, aciklama: String) -> void:
	_adim += 1
	if gercek == beklenen:
		print("  ✓ ", aciklama)
	else:
		_hata += 1
		print("  ✗ HATA: %s (beklenen %s, gelen %s)" % [aciklama, str(beklenen), str(gercek)])
