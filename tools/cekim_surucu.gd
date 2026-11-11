extends "res://tools/test_surucu.gd"
## Ekran görüntüsü sürücüsü. Senaryo adı komut satırından gelir:  -- akis

const CIKTI := "res://tools/cikti/"


func _calistir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CIKTI))
	var arg := OS.get_cmdline_user_args()
	var senaryo: String = arg[0] if arg.size() > 0 else "akis"
	var ad := "_senaryo_" + senaryo
	if has_method(ad):
		await call(ad)
	else:
		print("Bilinmeyen senaryo: ", senaryo)
	Oyun.kaydi_sil()
	get_tree().quit()


func cek(ad: String) -> void:
	await kare(2)
	await RenderingServer.frame_post_draw
	var goruntu := get_viewport().get_texture().get_image()
	var yol := ProjectSettings.globalize_path(CIKTI + ad + ".png")
	goruntu.save_png(yol)
	print("çekildi: ", yol)


func _senaryo_akis() -> void:
	Oyun.kaydi_sil()
	Oyun.sahneye_gec("menu")
	await sahneyi_bekle("AnaMenu")
	await cek("00_menu")
	bas("YeniOyun")
	await sahneyi_bekle("Masa")
	Oyun.gun = int(_arg("gun", "1"))
	await bekle(1.6)
	await cek("01_genelge")
	bas("GiseyiAc")
	var masa := sahne()
	await kosulu_bekle(func() -> bool: return masa.belgeler.size() >= 1 and not masa._mesgul)
	# birkaç karar: biri doğru, biri yanlış
	for i in 3:
		await kosulu_bekle(func() -> bool: return masa.belgeler.size() >= 1 and not masa._mesgul, 14.0)
		await bekle(0.6)
		var b: Belge = masa.belgeler[0]
		masa.karar_ver("onay", b, b.get_global_transform() * (b.size * 0.5))
		await bekle(0.5)
	masa.dakika = masa.MESAI_SONU - 0.5
	await bekle(2.2)
	await cek("02_kepenk")
	await sahneyi_bekle("GunSonu", 12.0)
	await bekle(2.6)
	await cek("03_gun_sonu")
	bas("EveGit")
	await sahneyi_bekle("Aile")
	await bekle(0.6)
	await cek("04_aile_bos")
	var aile := sahne()
	aile.sec("komur", true)
	aile.sec("yemek", true)
	await bekle(0.8)
	await cek("05_aile_secili")
	bas("Yat")
	await bekle(1.8)
	await cek("06_gece")


