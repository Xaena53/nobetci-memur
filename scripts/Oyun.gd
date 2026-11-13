extends Node
## Oyun (Autoload) — kalıcı oyun durumu, kayıt/yükleme, ayarlar ve sahne geçişleri.
## Sahneler bu düğüme "Oyun" adıyla her yerden ulaşır.

signal durum_degisti
signal ayarlar_degisti

const SURUM := 3                ## kayıt biçimi: 3 = imzalı zarf (bkz. kaydet)
const TOPLAM_GUN := 7
const BASLANGIC_PARASI := 500

# --- Maaş ---
const YEVMIYE := 350            ## mesaiye gelmenin karşılığı
const PRIM := 100               ## doğru sonuçlanan her işlem için
const SUPHELI_PRIMI := 50       ## sahteciliği müdüre havale etmenin ek primi
const IHTAR_ESIGI := 3          ## günde bu kadarıncı ihtardan itibaren maaş kesilir
const KESINTI_ILK := 200        ## eşik aşılınca ilk kesinti
const KESINTI_SONRAKI := 100    ## eşikten sonraki her ihtar için

# --- Sonlar ---
const SURGUN_IHTARI := 14       ## toplam ihtar bu sayıya varınca sürgün
const SURGUN_SUPHESI := 4       ## şüphe bu düzeye varınca sürgün
const TERFI_IHTARI := 6         ## terfi için en çok bu kadar ihtar
const TERFI_SUPHESI := 1        ## terfi için en çok bu kadar şüphe

# --- Görev şekli (zorluk) ---
## ipucu: inceleme modunda karşılaştırma sonucunun söylenmesi (−1: her zaman, 0: hiç, n: günde n hak).
## saat: mesai saatinin ağırlığı (1'den büyükse gün uzar). zorluk_farki: sahteciliklerin inceliğine eklenir.
const KIPLER := {
	"kolay": {"ad": "Kolay", "ipucu": -1, "saat": 1.3, "zorluk_farki": -1,
		"aciklama": "Her karşılaştırmada ipucu; saat ağır işler."},
	"orta": {"ad": "Orta", "ipucu": 3, "saat": 1.0, "zorluk_farki": 0,
		"aciklama": "Günde üç ipucu hakkı; gerisi sizin gözünüz."},
	"zor": {"ad": "Zor", "ipucu": 0, "saat": 1.0, "zorluk_farki": 1,
		"aciklama": "İpucu yok. Defter, büyüteç ve siz."},
}

## Kayıt dosyasının sınırları: bundan büyük dosya okunmaz, alanlar bu aralıklara çekilir.
const KAYIT_BOYUT_SINIRI := 256 * 1024
const PARA_SINIRI := 1_000_000
const IHTAR_SINIRI := 999
const SUPHE_SINIRI := 99
const BAYRAK_SINIRI := 128         ## en çok bu kadar hikâye bayrağı saklanır
## Kayıt imzasının anahtarı. Dosyanın elle değiştirilmesini ve bozulmasını yakalar; oyunun paketini
## açan biri anahtarı bulabilir, yani gerçek bir kilit sayılmaz.
const _IMZA_ANAHTARI := "ardicli-nufus-md-1984/2-numarali-gise/kayit"
## Ayarların geçerli aralıkları (dosyadan gelen değer bu aralığa çekilir).
const AYAR_ARALIKLARI := {
	"saat_hizi": [0.4, 2.5],
	"ses_genel": [0.0, 1.0],
	"ses_efekt": [0.0, 1.0],
	"ses_konusma": [0.0, 1.0],
	"ses_muzik": [0.0, 1.0],
	"ses_ortam": [0.0, 1.0],
	"yazi_hizi": [0.4, 100.0],
	"fare_hassasiyeti": [0.5, 2.0],
}
## Yalnızca belirli değerleri alabilen ayarlar (dosyadan başka bir değer gelirse varsayılana dönülür).
const AYAR_SECENEKLERI := {
	"pencere_boyutu": ["1280x720", "1600x900", "1920x1080"],
	"kare_siniri": [0, 30, 60, 120],
	"efekt_kalitesi": ["dusuk", "orta", "yuksek"],
	"doku_kalitesi": ["dusuk", "yuksek"],
}
const SAHNELER := {
	"menu": "res://scenes/AnaMenu.tscn",
	"masa": "res://scenes/Masa.tscn",
	"gun_sonu": "res://scenes/GunSonu.tscn",
	"aile": "res://scenes/Aile.tscn",
	"son": "res://scenes/Son.tscn",
}
const VARSAYILAN_AYARLAR := {
	# --- ses ---
	"ses_genel": 0.8,
	"ses_efekt": 0.9,
	"ses_konusma": 0.8,        ## vatandaşların mırıltısı ve iç çekişi
	"ses_muzik": 0.5,          ## radyo ve menü müziği
	"ses_ortam": 0.6,          ## soba, rüzgâr
	"muzik_acik": true,
	# --- görüntü ---
	"tam_ekran": false,
	"pencere_boyutu": "1280x720",
	"dikey_esleme": true,
	"kare_siniri": 0,          ## saniyedeki en çok kare (0: sınır yok)
	"efekt_kalitesi": "yuksek",    ## kar, duman gibi süsler: "dusuk" | "orta" | "yuksek"
	"doku_kalitesi": "yuksek",     ## arka planlar: "dusuk" iken yarı çözünürlükte yüklenir (bkz. Gorsel)
	"dusuk_cozunurluk": false,     ## oyun 1280×720 çizilip pencereye büyütülür (zayıf ekran kartları için)
	"otomatik_kalite": true,       ## kare hızı düşük kalırsa oyun kaliteyi kendiliğinden kısar
	"ekran_sarsintisi": true,  ## mühür inince masanın sarsılması
	"titreme": true,           ## cızırdayan lamba, yanıp sönen uyarı ışıkları
	# --- oyun ---
	"saat_hizi": 1.0,          ## oyun dakikası başına gerçek saniye (küçüldükçe gün hızlanır)
	"yazi_hizi": 1.0,          ## genelge, konuşma ve teleks yazısının hızı (100: anında)
	"odakta_mola": true,       ## pencere arka plana geçince kendiliğinden mola
	"fare_hassasiyeti": 1.0,   ## imlecin hızı (1: işletim sistemindeki gibi)
}

