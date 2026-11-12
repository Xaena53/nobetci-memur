class_name Canta
extends RefCounted
## Vatandaşın gişeye getirdiği çanta: türü ve içindeki eşyalar. Röntgen cihazı bunu gösterir.
##
## Çanta: {tur, esyalar: [{ad, x, y, aci, ayna}]}   (x, y: çantanın iç alanına oranlı 0..1; aci derece)
## Katalog data/esyalar.json içindedir. Hangi eşyanın yasak olduğunu günün genelgesi belirler
## (kural türü "canta_kontrol", "yasak": ["silah", "patlayici", ...]).

const YOL := "res://data/esyalar.json"
const ESYA_KLASORU := "res://assets/img/rontgen/esya/"
const KABUK_KLASORU := "res://assets/img/rontgen/kabuk/"
const DIS_GORUNUS := "res://assets/img/nesne/canta_%s.webp"
const CM := 4.7                  ## röntgen ekranında bir santimin pikseli (çanta ölçeği 1 iken)
const YASAK_ORANI := 0.3         ## çantaların ne kadarında yasak eşya çıkar (gün "yasak_orani" ile ezebilir)
const YANILTMACA_ORANI := 0.6    ## çantaların ne kadarında yasak eşyayı andıran zararsız bir şey bulunur

static var _dokular: Dictionary = {}


static func katalog() -> Dictionary:
	var v: Variant = Veri.oku(YOL)
	return v if typeof(v) == TYPE_DICTIONARY else {}


static func esya(ad: String) -> Dictionary:
	return (katalog().get("esyalar", {}) as Dictionary).get(ad, {})


static func tur_bilgisi(tur: String) -> Dictionary:
	return (katalog().get("cantalar", {}) as Dictionary).get(tur, {})


static func kategori_bilgisi(kategori: String) -> Dictionary:
	return (katalog().get("kategoriler", {}) as Dictionary).get(kategori, {})


static func esya_dokusu(ad: String) -> Texture2D:
	return _doku(ESYA_KLASORU + ad + ".webp")


static func kabuk_dokusu(tur: String) -> Texture2D:
	return _doku(KABUK_KLASORU + tur + ".webp")


## Çantanın dıştan görünüşü (gişenin eşiğinde durur).
static func dis_doku(tur: String) -> Texture2D:
	return _doku(DIS_GORUNUS % tur)


static func _doku(yol: String) -> Texture2D:
	if not _dokular.has(yol):
		_dokular[yol] = load(yol) if ResourceLoader.exists(yol) else null
	return _dokular[yol]


# --- Kurallar ---

## O gün çanta denetimi var mı?
static func denetim_var(gun: Dictionary) -> bool:
	return not Veri.kural(gun, "canta_kontrol").is_empty()


## Çantadaki, o günün genelgesine göre yasak olan eşyaların adları (katalog anahtarları).
static func yasaklar(canta: Dictionary, gun: Dictionary) -> Array[String]:
	var yasak: Array = Veri.kural(gun, "canta_kontrol").get("yasak", [])
	var sonuc: Array[String] = []
	for e: Dictionary in canta.get("esyalar", []):
		var ad := str(e.get("ad", ""))
		if yasak.has(str(esya(ad).get("kategori", ""))) and not sonuc.has(ad):
			sonuc.append(ad)
	return sonuc


## Eşya adlarını cümleye girecek biçimde sıralar: "tabanca ile şarjör ve mermi".
static func adlari_yaz(adlar: Array) -> String:
	var parcalar := PackedStringArray()
	for ad: String in adlar:
		parcalar.append(str(esya(ad).get("ad", ad)))
	return " ile ".join(parcalar)


## Boş yere alarm verilen çantada, memuru yanıltmış olabilecek eşya (yoksa ilk eşya).
static func yaniltan(canta: Dictionary, gun: Dictionary) -> String:
	var yasak: Array = Veri.kural(gun, "canta_kontrol").get("yasak", [])
	var ilk := ""
	var aday := ""
	for e: Dictionary in canta.get("esyalar", []):
		var ad := str(e.get("ad", ""))
		var b := esya(ad)
		if ilk == "":
			ilk = ad
		# o gün serbest olan kesici alet ya da yasak bir şeyi andıran eşya
		if str(b.get("kategori", "")) != "" and not yasak.has(str(b.kategori)):
			return str(b.get("ad", ad))
		if aday == "" and str(b.get("benzer", "")) != "":
			aday = ad
	var secilen := aday if aday != "" else ilk
	return str(esya(secilen).get("ad", secilen))


# --- Üretim ---

