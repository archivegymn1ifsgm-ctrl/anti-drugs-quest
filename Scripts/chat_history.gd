extends Node
## Автозагрузка (Autoload) с именем "ChatHistory".
## Хранит все сообщения и сохраняет их в user://chat_history.json,
## так что история переживает смену сцены и перезапуск игры.

const SAVE_PATH := "user://chat_history.json"

## Каждое сообщение: { "text": String, "player": bool }
var messages: Array[Dictionary] = []


func _ready() -> void:
	load_from_disk()


func add(text: String, is_player: bool) -> void:
	messages.append({"text": text, "player": is_player})
	save_to_disk()


func clear() -> void:
	messages.clear()
	save_to_disk()


func save_to_disk() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("ChatHistory: не удалось открыть файл для записи")
		return
	file.store_string(JSON.stringify(messages))


func load_from_disk() -> void:
	messages.clear()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	if data is Array:
		for item in data:
			if item is Dictionary and item.has("text"):
				messages.append({
					"text": str(item["text"]),
					"player": bool(item.get("player", false)),
				})
