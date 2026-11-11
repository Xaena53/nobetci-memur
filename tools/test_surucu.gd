extends Node
## Test sürücüsü: kök düğüme eklenir, sahneler değişse de yaşamaya devam eder.

var _hata := 0
var _adim := 0


func _ready() -> void:
	Oyun.kayit_yolu = "user://test_kayit.json"
	_calistir.call_deferred()


func _calistir() -> void:
	await _akis_testi()
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


# --- Yardımcılar ---

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
