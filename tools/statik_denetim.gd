extends Node
## Statik denetim: bütün betikleri yükler; derlenmeyen olursa adını yazar.
## Uyarıları hataya çeviren bir override.cfg ile çalıştırılır (bkz. tools/statik_denetim.sh).


func _ready() -> void:
	var kotu := 0
	var toplam := 0
	for klasor: String in ["res://scripts", "res://scripts/belgeler", "res://tools"]:
		for ad in DirAccess.get_files_at(klasor):
			if not ad.ends_with(".gd") or ad == "statik_denetim.gd":
				continue
			toplam += 1
			var betik: Variant = load(klasor + "/" + ad)
			if betik == null or not (betik as GDScript).can_instantiate():
				kotu += 1
				print("DERLENMEDİ: ", klasor + "/" + ad)
	print("STATİK DENETİM: %d betik, %d sorunlu" % [toplam, kotu])
	get_tree().quit(1 if kotu > 0 else 0)