var kayit_yolu := "user://kayit.json"  ## testler kendi dosyasını kullanır
var ayar_yolu := "user://ayarlar.json"

var gun: int = 1
var zorluk := "kolay"              ## görev şekli: "kolay" | "orta" | "zor" (bkz. KIPLER)
var para: int = BASLANGIC_PARASI
var ihtar: int = 0                 ## oyun boyunca alınan toplam ihtar
var suphe: int = 0                 ## rüşvet ve kayırma yüzünden biriken şüphe
var tohum: int = 0                 ## bu oyunun rastgelelik tohumu (günler aynı kayıtta aynı çıkar)
var gorulen_portreler: Array = []  ## gişeye gelmiş vatandaşların portreleri (yüzler tekrar etmesin)
var aile: Dictionary = {}          ## bkz. AileDurumu
var bayraklar: Dictionary = {}     ## hikâye olayları ("husnu_onaylandi": 3 gibi)
var toplam: Dictionary = {}        ## oyun geneli sayaçlar
var gun_ozeti: Dictionary = {}     ## biten mesainin özeti (Gün Sonu ekranı okur)
var son: Dictionary = {}           ## oyun bittiyse: {tur, neden}
var asama := "masa"                ## kayıtlı aşama: "masa" (gün başı) | "gun_sonu" (mesai kapandı) | "son" (oyun bitti)
var mesai_basladi := false         ## bu günün gişesi açıldı mı (açılmış gün kayıttan sürdürülürse kuyruk değişir)
var gun_denemesi := 0              ## bu günün kaçıncı kez baştan oynandığı (kuyruğun tohumuna girer)
var ayarlar: Dictionary = VARSAYILAN_AYARLAR.duplicate()

var _perde: ColorRect
var _geciste := false
var _katman: CanvasLayer
var _mola: MolaMenusu
var _son_kayit: Dictionary = {}    ## dosyaya en son yazılan durum
var odak_sinamasi := false         ## testler: başsız kipte de odak kaybı molasını dene
var _olculen_sahne := 0            ## kare hızı ölçülen sahnenin kimliği
var _olcum_suresi := 0.0
var _olcum_karesi := 0
var _dusuk_pencere := 0            ## üst üste düşük çıkan ölçüm penceresi sayısı
var _isinlanan := Vector2(-1, -1)  ## fare hassasiyeti: imleci en son taşıdığımız yer
var _gorunurluk_geri_cagrisi: Variant   ## Web: sekme gizlenince çağrılan JavaScript işlevi (başvurusu yaşamalı)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.theme = Stil.tema()
	get_tree().auto_accept_quit = false     # pencere kapanırken önce sesler susturulur (bkz. cik)
	_perde_kur()
	ayarlari_yukle()
	_pencereyi_boyutla()
	_sekme_gorunurlugunu_izle()


## Web: tarayıcı sekmesi gizlenince (başka sekmeye geçildi, pencere küçültüldü) oyun mola verir.
## Tarayıcıda uygulama odağı bildirimi gelmediği için sayfanın kendi "visibilitychange" olayı dinlenir.
func _sekme_gorunurlugunu_izle() -> void:
	if not OS.has_feature("web"):
		return
	var belge: Variant = JavaScriptBridge.get_interface("document")
	if belge == null:
		return
	_gorunurluk_geri_cagrisi = JavaScriptBridge.create_callback(func(_args: Array) -> void:
		if bool(JavaScriptBridge.eval("document.hidden", true)):
			odak_sinamasi = true
			arka_plana_gecildi()
			odak_sinamasi = false)
	belge.addEventListener("visibilitychange", _gorunurluk_geri_cagrisi)


## Fare hassasiyeti: imleç, farenin gerçek hareketinin `fare_hassasiyeti` katı kadar ilerler. İşletim
## sisteminin imleci kullanılmaya devam eder; her harekette aradaki fark kadar ileri (ya da geri) taşınır.
## Hassasiyet 1 iken hiçbir şey yapılmaz. Tarayıcıda imleç taşınamadığı için orada etkisizdir.
func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseMotion):
		return
	var h := float(ayar("fare_hassasiyeti"))
	if is_equal_approx(h, 1.0) or OS.has_feature("web") or DisplayServer.get_name() == "headless":
		return
	var e := event as InputEventMouseMotion
	if _isinlanan.x >= 0.0 and e.position.distance_to(_isinlanan) < 2.0:
		_isinlanan = Vector2(-1, -1)        # bu hareketi biz yaptık: yeniden ölçeklenmez
		return
	if e.relative.length() > 240.0:
		return                              # sıçrama (pencereye yeni girildi): ölçeklenmez
	var hedef := fare_hedefi(e.position, e.relative, h, get_viewport().get_visible_rect())
	if hedef.distance_to(e.position) < 0.5:
		return
	_isinlanan = hedef
	get_viewport().warp_mouse(hedef)


