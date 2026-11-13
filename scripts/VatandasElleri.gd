class_name VatandasElleri
extends Control
## Gişedeki vatandaşın elleri. Boyalı el pozları (assets/img/el/<erkek|kadin>_<poz>.webp) duruma göre
## değişir: evrakı uzatır, eşiğe koyar, konuşurken açıklar, sabrı taşınca parmak sallar, reddedilince
## yalvarır, yakalanınca ellerini kaldırır. Poz değişirken eller eşiğin altına inip yeni pozla çıkar.
## Kol ağzı vatandaşın giysisinin rengine boyanır (el.gdshader).
##
## Düğüm gişe açıklığını kaplar; eller açıklığın alt kenarına (eşiğe) göre yerleşir.

const YOL := "res://assets/img/el/%s_%s.webp"
const GOLGELEYICI := preload("res://assets/shader/el.gdshader")
## Poz → [yatay kayma (eşiğin ortasından), dikey kayma (artı: aşağı), ölçek çarpanı]
const POZLAR := {
	"esik": [0.0, 10.0, 1.0],
	"uzat": [22.0, 6.0, 1.0],
	"acik": [40.0, -8.0, 1.0],
	"parmak": [46.0, 4.0, 1.0],
	"yalvar": [0.0, 12.0, 1.0],
	"teslim": [0.0, 14.0, 1.12],
}
const OLCEK := 0.30
const TESLIM_ARASI := 150.0     ## eller yukarıdayken iki elin arası (başın iki yanı)

var poz := ""

var _sol: TextureRect           ## tek parçalı pozlarda görselin tamamı; "teslim"de sol el
var _sag: TextureRect           ## yalnız "teslim"de: sağ el
var _malzeme: ShaderMaterial
var _cins := "erkek"
var _boy := 1.0                 ## çocuklarda küçülür
var _zaman := 0.0
var _gecis: Tween
var _acik := false
var _taban := Vector2.ZERO      ## ellerin oturduğu yer (düğümün kendi koordinatında)


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_malzeme = ShaderMaterial.new()
	_malzeme.shader = GOLGELEYICI
	for i in 2:
		var r := TextureRect.new()
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_SCALE
		r.mouse_filter = MOUSE_FILTER_IGNORE
		r.material = _malzeme
		r.visible = false
		add_child(r)
		if i == 0:
			_sol = r
		else:
			_sag = r


## Yeni vatandaş: cinsiyete, yaşa ve giysiye göre eller hazırlanır (henüz görünmez).
func hazirla(kimlik: String) -> void:
	var bilgi := Portreler.bilgi(kimlik)
	_cins = "kadin" if str(bilgi.get("cinsiyet", "E")) == "K" else "erkek"
	var yas := int(bilgi.get("yas", 40))
	_boy = 0.72 if yas < 14 else 1.0
	if yas < 14:
		_cins = "kadin"                      # çocuk eli: ince, küçük
	_malzeme.set_shader_parameter("kol_rengi", _giysi_rengi(kimlik))
	_malzeme.set_shader_parameter("ten_koyulugu", 1.0)
	gizle(false)


## Portrenin alt orta bölümünün ortalama rengi: giysinin rengi sayılır.
func _giysi_rengi(kimlik: String) -> Vector3:
	var doku := Portreler.doku(kimlik)
	var g := doku.get_image() if doku != null else null
	if g == null:
		return Vector3(0.45, 0.42, 0.40)
	if g.is_compressed():
		g.decompress()
	var w := g.get_width()
	var h := g.get_height()
	var toplam := Vector3.ZERO
	var adet := 0
	for yi in 6:
		for xi in 10:
			var c := g.get_pixel(int(w * (0.22 + 0.56 * xi / 9.0)), int(h * (0.86 + 0.10 * yi / 5.0)))
			if c.a > 0.9:
				toplam += Vector3(c.r, c.g, c.b)
				adet += 1
	return toplam / float(adet) if adet > 0 else Vector3(0.45, 0.42, 0.40)


