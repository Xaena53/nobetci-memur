extends Node
## Test sürücüsü: kök düğüme eklenir, sahneler değişse de yaşamaya devam eder.

var _hata := 0
var _adim := 0


func _ready() -> void:
	Oyun.kayit_yolu = "user://test_kayit.json"
	_calistir.call_deferred()


func _calistir() -> void:
	await _akis_testi()
	await _ekonomi_testi()
	await _kural_testi()
	await _belge_testi()
	print("")
	if _hata == 0:
		print("DUMAN TESTİ: BAŞARILI (%d denetim)" % _adim)
	else:
		print("DUMAN TESTİ: %d HATA (%d denetim)" % [_hata, _adim])
	Oyun.kaydi_sil()
	get_tree().quit(1 if _hata > 0 else 0)


# --- Aşama 0 ve 3: sahne akışı, gün döngüsü ve kayıt ---

func _akis_testi() -> void:
	print("== Sahne akışı ve gün döngüsü ==")
	Oyun.kaydi_sil()
	Oyun.sahneye_gec("menu")
	bekle_dogru(await sahneyi_bekle("AnaMenu"), "ana menü açıldı")
	dogru(dugme("Devam").disabled, "kayıt yokken Devam kapalı")

	bas("YeniOyun")
	bekle_dogru(await sahneyi_bekle("Masa"), "Yeni Oyun → Masa")
	esit(Oyun.gun, 1, "ilk gün")
	dogru(Oyun.kayit_var_mi(), "gün başında otomatik kayıt")
	var masa := sahne()
	dogru(dugme("GiseyiAc") != null, "gün sabah genelgesiyle başlıyor")
	dogru(not masa.mesai_acik, "genelge okunmadan saat işlemiyor")
	var saat_once: float = masa.dakika
	await bekle(0.4)
	esit(masa.dakika, saat_once, "genelge açıkken saat duruyor")
	bas("GiseyiAc")
	dogru(await kosulu_bekle(func() -> bool: return masa.mesai_acik), "Gişeyi Aç → mesai başladı")
	await bekle(0.4)
	dogru(masa.dakika > saat_once, "saat işliyor")

	# saat 17:00 olunca gişe kendiliğinden kapanır
	masa.dakika = masa.MESAI_SONU - 0.2
	bekle_dogru(await sahneyi_bekle("GunSonu", 12.0), "17:00 → gişe kapandı → Gün Sonu")
	var maas: Dictionary = Oyun.gun_ozeti.get("maas", {})
	esit(int(maas.get("yevmiye", 0)), Oyun.YEVMIYE, "yevmiye yazıldı")
	esit(Oyun.para, Oyun.BASLANGIC_PARASI + int(maas.get("net", 0)), "günün kazancı paraya eklendi")

	bas("EveGit")
	bekle_dogru(await sahneyi_bekle("Aile"), "Gün Sonu → Aile")
	var aile := sahne()
	var para_once := Oyun.para
	dogru(aile.sec("kira", true), "kira işaretlendi")
	dogru(aile.sec("komur", true), "kömür işaretlendi")
	esit(aile.toplam(), AileDurumu.KIRA + AileDurumu.KOMUR, "akşam toplamı doğru")
	bas("Yat")
	await kare(3)
	esit(Oyun.para, para_once - AileDurumu.KIRA - AileDurumu.KOMUR, "ödenenler paradan düştü")
	dogru(dugme("SabahOldu") != null, "gece özeti gösterildi")
	bas("SabahOldu")
	bekle_dogru(await sahneyi_bekle("Masa"), "sabah → ertesi gün Masa")
	esit(Oyun.gun, 2, "ikinci güne geçildi")

	Oyun.gun = 5
	dogru(Oyun.yukle(), "kayıt yüklendi")
	esit(Oyun.gun, 2, "yükleme günü geri getirdi")
	esit(Oyun.para, para_once - AileDurumu.KIRA - AileDurumu.KOMUR, "yükleme parayı geri getirdi")


# --- Aşama 3: maaş ve aile mantığı ---