## Hassasiyet uygulanmış imleç konumu: gerçek hareketin `h` katı, görünümün içinde kalacak biçimde.
func fare_hedefi(konum: Vector2, hareket: Vector2, h: float, alan: Rect2) -> Vector2:
	var hedef := konum + hareket * (h - 1.0)
	return Vector2(clampf(hedef.x, alan.position.x, alan.end.x - 1.0), clampf(hedef.y, alan.position.y, alan.end.y - 1.0))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		cik()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		arka_plana_gecildi()


## Pencere odağını yitirdi (ya da tarayıcı sekmesi gizlendi): mesai saati oyuncunun haberi olmadan
## işlemesin diye oyun kendiliğinden mola verir. Ayarlardan kapatılabilir.
func arka_plana_gecildi() -> void:
	if bool(ayar("odakta_mola")) and mola_verilebilir() and (odak_sinamasi or _odak_izlenir()):
		mola_ver()


## Odak kaybında kendiliğinden mola verilsin mi? (Başsız kipte ve odak almayan test penceresinde hayır.)
func _odak_izlenir() -> bool:
	return DisplayServer.get_name() != "headless" \
		and not DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS)


## Oyundan çıkar: sesleri susturur, bir an bekleyip kapatır.
func cik(kod: int = 0) -> void:
	Ses.sustur()
	get_tree().create_timer(0.25, true).timeout.connect(get_tree().quit.bind(kod))


# --- Mola (ESC) ---

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		ayar_degistir("tam_ekran", not bool(ayar("tam_ekran")))
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F12:
		ekran_goruntusu_al()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if is_instance_valid(_mola):
			_mola.geri()
			get_viewport().set_input_as_handled()
		elif mola_verilebilir():
			mola_ver()
			get_viewport().set_input_as_handled()


## F12: ekranın görüntüsünü kullanıcı klasörüne kaydeder (mağaza sayfası için). Yolu döndürür.
func ekran_goruntusu_al() -> String:
	if DisplayServer.get_name() == "headless":
		return ""
	var klasor := "user://ekran_goruntuleri"
	DirAccess.make_dir_recursive_absolute(klasor)
	var damga := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var yol := "%s/nobetci_memur_%s.png" % [klasor, damga]
	get_viewport().get_texture().get_image().save_png(yol)
	print("Ekran görüntüsü kaydedildi: ", ProjectSettings.globalize_path(yol))
	Ses.cal("daktilo", 0.8, -8.0)
	return yol


## Mola yalnızca oyunun içinde (masa, gün sonu, ev) verilir.
func mola_verilebilir() -> bool:
	var sahne := get_tree().current_scene
	return not _geciste and sahne != null and str(sahne.name) in ["Masa", "GunSonu", "Aile"]


func mola_ver() -> void:
	if is_instance_valid(_mola):
		return
	get_tree().paused = true
	_mola = MolaMenusu.new()
	_katman.add_child(_mola)
	_katman.move_child(_mola, 0)        # geçiş perdesi her şeyin üstünde kalır
	_mola.devam_edildi.connect(molayi_bitir)
	_mola.menuye_donuldu.connect(func() -> void:
		molayi_bitir()
		Ses.yalniz([])
		sahneye_gec("menu"))


func molayi_bitir() -> void:
	if is_instance_valid(_mola):
		_mola.queue_free()
	_mola = null
	get_tree().paused = false


# --- Oyun akışı ---

## Seçili görev şeklinin ayarları.
func kip() -> Dictionary:
	return KIPLER.get(zorluk, KIPLER.kolay)


## O günün verisi, görev şekline göre ayarlanmış hâliyle (sahteciliklerin inceliği kiple değişir).
func gunun_verisi(gun_no: int = -1) -> Dictionary:
	var g: Dictionary = Veri.gun(gun if gun_no < 0 else gun_no).duplicate(true)
	g["zorluk"] = clampi(int(g.get("zorluk", 1)) + int(kip().get("zorluk_farki", 0)), 1, 3)
	return g


func yeni_oyun(gorev_sekli: String = "kolay") -> void:
	zorluk = gorev_sekli if KIPLER.has(gorev_sekli) else "kolay"
	gun = 1
	para = BASLANGIC_PARASI
	ihtar = 0
	suphe = 0
	tohum = randi()
	gorulen_portreler = []
	aile = AileDurumu.yeni()
	bayraklar = {}
	toplam = {"islenen": 0, "dogru": 0, "yanlis": 0, "kazanc": 0}
	gun_ozeti = {}
	son = {}
	asama = "masa"
	mesai_basladi = false
	gun_denemesi = 0
	kaydet()
	durum_degisti.emit()


## Gişe açılınca çağrılır: kayda "bu günün mesaisi başladı" diye not düşer. Gün yarıda bırakılıp
## kayıttan sürdürülürse kuyruk başka vatandaşlarla kurulur: aynı günü ezberleyip baştan oynamak işe yaramaz.
## (Yazılan, gün başındaki kayıttır; gün içinde değişen para, bayrak gibi değerler dosyaya geçmez.)
func mesaiyi_isaretle() -> void:
	if mesai_basladi or _son_kayit.is_empty() or asama != "masa":
		return
	mesai_basladi = true
	var v := _son_kayit.duplicate(true)
	v["mesai_basladi"] = true
	_yaz(v)


