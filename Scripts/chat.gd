extends Control
## Чат: сообщения и панель ввода живут в разных контейнерах.
##
## Внизу всегда видна полоска (InputBar). Над ней раскрывается панель с 2-3 вариантами:
##   - автоматически, когда вызван show_choices([...]);
##   - по нажатию на полоску (если есть варианты);
##   - сворачивается при прокрутке сообщений или повторном нажатии на полоску.

signal choice_selected(index: int, text: String)

## Тестовый сценарий. Выключи, когда подключишь сюжет.
@export var demo: bool = false
@export var bar_placeholder: String = "Выберите ответ…"
@export var bar_waiting: String = "…"
@export var anim_time: float = 0.25
@export var choice_color := Color("8fd694")
## Боковые поля вокруг сообщений как доля ширины экрана (0.04 = 4%).
@export_range(0.0, 0.2) var side_margin_ratio: float = 0.04

@onready var messages_scroll: ScrollContainer = %MessagesScroll
@onready var messages_box: VBoxContainer = %Messages
@onready var input_area: PanelContainer = %InputArea
@onready var choices_clip: Control = %ChoicesClip
@onready var choices_margin: MarginContainer = %ChoicesMargin
@onready var choices_box: VBoxContainer = %Choices
@onready var input_bar: Button = %InputBar

var _has_choices := false     # есть ли сейчас варианты ответа
var _expanded := false        # раскрыта ли панель вариантов
var _follow_bottom := true    # держать ли список сообщений прижатым к низу
var _height_tween: Tween
var _typing_balloon: ChatBalloon
var _avail_width := 0.0       # ширина под пузыри (без полей и полосы прокрутки)


func _ready() -> void:
	_style_ui()

	var vbar := messages_scroll.get_v_scroll_bar()
	vbar.changed.connect(_on_scroll_range_changed)
	vbar.gui_input.connect(_on_scroll_input)
	messages_scroll.gui_input.connect(_on_scroll_input)
	messages_scroll.scroll_started.connect(_on_user_scrolled)  # тач-прокрутка
	input_bar.pressed.connect(_on_bar_pressed)
	messages_scroll.resized.connect(_on_layout_resized)

	choices_clip.custom_minimum_size.y = 0.0
	_update_bar()

	if demo:
		choice_selected.connect(_on_demo_choice)
		_run_demo()


# ---------- Публичный API ----------

## Добавить сообщение вниз списка. is_player = true -> справа,
## is_system = true -> по центру (рассказчик/итог), иначе слева.
func add_message(text: String, is_player: bool = false, is_system: bool = false) -> void:
	_spawn_balloon(text, is_player, true, is_system)
	_follow_bottom = true


## Показать пузырь «печатает…» (три точки). Перед add_message вызови hide_typing().
func show_typing() -> void:
	if _typing_balloon:
		return
	_typing_balloon = BALLOON_SCENE.instantiate()
	messages_box.add_child(_typing_balloon)
	_typing_balloon.setup_typing()
	_follow_bottom = true


func hide_typing() -> void:
	if _typing_balloon:
		messages_box.remove_child(_typing_balloon)
		_typing_balloon.queue_free()
		_typing_balloon = null


## Полностью очистить чат (для перезапуска сюжета).
func reset() -> void:
	hide_typing()
	for b in messages_box.get_children():
		messages_box.remove_child(b)
		b.queue_free()
	if _height_tween:
		_height_tween.kill()
	_has_choices = false
	_expanded = false
	choices_clip.custom_minimum_size.y = 0.0
	_clear_choices()
	_follow_bottom = true
	_update_bar()


## Показать варианты (2-3) и сразу раскрыть панель.
func show_choices(options: Array) -> void:
	_clear_choices()
	_has_choices = not options.is_empty()
	for i in options.size():
		var btn := Button.new()
		btn.text = str(options[i])
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(0, 56)
		btn.add_theme_font_size_override("font_size", 20)
		_apply_button_style(btn, choice_color, choice_color.darkened(0.1), 22)
		btn.pressed.connect(_on_choice_pressed.bind(i, btn.text))
		choices_box.add_child(btn)
	_update_bar()
	if not _has_choices:
		return
	await get_tree().process_frame  # чтобы контейнер пересчитал высоту кнопок
	_set_expanded(true)


## Убрать варианты (панель сворачивается, полоска остаётся неактивной).
func hide_choices() -> void:
	_has_choices = false
	_set_expanded(false)


# ---------- Панель выбора ----------

func _set_expanded(value: bool, animate: bool = true) -> void:
	value = value and _has_choices
	_expanded = value
	if value:
		_follow_bottom = true  # последние сообщения остаются видны над панелью

	var target := 0.0
	if value:
		target = choices_margin.get_combined_minimum_size().y

	if _height_tween:
		_height_tween.kill()
	if animate:
		_height_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_height_tween.tween_property(choices_clip, "custom_minimum_size:y", target, anim_time)
		if not value:
			_height_tween.finished.connect(_on_collapse_finished)
	else:
		choices_clip.custom_minimum_size.y = target
		if not value:
			_on_collapse_finished()
	_update_bar()


