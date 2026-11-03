class_name BubbleStyle
extends Resource

enum Tail { NONE, LEFT, RIGHT }

@export var balloon_alignment: BoxContainer.AlignmentMode = BoxContainer.ALIGNMENT_BEGIN
@export var text_alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT
@export_range(0.3, 1.0, 0.01) var max_width_ratio: float = 0.8

@export var color: Color = Color.WHITE
@export_range(0.0, 1.0, 0.01) var opacity: float = 1.0
@export var text_color: Color = Color("1b1b1b")

@export var tail: Tail = Tail.NONE

@export var show_typing: bool = false
@export_range(0.0, 5.0, 0.1) var pause_before: float = 0.0