func _ekonomi_testi() -> void:
	print("== Maaş ve aile ==")
	var m := Oyun.maas_hesapla({"kazanc": 700, "ihtar": 0})
	esit(int(m.net), Oyun.YEVMIYE + 700, "ihtarsız gün: yevmiye + prim")
	esit(int(Oyun.maas_hesapla({"kazanc": 300, "ihtar": 2}).kesinti), 0, "iki ihtarda kesinti yok")
	esit(int(Oyun.maas_hesapla({"kazanc": 300, "ihtar": 3}).kesinti), Oyun.KESINTI_ILK, "üçüncü ihtarda maaş kesilir")
	esit(int(Oyun.maas_hesapla({"kazanc": 0, "ihtar": 5}).kesinti), Oyun.KESINTI_ILK + 2 * Oyun.KESINTI_SONRAKI, "sonraki ihtarlar da kesilir")

	var a := AileDurumu.yeni()
	var g := AileDurumu.geceyi_gecir(a, 1, ["kira", "komur", "yemek"])
	esit(str(g.son), "", "her şey ödendi: sakin gece")
	esit(AileDurumu.saglik(a, "anne"), 3, "  herkes iyi")

	a = AileDurumu.yeni()
	AileDurumu.geceyi_gecir(a, 1, ["kira", "yemek"])
	esit(AileDurumu.saglik(a, "anne"), 2, "kömürsüz gece: anne halsiz")
	esit(AileDurumu.saglik(a, "elif"), 3, "  ilk soğuk gecede Elif dayanır")
	AileDurumu.geceyi_gecir(a, 2, ["kira", "yemek"])
	esit(AileDurumu.saglik(a, "anne"), 1, "ikinci soğuk gece: anne hasta")
	esit(AileDurumu.saglik(a, "elif"), 2, "  Elif de üşüdü")
	var kalemler := AileDurumu.masraflar(a, 5)
	var kodlar: Array = []
	for k in kalemler:
		kodlar.append(k.kod)
	dogru(kodlar.has("ilac_anne") and kodlar.has("ilac_can"), "hastalar için ilaç kalemi çıktı")
	AileDurumu.geceyi_gecir(a, 5, ["kira", "komur", "yemek", "ilac_anne"])
	esit(AileDurumu.saglik(a, "anne"), 2, "ilaç + sıcak ev: anne toparlandı")
	esit(AileDurumu.saglik(a, "can"), 0, "ilaçsız kalan Can ağırlaştı")

	a = AileDurumu.yeni()
	g = AileDurumu.geceyi_gecir(a, 1, ["komur", "yemek"])
	g = AileDurumu.geceyi_gecir(a, 2, ["komur", "yemek"])
	esit(str(g.son), "", "iki akşam kira ödenmedi: son uyarı")
	g = AileDurumu.geceyi_gecir(a, 3, ["komur", "yemek"])
	esit(str(g.son), "tahliye", "üçüncü akşam: tahliye")

	a = AileDurumu.yeni()
	a.saglik["can"] = 1
	g = AileDurumu.geceyi_gecir(a, 1, ["kira"])
	esit(str(g.son), "aile", "hasta çocuk soğukta ve aç: kötü son")
	dogru(AileDurumu.masraflar(AileDurumu.yeni(), 2).any(func(k: Dictionary) -> bool: return k.kod == "okul"), "2. akşam okul masrafı var")

	# son denetimi
	Oyun.yeni_oyun()
	Oyun.para = -50
	esit(str(Oyun.son_denetle().get("neden", "")), "iflas", "para eksiye düştü: kötü son")
	Oyun.para = 100
	Oyun.ihtar = Oyun.SURGUN_IHTARI
	esit(str(Oyun.son_denetle().get("tur", "")), "surgun", "çok ihtar: sürgün")
	Oyun.ihtar = 2
	Oyun.gun = Oyun.TOPLAM_GUN
	esit(str(Oyun.son_denetle(true).get("tur", "")), "terfi", "7 gün, az ihtar, düşük şüphe: terfi")
	Oyun.suphe = Oyun.SURGUN_SUPHESI
	esit(str(Oyun.son_denetle(true).get("neden", "")), "suphe", "yüksek şüphe: sürgün")


# --- Aşama 1: belgeler, inceleme modu, karar araçları ---

