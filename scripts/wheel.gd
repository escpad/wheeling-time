extends Node2D

@onready var _spin_helper: Label = $"../SpinText"

const FONT_SIZE  := 18
const LABEL_DIST := 0.62
var _font: Font = preload("res://assets/BoldPixels.ttf")

# GROUP LEGEND -----------------------------------------------------------------

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
	{ "name": "Second Wind", "type": "extra_spin", "degrees": 0.0, "value": 0,   "label": ""     },
	{ "name": "Cleanse",     "type": "remove",  "degrees": 0.0,  "value": 0,    "label": ""     },
	{ "name": "Gamble",      "type": "gamble",  "degrees": 0.0,  "value": 0,    "label": ""     },
]

# TUNABLES ---------------------------------------------------------------
const RADIUS            := 220.0
const SPIN_SPEED        := 10.0
const DECEL_RATE_NORMAL := 10.0
const DECEL_RATE_LAST   := 1.5     # slower stop on the final spin of a level
const ARC_STEPS         := 32
const MIN_SECTION_DEG   := 8.0     # smallest a resizable section can shrink to

# Gameplay multipliers
const GOLD_MULT         := 1.5     # "multiply_gold" passive
const DARK_MULT         := 2.0     # "double_dark" passive
const DEBUFF_DIVISOR    := 2       # boss-level value halving
const GAMBLE_MIN        := 100     # smallest magnitude a Gamble section can roll
const GAMBLE_MAX        := 300     # largest magnitude a Gamble section can roll

# Color tiers — a section takes the color of the highest tier its magnitude
# clears, so equal-value sections always share an exact color.
const ZERO_COLOR := Color(0.16, 0.16, 0.18)
const GOLD_TIERS := [   # positive sections, cool → hot by value
	{ "min": 1,   "color": Color(0.30, 0.69, 0.39) },  # green
	{ "min": 100, "color": Color(0.55, 0.76, 0.29) },  # lime
	{ "min": 200, "color": Color(0.98, 0.75, 0.18) },  # amber
	{ "min": 350, "color": Color(0.96, 0.55, 0.15) },  # orange
	{ "min": 500, "color": Color(0.93, 0.34, 0.18) },  # ember
]
const CURSE_TIERS := [  # negative sections, deeper red by severity
	{ "min": 1,   "color": Color(0.85, 0.30, 0.30) },  # light red (mild)
	{ "min": 100, "color": Color(0.72, 0.16, 0.16) },  # red
	{ "min": 200, "color": Color(0.50, 0.08, 0.08) },  # deep red (severe)
]

enum State { IDLE, SPINNING, DECELERATING }

var state: State = State.IDLE
var angular_velocity: float = 0.0
var locked: bool = false
var passives: Array[String] = []
var debuff_active: bool = false
var remove_mode: bool = false
var _hovered_index: int = -1
var _decel_rate: float = DECEL_RATE_NORMAL

signal spin_stopped(landed_index: int, value: int)
signal section_removed

func _ready() -> void:
	randomize()
	for s in sections:
		s["group"] = _group_for(s["type"])
		s["color"] = _color_for(s["value"], s["group"])
	queue_redraw()

# COLOR SYSTEM ---------------------------------------------------------------
# Two groups (gold = positive, dark = curse) split into discrete value tiers.
# Equal-value sections share one exact color, so the wheel reads cleanly.

func _group_for(type: String) -> String:
	if type == "curse":
		return "dark"
	return "gold"

func _color_for(value: int, group: String) -> Color:
	if group == "dark":
		return _tier_color(abs(value), CURSE_TIERS)
	if value <= 0:
		return ZERO_COLOR
	return _tier_color(value, GOLD_TIERS)

func _tier_color(magnitude: int, tiers: Array) -> Color:
	var chosen: Color = tiers[0]["color"]
	for tier in tiers:
		if magnitude >= tier["min"]:
			chosen = tier["color"]
	return chosen

# BOONS ---------------------------------------------------------------

# Re-derives a section's label and color from its current value. Call after
# any change to s["value"] so the visuals stay in sync.
func _refresh_section(s: Dictionary) -> void:
	s["label"] = str(s["value"])
	s["color"] = _color_for(s["value"], s["group"])

func replace_random_section(new_value: int) -> void:
	var s: Dictionary = sections.pick_random()
	s["value"] = new_value
	for p in passives:
		_mutate_section(s, p)
	_refresh_section(s)
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
	sections.insert(randi() % (sections.size() + 1), entry)
	recalculate_sections()
	queue_redraw()

func _mutate_section(s: Dictionary, passive: String) -> void:
	match passive:
		"multiply_gold":
			if s["group"] == "gold" and s["value"] > 0:
				s["value"] = int(s["value"] * GOLD_MULT)
				_refresh_section(s)
		"double_dark":
			if s["group"] == "dark":
				s["value"] = int(s["value"] * DARK_MULT)
				_refresh_section(s)

