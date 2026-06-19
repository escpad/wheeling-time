extends Node2D

@onready var _spin_helper: Label = $"../SpinText"
const SECTIONS := [
	{ "value": 0,   "label": "0",    "color": Color(0.25, 0.25, 0.25) },
	{ "value": 50,  "label": "50",   "color": Color(0.1,  0.5,  0.85) },
	{ "value": 100, "label": "100",  "color": Color(0.2,  0.72, 0.32) },
	{ "value": 100, "label": "100",  "color": Color(0.85, 0.62, 0.1)  },
	{ "value": 150, "label": "150",  "color": Color(0.82, 0.22, 0.22) },
	{ "value": 200, "label": "200",  "color": Color(0.58, 0.12, 0.82) },
]

const RADIUS       := 220.0
const SPIN_SPEED   := 10.0
const DECEL_RATE   := 10
const ARC_STEPS    := 32

enum State { IDLE, SPINNING, DECELERATING }

var state: State = State.IDLE
var angular_velocity: float = 0.0

signal spin_stopped(landed_index: int, value: int)

func _ready() -> void:
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and state == State.IDLE:
		start_spin()
	elif event is InputEventMouseButton and event.pressed and state == State.SPINNING:
		state = State.DECELERATING

func _process(delta: float) -> void:
	match state:
		State.SPINNING:
			rotation += angular_velocity * delta
			queue_redraw()
		State.DECELERATING:
			angular_velocity = max(0.0, angular_velocity - DECEL_RATE * delta)
			rotation += angular_velocity * delta
			queue_redraw()
			if angular_velocity == 0.0:
				state = State.IDLE
				_resolve()

func start_spin() -> void:
	state = State.SPINNING
	angular_velocity = SPIN_SPEED
	_spin_helper.visible = true

func _resolve() -> void:
	var angle_per_section := TAU / SECTIONS.size()
	var normalized := fmod(-PI / 2.0 - rotation, TAU)
	if normalized < 0.0:
		normalized += TAU
	var index := int(normalized / angle_per_section) % SECTIONS.size()
	var section: Dictionary = SECTIONS[index]
	print("Landed: section %d — %d pts" % [index, section["value"]])
	emit_signal("spin_stopped", index, section["value"])

func _draw() -> void:
	var count := SECTIONS.size()
	var angle_per_section := TAU / count

	for i in count:
		var start := i * angle_per_section
		var end   := start + angle_per_section
		_draw_section(start, end, SECTIONS[i]["color"])

	for i in count:
		var a := i * angle_per_section
		draw_line(Vector2.ZERO, Vector2(cos(a), sin(a)) * RADIUS, Color.BLACK, 2.0)

	for i in count:
		var mid_angle := (i + 0.5) * angle_per_section
		var label_pos := Vector2(cos(mid_angle), sin(mid_angle)) * (RADIUS * 0.62)
		draw_string(
			ThemeDB.fallback_font,
			label_pos - Vector2(20, 10),
			SECTIONS[i]["label"],
			HORIZONTAL_ALIGNMENT_CENTER,
			40,
			18,
			Color.WHITE
		)

	draw_arc(Vector2.ZERO, RADIUS, 0, TAU, 64, Color.BLACK, 3.0)

func _draw_section(start_angle: float, end_angle: float, color: Color) -> void:
	var points := PackedVector2Array()
	points.append(Vector2.ZERO)
	for i in range(ARC_STEPS + 1):
		var t := float(i) / float(ARC_STEPS)
		var a := start_angle + t * (end_angle - start_angle)
		points.append(Vector2(cos(a), sin(a)) * RADIUS)
	draw_colored_polygon(points, color)
