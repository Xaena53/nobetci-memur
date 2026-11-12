class_name Dogrulayici
extends RefCounted
## Kural motoru. Bir vatandaşın belgelerini günün genelgesine göre denetler, oyuncunun
## kararını değerlendirir ve inceleme modundaki ikili karşılaştırmaları yapar.
##
## Vatandaş: {portre, belgeler: [{tur, alanlar: {...}, foto}], ...}
## Gün:      {tarih, kurallar: [{id, tur, ...}]}   (bkz. data/gunler/*.json)

## Geri çevirme gerekçeleri (fişte seçilir).
const GEREKCELER := {
	"belge_eksik": "Gerekli belge eksik",
	"ad_soyad": "Ad ya da soyad uyuşmuyor",
	"baba_adi": "Baba adı uyuşmuyor",
	"sure": "Belgenin süresi geçmiş",
	"muhur": "Mühür ya da imza eksik",
	"harc": "Harç tutarı yanlış",
	"seri": "Seri numarası geçersiz",
	"foto": "Fotoğraf başkasına ait",
	"mahalle": "Mahalle ilçemize bağlı değil",
	"sahte": "Sahte mühür, imza, kaşe ya da vize",
	"vize": "Çalışma vizesinin süresi geçmiş",
}
## Kural türü → o kuralın doğurabileceği gerekçe.
const KURAL_GEREKCESI := {
	"belge_zorunlu": "belge_eksik",
	"tarih_sure": "sure",
	"muhur_zorunlu": "muhur",
	"harc_tutar": "harc",
	"seri_aralik": "seri",
	"foto_eslesme": "foto",
	"mahalle_listesi": "mahalle",
	"sahtecilik": "sahte",
}
## Sahtecilik kokan kusurlar: bunları müdüre havale etmek doğru karardır.
const SUPHELI := ["seri", "foto", "sahte"]
const ALAN_ADLARI := {"ad": "Adı", "soyad": "Soyadı", "baba_adi": "Baba adı"}
## Cüzdan ile çalışma vizesi arasında birebir aynı olması gereken bilgiler.
const VIZE_ALANLARI := {"seri_no": "Cüzdan seri numarası", "dogum_tarihi": "Doğum tarihi", "imza": "İmza"}
const BELGE_ADLARI := {
	"nufus_cuzdani": "Nüfus cüzdanı",
	"ikametgah": "İkametgâh ilmühaberi",
	"harc_makbuzu": "Harç makbuzu",
	"calisma_vizesi": "Çalışma vizesi",
}
const ILGISIZ := {"durum": "ilgisiz", "mesaj": "Bu ikisi arasında bir bağ yok."}


# --- Belge denetimi ---

