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
	await _hikaye_testi()
	await _cila_testi()
	await _rontgen_testi()
	print("")
	if _hata == 0:
		print("DUMAN TESTİ: BAŞARILI (%d denetim)" % _adim)
	else:
		print("DUMAN TESTİ: %d HATA (%d denetim)" % [_hata, _adim])
	Oyun.kaydi_sil()
	Oyun.cik(1 if _hata > 0 else 0)


# --- Aşama 0 ve 3: sahne akışı, gün döngüsü ve kayıt ---

func _akis_testi() -> void:
	print("== Sahne akışı ve gün döngüsü ==")
	Oyun.kaydi_sil()
	await sahneye_git("menu")
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
	await sahneye_git("masa")
	await sahneyi_bekle("Masa")
	var masa := sahne()
	# İlk vatandaş kusursuz olsun: "eksik belge" kusurlu biri gelirse masaya tek belge düşer.
	var ilk_rng := RandomNumberGenerator.new()
	ilk_rng.seed = 11
	masa.kuyruk[0] = VatandasUretici.uret(masa.gun, ilk_rng, [], 0)
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


## Sahne değiştirir; süren bir geçiş varsa önce onun bitmesini bekler (yoksa istek yok sayılır).
func sahneye_git(ad: String) -> void:
	await kosulu_bekle(func() -> bool: return not Oyun.geciste_mi(), 4.0)
	Oyun.sahneye_gec(ad)


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


## Düğmeyi önce sahnede, bulamazsa Oyun'un üst katmanında (mola menüsü) arar.
func dugme(ad: String) -> Button:
	var d := sahne().find_child(ad, true, false) as Button if sahne() != null else null
	if d == null:
		d = Oyun.find_child(ad, true, false) as Button
	return d


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


# --- Aşama 4: hikâye karakterleri, zarf, arananlar, denetim, sonlar ---

func _one_al(masa: Node, kod: String) -> bool:
	for i in masa.kuyruk.size():
		if str(masa.kuyruk[i].get("kod", "")) == kod:
			var v: Dictionary = masa.kuyruk[i]
			masa.kuyruk.remove_at(i)
			masa.kuyruk.insert(0, v)
			return true
	return false


func _gune_git(gun_no: int, bayraklar: Dictionary = {}) -> Node:
	Oyun.yeni_oyun()
	Oyun.gun = gun_no
	Oyun.bayraklar = bayraklar
	await sahneye_git("masa")
	await sahneyi_bekle("Masa")
	await bekle(0.5)
	return sahne()


