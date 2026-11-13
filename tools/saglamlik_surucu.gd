extends "res://tools/test_surucu.gd"
## Sağlamlık testi: oyunu bozmaya çalışır.
##
##   veri     veri dosyalarının ve varlıkların çapraz denetimi (eksik görsel, yanlış eşleme, tanımsız bayrak)
##   kayit    kayıt ve ayar dosyalarını bozar, elle değiştirir, düşmanca değerlerle doldurur
##   uretici  üç görev şekli × beş tohum × yedi gün: üretici ile doğrulayıcı her vatandaşta aynı fikirde mi
##   ipucu    inceleme modunun her karşılaştırması kural motoruyla tutarlı mı (yanlış alarm yok, her kusur bulunur)
##   akis     zamanlama yarışları: mesai tam karar anında biterse, pencere açıkken kapanırsa, çift karar...
##   maymun   rastgele tıklama, sürükleme ve tuşlarla günler boyu oynar; kilitlenme ve tutarsızlık arar
##
## Çalıştırma:  bash tools/saglamlik.sh [bölüm ...]      (bölüm verilmezse hepsi)
## Betik hatası (SCRIPT ERROR) konsola düşerse kabuk betiği onu da başarısızlık sayar.

const BOLUMLER := ["veri", "kayit", "ayarlar", "uretici", "ipucu", "yerlesim", "akis", "maymun"]
const BELGE_TURLERI := ["nufus_cuzdani", "ikametgah", "harc_makbuzu", "calisma_vizesi"]
const KURAL_TURLERI := ["belge_zorunlu", "alan_esit", "tarih_sure", "muhur_zorunlu", "harc_tutar", "seri_aralik",
	"foto_eslesme", "mahalle_listesi", "arananlar", "sahtecilik", "vize", "canta_kontrol"]
const ETKI_ANLARI := ["onay", "eksik", "havale", "alarm", "gecir", "zarf", "ziyaret"]
const ETKI_ALANLARI := ["bayrak", "suphe", "para", "ikram", "kira_affi", "sonuc", "not"]

var _sessiz_hata := 0
var _hedef_onbellegi: Dictionary = {}     ## gün özeti -> arayüzdeki hedeflerin özetleri
var _hedef_sayisi := 0
var _en_dolu := 0.0          ## yerleşim denetimi: alanını en çok dolduran yazının doluluk oranı


func _ready() -> void:
	Oyun.kayit_yolu = "user://saglamlik_kayit.json"
	Oyun.ayar_yolu = "user://saglamlik_ayarlar.json"
	Oyun.ayarlari_yukle()
	_calistir.call_deferred()


func _calistir() -> void:
	var arg := OS.get_cmdline_user_args()
	var istenen: Array = []
	for a in arg:
		if BOLUMLER.has(a):
			istenen.append(a)
	if istenen.is_empty():
		istenen = BOLUMLER.duplicate()
	var once := _veri_ozeti()
	for b: String in istenen:
		await call("_bolum_" + b)
	esit(_veri_ozeti(), once, "veri dosyalarının bellekteki kopyası testler boyunca değişmedi")
	print("")
	if _hata == 0:
		print("SAĞLAMLIK TESTİ: BAŞARILI (%d denetim)" % _adim)
	else:
		print("SAĞLAMLIK TESTİ: %d HATA (%d denetim)" % [_hata, _adim])
	Engine.time_scale = 1.0
	Oyun.kaydi_sil()
	if FileAccess.file_exists(Oyun.ayar_yolu):
		DirAccess.remove_absolute(Oyun.ayar_yolu)
	Oyun.cik(1 if _hata > 0 else 0)


## Yalnızca tutmayan denetimi yazar (binlerce satır ✓ basmamak için).
func _v(kosul: bool, aciklama: String) -> void:
	_adim += 1
	if not kosul:
		_hata += 1
		_sessiz_hata += 1
		if _sessiz_hata <= 60:
			print("  ✗ HATA: ", aciklama)


## Bellekteki bütün veri dosyalarının özeti: kod veriyi yerinde değiştirirse özet değişir.
func _veri_ozeti() -> int:
	var parcalar: Array = [Veri.adlar(), Veri.oku(Veri.VATANDAS_YOLU), Hikaye.veri(), Hikaye.karakterler(),
		Canta.katalog(), Portreler.kunye()]
	var n := 1
	while Veri.gun_var_mi(n):
		parcalar.append(Veri.gun(n))
		n += 1
	return JSON.stringify(parcalar).hash()


# =====================================================================================================
# 1. Veri denetimi
# =====================================================================================================