## Belgeleri günün bütün kurallarından geçirir.
## Dönüş: {karar: "onay"|"eksik", hatalar: [{kod, gerekce, aciklama, kural, belge, alan}], gerekceler: [...]}
static func kontrol(v: Dictionary, gun: Dictionary) -> Dictionary:
	var hatalar: Array[Dictionary] = []
	var belgeler := belge_sozlugu(v)
	var bugun := str(gun.get("tarih", ""))

	for k: Dictionary in gun.get("kurallar", []):
		match str(k.get("tur", "")):
			"belge_zorunlu":
				for t: String in k.get("belgeler", []):
					if not belgeler.has(t):
						hatalar.append(_hata("belge_eksik", "belge_eksik", "%s yok." % belge_adi(t), k, t))
			"alan_esit":
				for alan: String in k.get("alanlar", []):
					var gorulen := _alan_degerleri(belgeler, alan)
					if gorulen.size() > 1:
						hatalar.append(_hata(alan + "_uyusmazligi", "baba_adi" if alan == "baba_adi" else "ad_soyad",
							"%s belgelerde farklı yazılmış (%s)." % [ALAN_ADLARI.get(alan, alan), " / ".join(PackedStringArray(gorulen))],
							k, "", alan))
			"tarih_sure":
				var t := str(k.get("belge", ""))
				if belgeler.has(t):
					var tarih := str(_alan(belgeler[t], "tarih"))
					if not tarih_gecerli(tarih, bugun, k):
						hatalar.append(_hata("sure_gecmis", "sure",
							"%s tarihi (%s) geçerlilik süresinin dışında." % [belge_adi(t), tarih], k, t, "tarih"))
			"muhur_zorunlu":
				if belgeler.has("ikametgah"):
					var b: Dictionary = belgeler["ikametgah"]
					if not bool(_alan(b, "muhtar_muhur", false)):
						hatalar.append(_hata("muhur_eksik", "muhur", "İkametgâhta muhtar mührü yok.", k, "ikametgah", "muhtar_muhur"))
					if bool(k.get("imza", false)) and not bool(_alan(b, "muhtar_imza", false)):
						hatalar.append(_hata("imza_eksik", "muhur", "İkametgâhta muhtar imzası yok.", k, "ikametgah", "muhtar_imza"))
			"harc_tutar":
				if belgeler.has("harc_makbuzu"):
					var b: Dictionary = belgeler["harc_makbuzu"]
					var islem := str(_alan(b, "islem"))
					var beklenen := harc(k, islem)
					var odenen := int(_alan(b, "tutar", 0))
					if beklenen != odenen:
						hatalar.append(_hata("harc_yanlis", "harc", "%s harcı %s olmalı; makbuzda %s yazıyor." % [
							Islemler.adi(islem), Stil.tl(beklenen), Stil.tl(odenen)], k, "harc_makbuzu", "tutar"))
			"seri_aralik":
				if belgeler.has("nufus_cuzdani"):
					var seri := str(_alan(belgeler["nufus_cuzdani"], "seri_no"))
					if not seri_gecerli(seri, k):
						hatalar.append(_hata("seri_gecersiz", "seri",
							"Cüzdanın seri numarası (%s) geçerli seriler arasında yok." % seri, k, "nufus_cuzdani", "seri_no"))
			"foto_eslesme":
				if belgeler.has("nufus_cuzdani"):
					if str((belgeler["nufus_cuzdani"] as Dictionary).get("foto", "")) != str(v.get("portre", "")):
						hatalar.append(_hata("foto_uyusmazligi", "foto",
							"Cüzdandaki fotoğraf başvuran kişiye ait değildi.", k, "nufus_cuzdani", "foto"))
			"mahalle_listesi":
				if belgeler.has("ikametgah"):
					var mahalle := str(_alan(belgeler["ikametgah"], "mahalle"))
					if not mahalle_gecerli(mahalle, k):
						hatalar.append(_hata("mahalle_gecersiz", "mahalle",
							"%s Mahallesi ilçemize bağlı değil." % mahalle, k, "ikametgah", "mahalle"))
			"arananlar":
				var aranan := aranan_kaydi(str(v.get("portre", "")), k)
				if not aranan.is_empty():
					hatalar.append(_hata("aranan", "aranan", "Gişeye gelen şahıs arananlar listesindeydi (%s)." % str(aranan.ad), k))
			"sahtecilik":
				for h in sahtecilik_hatalari(belgeler):
					hatalar.append(_hata(str(h.kod), "sahte", str(h.aciklama), k, str(h.belge), str(h.alan)))
			"vize":
				if str(v.get("islem", "")) != str(k.get("islem", "yurt_disi")):
					continue
				if not belgeler.has("calisma_vizesi"):
					hatalar.append(_hata("belge_eksik", "belge_eksik", "Çalışma vizesi yok.", k, "calisma_vizesi"))
					continue
				for h in vize_hatalari(belgeler, bugun, k):
					hatalar.append(_hata(str(h.kod), str(h.gerekce), str(h.aciklama), k, "calisma_vizesi", str(h.alan)))

	var gerekceler: Array[String] = []
	for h in hatalar:
		if not gerekceler.has(h.gerekce):
			gerekceler.append(h.gerekce)
	return {"karar": "onay" if hatalar.is_empty() else "eksik", "hatalar": hatalar, "gerekceler": gerekceler}


