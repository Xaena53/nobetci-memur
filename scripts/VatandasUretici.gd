class_name VatandasUretici
extends RefCounted
## Rastgele vatandaş üretir: kimlik, portre, işlem, belgeler ve konuşma. Vatandaşların bir
## bölümüne (günün `hata_orani`) günün kurallarına göre seçilmiş 1–2 kasıtlı kusur eklenir.
##
## Dönüş: {tur: "rastgele", portre, kimlik, islem, belgeler: [...], konusma: {...}, uretilen: [gerekçeler]}

const VARSAYILAN_SERI := [{"onek": "A", "min": 100000, "max": 499999}]
const VARSAYILAN_TARIFE := {"kayit_ornegi": 250, "cuzdan_yenileme": 1250, "nakil": 750}
const HARF_CIFTLERI := {
	"A": "E", "E": "A", "M": "N", "N": "M", "T": "D", "D": "T", "K": "G", "P": "B", "B": "P",
	"Z": "S", "R": "L", "L": "R", "F": "V", "V": "F", "H": "N", "Y": "V",
}
const NOKTA_CIFTLERI := {
	"I": "İ", "İ": "I", "O": "Ö", "Ö": "O", "U": "Ü", "Ü": "U", "C": "Ç", "Ç": "C", "S": "Ş", "Ş": "S", "G": "Ğ",
}


## `hata_adedi` −1 ise kusur sayısı günün oranına göre zarla belirlenir; 0 kusursuz demektir.
## `kullanilan`: daha önce görülen portre kimlikleri (aynı yüz iki kez gelmesin diye; güncellenir).
static func uret(gun: Dictionary, rng: RandomNumberGenerator, kullanilan: Array = [], hata_adedi: int = -1) -> Dictionary:
	var adlar := Veri.adlar()
	var bugun := str(gun.get("tarih", "09.01.1984"))

	var portre := _portre_sec(rng, kullanilan, gun)
	var bilgi := Portreler.bilgi(portre)
	var cins := str(bilgi.get("cinsiyet", "E"))
	var yas := int(bilgi.get("yas", 40))

	var kimlik := {
		"ad": Stil.buyuk(_sec(adlar.get("erkek" if cins == "E" else "kadin", ["Ali"]), rng)),
		"soyad": Stil.buyuk(_sec(adlar.get("soyad", ["Kaya"]), rng)),
		"baba_adi": Stil.buyuk(_sec(adlar.get("erkek", ["Ali"]), rng)),
		"ana_adi": Stil.buyuk(_sec(adlar.get("kadin", ["Ayşe"]), rng)),
		"dogum_yeri": Stil.buyuk(_sec(adlar.get("il", ["Ankara"]), rng)),
		"dogum_tarihi": _dogum_tarihi(yas, bugun, rng),
		"seri_no": _gecerli_seri(gun, rng),
		"cinsiyet": cins,
	}
	# Her yüz kalıcı bir kişidir: adı, soyadı, ana-baba adı, doğumu ve imzası değişmez
	# (rastgele değerler yine çekilir ki günün geri kalanı aynı tohumla aynı çıksın).
	var sabit := Veri.vatandas(portre)
	for alan: String in ["ad", "soyad", "baba_adi", "ana_adi", "dogum_yeri", "dogum_tarihi"]:
		if sabit.has(alan):
			kimlik[alan] = str(sabit[alan])
	kimlik["imza"] = "%s %s" % [kimlik.ad, kimlik.soyad]
	var islemler: Array = gun.get("islemler", ["kayit_ornegi"])
	var islem := str(_sec(islemler, rng))

	var v := {
		"tur": "rastgele",
		"portre": portre,
		"kimlik": kimlik,
		"islem": islem,
		"yas": yas,
		"belgeler": belgeleri_kur(kimlik, portre, islem, gun, rng),
		"uretilen": [],
	}

	if hata_adedi < 0:
		hata_adedi = 0
		if rng.randf() < float(gun.get("hata_orani", 0.4)):
			hata_adedi = 2 if rng.randf() < 0.22 else 1
	if hata_adedi > 0:
		_kusur_ekle(v, gun, rng, hata_adedi)

	# Çanta denetimi olan günlerde vatandaşların bir bölümü çantayla gelir.
	if Canta.denetim_var(gun) and rng.randf() < float(gun.get("canta_orani", 0.45)):
		v["canta"] = Canta.uret(gun, rng)
	v["konusma"] = _konusma(v, adlar, rng)
	return v


