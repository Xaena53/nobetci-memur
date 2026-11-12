extends Control
## Masa — mesai sahnesi. Gişe camı, masadaki belgeler, genelge defteri ve karar araçları.
##
## Akış: vatandaş cama gelir → belgeleri yarıktan masaya kayar → oyuncu inceler ve bir araç
## (mühür / eksik evrak fişi / havale pusulası) bırakarak karar verir → Dogrulayici kararı
## değerlendirir → doğruysa prim yazılır, yanlışsa müdürün ihtarı teleksten satır satır çıkar.
##
## Hikâye karakterleri (data/hikaye.json) kuyruğa belirli sıralarda girer. Bazıları evraksız gelir,
## yalnızca konuşur; bazıları masaya zarf bırakır. Müdür, günün belirli saatlerinde jaluziyi açıp
## gişeyi izler: o sırada yapılan hata çift ihtar sayılır.

const ARKA_PLAN := "res://assets/img/masa_arkaplan.webp"
const BUYUTEC := "res://assets/img/nesne/buyutec.webp"
const IGNE := "res://assets/img/nesne/igne.webp"
const MESAI_BASI := 9 * 60     ## 09:00 (dakika)
const MESAI_SONU := 17 * 60    ## 17:00
const KARAR_ADLARI := {"onay": "ONAY", "eksik": "EKSİK EVRAK", "havale": "MÜDÜRE HAVALE"}

var gun: Dictionary = {}                ## günün genelgesi ve kuralları (data/gunler)
var dakika := float(MESAI_BASI)
var mesai_acik := false                 ## sabah genelgesi okunup gişe açılınca true olur
var gun_bitti := false
var vatandas: Dictionary = {}           ## şu an camdaki vatandaş (yoksa boş)
var belgeler: Array[Belge] = []
var kuyruk: Array[Dictionary] = []      ## sırada bekleyenler
var kararlar: Array[Dictionary] = []    ## günün karar dökümü
var tespitler: Array[String] = []       ## incelemede yakalanan gerekçeler (camdaki vatandaş için)
var ozet: Dictionary = {}               ## günün sayaçları (Gün Sonu ekranına gider)
var havale_kalan := 2
var gunluk_ihtar := 0
var zarf: Zarf                          ## masadaki rüşvet zarfı (varsa)
var denetimde := false                  ## müdür camdan izliyor mu

var gise: Gise
var balon: KonusmaBalonu
var saat: DuvarSaati
var kural_kitabi: KuralKitabi
var inceleme: IncelemeKatmani
var teleks: Teleks
var araclar: Dictionary = {}            ## tür -> Arac

var _tepsi_katmani: Node2D
var _belge_katmani: Node2D
var _fis_katmani: Node2D
var _arac_katmani: Node2D
var _ust_katman: Control
var _incele_dugmesi: Button
var _incele_seridi: Label
var _ihtar_seridi: Label
var _igne: Control
var _igne_dokusu: Texture2D             ## çizim komutu dokuyu tutmaz; başvuru burada yaşamalı
var _bekleyen_fis: Dictionary = {}
var _mesgul := true                     ## vatandaş gelip giderken karar verilemez
var _jaluzi: Control
var _jaluzi_acik := 0.0                 ## 0 inik .. 1 açık
var _mudur_odasi: Control
var _mudur: CanliPortre
var _denetim_seridi: Label
var _saat_durdu := false                ## mektup gibi tam ekran bir kâğıt okunurken saat bekler
var _ses_perdesi := 1.0                 ## camdaki vatandaşın ses perdesi (yaşa ve cinsiyete göre)
var _tik_sayaci := 0.0


func _ready() -> void:
	gun = Veri.gun(Oyun.gun)
	havale_kalan = int(gun.get("havale_hakki", 2))
	ozet = {"islenen": 0, "dogru": 0, "yanlis": 0, "yarim": 0, "havale": 0, "yarida": 0, "kazanc": 0, "ihtar": 0,
		"ihtarlar": []}
	_sahneyi_kur()
	inceleme.karsilastir = _karsilastir
	kural_kitabi.yukle(gun)
	saat.tarih_ayarla(str(gun.get("tarih", "")))
	saat.dakika = dakika
	_kuyrugu_kur()
	_araclari_ayarla()
	_sesleri_bagla()
	_genelgeyi_goster()


func _process(delta: float) -> void:
	if not mesai_acik or _saat_durdu:
		return
	# Ayarlardaki saat hızı: bir oyun dakikasının kaç gerçek saniye sürdüğü.
	dakika += delta / maxf(0.05, float(Oyun.ayar("saat_hizi")))
	if dakika >= MESAI_SONU:
		dakika = MESAI_SONU
		mesaiyi_bitir()
	saat.dakika = dakika
	_denetimi_guncelle()
	# duvar saati: saniyede bir, kısık bir tık
	_tik_sayaci += delta
	if _tik_sayaci >= 1.0:
		_tik_sayaci -= 1.0
		Ses.cal("saat", 1.0 if int(dakika) % 2 == 0 else 0.86, -19.0)


