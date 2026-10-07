class_name StoryPlayer
extends Node
## Проигрывает сюжет из JSON (Assets/Story/*.json) в чате.
## Добавь как дочерний узел к корню Chat (сцена chat.tscn).
##
## Как показываются реплики:
##   "stranger"           -> пузырь слева, перед ним анимация «печатает…» (три точки)
##   "narrator" / "system" -> чёрный экран, текст печатается, переключение щелчком
## Финал: реплики рассказчика на чёрном экране -> красная плашка SOS -> «Начать заново».

signal story_finished(ending: Dictionary)
signal story_restarted

const OVERLAY_SCENE := preload("res://Scenes/story_overlay.tscn")

@export_file("*.json") var story_path: String = "res://Assets/Story/stranger_1.json"
@export var autostart: bool = true
## Сколько «печатает…» перед сообщением: base + секунд на символ, но не больше max.
@export var typing_base: float = 0.8
@export var typing_per_char: float = 0.02
@export var typing_max: float = 2.5
## Короткая пауза после сообщения собеседника.
@export var message_gap: float = 0.3

var chat: Control             # корень сцены чата (chat.gd)
var overlay: StoryOverlay
var _nodes: Dictionary = {}
var _start := ""
var _current: Dictionary = {}


func _ready() -> void:
	chat = get_parent()
	if not _load_story():
		return
	chat.choice_selected.connect(_on_choice_selected)
	await get_tree().process_frame   # родитель (Chat) должен закончить свой _ready
	overlay = OVERLAY_SCENE.instantiate()
	chat.add_child(overlay)          # последним ребёнком = поверх всего
	overlay.cover_instantly()        # старт с чёрного экрана
	if autostart:
		play(_start)


## Проиграть узел сюжета по id.
func play(id: String) -> void:
	if not _nodes.has(id):
		push_error("StoryPlayer: нет узла '%s'" % id)
		return
	var node: Dictionary = _nodes[id]
	_current = node
	var messages: Array = node["messages"]

	var i := 0
	while i < messages.size():
		if _is_narrator(messages[i]):
			# подряд идущие реплики рассказчика = один «чёрный экран»
			var lines: Array = []
			while i < messages.size() and _is_narrator(messages[i]):
				lines.append(messages[i]["text"])
				i += 1
			await overlay.show_lines(lines)
		else:
			var text: String = messages[i]["text"]
			await _show_chat()
			chat.show_typing()
			await get_tree().create_timer(_typing_time(text)).timeout
			chat.hide_typing()
			chat.add_message(text, false)
			await get_tree().create_timer(message_gap).timeout
			i += 1

	var choices: Array = node["choices"]
	if choices.is_empty():
		await _finish(node)
	else:
		await _show_chat()
		var texts: Array = []
		for c in choices:
			texts.append(c["text"])
		chat.show_choices(texts)


func _on_choice_selected(index: int, _text: String) -> void:
	var choices: Array = _current.get("choices", [])
	if index < 0 or index >= choices.size():
		return
	var next_id = choices[index]["next"]
	if next_id == null:
		push_warning("StoryPlayer: у варианта «%s» нет продолжения" % choices[index]["text"])
		return
	play(next_id)


func _finish(node: Dictionary) -> void:
	var sos_text := ""
	var sos = node.get("sos")
	if sos is Dictionary:
		sos_text = sos["text"]
	story_finished.emit(node)
	await overlay.show_end(sos_text)   # ждёт кнопку «Начать заново»
	chat.reset()                       # экран чёрный, чат чистим незаметно
	story_restarted.emit()
	play(_start)


## Убрать чёрный экран, если он сейчас закрывает чат.
func _show_chat() -> void:
	if overlay.visible:
		await overlay.fade_out()


func _is_narrator(m: Dictionary) -> bool:
	return m["from"] == "narrator" or m["from"] == "system"


func _typing_time(text: String) -> float:
	return minf(typing_base + text.length() * typing_per_char, typing_max)


func _load_story() -> bool:
	var file := FileAccess.open(story_path, FileAccess.READ)
	if file == null:
		push_error("StoryPlayer: не удалось открыть %s" % story_path)
		return false
	var data = JSON.parse_string(file.get_as_text())
	if not (data is Dictionary) or not data.has("nodes") or not data.has("start"):
		push_error("StoryPlayer: неверный формат %s" % story_path)
		return false
	_nodes = data["nodes"]
	_start = data["start"]
	return true
