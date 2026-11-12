extends Node
## Ses (Autoload) — efektler, döngülü ortam sesleri ve müzik.
##
## Efektler küçük bir çalıcı havuzundan çalınır:  Ses.cal("muhur")
##   Bir efektin birden çok kaydı varsa (adim.wav, adim_2.wav, adim_3.wav ...) her çalışta biri seçilir.
## Ortam sesleri (soba, rüzgâr) adlarıyla açılıp kapanır ve yumuşak geçiş yapar:
##   Ses.ortam("soba")   Ses.ortami_kes("soba")   Ses.ortami_kes()
## Müzik bir çalma listesidir; sırayla çalar, bitince başa döner:
##   Ses.muzik(["saz_semaisi", "harman_dali"], -6.0, true)   Ses.muzigi_kes()
##   `radyo` açıkken parça masadaki radyodan gelir gibi dar bantlı duyulur.
## Ses düzeyleri ayarlardan gelir (genel, efekt, radyo/ortam) ve veriyollarına uygulanır.
## Seslerin tamamı gerçek kayıtlardan derlenmiştir: tools/ses/topla.py, künyeler assets/ses/KAYNAKLAR.md.

const KLASOR := "res://assets/ses/"
const MUZIK_KLASORU := "res://assets/ses/muzik/"
const HAVUZ := 12
const EFEKT_YOLU := "Efekt"
const ORTAM_YOLU := "Ortam"
const MUZIK_YOLU := "Muzik"          ## menü müziği ve (Radyo üzerinden) masadaki radyo
const RADYO_YOLU := "Radyo"          ## Muzik'e akar; küçük hoparlör sesi verir
const KONUSMA_YOLU := "Konusma"      ## vatandaşların mırıltısı ve iç çekişi

var _calicilar: Array[AudioStreamPlayer] = []
var _siradaki := 0
var _cesitler: Dictionary = {}       ## ad -> Array[AudioStream] (bulunamayan için boş dizi)
var _son_cesit: Dictionary = {}      ## ad -> en son çalınan kaydın sırası (üst üste aynısı gelmesin)
var _ortamlar: Dictionary = {}       ## ad -> AudioStreamPlayer
var _gecisler: Dictionary = {}       ## ad -> Tween
var _son_calis: Dictionary = {}      ## ad -> son çalındığı an (ms): aynı ses üst üste binmesin
var _kapali := false                 ## oyundan çıkılırken: artık ses çalınmaz

var _muzik: AudioStreamPlayer        ## çalan parça
var _muzik_listesi: Array = []
var _muzik_sirasi := 0
var _muzik_gecisi: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_yol_ac(EFEKT_YOLU, "Master")
	_yol_ac(ORTAM_YOLU, "Master")
	_yol_ac(MUZIK_YOLU, "Master")
	_yol_ac(KONUSMA_YOLU, "Master")
	if _yol_ac(RADYO_YOLU, MUZIK_YOLU):
		var i := AudioServer.get_bus_index(RADYO_YOLU)
		var alt := AudioEffectHighPassFilter.new()
		alt.cutoff_hz = 260.0
		var ust := AudioEffectLowPassFilter.new()
		ust.cutoff_hz = 3800.0
		AudioServer.add_bus_effect(i, alt)
		AudioServer.add_bus_effect(i, ust)
	# üst üste binen sesler ana çıkışı taşırmasın
	var sinir := AudioEffectHardLimiter.new()
	sinir.ceiling_db = -1.0
	AudioServer.add_bus_effect(0, sinir)
	for i in HAVUZ:
		var c := AudioStreamPlayer.new()
		c.bus = EFEKT_YOLU
		add_child(c)
		_calicilar.append(c)
	Oyun.ayarlar_degisti.connect(ayarlari_uygula)
	ayarlari_uygula()
	get_tree().node_added.connect(_dugum_eklendi)


## Veriyolu yoksa açar; yeni açtıysa true döner.
func _yol_ac(ad: String, hedef: String) -> bool:
	if AudioServer.get_bus_index(ad) >= 0:
		return false
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, ad)
	AudioServer.set_bus_send(i, hedef)
	return true


## Ayarlardaki düzeyleri veriyollarına işler (0 = sessiz).
func ayarlari_uygula() -> void:
	_duzey("Master", float(Oyun.ayar("ses_genel")))
	_duzey(EFEKT_YOLU, float(Oyun.ayar("ses_efekt")))
	_duzey(KONUSMA_YOLU, float(Oyun.ayar("ses_konusma")))
	_duzey(ORTAM_YOLU, float(Oyun.ayar("ses_ortam")))
	_duzey(MUZIK_YOLU, float(Oyun.ayar("ses_muzik")) if bool(Oyun.ayar("muzik_acik")) else 0.0)


func _duzey(yol: String, oran: float) -> void:
	var i := AudioServer.get_bus_index(yol)
	if i < 0:
		return
	AudioServer.set_bus_mute(i, oran <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(clampf(oran, 0.001, 1.0)))