## Gün, müdürün genelgesiyle başlar; "Gişeyi Aç" denince saat işlemeye ve vatandaş gelmeye başlar.
func _genelgeyi_goster() -> void:
	var g := GenelgeEkrani.new()
	g.name = "GenelgeEkrani"
	_ust_katman.add_child(g)
	g.ac(gun, Oyun.gun)
	g.kapandi.connect(giseyi_ac)
	g.harf_yazildi.connect(Ses.cal.bind("daktilo", 1.0, -11.0, 0.08, 0.045))


func giseyi_ac() -> void:
	if mesai_acik or gun_bitti:
		return
	mesai_acik = true
	Oyun.bekle(0.8).connect(_sonraki_vatandas)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		inceleme.aktif = not inceleme.aktif
		get_viewport().set_input_as_handled()


# --- Vatandaş akışı ---

## Günün kuyruğu: rastgele vatandaşlar ve aralarına, hikâyedeki sıralarına göre giren özel karakterler.
func _kuyrugu_kur() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = Oyun.gun_tohumu()
	var ozel := Hikaye.ozel_vatandaslar(Oyun.gun, gun, Oyun.bayraklar, rng)
	var evrakli := 0
	for o in ozel:
		if not bool(o.vatandas.get("belgesiz", false)):
			evrakli += 1
	for i in maxi(0, int(gun.get("vatandas_sayisi", 8)) - evrakli):
		kuyruk.append(VatandasUretici.uret(gun, rng, Oyun.gorulen_portreler))
	var son_yer := -1
	for o in ozel:
		var yer := clampi(maxi(int(o.sira) - 1, son_yer + 1), 0, kuyruk.size())
		kuyruk.insert(yer, o.vatandas)
		son_yer = yer


func _sonraki_vatandas() -> void:
	if not mesai_acik:
		return
	if kuyruk.is_empty():
		balon.sus()
		Oyun.bekle(1.0).connect(mesaiyi_bitir)
		return
	vatandas = kuyruk.pop_front()
	tespitler.clear()
	Ses.cal("zil", 1.0, -9.0)
	_ses_perdesi = _perde_bul(str(vatandas.portre))
	gise.gelsin(str(vatandas.portre))
	await Oyun.bekle(Gise.GELIS_SURESI + 0.1)
	if not mesai_acik:
		return
	if bool(vatandas.get("belgesiz", false)):
		_belgesiz_ziyaret()
		return
	balon.soyle(str(vatandas.konusma.giris))
	_belgeleri_getir()
	if int(vatandas.get("zarf", 0)) > 0:
		_zarfi_getir(0.9)
	_mesgul = false
	_araclari_ayarla()


## Evraksız gelen hikâye karakteri: söyleyeceğini söyler (varsa zarfını bırakır) ve gider.
func _belgesiz_ziyaret() -> void:
	var z := vatandas
	var kod := str(z.get("kod", ""))
	for satir: String in z.get("satirlar", []):
		balon.soyle(satir)
		await balon.bitti
		await Oyun.bekle(1.1 + satir.length() * 0.03)
		if not _ziyaret_suruyor(kod):
			return
	Hikaye.etki_uygula((z.get("etki", {}) as Dictionary).get("ziyaret", null))
	if bool(z.get("mektup", false)):
		await _mektubu_goster()
		if not _ziyaret_suruyor(kod):
			return
	if int(z.get("zarf", 0)) > 0:
		_zarfi_getir(0.0)
		var bekleme := 14.0
		while bekleme > 0.0 and is_instance_valid(zarf) and not zarf.sonuclandi:
			await get_tree().process_frame
			bekleme -= get_process_delta_time()
		if not _ziyaret_suruyor(kod):
			return
		if is_instance_valid(zarf) and not zarf.sonuclandi:
			zarf.geri_git()
			balon.soyle(str((z.get("konusma", {}) as Dictionary).get("zarf_bekledi", "Düşünürsünüz.")), 1.4)
		await Oyun.bekle(1.6)
		if not _ziyaret_suruyor(kod):
			return
	balon.sus()
	gise.gitsin()
	vatandas = {}
	_fisi_goster()
	await Oyun.bekle(1.3)
	_sonraki_vatandas()


## Ziyaretçinin getirdiği mektup masanın üstünde açılır; oyuncu katlayınca ziyaret sürer.
func _mektubu_goster() -> void:
	var katman := Control.new()
	katman.name = "MektupEkrani"
	katman.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	katman.mouse_filter = MOUSE_FILTER_STOP
	_ust_katman.add_child(katman)
	var perde := ColorRect.new()
	perde.color = Color(0.07, 0.06, 0.05, 0.6)
	perde.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	perde.mouse_filter = MOUSE_FILTER_IGNORE
	katman.add_child(perde)
	var kagit := Mektup.new()
	katman.add_child(kagit)
	kagit.kur(Hikaye.mektup())
	Ses.cal("kagit", 0.85, -2.0)
	kagit.position = Vector2(560, 120)
	kagit.rotation = deg_to_rad(-2.0)
	var kapat := Button.new()
	kapat.name = "MektubuKatla"
	kapat.text = "Mektubu Katla"
	kapat.focus_mode = FOCUS_NONE
	kapat.custom_minimum_size = Vector2(210, 42)
	kapat.position = Vector2(560 + (Mektup.BOYUT.x - 210.0) / 2.0, 552)
	katman.add_child(kapat)
	katman.modulate.a = 0.0
	create_tween().tween_property(katman, "modulate:a", 1.0, 0.3)
	_saat_durdu = true            # mektup okunurken mesai saati işlemez
	await kapat.pressed
	_saat_durdu = false
	var t := create_tween()
	t.tween_property(katman, "modulate:a", 0.0, 0.2)
	t.tween_callback(katman.queue_free)


