extends Node2D

@onready var _spin_helper: Label = $"../SpinText"

const FONT_SIZE  := 18
const LABEL_DIST := 0.62  # fraction of radius
var _font: Font = preload("res://assets/BoldPixels.ttf")

var sections: Array[Dictionary] = [
	{ "value": 0,   "label": "0",   "type": "base", "degrees": 60.0 },
	{ "value": 50,  "label": "50",  "type": "base", "degrees": 60.0 },
	{ "value": 100, "label": "100", "type": "base", "degrees": 60.0 },
	{ "value": 100, "label": "100", "type": "base", "degrees": 60.0 },
	{ "value": 150, "label": "150", "type": "base", "degrees": 60.0 },
	{ "value": 500, "label": "500", "type": "base", "degrees": 60.0 },
]

const BOON_POOL: Array[Dictionary] = [
	{ "name": "Wedge",       "type": "fixed", "degrees": 30.0, "value": 200,  "label": "200"  },
	{ "name": "Sliver",      "type": "fixed", "degrees": 30.0, "value": 250,  "label": "250"  },
	{ "name": "Windfall",    "type": "flex",  "degrees": 30.0, "value": 75,   "label": "75"   },
	{ "name": "Overflow",    "type": "flex",  "degrees": 30.0, "value": 100,  "label": "100"  },
	{ "name": "Dark Deal",   "type": "curse", "degrees": 30.0, "value": -100, "label": "-100" },
	{ "name": "Devil's Cut", "type": "curse", "degrees": 30.0, "value": -75,  "label": "-75"  },
]

const RADIUS     := 220.0
const SPIN_SPEED := 10.0
const DECEL_RATE := 10
const ARC_STEPS  := 32
const MAX_VALUE  := 500.0

enum State { IDLE, SPINNING, DECELERATING }

var state: State = State.IDLE
var angular_velocity: float = 0.0
var locked: bool = false

signal spin_stopped(landed_index: int, value: int)

func _ready() -> void:
	for s in sections:
		s["color"] = _color_for(s["value"], s["type"])
	queue_redraw()

# COLOR SYSTEM ---------------------------------------------------------------
# Positive (base/fixed): muted green (low) → bright gold (high)
# Flex:                  fixed teal
# Curse:                 dark purple (mild) → dark crimson (severe)
# Zero:                  near-black

func _color_for(value: int, type: String) -> Color:
	if type == "curse":
		var t: float = clamp(float(abs(value)) / 100.0, 0.0, 1.0)
		return Color.from_hsv(lerpf(0.78, 0.02, t), 0.8, lerpf(0.38, 0.45, t))
	if type == "flex":
		return Color.from_hsv(0.5, 0.75, 0.65)
	if value == 0:
		return Color(0.13, 0.13, 0.13)
	var t: float = clamp(float(value) / MAX_VALUE, 0.0, 1.0)
	return Color.from_hsv(lerpf(0.36, 0.11, t), lerpf(0.5, 0.92, t), lerpf(0.52, 0.96, t))

# BOONS ---------------------------------------------------------------

func add_boon(boon: Dictionary) -> void:
	var entry := boon.duplicate()
	entry["color"] = _color_for(entry["value"], entry["type"])
	sections.append(entry)
	recalculate_sections()
	queue_redraw()

func recalculate_sections() -> void:
	var fixed_total     := 0.0
	var resizable_count := 0
	for s in sections:
		if s["type"] in ["fixed", "curse"]:
			fixed_total += s["degrees"]
		else:
			resizable_count += 1
	var each := (360.0 - fixed_total) / resizable_count if resizable_count > 0 else 0.0
	for s in sections:
		if s["type"] in ["base", "flex"]:
			s["degrees"] = each

func get_three_boons() -> Array:
	var pool := BOON_POOL.duplicate()
	pool.shuffle()
	return pool.slice(0, 3)

# SPIN PHYSICS ---------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if locked:
		return
	if event.is_action_pressed("ui_accept") and state == State.IDLE:
		start_spin()
	elif (event.is_action_pressed("ui_accept") or event is InputEventMouseButton) and event.pressed and state == State.SPINNING:
		state = State.DECELERATING

func _process(delta: float) -> void:
	if state == State.IDLE:
		return
	if state == State.DECELERATING:
		angular_velocity = max(0.0, angular_velocity - DECEL_RATE * delta)
		if angular_velocity == 0.0:
			state = State.IDLE
			_resolve()
			return
	rotation += angular_velocity * delta
	queue_redraw()

func start_spin() -> void:
	state = State.SPINNING
	angular_velocity = SPIN_SPEED
	_spin_helper.visible = true

# HIT DETECTION ---------------------------------------------------------------

func _resolve() -> void:
	var pointer_angle := fmod(-PI / 2.0 - rotation, TAU)
	if pointer_angle < 0.0:
		pointer_angle += TAU
	var cumulative := 0.0
	for i in sections.size():
		cumulative += deg_to_rad(sections[i]["degrees"])
		if pointer_angle < cumulative:
			print("Landed: %s — %d pts" % [sections[i]["label"], sections[i]["value"]])
			emit_signal("spin_stopped", i, sections[i]["value"])
			return
	emit_signal("spin_stopped", 0, sections[0]["value"])

# RENDERING ---------------------------------------------------------------

func _draw() -> void:
	var rad := 0.0
	for s in sections:
		var sweep    := deg_to_rad(s["degrees"])
		var mid      := rad + sweep * 0.5
		_draw_section(rad, rad + sweep, s["color"])
		draw_line(Vector2.ZERO, Vector2(cos(rad), sin(rad)) * RADIUS, Color.BLACK, 2.0)
		var sz := _font.get_string_size(s["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
		draw_set_transform(Vector2.ZERO, mid, Vector2.ONE)
		draw_string(_font, Vector2(RADIUS * LABEL_DIST - sz.x * 0.5, sz.y * 0.35),
			s["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color.WHITE)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		rad += sweep
	draw_arc(Vector2.ZERO, RADIUS, 0, TAU, 64, Color.BLACK, 3.0)

func _draw_section(start_angle: float, end_angle: float, color: Color) -> void:
	var points := PackedVector2Array()
	points.append(Vector2.ZERO)
	for i in range(ARC_STEPS + 1):
		var t := float(i) / float(ARC_STEPS)
		var a := start_angle + t * (end_angle - start_angle)
		points.append(Vector2(cos(a), sin(a)) * RADIUS)
	draw_colored_polygon(points, color)
