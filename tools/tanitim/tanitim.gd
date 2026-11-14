extends Node
## Tanıtım filmi düzeneği: oyunu kodla sürer, Godot'un film kaydı (--write-movie) görüntüyü ve sesi yazar.
## Çalıştırma:  bash tools/tanitim/cek.sh <sahne> <çıktı klasörü>     (pencere ekran dışında açılır)

const Surucu := preload("res://tools/tanitim/tanitim_surucu.gd")


func _ready() -> void:
	var s := Surucu.new()
	s.name = "TanitimSurucu"
	get_tree().root.add_child.call_deferred(s)