func _ziyaret_suruyor(kod: String) -> bool:
	return mesai_acik and str(vatandas.get("kod", "")) == kod


# --- Rüşvet zarfı ---

func _zarfi_getir(gecikme: float) -> void:
	zarf = Zarf.new()
	zarf.kur(int(vatandas.get("zarf", 0)), _belge_katmani, _ust_katman)
	zarf.alindi.connect(_zarf_alindi)
	zarf.geri_itildi.connect(_zarf_geri_itildi)
	zarf.gel(Yerlesim.GISE_YARIK, Yerlesim.ZARF_YERI, gecikme)
	Ses.gecikmeli("kagit_kay", gecikme + 0.02, 0.85, -5.0)


## Zarf çekmeceye atıldı: para cebe girer, şüphe artar. Müdür izliyorsa para müsadere edilir.
func _zarf_alindi(tutar: int) -> void:
	var konusma: Dictionary = vatandas.get("konusma", {})
	Ses.cal("zarf", 1.0, -3.0)
	Hikaye.etki_uygula((vatandas.get("etki", {}) as Dictionary).get("zarf", null))
	if denetimde:
		Oyun.suphe += 1
		gunluk_ihtar += 2
		ozet.ihtar = gunluk_ihtar
		var mesaj := "Zarfı çekmecenize atarken sizi gördüm. Para müsadere edildi; iki ihtar yazdım."
		(ozet.ihtarlar as Array).append(mesaj)
		teleks.yazdir(mesaj, gunluk_ihtar, "ihtar")
		_mudur.uzul()
		_igneyi_guncelle()
	else:
		Oyun.para += tutar
		ozet["zarf"] = int(ozet.get("zarf", 0)) + tutar
	gise.portre.sevin()
	balon.soyle(str(konusma.get("zarf", "Anlaştık.")), 1.4)


func _zarf_geri_itildi() -> void:
	var konusma: Dictionary = vatandas.get("konusma", {})
	gise.portre.sas()
	balon.soyle(str(konusma.get("zarf_geri", "Siz bilirsiniz.")), 1.4)


func _belgeleri_getir() -> void:
	var i := 0
	for v: Dictionary in vatandas.belgeler:
		var b := Belge.olustur(v)
		if b == null:
			continue
		b.masaya_koy(_belge_katmani)
		b.hedef_tiklandi.connect(inceleme.hedef_tiklandi)
		b.inceleme_ac(inceleme.aktif)
		var yer: Vector2 = Yerlesim.BELGE_YERI.get(b.tur, Vector2(450, 230))
		yer += Vector2(randf_range(-4, 4), randf_range(-2, 2))
		b.tutucu.yatis_acisi = deg_to_rad(randf_range(-1.0, 1.0))
		b.gel(Yerlesim.GISE_YARIK, yer, 0.15 + i * 0.2)
		Ses.gecikmeli("kagit_kay", 0.15 + i * 0.2, 1.0, -6.0, 0.08)
		belgeler.append(b)
		i += 1


func _vatandasi_ugurla(karar: String) -> void:
	_mesgul = true
	_araclari_ayarla()
	gise.tepki(karar)
	if is_instance_valid(zarf) and not zarf.sonuclandi:
		zarf.geri_git()            # dokunulmayan zarf sahibiyle birlikte gider
	_belgeleri_kilitle()
	await Oyun.bekle(0.7)
	balon.soyle(str(vatandas.konusma.get(karar, "")), 1.4)
	inceleme.temizle()
	kural_kitabi.isaretleri_temizle()
	_belgeleri_gonder(0.25)
	Ses.gecikmeli("kagit_kay", 0.25, 1.15, -8.0)
	await Oyun.bekle(1.0)
	gise.gitsin()
	vatandas = {}
	_fisi_goster()
	await Oyun.bekle(1.3)
	_sonraki_vatandas()


# Belgeler üzerindeki döngüler, bekleyen (await) işlevlerin dışında tutulur: beklerken oyundan
# çıkılırsa döngü değişkeni belge betiğini bellekte asılı bırakıyor.

func _belgeleri_kilitle() -> void:
	for b in belgeler:
		b.kilitli = true


