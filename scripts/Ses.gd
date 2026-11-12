extends Node
## Ses (Autoload) — efektler ve döngülü ortam sesleri.
##
## Efektler küçük bir çalıcı havuzundan çalınır:  Ses.cal("muhur")
## Ortam sesleri (radyo, soba, rüzgâr) adlarıyla açılıp kapanır ve yumuşak geçiş yapar:
##   Ses.ortam("radyo")   Ses.ortami_kes("radyo")   Ses.ortami_kes()
## Ses düzeyleri ayarlardan gelir (genel, efekt, radyo/ortam) ve üç veriyoluna uygulanır.
## Seslerin tamamı tools/ses/uret.py ile sentezlenmiştir.

const KLASOR := "res://assets/ses/"
const HAVUZ := 12
const EFEKT_YOLU := "Efekt"
const ORTAM_YOLU := "Ortam"

var _calicilar: Array[AudioStreamPlayer] = []
var _siradaki := 0
var _akislar: Dictionary = {}        ## ad -> AudioStream (bulunamayan için null)
var _ortamlar: Dictionary = {}       ## ad -> AudioStreamPlayer
var _gecisler: Dictionary = {}       ## ad -> Tween
var _son_calis: Dictionary = {}      ## ad -> son çalındığı an (ms): aynı ses üst üste binmesin
var _kapali := false                 ## oyundan çıkılırken: artık ses çalınmaz


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for ad: String in [EFEKT_YOLU, ORTAM_YOLU]:
		if AudioServer.get_bus_index(ad) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, ad)
			AudioServer.set_bus_send(i, "Master")
	for i in HAVUZ:
		var c := AudioStreamPlayer.new()
		c.bus = EFEKT_YOLU
		add_child(c)
		_calicilar.append(c)
	Oyun.ayarlar_degisti.connect(ayarlari_uygula)
	ayarlari_uygula()
	get_tree().node_added.connect(_dugum_eklendi)


## Ayarlardaki düzeyleri veriyollarına işler (0 = sessiz).
func ayarlari_uygula() -> void:
	_duzey("Master", float(Oyun.ayar("ses_genel")))
	_duzey(EFEKT_YOLU, float(Oyun.ayar("ses_efekt")))
	_duzey(ORTAM_YOLU, float(Oyun.ayar("ses_radyo")))


func _duzey(yol: String, oran: float) -> void:
	var i := AudioServer.get_bus_index(yol)
	if i < 0:
		return
	AudioServer.set_bus_mute(i, oran <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(clampf(oran, 0.001, 1.0)))


func _akis(ad: String) -> AudioStream:
	if not _akislar.has(ad):
		var bulunan: AudioStream = null
		for uzanti: String in [".wav", ".ogg"]:
			var yol := KLASOR + ad + uzanti
			if ResourceLoader.exists(yol):
				bulunan = load(yol)
				break
		_akislar[ad] = bulunan
	return _akislar[ad]


## Bir efekti çalar. `perde`: çalma hızı (1 = olduğu gibi); `sapma`: perdeye eklenen rastgele oynama;
## `db`: düzey farkı; `aralik`: aynı sesin yeniden çalınabilmesi için geçmesi gereken en az süre (sn).
func cal(ad: String, perde: float = 1.0, db: float = 0.0, sapma: float = 0.0, aralik: float = 0.0) -> void:
	var akis := _akis(ad)
	if akis == null or _kapali:
		return
	var simdi := Time.get_ticks_msec()
	if aralik > 0.0 and simdi - int(_son_calis.get(ad, -100000)) < int(aralik * 1000.0):
		return
	_son_calis[ad] = simdi
	var c := _calicilar[_siradaki]
	_siradaki = (_siradaki + 1) % HAVUZ
	c.stream = akis
	c.pitch_scale = maxf(0.2, perde + randf_range(-sapma, sapma))
	c.volume_db = db
	c.play()


## Bir efekti gecikmeyle çalar (duraklatmaya uyar).
func gecikmeli(ad: String, gecikme: float, perde: float = 1.0, db: float = 0.0, sapma: float = 0.0) -> void:
	Oyun.bekle(gecikme).connect(cal.bind(ad, perde, db, sapma))


## Döngülü bir ortam sesini açar (zaten çalıyorsa yalnızca düzeyini ayarlar).
func ortam(ad: String, db: float = 0.0, gecis: float = 1.2) -> void:
	var akis := _akis(ad)
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


## Bütün sesleri anında durdurur (oyundan çıkarken: çalan ses bellekte asılı kalmasın).
func sustur() -> void:
	_kapali = true
	for t: Tween in _gecisler.values():
		if t != null:
			t.kill()
	_gecisler.clear()
	for c in _calicilar:
		c.stop()
		c.stream = null
	for c: AudioStreamPlayer in _ortamlar.values():
		c.stop()
		c.stream = null
		c.queue_free()
	_ortamlar.clear()


func _exit_tree() -> void:
	sustur()


## Sahneye eklenen her düğme basılınca küçük bir tık sesi çıkarır.
func _dugum_eklendi(dugum: Node) -> void:
	if dugum is Button:
		(dugum as Button).pressed.connect(cal.bind("tik", 1.0, -6.0, 0.05))