# --- Kimlik ve belgeler ---

const BENZEYEN_MASUM_ORANI := 0.14      ## arananlar varken: vatandaşın, aranan birine benzeyen biri olma olasılığı


static func _portre_sec(rng: RandomNumberGenerator, kullanilan: Array, gun: Dictionary = {}) -> String:
	var havuz := Portreler.havuz()
	if havuz.is_empty():
		return ""
	# Arananlar listesi yürürlükteyse ara sıra, listedeki resme benzeyen masum biri gelir.
	var arananlar: Array = Veri.kural(gun, "arananlar").get("liste", [])
	if not arananlar.is_empty() and rng.randf() < BENZEYEN_MASUM_ORANI:
		var aranan: Dictionary = arananlar[rng.randi_range(0, arananlar.size() - 1)]
		for aday in Portreler.benzerler(str(aranan.get("portre", "")), "aranan_benzer"):
			if havuz.has(aday) and not kullanilan.has(aday):
				kullanilan.append(aday)
				return aday
	var bos: Array[String] = []
	for p in havuz:
		if not kullanilan.has(p):
			bos.append(p)
	if bos.is_empty():      # havuz tükendi: baştan dağıt
		kullanilan.clear()
		bos = havuz
	var secilen: String = bos[rng.randi_range(0, bos.size() - 1)]
	kullanilan.append(secilen)
	return secilen


static func _dogum_tarihi(yas: int, bugun: String, rng: RandomNumberGenerator) -> String:
	var t := Tarih.coz(bugun)
	var yil: int = int(t.get("yil", 1984)) - yas - rng.randi_range(0, 1)
	var ay := rng.randi_range(1, 12)
	return Tarih.yaz(rng.randi_range(1, Tarih.ay_gunu(ay, yil)), ay, yil)


static func _gecerli_seri(gun: Dictionary, rng: RandomNumberGenerator) -> String:
	var kural := Veri.kural(gun, "seri_aralik")
	var araliklar: Array = kural.get("araliklar", VARSAYILAN_SERI)
	# Yeni seriler daha seyrek görülür.
	var a: Dictionary = araliklar[0] if (araliklar.size() == 1 or rng.randf() < 0.7) else araliklar[rng.randi_range(1, araliklar.size() - 1)]
	return "%s-%06d" % [str(a.onek), rng.randi_range(int(a.min) + 500, int(a.max) - 500)]


