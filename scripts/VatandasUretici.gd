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

	var portre := _portre_sec(rng, kullanilan)
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
	var islemler: Array = gun.get("islemler", ["kayit_ornegi"])
	var islem := str(_sec(islemler, rng))

	var v := {
		"tur": "rastgele",
		"portre": portre,
		"kimlik": kimlik,
		"islem": islem,
		"yas": yas,
		"belgeler": _belgeleri_kur(kimlik, portre, islem, gun, rng),
		"uretilen": [],
	}

	if hata_adedi < 0:
		hata_adedi = 0
		if rng.randf() < float(gun.get("hata_orani", 0.4)):
			hata_adedi = 2 if rng.randf() < 0.22 else 1
	if hata_adedi > 0:
		_kusur_ekle(v, gun, rng, hata_adedi)

	v["konusma"] = _konusma(v, adlar, rng)
	return v


# --- Kimlik ve belgeler ---

static func _portre_sec(rng: RandomNumberGenerator, kullanilan: Array) -> String:
	var havuz := Portreler.havuz()
	if havuz.is_empty():
		return ""
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


static func _belgeleri_kur(kimlik: Dictionary, portre: String, islem: String, gun: Dictionary,
		rng: RandomNumberGenerator) -> Array:
	var adlar := Veri.adlar()
	var bugun := str(gun.get("tarih", "09.01.1984"))
	var belgeler: Array = []
	for tur: String in gun.get("belgeler", ["nufus_cuzdani", "ikametgah"]):
		match tur:
			"nufus_cuzdani":
				belgeler.append({"tur": tur, "foto": portre, "alanlar": kimlik.duplicate()})
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
				}})
	return belgeler


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
			for t: String in ["ikametgah", "harc_makbuzu"]:
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
			return "seri"
		"foto":
			if not belgeler.has("nufus_cuzdani"):
				return ""
			var baska := _baska_portre(str(v.portre), rng)
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
			return "mahalle"
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


## Aynı cinsiyetten, yaşça yakın başka birinin portresi (sahte cüzdandaki fotoğraf için).
static func _baska_portre(portre: String, rng: RandomNumberGenerator) -> String:
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