func _bolum_veri() -> void:
	print("== Veri denetimi ==")
	var once := _hata
	var kunye := Portreler.kunye()
	var adlar := Veri.adlar()
	var katalog := Canta.katalog()
	var karakterler := Hikaye.karakterler()
	var kisiler: Dictionary = karakterler.get("kisiler", {})
	var havuz := Portreler.havuz()

	# --- mahalleler ve muhtarlar ---
	var muhtari := {}
	for liste_adi: String in ["mahalleler", "dis_mahalleler"]:
		_v(not (adlar.get(liste_adi, []) as Array).is_empty(), "adlar.%s boş değil" % liste_adi)
		for m: Dictionary in adlar.get(liste_adi, []):
			var ad := str(m.get("ad", ""))
			_v(ad != "" and not muhtari.has(ad), "mahalle adı dolu ve tek: '%s'" % ad)
			muhtari[ad] = str(m.get("muhtar", ""))
			_v(Imza.doku(str(m.get("muhtar", ""))) != null, "muhtarın imza görseli var: %s (%s)" % [str(m.get("muhtar", "")), ad])
	for liste_adi: String in ["erkek", "kadin", "soyad", "il", "sokak", "selam", "laf", "onay", "eksik", "havale",
			"alarm", "alarm_bos", "ulkeler", "meslekler"]:
		_v(not (adlar.get(liste_adi, []) as Array).is_empty(), "adlar.%s boş değil" % liste_adi)
	for kisi: String in ["mudur", "veznedar"]:
		_v(Imza.doku(kisi) != null, "imza görseli var: " + kisi)

	# --- portreler ---
	_v(havuz.size() >= 80, "havuzda en az 80 yüz var (%d)" % havuz.size())
	for kimlik: String in kunye:
		var b: Dictionary = kunye[kimlik]
		_v(ResourceLoader.exists(Portreler.KLASOR + kimlik + ".webp"), "portre görseli var: " + kimlik)
		for alan: String in ["benzer", "aranan_benzer"]:
			for diger: Variant in b.get(alan, []):
				_v(kunye.has(str(diger)) and str(diger) != kimlik, "%s.%s geçerli bir başka yüz: %s" % [kimlik, alan, str(diger)])
	for kimlik: String in havuz:
		var b: Dictionary = kunye[kimlik]
		_v(["E", "K"].has(str(b.get("cinsiyet", ""))), "cinsiyet E/K: " + kimlik)
		_v(str(b.get("yas", "")).is_valid_int() and int(b.get("yas", 0)) >= 4 and int(b.get("yas", 0)) <= 95, "yaş makul: " + kimlik)
		_v(ResourceLoader.exists(Portreler.KLASOR + "vesika/" + kimlik + ".webp"), "vesikalığı var: " + kimlik)
		_v(Portreler.agiz_dokusu(kimlik) != null, "konuşma kareleri var: " + kimlik)
		_v(_agiz_kareleri_duzgun(kimlik), "konuşma kareleri iki ayrı, tam görünür kare (yarı saydam kopya değil): " + kimlik)
		_v(not Portreler.benzerler(kimlik).is_empty(), "benzer listesi dolu: " + kimlik)

	# --- sabit kimlikler ---
	var sabit: Dictionary = (Veri.oku(Veri.VATANDAS_YOLU) as Dictionary).get("kisiler", {})
	var ad_soyadlar := {}
	for kimlik: String in havuz:
		_v(sabit.has(kimlik), "havuzdaki yüzün sabit kimliği var: " + kimlik)
	for kimlik: String in sabit:
		var k: Dictionary = sabit[kimlik]
		_v(kunye.has(kimlik), "kimliği olan yüz künyede var: " + kimlik)
		for alan: String in ["ad", "soyad", "baba_adi", "ana_adi", "dogum_yeri", "dogum_tarihi"]:
			_v(str(k.get(alan, "")).strip_edges() != "", "%s.%s dolu" % [kimlik, alan])
		var dogum := Tarih.coz(str(k.get("dogum_tarihi", "")))
		_v(not dogum.is_empty(), "%s doğum tarihi geçerli (%s)" % [kimlik, str(k.get("dogum_tarihi", ""))])
		if not dogum.is_empty() and kunye.has(kimlik):
			var yas := int((kunye[kimlik] as Dictionary).get("yas", 0))
			_v(absi((1984 - int(dogum.yil)) - yas) <= 2, "%s doğum yılı görünen yaşıyla tutuyor (%d yaş, %d doğumlu)" % [kimlik, yas, int(dogum.yil)])
		var tam_ad := "%s %s" % [str(k.get("ad", "")), str(k.get("soyad", ""))]
		_v(not ad_soyadlar.has(Imza.kod(tam_ad)), "ad-soyad tek: %s (%s ve %s)" % [tam_ad, kimlik, str(ad_soyadlar.get(Imza.kod(tam_ad), ""))])
		ad_soyadlar[Imza.kod(tam_ad)] = kimlik
		_v(Imza.doku(tam_ad) != null, "vatandaşın imza görseli var: %s (%s)" % [tam_ad, kimlik])

	# --- eşyalar ve çantalar ---
	var kategoriler: Dictionary = katalog.get("kategoriler", {})
	var esyalar: Dictionary = katalog.get("esyalar", {})
	for ad: String in esyalar:
		var e: Dictionary = esyalar[ad]
		_v(Canta.esya_dokusu(ad) != null, "eşyanın röntgen görseli var: " + ad)
		_v(str(e.get("ad", "")) != "" and float(e.get("boy", 0)) > 0.0, "eşyanın adı ve boyu var: " + ad)
		_v(float(e.get("yogun", -1)) >= 0.0 and float(e.get("yogun", -1)) <= 1.0, "eşyanın yoğunluğu 0..1: " + ad)
		for alan: String in ["kategori", "benzer"]:
			if e.has(alan):
				_v(kategoriler.has(str(e[alan])), "%s.%s tanımlı bir sınıf: %s" % [ad, alan, str(e[alan])])
	for kat: String in kategoriler:
		var var_mi := false
		for ad: String in esyalar:
			if str((esyalar[ad] as Dictionary).get("kategori", "")) == kat:
				var_mi = true
		_v(var_mi, "yasak sınıfında en az bir eşya var: " + kat)
		for ornek: Variant in (kategoriler[kat] as Dictionary).get("ornek", []):
			_v(str((esyalar.get(str(ornek), {}) as Dictionary).get("kategori", "")) == kat, "%s örneği o sınıftan: %s" % [kat, str(ornek)])
	for tur: String in katalog.get("cantalar", {}):
		_v(Canta.kabuk_dokusu(tur) != null and Canta.dis_doku(tur) != null, "çantanın röntgen kabuğu ve dış görünüşü var: " + tur)

	# --- mühür ve kaşeler ---
	for cesit: String in Damga.SAHTELER:
		_v(Damga.doku(Damga.doku_adi(cesit)) != null, "damga görseli var: %s (gerçek)" % cesit)
		for s: Array in Damga.SAHTELER[cesit]:
			_v(Damga.doku(Damga.doku_adi(cesit, str(s[0]))) != null, "sahte damga görseli var: %s/%s" % [cesit, str(s[0])])
	for cesit: String in ["daire", "onay", "gorulmustur"]:
		_v(Damga.doku(Damga.doku_adi(cesit)) != null, "damga görseli var: " + cesit)

	# --- günler ---
	var onceki_kurallar: Array = []
	var onceki_tarih := 0
	var n := 1
	while Veri.gun_var_mi(n):
		var g := Veri.gun(n)
		var e := "gun%d: " % n
		_v(int(g.get("gun", 0)) == n, e + "gün numarası dosya adıyla aynı")
		var tarih_no := Tarih.gun_no(str(g.get("tarih", "")))
		_v(tarih_no > onceki_tarih, e + "tarih geçerli ve bir öncekinden sonra")
		onceki_tarih = tarih_no
		_v(int(g.get("vatandas_sayisi", 0)) >= 1 and int(g.get("vatandas_sayisi", 0)) <= 20, e + "vatandaş sayısı makul")
		_v(float(g.get("hata_orani", -1)) >= 0.0 and float(g.get("hata_orani", -1)) <= 1.0, e + "hata oranı 0..1")
		_v(int(g.get("zorluk", 0)) >= 1 and int(g.get("zorluk", 0)) <= 3, e + "zorluk 1..3")
		_v(int(g.get("havale_hakki", 2)) >= 1, e + "havale hakkı var")
		var genelge: Dictionary = g.get("genelge", {})
		for alan: String in ["sayi", "konu", "metin"]:
			_v(str(genelge.get(alan, "")).strip_edges() != "", e + "genelge." + alan + " dolu")
		var islemler: Array = g.get("islemler", [])
		_v(not islemler.is_empty(), e + "en az bir işlem var")
		for i: Variant in islemler:
			_v(Islemler.TABLO.has(str(i)), e + "işlem tanımlı: " + str(i))
		var kimlikler := {}
		var tur_belge := {}
		for k: Dictionary in g.get("kurallar", []):
			var kid := str(k.get("id", ""))
			var tur := str(k.get("tur", ""))
			_v(kid != "" and not kimlikler.has(kid), e + "kural kimliği dolu ve tek: " + kid)
			kimlikler[kid] = true
			_v(KURAL_TURLERI.has(tur), e + "kural türü tanımlı: " + tur)
			_v(str(k.get("metin", "")).strip_edges() != "", e + "kural metni dolu: " + kid)
			if tur != "alan_esit":
				var anahtar := tur + "/" + str(k.get("belge", ""))
				_v(not tur_belge.has(anahtar), e + "aynı türden kural bir kez yazılmış: " + anahtar)
				tur_belge[anahtar] = true
			_v(Dogrulayici.KURAL_GEREKCESI.has(tur) or ["alan_esit", "arananlar", "vize", "canta_kontrol"].has(tur),
				e + "kural türünün gerekçesi tanımlı: " + tur)
			match tur:
				"belge_zorunlu":
					for t: Variant in k.get("belgeler", []):
						_v(BELGE_TURLERI.has(str(t)), e + "zorunlu belge türü tanımlı: " + str(t))
						_v((g.get("belgeler", ["nufus_cuzdani", "ikametgah"]) as Array).has(str(t)), e + "zorunlu belge o gün vatandaşa veriliyor: " + str(t))
				"alan_esit":
					for a: Variant in k.get("alanlar", []):
						_v(Dogrulayici.ALAN_ADLARI.has(str(a)), e + "karşılaştırılan alan tanımlı: " + str(a))
				"tarih_sure":
					_v(BELGE_TURLERI.has(str(k.get("belge", ""))), e + "süre kuralının belgesi tanımlı")
					_v(int(k.get("ay", 0)) > 0 or int(k.get("gun", 0)) > 0, e + "süre kuralında ay ya da gün var")
				"harc_tutar":
					for i: Variant in islemler:
						_v(Dogrulayici.harc(k, str(i)) > 0, e + "tarifede harcı var: " + str(i))
				"seri_aralik":
					_v(not (k.get("araliklar", []) as Array).is_empty(), e + "seri aralığı var")
					for a: Dictionary in k.get("araliklar", []):
						_v(str(a.get("onek", "")) != "" and int(a.get("min", 0)) < int(a.get("max", 0)), e + "seri aralığı düzgün")
				"mahalle_listesi":
					for m: Variant in k.get("mahalleler", []):
						_v(muhtari.has(str(m)), e + "listedeki mahalle tanımlı: " + str(m))
				"arananlar":
					for a: Dictionary in k.get("liste", []):
						_v(kunye.has(str(a.get("portre", ""))), e + "arananın yüzü var: " + str(a.get("portre", "")))
						_v(str(a.get("ad", "")) != "" and str(a.get("bayrak", "")) != "", e + "arananın adı ve bayrağı var")
						_v(ResourceLoader.exists(Portreler.KLASOR + "aranan/" + str(a.get("portre", "")) + ".webp"), e + "arananın dosya resmi var")
				"vize":
					_v(islemler.has(str(k.get("islem", "yurt_disi"))), e + "vize aranan işlem o gün yapılıyor")
					var no: Dictionary = k.get("no", {})
					_v(str(no.get("onek", "")) != "" and int(no.get("min", 0)) < int(no.get("max", 0)) and int(no.get("max", 0)) <= 99999, e + "vize numarası aralığı düzgün")
				"canta_kontrol":
					_v(not (k.get("yasak", []) as Array).is_empty(), e + "en az bir yasak sınıfı var")
					for y: Variant in k.get("yasak", []):
						_v(kategoriler.has(str(y)), e + "yasak sınıfı tanımlı: " + str(y))
		# kurallar birikir: önceki günün her kuralı bugün de yürürlükte
		for kid: String in onceki_kurallar:
			_v(kimlikler.has(kid), e + "önceki günün kuralı sürüyor: " + kid)
		onceki_kurallar = kimlikler.keys()
		for g_kod: String in Dogrulayici.gunun_gerekceleri(g):
			_v(Dogrulayici.GEREKCELER.has(g_kod), e + "gerekçenin metni var: " + g_kod)
		var son_bitis := float(_masa_sabiti("MESAI_BASI"))
		for aralik: Variant in g.get("denetim", []):
			var tamam := typeof(aralik) == TYPE_ARRAY and (aralik as Array).size() == 2
			_v(tamam, e + "denetim aralığı iki sayı")
			if tamam:
				_v(float(aralik[0]) >= son_bitis and float(aralik[0]) < float(aralik[1]) and float(aralik[1]) <= float(_masa_sabiti("MESAI_SONU")),
					e + "denetim aralığı mesai içinde ve sıralı")
				son_bitis = float(aralik[1])
		n += 1
	_v(n - 1 == Oyun.TOPLAM_GUN, "gün dosyası sayısı oyunun gün sayısıyla aynı (%d)" % (n - 1))

	# --- hikâye: karakterler ve ziyaretler ---
	var baskasinin_cuzdani := {}
	for z: Dictionary in karakterler.get("ziyaretler", []):
		if z.has("foto"):
			baskasinin_cuzdani[str(z.get("kisi", ""))] = true
	for kod: String in kisiler:
		var k: Dictionary = kisiler[kod]
		var e := "kişi %s: " % kod
		_v(kunye.has(str(k.get("portre", ""))), e + "yüzü var")
		_v(ResourceLoader.exists(Portreler.KLASOR + "vesika/" + str(k.get("portre", "")) + ".webp"), e + "vesikalığı var")
		for alan: String in ["ad", "soyad", "baba_adi", "ana_adi", "dogum_yeri", "dogum_tarihi", "seri_no", "cinsiyet"]:
			_v(str(k.get(alan, "")).strip_edges() != "", e + alan + " dolu")
		_v(not Tarih.coz(str(k.get("dogum_tarihi", ""))).is_empty(), e + "doğum tarihi geçerli")
		# başkasının cüzdanıyla gelen (ziyaretinde yabancı fotoğraf olan) kişide kimlik ile yüz bilerek ayrıdır
		if not baskasinin_cuzdani.has(kod):
			_v(str(k.get("cinsiyet", "")) == str((kunye.get(str(k.get("portre", "")), {}) as Dictionary).get("cinsiyet", "")), e + "cinsiyeti yüzüyle aynı")
		var imzasi := str(k.get("imza", "%s %s" % [str(k.get("ad", "")), str(k.get("soyad", ""))]))
		_v(Imza.doku(imzasi) != null, e + "imza görseli var (%s)" % imzasi)
		if k.has("mahalle"):
			_v(muhtari.has(str(k.mahalle)), e + "mahallesi tanımlı: " + str(k.mahalle))
			if k.has("muhtar") and muhtari.has(str(k.mahalle)):
				_v(str(k.muhtar) == str(muhtari[str(k.mahalle)]), e + "muhtarı mahallesinin muhtarı (%s ≠ %s)" % [str(k.muhtar), str(muhtari[str(k.mahalle)])])
		_v(not ad_soyadlar.has(Imza.kod(imzasi)) or str(ad_soyadlar[Imza.kod(imzasi)]) == str(k.get("portre", "")),
			e + "adı başka bir yüzün kimliğiyle çakışmıyor")

	var kodlar := {}
	var yazilan := {}      # etkilerin yazdığı bayraklar
	var okunan := {}       # koşulların okuduğu bayraklar
	for z: Dictionary in karakterler.get("ziyaretler", []):
		var kod := str(z.get("kod", ""))
		var e := "ziyaret %s: " % kod
		_v(kod != "" and not kodlar.has(kod), e + "kodu dolu ve tek")
		kodlar[kod] = true
		var gun_no := int(z.get("gun", 0))
		_v(gun_no >= 1 and gun_no <= Oyun.TOPLAM_GUN, e + "günü 1..7")
		var g := Veri.gun(clampi(gun_no, 1, Oyun.TOPLAM_GUN))
		_v(int(z.get("sira", 1)) >= 1, e + "sırası 1 ya da büyük")
		_v(not z.has("kosul") or typeof(z.kosul) == TYPE_DICTIONARY, e + "koşulu sözlük")
		for ad: String in z.get("kosul", {}):
			okunan[ad] = kod
		var etki: Dictionary = z.get("etki", {})
		for an: String in etki:
			_v(ETKI_ANLARI.has(an), e + "etki anı tanımlı: " + an)
			_v(typeof(etki[an]) == TYPE_DICTIONARY, e + "etki sözlük: " + an)
			if typeof(etki[an]) != TYPE_DICTIONARY:
				continue
			for alan: String in etki[an]:
				_v(ETKI_ALANLARI.has(alan), e + "etki alanı tanımlı: %s.%s" % [an, alan])
			for ad: String in (etki[an] as Dictionary).get("bayrak", {}):
				yazilan[ad] = kod
			if (etki[an] as Dictionary).has("sonuc"):
				_v(["dogru", "yanlis", "yarim", "notr"].has(str(etki[an].sonuc)), e + "etki sonucu tanımlı: " + str(etki[an].sonuc))
		if z.has("zarf"):
			_v(int(z.zarf) > 0, e + "zarf tutarı artı")
			_v(etki.has("zarf"), e + "zarfın alınmasının etkisi yazılı")
		if bool(z.get("belgesiz", false)):
			_v(kunye.has(str(z.get("portre", ""))), e + "yüzü var")
			_v(not (z.get("satirlar", []) as Array).is_empty(), e + "söyleyeceği var")
			for s: Variant in z.get("satirlar", []):
				_v(typeof(s) == TYPE_STRING and str(s).strip_edges() != "", e + "satırı dolu")
			continue
		_v(kisiler.has(str(z.get("kisi", ""))), e + "kişisi tanımlı: " + str(z.get("kisi", "")))
		_v((g.get("islemler", []) as Array).has(str(z.get("islem", ""))), e + "işlemi o gün yapılıyor: " + str(z.get("islem", "")))
		var konusma: Dictionary = z.get("konusma", {})
		for an: String in ["giris", "onay", "eksik", "havale"]:
			_v(str(konusma.get(an, "")).strip_edges() != "", e + "konuşması var: " + an)
		for an: String in ["alarm", "gecir"]:
			if etki.has(an):
				_v(z.has("canta"), e + "çanta etkisi var ama çantası yok: " + an)
		if z.has("foto"):
			_v(kunye.has(str(z.foto)), e + "cüzdandaki yabancı fotoğraf tanımlı")
		for tur: Variant in z.get("sil", []):
			_v(BELGE_TURLERI.has(str(tur)), e + "silinen belge türü tanımlı: " + str(tur))
		for yol: String in z.get("alan", {}):
			var p := yol.split(".")
			_v(p.size() == 2 and BELGE_TURLERI.has(p[0]) and p[1] != "", e + "alan düzeltmesi 'belge.alan' biçiminde: " + yol)
			if p.size() == 2 and p[1] == "kase_turu":
				_v(Damga.sahte_aciklamasi("vezne" if p[0] == "harc_makbuzu" else "vize", str(z.alan[yol])) != "Örneğe uymuyor",
					e + "sahte kaşe türü tanımlı: " + str(z.alan[yol]))
			if p.size() == 2 and p[1] == "muhur_turu":
				_v(Damga.sahte_aciklamasi("muhtar", str(z.alan[yol])) != "Örneğe uymuyor", e + "sahte mühür türü tanımlı: " + str(z.alan[yol]))
			if p.size() == 2 and p[1] == "mahalle":
				_v(muhtari.has(str(z.alan[yol])), e + "düzeltilen mahalle tanımlı")
			if p.size() == 2 and p[1] in ["tarih", "verilis", "bitis"]:
				_v(not Tarih.coz(str(z.alan[yol])).is_empty(), e + "düzeltilen tarih geçerli: " + str(z.alan[yol]))
		if z.has("canta"):
			var c: Dictionary = z.canta
			_v((katalog.get("cantalar", {}) as Dictionary).has(str(c.get("tur", ""))), e + "çanta türü tanımlı")
			for ad: Variant in c.get("esyalar", []):
				_v(esyalar.has(str(ad)), e + "çantadaki eşya tanımlı: " + str(ad))
		# ziyaretin vatandaşı sorunsuz kuruluyor, belgeleri ekranda açılıyor
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(kod)
		var v := Hikaye.vatandas_kur(z, g, rng)
		_v(kunye.has(str(v.get("portre", ""))), e + "kurulan vatandaşın yüzü var")
		for b: Dictionary in v.get("belgeler", []):
			var belge := Belge.olustur(b)
			_v(belge != null and not belge.alanlar.is_empty(), e + "belgesi kuruluyor: " + str(b.get("tur", "")))
			if belge != null:
				belge.free()

	# --- hikâye: gazete, akşam, gece, sonlar; bayrakların yazanı ve okuyanı ---
	var hikaye := Hikaye.veri()
	for bolum: String in ["gazete", "aksam", "gece"]:
		var kayitli := {}
		for kayit: Dictionary in hikaye.get(bolum, []):
			var gun_no := int(kayit.get("gun", 0))
			_v(gun_no >= 1 and gun_no <= Oyun.TOPLAM_GUN, "%s kaydının günü 1..7" % bolum)
			_v(str(kayit.get("metin", "")).strip_edges() != "", "%s kaydının metni dolu (gün %d)" % [bolum, gun_no])
			kayitli[gun_no] = true
			for ad: String in kayit.get("kosul", {}):
				okunan[ad] = bolum
		if bolum != "gece":
			for gun_no in range(1, Oyun.TOPLAM_GUN + 1):
				_v(kayitli.has(gun_no), "%s: %d. gün için en az bir kayıt var" % [bolum, gun_no])
	# hiçbir koşulu tutturmayan (beklenmedik) bayraklarla da sabah gazetesi ve akşam metni boş kalmaz
	for gun_no in range(1, Oyun.TOPLAM_GUN + 1):
		_v(str(Hikaye.gazete(gun_no, {"savci": 1, "kasap": true}).get("manset", "")) != "", "beklenmedik bayraklarla da %d. günün gazetesi çıkıyor" % gun_no)
		_v(Hikaye.aksam(gun_no, {"savci": 1, "husnu_onay": "x"}) != "", "beklenmedik bayraklarla da %d. günün akşam metni çıkıyor" % gun_no)
	var son: Dictionary = hikaye.get("son", {})
	for tur: String in ["terfi", "olagan", "surgun_ihtar", "surgun_suphe", "iflas", "aile", "tahliye"]:
		var s: Dictionary = (son.get("ana", {}) as Dictionary).get(tur, {})
		_v(str(s.get("manset", "")) != "" and str(s.get("metin", "")) != "", "son gazetesi yazılı: " + tur)
	for y: Dictionary in son.get("yan", []):
		_v(str(y.get("baslik", "")) != "" and str(y.get("metin", "")) != "", "yan haberin başlığı ve metni dolu")
		for ad: String in y.get("kosul", {}):
			okunan[ad] = "son.yan"
	_v(str(son.get("mektup", "")).strip_edges() != "", "mektup metni dolu")
	# kodun doğrudan yazdığı bayraklar (arananlar listesi, savcının akıbeti)
	var kaynak := _kaynak_metni()
	for ad: String in okunan:
		var kodda := kaynak.contains('bayraklar["%s"]' % ad)
		var aranan := false
		n = 1
		while Veri.gun_var_mi(n):
			for a: Dictionary in Veri.kural(Veri.gun(n), "arananlar").get("liste", []):
				if str(a.get("bayrak", "")) == ad:
					aranan = true
			n += 1
		_v(yazilan.has(ad) or kodda or aranan, "koşulda okunan bayrağı yazan bir yer var: '%s' (okuyan: %s)" % [ad, str(okunan[ad])])

	# --- kaynak koddaki adlar: sesler, şeritler, dosya yolları ---
	var desen := RegEx.new()
	desen.compile('Ses\\.(?:cal|gecikmeli|ortam)(?:\\.bind)?\\(\\s*"([a-z_0-9]+)"')
	for m in desen.search_all(kaynak):
		_v(Ses._akis(m.get_string(1), 0) != null, "koddaki sesin dosyası var: " + m.get_string(1))
	desen.compile('"(res://[^"%]+\\.[a-z0-9]+)"')
	for m in desen.search_all(kaynak):
		var yol := m.get_string(1)
		_v(ResourceLoader.exists(yol) or FileAccess.file_exists(yol), "koddaki dosya yolu var: " + yol)
	desen.compile('(?:Serit\\.olustur|Serit\\.doku|_serit|_plaka)\\(\\s*"([a-z_0-9]+)"\\s*[,)]')
	for m in desen.search_all(kaynak):
		_v(Serit.doku(m.get_string(1)) != null, "koddaki etiket görseli var: " + m.get_string(1))
	for parca: String in _radyo_listesi() + ["ney", "taksim"]:
		_v(Ses._yukle(Ses.MUZIK_KLASORU, parca) != null, "müzik dosyası var: " + parca)
	for ad: String in Oyun.SAHNELER:
		_v(ResourceLoader.exists(str(Oyun.SAHNELER[ad])), "sahne dosyası var: " + ad)
	for ad: String in Belge.SAHNELER:
		_v(ResourceLoader.exists(str(Belge.SAHNELER[ad])), "belge sahnesi var: " + ad)
	dogru(_hata == once, "veri denetimi temiz (%d denetim)" % _adim)