func apply_debuff() -> void:
	debuff_active = true
	for s in sections:
		s["pre_debuff"] = s["value"]
		if s["value"] > 0:
			s["value"] = int(s["value"] / DEBUFF_DIVISOR)
			_refresh_section(s)
	queue_redraw()

func remove_debuff() -> void:
	debuff_active = false
	for s in sections:
		if s.has("pre_debuff"):
			s["value"] = s["pre_debuff"]
			s.erase("pre_debuff")
			_refresh_section(s)
	queue_redraw()

func recalculate_sections() -> void:
	var fixed_total     := 0.0
	var resizable_count := 0
	for s in sections:
		if s["type"] in ["fixed", "curse"]:
			fixed_total += s["degrees"]
		else:
			resizable_count += 1

	# Scale fixed/curse sections down if they'd crowd out resizables
	var max_fixed := 360.0 - resizable_count * MIN_SECTION_DEG
	if fixed_total > max_fixed and fixed_total > 0.0:
		var scale := max_fixed / fixed_total
		for s in sections:
			if s["type"] in ["fixed", "curse"]:
				s["degrees"] *= scale
		fixed_total = max_fixed

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

func add_gamble_section() -> void:
	var mag := randi_range(GAMBLE_MIN, GAMBLE_MAX)
	var val := mag if randf() < 0.5 else -mag
	var entry := {
		"name": "Gamble", "type": "base", "value": val,
		"degrees": 60.0, "group": "gold" if val > 0 else "dark",
	}
	for p in passives:
		_mutate_section(entry, p)
	_refresh_section(entry)
	sections.insert(randi() % (sections.size() + 1), entry)
	recalculate_sections()
	queue_redraw()

# REMOVE MODE ---------------------------------------------------------------

func enter_remove_mode() -> void:
	remove_mode = true
	_hovered_index = -1
	queue_redraw()

func _section_at(world_pos: Vector2) -> int:
	var local := world_pos - global_position
	var ang := fmod(atan2(local.y, local.x) - rotation, TAU)
	if ang < 0.0:
		ang += TAU
	var cumulative := 0.0
	for i in sections.size():
		cumulative += deg_to_rad(sections[i]["degrees"])
		if ang < cumulative:
			return i
	return sections.size() - 1

# SPIN PHYSICS ---------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if remove_mode:
		_handle_remove_input(event)
		return
	if locked:
		return
	if event.is_action_pressed("ui_accept") and state == State.IDLE:
		start_spin()
	elif (event.is_action_pressed("ui_accept") or event is InputEventMouseButton) and event.pressed and state == State.SPINNING:
		state = State.DECELERATING

func _handle_remove_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var idx := _section_at(event.position)
		if idx != _hovered_index:
			_hovered_index = idx
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if sections.size() <= 1:
			return  # never remove the final section
		var idx := _section_at(event.position)
		sections.remove_at(idx)
		remove_mode = false
		_hovered_index = -1
		recalculate_sections()
		queue_redraw()
		emit_signal("section_removed")

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
	for i in sections.size():
		var s: Dictionary = sections[i]
		var sweep := deg_to_rad(s["degrees"])
		var mid   := rad + sweep * 0.5
		var highlighted := remove_mode and i == _hovered_index
		var fill: Color = s["color"].lightened(0.4) if highlighted else s["color"]
		_draw_section(rad, rad + sweep, fill)
		draw_line(Vector2.ZERO, Vector2(cos(rad), sin(rad)) * RADIUS, Color.BLACK, 2.0)
		if highlighted:
			_draw_highlight_outline(rad, rad + sweep)
		var font_size := clampi(int(s["degrees"] * 0.9), 8, FONT_SIZE)
		var sz := _font.get_string_size(s["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		draw_set_transform(Vector2.ZERO, mid, Vector2.ONE)
		draw_string(_font, Vector2(RADIUS * LABEL_DIST - sz.x * 0.5, sz.y * 0.35),
			s["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		rad += sweep
	draw_arc(Vector2.ZERO, RADIUS, 0, TAU, 64, Color.BLACK, 3.0)

func _draw_highlight_outline(start_angle: float, end_angle: float) -> void:
	const OUTLINE := Color(1.0, 0.2, 0.2)
	const WIDTH   := 4.0
	draw_line(Vector2.ZERO, Vector2(cos(start_angle), sin(start_angle)) * RADIUS, OUTLINE, WIDTH)
	draw_line(Vector2.ZERO, Vector2(cos(end_angle), sin(end_angle)) * RADIUS, OUTLINE, WIDTH)
	draw_arc(Vector2.ZERO, RADIUS, start_angle, end_angle, ARC_STEPS, OUTLINE, WIDTH)

func _draw_section(start_angle: float, end_angle: float, color: Color) -> void:
	var points := PackedVector2Array()
	points.append(Vector2.ZERO)
	for i in range(ARC_STEPS + 1):
		var t := float(i) / float(ARC_STEPS)
		var a := start_angle + t * (end_angle - start_angle)
		points.append(Vector2(cos(a), sin(a)) * RADIUS)
	draw_colored_polygon(points, color)