func _hikaye_testi() -> void:
	print("== Hikâye ==")
	# koşullar
	dogru(Hikaye.kosul_tutar({"husnu_onay": 0}, {}), "yazılmamış sayı bayrağı 0 sayılır")
	dogru(not Hikaye.kosul_tutar({"husnu_onay": 0}, {"husnu_onay": 3}), "  yazılmışsa değeri geçerli")
	dogru(Hikaye.kosul_tutar({"husnu_onay": [1, 2, 3]}, {"husnu_onay": 2.0}), "liste koşulu: biri yeter (kayıttan gelen ondalık dahil)")
	dogru(Hikaye.kosul_tutar({"tarik2": ["onay", ""]}, {}), "yazılmamış metin bayrağı boş sayılır")
	dogru(not Hikaye.kosul_tutar({"nermin": "kayirildi"}, {"nermin": "reddedildi"}), "metin koşulu tutmuyor")

	# her günün özel karakterleri ve evraklarındaki kusur
	var beklenen := {
		"husnu1": "sure", "husnu2": "muhur", "husnu3": "belge_eksik", "husnu4": "harc", "husnu5": "harc",
		"husnu6": "mahalle", "husnu7": "sure", "nermin2": "muhur", "kenan3": "harc", "izzet4": "sure",
		"tarik2": "", "tarik4": "", "savci5": "", "kasap5": "aranan", "naciye6": "aranan",
		"nermin6a": "", "nermin6b": "foto", "bavullu7": "",
	}
	var gorulen := {}
	for gun_no in range(1, 8):
		var gun := Veri.gun(gun_no)
		for bayraklar: Dictionary in [{}, {"nermin": "kayirildi"}, {"nermin": "reddedildi"}]:
			var rng := RandomNumberGenerator.new()
			rng.seed = 7 + gun_no
			for o: Dictionary in Hikaye.ozel_vatandaslar(gun_no, gun, bayraklar, rng):
				var v: Dictionary = o.vatandas
				var kod := str(v.kod)
				if bool(v.get("belgesiz", false)) or gorulen.has(kod):
					continue
				gorulen[kod] = true
				var sonuc := Dogrulayici.kontrol(v, gun)
				var kusur := str(beklenen.get(kod, "?"))
				if kusur == "":
					esit(sonuc.gerekceler.size(), 0, "%s: evrakı kusursuz %s" % [kod, str(sonuc.gerekceler)])
				else:
					dogru(sonuc.gerekceler.size() == 1 and sonuc.gerekceler.has(kusur),
						"%s: tek kusur '%s' (bulunan: %s)" % [kod, kusur, str(sonuc.gerekceler)])
	esit(gorulen.size(), beklenen.size(), "evraklı bütün hikâye ziyaretleri denendi")

	# aranan şahıs: tek doğru karar havale
	var rng5 := RandomNumberGenerator.new()
	var kasap: Dictionary = {}
	for o: Dictionary in Hikaye.ozel_vatandaslar(5, Veri.gun(5), {}, rng5):
		if str(o.vatandas.kod) == "kasap5":
			kasap = o.vatandas
	var ks := Dogrulayici.kontrol(kasap, Veri.gun(5))
	esit(str(Dogrulayici.degerlendir("havale", "", ks).sonuc), "dogru", "aranan şahıs: havale doğru")
	esit(str(Dogrulayici.degerlendir("onay", "", ks).sonuc), "yanlis", "  onay yanlış")
	esit(str(Dogrulayici.degerlendir("eksik", "seri", ks).sonuc), "yanlis", "  geri çevirmek de yanlış")

	# savcının akıbeti ve gazeteler
	esit(Hikaye.savci_akibeti({}), "oldu", "kimse yakalanmadı: savcı öldürülür")
	esit(Hikaye.savci_akibeti({"kasap": "yakalandi"}), "yarali", "biri yakalandı: saldırıdan kurtulur")
	esit(Hikaye.savci_akibeti({"kasap": "yakalandi", "naciye": "yakalandi"}), "sag", "ikisi de yakalandı: saldırı olmaz")
	for gun_no in range(1, 8):
		var b := {"savci": "yarali"} if gun_no == 7 else {}
		dogru(str(Hikaye.gazete(gun_no, b).get("manset", "")) != "", "%d. gün gazetesi var" % gun_no)
		dogru(Hikaye.aksam(gun_no, {}) != "", "  akşam sahnesi var")
	dogru(str(Hikaye.gazete(6, {"kasap": "yakalandi"}).manset).contains("YAKALANDI"), "tetikçi yakalanınca manşet değişir")
	dogru(Hikaye.gece(3, {}) != "", "3. gece: patlama")
	dogru(Hikaye.gece(6, {"savci": "oldu"}).contains("hayatını kaybetmiş"), "6. gece: suikast")

	# sonlar
	for s: Array in [["terfi", "basari"], ["olagan", "yerinde"], ["surgun", "ihtar"], ["surgun", "suphe"],
			["kotu", "iflas"], ["kotu", "aile"], ["kotu", "tahliye"]]:
		var son := Hikaye.son({"tur": s[0], "neden": s[1]}, {})
		dogru(str(son.manset) != "" and str(son.metin) != "" and str(son.damga) != "", "son '%s/%s' yazılı" % s)
	dogru(str(Hikaye.son({"tur": "surgun", "neden": "suphe"}, {}).manset) != str(Hikaye.son({"tur": "surgun", "neden": "ihtar"}, {}).manset),
		"iki sürgün sonu ayrı")
	esit(str(Hikaye.son({"tur": "terfi"}, {}).mektup), "", "mektup bayrağı yoksa mektup yok")
	dogru(str(Hikaye.son({"tur": "terfi"}, {"mektup": true}).mektup).contains("Hüsnü"), "  varsa Hüsnü Amca'nın mektubu eklenir")
	esit((Hikaye.son({"tur": "terfi"}, {"savci": "sag", "husnu_onay": 7.0, "tarik_sonuc": "ovgu"}).yan as Array).size(), 3, "yan haberler bayraklara göre seçilir")

	# etkiler
	Oyun.yeni_oyun()
	Hikaye.etki_uygula({"bayrak": {"izzet": "kayirildi"}, "kira_affi": true, "suphe": 1})
	esit(Oyun.suphe, 1, "kayırma şüpheyi artırır")
	esit(int(AileDurumu.masraflar(Oyun.aile, 4)[0].tutar), 0, "ev sahibi kayırılınca o akşam kira istenmez")
	Hikaye.etki_uygula({"suphe": -3})
	esit(Oyun.suphe, 0, "şüphe sıfırın altına inmez")

	# kuyruk: özel karakterler günün sayısına eklenmez, evraksızlar hariç
	for gun_no in range(1, 8):
		var m: Node = await _gune_git(gun_no)
		var evraksiz := 0
		var ozel := 0
		for v: Dictionary in m.kuyruk:
			if str(v.get("tur", "")) == "hikaye":
				ozel += 1
				if bool(v.get("belgesiz", false)):
					evraksiz += 1
		esit(m.kuyruk.size(), int(m.gun.vatandas_sayisi) + evraksiz, "%d. gün kuyruğu: %d kişi, %d özel" % [gun_no, m.kuyruk.size(), ozel])
		dogru(ozel >= 1, "  hikâyeden en az bir kişi var")

	# zarf: çekmeceye atılınca para ve şüphe
	var masa: Node = await _gune_git(3)
	dogru(_one_al(masa, "kenan3"), "3. gün müteahhit kuyrukta")
	bas("GiseyiAc")
	dogru(await kosulu_bekle(func() -> bool: return masa.belgeler.size() >= 1 and not masa._mesgul), "müteahhit camda")
	dogru(await kosulu_bekle(func() -> bool: return dugme("ZarfAl") != null and dugme("ZarfAl").is_visible_in_tree(), 6.0), "zarf masada, seçenekler çıktı")
	var para_once := Oyun.para
	bas("ZarfAl")
	await bekle(0.3)
	esit(Oyun.para, para_once + 600, "zarf çekmeceye: +600 TL")
	esit(Oyun.suphe, 1, "  şüphe arttı")
	esit(str(Oyun.bayrak("kenan1", "")), "aldi", "  bayrak yazıldı")
	var b: Belge = masa.belgeler[0]
	masa.karar_ver("eksik", b, b.get_global_transform() * (b.size * 0.5), "harc")
	esit(int(masa.ozet.dogru), 1, "zarfı alıp yine de geri çevirmek: işlem doğru")
	await bekle(0.3)

	# zarf: geri itilince bir şey olmaz; havale edilince müdür takdir eder
	masa = await _gune_git(3)
	_one_al(masa, "kenan3")
	bas("GiseyiAc")
	await kosulu_bekle(func() -> bool: return masa.belgeler.size() >= 1 and not masa._mesgul)
	await kosulu_bekle(func() -> bool: return dugme("ZarfGeri") != null and dugme("ZarfGeri").is_visible_in_tree(), 6.0)
	para_once = Oyun.para
	bas("ZarfGeri")
	await bekle(0.3)
	esit(Oyun.para, para_once, "zarf geri itildi: para değişmedi")
	b = masa.belgeler[0]
	masa.karar_ver("havale", b, b.get_global_transform() * (b.size * 0.5))
	esit(int(masa.ozet.dogru), 1, "rüşvetçiyi havale etmek doğru sayılır")
	esit(str(Oyun.bayrak("kenan_tavir", "")), "havale", "  bayrak yazıldı")
	await bekle(0.3)

	# müdür denetimi: izlerken yapılan hata çift ihtar
	masa = await _gune_git(2)
	_one_al(masa, "tarik2")
	bas("GiseyiAc")
	await kosulu_bekle(func() -> bool: return masa.belgeler.size() >= 1 and not masa._mesgul)
	dogru(not masa.denetimde, "sabah jaluzi inik")
	masa.dakika = float(masa.gun.denetim[0][0]) + 1.0
	dogru(await kosulu_bekle(func() -> bool: return masa.denetimde, 3.0), "denetim saatinde müdür izliyor")
	b = masa.belgeler[0]
	masa.karar_ver("eksik", b, b.get_global_transform() * (b.size * 0.5), "ad_soyad")
	esit(masa.gunluk_ihtar, 2, "müdür izlerken hata: çift ihtar")
	esit(str(Oyun.bayrak("tarik1", "")), "eksik", "sivil başkomiserin ilk ziyareti kaydedildi")
	masa.dakika = float(masa.gun.denetim[0][1]) + 1.0
	dogru(await kosulu_bekle(func() -> bool: return not masa.denetimde, 3.0), "denetim bitince jaluzi iner")
	await bekle(0.3)

	# aranan şahıs yakalanınca
	masa = await _gune_git(5)
	_one_al(masa, "kasap5")
	bas("GiseyiAc")
	await _cantayi_gecir(masa, "gecir")
	await kosulu_bekle(func() -> bool: return masa.belgeler.size() >= 1 and not masa._mesgul)
	b = masa.belgeler[0]
	masa.karar_ver("havale", b, b.get_global_transform() * (b.size * 0.5))
	esit(str(Oyun.bayrak("kasap", "")), "yakalandi", "aranan şahıs havale edildi: yakalandı")
	esit(int(masa.ozet.kazanc), Oyun.PRIM + Oyun.SUPHELI_PRIMI, "  prim ve şüpheli primi yazıldı")
	await bekle(0.3)

	# evraksız ziyaretçi: Yusuf mektubu getirir
	masa = await _gune_git(7, {"husnu_onay": 3})
	dogru(_one_al(masa, "yusuf"), "Hüsnü Amca'ya onay verildiyse 7. gün Yusuf gelir")
	bas("GiseyiAc")
	dogru(await kosulu_bekle(func() -> bool: return dugme("MektubuKatla") != null, 20.0), "Yusuf mektubu masaya bıraktı")
	var saat_once: float = masa.dakika
	await bekle(0.4)
	esit(masa.dakika, saat_once, "mektup okunurken saat işlemiyor")
	dogru(bool(Oyun.bayrak("mektup", false)), "mektup bayrağı yazıldı")
	bas("MektubuKatla")
	dogru(await kosulu_bekle(func() -> bool: return masa.vatandas.is_empty() or str(masa.vatandas.get("kod", "")) != "yusuf", 6.0), "Yusuf gitti")
	esit(int(masa.ozet.islenen), 0, "evraksız ziyaret işlem sayılmaz")
	masa = await _gune_git(7)
	dogru(not _one_al(masa, "yusuf") and _one_al(masa, "husnu7"), "onay verilmediyse 7. gün Hüsnü Amca kendisi gelir")

	# son ekranı
	Oyun.yeni_oyun()
	Oyun.gun = 7
	Oyun.bayraklar = {"savci": "yarali", "mektup": true, "husnu_onay": 7}
	Oyun.son = {"tur": "olagan", "neden": "yerinde"}
	await sahneye_git("son")
	bekle_dogru(await sahneyi_bekle("Son"), "son ekranı açıldı")
	var son_sahne := sahne()
	dogru(son_sahne.find_child("Gazete", true, false) != null, "  gazete sayfası var")
	dogru(son_sahne.find_child("Mektup", true, false) != null, "  mektup var")
	dogru(dugme("AnaMenu") != null, "  ana menü düğmesi var")