func _senaryo_masa() -> void:
	Oyun.yeni_oyun()
	Oyun.gun = int(_arg("gun", "1"))
	Oyun.sahneye_gec("masa")
	await sahneyi_bekle("Masa")
	var masa := sahne()
	bas("GiseyiAc")
	await kosulu_bekle(func() -> bool: return masa.belgeler.size() >= 1 and not masa._mesgul)
	await bekle(1.6)
	await cek("10_masa_vatandas")
	masa.inceleme.aktif = true
	await kare(2)
	var cuzdan := _belge(masa, "nufus_cuzdani")
	var ikamet := _belge(masa, "ikametgah")
	if ikamet != null:
		masa.inceleme.hedef_tiklandi(cuzdan.alanlar["soyad"])
		masa.inceleme.hedef_tiklandi(ikamet.alanlar["soyad"])
		await bekle(0.3)
		await cek("11_inceleme")
		masa.inceleme.aktif = false
		ikamet.buyut(true)
		await bekle(0.5)
		await cek("12_belge_buyuk")
		ikamet.buyut(false)
		await bekle(0.4)
	masa.inceleme.aktif = false
	# eksik evrak fişini sürükle: gerekçe penceresi
	var fis: Arac = masa.araclar["eksik"]
	var fis_yeri: Vector2 = fis.get_global_transform() * (fis.size / 2.0)
	var hedef_yer: Vector2 = cuzdan.get_global_transform() * (cuzdan.size * Vector2(0.55, 0.6))
	fare_bas(fis_yeri)
	await kare(2)
	fare_tasi(hedef_yer)
	await kare(2)
	await cek("13_fis_suruklenirken")
	fare_birak(hedef_yer)
	await bekle(0.4)
	await cek("14_gerekce_penceresi")
	var pencere := masa.find_child("GerekcePenceresi", true, false)
	if pencere != null:
		(pencere.find_child("Vazgec", true, false) as Button).pressed.emit()
	await kare(3)
	# yanlış karar: ihtar pusulası gelsin
	var kusurlu: bool = Dogrulayici.kontrol(masa.vatandas, masa.gun).karar == "eksik"
	if kusurlu:
		masa.karar_ver("onay", cuzdan, cuzdan.get_global_transform() * (cuzdan.size * Vector2(0.6, 0.6)))
	else:
		masa.karar_ver("eksik", cuzdan, cuzdan.get_global_transform() * (cuzdan.size * Vector2(0.6, 0.6)), "ad_soyad")
	await bekle(0.5)
	await cek("15_karar_izi")
	await bekle(2.3)
	await cek("16_teleks_basliyor")
	await bekle(1.0)
	await cek("17_teleks_ortasi")
	await bekle(3.2)
	await cek("18_teleks_bitti")


## Canlı portre denemesi: aynı vatandaşın farklı ifadeleri (kareler tools/cikti/p_*.png).
func _senaryo_portre() -> void:
	Oyun.yeni_oyun()
	Oyun.gun = int(_arg("gun", "1"))
	Oyun.sahneye_gec("masa")
	await sahneyi_bekle("Masa")
	var masa := sahne()
	bas("GiseyiAc")
	await kosulu_bekle(func() -> bool: return masa.belgeler.size() >= 1 and not masa._mesgul)
	var p: CanliPortre = masa.gise.portre
	await kosulu_bekle(func() -> bool: return not p.konusuyor, 10.0)
	await bekle(0.3)
	p.set_process(false)
	var m: ShaderMaterial = p._malzeme
	var sifir := func() -> void:
		for ad: String in ["kirpma", "agiz_acik", "yanak", "bas_egim", "nefes", "kas"]:
			m.set_shader_parameter(ad, 0.0)
		m.set_shader_parameter("bas", Vector2.ZERO)
	sifir.call()
	await cek("p_0_duz")
	m.set_shader_parameter("kirpma", 1.0)
	await cek("p_1_goz_kapali")
	sifir.call()
	m.set_shader_parameter("kirpma", 0.5)
	await cek("p_2_goz_yari")
	sifir.call()
	m.set_shader_parameter("agiz_acik", 1.0)
	m.set_shader_parameter("kas", 0.6)
	await cek("p_3_agiz_acik")
	sifir.call()
	m.set_shader_parameter("agiz_acik", 0.45)
	await cek("p_4_agiz_yari")
	sifir.call()
	m.set_shader_parameter("yanak", 1.0)
	m.set_shader_parameter("kas", -0.7)
	m.set_shader_parameter("nefes", 1.9)
	await cek("p_5_yanak_sisik")
	sifir.call()
	m.set_shader_parameter("kas", -0.9)
	m.set_shader_parameter("bas", Vector2(0.010, 0.010))
	m.set_shader_parameter("nefes", -0.9)
	await cek("p_6_uzgun")
	sifir.call()
	m.set_shader_parameter("kas", 1.0)
	m.set_shader_parameter("bas_egim", 0.045)
	await cek("p_7_saskin")
	sifir.call()
	p.set_process(true)
	p.ofle()
	await bekle(0.95)
	await cek("p_8_ofleme")
	await bekle(0.35)
	await cek("p_9_ofleme_sonu")


