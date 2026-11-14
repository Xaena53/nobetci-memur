extends "res://tools/cekim_surucu.gd"
## Tanıtım filmi sürücüsü. Her sahne ayrı kaydedilir (bash tools/tanitim/cek.sh <sahne> <klasör>);
## kurgu tools/tanitim/kurgu.py ile yapılır. Oyun gerçek fare olaylarıyla oynanır, ekranda bir imleç
## çizilir. Kesim işaretleri (`iz`) film karesi numarasıyla <sahne>.json dosyasına yazılır.

var _izler: Dictionary = {}
var _sahne_adi := ""
var _imlec: Node2D
var _fare := Vector2(700, 520)
var _basili := false


func _calistir() -> void:
	var arg := OS.get_cmdline_user_args()
	_sahne_adi = arg[0] if arg.size() > 0 else "gise"
	Oyun.dil_sabit = _arg("dil", "tr")
	Oyun.ayarlari_sifirla()
	Oyun.ogretici_acik = false
	Oyun.ara_ekran_acik = false
	# filmin kendi müziği kurguda eklenir: kayıtta yalnız efektler ve ortam sesi kalır
	Oyun.ayar_degistir("muzik_acik", false)
	var ad := "_film_" + _sahne_adi
	if has_method(ad):
		await call(ad)
	else:
		print("Bilinmeyen sahne: ", _sahne_adi)
	var yol := _arg("cikti", ".") + "/" + _sahne_adi + ".json"
	var d := FileAccess.open(yol, FileAccess.WRITE)
	d.store_string(JSON.stringify(_izler, "  "))
	d.close()
	Oyun.kaydi_sil()
	Oyun.cik()


## Kurgu için işaret: o andaki film karesinin numarası.
func iz(ad: String) -> void:
	_izler[ad] = Engine.get_frames_drawn()
	print("iz ", ad, " = ", _izler[ad])


# --- İmleç ---

func _imleci_kur(yer: Vector2) -> void:
	var katman := CanvasLayer.new()
	katman.layer = 120
	add_child(katman)
	_imlec = Node2D.new()
	_imlec.scale = Vector2.ONE * 1.5
	katman.add_child(_imlec)
	var bicim := PackedVector2Array([Vector2(0, 0), Vector2(0, 17), Vector2(4.4, 13), Vector2(7.6, 19.6),
		Vector2(10.2, 18.4), Vector2(7.1, 12.3), Vector2(12.6, 12.3)])
	var golge := Polygon2D.new()
	golge.polygon = bicim
	golge.color = Color(0, 0, 0, 0.35)
	golge.position = Vector2(1.6, 2.2)
	_imlec.add_child(golge)
	var ok := Polygon2D.new()
	ok.polygon = bicim
	ok.color = Color(0.98, 0.97, 0.93)
	_imlec.add_child(ok)
	var kenar := Line2D.new()
	kenar.points = bicim
	kenar.closed = true
	kenar.width = 1.3
	kenar.default_color = Color(0.1, 0.08, 0.07)
	kenar.joint_mode = Line2D.LINE_JOINT_ROUND
	_imlec.add_child(kenar)
	_fare = yer
	_imlec.position = yer


func _hareket() -> void:
	_imlec.position = _fare
	var e := InputEventMouseMotion.new()
	e.position = _fare
	e.global_position = _fare
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if _basili else 0
	get_viewport().push_input(e, true)


## İmleci yumuşak bir yayla hedefe götürür (fare olaylarını da yollar).
func git(hedef: Vector2, sure: float = 0.45) -> void:
	var bas := _fare
	var yay := (hedef - bas).orthogonal().normalized() * minf(26.0, bas.distance_to(hedef) * 0.08)
	var t := 0.0
	while t < sure:
		await get_tree().process_frame
		t += get_process_delta_time()
		var k := clampf(t / sure, 0.0, 1.0)
		k = k * k * (3.0 - 2.0 * k)
		_fare = bas.lerp(hedef, k) + yay * sin(k * PI)
		_hareket()
	_fare = hedef
	_hareket()