# --- Röntgen cihazı ve vesikalıklar ---

## Vatandaşın çantası varsa röntgene alır ve verilen kararı düğmeyle verir. Çanta yoksa hiçbir şey yapmaz.
func _cantayi_gecir(masa: Node, karar: String) -> bool:
	if not await kosulu_bekle(func() -> bool: return masa.canta_asamasi == "bekliyor" or masa.belgeler.size() >= 1, 10.0):
		return false
	if masa.canta_asamasi != "bekliyor":
		return false
	bas("CantayiTara")
	if not await kosulu_bekle(func() -> bool: return masa.rontgen.karar_bekliyor, 8.0):
		return false
	bas("RontgenAlarm" if karar == "alarm" else "RontgenGecir")
	return true


func _rontgen_testi() -> void:
	print("-- röntgen ve vesikalık --")
	# vesikalıklar: herkesin ayrı bir fotoğrafı ve benzerleri var
	var eksik_vesika := 0
	var eksik_benzer := 0
	for kimlik in Portreler.havuz():
		if Portreler.vesikalik(kimlik) == Portreler.doku(kimlik):
			eksik_vesika += 1
		if Portreler.benzerler(kimlik).size() < 3:
			eksik_benzer += 1
	esit(eksik_vesika, 0, "havuzdaki herkesin ayrı bir vesikalığı var")
	esit(eksik_benzer, 0, "herkesin en az üç benzeri var")
	dogru(Portreler.aranan_resmi("v27") != Portreler.vesikalik("v27"), "arananların dosya resmi vesikalıktan ayrı")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var yakin := 0
	for i in 40:
		var kim: String = Portreler.havuz()[i % Portreler.havuz().size()]
		var sahte: String = VatandasUretici._baska_portre(kim, rng, 3)
		if sahte != kim and Portreler.benzerler(kim).slice(0, 3).has(sahte):
			yakin += 1
	esit(yakin, 40, "zor günlerde sahte fotoğraf, en benzer üç kişiden birine ait")

	# çanta üreticisi: her eşyanın görseli var, yasaklar günün kuralına uyuyor
	var bozuk := 0
	var yasakli := 0
	var buyuk_esya := 0
	for gun_no: int in [5, 6, 7]:
		var gun := Veri.gun(gun_no)
		dogru(Canta.denetim_var(gun), "%d. günde çanta denetimi var" % gun_no)
		var yasak: Array = Veri.kural(gun, "canta_kontrol").get("yasak", [])
		for i in 150:
			rng.seed = gun_no * 1000 + i
			var c := Canta.uret(gun, rng)
			if Canta.kabuk_dokusu(str(c.tur)) == null or Canta.dis_doku(str(c.tur)) == null or (c.esyalar as Array).size() < 3:
				bozuk += 1
			for e: Dictionary in c.esyalar:
				var bilgi := Canta.esya(str(e.ad))
				if bilgi.is_empty() or Canta.esya_dokusu(str(e.ad)) == null:
					bozuk += 1
				if str(c.tur) == "el_cantasi" and not bool(bilgi.get("kucuk", false)):
					buyuk_esya += 1
			var bulunan := Canta.yasaklar(c, gun)
			for ad in bulunan:
				if not yasak.has(str(Canta.esya(ad).get("kategori", ""))):
					bozuk += 1
			if not bulunan.is_empty():
				yasakli += 1
	esit(bozuk, 0, "450 rastgele çantanın hepsi geçerli")
	esit(buyuk_esya, 0, "el çantasına yalnızca küçük eşya girer")
	dogru(yasakli > 90 and yasakli < 190, "çantaların yaklaşık üçte birinde yasak eşya var (%d/450)" % yasakli)
	dogru(not Canta.denetim_var(Veri.gun(4)), "4. günde çanta denetimi yok")

	# 5. gün: satır henüz yasak değil; geçirmek doğru, evrak ardından gelir
	var masa: Node = await _gune_git(5)
	_one_al(masa, "kasap5")
	bas("GiseyiAc")
	dogru(await kosulu_bekle(func() -> bool: return masa.canta_asamasi == "bekliyor"), "çantalı vatandaş: çanta eşikte bekliyor")
	esit(masa.belgeler.size(), 0, "  çanta geçmeden evrak gelmez")
	dogru(not (masa.araclar["onay"] as Arac).etkin, "  çanta geçmeden mühür kullanılamaz")
	bas("CantayiTara")
	dogru(await kosulu_bekle(func() -> bool: return masa.rontgen.karar_bekliyor, 8.0), "  röntgen açıldı, görüntü ekranda")
	bas("RontgenKip2")
	esit(masa.rontgen.kip, 2, "  görüntü kipi değişti")
	bas("RontgenGecir")
	dogru(await kosulu_bekle(func() -> bool: return masa.belgeler.size() >= 1 and not masa._mesgul, 8.0), "  geçirince evrak geldi")
	dogru(not masa.vatandas.has("canta_kacti"), "  5. gün satır yasak değil: kaçak sayılmaz")
	dogru(not masa.rontgen.acik, "  cihaz kapandı")

	# boş alarm: zaman gider, ilkinde ihtar yok, ikincisinde var
	masa = await _gune_git(5)
	_one_al(masa, "husnu5")
	bas("GiseyiAc")
	var once: float = masa.dakika
	dogru(await _cantayi_gecir(masa, "alarm"), "Hüsnü Amca'nın torbasına alarm verildi")
	esit(masa.bos_alarm, 1, "  boş alarm sayıldı")
	dogru(masa.dakika >= once + masa.ALARM_KAYBI, "  mesaiden zaman gitti")
	esit(masa.gunluk_ihtar, 0, "  ilk boş alarmda ihtar yok")
	dogru(await kosulu_bekle(func() -> bool: return masa.belgeler.size() >= 1 and not masa._mesgul, 8.0), "  evrak yine de geldi")
	masa._bos_alarm(masa.vatandas.canta)
	esit(masa.gunluk_ihtar, 1, "  ikinci boş alarm ihtar getirir")
	await bekle(2.2)

	# 6. gün: "Terzi"nin el çantasında tabanca; alarm onu yakalar
	masa = await _gune_git(6)
	_one_al(masa, "naciye6")
	bas("GiseyiAc")
	dogru(await _cantayi_gecir(masa, "alarm"), "tabancalı el çantasına alarm verildi")
	esit(str(Oyun.bayrak("naciye", "")), "yakalandi", "  \"Terzi\" röntgende yakalandı")
	esit(int(masa.ozet.kazanc), Oyun.PRIM + Oyun.SUPHELI_PRIMI, "  prim ve şüpheli primi yazıldı")
	esit(masa.gunluk_ihtar, 0, "  ihtar yok")
	dogru(await kosulu_bekle(func() -> bool: return masa.vatandas.is_empty() or str(masa.vatandas.get("kod", "")) != "naciye6", 8.0), "  şahıs evrakına bakılmadan götürüldü")

	# 7. gün: bavuldaki saatli bomba gözden kaçarsa
	masa = await _gune_git(7)
	_one_al(masa, "bavullu7")
	bas("GiseyiAc")
	dogru(await _cantayi_gecir(masa, "gecir"), "saatli bombalı bavul geçirildi")
	esit(str(Oyun.bayrak("bomba", "")), "kacti", "  bavul binaya girdi")
	await kosulu_bekle(func() -> bool: return masa.belgeler.size() >= 1 and not masa._mesgul, 8.0)
	var b: Belge = masa.belgeler[0]
	masa.karar_ver("onay", b, b.get_global_transform() * (b.size * 0.5))
	esit(masa.gunluk_ihtar, 1, "  evrakı düzgün olsa da kaçan çanta ihtar getirir")
	dogru(Hikaye.son({"tur": "olagan"}, Oyun.bayraklar).yan.any(func(y: Dictionary) -> bool: return str(y.baslik).contains("PATLAMA")), "  son gazetede patlama haberi çıkar")
	await bekle(0.3)
	masa = await _gune_git(7)
	_one_al(masa, "bavullu7")
	bas("GiseyiAc")
	await _cantayi_gecir(masa, "alarm")
	esit(str(Oyun.bayrak("bomba", "")), "yakalandi", "saatli bomba röntgende yakalandı")
	await bekle(0.3)