func _belge_testi() -> void:
	print("== Belge sistemi ==")
	Oyun.yeni_oyun()
	Oyun.sahneye_gec("masa")
	await sahneyi_bekle("Masa")
	var masa := sahne()
	bas("GiseyiAc")
	dogru(await kosulu_bekle(func() -> bool: return masa.belgeler.size() >= 2 and not masa._mesgul), "vatandaş geldi, belgeler masada")
	await bekle(1.0)

	# sürükleme: gerçek fare olaylarıyla (belge masa perspektifinde yatıyor)
	var b: Belge = _belge(masa, "nufus_cuzdani")
	var once := b.tutucu.masa_konumu
	var tut: Vector2 = b.get_global_transform() * Vector2(30, 12)
	fare_bas(tut)
	await kare(2)
	fare_tasi(tut + Vector2(60, 40))
	await kare(2)
	fare_birak(tut + Vector2(60, 40))
	await kare(2)
	var tutulan: Vector2 = b.get_global_transform() * Vector2(30, 12)
	dogru(b.tutucu.masa_konumu.distance_to(once) > 50.0, "belge fareyle sürüklendi")
	dogru(tutulan.distance_to(tut + Vector2(60, 40)) < 4.0, "tutulan nokta imlecin altında kaldı")
	dogru(b.get_global_transform().x.length() < 1.0, "masadaki belge perspektifle küçülüyor")

	# çift tıkla büyütme: belge ele kalkar ve düzleşir
	var boyut := b.size
	b.buyut(true)
	await bekle(0.3)
	dogru(b.size.x > boyut.x * 1.4, "belge büyütüldü")
	dogru(is_equal_approx(b.get_global_transform().x.length(), 1.0) and absf(b.get_global_transform().x.y) < 0.001, "eldeki belge dümdüz")
	b.buyut(false)
	await bekle(0.3)
	dogru(is_equal_approx(b.size.x, boyut.x), "belge eski boyutuna döndü")

	# inceleme modu: iki belgede aynı alan
	var sonuclar: Array = []
	masa.inceleme.bulgu.connect(func(s: Dictionary) -> void: sonuclar.append(s))
	masa.inceleme.aktif = true
	await kare(2)
	var cuzdan := _belge(masa, "nufus_cuzdani")
	var ikamet := _belge(masa, "ikametgah")
	dogru(cuzdan != null, "nüfus cüzdanı masada")
	dogru(cuzdan.alanlar["ad"].aktif, "inceleme modunda alanlar tıklanabilir")
	if ikamet != null:
		masa.inceleme.hedef_tiklandi(cuzdan.alanlar["soyad"])
		masa.inceleme.hedef_tiklandi(ikamet.alanlar["soyad"])
		await kare(2)
		esit(sonuclar.size(), 1, "karşılaştırma yapıldı")
		if sonuclar.size() == 1:
			esit(sonuclar[0].durum, "uyumlu" if cuzdan.metin("soyad") == ikamet.metin("soyad") else "uyusmaz", "soyad karşılaştırması doğru")
	masa.inceleme.aktif = false

	# karar: onay mührü; sonuç doğrulayıcıyla aynı olmalı
	var beklenen: String = "dogru" if Dogrulayici.kontrol(masa.vatandas, masa.gun).karar == "onay" else "yanlis"
	var adet: int = masa.kararlar.size()
	masa.karar_ver("onay", cuzdan, cuzdan.get_global_transform() * Vector2(120, 80))
	await kare(3)
	esit(masa.kararlar.size(), adet + 1, "karar kaydedildi")
	esit(masa.kararlar[-1].sonuc, beklenen, "onay kararı doğru değerlendirildi")
	dogru(await kosulu_bekle(func() -> bool: return masa.belgeler.size() >= 1 and not masa._mesgul, 12.0), "sıradaki vatandaş geldi")

	# eksik evrak fişi: gerekçe penceresi açılır, seçilince karar verilir
	await bekle(0.8)
	var ilk: Belge = masa.belgeler[0]
	var fis: Arac = masa.araclar["eksik"]
	var fis_yeri: Vector2 = fis.get_global_transform() * (fis.size / 2.0)
	var hedef_yer: Vector2 = ilk.get_global_transform() * (ilk.size / 2.0)
	fare_bas(fis_yeri)
	await kare(2)
	fare_tasi(hedef_yer)
	await kare(2)
	fare_birak(hedef_yer)
	await kare(3)
	var pencere := masa.find_child("GerekcePenceresi", true, false)
	dogru(pencere != null, "fiş belgeye bırakılınca gerekçe penceresi açıldı")
	if pencere != null:
		var gerekceler: Array[String] = Dogrulayici.gunun_gerekceleri(masa.gun)
		var s2: Dictionary = Dogrulayici.kontrol(masa.vatandas, masa.gun)
		var secilen: String = s2.gerekceler[0] if not (s2.gerekceler as Array).is_empty() else gerekceler[0]
		var bek2: String = "dogru" if not (s2.gerekceler as Array).is_empty() else "yanlis"
		adet = masa.kararlar.size()
		(pencere.find_child("Gerekce_" + secilen, true, false) as Button).pressed.emit()
		await kare(3)
		esit(masa.kararlar.size(), adet + 1, "gerekçe seçilince karar kaydedildi")
		esit(masa.kararlar[-1].sonuc, bek2, "eksik evrak kararı doğru değerlendirildi")


func _belge(masa: Node, tur: String) -> Belge:
	for b: Belge in masa.belgeler:
		if b.tur == tur:
			return b
	return null


# --- Aşama 2: kural motoru ve vatandaş üreticisi ---