## Mesai kapanınca: maaşı hesaplar, parayı ve ihtarları işler, günün özetini saklar ve kaydeder
## (kötü geçen gün, oyundan çıkıp kayıttan dönerek silinemez).
func mesaiyi_kapat(ozet: Dictionary) -> void:
	var maas := maas_hesapla(ozet)
	ozet["maas"] = maas
	ozet["para_once"] = para
	para += int(maas.net)
	ihtar += int(ozet.get("ihtar", 0))
	toplam["islenen"] = int(toplam.get("islenen", 0)) + int(ozet.get("islenen", 0))
	toplam["dogru"] = int(toplam.get("dogru", 0)) + int(ozet.get("dogru", 0))
	toplam["yanlis"] = int(toplam.get("yanlis", 0)) + int(ozet.get("yanlis", 0))
	toplam["kazanc"] = int(toplam.get("kazanc", 0)) + int(maas.net)
	gun_ozeti = ozet
	asama = "gun_sonu"
	kaydet()
	durum_degisti.emit()


## Günün maaşı: yevmiye + primler − ihtar kesintisi.
func maas_hesapla(ozet: Dictionary) -> Dictionary:
	var prim := int(ozet.get("kazanc", 0))
	var ihtar_sayisi := int(ozet.get("ihtar", 0))
	var kesinti := 0
	if ihtar_sayisi >= IHTAR_ESIGI:
		kesinti = KESINTI_ILK + (ihtar_sayisi - IHTAR_ESIGI) * KESINTI_SONRAKI
	return {"yevmiye": YEVMIYE, "prim": prim, "kesinti": kesinti, "net": YEVMIYE + prim - kesinti}


## Aile ekranından sonra çağrılır; son gün de bittiyse false döner.
func sonraki_gun() -> bool:
	if gun >= TOPLAM_GUN:
		return false
	gun += 1
	gun_ozeti = {}
	asama = "masa"
	mesai_basladi = false
	gun_denemesi = 0
	kaydet()
	durum_degisti.emit()
	return true


## Oyunu bitirecek bir durum var mı? Varsa {tur, neden} döner (yoksa boş).
## `gun_bitti`: son günün akşamı da geçtiyse terfi/olağan son da değerlendirilir.
func son_denetle(gun_bitti: bool = false) -> Dictionary:
	if para < 0:
		return {"tur": "kotu", "neden": "iflas"}
	if ihtar >= SURGUN_IHTARI:
		return {"tur": "surgun", "neden": "ihtar"}
	if suphe >= SURGUN_SUPHESI:
		return {"tur": "surgun", "neden": "suphe"}
	if gun_bitti and gun >= TOPLAM_GUN:
		if ihtar <= TERFI_IHTARI and suphe <= TERFI_SUPHESI:
			return {"tur": "terfi", "neden": "basari"}
		return {"tur": "olagan", "neden": "yerinde"}
	return {}


## Akşam ışık sönünce çağrılır: ertesi sabahın kaydını şimdiden yazar. Gece ekranında oyundan çıkılırsa
## akşamın harcamaları yeniden seçilemez; oyun ertesi sabahtan sürer.
func sabahi_kaydet() -> void:
	var v := kayit_verisi()
	v["gun"] = mini(gun + 1, TOPLAM_GUN)
	v["asama"] = "masa"
	v["mesai_basladi"] = false
	v["gun_denemesi"] = 0
	v.erase("gun_ozeti")
	_yaz(v)


## Oyunun sonu belli olunca (son ekranı gösterilmeden önce) çağrılır: kayıttan dönülürse doğrudan son gelir.
func sonu_kaydet(sonuc: Dictionary) -> void:
	son = sonuc
	asama = "son"
	kaydet()


func oyunu_bitir(sonuc: Dictionary) -> void:
	son = sonuc
	kaydi_sil()
	sahneye_gec("son")


## Gecikme: `await Oyun.bekle(0.5)`. Oyun duraklatılınca sayaç da durur; bekleyen sahne kapanırsa
## sayaç sessizce biter (SceneTreeTimer'ın aksine çıkışta artık bırakmaz).
func bekle(sure: float) -> Signal:
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = maxf(0.001, sure)
	t.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(t)
	t.timeout.connect(t.queue_free)
	t.start()
	return t.timeout


func bayrak(ad: String, yedek: Variant = false) -> Variant:
	return bayraklar.get(ad, yedek)


## O günün vatandaş kuyruğu için tohum: aynı kayıtta aynı gün hep aynı kuyruğu verir.
func gun_tohumu() -> int:
	return hash([tohum, gun, gun_denemesi])


# --- Kayıt / yükleme (user://kayit.json) ---

## Yüklenebilir bir kayıt var mı? (Bozuk ya da imzası tutmayan dosya kayıt sayılmaz; yedeğine bakılır.)
func kayit_var_mi() -> bool:
	return not _kayit_oku().is_empty()