## Oyuncunun kararını doğru kararla karşılaştırır.
## Dönüş: {sonuc: "dogru"|"yanlis"|"yarim"|"notr", mesaj, supheli_yakalandi}
static func degerlendir(karar: String, gerekce: String, sonuc: Dictionary) -> Dictionary:
	var hatalar: Array = sonuc.get("hatalar", [])
	var gerekceler: Array = sonuc.get("gerekceler", [])
	var ilk := str(hatalar[0].aciklama) if not hatalar.is_empty() else ""
	# Aranan şahıs: tek doğru karar müdüre havaledir.
	if gerekceler.has("aranan"):
		var kim := ""
		for h: Dictionary in hatalar:
			if str(h.gerekce) == "aranan":
				kim = str(h.aciklama)
		match karar:
			"havale":
				return {"sonuc": "dogru", "mesaj": "", "supheli_yakalandi": true}
			"onay":
				return {"sonuc": "yanlis", "mesaj": "Aranan bir şahsın evrakını onayladınız! " + kim}
			_:
				return {"sonuc": "yanlis", "mesaj": "Aranan şahsı geri çevirip elinizden kaçırdınız. " + kim}
	match karar:
		"onay":
			if hatalar.is_empty():
				return {"sonuc": "dogru", "mesaj": ""}
			return {"sonuc": "yanlis", "mesaj": "Kusurlu evrakı onayladınız. " + ilk}
		"eksik":
			if hatalar.is_empty():
				return {"sonuc": "yanlis", "mesaj": "Evrakı tam olan vatandaşı geri çevirdiniz."}
			if gerekceler.has(gerekce):
				return {"sonuc": "dogru", "mesaj": ""}
			return {"sonuc": "yarim", "mesaj": "Geri çevirmeniz yerinde, gerekçeniz yanlış. " + ilk}
		"havale":
			for g: String in gerekceler:
				if SUPHELI.has(g):
					return {"sonuc": "dogru", "mesaj": "", "supheli_yakalandi": true}
			if hatalar.is_empty():
				return {"sonuc": "notr", "mesaj": "Müdür evrakı kusursuz buldu, işlemi kendisi yaptı."}
			return {"sonuc": "notr", "mesaj": "Müdür evrakı geri çevirdi. " + ilk}
	return {"sonuc": "notr", "mesaj": ""}


## O gün fişte sunulacak gerekçeler (yalnızca yürürlükteki kuralların doğurabilecekleri).
static func gunun_gerekceleri(gun: Dictionary) -> Array[String]:
	var liste: Array[String] = []
	for k: Dictionary in gun.get("kurallar", []):
		var tur := str(k.get("tur", ""))
		var adaylar: Array[String] = []
		if tur == "alan_esit":
			for alan: String in k.get("alanlar", []):
				adaylar.append("baba_adi" if alan == "baba_adi" else "ad_soyad")
		elif tur == "vize":
			adaylar.append("vize")
			adaylar.append("sahte")
		elif KURAL_GEREKCESI.has(tur):
			adaylar.append(KURAL_GEREKCESI[tur])
		for g in adaylar:
			if not liste.has(g):
				liste.append(g)
	return liste


# --- İnceleme modu: iki hedefin karşılaştırılması ---

## a ve b, Hedef.ozet() sözlükleridir: {tip, anahtar, deger, belge, kural, etiket}
## Dönüş: {durum: "uyusmaz"|"uyumlu"|"ilgisiz", mesaj, gerekce}
static func karsilastir(a: Dictionary, b: Dictionary, v: Dictionary, gun: Dictionary) -> Dictionary:
	if a.tip == "alan" and b.tip == "alan":
		return _alan_alan(a, b, gun)
	# vatandaşın yüzü ↔ arananlar sayfasındaki fotoğraf
	var yuz := a if a.tip == "yuz" else (b if b.tip == "yuz" else {})
	var kural_hedefi := a if a.tip == "kural" else (b if b.tip == "kural" else {})
	if not yuz.is_empty() and not kural_hedefi.is_empty() and str(kural_hedefi.kural.get("tur", "")) == "arananlar":
		var portre := str(v.get("portre", ""))
		var listede := not aranan_kaydi(portre, kural_hedefi.kural).is_empty()
		# kural satırına tıklandıysa bütün liste, resme tıklandıysa yalnızca o şahıs sorulur
		if str(kural_hedefi.anahtar) == portre or (str(kural_hedefi.anahtar) == "arananlar" and listede):
			return {"durum": "uyusmaz", "gerekce": "aranan", "mesaj": "DİKKAT: Camdaki kişi arananlar listesinde. Müdüre havale edin."}
		if str(kural_hedefi.anahtar) == "arananlar":
			return {"durum": "uyumlu", "mesaj": "Sorun yok: camdaki kişi arananlar listesinde görünmüyor."}
		return {"durum": "uyumlu", "mesaj": "Sorun yok: camdaki kişi resimdeki şahsa benzemiyor."}
	if a.tip != "alan" and b.tip != "alan":
		return ILGISIZ
	var alan := a if a.tip == "alan" else b
	var diger := b if a.tip == "alan" else a
	# bilgi defterindeki örnekle karşılaştırma: mühür, imza, kaşe, vize numarası
	if str(diger.tip) == "ornek":
		return _ornekle_karsilastir(alan, diger, v, gun)
	match str(diger.tip):
		"yuz":
			return _foto_yuz(alan, v, gun)
		"takvim":
			# vizenin son geçerlilik günü de takvimle karşılaştırılır
			if str(alan.anahtar) == "bitis":
				if Veri.kural(gun, "vize").is_empty():
					return {"durum": "ilgisiz", "mesaj": "Vizenin süresi için genelgede bir kural yok."}
				return _sahtelik_denetimi(alan, v, gun)
			return _tarih_denetimi(alan, Veri.kural(gun, "tarih_sure", str(alan.belge)), gun)
		"kural":
			return _alan_kural(alan, diger.kural, v, gun)
	return ILGISIZ


