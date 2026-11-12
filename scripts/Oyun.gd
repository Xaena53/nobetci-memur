extends Node
## Oyun (Autoload) — kalıcı oyun durumu, kayıt/yükleme, ayarlar ve sahne geçişleri.
## Sahneler bu düğüme "Oyun" adıyla her yerden ulaşır.

signal durum_degisti
signal ayarlar_degisti

const SURUM := 2
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

const AYAR_YOLU := "user://ayarlar.json"
const SAHNELER := {
	"menu": "res://scenes/AnaMenu.tscn",
	"masa": "res://scenes/Masa.tscn",
	"gun_sonu": "res://scenes/GunSonu.tscn",
	"aile": "res://scenes/Aile.tscn",
	"son": "res://scenes/Son.tscn",
}
const VARSAYILAN_AYARLAR := {
	"saat_hizi": 1.0,      ## oyun dakikası başına gerçek saniye (küçüldükçe gün hızlanır)
	"ses_genel": 0.8,
	"ses_efekt": 0.9,
	"ses_radyo": 0.5,
	"tam_ekran": false,
}

var kayit_yolu := "user://kayit.json"  ## testler kendi dosyasını kullanır

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
var ayarlar: Dictionary = VARSAYILAN_AYARLAR.duplicate()

var _perde: ColorRect
var _geciste := false
var _katman: CanvasLayer
var _mola: MolaMenusu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.theme = Stil.tema()
	get_tree().auto_accept_quit = false     # pencere kapanırken önce sesler susturulur (bkz. cik)
	_perde_kur()
	ayarlari_yukle()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		cik()


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
	Ses.cal("daktilo", 0.8, -4.0)
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
	kaydet()
	durum_degisti.emit()


## Mesai kapanınca: maaşı hesaplar, parayı ve ihtarları işler, günün özetini saklar.
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
	durum_degisti.emit()


## Günün maaşı: yevmiye + primler − ihtar kesintisi.
static func maas_hesapla(ozet: Dictionary) -> Dictionary:
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
	return hash([tohum, gun])


# --- Kayıt / yükleme (user://kayit.json) ---

func kayit_var_mi() -> bool:
	return FileAccess.file_exists(kayit_yolu)


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
	}


func kayittan_al(veri: Dictionary) -> void:
	gun = clampi(int(veri.get("gun", 1)), 1, TOPLAM_GUN)
	zorluk = str(veri.get("zorluk", "kolay"))
	if not KIPLER.has(zorluk):
		zorluk = "kolay"
	para = int(veri.get("para", BASLANGIC_PARASI))
	ihtar = int(veri.get("ihtar", 0))
	suphe = int(veri.get("suphe", 0))
	tohum = int(veri.get("tohum", 0))
	gorulen_portreler = (veri.get("gorulen_portreler", []) as Array).duplicate()
	aile = AileDurumu.onar(veri.get("aile", {}))
	bayraklar = (veri.get("bayraklar", {}) as Dictionary).duplicate(true)
	toplam = (veri.get("toplam", {}) as Dictionary).duplicate()
	gun_ozeti = {}
	son = {}


func kaydet() -> bool:
	var dosya := FileAccess.open(kayit_yolu, FileAccess.WRITE)
	if dosya == null:
		push_warning("Kayıt yazılamadı: %s" % error_string(FileAccess.get_open_error()))
		return false
	dosya.store_string(JSON.stringify(kayit_verisi(), "\t"))
	dosya.close()
	return true


func yukle() -> bool:
	if not kayit_var_mi():
		return false
	var veri: Variant = _json_oku(kayit_yolu)
	if typeof(veri) != TYPE_DICTIONARY:
		push_warning("Kayıt dosyası okunamadı; yok sayılıyor.")
		return false
	kayittan_al(veri)
	durum_degisti.emit()
	return true


func kaydi_sil() -> void:
	if kayit_var_mi():
		DirAccess.remove_absolute(kayit_yolu)


# --- Ayarlar (user://ayarlar.json) ---

func ayarlari_yukle() -> void:
	ayarlar = VARSAYILAN_AYARLAR.duplicate()
	var veri: Variant = _json_oku(AYAR_YOLU)
	if typeof(veri) == TYPE_DICTIONARY:
		for anahtar: String in VARSAYILAN_AYARLAR:
			if veri.has(anahtar) and typeof(veri[anahtar]) == typeof(VARSAYILAN_AYARLAR[anahtar]):
				ayarlar[anahtar] = veri[anahtar]
	ayarlari_uygula()


func ayar(ad: String) -> Variant:
	return ayarlar.get(ad, VARSAYILAN_AYARLAR.get(ad))


func ayar_degistir(ad: String, deger: Variant) -> void:
	ayarlar[ad] = deger
	ayarlari_uygula()
	var dosya := FileAccess.open(AYAR_YOLU, FileAccess.WRITE)
	if dosya != null:
		dosya.store_string(JSON.stringify(ayarlar, "\t"))
		dosya.close()


func ayarlari_uygula() -> void:
	if DisplayServer.get_name() != "headless":
		var hedef := DisplayServer.WINDOW_MODE_FULLSCREEN if bool(ayarlar.tam_ekran) else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != hedef:
			DisplayServer.window_set_mode(hedef)
	ayarlar_degisti.emit()


func _json_oku(yol: String) -> Variant:
	if not FileAccess.file_exists(yol):
		return null
	var dosya := FileAccess.open(yol, FileAccess.READ)
	if dosya == null:
		return null
	var veri: Variant = JSON.parse_string(dosya.get_as_text())
	dosya.close()
	return veri


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
