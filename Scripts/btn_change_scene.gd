extends Button

signal level_changed(level_info)

@export var level_info: LevelInfo

func _on_pressed() -> void:
	level_changed.emit(level_info)