func _on_collapse_finished() -> void:
	if not _has_choices:
		_clear_choices()


func _on_bar_pressed() -> void:
	if _has_choices:
		_set_expanded(not _expanded)


func _on_choice_pressed(index: int, text: String) -> void:
	if not _has_choices:
		return
	_has_choices = false
	for b in choices_box.get_children():
		b.disabled = true
	_set_expanded(false)          # панель сворачивается, затем кнопки удаляются
	add_message(text, true)       # выбранный ответ уходит как сообщение игрока
	choice_selected.emit(index, text)


func _clear_choices() -> void:
	for c in choices_box.get_children():
		choices_box.remove_child(c)
		c.queue_free()


func _update_bar() -> void:
	input_bar.disabled = not _has_choices
	input_bar.text = bar_placeholder if _has_choices else bar_waiting


# ---------- Прокрутка сообщений ----------

func _on_scroll_range_changed() -> void:
	if _follow_bottom:
		messages_scroll.scroll_vertical = int(messages_scroll.get_v_scroll_bar().max_value)


## Ловим именно пользовательскую прокрутку (колесо, тач, перетаскивание полосы),
## чтобы не путать её с программной.
func _on_scroll_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP
				or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			_on_user_scrolled()
	elif event is InputEventScreenDrag or event is InputEventPanGesture:
		_on_user_scrolled()
	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_on_user_scrolled()


func _on_user_scrolled() -> void:
	_follow_bottom = false
	if _expanded:
		_set_expanded(false)  # складываем варианты, остаётся только полоска


# ---------- Сообщения ----------

const BALLOON_SCENE := preload("res://Scenes/chat_balloon.tscn")


## Пересчитывает боковые поля и ширину всех пузырей под текущий размер окна.
func _on_layout_resized() -> void:
	var w := messages_scroll.size.x
	var m := int(w * side_margin_ratio)
	var margin := messages_box.get_parent() as MarginContainer
	margin.add_theme_constant_override("margin_left", m)
	margin.add_theme_constant_override("margin_right", m)
	var bar_w := messages_scroll.get_v_scroll_bar().get_combined_minimum_size().x
	_avail_width = w - 2.0 * m - bar_w
	for b in messages_box.get_children():
		if b is ChatBalloon:
			(b as ChatBalloon).update_width(_avail_width)


func _spawn_balloon(text: String, is_player: bool, animate: bool, is_system: bool = false) -> void:
	var balloon: ChatBalloon = BALLOON_SCENE.instantiate()
	messages_box.add_child(balloon)   # сначала в дерево...
	balloon.setup(text, is_player, animate, is_system)   # ...потом настройка
	balloon.update_width(_avail_width)


# ---------- Оформление ----------

func _style_ui() -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(1, 1, 1, 0.92)
	panel.corner_radius_top_left = 24
	panel.corner_radius_top_right = 24
	panel.content_margin_left = 12
	panel.content_margin_right = 12
	panel.content_margin_top = 12
	panel.content_margin_bottom = 12
	input_area.add_theme_stylebox_override("panel", panel)

	_apply_button_style(input_bar, Color("efefef"), Color("e2e2e2"), 28)
	input_bar.add_theme_font_size_override("font_size", 20)
	input_bar.add_theme_color_override("font_color", Color("666666"))
	input_bar.add_theme_color_override("font_hover_color", Color("444444"))
	input_bar.add_theme_color_override("font_pressed_color", Color("444444"))
	input_bar.add_theme_color_override("font_disabled_color", Color("aaaaaa"))


func _make_box(color: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.content_margin_left = 20
	s.content_margin_right = 20
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s


func _apply_button_style(btn: Button, base: Color, hover: Color, radius: int) -> void:
	btn.add_theme_stylebox_override("normal", _make_box(base, radius))
	btn.add_theme_stylebox_override("hover", _make_box(hover, radius))
	btn.add_theme_stylebox_override("pressed", _make_box(hover.darkened(0.08), radius))
	btn.add_theme_stylebox_override("disabled", _make_box(base, radius))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		btn.add_theme_color_override(c, Color("1b1b1b"))
	btn.add_theme_color_override("font_disabled_color", Color(0.1, 0.1, 0.1, 0.45))


# ---------- Демо ----------

func _run_demo() -> void:
	add_message("Привет! Ты уже видел то письмо?")
	await get_tree().create_timer(0.7).timeout
	add_message("Оно пришло сегодня утром, и там была странная подпись. Очень длинное сообщение, чтобы проверить перенос строк внутри пузыря и автоскролл вниз.")
	await get_tree().create_timer(0.7).timeout
	show_choices(["Да, видел", "Нет, о чём ты?", "Покажи его мне"])


func _on_demo_choice(_index: int, text: String) -> void:
	await get_tree().create_timer(0.8).timeout
	add_message("Ты выбрал: «%s». Это тестовая реакция." % text)
	await get_tree().create_timer(0.7).timeout
	show_choices(["Продолжить", "Закончить"])