static func belgeleri_kur(kimlik: Dictionary, portre: String, islem: String, gun: Dictionary,
		rng: RandomNumberGenerator) -> Array:
	var adlar := Veri.adlar()
	var bugun := str(gun.get("tarih", "09.01.1984"))
	var belgeler: Array = []
	for tur: String in gun.get("belgeler", ["nufus_cuzdani", "ikametgah"]):
		match tur:
			"nufus_cuzdani":
				belgeler.append({"tur": tur, "foto": portre, "alanlar": kimlik.duplicate()})
			"calisma_vizesi":
				pass      # yalnızca yurt dışı çıkış kaydında, aşağıda eklenir
			"ikametgah":
				var m := _gecerli_mahalle(gun, adlar, rng)
				var sure := Veri.kural(gun, "tarih_sure", "ikametgah")
				var en_cok := int(sure.get("ay", 6)) * 30 - 12
				belgeler.append({"tur": tur, "alanlar": {
					"ad": kimlik.ad, "soyad": kimlik.soyad, "baba_adi": kimlik.baba_adi,
					"mahalle": str(m.ad),
					"adres": "%s No: %d" % [str(_sec(adlar.get("sokak", ["Okul Sok."]), rng)), rng.randi_range(1, 64)],
					"tarih": Tarih.gun_ekle(bugun, -rng.randi_range(2, maxi(3, en_cok))),
					"muhtar": str(m.muhtar),
					"muhtar_imza": true,
					"muhtar_muhur": true,
					"muhur_turu": "",                 # boş: gerçek mühür; doluysa sahtecilik türü (bkz. Damga)
					"imza_sahibi": str(m.muhtar),     # imzayı atan (sahte belgede başkası)
				}})
			"harc_makbuzu":
				var tarife: Dictionary = Veri.kural(gun, "harc_tutar").get("tutarlar", VARSAYILAN_TARIFE)
				var makbuz_suresi := Veri.kural(gun, "tarih_sure", "harc_makbuzu")
				var geri := rng.randi_range(0, int(makbuz_suresi.get("gun", 2)))
				if rng.randf() < 0.55:
					geri = 0
				belgeler.append({"tur": tur, "alanlar": {
					"ad": kimlik.ad, "soyad": kimlik.soyad,
					"islem": islem,
					"tutar": int(tarife.get(islem, 250)),
					"tarih": Tarih.gun_ekle(bugun, -geri),
					"makbuz_no": "%06d" % rng.randi_range(1200, 9800),
					"kase_turu": "",                  # boş: gerçek vezne kaşesi
				}})
	# Yurt dışı çıkış kaydı için çalışma vizesi de getirilir.
	var vize_kurali := Veri.kural(gun, "vize")
	if not vize_kurali.is_empty() and islem == str(vize_kurali.get("islem", "yurt_disi")):
		belgeler.append(vize_kur(kimlik, gun, rng))
	return belgeler