## Konuşma atlasının iki karesi de aynı ölçüde görünür mü ve birbirinden farklı mı? (Bir karenin, ötekinin
## yarı saydam kopyası olması konuşurken çift dudak gösterir.)
func _agiz_kareleri_duzgun(kimlik: String) -> bool:
	var doku := Portreler.agiz_dokusu(kimlik)
	if doku == null:
		return false
	var g := doku.get_image()
	if g.is_compressed():
		g.decompress()
	@warning_ignore("integer_division")
	var yari := g.get_width() / 2
	var alfa := [0.0, 0.0]
	var fark := 0.0
	var sayi := 0
	for y in range(0, g.get_height(), 3):
		for x in range(0, yari, 3):
			var a := g.get_pixel(x, y)
			var b := g.get_pixel(x + yari, y)
			alfa[0] += a.a
			alfa[1] += b.a
			if a.a > 0.8 and b.a > 0.8:
				fark += absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
				sayi += 1
	if alfa[1] <= 0.0 or sayi < 20:
		return false
	var oran: float = alfa[0] / alfa[1]
	return oran > 0.85 and oran < 1.15 and fark / sayi > 0.012


func _masa_sabiti(ad: String) -> Variant:
	return (load("res://scripts/Masa.gd") as GDScript).get_script_constant_map()[ad]


func _radyo_listesi() -> Array:
	return _masa_sabiti("RADYO_LISTESI")


func _kaynak_metni() -> String:
	var metin := ""
	for klasor: String in ["res://scripts", "res://scripts/belgeler"]:
		for ad in DirAccess.get_files_at(klasor):
			if ad.ends_with(".gd"):
				metin += FileAccess.get_file_as_string(klasor + "/" + ad) + "\n"
	return metin


# =====================================================================================================
# 2. Kayıt ve ayar dosyaları
# =====================================================================================================

func _dosyaya_yaz(yol: String, icerik: Variant) -> void:
	var d := FileAccess.open(yol, FileAccess.WRITE)
	if typeof(icerik) == TYPE_PACKED_BYTE_ARRAY:
		d.store_buffer(icerik)
	else:
		d.store_string(str(icerik))
	d.close()


## Geçerli imzalı bir zarf üretir (anahtarı bilen biri ya da ilerideki bir hata, içeriği yine de bozabilir).
func _imzali(veri: Variant) -> String:
	var metin := JSON.stringify(veri)
	return JSON.stringify({"surum": Oyun.SURUM, "imza": Oyun._imza(metin), "veri": metin})


func _durum_makul() -> bool:
	return Oyun.gun >= 1 and Oyun.gun <= Oyun.TOPLAM_GUN and Oyun.KIPLER.has(Oyun.zorluk) \
		and absi(Oyun.para) <= Oyun.PARA_SINIRI and Oyun.ihtar >= 0 and Oyun.ihtar <= Oyun.IHTAR_SINIRI \
		and Oyun.suphe >= 0 and Oyun.suphe <= Oyun.SUPHE_SINIRI and Oyun.tohum >= 0 \
		and typeof(Oyun.aile.get("saglik")) == TYPE_DICTIONARY and Oyun.bayraklar.size() <= Oyun.BAYRAK_SINIRI