## Rastgele bir çanta doldurur. Bir bölümünde günün yasaklarından biri, çoğunda yanıltıcı bir eşya olur.
static func uret(gun: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var yasak: Array = Veri.kural(gun, "canta_kontrol").get("yasak", [])
	var turler: Dictionary = katalog().get("cantalar", {})
	var tur := _agirlikli_tur(turler, rng)
	var bilgi: Dictionary = turler.get(tur, {})
	var kucuk := bool(bilgi.get("kucuk", false))
	var adet_araligi: Array = bilgi.get("adet", [4, 6])
	var adet := rng.randi_range(int(adet_araligi[0]), int(adet_araligi[1]))

	var yasaklilar: Array[String] = []
	var yanilticilar: Array[String] = []
	var siradan: Array[String] = []
	var esyalar: Dictionary = katalog().get("esyalar", {})
	for ad: String in esyalar:
		var b: Dictionary = esyalar[ad]
		if bool(b.get("ozel", false)) or (kucuk and not bool(b.get("kucuk", false))):
			continue
		var kategori := str(b.get("kategori", ""))
		if kategori != "" and yasak.has(kategori):
			yasaklilar.append(ad)
		elif kategori != "" or str(b.get("benzer", "")) != "":
			yanilticilar.append(ad)      # o gün serbest olan kesici alet de yanıltıcıdır
		else:
			siradan.append(ad)

	var secilen: Array[String] = []
	if not yasaklilar.is_empty() and rng.randf() < float(gun.get("yasak_orani", YASAK_ORANI)):
		var y: String = yasaklilar[rng.randi_range(0, yasaklilar.size() - 1)]
		secilen.append(y)
		if (y == "tabanca" or y == "toplu") and rng.randf() < 0.35:
			secilen.append("mermi")
	if not yanilticilar.is_empty() and rng.randf() < YANILTMACA_ORANI:
		secilen.append(yanilticilar[rng.randi_range(0, yanilticilar.size() - 1)])
	var deneme := 0
	while secilen.size() < adet and deneme < 40 and not siradan.is_empty():
		deneme += 1
		var s: String = siradan[rng.randi_range(0, siradan.size() - 1)]
		if not secilen.has(s):
			secilen.append(s)
	return yerlestir(tur, secilen, rng)


## Verilen eşyaları çantanın içine dağıtır. Yoğun eşyalar birbirinin tam üstüne gelmesin diye her
## eşya için birkaç yer denenir ve öncekilere en uzak olanı seçilir.
static func yerlestir(tur: String, adlar: Array, rng: RandomNumberGenerator) -> Dictionary:
	var bilgi := tur_bilgisi(tur)
	var ic: Array = bilgi.get("ic", [0.1, 0.2, 0.9, 0.9])
	var kabuk := kabuk_dokusu(tur)
	var kabuk_boyutu := kabuk.get_size() if kabuk != null else Vector2(800, 620)
	# iç alanın ekrandaki pikseli: çanta, ekrana sığacak biçimde gösterilir (bkz. Rontgen)
	var gosterim := gosterim_boyutu(kabuk_boyutu)
	var ic_boyut := Vector2((float(ic[2]) - float(ic[0])) * gosterim.x, (float(ic[3]) - float(ic[1])) * gosterim.y)
	var olcek := float(bilgi.get("olcek", 1.0))

	var esyalar: Array = []
	var merkezler: Array[Vector2] = []
	# büyükten küçüğe yerleştir: büyükler köşeleri kapsın, küçükler aralara girsin
	var sirali: Array = adlar.duplicate()
	sirali.sort_custom(func(a: String, b: String) -> bool:
		return float(esya(a).get("boy", 20)) > float(esya(b).get("boy", 20)))
	for ad: String in sirali:
		var boy := float(esya(ad).get("boy", 20)) * CM * olcek
		var pay := Vector2(minf(0.42, boy * 0.30 / ic_boyut.x), minf(0.42, boy * 0.30 / ic_boyut.y))
		var en_iyi := Vector2(0.5, 0.5)
		var en_uzak := -1.0
		for i in 9:
			var aday := Vector2(rng.randf_range(pay.x, 1.0 - pay.x), rng.randf_range(pay.y, 1.0 - pay.y))
			var yakin := 9.0
			for m in merkezler:
				yakin = minf(yakin, ((aday - m) * ic_boyut).length())
			if yakin > en_uzak:
				en_uzak = yakin
				en_iyi = aday
		merkezler.append(en_iyi)
		esyalar.append({
			"ad": ad,
			"x": snappedf(en_iyi.x, 0.001),
			"y": snappedf(en_iyi.y, 0.001),
			"aci": float(rng.randi_range(0, 3) * 90) + snappedf(rng.randf_range(-24.0, 24.0), 0.1),
			"ayna": rng.randf() < 0.5,
		})
	return {"tur": tur, "esyalar": esyalar}


## Çanta kabuğunun röntgen ekranındaki boyutu (ekranın tasarım ölçüsüne sığdırılmış).
static func gosterim_boyutu(kabuk_boyutu: Vector2) -> Vector2:
	var k := minf(Rontgen.TUVAL.x * 0.90 / kabuk_boyutu.x, Rontgen.TUVAL.y * 0.92 / kabuk_boyutu.y)
	return kabuk_boyutu * k


static func _agirlikli_tur(turler: Dictionary, rng: RandomNumberGenerator) -> String:
	var toplam := 0.0
	for t: String in turler:
		toplam += float((turler[t] as Dictionary).get("agirlik", 1))
	var zar := rng.randf() * toplam
	for t: String in turler:
		zar -= float((turler[t] as Dictionary).get("agirlik", 1))
		if zar <= 0.0:
			return t
	return "bavul"