## Ağız denemesi: belirli portrelerde kapalı / yarı açık / tam açık ağız (kareler a_*.png).
func _senaryo_agiz() -> void:
	Oyun.yeni_oyun()
	Oyun.sahneye_gec("masa")
	await sahneyi_bekle("Masa")
	var masa := sahne()
	bas("GiseyiAc")
	await kosulu_bekle(func() -> bool: return masa.belgeler.size() >= 1 and not masa._mesgul)
	var p: CanliPortre = masa.gise.portre
	await kosulu_bekle(func() -> bool: return not p.konusuyor, 10.0)
	p.set_process(false)
	var m: ShaderMaterial = p._malzeme
	var no := 0
	for kimlik: String in ["v01", "v06", "v19", "husnu", "v41", "nermin"]:
		p.ayarla(kimlik, Gise.OLCEK)
		p.position = Vector2((masa.gise.size.x - p.size.x) / 2.0, masa.gise.size.y - p.size.y + 3.0)
		for ad: String in ["kirpma", "yanak", "bas_egim", "nefes", "kas"]:
			m.set_shader_parameter(ad, 0.0)
		m.set_shader_parameter("bas", Vector2.ZERO)
		for acik: float in [0.0, 0.4, 0.75, 1.0]:
			m.set_shader_parameter("agiz_acik", acik)
			await cek("a_%d_%d" % [no, roundi(acik * 100.0)])
		no += 1


