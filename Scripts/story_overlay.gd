class_name StoryOverlay
extends Control
## Полноэкранный слой поверх чата:
##   - чёрный экран с репликами рассказчика (печатаются, переключаются щелчком);
##   - экран финала: красная плашка SOS по центру + кнопка «Начать заново».
## Создаётся и управляется из StoryPlayer, руками добавлять не нужно.

signal restart_pressed
signal _clicked
signal _typing_done

@export var fade_time: float = 0.6
## Скорость «печати» текста рассказчика: секунд на символ.
@export var seconds_per_char: float = 0.035
@export var max_text_width: float = 760.0
@export_range(0.3, 1.0) var width_ratio: float = 0.85

@onready var narration: Label = %Narration
@onready var narration_center: CenterContainer = $NarrationCenter
@onready var hint: Label = $Hint
@onready var end_center: CenterContainer = %EndCenter
@onready var sos_panel: PanelContainer = %SosPanel
@onready var sos_text: Label = %SosText
@onready var restart_button: Button = %RestartButton

var _typing := false
var _tween: Tween
var _fade_tween: Tween
var _hint_tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	narration.text = ""
	hint.modulate.a = 0.0
	end_center.visible = false
	restart_button.pressed.connect(func(): restart_pressed.emit())
	gui_input.connect(_on_gui_input)
	resized.connect(_update_widths)
	_style_restart_button()


# ---------- Публичный API ----------

## Мгновенно закрыть экран чёрным (чтобы чат не мелькал при старте).
func cover_instantly() -> void:
	visible = true
	modulate.a = 1.0
	narration.text = ""
	narration_center.visible = true
	end_center.visible = false
	_update_widths()


## Чёрный экран + реплики по очереди. Щелчок: дописать текст / перейти к следующей.
## Экран остаётся чёрным — убрать его можно через fade_out().
func show_lines(lines: Array) -> void:
	await _fade_in()
	end_center.visible = false
	narration_center.visible = true
	_update_widths()
	for line in lines:
		await _type_line(str(line))
		await _wait_click()
	narration.text = ""


## Экран финала: красная плашка SOS (если текст не пустой) и кнопка рестарта.
## Ждёт, пока игрок нажмёт «Начать заново».
func show_end(sos: String) -> void:
	_show_hint(false)
	await _fade_in()
	narration_center.visible = false
	sos_panel.visible = sos != ""
	sos_text.text = sos
	_update_widths()
	end_center.modulate.a = 0.0
	end_center.visible = true
	create_tween().tween_property(end_center, "modulate:a", 1.0, fade_time)
	await restart_pressed


## Плавно убрать чёрный экран.
func fade_out() -> void:
	if not visible:
		return
	_show_hint(false)
	_kill(_fade_tween)
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 0.0, fade_time)
	await _fade_tween.finished
	visible = false
	narration.text = ""
	narration_center.visible = true
	end_center.visible = false


# ---------- Внутреннее ----------

func _fade_in() -> void:
	if visible and modulate.a >= 0.99:
		return
	if not visible:
		modulate.a = 0.0
		visible = true
	_kill(_fade_tween)
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 1.0, fade_time)
	await _fade_tween.finished


func _type_line(text: String) -> void:
	_show_hint(false)
	narration.text = text
	narration.visible_ratio = 0.0
	var duration := clampf(text.length() * seconds_per_char, 0.3, 5.0)
	_typing = true
	_kill(_tween)
	_tween = create_tween()
	_tween.tween_property(narration, "visible_ratio", 1.0, duration)
	_tween.finished.connect(_finish_typing)
	await _typing_done


func _finish_typing() -> void:
	if not _typing:
		return
	_typing = false
	narration.visible_ratio = 1.0
	_typing_done.emit()


func _wait_click() -> void:
	_show_hint(true)
	await _clicked
	_show_hint(false)


func _on_click() -> void:
	if _typing:
		_kill(_tween)
		_finish_typing()      # первый щелчок — дописать фразу целиком
	else:
		_clicked.emit()       # второй — дальше


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_on_click()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_on_click()


func _show_hint(on: bool) -> void:
	_kill(_hint_tween)
	hint.modulate.a = 0.0
	if on:
		_hint_tween = create_tween().set_loops()
		_hint_tween.tween_property(hint, "modulate:a", 0.8, 0.8)
		_hint_tween.tween_property(hint, "modulate:a", 0.25, 0.8)


func _update_widths() -> void:
	var w := minf(size.x * width_ratio, max_text_width)
	narration.custom_minimum_size.x = w
	sos_text.custom_minimum_size.x = maxf(w - 64.0, 100.0)   # 64 = отступы плашки


func _kill(t: Tween) -> void:
	if t and t.is_valid():
		t.kill()


func _style_restart_button() -> void:
	restart_button.add_theme_stylebox_override("normal", _button_box(Color("ffffff")))
	restart_button.add_theme_stylebox_override("hover", _button_box(Color("e6e6e6")))
	restart_button.add_theme_stylebox_override("pressed", _button_box(Color("cccccc")))
	restart_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		restart_button.add_theme_color_override(c, Color("1b1b1b"))


func _button_box(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(32)
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s
