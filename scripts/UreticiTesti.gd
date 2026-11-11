extends Control
## Üretici testi (hata ayıklama sahnesi): her gün için 100 rastgele vatandaş üretir, hepsini
## doğrulayıcıdan geçirir ve istatistiği hem ekrana hem konsola yazar.
##
## Denetlenen: üreticinin kasten eklediği kusurlar ile doğrulayıcının bulduğu kusurlar birebir
## aynı mı? (Kusursuz üretilen vatandaş ONAY, kusurlu üretilen EKSİK çıkmalı.)
##
## Çalıştırma:  godot --path . res://scenes/UreticiTesti.tscn
##              godot --headless --path . res://scenes/UreticiTesti.tscn -- --cik   (yazıp çıkar)

const ADET := 100


func _ready() -> void:
	var rapor := calistir(ADET)
	print(rapor.metin)

	var zemin := ColorRect.new()
	zemin.color = Stil.KAGIT
	zemin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(zemin)
	var kaydirma := ScrollContainer.new()
	kaydirma.position = Vector2(24, 20)
	kaydirma.size = Vector2(1232, 630)
	add_child(kaydirma)
	var yazi := Stil.etiket(rapor.metin, 13)
	kaydirma.add_child(yazi)
	var geri := Button.new()
	geri.text = "Ana Menü"
	geri.position = Vector2(1090, 662)
	geri.pressed.connect(func() -> void: Oyun.sahneye_gec("menu"))
	add_child(geri)

	if OS.get_cmdline_user_args().has("--cik"):
		get_tree().quit(1 if int(rapor.tutarsiz) > 0 else 0)


## Her gün için `adet` vatandaş üretip doğrular. Dönüş: {metin, tutarsiz, gunler: [...]}
static func calistir(adet: int, tohum: int = 1984) -> Dictionary:
	var satirlar: Array[String] = []
	var toplam_tutarsiz := 0
	var gunler: Array[Dictionary] = []
	satirlar.append("ÜRETİCİ TESTİ — her gün %d rastgele vatandaş (tohum %d)" % [adet, tohum])
	satirlar.append("")
	var gun_no := 1
	while Veri.gun_var_mi(gun_no):
		var gun := Veri.gun(gun_no)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([tohum, gun_no])
		var kullanilan: Array = []
		var onay := 0
		var eksik := 0
		var cift_kusur := 0
		var tutarsiz := 0
		var sayac := {}
		var ornek := ""
		for i in adet:
			var v := VatandasUretici.uret(gun, rng, kullanilan)
			var sonuc := Dogrulayici.kontrol(v, gun)
			if sonuc.karar == "onay":
				onay += 1
			else:
				eksik += 1
			var bulunan: Array = (sonuc.gerekceler as Array).duplicate()
			var uretilen: Array = (v.uretilen as Array).duplicate()
			bulunan.sort()
			uretilen.sort()
			if bulunan != uretilen:
				tutarsiz += 1
				if ornek == "":
					ornek = "    ! üretilen %s  ≠  bulunan %s  (%s %s)" % [str(uretilen), str(bulunan), v.kimlik.ad, v.kimlik.soyad]
			if bulunan.size() > 1:
				cift_kusur += 1
			for g: String in bulunan:
				sayac[g] = int(sayac.get(g, 0)) + 1
		toplam_tutarsiz += tutarsiz
		gunler.append({"gun": gun_no, "onay": onay, "eksik": eksik, "tutarsiz": tutarsiz, "sayac": sayac})

		satirlar.append("GÜN %d  (%s, %d kural, hedef kusur oranı %%%d)" % [gun_no, str(gun.get("tarih", "")),
			(gun.get("kurallar", []) as Array).size(), roundi(float(gun.get("hata_orani", 0.0)) * 100.0)])
		satirlar.append("  ONAY %3d    EKSİK %3d (çift kusurlu %d)    tutarsız %d" % [onay, eksik, cift_kusur, tutarsiz])
		var dokum := PackedStringArray()
		for g: String in Dogrulayici.gunun_gerekceleri(gun):
			dokum.append("%s %d" % [g, int(sayac.get(g, 0))])
		satirlar.append("  kusurlar: " + ",  ".join(dokum))
		if ornek != "":
			satirlar.append(ornek)
		satirlar.append("")
		gun_no += 1

	satirlar.append("SONUÇ: %s" % ("üretici ile doğrulayıcı her vatandaşta aynı fikirde." if toplam_tutarsiz == 0
		else "%d vatandaşta üretici ile doğrulayıcı ayrıştı!" % toplam_tutarsiz))
	return {"metin": "\n".join(PackedStringArray(satirlar)), "tutarsiz": toplam_tutarsiz, "gunler": gunler}
