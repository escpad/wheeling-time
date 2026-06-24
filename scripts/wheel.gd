extends Node2D

@onready var _spin_helper: Label = $"../SpinText"

const FONT_SIZE  := 18
const LABEL_DIST := 0.62
var _font: Font = preload("res://assets/BoldPixels.ttf")

# GROUP LEGEND -----------------------------------------------------------------
# "gold" → base + fixed + flex sections (warm amber → bright gold by value)
# "dark" → curse sections (dark purple → dark crimson by severity)

var sections: Array[Dictionary] = [
	{ "value": 0,   "label": "0",   "type": "base", "degrees": 60.0 },
	{ "value": 50,  "label": "50",  "type": "base", "degrees": 60.0 },
	{ "value": 100, "label": "100", "type": "base", "degrees": 60.0 },
	{ "value": 100, "label": "100", "type": "base", "degrees": 60.0 },
	{ "value": 150, "label": "150", "type": "base", "degrees": 60.0 },
	{ "value": 500, "label": "500", "type": "base", "degrees": 60.0 },
]

const BOON_POOL: Array[Dictionary] = [
	{ "name": "Wedge",       "type": "fixed",   "degrees": 30.0, "value": 200,  "label": "200"  },
	{ "name": "Sliver",      "type": "fixed",   "degrees": 30.0, "value": 250,  "label": "250"  },
	{ "name": "Windfall",    "type": "flex",    "degrees": 30.0, "value": 75,   "label": "75"   },
	{ "name": "Overflow",    "type": "flex",    "degrees": 30.0, "value": 100,  "label": "100"  },
	{ "name": "Dark Deal",   "type": "curse",   "degrees": 30.0, "value": -100, "label": "-100", "passive": "multiply_gold" },
	{ "name": "Devil's Cut", "type": "curse",   "degrees": 30.0, "value": -75,  "label": "-75",  "passive": "multiply_gold", "passive2": "double_dark" },
	{ "name": "Transmute",   "type": "replace", "degrees": 0.0,  "value": 250,  "label": "250"  },
]

const RADIUS            := 220.0
const SPIN_SPEED        := 10.0
const DECEL_RATE_NORMAL := 10.0
const DECEL_RATE_LAST   := 1.5
const ARC_STEPS         := 32
const MAX_VALUE_GOLD    := 500.0

enum State { IDLE, SPINNING, DECELERATING }

var state: State = State.IDLE
var angular_velocity: float = 0.0
var locked: bool = false
var passives: Array[String] = []
var debuff_active: bool = false
var _decel_rate: float = DECEL_RATE_NORMAL

signal spin_stopped(landed_index: int, value: int)

func _ready() -> void:
	for s in sections:
		s["group"] = _group_for(s["type"])
		s["color"] = _color_for(s["value"], s["group"])
	queue_redraw()

# COLOR SYSTEM ---------------------------------------------------------------
# Group-based hue ranges so color identity signals which passive will boost it.

func _group_for(type: String) -> String:
	if type == "curse":
		return "dark"
	return "gold"

func _color_for(value: int, group: String) -> Color:
	if group == "dark":
		var t: float = clamp(float(abs(value)) / 100.0, 0.0, 1.0)
		return Color.from_hsv(lerpf(0.78, 0.02, t), 0.8, lerpf(0.35, 0.45, t))
	if value == 0:
		return Color(0.13, 0.13, 0.13)
	var t: float = clamp(float(value) / MAX_VALUE_GOLD, 0.0, 1.0)
	return Color.from_hsv(lerpf(0.10, 0.14, t), lerpf(0.5, 0.95, t), lerpf(0.55, 0.95, t))

# BOONS ---------------------------------------------------------------
func replace_random_section(new_value: int) -> void:
	var s: Dictionary = sections.pick_random()
	s["value"] = new_value
	for p in passives:
		_mutate_section(s, p)
	s["label"] = str(s["value"])
	s["color"]  = _color_for(s["value"], s["group"])
	queue_redraw()

func add_boon(boon: Dictionary) -> void:
	var entry := boon.duplicate()
	entry["group"] = _group_for(entry["type"])
	entry["color"] = _color_for(entry["value"], entry["group"])
	if entry.has("passive"):
		for key in ["passive", "passive2"]:
			if entry.has(key):
				passives.append(entry[key])
				for s in sections:
					_mutate_section(s, entry[key])
	else:
		for p in passives:
			_mutate_section(entry, p)
	sections.append(entry)
	recalculate_sections()
	queue_redraw()

func _mutate_section(s: Dictionary, passive: String) -> void:
	match passive:
		"multiply_gold":
			if s["group"] == "gold" and s["value"] > 0:
				s["value"] = int(float(s["value"]) * 1.5)
				s["label"] = str(s["value"])
				s["color"] = _color_for(s["value"], s["group"])
		"double_dark":
			if s["group"] == "dark":
				s["value"] *= 2
				s["label"] = str(s["value"])
				s["color"] = _color_for(s["value"], s["group"])

func apply_debuff() -> void:
	debuff_active = true
	for s in sections:
		s["pre_debuff"] = s["value"]
		if s["value"] > 0:
			s["value"] = s["value"] / 2
			s["label"] = str(s["value"])
			s["color"]  = _color_for(s["value"], s["group"])
	queue_redraw()

func remove_debuff() -> void:
	debuff_active = false
	for s in sections:
		if s.has("pre_debuff"):
			s["value"] = s["pre_debuff"]
			s.erase("pre_debuff")
			s["label"] = str(s["value"])
			s["color"]  = _color_for(s["value"], s["group"])
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
	var curses    := BOON_POOL.filter(func(b: Dictionary) -> bool: return b["type"] == "curse")
	var positives := BOON_POOL.filter(func(b: Dictionary) -> bool: return b["type"] != "curse")
	curses.shuffle()
	positives.shuffle()
	return [positives[0], positives[1], curses[0]]

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
		angular_velocity = max(0.0, angular_velocity - _decel_rate * delta)
		if angular_velocity == 0.0:
			state = State.IDLE
			_resolve()
			return
	rotation += angular_velocity * delta
	queue_redraw()

func start_spin() -> void:
	state = State.SPINNING
	angular_velocity = SPIN_SPEED
	_decel_rate = DECEL_RATE_LAST if GameManager.spins_left == 1 else DECEL_RATE_NORMAL
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
		var sweep := deg_to_rad(s["degrees"])
		var mid   := rad + sweep * 0.5
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