func _bolum_kayit() -> void:
	print("== Kayıt ve ayar dosyaları ==")
	var yol := Oyun.kayit_yolu
	Oyun.kaydi_sil()
	dogru(not Oyun.kayit_var_mi() and not Oyun.yukle(), "kayıt yokken yükleme olmaz")

	# gidiş-dönüş: değerler ve türleri aynen döner
	Oyun.yeni_oyun("orta")
	Oyun.gun = 5
	Oyun.para = 1234
	Oyun.ihtar = 3
	Oyun.suphe = 1
	Oyun.bayraklar = {"husnu_onay": 1, "nermin": "kayirildi", "mektup": true}
	Oyun.gorulen_portreler = ["v01", "v02", "v40"]
	Oyun.aile["saglik"]["can"] = 1
	Oyun.aile["kira_borcu"] = 2
	Oyun.toplam = {"islenen": 30, "dogru": 20, "yanlis": 6, "kazanc": 2600}
	var tohum := Oyun.tohum
	dogru(Oyun.kaydet(), "kayıt yazılır")
	dogru(not FileAccess.file_exists(yol + ".tmp"), "  geçici dosya geride kalmaz")
	dogru(FileAccess.file_exists(yol + ".yedek"), "  önceki kayıt yedeğe alınır")
	var beklenen := JSON.stringify(Oyun.kayit_verisi())
	var dosya_metni := FileAccess.get_file_as_string(yol)
	Oyun.yeni_oyun("kolay")
	_dosyaya_yaz(yol, dosya_metni)
	dogru(Oyun.yukle(), "kayıt yüklenir")
	esit(JSON.stringify(Oyun.kayit_verisi()), beklenen, "  yüklenen durum yazılanla birebir aynı")
	esit(typeof(Oyun.bayraklar.get("husnu_onay")), TYPE_INT, "  sayı bayrağı tam sayı olarak döner")
	esit(typeof(Oyun.bayraklar.get("mektup")), TYPE_BOOL, "  mantıksal bayrak mantıksal olarak döner")
	esit(Oyun.tohum, tohum, "  tohum korunur")

	# elle değiştirilmiş dosya: imza tutmaz
	Oyun.kaydet()
	var ham := FileAccess.get_file_as_string(yol)
	dogru(ham.contains("1234"), "kayıt dosyasında para değeri okunuyor (değiştirme denemesi için)")
	DirAccess.remove_absolute(yol + ".yedek")
	_dosyaya_yaz(yol, ham.replace("1234", "999999"))
	Oyun.para = 77
	dogru(not Oyun.kayit_var_mi(), "elle değiştirilen kayıt geçersiz sayılır")
	dogru(not Oyun.yukle() and Oyun.para == 77, "  yüklenmez, oyun durumuna dokunulmaz")
	# asıl dosya bozuksa yedek devreye girer
	_dosyaya_yaz(yol + ".yedek", ham)
	dogru(Oyun.yukle() and Oyun.para == 1234, "asıl kayıt bozuksa yedekten yüklenir")

	# bozuk, eksik, yabancı dosyalar
	var eski_bicim := JSON.stringify({"surum": 2, "gun": 6, "para": 99999, "zorluk": "kolay"})
	var derin := "[".repeat(5000) + "]".repeat(5000)
	var bozuklar := {
		"boş dosya": "",
		"yarım JSON": "{\"surum\": 3, \"imza\": \"ab",
		"null": "null",
		"dizi": "[1, 2, 3]",
		"sayı": "42",
		"metin": "\"merhaba\"",
		"boş sözlük": "{}",
		"eski imzasız biçim": eski_bicim,
		"alanların türü yanlış": "{\"surum\": 3, \"imza\": 5, \"veri\": [1]}",
		"imza yanlış": JSON.stringify({"surum": Oyun.SURUM, "imza": "00".repeat(32), "veri": "{\"gun\": 7}"}),
		"imzalı ama sözlük değil": _imzali([1, 2, 3]),
		"başka sürüm": JSON.stringify({"surum": 99, "imza": Oyun._imza("{}"), "veri": "{}"}),
		"çok derin iç içe": derin,
		"aşırı büyük dosya": "{\"x\": \"" + "a".repeat(Oyun.KAYIT_BOYUT_SINIRI + 10) + "\"}",
		"geçersiz baytlar": PackedByteArray([0xff, 0xfe, 0x00, 0x7b, 0x22, 0xc3, 0x28, 0x00, 0x9f]),
	}
	for ad: String in bozuklar:
		Oyun.kaydi_sil()
		_dosyaya_yaz(yol, bozuklar[ad])
		Oyun.para = 55
		Oyun.gun = 2
		dogru(not Oyun.kayit_var_mi() and not Oyun.yukle() and Oyun.para == 55 and Oyun.gun == 2, "bozuk kayıt yok sayılır: " + ad)

	# imzası doğru ama içeriği düşmanca: her alan güvenli değere çekilir
	Oyun.kaydi_sil()
	_dosyaya_yaz(yol, _imzali({"gun": 99, "zorluk": 5, "para": 1.0e300, "ihtar": -5, "suphe": "çok", "tohum": -1,
		"gorulen_portreler": "v01", "aile": [], "bayraklar": [1, 2], "toplam": "x"}))
	dogru(Oyun.yukle(), "düşmanca içerikli (imzası doğru) kayıt çökertmeden yüklenir")
	esit(Oyun.gun, Oyun.TOPLAM_GUN, "  gün son güne çekilir")
	esit(Oyun.zorluk, "kolay", "  tanınmayan görev şekli kolaya döner")
	esit(Oyun.para, Oyun.PARA_SINIRI, "  para sınıra çekilir")
	esit([Oyun.ihtar, Oyun.suphe, Oyun.tohum], [0, 0, 0], "  ihtar, şüphe ve tohum sıfırlanır")
	esit(Oyun.gorulen_portreler, [], "  dizi olmayan yüz listesi boşalır")
	esit(JSON.stringify(Oyun.aile), JSON.stringify(AileDurumu.yeni()), "  aile durumu baştan kurulur")
	esit(Oyun.bayraklar, {}, "  sözlük olmayan bayraklar boşalır")
	esit(int(Oyun.toplam.get("islenen", -1)), 0, "  sayaçlar sıfırlanır")

	var cok_bayrak := {}
	for i in 500:
		cok_bayrak["b%d" % i] = i
	_dosyaya_yaz(yol, _imzali({"gun": "3", "zorluk": "zor", "para": -1.0e300, "ihtar": 1.0e12, "suphe": 7.9,
		"gorulen_portreler": ["v01", 5, "olmayan", "v01", {"a": 1}, "v02", null],
		"aile": {"saglik": {"anne": -4, "elif": "iyi", "can": 99}, "soguk_gece": 1.0e99, "kira_borcu": [], "ikram": "evet"},
		"bayraklar": {"dizi": [1], "sozluk": {"c": 1}, "husnu_onay": 2.0, "kesir": 0.5, "x".repeat(100): 1, "": 1,
			"uzun": "y".repeat(500), "iyi": "tamam", "dogru": true, "yok": null},
		"toplam": {"islenen": -4, "dogru": "on", "kazanc": 1.0e99}}))
	dogru(Oyun.yukle() and _durum_makul(), "ikinci düşmanca kayıt da makul bir duruma çekilir")
	esit(Oyun.gun, 1, "  metin olarak yazılmış gün sayılmaz")
	esit(Oyun.para, -Oyun.PARA_SINIRI, "  eksi para alt sınıra çekilir")
	esit(Oyun.gorulen_portreler, ["v01", "v02"], "  yüz listesinden yalnız tanınan, yinelenmeyen yüzler kalır")
	esit(Oyun.aile.saglik, {"anne": 0, "elif": 3, "can": 3}, "  sağlık değerleri 0..3 aralığına oturur")
	esit(typeof(Oyun.aile.ikram), TYPE_BOOL, "  mantıksal olmayan ikram yok sayılır")
	esit(Oyun.bayraklar, {"husnu_onay": 2, "kesir": 0.5, "iyi": "tamam", "dogru": true}, "  bayraklardan yalnız sade değerler kalır")
	_dosyaya_yaz(yol, _imzali({"gun": 2, "bayraklar": cok_bayrak}))
	dogru(Oyun.yukle() and Oyun.bayraklar.size() == Oyun.BAYRAK_SINIRI, "bayrak sayısı sınırlanır")

	# düşmanca kayıtla oyun açılıp bir gün başlatılabiliyor
	_dosyaya_yaz(yol, _imzali({"gun": 7, "zorluk": "zor", "para": -50, "ihtar": 13, "suphe": 3, "tohum": 4294967295.0,
		"bayraklar": {"husnu_onay": "bozuk", "nermin": 5, "tarik2": true, "kasap": [], "savci": 1}}))
	dogru(Oyun.yukle(), "sınırdaki değerlerle kayıt yüklenir")
	await sahneye_git("masa")
	dogru(await sahneyi_bekle("Masa"), "  o kayıtla mesai sahnesi açılır")
	await bekle(0.6)
	bas("GiseyiAc")
	var masa := sahne()
	dogru(await kosulu_bekle(func() -> bool: return not masa.vatandas.is_empty(), 8.0), "  ilk vatandaş gişeye gelir")
	for gun_no in range(1, Oyun.TOPLAM_GUN + 1):
		Hikaye.gazete(gun_no, Oyun.bayraklar)
		Hikaye.aksam(gun_no, Oyun.bayraklar)
		Hikaye.gece(gun_no, Oyun.bayraklar)
	dogru(str(Hikaye.son({"tur": "kotu", "neden": "iflas"}, Oyun.bayraklar).manset) != "", "  bozuk bayraklarla son gazetesi kurulur")
	await sahneye_git("menu")
	await sahneyi_bekle("AnaMenu")
	Oyun.kaydi_sil()
	dogru(not FileAccess.file_exists(yol) and not FileAccess.file_exists(yol + ".yedek"), "kayıt silinince yedeği de silinir")

	# --- kayıt aşamaları: aynı günü baştan oynamak, kötü günü silmek, akşamı yeniden seçmek ---
	Oyun.yeni_oyun("orta")
	var ilk_tohum := Oyun.gun_tohumu()
	dogru(Oyun.yukle() and Oyun.gun_tohumu() == ilk_tohum, "gişe açılmadan kayıttan dönülürse kuyruk aynı kalır")
	Oyun.para = 9999
	Oyun.mesaiyi_isaretle()
	dogru(Oyun.yukle() and Oyun.gun_denemesi == 1 and Oyun.gun_tohumu() != ilk_tohum, "gişesi açılmış gün kayıttan sürdürülürse kuyruk yeniden karılır")
	esit(Oyun.para, Oyun.BASLANGIC_PARASI, "  gün içinde değişen para dosyaya geçmemiştir")
	dogru(Oyun.yukle() and Oyun.gun_denemesi == 1, "  gişe yeniden açılmadıkça deneme sayısı artmaz")
	Oyun.mesaiyi_isaretle()
	Oyun.mesaiyi_kapat({"islenen": 4, "dogru": 1, "yanlis": 3, "yarim": 0, "havale": 0, "yarida": 0, "kazanc": 100,
		"ihtar": 3, "ihtarlar": ["Kusurlu evrakı onayladınız."]})
	var kapanis_parasi := Oyun.para
	Oyun.para = 1
	Oyun.ihtar = 0
	dogru(Oyun.yukle() and Oyun.asama == "gun_sonu", "mesai kapanınca sonuç kaydedilir: kayıttan dönülünce puantaj gelir")
	esit([Oyun.para, Oyun.ihtar, int(Oyun.gun_ozeti.get("islenen", 0))], [kapanis_parasi, 3, 4], "  kötü günün parası, ihtarı ve özeti yerinde")
	esit(int((Oyun.gun_ozeti.get("maas", {}) as Dictionary).get("net", 0)), Oyun.YEVMIYE + 100 - Oyun.KESINTI_ILK, "  maaş yeniden hesaplanır")
	Oyun.para -= 200
	Oyun.sabahi_kaydet()
	Oyun.para = 5
	dogru(Oyun.yukle() and Oyun.gun == 2 and Oyun.asama == "masa" and Oyun.para == kapanis_parasi - 200, "ışık sönünce ertesi sabah kaydedilir: akşam yeniden seçilemez")
	Oyun.sonu_kaydet({"tur": "kotu", "neden": "aile", "kritik": "can"})
	Oyun.son = {}
	dogru(Oyun.yukle() and Oyun.asama == "son" and str(Oyun.son.get("neden", "")) == "aile" and str(Oyun.son.get("kritik", "")) == "can",
		"oyunun sonu belli olunca kaydedilir: kayıttan dönülünce son gelir")
	_dosyaya_yaz(yol, _imzali({"gun": 3, "asama": "gun_sonu", "gun_ozeti": "x"}))
	dogru(Oyun.yukle() and Oyun.asama == "masa", "özeti bozuk 'gün sonu' kaydı gün başına döner")
	_dosyaya_yaz(yol, _imzali({"gun": 3, "asama": "son", "son": {"tur": "uydurma"}}))
	dogru(Oyun.yukle() and Oyun.asama == "masa" and Oyun.son.is_empty(), "tanınmayan oyun sonu kabul edilmez")
	_dosyaya_yaz(yol, _imzali({"gun": 3, "asama": "son", "son": {"tur": "kotu", "neden": "<yabancı>", "kritik": "kimse"}}))
	dogru(Oyun.yukle() and Oyun.asama == "son" and str(Oyun.son.neden) == "" and not Oyun.son.has("kritik"), "oyun sonundaki tanınmayan alanlar atılır")
	_dosyaya_yaz(yol, _imzali({"gun": 2, "asama": "gun_sonu", "gun_ozeti": {"islenen": "çok", "kazanc": 1.0e99,
		"ihtarlar": [1, "a", {"x": 1}], "maas": {"net": 999999}}}))
	dogru(Oyun.yukle() and Oyun.asama == "gun_sonu", "düşmanca gün özeti çökertmeden yüklenir")
	esit([int(Oyun.gun_ozeti.islenen), int(Oyun.gun_ozeti.kazanc), Oyun.gun_ozeti.ihtarlar], [0, Oyun.PARA_SINIRI, ["a"]], "  özet alanları aralığa çekilir")
	esit(int(Oyun.gun_ozeti.maas.net), Oyun.YEVMIYE + Oyun.PARA_SINIRI, "  dosyadaki maaşa güvenilmez, yeniden hesaplanır")
	# menüden "Devam": kayıt hangi aşamadaysa o ekran açılır
	await sahneye_git("menu")
	await sahneyi_bekle("AnaMenu")
	bas("Devam")
	dogru(await sahneyi_bekle("GunSonu", 8.0), "gün sonunda alınmış kayıt puantaj ekranından sürer")
	await bekle(0.5)
	Oyun.sonu_kaydet({"tur": "surgun", "neden": "ihtar"})
	await sahneye_git("menu")
	await sahneyi_bekle("AnaMenu")
	bas("Devam")
	dogru(await sahneyi_bekle("Son", 8.0), "sonu belli olmuş kayıt son ekranından sürer")
	dogru(not Oyun.kayit_var_mi(), "  son gösterilince kayıt silinir")
	await sahneye_git("menu")
	await sahneyi_bekle("AnaMenu")

	_bayrak_supurmesi()

	# ayarlar
	_dosyaya_yaz(Oyun.ayar_yolu, JSON.stringify({"saat_hizi": 0, "ses_genel": 99, "ses_efekt": "yüksek", "ses_ortam": -3,
		"tam_ekran": "evet", "yabanci": 1, "pencere_boyutu": "99999x99999", "kare_siniri": 45, "efekt_kalitesi": 5,
		"muzik_acik": "evet", "fare_hassasiyeti": 99, "yazi_hizi": -1, "dikey_esleme": 0}))
	Oyun.ayarlari_yukle()
	esit(float(Oyun.ayar("saat_hizi")), 0.4, "ayar: sıfır saat hızı en küçük değere çekilir")
	esit(float(Oyun.ayar("ses_genel")), 1.0, "  aşırı ses düzeyi 1'e çekilir")
	esit(float(Oyun.ayar("ses_efekt")), float(Oyun.VARSAYILAN_AYARLAR.ses_efekt), "  sayı olmayan ayar varsayılana döner")
	esit(float(Oyun.ayar("ses_ortam")), 0.0, "  eksi ses düzeyi sıfıra çekilir")
	esit([Oyun.ayar("pencere_boyutu"), Oyun.ayar("kare_siniri"), Oyun.ayar("efekt_kalitesi")], ["1280x720", 0, "yuksek"],
		"  tanınmayan seçenekler (pencere boyutu, kare sınırı, efekt kalitesi) varsayılana döner")
	esit([Oyun.ayar("muzik_acik"), Oyun.ayar("dikey_esleme")], [true, true], "  mantıksal olmayan açık/kapalı ayarlar varsayılanda kalır")
	esit([float(Oyun.ayar("fare_hassasiyeti")), float(Oyun.ayar("yazi_hizi"))], [2.0, 0.4], "  fare hassasiyeti ve yazı hızı aralığa çekilir")
	_dosyaya_yaz(Oyun.ayar_yolu, JSON.stringify({"kare_siniri": 60.0, "efekt_kalitesi": "orta", "pencere_boyutu": "1600x900"}))
	Oyun.ayarlari_yukle()
	esit([Oyun.ayar("kare_siniri"), Oyun.ayar("efekt_kalitesi"), Oyun.ayar("pencere_boyutu")], [60, "orta", "1600x900"],
		"  geçerli seçenekler dosyadan aynen okunur")
	esit(Oyun.ayar("tam_ekran"), false, "  mantıksal olmayan tam ekran yok sayılır")
	dogru(not Oyun.ayarlar.has("yabanci"), "  tanınmayan ayar alınmaz")
	for ad: String in ["yarım", "dizi", "boş"]:
		_dosyaya_yaz(Oyun.ayar_yolu, {"yarım": "{\"ses_genel\": 0.", "dizi": "[]", "boş": ""}[ad])
		Oyun.ayarlari_yukle()
		esit(JSON.stringify(Oyun.ayarlar), JSON.stringify(Oyun.VARSAYILAN_AYARLAR), "bozuk ayar dosyası varsayılanlara döner: " + ad)
	Oyun.ayar_degistir("olmayan_ayar", 5)
	dogru(not Oyun.ayarlar.has("olmayan_ayar"), "tanınmayan ayar değiştirilemez")
	Oyun.ayar_degistir("saat_hizi", -1.0)
	esit(float(Oyun.ayar("saat_hizi")), 0.4, "eksi saat hızı kabul edilmez")
	Oyun.ayar_degistir("saat_hizi", 1.0)


