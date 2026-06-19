extends Node2D

const WHEEL_POS    := Vector2(576, 324)
const WHEEL_RADIUS := 220.0

@onready var _wheel:    Node2D = $Wheel
@onready var _spin_btn: Button = $SpinButton
@onready var _spin_helper: Label = $SpinText
func _ready() -> void:
	_spin_btn.pressed.connect(_wheel.start_spin)
	_wheel.spin_stopped.connect(_on_spin_stopped)

func _on_spin_stopped(_index: int, _value: int) -> void:
	_spin_helper.visible = false

func _draw() -> void:
	# Fixed pointer triangle, tip touching the wheel rim at the top
	var tip   := WHEEL_POS + Vector2(0, -WHEEL_RADIUS - 5)
	var left  := tip + Vector2(-14, -22)
	var right := tip + Vector2( 14, -22)
	draw_colored_polygon(PackedVector2Array([tip, left, right]), Color.WHITE)
	draw_polyline(PackedVector2Array([tip, left, right, tip]), Color.BLACK, 2.0)