func basili_tut() -> void:
	_basili = true
	fare_bas(_fare)
	_imlec.scale = Vector2.ONE * 1.35


func birak() -> void:
	_basili = false
	fare_birak(_fare)
	_imlec.scale = Vector2.ONE * 1.5


func tikla() -> void:
	basili_tut()
	await kare(3)
	birak()
	await kare(1)


func _orta(c: Control, oran: Vector2 = Vector2(0.5, 0.5)) -> Vector2:
	return c.get_global_transform() * (c.size * oran)


## Düğmeye imleçle gidip tıklar; tık işlemediyse (üstünde başka bir katman varsa) sinyali doğrudan yollar.
func dugmeye_tikla(ad: String, sure: float = 0.45, oran: Vector2 = Vector2(0.5, 0.5)) -> void:
	var d := dugme(ad)
	if d == null:
		print("düğme yok: ", ad)
		return
	await git(_orta(d, oran), sure)
	var sayac := [0]
	var say := func() -> void: sayac[0] += 1
	d.pressed.connect(say)
	await tikla()
	if is_instance_valid(d):
		d.pressed.disconnect(say)
		if sayac[0] == 0:
			print("  (tık işlemedi, sinyal yollandı: ", ad, ")")
			d.pressed.emit()


func _bekle_kosul(kosul: Callable, en_cok: float = 20.0) -> bool:
	var t := 0.0
	while t < en_cok:
		if kosul.call():
			return true
		await get_tree().process_frame
		t += get_process_delta_time()
	print("  (koşul zaman aşımı)")
	return false


# --- Sahneler ---

## Gişe: vatandaş gelir, soyadlar karşılaştırılır, ret mührü basılır.
func _film_gise() -> void:
	var masa: Node = await _gune_git(1)
	_imleci_kur(Vector2(760, 610))
	# soyadı ilmühaberde farklı yazılmış bir vatandaş
	var v: Dictionary = {}
	for tohum in range(int(_arg("tohum", "3")), 400):
		var rng := RandomNumberGenerator.new()
		rng.seed = tohum
		v = VatandasUretici.uret(masa.gun, rng, [], 0)
		if not Dogrulayici.belge_sozlugu(v).has("ikametgah"):
			continue
		if VatandasUretici.kusur_uygula(v, "soyad", masa.gun, rng) == "ad_soyad":
			print("vatandaş tohumu: ", tohum, "  karar: ", Dogrulayici.kontrol(v, masa.gun).karar)
			break
	masa.kuyruk[0] = v
	await bekle(0.6)
	iz("genelge")
	await dugmeye_tikla("GiseyiAc", 0.7)
	iz("acilis")
	await _bekle_kosul(func() -> bool: return masa.belgeler.size() >= 2 and not masa._mesgul)
	iz("belgeler")
	await bekle(1.2)

	# inceleme: iki soyada tıkla
	await dugmeye_tikla("Incele", 0.55)
	if not masa.inceleme.aktif:
		masa.inceleme.aktif = true
	await bekle(0.25)
	var cuzdan := _belge(masa, "nufus_cuzdani")
	var ikamet := _belge(masa, "ikametgah")
	iz("inceleme")
	await _hedefe_tikla(masa, cuzdan.alanlar["soyad"], 0.5)
	await bekle(0.3)
	await _hedefe_tikla(masa, ikamet.alanlar["soyad"], 0.55)
	iz("uyusmaz")
	await bekle(2.0)
	await dugmeye_tikla("Incele", 0.5)
	if masa.inceleme.aktif:
		masa.inceleme.aktif = false
	await bekle(0.3)

	# ret mührünü ilmühabere sürükle
	var muhur: Arac = masa.araclar["eksik"]
	await git(_orta(muhur), 0.45)
	iz("muhur_al")
	basili_tut()
	await kare(4)
	await git(_orta(ikamet, Vector2(0.62, 0.52)), 0.7)
	await kare(3)
	birak()
	iz("birak")
	await _bekle_kosul(func() -> bool: return masa.find_child("GerekcePenceresi", true, false) != null, 3.0)
	await bekle(0.7)
	await dugmeye_tikla("Gerekce_ad_soyad", 0.5)
	iz("muhur")
	await git(_fare + Vector2(150, 60), 0.5)
	await bekle(4.0)
	iz("son")