static func _alan_alan(a: Dictionary, b: Dictionary, gun: Dictionary) -> Dictionary:
	if a.belge == b.belge:
		return {"durum": "ilgisiz", "mesaj": "İki ayrı belgeden birer bilgi seçin."}
	# cüzdan ↔ çalışma vizesi: seri numarası, doğum tarihi ve imza birebir aynı olmalı
	if a.anahtar == b.anahtar and VIZE_ALANLARI.has(a.anahtar) and (a.belge == "calisma_vizesi" or b.belge == "calisma_vizesi"):
		var etiket: String = VIZE_ALANLARI[a.anahtar]
		var ayni := str(a.deger) == str(b.deger)
		if a.anahtar == "imza":
			ayni = Imza.kod(str(a.deger)) == Imza.kod(str(b.deger))      # kontrol() ile aynı ölçü
		if ayni:
			return {"durum": "uyumlu", "mesaj": "Sorun yok: %s iki belgede de aynı." % Stil.kucuk(etiket)}
		if Veri.kural(gun, "vize").is_empty():
			return {"durum": "ilgisiz", "mesaj": "%s farklı; ama genelgede bunu arayan bir kural yok." % etiket}
		return {"durum": "uyusmaz", "gerekce": "sahte", "mesaj": "Uyuşmazlık: %s cüzdandakiyle aynı değil. Vize sahte olabilir." % Stil.kucuk(etiket)}
	if a.anahtar != b.anahtar or not ALAN_ADLARI.has(a.anahtar):
		return {"durum": "ilgisiz", "mesaj": "Bu iki bilgi birbiriyle karşılaştırılmaz."}
	var ad: String = ALAN_ADLARI[a.anahtar]
	if str(a.deger) == str(b.deger):
		return {"durum": "uyumlu", "mesaj": "Sorun yok: %s iki belgede de aynı." % ad}
	var gerekce := "baba_adi" if a.anahtar == "baba_adi" else "ad_soyad"
	if not gunun_gerekceleri(gun).has(gerekce):
		return {"durum": "ilgisiz", "mesaj": "%s farklı yazılmış; ama genelgede bunu arayan bir kural yok." % ad}
	return {"durum": "uyusmaz", "gerekce": gerekce,
		"mesaj": "Uyuşmazlık: %s tutmuyor (%s ≠ %s)." % [ad, str(a.deger), str(b.deger)]}


static func _foto_yuz(alan: Dictionary, v: Dictionary, gun: Dictionary) -> Dictionary:
	if alan.anahtar != "foto":
		return {"durum": "ilgisiz", "mesaj": "Yüzle ancak cüzdandaki fotoğraf karşılaştırılır."}
	if str(alan.deger) == str(v.get("portre", "")):
		return {"durum": "uyumlu", "mesaj": "Sorun yok: fotoğraf başvuran kişiye ait."}
	if Veri.kural(gun, "foto_eslesme").is_empty():
		return {"durum": "ilgisiz", "mesaj": "Fotoğraf pek benzemiyor; ama genelgede bunu arayan bir kural yok."}
	return {"durum": "uyusmaz", "gerekce": "foto", "mesaj": "Uyuşmazlık: fotoğraftaki kişi başvuran değil."}


static func _tarih_denetimi(alan: Dictionary, kural: Dictionary, gun: Dictionary) -> Dictionary:
	if alan.anahtar != "tarih":
		return {"durum": "ilgisiz", "mesaj": "Takvimle ancak belgenin düzenlenme tarihi karşılaştırılır."}
	if kural.is_empty():
		return {"durum": "ilgisiz", "mesaj": "Bu belgenin tarihi için genelgede bir süre kuralı yok."}
	var bugun := str(gun.get("tarih", ""))
	var en_eski := en_eski_gecerli(bugun, kural)
	if tarih_gecerli(str(alan.deger), bugun, kural):
		return {"durum": "uyumlu", "mesaj": "Sorun yok: belge süresi içinde (en eski geçerli tarih %s)." % en_eski}
	if Tarih.gun_no(str(alan.deger)) > Tarih.gun_no(bugun):
		return {"durum": "uyusmaz", "gerekce": "sure", "mesaj": "Uyuşmazlık: belgeye ileri bir tarih atılmış."}
	return {"durum": "uyusmaz", "gerekce": "sure",
		"mesaj": "Uyuşmazlık: belge çok eski. En erken %s tarihli olmalıydı." % en_eski}


