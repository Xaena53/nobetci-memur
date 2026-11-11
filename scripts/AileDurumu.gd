class_name AileDurumu
extends RefCounted
## Evdeki durum: aile üyelerinin sağlığı, akşam masrafları ve gecenin sonuçları.
##
## Memur dul; evde annesi Hacer Hanım, kızı Elif (8) ve oğlu Can (4) var.
## Sağlık 3'ten (iyi) 0'a (ağır hasta) iner. Kömür alınmayan gece ev soğur, yiyecek alınmayan
## gece herkes aç yatar; hasta olana ilaç alınmazsa kötüleşir. Biri ağır hastalanırsa ya da
## kira üç akşam ödenmezse oyun kötü sonla biter.

const UYELER := ["anne", "elif", "can"]
const BILGI := {
	"anne": {"ad": "Hacer Hanım", "hitap": "Anneniz", "kisa": "Annenizin", "zayif": true},
	"elif": {"ad": "Elif", "hitap": "Kızınız Elif", "kisa": "Elif'in", "zayif": false},
	"can": {"ad": "Can", "hitap": "Oğlunuz Can", "kisa": "Can'ın", "zayif": true},
}
const SAGLIK_ADI := ["ağır hasta", "hasta", "halsiz", "iyi"]

const KIRA := 350
const KOMUR := 200
const YEMEK := 250
const ILAC := 300
const KIRA_SINIRI := 3      ## bu kadar akşam ödenmeyince tahliye
## Okulun para istediği akşamlar (gün → masraf).
const OKUL := {
	2: {"ad": "Elif'e defter ve kalem", "tutar": 150},
	4: {"ad": "Okul aile birliği aidatı", "tutar": 200},
	6: {"ad": "Elif'e kışlık bot", "tutar": 400},
}
## Annenin tansiyon ilacının bittiği akşamlar.
const ANNE_ILACI := [3, 6]


static func yeni() -> Dictionary:
	return {
		"saglik": {"anne": 3, "elif": 3, "can": 3},
		"soguk_gece": 0,      ## üst üste soğuk geçen gece sayısı
		"kira_borcu": 0,      ## ödenmemiş akşam sayısı
		"okul_eksigi": 0,
		"ikram": false,       ## komşudan yemek geldiyse o akşam yiyecek parasızdır
		"kira_affi": false,   ## ev sahibi o akşam kirayı istemiyorsa
	}


## Kayıttan gelen sözlüğü eksik alanlara karşı onarır (JSON sayıları tam sayıya çevrilir).
static func onar(v: Variant) -> Dictionary:
	var a := yeni()
	if typeof(v) != TYPE_DICTIONARY:
		return a
	var s: Dictionary = v.get("saglik", {})
	for u: String in UYELER:
		a.saglik[u] = clampi(int(s.get(u, 3)), 0, 3)
	a.soguk_gece = int(v.get("soguk_gece", 0))
	a.kira_borcu = int(v.get("kira_borcu", 0))
	a.okul_eksigi = int(v.get("okul_eksigi", 0))
	a.ikram = bool(v.get("ikram", false))
	a.kira_affi = bool(v.get("kira_affi", false))
	return a


static func saglik(aile: Dictionary, uye: String) -> int:
	return int((aile.get("saglik", {}) as Dictionary).get(uye, 3))


## "Anneniz Hacer Hanım: halsiz" gibi durum satırı.
static func durum_metni(aile: Dictionary, uye: String) -> String:
	return "%s: %s" % [str(BILGI[uye].hitap), SAGLIK_ADI[saglik(aile, uye)]]


## O akşamın masraf kalemleri: [{kod, ad, tutar, not}]
static func masraflar(aile: Dictionary, gun: int) -> Array[Dictionary]:
	var liste: Array[Dictionary] = []
	var borc := int(aile.get("kira_borcu", 0))
	var kira_notu := ""
	if borc == 1:
		kira_notu = "Ev sahibi dün de bekledi."
	elif borc >= 2:
		kira_notu = "Son uyarı: bu akşam ödenmezse tahliye."
	if bool(aile.get("kira_affi", false)):
		liste.append({"kod": "kira", "ad": "Kira", "tutar": 0, "not": "Ev sahibi bu akşam kirayı istemedi."})
	else:
		liste.append({"kod": "kira", "ad": "Kira", "tutar": KIRA, "not": kira_notu})
	liste.append({"kod": "komur", "ad": "Kömür", "tutar": KOMUR, "not": ""})
	if bool(aile.get("ikram", false)):
		liste.append({"kod": "yemek", "ad": "Yiyecek", "tutar": 0, "not": "Nermin Hanım bir tencere yemek getirdi."})
	else:
		liste.append({"kod": "yemek", "ad": "Yiyecek", "tutar": YEMEK, "not": ""})
	for u: String in UYELER:
		var s := saglik(aile, u)
		if s <= 1:
			liste.append({"kod": "ilac_" + u, "ad": "%s ilacı" % str(BILGI[u].kisa), "tutar": ILAC,
				"not": "%s hasta." % str(BILGI[u].hitap)})
		elif u == "anne" and ANNE_ILACI.has(gun):
			liste.append({"kod": "ilac_anne", "ad": "Annenizin tansiyon ilacı", "tutar": ILAC, "not": "Kutusu bitti."})
	if OKUL.has(gun):
		liste.append({"kod": "okul", "ad": str(OKUL[gun].ad), "tutar": int(OKUL[gun].tutar), "not": ""})
	return liste


