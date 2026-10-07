class_name ChatBalloon
extends HBoxContainer
## Скрипт корня сцены chat_balloon.tscn.
## Вызывать setup() ПОСЛЕ add_child() — тогда узлы уже готовы и у Label есть шрифт.
## Ширину пузыря задаёт update_width(): доля от доступной ширины экрана.
##
## Три вида пузырей:
##   is_player = true  -> справа (ответ игрока)
##   is_player = false -> слева (собеседник)
##   is_system = true  -> по центру (рассказчик, «Итог», «Финал»)

## Максимальная ширина пузыря как доля доступной ширины (0.8 = 80%).
@export_range(0.3, 1.0) var max_width_ratio: float = 0.8
@export_range(0.3, 1.0) var system_width_ratio: float = 0.9
@export var incoming_color := Color("ffffff")
@export var outgoing_color := Color("8fd694")
@export var system_color := Color(0, 0, 0, 0.55)
@export var system_text_color := Color("ffffff")

@onready var panel: PanelContainer = $Panel
@onready var label: Label = $Panel/Label

var _one_line_width := 0.0   # ширина текста, если бы он был в одну строку
var _padding_x := 0.0        # внутренние отступы пузыря слева+справа
var _is_system := false
var _dots: Array[Panel] = []
var _typing_time := 0.0


func _ready() -> void:
	set_process(false)   # _process нужен только пузырю «печатает…»


func setup(text: String, is_player: bool, animate: bool = true, is_system: bool = false) -> void:
	_is_system = is_system
	label.text = text

	if is_system:
		alignment = BoxContainer.ALIGNMENT_CENTER
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", system_text_color)
	else:
		alignment = BoxContainer.ALIGNMENT_END if is_player else BoxContainer.ALIGNMENT_BEGIN

	# Копия стиля из сцены, чтобы цвет одного пузыря не менял все остальные
	var style := (panel.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	if is_system:
		style.bg_color = system_color
	else:
		style.bg_color = outgoing_color if is_player else incoming_color
		# «хвостик»: у угла, ближайшего к автору, радиус поменьше
		if is_player:
			style.corner_radius_bottom_right = 4
		else:
			style.corner_radius_bottom_left = 4
	panel.add_theme_stylebox_override("panel", style)
	_padding_x = style.get_minimum_size().x

	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	_one_line_width = font.get_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
	).x

	if animate:
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 0.2)


## available_width — ширина области сообщений (без полей и полосы прокрутки).
## Вызывается при добавлении пузыря и при каждом изменении размера окна.
func update_width(available_width: float) -> void:
	if available_width <= 0.0:
		return
	var ratio := system_width_ratio if _is_system else max_width_ratio
	var max_text_width := maxf(available_width * ratio - _padding_x, 40.0)
	label.custom_minimum_size.x = minf(_one_line_width + 2.0, max_text_width)


## Пузырь «собеседник печатает…»: три мигающих точки вместо текста.
## Убирается через chat.hide_typing().
func setup_typing() -> void:
	alignment = BoxContainer.ALIGNMENT_BEGIN
	label.visible = false

	var style := (panel.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	style.bg_color = incoming_color
	style.corner_radius_bottom_left = 4
	panel.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	panel.add_child(row)
	for i in 3:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(12, 12)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var dot_style := StyleBoxFlat.new()
		dot_style.bg_color = Color("8a8a8a")
		dot_style.set_corner_radius_all(6)   # половина размера = круг
		dot.add_theme_stylebox_override("panel", dot_style)
		row.add_child(dot)
		_dots.append(dot)

	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.15)
	set_process(true)


func _process(delta: float) -> void:
	_typing_time += delta
	for i in _dots.size():
		var wave := 0.5 + 0.5 * sin(_typing_time * 6.0 - i * 0.9)
		_dots[i].modulate.a = 0.3 + 0.7 * wave