## Masadaki belgeleri sırayla yarıktan geri yollar.
func _belgeleri_gonder(ilk_gecikme: float) -> void:
	var i := 0
	for b in belgeler:
		b.git(Yerlesim.GISE_YARIK, ilk_gecikme + i * 0.12)
		i += 1
	belgeler.clear()


# --- Kararlar ---

func _arac_birakildi(arac: Arac, konum: Vector2) -> void:
	var b := _konumdaki_belge(konum)
	if b == null or _mesgul or vatandas.is_empty():
		arac.eve_don()
		return
	if arac.tur == "eksik":
		arac.eve_don()
		_gerekce_sor(b, konum)
		return
	karar_ver(arac.tur, b, konum)
	Oyun.bekle(0.16).connect(arac.eve_don)


## "Eksik evrak" için gerekçe penceresini açar; seçilince karar verilir.
func _gerekce_sor(belge: Belge, konum: Vector2) -> void:
	_mesgul = true
	_araclari_ayarla()
	var p := GerekcePenceresi.new()
	p.name = "GerekcePenceresi"
	_ust_katman.add_child(p)
	p.ac(Dogrulayici.gunun_gerekceleri(gun), tespitler, konum)
	p.secildi.connect(func(gerekce: String) -> void:
		_mesgul = false
		karar_ver("eksik", belge, konum, gerekce))
	p.vazgecildi.connect(func() -> void:
		_mesgul = false
		_araclari_ayarla())


## Kararı kaydeder, belgeye izini bırakır ve doğruluğunu değerlendirir. `konum` ekran koordinatıdır.
func karar_ver(karar: String, belge: Belge, konum: Vector2, gerekce: String = "") -> void:
	if _mesgul or vatandas.is_empty() or not is_instance_valid(belge):
		return
	_mesgul = true
	var yerel := belge.get_global_transform().affine_inverse() * konum
	match karar:
		"onay":
			belge.iz_birak("onay", yerel, PackedStringArray(["ONAYLANMIŞTIR", "Ardıçlı Nüfus Md.", str(gun.get("tarih", ""))]))
			Ses.cal("muhur", 1.0, 0.0, 0.04)
			_sarsinti()
		"eksik":
			belge.iz_birak("eksik", yerel, _fis_satirlari(str(Dogrulayici.GEREKCELER.get(gerekce, "Eksik evrak"))))
			Ses.cal("kagit", 1.0, -2.0, 0.08)
		"havale":
			belge.iz_birak("havale", yerel, PackedStringArray(["MÜDÜRE HAVALE", "Müdürlük makamına", "arz olunur."]))
			Ses.cal("kagit", 0.9, -2.0, 0.08)
			havale_kalan -= 1
			(araclar["havale"] as Arac).kalan = havale_kalan

	var sonuc := Dogrulayici.kontrol(vatandas, gun)
	var degerlendirme := Dogrulayici.degerlendir(karar, gerekce, sonuc)
	# Hikâye karakterlerinde kararın ayrıca bir bedeli ya da karşılığı olur.
	var etki: Dictionary = {}
	if str(vatandas.get("tur", "")) == "hikaye":
		var e: Variant = (vatandas.get("etki", {}) as Dictionary).get(karar, null)
		if typeof(e) == TYPE_DICTIONARY:
			etki = e
	if etki.has("sonuc"):
		degerlendirme = {"sonuc": str(etki.sonuc), "mesaj": ""}
	_sonucu_isle(karar, degerlendirme)
	if not etki.is_empty():
		Hikaye.etki_uygula(etki)
		if etki.has("not"):
			_bekleyen_fis = {"cesit": "not", "metin": str(etki["not"])}
		# arananlardan biri yakalandıysa defterdeki resmine damga vurulur
		var acik_sayfa := kural_kitabi.sayfa
		kural_kitabi.yukle(gun)
		kural_kitabi.sayfaya_gec(acik_sayfa, false)
	kararlar.append({"karar": karar, "gerekce": gerekce, "sonuc": degerlendirme.sonuc, "dogru_karar": sonuc.karar,
		"vatandas": vatandas})
	_vatandasi_ugurla(karar)


func _sonucu_isle(karar: String, d: Dictionary) -> void:
	ozet.islenen += 1
	if karar == "havale":
		ozet.havale += 1
	match str(d.sonuc):
		"dogru":
			ozet.dogru += 1
			ozet.kazanc += Oyun.PRIM
			Ses.gecikmeli("prim", 0.5, 1.0, -12.0)
			if bool(d.get("supheli_yakalandi", false)):
				ozet.kazanc += Oyun.SUPHELI_PRIMI
				_bekleyen_fis = {"cesit": "not", "metin": "Şüpheniz yerindeymiş; evrak sahte çıktı. Dikkatiniz sicilinize işlendi."}
		"yanlis":
			ozet.yanlis += 1
			var mesaj := str(d.mesaj)
			if denetimde:
				gunluk_ihtar += 2
				mesaj += " Camdan izliyordum: çift ihtar."
				_mudur.uzul()
			else:
				gunluk_ihtar += 1
			ozet.ihtar = gunluk_ihtar
			(ozet.ihtarlar as Array).append(mesaj)
			_bekleyen_fis = {"cesit": "ihtar", "metin": mesaj}
		"yarim":
			ozet.yarim += 1
			_bekleyen_fis = {"cesit": "uyari", "metin": str(d.mesaj)}
		_:
			if str(d.get("mesaj", "")) != "":
				_bekleyen_fis = {"cesit": "not", "metin": str(d.mesaj)}


