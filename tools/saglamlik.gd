extends Node
## Sağlamlık testi: veri denetimi, kayıt bozma, üretici ve ipucu tutarlılığı, akış yarışları, maymun testi.
## Çalıştırma:  bash tools/saglamlik.sh [bölüm ...]

const Surucu := preload("res://tools/saglamlik_surucu.gd")


func _ready() -> void:
	var s := Surucu.new()
	s.name = "SaglamlikSurucu"
	get_tree().root.add_child.call_deferred(s)
