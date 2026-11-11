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
	await bekle(0.5)
	await cek("01_masa")
	sahne().mesaiyi_bitir()
	await sahneyi_bekle("GunSonu")
	await cek("02_gun_sonu")
	bas("EveGit")
	await sahneyi_bekle("Aile")
	await cek("03_aile")


func _senaryo_masa() -> void:
	Oyun.yeni_oyun()
	Oyun.sahneye_gec("masa")
	await sahneyi_bekle("Masa")
	var masa := sahne()
	await kosulu_bekle(func() -> bool: return masa.belgeler.size() >= 2 and not masa._mesgul)
	await bekle(1.6)
	await cek("10_masa_vatandas")
	masa.inceleme.aktif = true
	await kare(2)
	var cuzdan := _belge(masa, "nufus_cuzdani")
	var ikamet := _belge(masa, "ikametgah")
	masa.inceleme.hedef_tiklandi(cuzdan.alanlar["soyad"])
	masa.inceleme.hedef_tiklandi(ikamet.alanlar["soyad"])
	await bekle(0.3)
	await cek("11_inceleme_uyusmazlik")
	masa.inceleme.aktif = false
	ikamet.buyut(true)
	await bekle(0.4)
	await cek("12_belge_buyuk")
	ikamet.buyut(false)
	await bekle(0.3)
	masa.karar_ver("onay", cuzdan, cuzdan.global_position + Vector2(190, 120))
	await bekle(0.45)
	await cek("13_onay_muhru")


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
