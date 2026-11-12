extends "res://tools/test_surucu.gd"
## Tam oyun testi: yedi günü baştan sona iki ayrı "memur"la, gerçek sahne akışı üzerinden oynar.
##
##  - titiz : her kararı kurallara göre verir, arananı havale eder, zarfı geri iter, evin
##            masraflarını öder. Beklenen son: TERFİ; iki aranan da yakalanır, savcı sağ kalır.
##  - savruk: her evrakı onaylar, zarfı çekmeceye atar, eve yalnız yiyecek alır.
##            Beklenen son: sürgün ya da kötü sonlardan biri.
##
## Zaman 5 kat hızlı akar; bir koşu bir iki dakika sürer.
## Çalıştırma:  godot --headless --path . res://tools/TamOyun.tscn

const HIZ := 5.0
const ZAMAN_ASIMI := 420.0      ## bir oyun için en çok gerçek süre (sn)

var _gunluk: Array[String] = []


func _calistir() -> void:
	Engine.time_scale = HIZ
	Oyun.ayarlar["saat_hizi"] = 1.0          # yalnız bellekte; kullanıcının ayar dosyasına dokunulmaz
	print("== Tam oyun: titiz memur ==")
	var titiz := await _oyna("titiz", 1984)
	esit(str(titiz.get("tur", "")), "terfi", "titiz memur terfi etti")
	esit(int(titiz.get("gun", 0)), Oyun.TOPLAM_GUN, "  yedi günün yedisi de oynandı")
	esit(str(titiz.bayraklar.get("kasap", "")), "yakalandi", "  \"Kasap\" gişede yakalandı")
	esit(str(titiz.bayraklar.get("naciye", "")), "yakalandi", "  \"Terzi\" gişede yakalandı")
	esit(str(titiz.bayraklar.get("savci", "")), "sag", "  savcıya saldırı olmadı")
	esit(int(titiz.get("ihtar", -1)), 0, "  hiç ihtar almadı")
	dogru(int(titiz.get("para", -1)) >= 0, "  borca batmadı (%s)" % Stil.tl(int(titiz.get("para", 0))))
	dogru(int(titiz.get("islenen", 0)) >= 60, "  kuyruklar eritildi (%d işlem)" % int(titiz.get("islenen", 0)))

	print("== Tam oyun: savruk memur ==")
	var savruk := await _oyna("savruk", 1984)
	dogru(str(savruk.get("tur", "")) in ["surgun", "kotu"], "savruk memurun sonu kötü: %s/%s (gün %d)" % [
		str(savruk.get("tur", "")), str(savruk.get("neden", "")), int(savruk.get("gun", 0))])
	dogru(int(savruk.get("ihtar", 0)) > 0, "  ihtar aldı (%d)" % int(savruk.get("ihtar", 0)))

	Engine.time_scale = 1.0
	print("")
	for satir in _gunluk:
		print(satir)
	print("")
	if _hata == 0:
		print("TAM OYUN TESTİ: BAŞARILI (%d denetim)" % _adim)
	else:
		print("TAM OYUN TESTİ: %d HATA (%d denetim)" % [_hata, _adim])
	Oyun.kaydi_sil()
	Oyun.cik(1 if _hata > 0 else 0)


