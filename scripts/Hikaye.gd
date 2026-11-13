class_name Hikaye
extends RefCounted
## Hikâye: özel karakterlerin gişe ziyaretleri, her sabahın gazetesi, akşam ev sahneleri,
## gece olayları ve sonlar. Metinlerin tamamı veri dosyalarındadır (karakterler ve diyaloglar
## data/karakterler.json, gerisi data/hikaye.json); burada yalnızca koşullar (Oyun.bayraklar)
## değerlendirilir ve kararların etkileri uygulanır.

const YOL := "res://data/hikaye.json"
const KARAKTER_YOLU := "res://data/karakterler.json"
const GAZETE_ADI := "ARDIÇLI POSTASI"


## Gazete, akşam, gece ve sonlar.
static func veri() -> Dictionary:
	var v: Variant = Veri.oku(YOL)
	return v if typeof(v) == TYPE_DICTIONARY else {}


## Karakterler ve gişe ziyaretleri.
static func karakterler() -> Dictionary:
	var v: Variant = Veri.oku(KARAKTER_YOLU)
	return v if typeof(v) == TYPE_DICTIONARY else {}


# --- Koşullar ---

## Koşul sözlüğündeki her bayrak tutuyor mu? Değer liste ise içindekilerden biri yeter.
## Hiç yazılmamış bayrak; sayı beklenen yerde 0, metin beklenen yerde "", mantıksal yerde false sayılır.
static func kosul_tutar(kosul: Variant, bayraklar: Dictionary) -> bool:
	if typeof(kosul) != TYPE_DICTIONARY:
		return true
	for ad: String in kosul:
		var beklenen: Variant = kosul[ad]
		var secenekler: Array = beklenen if typeof(beklenen) == TYPE_ARRAY else [beklenen]
		var tuttu := false
		for s: Variant in secenekler:
			if _esit(bayraklar.get(ad, _bos(s)), s):
				tuttu = true
				break
		if not tuttu:
			return false
	return true


static func _bos(ornek: Variant) -> Variant:
	match typeof(ornek):
		TYPE_INT, TYPE_FLOAT:
			return 0
		TYPE_BOOL:
			return false
	return ""


static func _esit(a: Variant, b: Variant) -> bool:
	var a_sayi := typeof(a) == TYPE_INT or typeof(a) == TYPE_FLOAT
	var b_sayi := typeof(b) == TYPE_INT or typeof(b) == TYPE_FLOAT
	if a_sayi and b_sayi:
		return is_equal_approx(float(a), float(b))
	return typeof(a) == typeof(b) and a == b


static func _ilk_uyan(liste: Array, gun_no: int, bayraklar: Dictionary) -> Dictionary:
	for g: Dictionary in liste:
		if int(g.get("gun", 0)) == gun_no and kosul_tutar(g.get("kosul", null), bayraklar):
			return g
	return {}


# --- Günlük metinler ---

## O sabahın gazetesi: {manset, metin} (yoksa boş).
static func gazete(gun_no: int, bayraklar: Dictionary) -> Dictionary:
	var uyan := _ilk_uyan(veri().get("gazete", []), gun_no, bayraklar)
	if not uyan.is_empty():
		return uyan
	# Hiçbir koşul tutmadıysa (beklenmedik bir bayrak değeri) o günün son kaydı basılır: sabah gazetesiz kalmaz.
	var yedek := {}
	for g: Dictionary in veri().get("gazete", []):
		if int(g.get("gun", 0)) == gun_no:
			yedek = g
	return yedek


## Akşam evde geçen kısa sahne.
static func aksam(gun_no: int, bayraklar: Dictionary) -> String:
	return str(_ilk_uyan(veri().get("aksam", []), gun_no, bayraklar).get("metin", ""))


## Gece olan olay (patlama, saldırı) varsa metni.
static func gece(gun_no: int, bayraklar: Dictionary) -> String:
	return str(_ilk_uyan(veri().get("gece", []), gun_no, bayraklar).get("metin", ""))


## Savcının akıbeti, arananlardan kaçının gişede yakalandığına bağlıdır.
static func savci_akibeti(bayraklar: Dictionary) -> String:
	var yakalanan := 0
	for ad: String in ["kasap", "naciye"]:
		if str(bayraklar.get(ad, "")) == "yakalandi":
			yakalanan += 1
	return ["oldu", "yarali", "sag"][yakalanan]


# --- Gişeye gelen özel karakterler ---

## O gün gelecek özel karakterler: [{sira, vatandas}] (sıraya göre dizili).
static func ozel_vatandaslar(gun_no: int, gun: Dictionary, bayraklar: Dictionary, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var sonuc: Array[Dictionary] = []
	for z: Dictionary in karakterler().get("ziyaretler", []):
		if int(z.get("gun", 0)) != gun_no or not kosul_tutar(z.get("kosul", null), bayraklar):
			continue
		sonuc.append({"sira": int(z.get("sira", 1)), "vatandas": vatandas_kur(z, gun, rng)})
	sonuc.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.sira) < int(b.sira))
	return sonuc