## Geceyi geçirir: ödenen kalemlere göre aileyi günceller.
## Dönüş: {satirlar: [gecenin anlatımı], son: "" | "aile" | "tahliye", kritik: üye}
static func geceyi_gecir(aile: Dictionary, gun: int, odenen: Array) -> Dictionary:
	var satirlar: Array[String] = []
	var komur := odenen.has("komur")
	var yemek := odenen.has("yemek")
	var kalemler := masraflar(aile, gun)
	var kodlar: Array[String] = []
	for k in kalemler:
		kodlar.append(str(k.kod))

	# kira
	if odenen.has("kira"):
		aile.kira_borcu = 0
	else:
		aile.kira_borcu = int(aile.kira_borcu) + 1
		match int(aile.kira_borcu):
			1:
				satirlar.append("Ev sahibi kapıya geldi. Kirayı yarına bıraktınız.")
			2:
				satirlar.append("Ev sahibi merdivenden bağırdı: \"Yarın akşam kira yoksa eşyalar sokakta!\"")
			_:
				satirlar.append("Ev sahibi iki hamalla geldi. Eşyalar kapının önüne indirildi.")
				return {"satirlar": satirlar, "son": "tahliye", "kritik": ""}

	# soba ve sofra
	var onceki_soguk := int(aile.soguk_gece)
	if komur:
		aile.soguk_gece = 0
	else:
		aile.soguk_gece = onceki_soguk + 1
		satirlar.append("Soba yanmadı. Ev sabaha kadar buz gibiydi." if onceki_soguk == 0
			else "Soba yine yanmadı. Camların içi buz tuttu.")
	if not yemek:
		satirlar.append("Sofraya bu akşam yalnız çay kondu. Çocuklar aç yattı.")
	aile.ikram = false
	aile.kira_affi = false

	# okul
	if kodlar.has("okul"):
		if odenen.has("okul"):
			satirlar.append("Elif yeni %s yastığının yanına koyup uyudu." % ("botlarını" if gun == 6 else "defterini")
				if gun != 4 else "Elif aidat makbuzunu çantasına özenle yerleştirdi.")
		else:
			aile.okul_eksigi = int(aile.okul_eksigi) + 1
			satirlar.append("Elif bir şey demedi; çantasını sessizce topladı.")

	# sağlık
	var kritik := ""
	for u: String in UYELER:
		var once := saglik(aile, u)
		var fark := 0
		var ilac_gerekli := kodlar.has("ilac_" + u)
		var ilac_alindi := odenen.has("ilac_" + u)
		if not komur and (bool(BILGI[u].zayif) or onceki_soguk >= 1):
			fark -= 1
		if not yemek:
			fark -= 1
		if once <= 1:
			fark += 1 if ilac_alindi else -1
		elif ilac_gerekli and not ilac_alindi:
			fark -= 1                      # annenin tansiyon ilacı alınmadı
		elif komur and yemek and once < 3:
			fark += 1                      # sıcak ev, tok karın: toparlanır
		var sonra := clampi(once + fark, 0, 3)
		aile.saglik[u] = sonra
		if sonra == once:
			continue
		var ad := str(BILGI[u].hitap)
		if sonra > once:
			satirlar.append("%s biraz toparlandı." % ad if sonra < 3 else "%s iyileşti." % ad)
		elif sonra == 2:
			satirlar.append("%s sabaha halsiz uyandı." % ad)
		elif sonra == 1:
			satirlar.append("%s gece boyu öksürdü; ateşi çıktı." % ad)
		else:
			satirlar.append("%s ateşi düşmedi. Gece yarısı hastaneye götürdünüz." % str(BILGI[u].kisa))
			kritik = u

	if kritik != "":
		return {"satirlar": satirlar, "son": "aile", "kritik": kritik}
	if satirlar.is_empty():
		satirlar.append("Soba yandı, karınlar doydu. Sakin bir geceydi.")
	return {"satirlar": satirlar, "son": "", "kritik": ""}
