extends Node
## Duman testi: oyunu baştan sona kodla "oynar", her adımda beklenen durumu denetler.
## Çalıştırma:  godot --headless --path . res://tools/DumanTesti.tscn
## Başarıda çıkış kodu 0, hatada 1 döner. Kendi kayıt dosyasını kullanır.

const Surucu := preload("res://tools/test_surucu.gd")


func _ready() -> void:
	var s := Surucu.new()
	s.name = "TestSurucu"
	get_tree().root.add_child.call_deferred(s)