static func _alan_kural(alan: Dictionary, kural: Dictionary, v: Dictionary, gun: Dictionary) -> Dictionary:
	var belgeler := belge_sozlugu(v)
	match str(kural.get("tur", "")):
		"alan_esit":
			return {"durum": "ilgisiz", "mesaj": "Bu kural için iki ayrı belgedeki aynı bilgiyi seçin."}
		"belge_zorunlu":
			return {"durum": "ilgisiz", "mesaj": "Eksik belge varsa fişle doğrudan geri çevirin."}
		"arananlar":
			if alan.anahtar == "foto":
				return {"durum": "ilgisiz", "mesaj": "Cüzdan fotoğrafı yanıltabilir; aranan resmini camdaki yüzle karşılaştırın."}
			return {"durum": "ilgisiz", "mesaj": "Aranan resmini, camın ardındaki vatandaşın yüzüyle karşılaştırın."}
		"foto_eslesme":
			return {"durum": "ilgisiz", "mesaj": "Fotoğrafı, camın ardındaki vatandaşın yüzüyle karşılaştırın."}
		"tarih_sure":
			if alan.anahtar == "tarih" and str(alan.belge) == str(kural.get("belge", "")):
				return _tarih_denetimi(alan, kural, gun)
		"muhur_zorunlu":
			if alan.anahtar == "muhtar_muhur":
				if bool(alan.deger):
					return {"durum": "uyumlu", "mesaj": "Sorun yok: muhtar mührü yerinde."}
				return {"durum": "uyusmaz", "gerekce": "muhur", "mesaj": "Uyuşmazlık: muhtar mührü basılmamış."}
			if alan.anahtar == "muhtar_imza" and bool(kural.get("imza", false)):
				if bool(alan.deger):
					return {"durum": "uyumlu", "mesaj": "Sorun yok: muhtar imzası yerinde."}
				return {"durum": "uyusmaz", "gerekce": "muhur", "mesaj": "Uyuşmazlık: muhtar imzası atılmamış."}
		"harc_tutar":
			if str(alan.belge) == "harc_makbuzu" and (alan.anahtar == "tutar" or alan.anahtar == "islem"):
				var m: Dictionary = belgeler.get("harc_makbuzu", {})
				var islem := str(_alan(m, "islem"))
				var beklenen := harc(kural, islem)
				var odenen := int(_alan(m, "tutar", 0))
				if beklenen == odenen:
					return {"durum": "uyumlu", "mesaj": "Sorun yok: %s harcı %s." % [Islemler.adi(islem), Stil.tl(beklenen)]}
				return {"durum": "uyusmaz", "gerekce": "harc", "mesaj": "Uyuşmazlık: %s harcı %s olmalı, makbuzda %s yazıyor." % [
					Islemler.adi(islem), Stil.tl(beklenen), Stil.tl(odenen)]}
		"sahtecilik", "vize":
			var s := _sahtelik_denetimi(alan, v, gun)
			if not s.is_empty():
				return s
		"seri_aralik":
			if alan.anahtar == "seri_no" and str(alan.belge) == "nufus_cuzdani":
				if seri_gecerli(str(alan.deger), kural):
					return {"durum": "uyumlu", "mesaj": "Sorun yok: seri numarası geçerli."}
				return {"durum": "uyusmaz", "gerekce": "seri", "mesaj": "Uyuşmazlık: %s geçerli seriler arasında yok." % str(alan.deger)}
		"mahalle_listesi":
			if alan.anahtar == "mahalle":
				if mahalle_gecerli(str(alan.deger), kural):
					return {"durum": "uyumlu", "mesaj": "Sorun yok: %s Mahallesi ilçemize bağlı." % str(alan.deger)}
				return {"durum": "uyusmaz", "gerekce": "mahalle", "mesaj": "Uyuşmazlık: %s Mahallesi listede yok." % str(alan.deger)}
	return {"durum": "ilgisiz", "mesaj": "Bu bilgi bu kuralla ilgili değil."}