## Hikâyedeki her bayrağa sırayla her türden beklenmedik değer verir; hikâyenin bütün okuyucuları
## (ziyaretler, gazete, akşam, gece, sonlar, genelge defteri) hata vermeden çalışmalıdır.
func _bayrak_supurmesi() -> void:
	var adlar := {}
	for z: Dictionary in Hikaye.karakterler().get("ziyaretler", []):
		for ad: String in z.get("kosul", {}):
			adlar[ad] = true
		for an: String in z.get("etki", {}):
			if typeof(z.etki[an]) == TYPE_DICTIONARY:
				for ad: String in (z.etki[an] as Dictionary).get("bayrak", {}):
					adlar[ad] = true
	for bolum: String in ["gazete", "aksam", "gece"]:
		for kayit: Dictionary in Hikaye.veri().get(bolum, []):
			for ad: String in kayit.get("kosul", {}):
				adlar[ad] = true
	for y: Dictionary in (Hikaye.veri().get("son", {}) as Dictionary).get("yan", []):
		for ad: String in y.get("kosul", {}):
			adlar[ad] = true
	for ad: String in ["savci", "kasap", "naciye", "mektup", "bomba"]:
		adlar[ad] = true
	var eski: Dictionary = Oyun.bayraklar
	var kurulan := 0
	var bos_gazete := 0
	for deger: Variant in [true, false, 7, -3, 0.5, "", "bilinmeyen", "yakalandi", "kayirildi", 1]:
		var bayraklar := {}
		for ad: String in adlar:
			bayraklar[ad] = deger
		Oyun.bayraklar = bayraklar
		for gun_no in range(1, Oyun.TOPLAM_GUN + 1):
			var g := _kipli_gun(gun_no, 0)
			var rng := RandomNumberGenerator.new()
			rng.seed = gun_no
			kurulan += Hikaye.ozel_vatandaslar(gun_no, g, bayraklar, rng).size()
			if str(Hikaye.gazete(gun_no, bayraklar).get("manset", "")) == "" or Hikaye.aksam(gun_no, bayraklar) == "":
				bos_gazete += 1
			Hikaye.gece(gun_no, bayraklar)
			var kitap := KuralKitabi.new()
			add_child(kitap)
			kitap.yukle(g)
			kitap.free()
		Hikaye.savci_akibeti(bayraklar)
		for son: Dictionary in [{"tur": "terfi", "neden": "basari"}, {"tur": "olagan", "neden": "yerinde"},
				{"tur": "surgun", "neden": "ihtar"}, {"tur": "surgun", "neden": "suphe"}, {"tur": "kotu", "neden": "iflas"},
				{"tur": "kotu", "neden": "aile", "kritik": "can"}, {"tur": "kotu", "neden": "tahliye"}, {"tur": "kotu", "neden": ""}, {}]:
			if str(Hikaye.son(son, bayraklar).get("manset", "")) == "":
				bos_gazete += 1
	Oyun.bayraklar = eski
	dogru(kurulan > 0, "%d bayrak × 10 beklenmedik değerle hikâyenin bütün okuyucuları çalışıyor (%d ziyaret kuruldu)" % [adlar.size(), kurulan])
	esit(bos_gazete, 0, "  hiçbir bayrak değeri gazeteyi, akşam metnini ya da son sayfasını boş bırakmıyor")


# =====================================================================================================
# 3. Üretici × görev şekli × tohum
# =====================================================================================================

func _kipli_gun(gun_no: int, fark: int) -> Dictionary:
	var g: Dictionary = Veri.gun(gun_no).duplicate(true)
	g["zorluk"] = clampi(int(g.get("zorluk", 1)) + fark, 1, 3)
	return g


func _bolum_uretici() -> void:
	print("== Üretici ile doğrulayıcı (üç görev şekli × beş tohum × yedi gün × 60 vatandaş) ==")
	var kunye := Portreler.kunye()
	var toplam := 0
	var tutarsiz := 0
	var bicimsiz := 0
	var ornek := ""
	for fark: int in [-1, 0, 1]:
		for tohum: int in [1984, 7, 20261112, 99, 31337]:
			for gun_no in range(1, Oyun.TOPLAM_GUN + 1):
				var g := _kipli_gun(gun_no, fark)
				var rng := RandomNumberGenerator.new()
				rng.seed = hash([tohum, gun_no, fark])
				var kullanilan: Array = []
				for i in 60:
					var v := VatandasUretici.uret(g, rng, kullanilan)
					toplam += 1
					var bulunan: Array = (Dogrulayici.kontrol(v, g).gerekceler as Array).duplicate()
					var uretilen: Array = (v.uretilen as Array).duplicate()
					bulunan.sort()
					uretilen.sort()
					if bulunan != uretilen:
						tutarsiz += 1
						if ornek == "":
							ornek = "gün %d, fark %d, tohum %d: üretilen %s ≠ bulunan %s" % [gun_no, fark, tohum, str(uretilen), str(bulunan)]
					if not _vatandas_bicimli(v, g, kunye):
						bicimsiz += 1
	esit(tutarsiz, 0, "%d vatandaşın hepsinde üretilen kusur = bulunan kusur %s" % [toplam, ornek])
	esit(bicimsiz, 0, "üretilen her vatandaşın yüzü, belgeleri, konuşması ve çantası eksiksiz")
	# aynı tohum aynı kuyruğu verir (kayıttan devam edince gün değişmesin)
	var g1 := _kipli_gun(5, 0)
	var a := _kuyruk_ozeti(g1, 424242)
	var b := _kuyruk_ozeti(g1, 424242)
	esit(a, b, "aynı tohumla aynı gün birebir aynı kuyruğu üretir")
	dogru(a != _kuyruk_ozeti(g1, 424243), "başka tohum başka kuyruk üretir")


