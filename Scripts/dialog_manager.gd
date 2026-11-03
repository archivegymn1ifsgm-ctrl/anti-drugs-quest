class_name DialogManager
extends RefCounted
## Хранит диалог и текущую позицию. Про интерфейс ничего не знает.
##
## Формат JSON: { "id": { "speaker": "...", "text": "...", "next": "id", "choices": [ {"text": "...", "next": "id"} ] } }
## Старт — реплика "START". Пустой "next" = конец.

const START_MARKER := "START"

var dialogue: Dictionary = {}
var pos: String = ""


## Загружает JSON. Возвращает false, если файл не найден или сломан.
func init_dialogue(path: String) -> bool:
	var json := FileAccess.get_file_as_string(path)
	if json.is_empty():
		push_error("DialogManager: файл '%s' не найден или пуст" % path)
		return false
	var data = JSON.parse_string(json)
	if not (data is Dictionary):
		push_error("DialogManager: в '%s' ошибка JSON (ожидался объект)" % path)
		return false
	dialogue = data
	if not dialogue.has(START_MARKER):
		push_error("DialogManager: в диалоге нет реплики '%s'" % START_MARKER)
		return false
	_validate()
	restart()
	return true


func restart() -> void:
	pos = START_MARKER


## Отдаёт текущую реплику и двигает позицию на её "next".
## Если у реплики есть choices, позиция сбрасывается и ждёт choose().
## Пустой словарь = диалог закончился.
func next_line() -> Dictionary:
	if not dialogue.has(pos):
		return {}
	var line: Dictionary = dialogue[pos]
	var choices: Array = line.get("choices", [])
	pos = "" if not choices.is_empty() else str(line.get("next", ""))
	return line


## Игрок выбрал вариант: переходим на его "next".
func choose(next_id: String) -> void:
	pos = next_id


## Проверка опечаток: все "next" должны вести на существующие реплики.
func _validate() -> void:
	for id in dialogue:
		var line: Dictionary = dialogue[id]
		var targets: Array = [str(line.get("next", ""))]
		for c in line.get("choices", []):
			targets.append(str(c.get("next", "")))
		for t in targets:
			if t != "" and not dialogue.has(t):
				push_warning("DialogManager: '%s' ведёт на несуществующую '%s'" % [id, t])
