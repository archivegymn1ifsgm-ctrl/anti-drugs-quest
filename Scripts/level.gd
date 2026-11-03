extends Control

@export var level_info: LevelInfo
@export var restart_text: String = "Начать заново"

@onready var background: TextureRect = $Background
@onready var chat: Chat = $Chat

var dm: DialogManager


func _ready() -> void:
	if level_info == null:
		push_error("Level: не назначен level_info")
		return
		
	if level_info.background_path != "":
		background.texture = load(level_info.background_path)

	dm = DialogManager.new()
	if not dm.init_dialogue(level_info.script_path):
		return
	
	_run()


func _run() -> void:
	while true:
		await _play_dialogue()
		await _wait_restart()


func _play_dialogue() -> void:
	dm.restart()
	while true:
		var line := dm.next_line()
		if line.is_empty():
			return
		
		var text: String = line.get("text", "")
		if text != "":
			await chat.say(line.get("speaker", ""), text)
		
		var choices: Array = line.get("choices", [])
		if not choices.is_empty():
			await _ask(choices)


func _ask(choices: Array) -> void:
	var texts: Array = []
	for c in choices:
		texts.append(c["text"])
	
	chat.show_choices(texts)
	var picked: Array = await chat.choice_selected
	dm.choose(str(choices[picked[0]].get("next", "")))


func _wait_restart() -> void:
	chat.show_choices([restart_text])
	await chat.choice_selected
	chat.reset()