func _kuyruk_ozeti(g: Dictionary, tohum: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = tohum
	var kullanilan: Array = []
	var hepsi: Array = []
	for i in 12:
		hepsi.append(VatandasUretici.uret(g, rng, kullanilan))
	return JSON.stringify(hepsi).hash()


func _vatandas_bicimli(v: Dictionary, g: Dictionary, kunye: Dictionary) -> bool:
	if not kunye.has(str(v.get("portre", ""))) or (v.get("belgeler", []) as Array).is_empty():
		return false
	if not (g.get("islemler", []) as Array).has(str(v.get("islem", ""))):
		return false
	var konusma: Dictionary = v.get("konusma", {})
	for an: String in ["giris", "onay", "eksik", "havale"]:
		if str(konusma.get(an, "")).strip_edges() == "":
			return false
	for b: Dictionary in v.belgeler:
		if not BELGE_TURLERI.has(str(b.get("tur", ""))) or (b.get("alanlar", {}) as Dictionary).is_empty():
			return false
		for alan: String in b.alanlar:
			var d: Variant = b.alanlar[alan]
			if typeof(d) == TYPE_STRING and str(d).strip_edges() == "" and not alan.ends_with("_turu"):
				return false
	if str(Dogrulayici.belge_sozlugu(v).get("nufus_cuzdani", {}).get("foto", "x")) == "":
		return false
	if v.has("canta"):
		if Canta.tur_bilgisi(str(v.canta.get("tur", ""))).is_empty() or (v.canta.get("esyalar", []) as Array).is_empty():
			return false
		for e: Dictionary in v.canta.esyalar:
			if Canta.esya(str(e.get("ad", ""))).is_empty():
				return false
	return true


# =====================================================================================================
# 4. İnceleme modu ile kural motorunun tutarlılığı
# =====================================================================================================

## Bir vatandaş için inceleme modunda tıklanabilecek bütün hedeflerin özetleri.
func _hedefler(v: Dictionary, g: Dictionary) -> Array[Dictionary]:
	var liste: Array[Dictionary] = []
	for b: Dictionary in v.get("belgeler", []):
		var belge := Belge.olustur(b)
		if belge == null:
			continue
		for h: Hedef in belge.alanlar.values():
			liste.append(h.ozet())
		belge.free()
	liste.append({"tip": "yuz", "anahtar": "", "deger": null, "belge": "", "kural": {}, "etiket": ""})
	liste.append({"tip": "takvim", "anahtar": "", "deger": str(g.get("tarih", "")), "belge": "", "kural": {}, "etiket": ""})
	liste.append_array(_arayuz_hedefleri(g))
	return liste


## Genelge defterinin bütün sayfalarındaki ve bilgi defterinin bütün yapraklarındaki GERÇEK hedefler
## (arayüz neyi tıklatıyorsa o): elle tarif edilmez, düğümlerin kendisinden okunur. Gün başına bir kez kurulur.
func _arayuz_hedefleri(g: Dictionary) -> Array[Dictionary]:
	var anahtar := JSON.stringify(g).hash()
	if _hedef_onbellegi.has(anahtar):
		return _hedef_onbellegi[anahtar]
	var liste: Array[Dictionary] = []
	var kitap := KuralKitabi.new()
	add_child(kitap)
	kitap.yukle(g)
	for h: Hedef in kitap.hedefler:
		liste.append(h.ozet())
	kitap.queue_free()
	if not Veri.kural(g, "sahtecilik").is_empty():
		var tasiyici := Node2D.new()
		add_child(tasiyici)
		var defter := Belge.olustur({"tur": "bilgi_defteri", "gun": g})
		defter.masaya_koy(tasiyici)
		defter.buyut(true)
		for no in (defter.yapraklar() as Array).size():
			defter.yapraga_gec(no)
			for h: Hedef in defter.alanlar.values():
				liste.append(h.ozet())
		tasiyici.queue_free()
	_hedef_onbellegi[anahtar] = liste
	_hedef_sayisi = maxi(_hedef_sayisi, liste.size())
	return liste


## Vatandaşın bütün hedef çiftlerini karşılaştırır; tutarsızlık varsa açıklamasını döndürür (yoksa "").
func _ipucu_tutarli(v: Dictionary, g: Dictionary) -> String:
	var sonuc := Dogrulayici.kontrol(v, g)
	var gerekceler: Array = sonuc.gerekceler
	var hedefler := _hedefler(v, g)
	var bulunan := {}
	for i in hedefler.size():
		for j in hedefler.size():
			if i == j:
				continue
			var a := hedefler[i]
			var b := hedefler[j]
			var r: Dictionary = Dogrulayici.karsilastir(a, b, v, g)
			var durum := str(r.get("durum", ""))
			if not ["uyusmaz", "uyumlu", "ilgisiz"].has(durum) or typeof(r.get("mesaj")) != TYPE_STRING:
				return "biçimsiz sonuç: %s ↔ %s → %s" % [_hedef_adi(a), _hedef_adi(b), str(r)]
			if i < j and str(Dogrulayici.karsilastir(b, a, v, g).get("durum", "")) != durum:
				return "sıra değişince sonuç değişiyor: %s ↔ %s" % [_hedef_adi(a), _hedef_adi(b)]
			if durum == "uyusmaz":
				var gerekce := str(r.get("gerekce", ""))
				if not gerekceler.has(gerekce):
					return "yanlış alarm: %s ↔ %s '%s' diyor (%s); gerçek kusurlar %s" % [_hedef_adi(a), _hedef_adi(b), gerekce, str(r.mesaj), str(gerekceler)]
				bulunan[gerekce] = true
	for h: Dictionary in sonuc.hatalar:
		if str(h.gerekce) == "belge_eksik":
			continue        # eksik belge karşılaştırmayla değil, masaya bakarak görülür
		if not bulunan.has(str(h.gerekce)):
			return "kusur incelemeyle bulunamıyor: %s (%s)" % [str(h.gerekce), str(h.aciklama)]
	return ""


func _hedef_adi(h: Dictionary) -> String:
	return "%s/%s%s" % [str(h.tip), str(h.belge) + "." if str(h.belge) != "" else "", str(h.anahtar)]


func _bolum_ipucu() -> void:
	print("== İnceleme modu ile kural motoru ==")
	var toplam := 0
	var sorunlu := 0
	var ornekler: Array[String] = []
	for fark: int in [-1, 0, 1]:
		for gun_no in range(1, Oyun.TOPLAM_GUN + 1):
			var g := _kipli_gun(gun_no, fark)
			var rng := RandomNumberGenerator.new()
			rng.seed = hash([2718, gun_no, fark])
			var kullanilan: Array = []
			for i in 14:
				# üçte biri kusursuz, gerisi bir ya da iki kusurlu
				var v := VatandasUretici.uret(g, rng, kullanilan, i % 3)
				toplam += 1
				var sorun := _ipucu_tutarli(v, g)
				if sorun != "":
					sorunlu += 1
					if ornekler.size() < 8:
						ornekler.append("gün %d (fark %d): %s" % [gun_no, fark, sorun])
			await get_tree().process_frame
	for o in ornekler:
		print("    ! ", o)
	esit(sorunlu, 0, "%d rastgele vatandaşta her karşılaştırma kural motoruyla tutarlı" % toplam)
	dogru(_hedef_sayisi >= 30, "  genelge ve bilgi defterinden okunan hedef sayısı yeterli (en çok %d)" % _hedef_sayisi)
	# hikâye ziyaretleri
	var hikaye_sorunu := 0
	for z: Dictionary in Hikaye.karakterler().get("ziyaretler", []):
		if bool(z.get("belgesiz", false)):
			continue
		var g := _kipli_gun(int(z.gun), 0)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(str(z.kod))
		var sorun := _ipucu_tutarli(Hikaye.vatandas_kur(z, g, rng), g)
		if sorun != "":
			hikaye_sorunu += 1
			print("    ! ziyaret %s: %s" % [str(z.kod), sorun])
	esit(hikaye_sorunu, 0, "hikâye ziyaretlerinin her karşılaştırması tutarlı")


# =====================================================================================================
# 5. Akış yarışları
# =====================================================================================================

func _ilk_belgeyi_bekle(masa: Node) -> Belge:
	await kosulu_bekle(func() -> bool: return masa.belgeler.size() >= 1 and not masa._mesgul, 14.0)
	return masa.belgeler[0] if masa.belgeler.size() > 0 else null


func _evrakli_gun(gun_no: int) -> Node:
	var masa: Node = await _gune_git(gun_no)
	# kuyruğun başına evraklı, çantasız, sıradan bir vatandaş gelsin
	for i in masa.kuyruk.size():
		var v: Dictionary = masa.kuyruk[i]
		if str(v.get("tur", "")) == "rastgele" and not v.has("canta"):
			masa.kuyruk.remove_at(i)
			masa.kuyruk.insert(0, v)
			break
	bas("GiseyiAc")
	return masa


func _bolum_akis() -> void:
	print("== Akış yarışları ==")
	# 1) karar verildi, vatandaş uğurlanırken mesai bitti: işlem bir kez sayılır, yarıda kalmış sayılmaz
	var masa: Node = await _evrakli_gun(1)
	var b: Belge = await _ilk_belgeyi_bekle(masa)
	dogru(b != null, "vatandaşın evrakı masada")
	masa.karar_ver("onay", b, b.get_global_transform() * (b.size * 0.5))
	masa.dakika = masa.MESAI_SONU - 0.01
	dogru(await sahneyi_bekle("GunSonu", 14.0), "mesai kapanır, gün sonu gelir")
	esit(int(Oyun.gun_ozeti.get("islenen", -1)), 1, "  işlem bir kez sayıldı")
	esit(int(Oyun.gun_ozeti.get("yarida", -1)), 0, "  kararı verilmiş vatandaş yarıda kalmış sayılmadı")

	# 2) gerekçe penceresi açıkken mesai bitti: pencere kapanır, vatandaş yarıda kalır, oyun kilitlenmez
	masa = await _evrakli_gun(1)
	b = await _ilk_belgeyi_bekle(masa)
	masa._gerekce_sor(b, Vector2(500, 400))
	await kare(2)
	dogru(masa.find_child("GerekcePenceresi", true, false) != null, "gerekçe penceresi açık")
	masa.dakika = masa.MESAI_SONU - 0.01
	await kare(6)
	dogru(masa.find_child("GerekcePenceresi", true, false) == null, "  mesai bitince pencere kapanır")
	dogru(await sahneyi_bekle("GunSonu", 14.0), "  gün sonu gelir")
	esit([int(Oyun.gun_ozeti.get("islenen", -1)), int(Oyun.gun_ozeti.get("yarida", -1))], [0, 1], "  işlem sayılmadı, vatandaş yarıda kaldı")

	# 3) aynı karede iki karar, hakkı bitmiş havale, bilgi defterine mühür
	masa = await _evrakli_gun(4)
	b = await _ilk_belgeyi_bekle(masa)
	var yer: Vector2 = b.get_global_transform() * (b.size * 0.5)
	dogru(is_instance_valid(masa.defter), "4. günde bilgi defteri masada")
	masa.karar_ver("onay", masa.defter, yer)
	esit(int(masa.ozet.islenen), 0, "bilgi defterine vurulan mühür karar sayılmaz")
	masa.karar_ver("uydurma", b, yer)
	esit(int(masa.ozet.islenen), 0, "tanınmayan karar yok sayılır")
	masa.havale_kalan = 0
	masa.karar_ver("havale", b, yer)
	esit([int(masa.ozet.islenen), int(masa.havale_kalan)], [0, 0], "hakkı bitmiş havale verilemez")
	masa.havale_kalan = 2
	masa.karar_ver("onay", b, yer)
	masa.karar_ver("onay", b, yer)
	masa.karar_ver("havale", b, yer)
	esit([int(masa.ozet.islenen), int(masa.havale_kalan)], [1, 2], "aynı vatandaşa art arda verilen kararlardan yalnız ilki sayılır")
	masa.mesaiyi_bitir()
	masa.karar_ver("onay", b, yer)
	dogru(await sahneyi_bekle("GunSonu", 14.0), "gün sonu gelir")
	esit(int(Oyun.gun_ozeti.get("islenen", -1)), 1, "  mesai kapandıktan sonra verilen karar sayılmaz")

	# 3b) mesai sonuna yakın boş alarm saati geri almaz; röntgen açıkken mesai biterse oyun kilitlenmez
	masa = await _gune_git(5)
	var temiz := -1
	for i in masa.kuyruk.size():
		var kv: Dictionary = masa.kuyruk[i]
		if str(kv.get("tur", "")) == "rastgele" and kv.has("canta") and Canta.yasaklar(kv.canta, masa.gun).is_empty():
			temiz = i
			break
	if temiz < 0:
		# bu tohumda temiz çantalı vatandaş çıkmadıysa bir tane kur
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		var yeni := VatandasUretici.uret(masa.gun, rng, [], 0)
		yeni["canta"] = Canta.yerlestir("torba", ["ekmek", "kazak"], rng)
		masa.kuyruk.insert(0, yeni)
	else:
		var kv2: Dictionary = masa.kuyruk[temiz]
		masa.kuyruk.remove_at(temiz)
		masa.kuyruk.insert(0, kv2)
	bas("GiseyiAc")
	dogru(await kosulu_bekle(func() -> bool: return masa.canta_asamasi == "bekliyor", 10.0), "çantalı vatandaş eşikte bekliyor")
	masa._cantayi_tara()
	await bekle(0.6)
	masa._saat_durdu = true
	masa.dakika = masa.MESAI_SONU - 0.4
	var saat_once: float = masa.dakika
	masa._canta_karari("alarm")
	dogru(masa.dakika >= saat_once, "mesai sonuna yakın boş alarm saati geri almaz")
	esit(int(masa.bos_alarm), 1, "  boş alarm sayıldı")
	masa._saat_durdu = false
	dogru(await sahneyi_bekle("GunSonu", 16.0), "  evrak beklenirken mesai bitince gün sonu gelir")

	# 3c) çift tetikleme: aynı karede iki kez gelen sinyal işlemi iki kez yaptırmaz
	masa = await _evrakli_gun(2)
	b = await _ilk_belgeyi_bekle(masa)
	masa._gerekce_sor(b, Vector2(500, 400))
	await kare(2)
	var pencere := masa.find_child("GerekcePenceresi", true, false)
	pencere._sec("sure")
	pencere._sec("muhur")
	pencere._vazgec()
	await kare(2)
	esit(int(masa.ozet.islenen), 1, "gerekçe penceresi aynı karede tek sonuç bildirir")
	dogru(not masa.araclar["onay"].etkin and not masa.araclar["eksik"].etkin, "  vatandaş uğurlanırken karar araçları kapalı")
	masa.karar_ver("onay", b, Vector2(500, 400))
	esit(int(masa.ozet.islenen), 1, "  uğurlanan vatandaşa ikinci karar verilemez")
	masa.dakika = masa.MESAI_SONU - 0.01
	dogru(await sahneyi_bekle("GunSonu", 16.0), "gün sonu gelir")
	Oyun.para = 1000
	Oyun.aile["ikram"] = true           # komşu yemek getirdi: yiyecek bu akşam bedelsiz
	await bekle(0.4)
	sahne()._devam()
	sahne()._devam()
	dogru(await sahneyi_bekle("Aile", 8.0), "puantajdan eve iki kez basılsa da tek geçiş olur")
	var aile := sahne()
	dogru(not aile.sec("yemek", false), "bedelsiz kalemin işareti kaldırılamaz")
	aile.sec("komur", true)
	var para_once: int = Oyun.para
	aile._lambayi_sondur()
	aile._lambayi_sondur()
	esit(Oyun.para, para_once - AileDurumu.KOMUR, "ışık iki kez söndürülse de masraf bir kez düşer")
	dogru(not aile.sec("kira", true), "  ışık söndükten sonra masraf seçilemez")
	dogru(not "
".join(PackedStringArray(aile.gece.get("satirlar", []))).contains("aç yattı"), "  komşunun getirdiği yemek işaretlenmeden de sayılır")
	var gun_once := Oyun.gun
	aile._sabah()
	aile._sabah()
	dogru(await sahneyi_bekle("Masa", 8.0), "sabah olur")
	esit(Oyun.gun, gun_once + 1, "  sabaha iki kez basılsa da gün bir kez ilerler")

	# 4) sahne geçişi sürerken gelen ikinci istek geçişi bozmaz
	await sahneye_git("menu")
	await sahneyi_bekle("AnaMenu")
	Oyun.sahneye_gec("masa")
	Oyun.sahneye_gec("menu")
	Oyun.sahneye_gec("olmayan_sahne")
	dogru(await sahneyi_bekle("Masa", 6.0), "üst üste gelen geçiş isteklerinden ilki tamamlanır")
	dogru(not Oyun.geciste_mi(), "  geçiş kilidi açılır")
	# 5) mola: açılır, kapanır, oyun duraklar ve sürer
	await bekle(0.4)
	bas("GiseyiAc")
	masa = sahne()
	await kosulu_bekle(func() -> bool: return masa.mesai_acik, 4.0)
	var d0: float = masa.dakika
	Oyun.mola_ver()
	Oyun.mola_ver()
	await bekle(0.5)
	dogru(get_tree().paused and absf(masa.dakika - d0) < 0.8, "molada mesai saati durur")
	Oyun.molayi_bitir()
	Oyun.molayi_bitir()
	await bekle(0.5)
	dogru(not get_tree().paused and masa.dakika > d0, "mola bitince saat işler")
	# 6) olmayan sesler ve boş çalma listeleri
	Ses.cal("")
	Ses.ortam("olmayan_ortam")
	Ses.muzik([])
	Ses.muzik(["olmayan_parca"])
	esit(Ses.calan_parca(), "", "olmayan parça çalınmaz, hata vermez")
	Ses.muzik(["olmayan_parca", "ney"])
	esit(Ses.calan_parca(), "ney", "listede bulunmayan parça atlanır")
	Ses.muzigi_kes(0.05)
	await sahneye_git("menu")
	await sahneyi_bekle("AnaMenu")


# =====================================================================================================
# 6. Maymun testi
# =====================================================================================================

func _tus(kod: Key) -> void:
	for basili: bool in [true, false]:
		var e := InputEventKey.new()
		e.keycode = kod
		e.physical_keycode = kod
		e.pressed = basili
		get_viewport().push_input(e, true)


func _rastgele_nokta(rng: RandomNumberGenerator) -> Vector2:
	return Vector2(rng.randf_range(4.0, 1276.0), rng.randf_range(4.0, 716.0))


## Sahnede (ve Oyun'un üst katmanında) o an görünen, basılabilir düğmeler.
func _dugmeler() -> Array[Button]:
	var sonuc: Array[Button] = []
	var kokler: Array[Node] = [Oyun]
	if sahne() != null:
		kokler.append(sahne())
	for kok in kokler:
		for d: Node in kok.find_children("*", "Button", true, false):
			var dugme_ := d as Button
			if dugme_.is_visible_in_tree() and not dugme_.disabled:
				sonuc.append(dugme_)
	return sonuc


## Rastgele bir girdi: tıklama, çift tıklama, sürükleme, tuş, düğme ya da karar aracı.
func _rastgele_girdi(rng: RandomNumberGenerator) -> void:
	var zar := rng.randf()
	var s := sahne()
	if zar < 0.22:
		var p := _rastgele_nokta(rng)
		fare_bas(p, rng.randf() < 0.3)
		await kare(1)
		fare_birak(p)
	elif zar < 0.40:
		var p1 := _rastgele_nokta(rng)
		var p2 := _rastgele_nokta(rng)
		fare_bas(p1)
		await kare(1)
		for i in 3:
			fare_tasi(p1.lerp(p2, (i + 1) / 3.0))
			await kare(1)
		fare_birak(p2)
	elif zar < 0.52:
		_tus([KEY_SPACE, KEY_ENTER, KEY_ESCAPE, KEY_SPACE, KEY_TAB, KEY_A, KEY_F1][rng.randi() % 7])
	elif zar < 0.80:
		var dugmeler := _dugmeler()
		if not dugmeler.is_empty():
			var d := dugmeler[rng.randi() % dugmeler.size()]
			# ana menüye dönüş ve çıkış düğmeleri oturumu bitirir: onlara seyrek basılır
			if not (str(d.name) in ["MolaMenu", "Cikis", "AnaMenu"]) or rng.randf() < 0.02:
				if str(d.name) != "Cikis":
					# kimi zaman aynı karede iki üç kez: çift tıklama, takılan fare düğmesi
					for i in (1 if rng.randf() < 0.7 else rng.randi_range(2, 3)):
						if is_instance_valid(d):
							d.pressed.emit()
					# kimi zaman aynı karede başka bir düğme de: iki ayrı işlem üst üste gelsin
					if rng.randf() < 0.15:
						var diger := dugmeler[rng.randi() % dugmeler.size()]
						if is_instance_valid(diger) and not (str(diger.name) in ["MolaMenu", "Cikis", "AnaMenu", "AyarSifirla"]):
							diger.pressed.emit()
	elif s != null and s.name == "Masa":
		# bir karar aracını masadaki bir belgeye (ya da rastgele bir yere) sürükle
		var araclar: Array = s.araclar.values()
		var arac: Control = araclar[rng.randi() % araclar.size()]
		var bas_yeri: Vector2 = arac.get_global_transform() * (arac.size / 2.0)
		var hedef := _rastgele_nokta(rng)
		if s.belgeler.size() > 0 and rng.randf() < 0.85:
			var b: Belge = s.belgeler[rng.randi() % s.belgeler.size()]
			if is_instance_valid(b):
				hedef = b.get_global_transform() * (b.size * Vector2(rng.randf_range(0.2, 0.8), rng.randf_range(0.2, 0.8)))
		fare_bas(bas_yeri)
		await kare(2)
		fare_tasi(hedef)
		await kare(2)
		fare_birak(hedef)
	else:
		var p := _rastgele_nokta(rng)
		fare_bas(p)
		fare_birak(p)


## Her girdiden sonra bakılan değişmezler; bozulan olursa açıklaması döner.
func _degismezler() -> String:
	if absi(Oyun.para) > Oyun.PARA_SINIRI * 2 or Oyun.ihtar < 0 or Oyun.suphe < 0 or Oyun.gun < 1 or Oyun.gun > Oyun.TOPLAM_GUN:
		return "oyun durumu bozuk: para %d, ihtar %d, şüphe %d, gün %d" % [Oyun.para, Oyun.ihtar, Oyun.suphe, Oyun.gun]
	for u: String in AileDurumu.UYELER:
		var sag := int((Oyun.aile.get("saglik", {}) as Dictionary).get(u, -1))
		if sag < 0 or sag > 3:
			return "sağlık aralık dışı: %s = %d" % [u, sag]
	var s := sahne()
	if s == null or s.name != "Masa":
		return ""
	var o: Dictionary = s.ozet
	if int(s.havale_kalan) < 0:
		return "havale hakkı eksiye düştü"
	if int(o.islenen) != (s.kararlar as Array).size():
		return "işlenen sayısı (%d) karar dökümüyle (%d) tutmuyor" % [int(o.islenen), (s.kararlar as Array).size()]
	if int(o.dogru) + int(o.yanlis) + int(o.yarim) > int(o.islenen):
		return "doğru + yanlış + yarım, işlenenden fazla"
	if int(o.kazanc) < 0 or int(s.gunluk_ihtar) < 0:
		return "günlük kazanç ya da ihtar eksi"
	if float(s.dakika) < float(s.MESAI_BASI) - 0.01 or float(s.dakika) > float(s.MESAI_SONU) + 0.01:
		return "saat mesai dışına çıktı: %.1f" % float(s.dakika)
	for b: Variant in s.belgeler:
		if not is_instance_valid(b):
			return "masadaki belge listesinde silinmiş belge var"
	return ""


func _bolum_maymun() -> void:
	print("== Maymun testi: rastgele girdilerle oynanış ==")
	var tur_sayisi := 9
	var eski_hiz: float = float(Oyun.ayar("saat_hizi"))
	Oyun.ayarlar["saat_hizi"] = 0.4          # en hızlı mesai saati: gün ~3 dakikada biter (hızlandırılınca ~25 sn)
	Engine.time_scale = 8.0
	var girdi := 0
	var sorunlar: Array[String] = []
	var kilit := 0
	var gunler := [1, 2, 3, 4, 5, 6, 7, 6, 5]
	var kipler := ["kolay", "orta", "zor"]
	for tur in tur_sayisi:
		var rng := RandomNumberGenerator.new()
		rng.seed = 9000 + tur
		await sahneye_git("menu")
		await sahneyi_bekle("AnaMenu")
		Oyun.yeni_oyun(kipler[tur % 3])
		Oyun.gun = gunler[tur % gunler.size()]
		Oyun.para = 3000        # gün sonunda ev ekranına kadar gidilebilsin
		await sahneye_git("masa")
		await sahneyi_bekle("Masa")
		var gorulen := {"Masa": true}
		var son_gun := Oyun.gun
		var basla := Time.get_ticks_msec()
		var son_degisim := Time.get_ticks_msec()
		var son_sahne := "Masa"
		# bir oturum: mesai, gün sonu, ev ve (varsa) ertesi sabah; gerçek sürede en çok 70 sn
		while Time.get_ticks_msec() - basla < 70000:
			if get_tree().paused and rng.randf() < 0.25:
				Oyun.molayi_bitir()
			await _rastgele_girdi(rng)
			girdi += 1
			await kare(rng.randi_range(1, 3))
			var sorun := _degismezler()
			if Oyun.gun > son_gun + 1:
				sorun = "gün atladı: %d → %d" % [son_gun, Oyun.gun]
			son_gun = Oyun.gun
			if sorun != "" and not sorunlar.has(sorun):
				sorunlar.append("tur %d: %s" % [tur, sorun])
			var ad := str(sahne().name) if sahne() != null else ""
			if ad != son_sahne:
				son_sahne = ad
				son_degisim = Time.get_ticks_msec()
				gorulen[ad] = true
			# genelge açık kaldıysa gişeyi açtır: mesai saati işlemeye başlasın
			if ad == "Masa" and not sahne().mesai_acik and not sahne().gun_bitti and rng.randf() < 0.1 and dugme("GiseyiAc") != null:
				bas("GiseyiAc")
			if ad == "Son" or ad == "AnaMenu":
				break
			if gorulen.has("Aile") and ad == "Masa" and gorulen.size() >= 3 and Time.get_ticks_msec() - son_degisim > 3000:
				break       # ertesi sabaha varıldı
		get_tree().paused = false
		Oyun.molayi_bitir()
		# mesai sahnesinden hiç çıkılamadıysa oyun kilitlenmiş demektir (saat her durumda günü bitirmeli)
		if gorulen.size() == 1 and son_sahne == "Masa":
			var s := sahne()
			if not s.mesai_acik and not s.gun_bitti:
				pass        # gişe hiç açılmadı: rastgele girdiler "Gişeyi Aç"a denk gelmedi
			else:
				kilit += 1
				sorunlar.append("tur %d: mesai sahnesinden çıkılamadı (saat %.0f, gün bitti: %s)" % [tur, float(s.dakika), str(s.gun_bitti)])
		print("  tur %d: gün %d, %s, görülen sahneler %s" % [tur, gunler[tur % gunler.size()], kipler[tur % 3], str(gorulen.keys())])
	Engine.time_scale = 1.0
	Oyun.ayarlar["saat_hizi"] = eski_hiz
	for s in sorunlar:
		print("    ! ", s)
	esit(sorunlar.size(), 0, "%d rastgele girdi boyunca oyun durumu tutarlı kaldı" % girdi)
	esit(kilit, 0, "hiçbir turda oyun kilitlenmedi")
	await sahneye_git("menu")
	await sahneyi_bekle("AnaMenu")


# =====================================================================================================
# 7. Yerleşim: yazılar ayrılan yere sığıyor mu
# =====================================================================================================

## Belgedeki tek satırlık yazıların alanından taşanlarını döndürür: ["tür.metin (genişlik > alan)"].
func _tasan_yazilar(belge: Belge) -> Array[String]:
	var tasan: Array[String] = []
	for o: Dictionary in belge._ogeler:
		var l := o.d as Label
		if l == null or l.autowrap_mode != TextServer.AUTOWRAP_OFF or float(o.p) <= 0.0 or l.text == "":
			continue
		var font := l.get_theme_font("font")
		var en := font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(float(o.p))).x
		var alan: Rect2 = o.r
		_en_dolu = maxf(_en_dolu, en / maxf(1.0, alan.size.x))
		if en > alan.size.x + 1.5:
			tasan.append("%s: '%s' (%.0f > %.0f)" % [belge.tur, l.text, en, alan.size.x])
	return tasan


func _bolum_yerlesim() -> void:
	print("== Yerleşim: yazılar yerine sığıyor mu ==")
	# her yüzün kimliğiyle ve hikâye kişileriyle kurulan belgeler
	var tasanlar := {}
	var belge_sayisi := 0
	for fark: int in [0]:
		for gun_no: int in [3, 6, 7]:
			var g := _kipli_gun(gun_no, fark)
			var rng := RandomNumberGenerator.new()
			rng.seed = hash([515, gun_no])
			var kullanilan: Array = []
			for i in 260:
				if kullanilan.size() > 80:
					kullanilan.clear()
				var v := VatandasUretici.uret(g, rng, kullanilan, i % 3)
				for b: Dictionary in v.belgeler:
					var belge := Belge.olustur(b)
					belge_sayisi += 1
					for t in _tasan_yazilar(belge):
						tasanlar[t] = true
					belge.free()
	for z: Dictionary in Hikaye.karakterler().get("ziyaretler", []):
		if bool(z.get("belgesiz", false)):
			continue
		var g := _kipli_gun(int(z.gun), 0)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(str(z.kod))
		for b: Dictionary in Hikaye.vatandas_kur(z, g, rng).belgeler:
			var belge := Belge.olustur(b)
			belge_sayisi += 1
			for t in _tasan_yazilar(belge):
				tasanlar[t] = true
			belge.free()
	var liste: Array = tasanlar.keys()
	liste.sort()
	for i in mini(liste.size(), 25):
		print("    ! ", liste[i])
	esit(liste.size(), 0, "%d belgede hiçbir yazı alanından taşmıyor" % belge_sayisi)
	# ölçümün kendisi anlamlı mı: en uzun yazı alanının en az yarısını dolduruyor olmalı
	dogru(_en_dolu > 0.5 and _en_dolu <= 1.03, "  en dolu alan yüzde %d dolu (ölçüm çalışıyor)" % roundi(_en_dolu * 100.0))

	# (Sabah genelgelerinin kâğıda sığması gözle denetlenir: bash tools/cek.sh genelge. Başsız kipte satır
	# yüksekliği ölçümü güvenilir değildir.)

	# en uzun konuşmalar balona sığıyor (balon yazıyı küçültür; en küçük puntoda da taşmamalı)
	var balon := KonusmaBalonu.new()
	add_child(balon)
	await kare(1)
	var uzunlar := {}
	for z: Dictionary in Hikaye.karakterler().get("ziyaretler", []):
		for s: Variant in z.get("satirlar", []):
			uzunlar[str(s)] = true
		for s: Variant in (z.get("konusma", {}) as Dictionary).values():
			uzunlar[str(s)] = true
	var sigmayan := 0
	for metin: String in uzunlar:
		var genislik := balon.size.x - 2.0 * balon.IC_BOSLUK.x
		var boyut := Stil.daktilo().get_multiline_string_size(metin, HORIZONTAL_ALIGNMENT_LEFT, genislik, 11)
		if boyut.y + 2.0 * balon.IC_BOSLUK.y + 6.0 + 11.0 > balon.size.y:
			sigmayan += 1
			print("    ! balona sığmıyor (%d harf): %s" % [metin.length(), metin.left(60)])
	esit(sigmayan, 0, "hikâyedeki %d konuşmanın hepsi balona sığıyor" % uzunlar.size())
	balon.queue_free()

	# teleks pusulası uzun (birleşmiş) iletide de ekrana sığıyor
	var fis := IhtarFisi.new()
	fis.hazirla("Kusurlu evrakı onayladınız. İkametgâhtaki muhtar mührü sahteydi (dış halka tek). Camdan izliyordum: çift ihtar. "
		+ "Üstelik: Röntgenden geçirdiğiniz çantada toplu tabanca ile mermi vardı; şahıs binaya onunla girdi. Camdan izliyordum: çift ihtar.", 4, "ihtar")
	dogru(fis.size.y <= 520.0, "en uzun birleşik ihtar pusulası ekrana sığıyor (%d piksel)" % int(fis.size.y))
	fis.free()


# =====================================================================================================
# 8. Ayarlar: her ayar uygulanıyor mu, pencerenin her düğmesi doğru ayarı yazıyor mu
# =====================================================================================================

func _yol_db(ad: String) -> float:
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(ad))