## Belge alanını bilgi defterindeki örnekle karşılaştırır. Örnek hedefinin anahtarı neyin örneği olduğunu
## söyler: "muhur", "imza:<kişi>", "kase_vezne", "kase_vize", "vize_no".
static func _ornekle_karsilastir(alan: Dictionary, ornek: Dictionary, v: Dictionary, gun: Dictionary) -> Dictionary:
	var konu := str(ornek.anahtar)
	var uygun := {
		"muhur": ["muhtar_muhur"], "kase_vezne": ["kase"], "kase_vize": ["vize_kase"], "vize_no": ["vize_no"],
	}
	if konu.begins_with("imza:"):
		# defterdeki imza örnekleri muhtarlarındır: hamilin imzası onlarla kıyaslanmaz
		if str(alan.anahtar) == "imza":
			return {"durum": "ilgisiz", "mesaj": "Bu örnek bir muhtarın imzası. Hamilin imzasını cüzdandaki imzayla karşılaştırın."}
		if str(alan.anahtar) != "muhtar_imza":
			return {"durum": "ilgisiz", "mesaj": "İmza örneği ancak bir imzayla karşılaştırılır."}
		var kimin := konu.trim_prefix("imza:")
		var imzalayan := str(alan.deger)
		if str(alan.anahtar) == "muhtar_imza":
			var ik: Dictionary = belge_sozlugu(v).get("ikametgah", {})
			if not bool(_alan(ik, "muhtar_imza", false)):
				return {"durum": "ilgisiz", "mesaj": "Belgede imza yok."}
			imzalayan = str(_alan(ik, "imza_sahibi", _alan(ik, "muhtar")))
			if Imza.kod(kimin) != Imza.kod(str(_alan(ik, "muhtar"))):
				return {"durum": "ilgisiz", "mesaj": "Bu örnek başka muhtarın. Belgede adı yazan muhtarın örneğine bakın."}
		if Imza.kod(imzalayan) == Imza.kod(kimin):
			return {"durum": "uyumlu", "mesaj": "Sorun yok: imza örnekle aynı elden çıkmış."}
		return {"durum": "uyusmaz", "gerekce": "sahte", "mesaj": "Uyuşmazlık: imza örnektekine benzemiyor. Başkası atmış."}
	if not uygun.has(konu) or not (uygun[konu] as Array).has(str(alan.anahtar)):
		return {"durum": "ilgisiz", "mesaj": "Bu örnek bu bilgiyle karşılaştırılmaz."}
	var s := _sahtelik_denetimi(alan, v, gun)
	return s if not s.is_empty() else ILGISIZ


## Mühür, imza, kaşe ve vize numarası için "gerçek mi" denetimi (ipucu). İlgisiz alanda boş sözlük döner.
static func _sahtelik_denetimi(alan: Dictionary, v: Dictionary, gun: Dictionary) -> Dictionary:
	var belgeler := belge_sozlugu(v)
	var bugun := str(gun.get("tarih", ""))
	match str(alan.anahtar):
		"muhtar_muhur":
			var ik: Dictionary = belgeler.get("ikametgah", {})
			if not bool(_alan(ik, "muhtar_muhur", false)):
				return {"durum": "ilgisiz", "mesaj": "Belgede mühür yok."}
			var tur := str(_alan(ik, "muhur_turu"))
			if tur == "":
				return {"durum": "uyumlu", "mesaj": "Sorun yok: mühür örneğe uyuyor."}
			return {"durum": "uyusmaz", "gerekce": "sahte", "mesaj": "Uyuşmazlık: mühür sahte (%s)." % Stil.kucuk(Damga.sahte_aciklamasi("muhtar", tur))}
		"muhtar_imza":
			var ik: Dictionary = belgeler.get("ikametgah", {})
			if not bool(_alan(ik, "muhtar_imza", false)):
				return {"durum": "ilgisiz", "mesaj": "Belgede imza yok."}
			if Imza.kod(str(_alan(ik, "imza_sahibi", _alan(ik, "muhtar")))) == Imza.kod(str(_alan(ik, "muhtar"))):
				return {"durum": "uyumlu", "mesaj": "Sorun yok: imza muhtarın kendi imzası."}
			return {"durum": "uyusmaz", "gerekce": "sahte", "mesaj": "Uyuşmazlık: imza bu muhtarın imzası değil."}
		"kase":
			var tur := str(_alan(belgeler.get("harc_makbuzu", {}), "kase_turu"))
			if tur == "":
				return {"durum": "uyumlu", "mesaj": "Sorun yok: vezne kaşesi örneğe uyuyor."}
			return {"durum": "uyusmaz", "gerekce": "sahte", "mesaj": "Uyuşmazlık: vezne kaşesi sahte (%s)." % Stil.kucuk(Damga.sahte_aciklamasi("vezne", tur))}
		"vize_kase":
			var tur := str(_alan(belgeler.get("calisma_vizesi", {}), "kase_turu"))
			if tur == "":
				return {"durum": "uyumlu", "mesaj": "Sorun yok: konsolosluk kaşesi örneğe uyuyor."}
			return {"durum": "uyusmaz", "gerekce": "sahte", "mesaj": "Uyuşmazlık: konsolosluk kaşesi sahte (%s)." % Stil.kucuk(Damga.sahte_aciklamasi("vize", tur))}
		"vize_no":
			var kural := Veri.kural(gun, "vize")
			if kural.is_empty():
				return {}
			if vize_no_gecerli(str(alan.deger), kural):
				return {"durum": "uyumlu", "mesaj": "Sorun yok: vize numarası geçerli."}
			return {"durum": "uyusmaz", "gerekce": "sahte", "mesaj": "Uyuşmazlık: %s verilmiş vize numaraları arasında yok." % str(alan.deger)}
		"bitis":
			if Tarih.gun_no(str(alan.deger)) >= Tarih.gun_no(bugun):
				return {"durum": "uyumlu", "mesaj": "Sorun yok: vizenin süresi dolmamış."}
			return {"durum": "uyusmaz", "gerekce": "vize", "mesaj": "Uyuşmazlık: vizenin süresi %s günü dolmuş." % str(alan.deger)}
	return {}