## Bekleyen pusulayı (ihtar / uyarı / not) teleksten bastırır.
func _fisi_goster() -> void:
	if _bekleyen_fis.is_empty():
		return
	if str(_bekleyen_fis.cesit) == "ihtar":
		Ses.cal("ihtar", 1.0, -9.0)
	teleks.yazdir(str(_bekleyen_fis.metin), gunluk_ihtar, str(_bekleyen_fis.cesit))
	_bekleyen_fis = {}


func _fis_satirlari(gerekce: String) -> PackedStringArray:
	# gerekçeyi fişe sığacak kısa satırlara böl
	var satirlar := PackedStringArray(["EKSİK EVRAK"])
	var satir := ""
	for k in gerekce.split(" "):
		if (satir + " " + k).strip_edges().length() > 22 and satir != "":
			satirlar.append(satir)
			satir = k
		else:
			satir = (satir + " " + k).strip_edges()
	if satir != "":
		satirlar.append(satir)
	return satirlar


func _konumdaki_belge(konum: Vector2) -> Belge:
	for i in range(_belge_katmani.get_child_count() - 1, -1, -1):
		var t := _belge_katmani.get_child(i) as MasaNesnesi
		if t == null:
			continue
		var b := t.icerik() as Belge
		if b == null or b.kilitli:
			continue
		var yerel := b.get_global_transform().affine_inverse() * konum
		if Rect2(Vector2.ZERO, b.size).has_point(yerel):
			return b
	return null


func _araclari_ayarla() -> void:
	var acik := mesai_acik and not _mesgul and not vatandas.is_empty()
	for a: Arac in araclar.values():
		a.etkin = acik and a.kalan != 0


## Mesai biter (saat 17:00 oldu ya da kuyruk tükendi): gişe kapanır, camdaki vatandaş yarıda kalır.
func mesaiyi_bitir() -> void:
	if gun_bitti:
		return
	gun_bitti = true
	mesai_acik = false
	_mesgul = true
	_araclari_ayarla()
	inceleme.aktif = false
	inceleme.temizle()
	if is_instance_valid(zarf) and not zarf.sonuclandi:
		zarf.geri_git()
	if not vatandas.is_empty():
		if bool(vatandas.get("belgesiz", false)):
			balon.soyle("Kapatıyorsunuz demek. Sonra konuşuruz.", 1.6)
		else:
			ozet.yarida += 1
			balon.soyle("Saat beş mi oldu? Ama daha işim bitmemişti!", 1.6)
		gise.tepki("eksik")
		_belgeleri_gonder(0.3)
		vatandas = {}
		await Oyun.bekle(1.3)
		gise.gitsin()
	gise.kepengi_indir()
	Ses.cal("kepenk", 1.0, -2.0)
	Ses.ortami_kes("radyo", 2.2)
	await Oyun.bekle(1.9)
	ozet.ihtar = gunluk_ihtar
	Oyun.mesaiyi_kapat(ozet)
	Oyun.sahneye_gec("gun_sonu")


# --- Ses ve sarsıntı ---

func _sesleri_bagla() -> void:
	gise.efekt.connect(_gise_sesi)
	teleks.satir_basildi.connect(Ses.cal.bind("teleks", 1.0, -5.0, 0.06))
	teleks.fis_koptu.connect(func(_f: IhtarFisi) -> void: Ses.cal("yirt", 1.0, -3.0, 0.05))
	kural_kitabi.sayfa_cevrildi.connect(Ses.cal.bind("sayfa", 1.0, -4.0, 0.06))
	for a: Arac in araclar.values():
		a.alindi.connect(func(_a: Arac) -> void: Ses.cal("tik", 0.8, -5.0))
	Ses.yalniz(["radyo"])
	Ses.ortam("radyo", -10.0, 2.5)


## Camdaki vatandaştan gelen sesler: ayak sesi, konuşma heceleri, öfleme.
func _gise_sesi(ad: String) -> void:
	match ad:
		"adim":
			Ses.cal("adim", 1.0, -9.0, 0.12)
		"hece":
			Ses.cal("hece", _ses_perdesi, -8.0, 0.07)
		"ofle":
			Ses.cal("ofle", clampf(_ses_perdesi, 0.85, 1.25), -5.0)


## Portrenin yaşına ve cinsiyetine göre konuşma perdesi; kişiden kişiye biraz oynar.
func _perde_bul(portre: String) -> float:
	var b := Portreler.bilgi(portre)
	var yas := int(b.get("yas", 40))
	var perde := 1.48 if str(b.get("cinsiyet", "E")) == "K" else 0.96
	if yas <= 12:
		perde = 1.9
	elif yas >= 62:
		perde *= 0.9
	return perde + float(hash(portre) % 100) / 100.0 * 0.16 - 0.08