func _yukle(klasor: String, ad: String) -> AudioStream:
	for uzanti: String in [".wav", ".ogg"]:
		var yol := klasor + ad + uzanti
		if ResourceLoader.exists(yol):
			return load(yol)
	return null


## Efektin kayıtlarından birini verir (`cesit` verilmişse o sıradakini; yoksa bir öncekinden farklı birini).
func _akis(ad: String, cesit: int = -1) -> AudioStream:
	if not _cesitler.has(ad):
		var bulunan: Array[AudioStream] = []
		var ilk := _yukle(KLASOR, ad)
		if ilk != null:
			bulunan.append(ilk)
			var no := 2
			while true:
				var s := _yukle(KLASOR, "%s_%d" % [ad, no])
				if s == null:
					break
				bulunan.append(s)
				no += 1
		_cesitler[ad] = bulunan
	var liste: Array = _cesitler[ad]
	if liste.is_empty():
		return null
	if cesit >= 0:
		return liste[cesit % liste.size()]
	if liste.size() == 1:
		return liste[0]
	var i := randi() % liste.size()
	if i == int(_son_cesit.get(ad, -1)):
		i = (i + 1) % liste.size()
	_son_cesit[ad] = i
	return liste[i]


## Bir efektin kaç ayrı kaydı olduğunu söyler.
func cesit_sayisi(ad: String) -> int:
	_akis(ad)
	return (_cesitler[ad] as Array).size()


## Bir efekti çalar. `perde`: çalma hızı (1 = olduğu gibi); `sapma`: perdeye eklenen rastgele oynama;
## `db`: düzey farkı; `aralik`: aynı sesin yeniden çalınabilmesi için geçmesi gereken en az süre (sn);
## `cesit`: birden çok kaydı olan efektte hangisinin çalınacağı (-1: rastgele).
func cal(ad: String, perde: float = 1.0, db: float = 0.0, sapma: float = 0.0, aralik: float = 0.0, cesit: int = -1) -> void:
	if _kapali:
		return
	var simdi := Time.get_ticks_msec()
	if aralik > 0.0 and simdi - int(_son_calis.get(ad, -100000)) < int(aralik * 1000.0):
		return
	var akis := _akis(ad, cesit)
	if akis == null:
		return
	_son_calis[ad] = simdi
	var c := _calicilar[_siradaki]
	_siradaki = (_siradaki + 1) % HAVUZ
	c.stream = akis
	c.bus = KONUSMA_YOLU if (ad == "hece" or ad.begins_with("ofle")) else EFEKT_YOLU
	c.pitch_scale = maxf(0.2, perde + randf_range(-sapma, sapma))
	c.volume_db = db
	c.play()


## Bir efekti gecikmeyle çalar (duraklatmaya uyar).
func gecikmeli(ad: String, gecikme: float, perde: float = 1.0, db: float = 0.0, sapma: float = 0.0) -> void:
	Oyun.bekle(gecikme).connect(cal.bind(ad, perde, db, sapma))


## Döngülü bir ortam sesini açar (zaten çalıyorsa yalnızca düzeyini ayarlar).
func ortam(ad: String, db: float = 0.0, gecis: float = 1.2) -> void:
	var akis := _akis(ad, 0)
	if akis == null or _kapali:
		return
	if akis is AudioStreamOggVorbis:
		(akis as AudioStreamOggVorbis).loop = true
	var c: AudioStreamPlayer = _ortamlar.get(ad)
	if c == null:
		c = AudioStreamPlayer.new()
		c.bus = ORTAM_YOLU
		c.playback_type = AudioServer.PLAYBACK_TYPE_STREAM    # web'de de düzeyi çalarken değişebilsin
		c.stream = akis
		c.volume_db = -60.0
		add_child(c)
		_ortamlar[ad] = c
	if not c.playing:
		c.volume_db = -60.0
		c.play()
	_gecis(ad, c, db, gecis, false)


## Bir ortam sesini (ad boşsa hepsini) kısıp durdurur.
func ortami_kes(ad: String = "", gecis: float = 0.8) -> void:
	var adlar: Array = [ad] if ad != "" else _ortamlar.keys()
	for a: String in adlar:
		var c: AudioStreamPlayer = _ortamlar.get(a)
		if c != null and c.playing:
			_gecis(a, c, -60.0, gecis, true)


## Verilenler dışındaki bütün ortam seslerini keser (sahne değişirken).
func yalniz(adlar: Array) -> void:
	for a: String in _ortamlar.keys():
		if not adlar.has(a):
			ortami_kes(a)


func _gecis(ad: String, c: AudioStreamPlayer, db: float, sure: float, durdur: bool) -> void:
	var eski: Tween = _gecisler.get(ad)
	if eski != null:
		eski.kill()
	var t := create_tween()
	t.tween_property(c, "volume_db", db, maxf(0.01, sure))
	if durdur:
		t.tween_callback(c.stop)
	_gecisler[ad] = t