func kayit_verisi() -> Dictionary:
	return {
		"surum": SURUM,
		"zorluk": zorluk,
		"gun": gun,
		"para": para,
		"ihtar": ihtar,
		"suphe": suphe,
		"tohum": tohum,
		"gorulen_portreler": gorulen_portreler,
		"aile": aile,
		"bayraklar": bayraklar,
		"toplam": toplam,
		"asama": asama,
		"mesai_basladi": mesai_basladi,
		"gun_denemesi": gun_denemesi,
		"gun_ozeti": gun_ozeti if asama == "gun_sonu" else {},
		"son": son if asama == "son" else {},
	}


## Kayıttan gelen sözlüğü oyun durumuna işler. Dosya dışarıdan geldiği için hiçbir alana güvenilmez:
## türü tutmayan alan varsayılana döner, sayılar geçerli aralığa çekilir, tanınmayan içerik atılır.
func kayittan_al(veri: Dictionary) -> void:
	gun = _tam(veri.get("gun"), 1, 1, TOPLAM_GUN)
	zorluk = str(veri.get("zorluk")) if typeof(veri.get("zorluk")) == TYPE_STRING and KIPLER.has(veri.get("zorluk")) else "kolay"
	para = _tam(veri.get("para"), BASLANGIC_PARASI, -PARA_SINIRI, PARA_SINIRI)
	ihtar = _tam(veri.get("ihtar"), 0, 0, IHTAR_SINIRI)
	suphe = _tam(veri.get("suphe"), 0, 0, SUPHE_SINIRI)
	tohum = _tam(veri.get("tohum"), 0, 0, 0xFFFFFFFF)
	gorulen_portreler = []
	var gorulen: Variant = veri.get("gorulen_portreler")
	if typeof(gorulen) == TYPE_ARRAY:
		var kunye := Portreler.kunye()
		for p: Variant in gorulen:
			if typeof(p) == TYPE_STRING and kunye.has(p) and not gorulen_portreler.has(p):
				gorulen_portreler.append(p)
	aile = AileDurumu.onar(veri.get("aile"))
	bayraklar = _bayraklari_suz(veri.get("bayraklar"))
	var t: Dictionary = {}
	if typeof(veri.get("toplam")) == TYPE_DICTIONARY:
		t = veri.get("toplam")
	toplam = {}
	for anahtar: String in ["islenen", "dogru", "yanlis"]:
		toplam[anahtar] = _tam(t.get(anahtar), 0, 0, PARA_SINIRI)
	toplam["kazanc"] = _tam(t.get("kazanc"), 0, -PARA_SINIRI, PARA_SINIRI)
	gun_denemesi = _tam(veri.get("gun_denemesi"), 0, 0, 100000)
	mesai_basladi = false
	if typeof(veri.get("mesai_basladi")) == TYPE_BOOL and bool(veri.get("mesai_basladi")):
		gun_denemesi += 1               # gişesi açılmış gün baştan oynanıyor: kuyruk yeniden karılır
	asama = "masa"
	gun_ozeti = {}
	son = {}
	if typeof(veri.get("asama")) == TYPE_STRING:
		if veri.get("asama") == "gun_sonu" and typeof(veri.get("gun_ozeti")) == TYPE_DICTIONARY:
			gun_ozeti = _ozeti_suz(veri.get("gun_ozeti"))
			asama = "gun_sonu"
		elif veri.get("asama") == "son":
			son = _sonu_suz(veri.get("son"))
			if not son.is_empty():
				asama = "son"


## Kayıttan gelen gün özeti (puantaj ekranı okur): sayılar aralığa çekilir, maaş yeniden hesaplanır.
func _ozeti_suz(v: Dictionary) -> Dictionary:
	var o := {}
	for alan: String in ["islenen", "dogru", "yanlis", "yarim", "havale", "yarida", "kazanc", "ihtar", "canta",
			"canta_yakalanan", "canta_kacan", "bos_alarm", "zarf", "ipucu"]:
		o[alan] = _tam(v.get(alan), 0, 0, PARA_SINIRI)
	o["para_once"] = _tam(v.get("para_once"), 0, -PARA_SINIRI, PARA_SINIRI)
	var ihtarlar: Array = []
	if typeof(v.get("ihtarlar")) == TYPE_ARRAY:
		for s: Variant in v.get("ihtarlar"):
			if typeof(s) == TYPE_STRING and ihtarlar.size() < 40:
				ihtarlar.append((s as String).left(600))
	o["ihtarlar"] = ihtarlar
	o["maas"] = maas_hesapla(o)
	return o


## Kayıttan gelen oyun sonu: yalnız tanınan türler ve kısa metinler kabul edilir (yoksa boş).
func _sonu_suz(v: Variant) -> Dictionary:
	if typeof(v) != TYPE_DICTIONARY or typeof(v.get("tur")) != TYPE_STRING:
		return {}
	if not ["kotu", "surgun", "terfi", "olagan"].has(v.get("tur")):
		return {}
	var s := {"tur": str(v.get("tur")), "neden": ""}
	if typeof(v.get("neden")) == TYPE_STRING and ["iflas", "aile", "tahliye", "ihtar", "suphe", "basari", "yerinde"].has(v.get("neden")):
		s["neden"] = str(v.get("neden"))
	if typeof(v.get("kritik")) == TYPE_STRING and AileDurumu.UYELER.has(v.get("kritik")):
		s["kritik"] = str(v.get("kritik"))
	return s