## Bir oyunu baştan sona oynar; sonda oyun durumunun özetini döndürür.
func _oyna(tarz: String, tohum: int) -> Dictionary:
	Oyun.kaydi_sil()
	Oyun.yeni_oyun()
	Oyun.tohum = tohum
	await sahneye_git("masa")
	var bitis := Time.get_ticks_msec() + int(ZAMAN_ASIMI * 1000.0)
	while Time.get_ticks_msec() < bitis:
		var s := sahne()
		if s == null or Oyun.geciste_mi():
			await get_tree().process_frame
			continue
		match str(s.name):
			"Masa":
				await _masada(s, tarz)
			"GunSonu":
				var o: Dictionary = Oyun.gun_ozeti
				_gunluk.append("  [%s] %d. gün: %d işlem, %d doğru, %d ihtar, kazanç %s, eldeki %s" % [tarz, Oyun.gun,
					int(o.get("islenen", 0)), int(o.get("dogru", 0)), int(o.get("ihtar", 0)),
					Stil.tl(int((o.get("maas", {}) as Dictionary).get("net", 0))), Stil.tl(Oyun.para)])
				bas("EveGit")
				await _sahne_degissin(s)
			"Aile":
				await _evde(s, tarz)
			"Son":
				dogru(dugme("AnaMenu") != null, "[%s] son ekranı açıldı: %s" % [tarz, str(Oyun.son)])
				var ozet := {"tur": str(Oyun.son.get("tur", "")), "neden": str(Oyun.son.get("neden", "")), "gun": Oyun.gun,
					"ihtar": Oyun.ihtar, "suphe": Oyun.suphe, "para": Oyun.para, "bayraklar": Oyun.bayraklar.duplicate(),
					"islenen": int(Oyun.toplam.get("islenen", 0))}
				_gunluk.append("  [%s] SON: %s/%s — ihtar %d, şüphe %d, para %s, bayraklar %s" % [tarz, ozet.tur, ozet.neden,
					Oyun.ihtar, Oyun.suphe, Stil.tl(Oyun.para), str(Oyun.bayraklar)])
				return ozet
			_:
				await get_tree().process_frame
	dogru(false, "[%s] oyun %d saniyede bitmedi (gün %d, sahne %s)" % [tarz, int(ZAMAN_ASIMI), Oyun.gun, str(sahne())])
	return {}


func _sahne_degissin(eski: Node) -> void:
	while is_instance_valid(eski) and sahne() == eski:
		await get_tree().process_frame


## Mesai: genelgeyi kapatır, kuyruk bitene kadar her vatandaş için karar verir.
func _masada(masa: Node, tarz: String) -> void:
	while is_instance_valid(masa) and sahne() == masa:
		var ac := dugme("GiseyiAc")
		if ac != null and not ac.disabled and not masa.mesai_acik and not masa.gun_bitti:
			ac.pressed.emit()
		var mektup := dugme("MektubuKatla")
		if mektup != null:
			mektup.pressed.emit()
		if is_instance_valid(masa.zarf) and not masa.zarf.sonuclandi and dugme("ZarfAl") != null and dugme("ZarfAl").is_visible_in_tree():
			if tarz == "savruk":
				masa.zarf.al()
			else:
				masa.zarf.geri_it()
		if masa.mesai_acik and not masa._mesgul and not masa.vatandas.is_empty() and masa.belgeler.size() > 0:
			var sonuc := Dogrulayici.kontrol(masa.vatandas, masa.gun)
			var karar := "onay"
			var gerekce := ""
			if tarz == "titiz":
				if (sonuc.gerekceler as Array).has("aranan"):
					karar = "havale"
				elif not (sonuc.hatalar as Array).is_empty():
					karar = "eksik"
					gerekce = str(sonuc.gerekceler[0])
			var belge: Control = masa.belgeler[0]
			masa.karar_ver(karar, belge, belge.get_global_transform() * (belge.size * 0.5), gerekce)
		await get_tree().process_frame


## Akşam: masrafları seçer, lambayı söndürür, sabahı bekler.
func _evde(aile: Node, tarz: String) -> void:
	await bekle(0.4)
	if not is_instance_valid(aile) or sahne() != aile:
		return
	var sira: Array[String] = []
	if tarz == "titiz":
		sira = ["kira", "yemek", "komur"]
		for k: Dictionary in aile.kalemler:
			if not sira.has(str(k.kod)):
				sira.append(str(k.kod))
	else:
		sira = ["yemek"]
	var odenen: Array[String] = []
	for kod in sira:
		if aile.sec(kod, true):
			odenen.append(kod)
	_gunluk.append("  [%s] %d. akşam: ödenen %s, kalan %s" % [tarz, Oyun.gun, str(odenen), Stil.tl(Oyun.para - int(aile.toplam()))])
	bas("Yat")
	await kosulu_bekle(func() -> bool: return dugme("SabahOldu") != null, 6.0)
	await bekle(0.3)
	bas("SabahOldu")
	await _sahne_degissin(aile)