# --- Tekil denetimler (üretici ve testler de kullanır) ---

## İkametgâh ve makbuzdaki sahte mühür, imza ve kaşeler: [{kod, aciklama, belge, alan}]
static func sahtecilik_hatalari(belgeler: Dictionary) -> Array[Dictionary]:
	var sonuc: Array[Dictionary] = []
	if belgeler.has("ikametgah"):
		var ik: Dictionary = belgeler["ikametgah"]
		var tur := str(_alan(ik, "muhur_turu"))
		if bool(_alan(ik, "muhtar_muhur", false)) and tur != "":
			sonuc.append({"kod": "muhur_sahte", "belge": "ikametgah", "alan": "muhtar_muhur",
				"aciklama": "İkametgâhtaki muhtar mührü sahteydi (%s)." % Stil.kucuk(Damga.sahte_aciklamasi("muhtar", tur))})
		var muhtar := str(_alan(ik, "muhtar"))
		var imzalayan := str(_alan(ik, "imza_sahibi", muhtar))
		if bool(_alan(ik, "muhtar_imza", false)) and Imza.kod(imzalayan) != Imza.kod(muhtar):
			sonuc.append({"kod": "imza_sahte", "belge": "ikametgah", "alan": "muhtar_imza",
				"aciklama": "İkametgâhtaki imza muhtar %s'in imzası değildi." % muhtar})
	if belgeler.has("harc_makbuzu"):
		var tur := str(_alan(belgeler["harc_makbuzu"], "kase_turu"))
		if tur != "":
			sonuc.append({"kod": "kase_sahte", "belge": "harc_makbuzu", "alan": "kase",
				"aciklama": "Makbuzdaki vezne kaşesi sahteydi (%s)." % Stil.kucuk(Damga.sahte_aciklamasi("vezne", tur))})
	return sonuc


## Çalışma vizesindeki kusurlar: [{kod, gerekce, aciklama, alan}]. Süresi geçmiş vize "vize", gerisi "sahte"dir.
static func vize_hatalari(belgeler: Dictionary, bugun: String, kural: Dictionary) -> Array[Dictionary]:
	var sonuc: Array[Dictionary] = []
	var vize: Dictionary = belgeler.get("calisma_vizesi", {})
	var cuzdan: Dictionary = belgeler.get("nufus_cuzdani", {})
	var no := str(_alan(vize, "vize_no"))
	if not vize_no_gecerli(no, kural):
		sonuc.append({"kod": "vize_no", "gerekce": "sahte", "alan": "vize_no",
			"aciklama": "Vize numarası (%s) verilmiş numaralar arasında yoktu." % no})
	if str(_alan(vize, "kase_turu")) != "":
		sonuc.append({"kod": "vize_kase", "gerekce": "sahte", "alan": "vize_kase",
			"aciklama": "Vizedeki konsolosluk kaşesi sahteydi (%s)." % Stil.kucuk(Damga.sahte_aciklamasi("vize", str(_alan(vize, "kase_turu"))))})
	if not cuzdan.is_empty():
		for alan: String in ["seri_no", "dogum_tarihi"]:
			if str(_alan(vize, alan)) != str(_alan(cuzdan, alan)):
				sonuc.append({"kod": "vize_kimlik", "gerekce": "sahte", "alan": alan,
					"aciklama": "Vizedeki %s cüzdandakiyle aynı değildi." % Stil.kucuk(str(VIZE_ALANLARI[alan]))})
				break
		if Imza.kod(str(_alan(vize, "imza"))) != Imza.kod(str(_alan(cuzdan, "imza"))):
			sonuc.append({"kod": "vize_imza", "gerekce": "sahte", "alan": "imza",
				"aciklama": "Vizedeki imza cüzdandaki imzayla aynı elden çıkmamıştı."})
	var bitis := str(_alan(vize, "bitis"))
	if Tarih.gun_no(bitis) < Tarih.gun_no(bugun):
		sonuc.append({"kod": "vize_sure", "gerekce": "vize", "alan": "bitis",
			"aciklama": "Çalışma vizesinin süresi %s günü dolmuştu." % bitis})
	return sonuc


