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