## Geçerli bir çalışma vizesi: numarası verilmiş aralıkta, süresi dolmamış, bilgileri cüzdanla aynı.
static func vize_kur(kimlik: Dictionary, gun: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var adlar := Veri.adlar()
	var bugun := str(gun.get("tarih", "09.01.1984"))
	var b: Dictionary = Veri.kural(gun, "vize").get("no", {})
	var verilis := Tarih.gun_ekle(bugun, -rng.randi_range(4, 38))
	return {"tur": "calisma_vizesi", "alanlar": {
		"ad": kimlik.ad, "soyad": kimlik.soyad,
		"dogum_tarihi": kimlik.get("dogum_tarihi", ""),
		"seri_no": kimlik.get("seri_no", ""),
		"ulke": str(_sec(adlar.get("ulkeler", ["Almanya"]), rng)),
		"meslek": str(_sec(adlar.get("meslekler", ["Kaynakçı"]), rng)),
		"vize_no": "%s-%02d-%05d" % [str(b.get("onek", "ÇV")), int(b.get("yil", 84)),
			rng.randi_range(int(b.get("min", 2000)) + 50, int(b.get("max", 6999)) - 50)],
		"verilis": verilis,
		"bitis": Tarih.gun_ekle(verilis, 90),
		"kase_turu": "",
		"imza": kimlik.get("imza", ""),
	}}


static func _gecerli_mahalle(gun: Dictionary, adlar: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var hepsi: Array = adlar.get("mahalleler", [{"ad": "Çarşı", "muhtar": "Rıza Aksoy"}])
	var kural := Veri.kural(gun, "mahalle_listesi")
	if kural.is_empty():
		return _sec(hepsi, rng)
	var uygun: Array = []
	for m: Dictionary in hepsi:
		if (kural.mahalleler as Array).has(str(m.ad)):
			uygun.append(m)
	return _sec(uygun if not uygun.is_empty() else hepsi, rng)


# --- Kasıtlı kusurlar ---

## Günün kurallarına göre uygulanabilecek kusur türleri: [[tür, ağırlık], ...]
static func kusur_adaylari(v: Dictionary, gun: Dictionary) -> Array:
	var belgeler := Dogrulayici.belge_sozlugu(v)
	var adaylar: Array = []
	for k: Dictionary in gun.get("kurallar", []):
		var w := 2.6 if bool(k.get("yeni", false)) else 1.0
		match str(k.get("tur", "")):
			"alan_esit":
				for alan: String in k.get("alanlar", []):
					adaylar.append([alan, w * (0.8 if alan == "ad" else 1.0)])
			"tarih_sure":
				if belgeler.has(str(k.get("belge", ""))):
					adaylar.append(["sure_" + str(k.belge), w])
			"muhur_zorunlu":
				if belgeler.has("ikametgah"):
					adaylar.append(["muhur", w])
					if bool(k.get("imza", false)):
						adaylar.append(["imza", w * 0.45])
			"harc_tutar":
				if belgeler.has("harc_makbuzu"):
					adaylar.append(["harc", w])
			"seri_aralik":
				adaylar.append(["seri", w])
			"foto_eslesme":
				adaylar.append(["foto", w])
			"mahalle_listesi":
				if belgeler.has("ikametgah"):
					adaylar.append(["mahalle", w])
			"sahtecilik":
				if belgeler.has("ikametgah"):
					adaylar.append(["muhur_sahte", w * 0.9])
					adaylar.append(["imza_sahte", w * 0.6])
				if belgeler.has("harc_makbuzu"):
					adaylar.append(["kase_sahte", w * 0.7])
			"vize":
				if belgeler.has("calisma_vizesi"):
					adaylar.append(["vize_no", w * 1.6])
					adaylar.append(["vize_kase", w * 1.6])
					adaylar.append(["vize_kimlik", w * 1.2])
					adaylar.append(["vize_imza", w * 0.9])
					adaylar.append(["vize_sure", w * 1.4])
			"belge_zorunlu":
				if (k.get("belgeler", []) as Array).size() > 1:
					adaylar.append(["belge_eksik", 0.55 * w])
	return adaylar


static func _kusur_ekle(v: Dictionary, gun: Dictionary, rng: RandomNumberGenerator, adet: int) -> void:
	var adaylar := kusur_adaylari(v, gun)
	var secilenler: Array[String] = []
	while secilenler.size() < adet and not adaylar.is_empty():
		var i := _agirlikli(adaylar, rng)
		var tur: String = adaylar[i][0]
		adaylar.remove_at(i)
		# Eksik belge tek başına bir kusurdur: başka kusurun hedefini ortadan kaldırabilir.
		if tur == "belge_eksik" and not secilenler.is_empty():
			continue
		# Olmayan mühür sahte olamaz: aynı öğeye iki ayrı kusur verilmez.
		var cakisan := false
		for cift: Array in [["muhur", "muhur_sahte"], ["imza", "imza_sahte"]]:
			if cift.has(tur):
				for s in secilenler:
					if cift.has(s):
						cakisan = true
		if cakisan:
			continue
		secilenler.append(tur)
		if tur == "belge_eksik":
			break
	for tur in secilenler:
		var gerekce := kusur_uygula(v, tur, gun, rng)
		if gerekce != "" and not (v.uretilen as Array).has(gerekce):
			(v.uretilen as Array).append(gerekce)


## Tek bir kusuru uygular; doğurduğu gerekçe kodunu döndürür (uygulanamadıysa "").
static func kusur_uygula(v: Dictionary, tur: String, gun: Dictionary, rng: RandomNumberGenerator) -> String:
	var belgeler := Dogrulayici.belge_sozlugu(v)
	var bugun := str(gun.get("tarih", ""))
	var zorluk := int(gun.get("zorluk", 1))
	var adlar := Veri.adlar()
	match tur:
		"ad", "soyad":
			var hedefler: Array = []
			for t: String in ["ikametgah", "harc_makbuzu", "calisma_vizesi"]:
				if belgeler.has(t):
					hedefler.append(belgeler[t])
			if hedefler.is_empty():
				return ""
			var b: Dictionary = _sec(hedefler, rng)
			b.alanlar[tur] = benzet(str(b.alanlar[tur]), rng, zorluk)
			return "ad_soyad"
		"baba_adi":
			if not belgeler.has("ikametgah"):
				return ""
			var al: Dictionary = belgeler["ikametgah"].alanlar
			al["baba_adi"] = benzet(str(al["baba_adi"]), rng, zorluk)
			return "baba_adi"
		"sure_ikametgah":
			var k := Veri.kural(gun, "tarih_sure", "ikametgah")
			if k.is_empty() or not belgeler.has("ikametgah"):
				return ""
			var sinir := Dogrulayici.en_eski_gecerli(bugun, k)
			var tarih := Tarih.gun_ekle(sinir, -rng.randi_range(4, 330))
			if zorluk >= 2 and rng.randf() < 0.3:
				tarih = Tarih.gun_ekle(sinir, -rng.randi_range(1, 9))      # sınırı birkaç günle kaçırmış
			elif rng.randf() < 0.08:
				tarih = Tarih.gun_ekle(bugun, rng.randi_range(1, 20))      # ileri tarih atılmış
			belgeler["ikametgah"].alanlar["tarih"] = tarih
			return "sure"
		"sure_harc_makbuzu":
			var k := Veri.kural(gun, "tarih_sure", "harc_makbuzu")
			if k.is_empty() or not belgeler.has("harc_makbuzu"):
				return ""
			belgeler["harc_makbuzu"].alanlar["tarih"] = Tarih.gun_ekle(bugun, -(int(k.get("gun", 3)) + rng.randi_range(1, 12)))
			return "sure"
		"muhur":
			if not belgeler.has("ikametgah"):
				return ""
			belgeler["ikametgah"].alanlar["muhtar_muhur"] = false
			return "muhur"
		"imza":
			if not belgeler.has("ikametgah"):
				return ""
			belgeler["ikametgah"].alanlar["muhtar_imza"] = false
			return "muhur"
		"harc":
			var k := Veri.kural(gun, "harc_tutar")
			if k.is_empty() or not belgeler.has("harc_makbuzu"):
				return ""
			var al: Dictionary = belgeler["harc_makbuzu"].alanlar
			al["tutar"] = _yanlis_harc(Dogrulayici.harc(k, str(al.islem)), str(al.islem), gun, rng)
			return "harc"
		"seri":
			var k := Veri.kural(gun, "seri_aralik")
			if k.is_empty() or not belgeler.has("nufus_cuzdani"):
				return ""
			belgeler["nufus_cuzdani"].alanlar["seri_no"] = _gecersiz_seri(k, rng)
			if belgeler.has("calisma_vizesi"):      # vize bu cüzdana göre düzenlenmiştir: numara aynı kalır
				belgeler["calisma_vizesi"].alanlar["seri_no"] = belgeler["nufus_cuzdani"].alanlar["seri_no"]
			return "seri"
		"foto":
			if not belgeler.has("nufus_cuzdani"):
				return ""
			var baska := _baska_portre(str(v.portre), rng, zorluk)
			if baska == "":
				return ""
			belgeler["nufus_cuzdani"]["foto"] = baska
			return "foto"
		"mahalle":
			var k := Veri.kural(gun, "mahalle_listesi")
			if k.is_empty() or not belgeler.has("ikametgah"):
				return ""
			var disarisi: Array = []
			for m: Dictionary in (adlar.get("mahalleler", []) as Array) + (adlar.get("dis_mahalleler", []) as Array):
				if not (k.mahalleler as Array).has(str(m.ad)):
					disarisi.append(m)
			if disarisi.is_empty():
				return ""
			var secilen: Dictionary = _sec(disarisi, rng)
			belgeler["ikametgah"].alanlar["mahalle"] = str(secilen.ad)
			belgeler["ikametgah"].alanlar["muhtar"] = str(secilen.muhtar)
			belgeler["ikametgah"].alanlar["imza_sahibi"] = str(secilen.muhtar)
			return "mahalle"
		"muhur_sahte":
			if not belgeler.has("ikametgah") or not bool(belgeler["ikametgah"].alanlar.get("muhtar_muhur", false)):
				return ""
			belgeler["ikametgah"].alanlar["muhur_turu"] = Damga.sahte_sec("muhtar", zorluk, rng)
			return "sahte"
		"imza_sahte":
			if not belgeler.has("ikametgah") or not bool(belgeler["ikametgah"].alanlar.get("muhtar_imza", false)):
				return ""
			var al: Dictionary = belgeler["ikametgah"].alanlar
			var baskasi := _baska_muhtar(str(al.get("muhtar", "")), adlar, rng)
			if baskasi == "":
				return ""
			al["imza_sahibi"] = baskasi
			return "sahte"
		"kase_sahte":
			if not belgeler.has("harc_makbuzu"):
				return ""
			belgeler["harc_makbuzu"].alanlar["kase_turu"] = Damga.sahte_sec("vezne", zorluk, rng)
			return "sahte"
		"vize_no", "vize_kase", "vize_kimlik", "vize_imza", "vize_sure":
			if not belgeler.has("calisma_vizesi"):
				return ""
			return _vize_boz(belgeler["calisma_vizesi"].alanlar, tur, gun, rng, zorluk)
		"belge_eksik":
			var liste: Array = v.belgeler
			var adaylar: Array = []
			for b: Dictionary in liste:
				if str(b.tur) != "nufus_cuzdani":
					adaylar.append(b)
			if adaylar.is_empty():
				return ""
			liste.erase(_sec(adaylar, rng))
			return "belge_eksik"
	return ""


## Çalışma vizesine tek bir kusur işler; doğurduğu gerekçeyi döndürür.
static func _vize_boz(al: Dictionary, tur: String, gun: Dictionary, rng: RandomNumberGenerator, zorluk: int) -> String:
	var bugun := str(gun.get("tarih", ""))
	var b: Dictionary = Veri.kural(gun, "vize").get("no", {})
	match tur:
		"vize_no":
			var onek := str(b.get("onek", "ÇV"))
			var yil := int(b.get("yil", 84))
			match rng.randi_range(0, 2 if zorluk >= 2 else 1):
				0:      # geçen yılın numarası
					al["vize_no"] = "%s-%02d-%05d" % [onek, yil - 1, rng.randi_range(int(b.get("min", 2000)), int(b.get("max", 6999)))]
				1:      # henüz verilmemiş bir numara
					al["vize_no"] = "%s-%02d-%05d" % [onek, yil, rng.randi_range(int(b.get("max", 6999)) + 1, mini(99999, int(b.get("max", 6999)) + 2500))]
				_:      # önek harfleri yanlış
					al["vize_no"] = "%s-%02d-%05d" % [["CV", "ÇY", "ÇW"][rng.randi_range(0, 2)], yil, rng.randi_range(int(b.get("min", 2000)), int(b.get("max", 6999)))]
			return "sahte"
		"vize_kase":
			al["kase_turu"] = Damga.sahte_sec("vize", zorluk, rng)
			return "sahte"
		"vize_kimlik":
			if rng.randf() < 0.5:
				al["seri_no"] = _rakam_degistir(str(al.get("seri_no", "")), rng)
			else:
				al["dogum_tarihi"] = _rakam_degistir(str(al.get("dogum_tarihi", "")), rng)
			return "sahte"
		"vize_imza":
			var baskasi := _baska_imza(str(al.get("imza", "")), rng)
			if baskasi == "":
				return ""
			al["imza"] = baskasi
			return "sahte"
		"vize_sure":
			var bitis := Tarih.gun_ekle(bugun, -rng.randi_range(1, 4 if zorluk >= 3 else 30))
			al["bitis"] = bitis
			al["verilis"] = Tarih.gun_ekle(bitis, -90)
			return "vize"
	return ""


## Metindeki rakamlardan birini başka bir rakamla değiştirir ("A-318722" → "A-318122").
static func _rakam_degistir(metin: String, rng: RandomNumberGenerator) -> String:
	var yerler: Array[int] = []
	for i in metin.length():
		if metin[i] >= "0" and metin[i] <= "9":
			yerler.append(i)
	if yerler.is_empty():
		return metin + "1"
	var i: int = yerler[rng.randi_range(maxi(0, yerler.size() - 4), yerler.size() - 1)]      # sondaki rakamlar: daha zor fark edilir
	var yeni := (int(metin[i]) + rng.randi_range(1, 9)) % 10
	return metin.substr(0, i) + str(yeni) + metin.substr(i + 1)


## Sahte ilmühabere imza atan: bu mahallenin muhtarı olmayan başka bir muhtar.
static func _baska_muhtar(muhtar: String, adlar: Dictionary, rng: RandomNumberGenerator) -> String:
	var digerleri: Array[String] = []
	for m: Dictionary in (adlar.get("mahalleler", []) as Array) + (adlar.get("dis_mahalleler", []) as Array):
		if str(m.muhtar) != muhtar and Imza.doku(str(m.muhtar)) != null:
			digerleri.append(str(m.muhtar))
	return digerleri[rng.randi_range(0, digerleri.size() - 1)] if not digerleri.is_empty() else ""


## Sahte vizedeki imza: kadrodan başka birinin imzası.
static func _baska_imza(sahibi: String, rng: RandomNumberGenerator) -> String:
	var havuz := Portreler.havuz()
	for deneme in 12:
		var k := Veri.vatandas(havuz[rng.randi_range(0, havuz.size() - 1)])
		var aday := "%s %s" % [str(k.get("ad", "")), str(k.get("soyad", ""))]
		if not k.is_empty() and Imza.kod(aday) != Imza.kod(sahibi) and Imza.doku(aday) != null:
			return aday
	return ""


## Bir adı/soyadı, gözden kaçabilecek kadar benzer başka bir yazıma çevirir.
## zorluk 1: bambaşka ama benzer bir ad; 2: tek harf; 3: tek nokta/çengel (I-İ, O-Ö, S-Ş...).
static func benzet(ad: String, rng: RandomNumberGenerator, zorluk: int = 1) -> String:
	var tablo: Dictionary = Veri.adlar().get("benzer", {})
	var seviye := zorluk
	if seviye > 1 and rng.randf() < 0.35:
		seviye -= 1
	if seviye >= 3:
		var s := _harf_degistir(ad, NOKTA_CIFTLERI, rng)
		if s != ad:
			return s
	if seviye >= 2 or not tablo.has(ad):
		var s := _harf_degistir(ad, HARF_CIFTLERI, rng)
		if s != ad:
			return s
	if tablo.has(ad):
		return str(_sec(tablo[ad], rng))
	# Son çare: sondaki harfi değiştir.
	var son := ad.substr(ad.length() - 1)
	return ad.substr(0, ad.length() - 1) + ("N" if son != "N" else "M")


static func _harf_degistir(ad: String, ciftler: Dictionary, rng: RandomNumberGenerator) -> String:
	var yerler: Array[int] = []
	for i in range(1, ad.length()):      # baş harfe dokunma: fazla göze batar
		if ciftler.has(ad[i]):
			yerler.append(i)
	if yerler.is_empty():
		return ad
	var i: int = yerler[rng.randi_range(0, yerler.size() - 1)]
	return ad.substr(0, i) + str(ciftler[ad[i]]) + ad.substr(i + 1)


static func _yanlis_harc(dogru: int, islem: String, gun: Dictionary, rng: RandomNumberGenerator) -> int:
	var secenekler: Array[int] = []
	var eski: Dictionary = gun.get("eski_tarife", {})
	if eski.has(islem) and int(eski[islem]) != dogru:
		# Zamdan haberi olmayan vatandaş eski tarifeden yatırmıştır.
		for i in 3:
			secenekler.append(int(eski[islem]))
	for fark: int in [-100, -50, 50, 100]:
		secenekler.append(dogru + fark)
	@warning_ignore("integer_division")
	secenekler.append(dogru / 10)                      # bir sıfırı eksik
	var basamak := str(dogru)
	if basamak.length() >= 3 and basamak[0] != basamak[1]:
		secenekler.append(int(basamak[1] + basamak[0] + basamak.substr(2)))   # ilk iki rakam yer değiştirmiş
	var gecerli: Array[int] = []
	for s in secenekler:
		if s > 0 and s != dogru:
			gecerli.append(s)
	return gecerli[rng.randi_range(0, gecerli.size() - 1)] if not gecerli.is_empty() else dogru + 50


static func _gecersiz_seri(kural: Dictionary, rng: RandomNumberGenerator) -> String:
	var araliklar: Array = kural.get("araliklar", VARSAYILAN_SERI)
	var a: Dictionary = araliklar[rng.randi_range(0, araliklar.size() - 1)]
	var aday := ""
	for deneme in 12:
		match rng.randi_range(0, 3):
			0:
				aday = "%s-%06d" % [str(a.onek), rng.randi_range(maxi(1000, int(a.min) - 90000), int(a.min) - 1)]
			1:
				aday = "%s-%06d" % [str(a.onek), rng.randi_range(int(a.max) + 1, mini(999999, int(a.max) + 90000))]
			2:
				aday = "%s-%06d" % [["C", "D", "E", "K"][rng.randi_range(0, 3)], rng.randi_range(int(a.min), int(a.max))]
			_:
				aday = "%s-%06d" % [str(a.onek), rng.randi_range(600000, 989999)]
		if not Dogrulayici.seri_gecerli(aday, kural):
			return aday
	return "X-000000"


## Sahte cüzdandaki fotoğrafın sahibi: başvurana benzeyen başka biri. Zorluk arttıkça daha çok benzeyeni
## seçilir (zorluk 1: aynı cinsiyetten, yaşça yakın herhangi biri; 2: en benzer altı kişiden biri;
## 3: en benzer üç kişiden biri). Benzerlik listesi yoksa yaşça yakın biri alınır.
static func _baska_portre(portre: String, rng: RandomNumberGenerator, zorluk: int = 1) -> String:
	var benzerler := Portreler.benzerler(portre)
	if zorluk >= 2 and not benzerler.is_empty():
		var adet := mini(benzerler.size(), 3 if zorluk >= 3 else 6)
		return benzerler[rng.randi_range(0, adet - 1)]
	var bilgi := Portreler.bilgi(portre)
	var yas := int(bilgi.get("yas", 40))
	var yakinlar: Array[String] = []
	var digerleri: Array[String] = []
	for p in Portreler.havuz(str(bilgi.get("cinsiyet", ""))):
		if p == portre:
			continue
		digerleri.append(p)
		if absi(int(Portreler.bilgi(p).get("yas", 40)) - yas) <= 14:
			yakinlar.append(p)
	var liste := yakinlar if not yakinlar.is_empty() else digerleri
	return liste[rng.randi_range(0, liste.size() - 1)] if not liste.is_empty() else ""


# --- Konuşma ---

static func _konusma(v: Dictionary, adlar: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var yasli := int(v.get("yas", 40)) >= 62
	var selam := str(_sec(adlar.get("selam_yasli" if yasli else "selam", ["İyi günler."]), rng))
	var giris := selam + " " + str(_sec(Islemler.talepler(str(v.islem)), rng))
	if rng.randf() < 0.32:
		giris += " " + str(_sec(adlar.get("laf", [""]), rng))
	return {
		"giris": giris.strip_edges(),
		"onay": str(_sec(adlar.get("onay_yasli" if yasli and rng.randf() < 0.6 else "onay", ["Sağ olun."]), rng)),
		"eksik": str(_sec(adlar.get("eksik_yasli" if yasli and rng.randf() < 0.5 else "eksik", ["Peki."]), rng)),
		"havale": str(_sec(adlar.get("havale", ["Peki efendim."]), rng)),
		"alarm": str(_sec(adlar.get("alarm", ["O çanta benim değil!"]), rng)),
		"alarm_bos": str(_sec(adlar.get("alarm_bos", ["Çantamı didik didik ettiniz; bulduğunuz bu mu?"]), rng)),
	}


# --- Yardımcılar ---

static func _sec(dizi: Array, rng: RandomNumberGenerator) -> Variant:
	return dizi[rng.randi_range(0, dizi.size() - 1)]


static func _agirlikli(adaylar: Array, rng: RandomNumberGenerator) -> int:
	var toplam := 0.0
	for a: Array in adaylar:
		toplam += float(a[1])
	var zar := rng.randf() * toplam
	for i in adaylar.size():
		zar -= float(adaylar[i][1])
		if zar <= 0.0:
			return i
	return adaylar.size() - 1
