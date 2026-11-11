extends Node
## Oyun (Autoload) — kalıcı oyun durumu, kayıt/yükleme ve sahne geçişleri.
## Sahneler bu düğüme "Oyun" adıyla her yerden ulaşır.

signal durum_degisti

const SURUM := 1
const TOPLAM_GUN := 7
const BASLANGIC_PARASI := 500
const SAHNELER := {
	"menu": "res://scenes/AnaMenu.tscn",
	"masa": "res://scenes/Masa.tscn",
	"gun_sonu": "res://scenes/GunSonu.tscn",
	"aile": "res://scenes/Aile.tscn",
}

var kayit_yolu := "user://kayit.json"  ## testler kendi dosyasını kullanır

var gun: int = 1
var para: int = BASLANGIC_PARASI
var ihtar: int = 0            ## oyun boyunca alınan toplam ihtar
var gun_ozeti: Dictionary = {}  ## biten mesainin özeti (Gün Sonu ekranı okur)

var _perde: ColorRect
var _geciste := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.theme = Stil.tema()
	_perde_kur()


# --- Oyun akışı ---

func yeni_oyun() -> void:
	gun = 1
	para = BASLANGIC_PARASI
	ihtar = 0
	gun_ozeti = {}
	kaydet()
	durum_degisti.emit()


## Aile ekranından sonra çağrılır; son gün de bittiyse false döner.
func sonraki_gun() -> bool:
	if gun >= TOPLAM_GUN:
		return false
	gun += 1
	gun_ozeti = {}
	kaydet()
	durum_degisti.emit()
	return true


# --- Kayıt / yükleme (user://kayit.json) ---

func kayit_var_mi() -> bool:
	return FileAccess.file_exists(kayit_yolu)


func kayit_verisi() -> Dictionary:
	return {
		"surum": SURUM,
		"gun": gun,
		"para": para,
		"ihtar": ihtar,
	}


func kayittan_al(veri: Dictionary) -> void:
	gun = clampi(int(veri.get("gun", 1)), 1, TOPLAM_GUN)
	para = int(veri.get("para", BASLANGIC_PARASI))
	ihtar = int(veri.get("ihtar", 0))
	gun_ozeti = {}


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
	var dosya := FileAccess.open(kayit_yolu, FileAccess.READ)
	if dosya == null:
		return false
	var veri: Variant = JSON.parse_string(dosya.get_as_text())
	dosya.close()
	if typeof(veri) != TYPE_DICTIONARY:
		push_warning("Kayıt dosyası okunamadı; yok sayılıyor.")
		return false
	kayittan_al(veri)
	durum_degisti.emit()
	return true


func kaydi_sil() -> void:
	if kayit_var_mi():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(kayit_yolu))


# --- Sahne geçişleri (kısa kararma ile) ---

func sahneye_gec(ad: String) -> void:
	if _geciste or not SAHNELER.has(ad):
		return
	_geciste = true
	_perde.mouse_filter = Control.MOUSE_FILTER_STOP
	var kapan := create_tween()
	kapan.tween_property(_perde, "color:a", 1.0, 0.22)
	await kapan.finished
	get_tree().change_scene_to_file(SAHNELER[ad])
	await get_tree().process_frame
	await get_tree().process_frame
	var acil := create_tween()
	acil.tween_property(_perde, "color:a", 0.0, 0.28)
	await acil.finished
	_perde.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_geciste = false


func geciste_mi() -> bool:
	return _geciste


func _perde_kur() -> void:
	var katman := CanvasLayer.new()
	katman.layer = 100
	add_child(katman)
	_perde = ColorRect.new()
	_perde.color = Color(Stil.GECE, 0.0)
	_perde.set_anchors_preset(Control.PRESET_FULL_RECT)
	_perde.mouse_filter = Control.MOUSE_FILTER_IGNORE
	katman.add_child(_perde)
