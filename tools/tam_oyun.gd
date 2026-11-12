extends Node
## Tam oyun testi: yedi günü baştan sona kodla oynar (bkz. tam_oyun_surucu.gd).
## Çalıştırma:  godot --headless --path . res://tools/TamOyun.tscn

const Surucu := preload("res://tools/tam_oyun_surucu.gd")


func _ready() -> void:
	var s := Surucu.new()
	s.name = "TamOyunSurucu"
	get_tree().root.add_child.call_deferred(s)
