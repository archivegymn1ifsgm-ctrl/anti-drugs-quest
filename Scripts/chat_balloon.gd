class_name ChatBalloon
extends HBoxContainer

const TAIL_RADIUS := 4

@onready var panel: PanelContainer = $Panel
@onready var label: Label = $Panel/Label

var _style: BubbleStyle
var _one_line_width := 0.0
var _padding_x := 0.0
var _dots: Array[Panel] = []
var _typing_time := 0.0


func _ready() -> void:
	set_process(false)


func setup(text: String, bubble_style: BubbleStyle, animate: bool = true) -> void:
	_style = bubble_style
	label.text = text
	label.horizontal_alignment = _style.text_alignment
	label.add_theme_color_override("font_color", _style.text_color)
	_apply_style()

	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	_one_line_width = font.get_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size
	).x

	if animate:
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 0.2)


func update_width(available_width: float) -> void:
	if available_width <= 0.0 or _style == null:
		return
	var max_text_width := maxf(available_width * _style.max_width_ratio - _padding_x, 40.0)
	label.custom_minimum_size.x = minf(_one_line_width + 2.0, max_text_width)


func setup_typing(bubble_style: BubbleStyle) -> void:
	_style = bubble_style
	label.visible = false
	_apply_style()

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	panel.add_child(row)
	for i in 3:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(12, 12)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var dot_style := StyleBoxFlat.new()
		dot_style.bg_color = _style.text_color
		dot_style.set_corner_radius_all(6)
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
		_dots[i].modulate.a = 0.2 + 0.6 * wave


func _apply_style() -> void:
	alignment = _style.balloon_alignment

	var box := (panel.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	var bg := _style.color
	bg.a *= _style.opacity
	box.bg_color = bg
	match _style.tail:
		BubbleStyle.Tail.LEFT:
			box.corner_radius_bottom_left = TAIL_RADIUS
		BubbleStyle.Tail.RIGHT:
			box.corner_radius_bottom_right = TAIL_RADIUS
	panel.add_theme_stylebox_override("panel", box)
	_padding_x = box.get_minimum_size().x