func _arg(ad: String, yedek: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(ad + "="):
			return a.substr(ad.length() + 1)
	return yedek


## Yazı tipi denemesi: küçük puntolarda Türkçe harflerin noktaları, ipucu (hinting) ayarına göre.
func _senaryo_font() -> void:
	var kok := ColorRect.new()
	kok.color = Stil.KAGIT_BEYAZ
	kok.size = Vector2(1280, 720)
	get_tree().root.add_child(kok)
	var metin := "NÜFUS HÜVİYET CÜZDANI  Doğum Yeri  İKAMETGÂH İLMÜHABERİ  ığüşöç ĞÜŞİÖÇ"
	var y := 10.0
	for dosya: String in ["OldStandard-Regular.ttf", "OldStandard-Bold.ttf", "OldStandard-Italic.ttf", "CourierPrime-Regular.ttf"]:
		for ipucu: int in [TextServer.HINTING_LIGHT, TextServer.HINTING_NONE]:
			var f: FontFile = (load("res://assets/font/" + dosya) as FontFile).duplicate()
			f.hinting = ipucu as TextServer.Hinting
			for punto: int in [9, 11, 14]:
				var l := Label.new()
				l.text = "%s h%d %dpx: %s" % [dosya.substr(0, 14), ipucu, punto, metin]
				l.add_theme_font_override("font", f)
				l.add_theme_font_size_override("font_size", punto)
				l.add_theme_color_override("font_color", Stil.MUREKKEP)
				l.position = Vector2(10, y)
				kok.add_child(l)
				y += punto + 12.0
	await cek("font_deneme")
	kok.queue_free()


## Hikâye ekranları: sabah gazetesi, arananlar, zarf, müdür denetimi, ev, gece, sonlar (h_*.png).
func _senaryo_hikaye() -> void:
	# 4. gün sabahı: gazete + genelge
	var masa: Node = await _gune_git(4)
	await bekle(2.4)
	await cek("h_01_sabah_gazete")
	_one_al(masa, "izzet4")
	bas("GiseyiAc")
	await kosulu_bekle(func() -> bool: return masa.belgeler.size() >= 1 and not masa._mesgul)
	masa.kural_kitabi.sayfaya_gec(99)
	masa.dakika = 575.0
	await bekle(2.6)
	await cek("h_02_arananlar_denetim")

	# 3. gün: müteahhit ve zarf
	masa = await _gune_git(3)
	_one_al(masa, "kenan3")
	bas("GiseyiAc")
	await kosulu_bekle(func() -> bool: return masa.belgeler.size() >= 1 and not masa._mesgul)
	await bekle(2.6)
	await cek("h_03_zarf")
	masa.zarf.al()
	await bekle(1.2)
	await cek("h_04_zarf_alindi")

	# 5. gün: aranan şahıs camda, inceleme
	masa = await _gune_git(5)
	_one_al(masa, "kasap5")
	bas("GiseyiAc")
	await kosulu_bekle(func() -> bool: return masa.belgeler.size() >= 1 and not masa._mesgul)
	masa.kural_kitabi.sayfaya_gec(99)
	await bekle(1.5)
	masa.inceleme.aktif = true
	await kare(3)
	masa.inceleme.hedef_tiklandi(masa.gise.yuz)
	for h: Hedef in masa.kural_kitabi.hedefler:
		if h.anahtar == "v27":
			masa.inceleme.hedef_tiklandi(h)
	await bekle(0.5)
	await cek("h_05_aranan_inceleme")
	masa.inceleme.aktif = false
	var b: Belge = masa.belgeler[0]
	masa.karar_ver("havale", b, b.get_global_transform() * (b.size * 0.5))
	await bekle(7.5)
	await cek("h_06_aranan_yakalandi")

	# 7. gün: evraksız ziyaretçi (Yusuf)
	masa = await _gune_git(7, {"husnu_onay": 3})
	_one_al(masa, "yusuf")
	bas("GiseyiAc")
	await bekle(4.2)
	await cek("h_07_yusuf")

	# ev: tam boy aile
	Oyun.yeni_oyun()
	Oyun.gun = 2
	Oyun.para = 1400
	Oyun.bayraklar = {"nermin": "kayirildi"}
	Oyun.aile["ikram"] = true
	Oyun.sahneye_gec("aile")
	await sahneyi_bekle("Aile")
	await bekle(1.0)
	await cek("h_08_ev")
	var aile := sahne()
	aile.sec("komur", true)
	aile.sec("yemek", true)
	aile.sec("okul", true)
	await bekle(1.0)
	await cek("h_09_ev_secili")

	# ev: hastalık ve çok kalem
	Oyun.yeni_oyun()
	Oyun.gun = 6
	Oyun.para = 900
	Oyun.aile["saglik"] = {"anne": 1, "elif": 2, "can": 0}
	Oyun.aile["kira_borcu"] = 2
	Oyun.bayraklar = {"kasap": "yakalandi", "naciye": "gecti", "savci_tanisti": true}
	Oyun.sahneye_gec("aile")
	await sahneyi_bekle("Aile")
	await bekle(1.0)
	await cek("h_10_ev_hasta")
	aile = sahne()
	aile.sec("kira", true)
	aile.sec("komur", true)
	bas("Yat")
	await bekle(2.0)
	await cek("h_11_gece_olay")

	# sonlar
	Oyun.yeni_oyun()
	Oyun.gun = 7
	Oyun.para = 2350
	Oyun.ihtar = 4
	Oyun.toplam = {"islenen": 61, "dogru": 52, "yanlis": 4, "kazanc": 7400}
	Oyun.bayraklar = {"savci": "sag", "husnu_onay": 7, "mektup": true, "tarik_sonuc": "ovgu"}
	Oyun.son = {"tur": "terfi", "neden": "basari"}
	Oyun.sahneye_gec("son")
	await sahneyi_bekle("Son")
	await bekle(3.0)
	await cek("h_12_son_terfi")
	Oyun.bayraklar = {"savci": "oldu", "husnu_onay": -1}
	Oyun.suphe = 5
	Oyun.son = {"tur": "surgun", "neden": "suphe"}
	Oyun.sahneye_gec("menu")
	await sahneyi_bekle("AnaMenu")
	Oyun.sahneye_gec("son")
	await sahneyi_bekle("Son")
	await bekle(3.0)
	await cek("h_13_son_surgun")