func _bolum_ayarlar() -> void:
	print("== Ayarlar ==")
	Oyun.ayarlari_sifirla()
	esit(JSON.stringify(Oyun.ayarlar), JSON.stringify(Oyun.VARSAYILAN_AYARLAR), "varsayılana dönüş bütün ayarları sıfırlar")
	# ses veriyolları
	for yol: String in ["Efekt", "Ortam", "Muzik", "Radyo", "Konusma"]:
		dogru(AudioServer.get_bus_index(yol) >= 0, "ses veriyolu var: " + yol)
	esit(str(AudioServer.get_bus_send(AudioServer.get_bus_index("Radyo"))), "Muzik", "radyo, müzik veriyoluna akar")
	for cift: Array in [["ses_genel", "Master"], ["ses_efekt", "Efekt"], ["ses_konusma", "Konusma"], ["ses_muzik", "Muzik"], ["ses_ortam", "Ortam"]]:
		Oyun.ayar_degistir(str(cift[0]), 0.5)
		dogru(absf(_yol_db(str(cift[1])) - linear_to_db(0.5)) < 0.01, "%s ayarı %s veriyolunun düzeyini değiştirir" % [str(cift[0]), str(cift[1])])
		Oyun.ayar_degistir(str(cift[0]), 0.0)
		dogru(AudioServer.is_bus_mute(AudioServer.get_bus_index(str(cift[1]))), "  sıfırda veriyolu susar")
		Oyun.ayar_degistir(str(cift[0]), float(Oyun.VARSAYILAN_AYARLAR[cift[0]]))
	Oyun.ayar_degistir("muzik_acik", false)
	dogru(AudioServer.is_bus_mute(AudioServer.get_bus_index("Muzik")), "müzik kapatılınca müzik veriyolu susar")
	dogru(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Efekt")), "  efektler çalmaya devam eder")
	Oyun.ayar_degistir("muzik_acik", true)
	dogru(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Muzik")), "  yeniden açılınca çalar")
	Ses.cal("hece")
	Ses.cal("muhur")
	var konusma_var := false
	var efekt_var := false
	for c: AudioStreamPlayer in Ses._calicilar:
		if c.stream != null and str(c.bus) == "Konusma":
			konusma_var = true
		if c.stream != null and str(c.bus) == "Efekt":
			efekt_var = true
	dogru(konusma_var and efekt_var, "konuşma heceleri kendi veriyolundan, öbür efektler efekt veriyolundan çalar")
	# görüntü ve oyun
	Oyun.ayar_degistir("kare_siniri", 30)
	esit(Engine.max_fps, 30, "kare sınırı motora işlenir")
	Oyun.ayar_degistir("kare_siniri", 0)
	esit(Engine.max_fps, 0, "  sınır kaldırılır")
	for i in 3:
		Oyun.ayar_degistir("efekt_kalitesi", ["dusuk", "orta", "yuksek"][i])
		esit(Oyun.efekt_duzeyi(), i, "efekt kalitesi düzeyi: " + ["düşük", "orta", "yüksek"][i])
	esit(Oyun.fare_hedefi(Vector2(100, 100), Vector2(10, -4), 2.0, Rect2(0, 0, 1280, 720)), Vector2(110, 96), "fare hassasiyeti 2×: imleç hareketin bir katı daha ilerler")
	esit(Oyun.fare_hedefi(Vector2(100, 100), Vector2(10, -4), 0.5, Rect2(0, 0, 1280, 720)), Vector2(95, 102), "  0,5×: yarısı kadar geri çekilir")
	esit(Oyun.fare_hedefi(Vector2(1275, 5), Vector2(30, -30), 2.0, Rect2(0, 0, 1280, 720)), Vector2(1279, 0), "  imleç görünümün dışına taşmaz")
	# zayıf sistem ayarları: düşük çözünürlük, doku kalitesi, kendiliğinden kısılan kalite
	Oyun.ayar_degistir("dusuk_cozunurluk", true)
	esit(get_tree().root.content_scale_mode, Window.CONTENT_SCALE_MODE_VIEWPORT, "düşük çözünürlük: sahne 720p çizilip pencereye büyütülür")
	Oyun.ayar_degistir("dusuk_cozunurluk", false)
	esit(get_tree().root.content_scale_mode, Window.CONTENT_SCALE_MODE_CANVAS_ITEMS, "  kapatılınca pencere çözünürlüğünde çizilir")
	var tam := Gorsel.yukle("res://assets/img/masa_arkaplan.webp")
	Oyun.ayar_degistir("doku_kalitesi", "dusuk")
	var yarim := Gorsel.yukle("res://assets/img/masa_arkaplan.webp")
	esit(Vector2(yarim.get_size()), Vector2(tam.get_size()) / 2.0, "doku kalitesi düşükken arka plan yarı çözünürlükte yüklenir")
	dogru(Gorsel.yukle("res://assets/img/masa_arkaplan.webp") == yarim, "  küçültülmüş kopya yeniden kullanılır")
	dogru(Gorsel.yukle("res://assets/img/olmayan.webp") == null, "  olmayan görsel hata vermez")
	Oyun.ayarlari_sifirla()
	var adimlar := PackedStringArray()
	for i in 8:
		var adim := Oyun.kaliteyi_dusur()
		if adim == "":
			break
		adimlar.append(adim)
	esit(", ".join(adimlar), "efekt_kalitesi, efekt_kalitesi, dusuk_cozunurluk, doku_kalitesi, kare_siniri",
		"otomatik kalite kademe kademe kısar: önce süsler, sonra çözünürlük, doku, kare sınırı")
	esit([Oyun.ayar("efekt_kalitesi"), Oyun.ayar("dusuk_cozunurluk"), Oyun.ayar("doku_kalitesi"), Oyun.ayar("kare_siniri")],
		["dusuk", true, "dusuk", 30], "  en düşük kademede bütün kısıtlar açık")
	esit(Oyun.kaliteyi_dusur(), "", "  kısacak bir şey kalmayınca durur")
	Oyun.ayarlari_sifirla()
	Portreler.doku("v01")
	Portreler.vesikalik("v01")
	Portreler.agiz_dokusu("v01")
	Portreler.birak("v01")
	dogru(not Portreler._onbellek.has("v01") and not Portreler._onbellek.has("vesika/v01") and not Portreler._onbellek.has("agiz/v01"),
		"gişeden ayrılan vatandaşın görselleri bellekten bırakılır")
	# kar taneleri kaliteye göre azalır
	await sahneye_git("menu")
	await sahneyi_bekle("AnaMenu")
	var kar: Kar = null
	for c in sahne().find_children("*", "Control", true, false):
		if c is Kar:
			kar = c
	var sayilar: Array[int] = []
	for kalite: String in ["dusuk", "orta", "yuksek"]:
		Oyun.ayar_degistir("efekt_kalitesi", kalite)
		var toplam := 0
		for t: PackedFloat32Array in kar._taneler:
			@warning_ignore("integer_division")
			toplam += t.size() / 6
		sayilar.append(toplam)
	dogru(sayilar[0] < sayilar[1] and sayilar[1] < sayilar[2], "kar tanesi sayısı efekt kalitesiyle artar (%s)" % str(sayilar))
	# ayar penceresi: her yaprak açılır, her düğme kendi ayarını yazar
	bas("Ayarlar")
	await kare(3)
	var pencere := sahne().find_child("AyarlarPenceresi", true, false) as AyarlarPenceresi
	dogru(pencere != null, "ayar penceresi açılır")
	var denenen := 0
	var tutmayan: Array[String] = []
	for i in AyarlarPenceresi.SAYFALAR.size():
		var s: Dictionary = AyarlarPenceresi.SAYFALAR[i]
		bas("AyarSekme_" + str(s.kod))
		await kare(1)
		if pencere.sayfa != i:
			tutmayan.append("sekme " + str(s.kod))
		for satir: Dictionary in s.satirlar:
			var anahtar := str(satir.anahtar)
			match str(satir.tur):
				"kademe":
					var k := pencere.find_child("Kademe_" + anahtar, true, false)
					k.degisti.emit(0.3)
					denenen += 1
					if not is_equal_approx(float(Oyun.ayar(anahtar)), 0.3):
						tutmayan.append(anahtar)
				"isaret":
					var once := bool(Oyun.ayar(anahtar))
					bas("TamEkran" if anahtar == "tam_ekran" else "Isaret_" + anahtar)
					denenen += 1
					if bool(Oyun.ayar(anahtar)) == once:
						tutmayan.append(anahtar)
					bas("TamEkran" if anahtar == "tam_ekran" else "Isaret_" + anahtar)
				"secenek":
					for secenek: Array in satir.secenekler:
						bas("%s_%s" % [str(satir.get("onek", "Sec_" + anahtar)), str(secenek[0])])
						denenen += 1
						if not AyarlarPenceresi._ayni(Oyun.ayar(anahtar), secenek[1]):
							tutmayan.append("%s=%s" % [anahtar, str(secenek[0])])
	esit(tutmayan.size(), 0, "ayar penceresindeki %d düğmenin her biri kendi ayarını yazar %s" % [denenen, str(tutmayan)])
	bas("AyarSifirla")
	esit(JSON.stringify(Oyun.ayarlar), JSON.stringify(Oyun.VARSAYILAN_AYARLAR), "varsayılana dön düğmesi bütün ayarları sıfırlar")
	bas("AyarKapat")
	await kare(2)
	# sarsıntı ve odak kaybı molası
	var masa: Node = await _gune_git(1)
	Oyun.ayar_degistir("ekran_sarsintisi", false)
	masa._sarsinti()
	await kare(3)
	esit(masa.position, Vector2.ZERO, "ekran sarsıntısı kapalıyken masa sarsılmaz")
	Oyun.ayar_degistir("ekran_sarsintisi", true)
	Oyun.odak_sinamasi = true
	Oyun.ayar_degistir("odakta_mola", false)
	Oyun.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	dogru(not get_tree().paused, "arka planda mola kapalıyken odak kaybı oyunu durdurmaz")
	Oyun.ayar_degistir("odakta_mola", true)
	Oyun.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	dogru(get_tree().paused, "odak kaybında oyun kendiliğinden mola verir")
	Oyun.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	Oyun.molayi_bitir()
	dogru(not get_tree().paused, "  mola bitince oyun sürer")
	Oyun.odak_sinamasi = false
	# yazı hızı
	Oyun.ayar_degistir("yazi_hizi", 100.0)
	masa = await _gune_git(2)
	await bekle(0.4)
	var genelge := masa.find_child("GenelgeEkrani", true, false)
	dogru(genelge != null and not genelge._yaziyor, "yazı hızı en yüksekteyken genelge hemen tamamlanır")
	Oyun.ayarlari_sifirla()
	await sahneye_git("menu")
	await sahneyi_bekle("AnaMenu")