## Mühür inince masa kısa bir an sarsılır.
func _sarsinti(guc: float = 5.0) -> void:
	var t := create_tween()
	for i in 5:
		var g := guc * (1.0 - i / 5.0)
		t.tween_property(self, "position", Vector2(randf_range(-g, g), randf_range(-g * 0.3, g)), 0.028)
	t.tween_property(self, "position", Vector2.ZERO, 0.04)


# --- İnceleme modu ---

func _karsilastir(a: Hedef, b: Hedef) -> Dictionary:
	return Dogrulayici.karsilastir(a.ozet(), b.ozet(), vatandas, gun)


func _bulgu(sonuc: Dictionary) -> void:
	var gerekce := str(sonuc.get("gerekce", ""))
	var durum := str(sonuc.get("durum", ""))
	if durum == "uyusmaz":
		Ses.cal("tik", 0.55, 0.0)
	elif durum == "uyumlu":
		Ses.cal("tik", 1.5, -5.0)
	if durum == "uyusmaz" and gerekce != "" and not tespitler.has(gerekce):
		tespitler.append(gerekce)


func _inceleme_degisti(acik: bool) -> void:
	for b in belgeler:
		b.inceleme_ac(acik)
	kural_kitabi.inceleme_ac(acik)
	gise.yuz.aktif = acik
	saat.takvim.aktif = acik
	_incele_dugmesi.set_pressed_no_signal(acik)
	_incele_dugmesi.modulate = Color(1.25, 1.2, 1.05) if acik else Color.WHITE
	_incele_seridi.text = "İNCELEME AÇIK" if acik else "İNCELE [BOŞLUK]"
	_incele_seridi.add_theme_color_override("font_color", Color("ffd9a0") if acik else Stil.KAGIT_BEYAZ)


# --- Sahne kurulumu ---

func _sahneyi_kur() -> void:
	if ResourceLoader.exists(ARKA_PLAN):
		var zemin := TextureRect.new()
		zemin.name = "ArkaPlan"
		zemin.texture = load(ARKA_PLAN)
		zemin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		zemin.stretch_mode = TextureRect.STRETCH_SCALE
		zemin.size = Yerlesim.EKRAN.size
		zemin.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(zemin)
	else:
		var duz := ColorRect.new()
		duz.color = Stil.MASA
		duz.size = Yerlesim.EKRAN.size
		duz.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(duz)

	gise = Gise.new()
	gise.name = "Gise"
	add_child(gise)

	saat = DuvarSaati.new()
	saat.name = "DuvarSaati"
	add_child(saat)

	_mudur_bolmesini_kur()

	balon = KonusmaBalonu.new()
	balon.name = "Balon"
	add_child(balon)
	balon.basladi.connect(gise.konus.bind(true))
	balon.bitti.connect(gise.konus.bind(false))

	kural_kitabi = KuralKitabi.new()
	kural_kitabi.name = "KuralKitabi"
	kural_kitabi.position = Yerlesim.PANO.position
	kural_kitabi.size = Yerlesim.PANO.size
	add_child(kural_kitabi)

	_tepsi_katmani = _katman("Tepsi")
	_belge_katmani = _katman("Belgeler")
	_fis_katmani = _katman("Fisler")
	teleks = Teleks.new()
	teleks.name = "Teleks"
	add_child(teleks)
	_arac_katmani = _katman("Araclar")
	_tepsiyi_kur()
	teleks.kur(_fis_katmani, Perspektif.ekrana(Yerlesim.IGNE_YERI) + Vector2(0, -30))
	teleks.fis_koptu.connect(func(_f: IhtarFisi) -> void: _igneyi_guncelle())
	var yerler := {"onay": Yerlesim.MUHUR_YERI, "eksik": Yerlesim.EKSIK_YERI, "havale": Yerlesim.HAVALE_YERI}
	for tur: String in yerler:
		var a := Arac.new()
		a.kur(tur, yerler[tur], _arac_katmani)
		a.birakildi.connect(_arac_birakildi)
		araclar[tur] = a
	(araclar["havale"] as Arac).kalan = havale_kalan

	inceleme = IncelemeKatmani.new()
	inceleme.name = "Inceleme"
	add_child(inceleme)
	inceleme.mod_degisti.connect(_inceleme_degisti)
	inceleme.bulgu.connect(_bulgu)
	gise.hedef_tiklandi.connect(inceleme.hedef_tiklandi)
	saat.hedef_tiklandi.connect(inceleme.hedef_tiklandi)
	kural_kitabi.hedef_tiklandi.connect(inceleme.hedef_tiklandi)

	_ust_katman = Control.new()
	_ust_katman.name = "UstKatman"
	_ust_katman.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_ust_katman.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_ust_katman)


func _katman(ad: String) -> Node2D:
	var k := Node2D.new()
	k.name = ad
	add_child(k)
	return k