# --- Aşama 5: sesler, ana menü, ayarlar, mola ---

func _cila_testi() -> void:
	print("== Sesler, menü, ayarlar, mola ==")
	# sesler: oyunun çağırdığı her ad için dosya var
	for ad: String in ["muhur", "kagit", "kagit_kay", "sayfa", "zil", "teleks", "daktilo", "yirt", "hece", "adim",
			"ofle", "kepenk", "ihtar", "prim", "tik", "saat", "jaluzi", "zarf", "kalem", "patlama", "silah",
			"soba", "ruzgar", "radyo"]:
		dogru(Ses._akis(ad) != null, "ses dosyası var: %s" % ad)
	dogru(AudioServer.get_bus_index("Efekt") >= 0 and AudioServer.get_bus_index("Ortam") >= 0, "ses veriyolları kuruldu")
	Ses.cal("olmayan_ses")
	dogru(true, "bilinmeyen ses adı sessizce geçilir")

	# ayarlar (kullanıcının dosyası testten sonra eski hâline döner)
	var eski: Dictionary = Oyun.ayarlar.duplicate()
	await sahneye_git("menu")
	bekle_dogru(await sahneyi_bekle("AnaMenu"), "ana menü")
	for ad: String in ["YeniOyun", "Devam", "Ayarlar", "Cikis"]:
		dogru(dugme(ad) != null, "  menüde '%s' var" % ad)
	bas("Ayarlar")
	await kare(3)
	var ayarlar := sahne().find_child("AyarlarPenceresi", true, false)
	dogru(ayarlar != null, "Ayarlar penceresi açıldı")
	bas("Hiz_Telaşlı")
	esit(float(Oyun.ayar("saat_hizi")), 0.7, "  mesai saati hızı değişti")
	bas("Hiz_Sakin")
	esit(float(Oyun.ayar("saat_hizi")), 1.4, "  yavaşlatıldı")
	var kademe: Control = ayarlar.find_child("Kademe_ses_efekt", true, false)
	kademe.degisti.emit(0.3)
	esit(float(Oyun.ayar("ses_efekt")), 0.3, "  efekt sesi kademeden ayarlandı")
	dogru(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Efekt")) - linear_to_db(0.3)) < 0.01, "  veriyoluna işlendi")
	kademe.degisti.emit(0.0)
	dogru(AudioServer.is_bus_mute(AudioServer.get_bus_index("Efekt")), "  sıfırda veriyolu susar")
	bas("AyarKapat")
	await kare(3)
	dogru(sahne().find_child("AyarlarPenceresi", true, false) == null, "Ayarlar kapandı")
	for anahtar: String in eski:
		Oyun.ayar_degistir(anahtar, eski[anahtar])

	# mola
	dogru(not Oyun.mola_verilebilir(), "ana menüde mola verilmez")
	var masa: Node = await _gune_git(1)
	bas("GiseyiAc")
	await kosulu_bekle(func() -> bool: return masa.mesai_acik)
	await bekle(0.3)
	dogru(Oyun.mola_verilebilir(), "masada mola verilebilir")
	Oyun.mola_ver()
	await kare(3)
	dogru(get_tree().paused and dugme("MolaDevam") != null, "mola: oyun durdu, menü açıldı")
	var saat_once: float = masa.dakika
	await bekle(0.5)
	esit(masa.dakika, saat_once, "  molada saat işlemiyor")
	bas("MolaAyarlar")
	await kare(3)
	dogru(dugme("AyarKapat") != null, "  moladan ayarlar açılıyor")
	bas("AyarKapat")
	await kare(3)
	bas("MolaDevam")
	await kare(3)
	dogru(not get_tree().paused, "Gişeye Dön: oyun sürüyor")
	await bekle(0.4)
	dogru(masa.dakika > saat_once, "  saat yeniden işliyor")
	Oyun.mola_ver()
	await kare(3)
	bas("MolaMenu")
	bekle_dogru(await sahneyi_bekle("AnaMenu"), "moladan ana menüye dönüldü")
	dogru(not get_tree().paused, "  oyun duraklatılmış kalmadı")
	dogru(not dugme("Devam").disabled, "  sabahki kayıt duruyor: Devam açık")

