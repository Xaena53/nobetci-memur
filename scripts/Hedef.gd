class_name Hedef
extends Control
## İnceleme modunda tıklanabilen bir bilgi parçası: belge alanı, kural satırı,
## vatandaşın yüzü ya da duvar takvimi. İki hedef seçilince karşılaştırılır.

signal tiklandi(hedef: Hedef)

enum Durum { BOS, SECILI, UYUSMAZ, UYUMLU }

var tip := "alan"            ## "alan" | "kural" | "yuz" | "takvim"
var anahtar := ""            ## alan anahtarı (ad, soyad, tarih...) ya da kural kimliği
var deger: Variant = null
var belge_turu := ""         ## tip == "alan" ise ait olduğu belge türü
var etiket := ""             ## okunur ad ("Soyadı")
var kural: Dictionary = {}   ## tip == "kural" ise kuralın kendisi
var cerceve_payi := 2.0

var durum: Durum = Durum.BOS:
	set(d):
		durum = d
		queue_redraw()

var aktif := false:
	set(a):
		aktif = a
		mouse_filter = MOUSE_FILTER_STOP if a else MOUSE_FILTER_IGNORE
		if not a:
			_uzerinde = false
			if durum == Durum.SECILI or durum == Durum.UYUMLU:
				durum = Durum.BOS
		queue_redraw()

var _uzerinde := false


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = CURSOR_POINTING_HAND
	mouse_entered.connect(func() -> void:
		_uzerinde = true
		queue_redraw())
	mouse_exited.connect(func() -> void:
		_uzerinde = false
		queue_redraw())


## Kural motorunun (Dogrulayici.karsilastir) beklediği sade özet.
func ozet() -> Dictionary:
	return {"tip": tip, "anahtar": anahtar, "deger": deger, "belge": belge_turu, "kural": kural, "etiket": etiket}


## Ekran (tuval) koordinatlarında orta nokta; inceleme çizgileri buraya bağlanır.
func merkez() -> Vector2:
	return get_global_transform() * (size / 2.0)


func _gui_input(event: InputEvent) -> void:
	if not aktif:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		tiklandi.emit(self)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size).grow(cerceve_payi)
	match durum:
		Durum.SECILI:
			draw_rect(r, Color(Stil.KIRMIZI, 0.10))
			draw_rect(r, Stil.KIRMIZI, false, 2.0)
		Durum.UYUSMAZ:
			draw_rect(r, Color(Stil.KIRMIZI, 0.16))
			draw_rect(r, Stil.KIRMIZI, false, 2.0)
		Durum.UYUMLU:
			draw_rect(r, Color(Stil.YESIL, 0.12))
			draw_rect(r, Color(Stil.YESIL, 0.9), false, 1.5)
		_:
			if aktif and _uzerinde:
				draw_rect(r, Color(Stil.MUREKKEP, 0.08))
				draw_rect(r, Color(Stil.MUREKKEP, 0.55), false, 1.0)
			elif aktif:
				_kesikli(r, Color(Stil.MUREKKEP, 0.28))


## İnceleme modunda tıklanabilir yerleri belli eden kesikli çerçeve.
func _kesikli(r: Rect2, renk: Color) -> void:
	var koseler := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		draw_dashed_line(koseler[i], koseler[(i + 1) % 4], renk, 1.0, 4.0)
