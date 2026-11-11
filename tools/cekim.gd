extends Node
## Ekran görüntüsü düzeneği: oyunu kodla sürer, kareleri tools/cikti/ altına PNG yazar.
## Çalıştırma:  bash tools/cek.sh <senaryo>     (pencere ekran dışında, odak almadan açılır)

const Surucu := preload("res://tools/cekim_surucu.gd")


func _ready() -> void:
	var s := Surucu.new()
	s.name = "CekimSurucu"
	get_tree().root.add_child.call_deferred(s)