## Elleri verilen poza getirir. Açık bir poz varsa eller önce eşiğin altına iner.
func goster(yeni: String) -> void:
	if yeni == poz and _acik:
		return
	poz = yeni
	if _gecis != null:
		_gecis.kill()
	_gecis = create_tween()
	if _acik:
		_gecis.tween_property(self, "position:y", 110.0, 0.13).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	else:
		position.y = 110.0
	_acik = true
	_gecis.tween_callback(_pozu_kur)
	_gecis.tween_property(self, "position:y", 0.0, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Eller eşiğin altına iner ve kaybolur.
func gizle(yumusak: bool = true) -> void:
	if _gecis != null:
		_gecis.kill()
	poz = ""
	if not _acik or not yumusak:
		_acik = false
		_sol.visible = false
		_sag.visible = false
		position.y = 0.0
		return
	_acik = false
	_gecis = create_tween()
	_gecis.tween_property(self, "position:y", 120.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_gecis.tween_callback(func() -> void:
		_sol.visible = false
		_sag.visible = false
		position.y = 0.0)


func _pozu_kur() -> void:
	var yol := YOL % [_cins, poz]
	if not ResourceLoader.exists(yol) or not POZLAR.has(poz):
		_sol.visible = false
		_sag.visible = false
		return
	var doku: Texture2D = load(yol)
	var ayar: Array = POZLAR[poz]
	var olcek := OLCEK * _boy * float(ayar[2])
	var boyut := doku.get_size() * olcek
	_taban = Vector2(size.x / 2.0 + float(ayar[0]) * _boy, size.y + float(ayar[1]))
	if poz == "teslim":
		# görselin iki yarısı ayrı ayrı, başın iki yanına
		for i in 2:
			var yarim := AtlasTexture.new()
			yarim.atlas = doku
			yarim.region = Rect2(doku.get_width() * 0.5 * i, 0, doku.get_width() * 0.5, doku.get_height())
			var r := _sol if i == 0 else _sag
			r.texture = yarim
			r.size = Vector2(boyut.x / 2.0, boyut.y)
			r.pivot_offset = Vector2(r.size.x / 2.0, r.size.y)
			r.position = Vector2(_taban.x + (-0.5 if i == 0 else 0.5) * TESLIM_ARASI * _boy - r.size.x / 2.0, _taban.y - r.size.y)
			r.rotation = 0.0
			r.visible = true
	else:
		_sol.texture = doku
		_sol.size = boyut
		_sol.pivot_offset = Vector2(boyut.x / 2.0, boyut.y)
		_sol.position = Vector2(_taban.x - boyut.x / 2.0, _taban.y - boyut.y)
		_sol.rotation = 0.0
		_sol.visible = true
		_sag.visible = false


func _process(delta: float) -> void:
	if not _acik or not _sol.visible:
		return
	_zaman += delta
	match poz:
		"parmak":       # parmak sallar
			_sol.rotation = 0.16 * sin(_zaman * 11.0)
		"yalvar":       # kenetli eller yukarı aşağı titrer
			_sol.position.y = _taban.y - _sol.size.y + 2.5 * sin(_zaman * 7.0)
		"acik":         # açıklarken el hafifçe tartar
			_sol.rotation = 0.07 * sin(_zaman * 3.4)
			_sol.position.y = _taban.y - _sol.size.y + 2.0 * sin(_zaman * 3.4 + 1.0)
		"teslim":       # havadaki eller titrer
			_sol.rotation = 0.04 * sin(_zaman * 17.0)
			_sag.rotation = -0.04 * sin(_zaman * 15.0 + 0.6)
		"uzat":
			_sol.position.y = _taban.y - _sol.size.y + 1.5 * sin(_zaman * 2.2)
		_:              # eşikte: nefesle belli belirsiz kıpırdar, arada parmaklar tıkırdar
			_sol.position.y = _taban.y - _sol.size.y + 0.8 * sin(_zaman * 1.7)
			_sol.rotation = 0.012 * sin(_zaman * 0.9)
