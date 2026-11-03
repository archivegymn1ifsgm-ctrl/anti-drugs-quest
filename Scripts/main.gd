extends Control

@onready var level_scene: PackedScene = preload("res://Scenes/level.tscn")
@onready var levels: Node = $VBoxContainer/levels

var current_level: Node

func _ready() -> void:
	$btnBack.hide()


func clear_level() -> void:
	$btnBack.hide()
	if current_level:
		current_level.queue_free()
		current_level = null


func _on__level_changed(level_info: LevelInfo) -> void:
	$btnBack.show()
	current_level = level_scene.instantiate()
	current_level.level_info = level_info
	add_child(current_level)
	move_child(current_level, $btnBack.get_index())


func _on_btn_back_pressed() -> void:
	clear_level()