func _kural_testi() -> void:
	print("== Kural motoru ==")
	esit(Tarih.haftanin_gunu("09.01.1984"), "Pazartesi", "9 Ocak 1984 pazartesi")
	esit(Tarih.gun_ekle("28.02.1984", 2), "01.03.1984", "artık yıl: 28 Şubat + 2 gün")
	esit(Tarih.ay_ekle("31.03.1984", -1), "29.02.1984", "31 Mart − 1 ay = 29 Şubat")
	dogru(Tarih.ay_icinde_mi("09.07.1983", "09.01.1984", 6), "tam 6 ay önceki belge geçerli")
	dogru(not Tarih.ay_icinde_mi("08.07.1983", "09.01.1984", 6), "6 ay 1 günlük belge geçersiz")
	dogru(not Tarih.ay_icinde_mi("10.01.1984", "09.01.1984", 6), "ileri tarihli belge geçersiz")

	var gun := Veri.gun(7)
	dogru(not gun.is_empty(), "7. günün genelgesi okundu")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var temiz := VatandasUretici.uret(gun, rng, [], 0)
	var s := Dogrulayici.kontrol(temiz, gun)
	esit(s.karar, "onay", "kusursuz vatandaş onay alır")
	esit(Dogrulayici.degerlendir("onay", "", s).sonuc, "dogru", "kusursuzu onaylamak doğru")
	esit(Dogrulayici.degerlendir("eksik", "sure", s).sonuc, "yanlis", "kusursuzu geri çevirmek ihtar")
	esit(Dogrulayici.degerlendir("havale", "", s).sonuc, "notr", "kusursuzu havale etmek nötr")

	# her kusur türü tek tek: doğrulayıcı yakalamalı
	for tur: String in ["ad", "soyad", "baba_adi", "sure_ikametgah", "sure_harc_makbuzu", "muhur", "imza", "harc", "seri", "foto", "mahalle", "belge_eksik"]:
		var v := VatandasUretici.uret(gun, rng, [], 0)
		var gerekce := VatandasUretici.kusur_uygula(v, tur, gun, rng)
		var sonuc := Dogrulayici.kontrol(v, gun)
		dogru(gerekce != "" and sonuc.karar == "eksik" and (sonuc.gerekceler as Array) == [gerekce],
			"kusur yakalandı: %s → %s" % [tur, gerekce])
		esit(Dogrulayici.degerlendir("onay", "", sonuc).sonuc, "yanlis", "  kusurluyu onaylamak ihtar (%s)" % tur)
		esit(Dogrulayici.degerlendir("eksik", gerekce, sonuc).sonuc, "dogru", "  doğru gerekçeyle geri çevirmek doğru (%s)" % tur)
		var yanlis_gerekce := "harc" if gerekce != "harc" else "seri"
		esit(Dogrulayici.degerlendir("eksik", yanlis_gerekce, sonuc).sonuc, "yarim", "  yanlış gerekçe uyarı (%s)" % tur)
		esit(Dogrulayici.degerlendir("havale", "", sonuc).sonuc, "dogru" if Dogrulayici.SUPHELI.has(gerekce) else "notr",
			"  havale değerlendirmesi (%s)" % tur)

	# inceleme karşılaştırmaları
	var v2 := VatandasUretici.uret(gun, rng, [], 0)
	VatandasUretici.kusur_uygula(v2, "seri", gun, rng)
	var cuzdan: Dictionary = Dogrulayici.belge_sozlugu(v2)["nufus_cuzdani"]
	var seri_alani := {"tip": "alan", "anahtar": "seri_no", "deger": cuzdan.alanlar.seri_no, "belge": "nufus_cuzdani", "kural": {}, "etiket": ""}
	var seri_kurali := {"tip": "kural", "anahtar": "seri", "deger": null, "belge": "", "kural": Veri.kural(gun, "seri_aralik"), "etiket": ""}
	esit(Dogrulayici.karsilastir(seri_alani, seri_kurali, v2, gun).durum, "uyusmaz", "inceleme: geçersiz seri ↔ kural")
	var foto := {"tip": "alan", "anahtar": "foto", "deger": cuzdan.foto, "belge": "nufus_cuzdani", "kural": {}, "etiket": ""}
	var yuz := {"tip": "yuz", "anahtar": "", "deger": v2.portre, "belge": "", "kural": {}, "etiket": ""}
	esit(Dogrulayici.karsilastir(yuz, foto, v2, gun).durum, "uyumlu", "inceleme: fotoğraf ↔ yüz (aynı kişi)")
	esit(Dogrulayici.karsilastir(yuz, seri_alani, v2, gun).durum, "ilgisiz", "inceleme: yüz ↔ seri ilgisiz")

	var rapor: Dictionary = load("res://scripts/UreticiTesti.gd").calistir(60, 7)
	esit(rapor.tutarsiz, 0, "üretici ile doğrulayıcı 7 gün × 60 vatandaşta tutarlı")
	for g: Dictionary in rapor.gunler:
		var oran := float(g.eksik) / 60.0
		dogru(oran > 0.2 and oran < 0.7, "  %d. gün kusurlu oranı makul (%%%d)" % [g.gun, roundi(oran * 100.0)])


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