func _hedefe_tikla(masa: Node, h: Hedef, sure: float) -> void:
	await git(_orta(h), sure)
	var once: int = masa.inceleme._cizgiler.size()
	var ilk_once: Hedef = masa.inceleme._ilk
	await tikla()
	await kare(2)
	if masa.inceleme._cizgiler.size() == once and masa.inceleme._ilk == ilk_once:
		print("  (hedef tıkı işlemedi, doğrudan çağrıldı)")
		masa.inceleme.hedef_tiklandi(h)


## Röntgen: "Terzi"nin el çantası taranır, alarm verilir.
func _film_rontgen() -> void:
	var masa: Node = await _gune_git(6)
	_imleci_kur(Vector2(640, 560))
	_one_al(masa, "naciye6")
	await bekle(0.5)
	await dugmeye_tikla("GiseyiAc", 0.6)
	iz("acilis")
	await _bekle_kosul(func() -> bool: return masa.canta_asamasi == "bekliyor")
	await bekle(1.0)
	iz("canta")
	await dugmeye_tikla("CantayiTara", 0.6)
	iz("tara")
	await _bekle_kosul(func() -> bool: return masa.rontgen.karar_bekliyor)
	iz("ekran")
	await git(_fare + Vector2(120, 40), 0.5)
	await bekle(1.0)
	await dugmeye_tikla("RontgenKip1", 0.45)
	await bekle(0.9)
	await dugmeye_tikla("RontgenKip0", 0.3)
	await bekle(0.4)
	await dugmeye_tikla("RontgenAlarm", 0.5)
	iz("alarm")
	await bekle(8.0)
	iz("son")


## Akşam defteri: maaş kira, kömür ve yiyecek arasında bölüştürülür.
func _film_ev() -> void:
	Oyun.yeni_oyun("orta")
	Oyun.ayar_degistir("muzik_acik", false)
	Oyun.gun = int(_arg("gun", "2"))
	Oyun.para = int(_arg("para", "850"))
	await sahneye_git("aile")
	await sahneyi_bekle("Aile")
	_imleci_kur(Vector2(900, 520))
	var aile := sahne()
	print("kalemler: ", aile.kalemler)
	await bekle(1.6)
	iz("basla")
	for kod: String in ["kira", "yemek", "komur"]:
		if dugme("Kalem_" + kod) == null:
			continue
		await dugmeye_tikla("Kalem_" + kod, 0.5, Vector2(0.12, 0.5))
		iz("sec_" + kod)
		await bekle(0.75)
	await git(_fare + Vector2(-190, 90), 0.6)
	await bekle(3.0)
	iz("son")


## Ana menü: önce kâğıtsız (açılış görüntüsü), sonra başlığın daktiloyla yazıldığı hâli.
func _film_menu() -> void:
	Oyun.kaydi_sil()
	await sahneye_git("menu")
	await sahneyi_bekle("AnaMenu")
	var menu := sahne()
	for ad: String in ["MenuKagidi", "Kunye", "Yapimci"]:
		var d := menu.find_child(ad, true, false) as CanvasItem
		if d != null:
			d.visible = false
	await bekle(0.6)
	iz("bos")
	await bekle(9.0)
	iz("bos_son")
	# ikinci tur: sahne baştan, başlık yazılırken
	var eski := menu.get_instance_id()
	Oyun.sahneye_gec("menu")
	await bekle(0.2)
	await _bekle_kosul(func() -> bool: return not Oyun.geciste_mi() and sahne() != null and sahne().get_instance_id() != eski and sahne().name == "AnaMenu", 6.0)
	iz("baslik")
	await bekle(9.0)
	iz("son")