# --- Müzik ---

## Bir çalma listesini açar: parçalar sırayla çalar, liste bitince başa döner. Aynı liste zaten çalıyorsa
## yalnızca düzeyi ve tınısı (radyo) ayarlanır. `ilk`: listenin kaçıncı parçasından başlanacağı.
func muzik(liste: Array, db: float = 0.0, radyo: bool = false, gecis: float = 2.0, ilk: int = 0) -> void:
	if _kapali or liste.is_empty():
		return
	var yol := RADYO_YOLU if radyo else MUZIK_YOLU
	if _muzik != null and _muzik.playing and liste == _muzik_listesi and _muzik.bus == yol:
		_muzik_duzeyi(_muzik, db, gecis, false)
		return
	_eski_muzigi_birak(gecis)
	_muzik_listesi = liste.duplicate()
	_muzik_sirasi = posmod(ilk, liste.size())
	_muzik = AudioStreamPlayer.new()
	_muzik.bus = yol
	_muzik.playback_type = AudioServer.PLAYBACK_TYPE_STREAM    # süzgeç ve düzey geçişi web'de de işlesin
	_muzik.volume_db = -60.0
	_muzik.finished.connect(_siradaki_parca.bind(_muzik))
	add_child(_muzik)
	if _parcayi_cal():
		_muzik_duzeyi(_muzik, db, gecis, false)


## Çalan müziği kısıp durdurur.
func muzigi_kes(gecis: float = 1.5) -> void:
	_eski_muzigi_birak(gecis)
	_muzik_listesi = []


## Çalan parçanın adı (müzik yoksa boş).
func calan_parca() -> String:
	if _muzik == null or not _muzik.playing or _muzik_listesi.is_empty():
		return ""
	return str(_muzik_listesi[_muzik_sirasi])


func _parcayi_cal() -> bool:
	# listede bulunamayan parça atlanır; hiçbiri yoksa çalınmaz
	for deneme in _muzik_listesi.size():
		var akis := _yukle(MUZIK_KLASORU, str(_muzik_listesi[_muzik_sirasi]))
		if akis != null:
			if akis is AudioStreamOggVorbis:
				(akis as AudioStreamOggVorbis).loop = false
			_muzik.stream = akis
			_muzik.play()
			return true
		_muzik_sirasi = (_muzik_sirasi + 1) % _muzik_listesi.size()
	return false


func _siradaki_parca(calici: AudioStreamPlayer) -> void:
	if calici != _muzik or _kapali or _muzik_listesi.is_empty():
		return
	_muzik_sirasi = (_muzik_sirasi + 1) % _muzik_listesi.size()
	_parcayi_cal()


func _eski_muzigi_birak(gecis: float) -> void:
	if _muzik_gecisi != null:
		_muzik_gecisi.kill()
		_muzik_gecisi = null
	if _muzik == null:
		return
	var eski := _muzik
	_muzik = null
	var t := create_tween()
	t.tween_property(eski, "volume_db", -60.0, maxf(0.01, gecis))
	t.tween_callback(eski.stop)
	t.tween_callback(eski.queue_free)


func _muzik_duzeyi(c: AudioStreamPlayer, db: float, sure: float, _durdur: bool) -> void:
	if _muzik_gecisi != null:
		_muzik_gecisi.kill()
	_muzik_gecisi = create_tween()
	_muzik_gecisi.tween_property(c, "volume_db", db, maxf(0.01, sure))


## Bütün sesleri anında durdurur (oyundan çıkarken: çalan ses bellekte asılı kalmasın).
func sustur() -> void:
	_kapali = true
	for t: Tween in _gecisler.values():
		if t != null:
			t.kill()
	_gecisler.clear()
	if _muzik_gecisi != null:
		_muzik_gecisi.kill()
		_muzik_gecisi = null
	for c in _calicilar:
		c.stop()
		c.stream = null
	for c: AudioStreamPlayer in _ortamlar.values():
		c.stop()
		c.stream = null
		c.queue_free()
	_ortamlar.clear()
	for c in get_children():
		if c is AudioStreamPlayer and not _calicilar.has(c):
			(c as AudioStreamPlayer).stop()
			(c as AudioStreamPlayer).stream = null
			c.queue_free()
	_muzik = null
	_muzik_listesi = []


func _exit_tree() -> void:
	sustur()


## Sahneye eklenen her düğme basılınca küçük bir tık sesi çıkarır.
func _dugum_eklendi(dugum: Node) -> void:
	# düğüm ağaçtan çıkıp yeniden girerse ikinci kez bağlanmasın
	if dugum is Button and not dugum.has_meta("tik_bagli"):
		dugum.set_meta("tik_bagli", true)
		(dugum as Button).pressed.connect(cal.bind("tik", 1.0, -6.0, 0.05))