## Ziyaret kaydından vatandaş sözlüğünü kurar (rastgele vatandaşlarla aynı biçimde).
static func vatandas_kur(z: Dictionary, gun: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var v := {
		"tur": "hikaye",
		"kod": str(z.get("kod", "")),
		"etki": z.get("etki", {}),
		"zarf": int(z.get("zarf", 0)),
		"belgeler": [],
		"uretilen": [],
	}
	if bool(z.get("belgesiz", false)):
		var satirlar: Array = z.get("satirlar", [""])
		v["portre"] = str(z.get("portre", ""))
		v["belgesiz"] = true
		v["satirlar"] = satirlar
		v["mektup"] = bool(z.get("mektup", false))
		v["konusma"] = {"giris": str(satirlar[0])}
		return v

	var kisi: Dictionary = (karakterler().get("kisiler", {}) as Dictionary).get(str(z.get("kisi", "")), {})
	var kimlik := {}
	for alan: String in ["ad", "soyad", "baba_adi", "ana_adi", "dogum_yeri", "dogum_tarihi", "seri_no", "cinsiyet"]:
		kimlik[alan] = str(kisi.get(alan, ""))
	kimlik["imza"] = str(kisi.get("imza", "%s %s" % [kimlik.ad, kimlik.soyad]))
	v["portre"] = str(kisi.get("portre", ""))
	v["kimlik"] = kimlik
	v["islem"] = str(z.get("islem", "kayit_ornegi"))
	v["yas"] = int(kisi.get("yas", 40))
	v["konusma"] = z.get("konusma", {})
	var belgeler: Array = VatandasUretici.belgeleri_kur(kimlik, str(v.portre), str(v.islem), gun, rng)
	for b: Dictionary in belgeler:
		if str(b.tur) == "ikametgah":
			for alan: String in ["mahalle", "muhtar", "adres"]:
				if kisi.has(alan):
					b.alanlar[alan] = str(kisi[alan])
		elif str(b.tur) == "nufus_cuzdani" and z.has("foto"):
			b["foto"] = str(z.foto)
	# "ikametgah.tarih": "14.02.1982" gibi alan düzeltmeleri
	var duzeltme: Dictionary = z.get("alan", {})
	for yol: String in duzeltme:
		var p := yol.split(".")
		for b: Dictionary in belgeler:
			if str(b.tur) == p[0]:
				var deger: Variant = duzeltme[yol]
				if typeof(deger) == TYPE_FLOAT and is_equal_approx(deger, roundf(deger)):
					deger = int(deger)
				b.alanlar[p[1]] = deger
	# imzayı, belgede adı yazan muhtar atar (veride açıkça başkası gösterilmediyse)
	if not duzeltme.has("ikametgah.imza_sahibi"):
		for b: Dictionary in belgeler:
			if str(b.tur) == "ikametgah":
				b.alanlar["imza_sahibi"] = str(b.alanlar.get("muhtar", ""))
	for tur: String in z.get("sil", []):
		for i in range(belgeler.size() - 1, -1, -1):
			if str(belgeler[i].tur) == tur:
				belgeler.remove_at(i)
	v["belgeler"] = belgeler
	# röntgenden geçecek çanta: içindekiler veride yazılıdır, yerleşimi günün tohumuna göre kurulur
	var canta: Dictionary = z.get("canta", {})
	if not canta.is_empty():
		v["canta"] = Canta.yerlestir(str(canta.get("tur", "bavul")), canta.get("esyalar", []), rng)
	return v


# --- Kararların etkileri ---

## Bir etkiyi oyun durumuna işler: bayrak, şüphe, para, komşu ikramı, kira affı.
static func etki_uygula(e: Variant) -> void:
	if typeof(e) != TYPE_DICTIONARY:
		return
	var b: Dictionary = e.get("bayrak", {})
	for ad: String in b:
		var deger: Variant = b[ad]
		if typeof(deger) == TYPE_FLOAT and is_equal_approx(deger, roundf(deger)):
			deger = int(deger)
		Oyun.bayraklar[ad] = deger
	Oyun.suphe = maxi(0, Oyun.suphe + int(e.get("suphe", 0)))
	Oyun.para += int(e.get("para", 0))
	if bool(e.get("ikram", false)):
		Oyun.aile["ikram"] = true
	if bool(e.get("kira_affi", false)):
		Oyun.aile["kira_affi"] = true


# --- Son ---

## Oyun sonu gazetesi: {tarih, manset, metin, foto, foto_alt, damga, yan: [{baslik, metin}], mektup}
static func son(sonuc: Dictionary, bayraklar: Dictionary) -> Dictionary:
	var s: Dictionary = veri().get("son", {})
	var ana: Dictionary = s.get("ana", {})
	var anahtar := str(sonuc.get("tur", "olagan"))
	match anahtar:
		"surgun":
			anahtar = "surgun_suphe" if str(sonuc.get("neden", "")) == "suphe" else "surgun_ihtar"
		"kotu":
			anahtar = str(sonuc.get("neden", "iflas"))
	var bas: Dictionary = ana.get(anahtar, ana.get("olagan", {}))
	var yan: Array[Dictionary] = []
	for y: Dictionary in s.get("yan", []):
		if kosul_tutar(y.get("kosul", null), bayraklar):
			yan.append(y)
	return {
		"tarih": Dil.c(str(s.get("gazete_tarihi", ""))),
		"manset": str(bas.get("manset", "")),
		"metin": str(bas.get("metin", "")),
		"foto": str(bas.get("foto", "")),
		"foto_alt": str(bas.get("foto_alt", "")),
		"damga": str(bas.get("damga", "")),
		"yan": yan,
		"ilanlar": s.get("ilanlar", []),
		"mektup": mektup() if _isaretli(bayraklar.get("mektup")) else "",
	}


## Mantıksal bir bayrak işaretli mi? Kayıttan başka türde bir değer gelirse (metin, sayı) hata vermez.
static func _isaretli(v: Variant) -> bool:
	match typeof(v):
		TYPE_BOOL:
			return v
		TYPE_INT, TYPE_FLOAT:
			return v != 0
	return false


## Hüsnü Amca'nın mektubu.
static func mektup() -> String:
	return str((veri().get("son", {}) as Dictionary).get("mektup", ""))