## "ÇV-84-03127": önek ve yıl kurala uymalı, numara verilmiş aralıkta olmalı.
static func vize_no_gecerli(no: String, kural: Dictionary) -> bool:
	var b: Dictionary = kural.get("no", {})
	var p := no.split("-")
	if p.size() != 3 or not p[1].is_valid_int() or not p[2].is_valid_int() or p[2].length() != 5:
		return false
	return p[0] == str(b.get("onek", "ÇV")) and int(p[1]) == int(b.get("yil", 84)) \
		and int(p[2]) >= int(b.get("min", 0)) and int(p[2]) <= int(b.get("max", 99999))


static func tarih_gecerli(tarih: String, bugun: String, kural: Dictionary) -> bool:
	if kural.has("ay"):
		return Tarih.ay_icinde_mi(tarih, bugun, int(kural.ay))
	return Tarih.gun_icinde_mi(tarih, bugun, int(kural.get("gun", 0)))


static func en_eski_gecerli(bugun: String, kural: Dictionary) -> String:
	if kural.has("ay"):
		return Tarih.ay_ekle(bugun, -int(kural.ay))
	return Tarih.gun_ekle(bugun, -int(kural.get("gun", 0)))


static func seri_gecerli(seri: String, kural: Dictionary) -> bool:
	var p := seri.split("-")
	if p.size() != 2 or not p[1].is_valid_int():
		return false
	var no := int(p[1])
	for a: Dictionary in kural.get("araliklar", []):
		if str(a.onek) == p[0] and no >= int(a.min) and no <= int(a.max):
			return true
	return false


## Portre arananlar listesindeyse o kaydı döndürür (yoksa boş sözlük).
static func aranan_kaydi(portre: String, kural: Dictionary) -> Dictionary:
	for a: Dictionary in kural.get("liste", []):
		if str(a.get("portre", "")) == portre:
			return a
	return {}


static func mahalle_gecerli(mahalle: String, kural: Dictionary) -> bool:
	return (kural.get("mahalleler", []) as Array).has(mahalle)


static func harc(kural: Dictionary, islem: String) -> int:
	return int((kural.get("tutarlar", {}) as Dictionary).get(islem, -1))


static func belge_adi(tur: String) -> String:
	return BELGE_ADLARI.get(tur, tur)


## Vatandaşın belgeleri: tür → belge sözlüğü.
static func belge_sozlugu(v: Dictionary) -> Dictionary:
	var s := {}
	for b: Dictionary in v.get("belgeler", []):
		s[str(b.get("tur", ""))] = b
	return s


static func _alan(belge: Dictionary, anahtar: String, yedek: Variant = "") -> Variant:
	return (belge.get("alanlar", {}) as Dictionary).get(anahtar, yedek)


## Bir alanın belgelerde aldığı farklı değerler (hepsi aynıysa tek öğe).
static func _alan_degerleri(belgeler: Dictionary, alan: String) -> Array[String]:
	var gorulen: Array[String] = []
	for t: String in belgeler:
		var al: Dictionary = (belgeler[t] as Dictionary).get("alanlar", {})
		if al.has(alan) and not gorulen.has(str(al[alan])):
			gorulen.append(str(al[alan]))
	return gorulen


static func _hata(kod: String, gerekce: String, aciklama: String, kural: Dictionary,
		belge: String = "", alan: String = "") -> Dictionary:
	return {"kod": kod, "gerekce": gerekce, "aciklama": aciklama, "kural": str(kural.get("id", "")),
		"belge": belge, "alan": alan}