## Müdür odasının camlı bölmesi: plaket, camın ardındaki müdür ve jaluzi. Jaluzi çoğu zaman iniktir;
## müdür denetim saatlerinde açar ve gişeyi izler.
func _mudur_bolmesini_kur() -> void:
	var p := Yerlesim.MUDUR_PLAKET
	var yazi := Stil.etiket("MÜDÜR", 12, Color("3a2a14"), Stil.serif_kalin())
	yazi.position = p.position
	yazi.size = p.size
	yazi.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	yazi.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(yazi)

	_mudur_odasi = Control.new()
	_mudur_odasi.name = "MudurOdasi"
	_mudur_odasi.position = Yerlesim.MUDUR_CAMI.position
	_mudur_odasi.size = Yerlesim.MUDUR_CAMI.size
	_mudur_odasi.clip_contents = true
	_mudur_odasi.mouse_filter = MOUSE_FILTER_IGNORE
	_mudur_odasi.visible = false
	_mudur_odasi.draw.connect(func() -> void:
		var b := _mudur_odasi.size
		_mudur_odasi.draw_rect(Rect2(Vector2.ZERO, b), Color("3a3626"))
		_mudur_odasi.draw_rect(Rect2(0, b.y * 0.62, b.x, b.y * 0.38), Color("2c2a1f"))
		_mudur_odasi.draw_circle(Vector2(b.x * 0.5, b.y * 0.30), b.x * 0.62, Color(1.0, 0.86, 0.55, 0.10))
		_mudur_odasi.draw_circle(Vector2(b.x * 0.5, b.y * 0.26), b.x * 0.36, Color(1.0, 0.86, 0.55, 0.10)))
	add_child(_mudur_odasi)
	_mudur = CanliPortre.new()
	_mudur.name = "Mudur"
	_mudur_odasi.add_child(_mudur)
	_mudur.ayarla("mudur", 0.335)
	_mudur.position = Vector2((_mudur_odasi.size.x - _mudur.size.x) / 2.0, _mudur_odasi.size.y - _mudur.size.y + 8.0)
	_mudur.set_process(false)

	_jaluzi = Control.new()
	_jaluzi.name = "Jaluzi"
	_jaluzi.position = Yerlesim.MUDUR_CAMI.position
	_jaluzi.size = Yerlesim.MUDUR_CAMI.size
	_jaluzi.mouse_filter = MOUSE_FILTER_IGNORE
	_jaluzi.draw.connect(_jaluzi_ciz)
	add_child(_jaluzi)

	_denetim_seridi = Stil.etiket("MÜDÜR İZLİYOR", 11, Stil.KAGIT_BEYAZ, Stil.daktilo_kalin())
	_denetim_seridi.name = "DenetimSeridi"
	_denetim_seridi.add_theme_stylebox_override("normal", Stil.bosluklu(Stil.kutu(Stil.BORDO, Color(0, 0, 0, 0.45), 1, 2, 2), 4, 2))
	_denetim_seridi.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_denetim_seridi.position = Yerlesim.DENETIM_ETIKETI.position
	_denetim_seridi.size = Yerlesim.DENETIM_ETIKETI.size
	_denetim_seridi.visible = false
	add_child(_denetim_seridi)


## Jaluzi: yatay latalar. Açıldıkça latalar incelir, aralarından oda görünür.
func _jaluzi_ciz() -> void:
	var w := _jaluzi.size.x
	var kalin := lerpf(7.0, 1.4, _jaluzi_acik)
	var y := 0.0
	while y < _jaluzi.size.y:
		_jaluzi.draw_rect(Rect2(0, y, w, kalin), Color("b9b6a2"))
		_jaluzi.draw_rect(Rect2(0, y + kalin - 1.2, w, 1.2), Color("8f8c7a"))
		_jaluzi.draw_rect(Rect2(0, y + kalin, w, 9.0 - kalin), Color(0.08, 0.10, 0.10, 0.85 * (1.0 - _jaluzi_acik)))
		y += 9.0
	for x: float in [w * 0.22, w * 0.78]:
		_jaluzi.draw_line(Vector2(x, 0), Vector2(x, _jaluzi.size.y), Color(0.25, 0.24, 0.20, 0.7), 1.0)
	# camın yansıması
	_jaluzi.draw_colored_polygon(PackedVector2Array([Vector2(w * 0.55, 0), Vector2(w * 0.78, 0),
		Vector2(w * 0.40, _jaluzi.size.y), Vector2(w * 0.17, _jaluzi.size.y)]), Color(1, 1, 1, 0.05 * _jaluzi_acik))