## Herhangi bir değeri sınırlı bir tam sayıya çevirir; sayı değilse (ya da sonlu değilse) yedeği verir.
func _tam(v: Variant, yedek: int, alt: int, ust: int) -> int:
	match typeof(v):
		TYPE_INT:
			return clampi(v, alt, ust)
		TYPE_FLOAT:
			if is_nan(v) or is_inf(v):
				return yedek
			return int(clampf(v, float(alt), float(ust)))
	return yedek


## Hikâye bayrakları: adı kısa bir metin, değeri mantıksal, sayı ya da kısa metin olanlar kalır.
## (JSON bütün sayıları ondalıklı okur; tam sayı olanlar yeniden tam sayıya çevrilir.)
func _bayraklari_suz(v: Variant) -> Dictionary:
	var temiz := {}
	if typeof(v) != TYPE_DICTIONARY:
		return temiz
	for ad: Variant in v:
		if temiz.size() >= BAYRAK_SINIRI:
			break
		if typeof(ad) != TYPE_STRING or (ad as String).length() > 48 or ad == "":
			continue
		var deger: Variant = v[ad]
		match typeof(deger):
			TYPE_BOOL:
				temiz[ad] = deger
			TYPE_INT:
				temiz[ad] = clampi(deger, -PARA_SINIRI, PARA_SINIRI)
			TYPE_FLOAT:
				if not is_nan(deger) and not is_inf(deger):
					var f := clampf(deger, -float(PARA_SINIRI), float(PARA_SINIRI))
					if is_equal_approx(f, roundf(f)):
						temiz[ad] = int(f)
					else:
						temiz[ad] = f
			TYPE_STRING:
				if (deger as String).length() <= 64:
					temiz[ad] = deger
	return temiz


## Kaydı yazar. Dosya imzalı bir zarftır: {surum, imza, veri}; `veri` oyun durumunun JSON metni,
## `imza` o metnin özetidir. Önce geçici dosyaya yazılır, eski kayıt yedeğe alınır, sonra yerine konur:
## yazma yarıda kesilse bile okunabilir bir kayıt kalır.
func kaydet() -> bool:
	return _yaz(kayit_verisi())


func _yaz(veri: Dictionary) -> bool:
	var metin := JSON.stringify(veri)
	var zarf := JSON.stringify({"surum": SURUM, "imza": _imza(metin), "veri": metin}, "\t")
	var gecici := kayit_yolu + ".tmp"
	var dosya := FileAccess.open(gecici, FileAccess.WRITE)
	if dosya == null:
		push_warning("Kayıt yazılamadı: %s" % error_string(FileAccess.get_open_error()))
		return false
	dosya.store_string(zarf)
	var hata := dosya.get_error()
	dosya.close()
	if hata != OK:
		DirAccess.remove_absolute(gecici)
		push_warning("Kayıt yazılamadı: %s" % error_string(hata))
		return false
	var yedek := kayit_yolu + ".yedek"
	if FileAccess.file_exists(kayit_yolu):
		if FileAccess.file_exists(yedek):
			DirAccess.remove_absolute(yedek)
		DirAccess.rename_absolute(kayit_yolu, yedek)
	if DirAccess.rename_absolute(gecici, kayit_yolu) != OK:
		if FileAccess.file_exists(yedek):
			DirAccess.rename_absolute(yedek, kayit_yolu)
		push_warning("Kayıt yerine konamadı.")
		return false
	_son_kayit = veri.duplicate(true)
	return true


func yukle() -> bool:
	var veri := _kayit_oku()
	if veri.is_empty():
		return false
	kayittan_al(veri)
	_son_kayit = kayit_verisi().duplicate(true)
	if typeof(veri.get("mesai_basladi")) == TYPE_BOOL and bool(veri.get("mesai_basladi")):
		kaydet()                        # deneme sayısı dosyaya da işlensin
	durum_degisti.emit()
	return true


func kaydi_sil() -> void:
	for yol: String in [kayit_yolu, kayit_yolu + ".yedek", kayit_yolu + ".tmp"]:
		if FileAccess.file_exists(yol):
			DirAccess.remove_absolute(yol)


## Kayıt dosyasını (bozuksa yedeğini) okur; geçerli bir kayıt yoksa boş sözlük döner.
func _kayit_oku() -> Dictionary:
	for yol: String in [kayit_yolu, kayit_yolu + ".yedek"]:
		var veri := _zarfi_ac(yol)
		if not veri.is_empty():
			return veri
	return {}


## İmzalı zarfı açar: boyutu, biçimi, sürümü ve imzası tutuyorsa içindeki oyun durumunu verir.
func _zarfi_ac(yol: String) -> Dictionary:
	var zarf: Variant = _json_oku(yol, KAYIT_BOYUT_SINIRI)
	if typeof(zarf) != TYPE_DICTIONARY:
		return {}
	var metin: Variant = zarf.get("veri")
	var imza: Variant = zarf.get("imza")
	if typeof(metin) != TYPE_STRING or typeof(imza) != TYPE_STRING:
		return {}                       # eski, imzasız biçim ya da başka bir dosya
	if _tam(zarf.get("surum"), 0, 0, 1000) != SURUM or imza != _imza(metin):
		return {}                       # başka sürümün kaydı ya da değiştirilmiş içerik
	var veri: Variant = JSON.parse_string(metin)
	return veri if typeof(veri) == TYPE_DICTIONARY else {}


func _imza(metin: String) -> String:
	var ozet := HMACContext.new()
	if ozet.start(HashingContext.HASH_SHA256, _IMZA_ANAHTARI.to_utf8_buffer()) != OK:
		return ""
	ozet.update(metin.to_utf8_buffer())
	return ozet.finish().hex_encode()