## Günün denetim saatlerine (data/gunler: "denetim": [[başlangıç, bitiş] dakika]) göre jaluziyi açar/kapatır.
func _denetimi_guncelle() -> void:
	var simdi := false
	if mesai_acik:
		for aralik: Array in gun.get("denetim", []):
			if dakika >= float(aralik[0]) and dakika < float(aralik[1]):
				simdi = true
	if simdi == denetimde:
		return
	denetimde = simdi
	_denetim_seridi.visible = simdi
	Ses.cal("jaluzi", 1.0 if simdi else 0.85, -5.0)
	if simdi:
		_mudur_odasi.visible = true
		_mudur.set_process(true)
	var t := create_tween()
	t.tween_method(func(a: float) -> void:
		_jaluzi_acik = a
		_jaluzi.queue_redraw(), _jaluzi_acik, 1.0 if simdi else 0.0, 0.7).set_trans(Tween.TRANS_SINE)
	if not simdi:
		t.tween_callback(func() -> void:
			_mudur_odasi.visible = false
			_mudur.set_process(false))


## Araç tepsisi: büyüteç (inceleme modu düğmesi), ihtar iğnesi ve şerit etiketler.
func _tepsiyi_kur() -> void:
	_incele_dugmesi = Button.new()
	_incele_dugmesi.name = "Incele"
	_incele_dugmesi.toggle_mode = true
	_incele_dugmesi.focus_mode = FOCUS_NONE
	_incele_dugmesi.flat = true
	_incele_dugmesi.size = Vector2(124, 78)
	_incele_dugmesi.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	for durum: String in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		_incele_dugmesi.add_theme_stylebox_override(durum, StyleBoxEmpty.new())
	if ResourceLoader.exists(BUYUTEC):
		var resim := TextureRect.new()
		resim.texture = load(BUYUTEC)
		resim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		resim.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		resim.size = Vector2(58, 108)
		resim.position = Vector2(33, -15)
		resim.pivot_offset = resim.size / 2.0
		resim.rotation = deg_to_rad(58.0)
		resim.mouse_filter = MOUSE_FILTER_IGNORE
		_incele_dugmesi.add_child(resim)
	_incele_dugmesi.toggled.connect(func(acik: bool) -> void: inceleme.aktif = acik)
	_masaya_yerlestir(_incele_dugmesi, Yerlesim.BUYUTEC_YERI)
	_incele_seridi = _serit("İNCELE [BOŞLUK]", Yerlesim.BUYUTEC_YERI + Vector2(-8, 58), Color("1d1b19"), 118)

	if ResourceLoader.exists(IGNE):
		_igne_dokusu = load(IGNE)
	_igne = Control.new()
	_igne.name = "Igne"
	_igne.size = Vector2(52, 78)
	_igne.mouse_filter = MOUSE_FILTER_IGNORE
	_igne.draw.connect(_igne_ciz)
	_masaya_yerlestir(_igne, Yerlesim.IGNE_YERI + Vector2(0, -22))
	_ihtar_seridi = _serit("İHTAR 0", Yerlesim.IGNE_YERI + Vector2(8, 30), Stil.BORDO, 64)


## İğne ve ona takılmış günün ihtar pusulaları.
func _igne_ciz() -> void:
	var s := _igne.size
	if _igne_dokusu != null:
		_igne.draw_texture_rect(_igne_dokusu, Rect2(Vector2.ZERO, s), false)
	else:
		_igne.draw_line(Vector2(s.x / 2.0, 4), Vector2(s.x / 2.0, s.y - 12), Color("8f9498"), 2.0)
		_igne.draw_circle(Vector2(s.x / 2.0, s.y - 8), 14, Stil.MASA_KOYU)
	for i in mini(gunluk_ihtar, 6):
		var y := s.y - 30.0 - i * 5.0
		var kayma := 3.0 if i % 2 == 0 else -2.0
		var kose := PackedVector2Array([Vector2(6 + kayma, y), Vector2(s.x - 8 + kayma, y - 3),
			Vector2(s.x - 5 + kayma, y + 5), Vector2(9 + kayma, y + 8)])
		_igne.draw_colored_polygon(kose, Color("f2c4c4"))
		kose.append(kose[0])
		_igne.draw_polyline(kose, Color(Stil.BORDO, 0.7), 1.0, true)


func _igneyi_guncelle() -> void:
	_igne.queue_redraw()
	_ihtar_seridi.text = "İHTAR %d" % gunluk_ihtar


## Bir denetimi (düğme, etiket, gösterge) tepsideki yerine, masa perspektifiyle yerleştirir.
func _masaya_yerlestir(d: Control, yer: Vector2) -> MasaNesnesi:
	var t := MasaNesnesi.new()
	t.name = "Tutucu_" + str(d.name)
	_tepsi_katmani.add_child(t)
	t.add_child(d)
	t.ortala()
	t.masa_konumu = yer
	return t


## Dymo tarzı kabartma şerit etiket (masa düzleminde; `yer` ortasıdır).
func _serit(metin: String, yer: Vector2, zemin: Color, genislik: float = 128.0) -> Label:
	var l := Stil.etiket(metin, 11, Stil.KAGIT_BEYAZ, Stil.daktilo_kalin())
	l.add_theme_stylebox_override("normal", Stil.bosluklu(Stil.kutu(zemin, Color(0, 0, 0, 0.45), 1, 2, 2), 4, 2))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.size = Vector2(genislik, 18)
	_masaya_yerlestir(l, yer)
	return l