# --- Ayarlar (user://ayarlar.json) ---

func ayarlari_yukle() -> void:
	ayarlar = VARSAYILAN_AYARLAR.duplicate()
	if not FileAccess.file_exists(ayar_yolu):
		_ilk_profil()
	var veri: Variant = _json_oku(ayar_yolu)
	if typeof(veri) == TYPE_DICTIONARY:
		for anahtar: String in VARSAYILAN_AYARLAR:
			if veri.has(anahtar):
				ayarlar[anahtar] = _ayari_duzelt(anahtar, veri[anahtar])
	ayarlari_uygula()


## Bir ayar değerini türüne ve geçerli aralığına oturtur; uymuyorsa varsayılanı verir.
func _ayari_duzelt(ad: String, deger: Variant) -> Variant:
	var varsayilan: Variant = VARSAYILAN_AYARLAR.get(ad)
	if typeof(varsayilan) == TYPE_BOOL:
		return deger if typeof(deger) == TYPE_BOOL else varsayilan
	if AYAR_SECENEKLERI.has(ad):
		# seçenekli ayar: metinler birebir, sayılar değerce eşleşmeli (JSON 60'ı 60.0 okur)
		for s: Variant in AYAR_SECENEKLERI[ad]:
			if typeof(s) == TYPE_STRING:
				if typeof(deger) == TYPE_STRING and deger == s:
					return s
			elif (typeof(deger) == TYPE_INT or typeof(deger) == TYPE_FLOAT) and is_equal_approx(float(deger), float(s)):
				return s
		return varsayilan
	if typeof(deger) != TYPE_FLOAT and typeof(deger) != TYPE_INT:
		return varsayilan
	var sayi := float(deger)
	if is_nan(sayi) or is_inf(sayi):
		return varsayilan
	var aralik: Array = AYAR_ARALIKLARI.get(ad, [sayi, sayi])
	return clampf(sayi, float(aralik[0]), float(aralik[1]))


func ayar(ad: String) -> Variant:
	return ayarlar.get(ad, VARSAYILAN_AYARLAR.get(ad))


func ayar_degistir(ad: String, deger: Variant) -> void:
	if not VARSAYILAN_AYARLAR.has(ad):
		return
	ayarlar[ad] = _ayari_duzelt(ad, deger)
	ayarlari_uygula()
	if ad == "pencere_boyutu" or ad == "tam_ekran":
		_pencereyi_boyutla()
	_ayarlari_yaz()


## Bütün ayarları varsayılanlarına döndürür.
func ayarlari_sifirla() -> void:
	ayarlar = VARSAYILAN_AYARLAR.duplicate()
	ayarlari_uygula()
	_pencereyi_boyutla()
	_ayarlari_yaz()


func _ayarlari_yaz() -> void:
	var dosya := FileAccess.open(ayar_yolu, FileAccess.WRITE)
	if dosya != null:
		dosya.store_string(JSON.stringify(ayarlar, "\t"))
		dosya.close()


## Süslerin (kar, duman) yoğunluğu: 0 düşük, 1 orta, 2 yüksek.
func efekt_duzeyi() -> int:
	return maxi(0, (AYAR_SECENEKLERI.efekt_kalitesi as Array).find(str(ayar("efekt_kalitesi"))))


func ayarlari_uygula() -> void:
	if DisplayServer.get_name() != "headless" and not OS.has_feature("web"):
		var hedef := DisplayServer.WINDOW_MODE_FULLSCREEN if bool(ayarlar.tam_ekran) else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != hedef:
			DisplayServer.window_set_mode(hedef)
		var esleme := DisplayServer.VSYNC_ENABLED if bool(ayar("dikey_esleme")) else DisplayServer.VSYNC_DISABLED
		if DisplayServer.window_get_vsync_mode() != esleme:
			DisplayServer.window_set_vsync_mode(esleme)
	Engine.max_fps = int(ayar("kare_siniri"))
	# düşük çözünürlük: sahne tasarım çözünürlüğünde (1280×720) çizilir, pencereye büyütülür;
	# büyük ekranlı zayıf ekran kartlarında boyanan piksel sayısı kat kat azalır
	var kok := get_tree().root
	var olcek_kipi := Window.CONTENT_SCALE_MODE_VIEWPORT if bool(ayar("dusuk_cozunurluk")) else Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	if kok.content_scale_mode != olcek_kipi:
		kok.content_scale_mode = olcek_kipi
	ayarlar_degisti.emit()


# --- Kendiliğinden kalite ayarı ---

## Kare hızını beşer saniyelik pencerelerle izler; iki pencere üst üste düşük kalırsa kaliteyi bir kademe kısar.
func _process(delta: float) -> void:
	if not bool(ayar("otomatik_kalite")) or get_tree().paused or _geciste:
		return
	if DisplayServer.get_name() == "headless" or not DisplayServer.window_is_focused():
		return                              # arka plandaki pencereyi işletim sistemi yavaşlatır: ölçüm yanıltır
	var sahne := get_tree().current_scene
	var kimlik := sahne.get_instance_id() if sahne != null else 0
	if kimlik != _olculen_sahne:
		_olculen_sahne = kimlik             # yeni sahne: yükleme takılmaları ölçüme girmesin
		_olcum_suresi = -3.0
		_olcum_karesi = 0
		return
	_olcum_suresi += delta
	if _olcum_suresi < 0.0:
		return
	_olcum_karesi += 1
	if _olcum_suresi < 5.0:
		return
	var kare_hizi := _olcum_karesi / _olcum_suresi
	_olcum_suresi = 0.0
	_olcum_karesi = 0
	var hedef := float(int(ayar("kare_siniri"))) if int(ayar("kare_siniri")) > 0 else 60.0
	if kare_hizi < minf(40.0, hedef * 0.66):
		_dusuk_pencere += 1
		if _dusuk_pencere >= 2:
			_dusuk_pencere = 0
			kaliteyi_dusur()
	else:
		_dusuk_pencere = 0


## Kaliteyi bir kademe kısar ve neyi kıstığını döndürür (kısacak bir şey kalmadıysa boş metin).
## Sıra: efekt kalitesi → düşük çözünürlük → doku kalitesi → kare sınırı 30.
func kaliteyi_dusur() -> String:
	var duzey := efekt_duzeyi()
	if duzey > 0:
		ayar_degistir("efekt_kalitesi", AYAR_SECENEKLERI.efekt_kalitesi[duzey - 1])
		return "efekt_kalitesi"
	if not bool(ayar("dusuk_cozunurluk")):
		ayar_degistir("dusuk_cozunurluk", true)
		return "dusuk_cozunurluk"
	if str(ayar("doku_kalitesi")) != "dusuk":
		ayar_degistir("doku_kalitesi", "dusuk")
		return "doku_kalitesi"
	if int(ayar("kare_siniri")) == 0 or int(ayar("kare_siniri")) > 30:
		ayar_degistir("kare_siniri", 30)
		return "kare_siniri"
	return ""


## İlk açılışta (ayar dosyası yokken) donanıma göre başlangıç ayarı: az çekirdekli ya da az bellekli
## bilgisayarda süsler ve arka planlar düşükten başlar. Oyuncu ayarlardan değiştirebilir.
func _ilk_profil() -> void:
	var bellek := int(OS.get_memory_info().get("physical", -1))
	var zayif := OS.get_processor_count() <= 2 or (bellek > 0 and bellek < 3_400_000_000)
	if zayif:
		ayarlar["efekt_kalitesi"] = "dusuk"
		ayarlar["doku_kalitesi"] = "dusuk"


## Pencereyi ayarlardaki boyuta getirir ve ekranın ortasına alır (yalnız pencere kipinde, masaüstünde).
## Yalnızca boyut ayarı değişince ve açılışta çağrılır: oyuncunun elle büyüttüğü pencere, başka bir
## ayar değişti diye eski boyutuna dönmez. Ekrana sığmayan boyut ekranın kullanılabilir alanına çekilir.
func _pencereyi_boyutla() -> void:
	if DisplayServer.get_name() == "headless" or OS.has_feature("web") or bool(ayar("tam_ekran")):
		return
	if DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS):
		return                              # ekran dışındaki test penceresi yerinde kalır
	var parca := str(ayar("pencere_boyutu")).split("x")
	if parca.size() != 2:
		return
	var ekran := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	var boyut := Vector2i(mini(int(parca[0]), ekran.size.x), mini(int(parca[1]), ekran.size.y))
	if DisplayServer.window_get_size() == boyut:
		return
	DisplayServer.window_set_size(boyut)
	DisplayServer.window_set_position(ekran.position + (ekran.size - boyut) / 2)


## Kullanıcı klasöründeki bir JSON dosyasını okur. Dosya yoksa, `sinir` bayttan büyükse ya da
## çözülemiyorsa null döner (konsola hata yazmaz: bozuk dosya olağan bir durumdur).
func _json_oku(yol: String, sinir: int = 64 * 1024) -> Variant:
	if not FileAccess.file_exists(yol):
		return null
	var dosya := FileAccess.open(yol, FileAccess.READ)
	if dosya == null:
		return null
	if dosya.get_length() > sinir:
		dosya.close()
		return null
	var metin := dosya.get_buffer(dosya.get_length()).get_string_from_utf8()
	dosya.close()
	var json := JSON.new()
	if json.parse(metin) != OK:
		return null
	return json.data


# --- Sahne geçişleri (kısa kararma ile) ---

func sahneye_gec(ad: String) -> void:
	if _geciste or not SAHNELER.has(ad):
		return
	_geciste = true
	_perde.mouse_filter = Control.MOUSE_FILTER_STOP
	# Tek bir geçiş zinciri: karar, sahneyi değiştir, aç. (Bekleyen bir eşyordam kullanılmaz;
	# geçişin ortasında oyundan çıkılırsa geçiş nesnesi bellekte asılı kalmasın.)
	var t := create_tween()
	t.tween_property(_perde, "color:a", 1.0, 0.22)
	t.tween_callback(get_tree().change_scene_to_file.bind(SAHNELER[ad]))
	t.tween_interval(0.06)
	t.tween_property(_perde, "color:a", 0.0, 0.28)
	t.tween_callback(func() -> void:
		_perde.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_geciste = false)


func geciste_mi() -> bool:
	return _geciste


func _perde_kur() -> void:
	var katman := CanvasLayer.new()
	katman.layer = 100
	add_child(katman)
	_katman = katman
	_perde = ColorRect.new()
	_perde.color = Color(Stil.GECE, 0.0)
	_perde.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_perde.mouse_filter = Control.MOUSE_FILTER_IGNORE
	katman.add_child(_perde)
