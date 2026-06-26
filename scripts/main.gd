extends Node2D

const WHEEL_POS    := Vector2(576, 324)
const WHEEL_RADIUS := 220.0

# BOON CARD DESIGN TOKENS ---------------------------------------------------
const CARD_BG       := Color(0.11, 0.105, 0.145)
const CARD_BG_HOVER := Color(0.17, 0.16, 0.22)
const CARD_BORDER   := Color(0.30, 0.28, 0.38)
const TEXT_PRIMARY  := Color(0.96, 0.94, 0.90)
const TEXT_MUTED    := Color(0.58, 0.56, 0.64)

var _pixel_font: Font = preload("res://assets/BoldPixels.ttf")
var _cards: Array = []   # per-card label/accent refs, built in _ready()

@onready var _wheel:          Node2D      = $Wheel
@onready var _spin_btn:       Button      = $SpinButton
@onready var _spin_helper:    Label       = $SpinText
@onready var _quota_lbl:      Label       = $QuotaLabel
@onready var _quota_bar:      ProgressBar = $QuotaBar
@onready var _spins_lbl:      Label       = $SpinsLabel
@onready var _stage_lbl:      Label       = $StageLevelLabel
@onready var _debuff_lbl:     Label       = $DebuffLabel
@onready var _level_layer:    CanvasLayer = $LevelCompleteLayer
@onready var _level_lbl:      Label       = $"LevelCompleteLayer/LevelLabel"
@onready var _next_lbl:       Label       = $"LevelCompleteLayer/NextLevelLabel"
@onready var _continue_btn:   Button      = $"LevelCompleteLayer/ContinueBtn"
@onready var _game_over:      CanvasLayer = $GameOverLayer
@onready var _result_lbl:     Label       = $"GameOverLayer/ResultLabel"
@onready var _score_lbl:      Label       = $"GameOverLayer/ScoreLabel"
@onready var _restart_btn:    Button      = $"GameOverLayer/RestartBtn"
@onready var _boon_sel:       CanvasLayer = $BoonSelectorLayer
@onready var _skip_btn:       Button      = $"BoonSelectorLayer/SkipBtn"
@onready var _boon_btns:      Array       = [
	$"BoonSelectorLayer/BoonBtn0",
	$"BoonSelectorLayer/BoonBtn1",
	$"BoonSelectorLayer/BoonBtn2",
]

var _current_boons: Array = []
var _pending_level_complete: bool = false
var _pending_next_stage:     int  = 0
var _pending_next_level:     int  = 0

func _ready() -> void:
	GameManager.start_game()
	_spin_btn.pressed.connect(_wheel.start_spin)
	_wheel.spin_stopped.connect(_on_spin_stopped)
	_restart_btn.pressed.connect(GameManager.reload)
	_continue_btn.pressed.connect(_on_continue_level)
	_skip_btn.pressed.connect(_on_skip)
	GameManager.score_changed.connect(func(_s: int): _update_hud())
	GameManager.game_over.connect(_on_game_over)
	GameManager.level_complete.connect(_on_level_complete)
	_wheel.section_removed.connect(_on_section_removed)
	for i in 3:
		var idx := i
		var btn: Button = _boon_btns[i]
		_cards.append(_build_card(btn))
		btn.pressed.connect(func(): _on_boon_chosen(idx))
		btn.mouse_entered.connect(func(): _scale_card(btn, Vector2(1.05, 1.05)))
		btn.mouse_exited.connect(func(): _scale_card(btn, Vector2.ONE))
	_style_skip_button()
	_update_hud()

func _on_spin_stopped(_index: int, value: int) -> void:
	_spin_helper.visible = false
	GameManager.add_score(value)
	GameManager.use_spin()
	_update_hud()
	var was_last_spin := GameManager.spins_left == 0
	GameManager.check_and_end()
	if _pending_level_complete:
		if not was_last_spin:
			_show_boon_selector()
		else:
			_show_level_complete_overlay()
	elif not GameManager.is_over():
		_spin_helper.text = "LAST SPIN — click to stop!" if GameManager.spins_left == 1 else "Press SPACE to stop!"
		_show_boon_selector()

func _on_level_complete(new_stage: int, new_level: int) -> void:
	_pending_level_complete = true
	_pending_next_stage     = new_stage
	_pending_next_level     = new_level

func _show_level_complete_overlay() -> void:
	_spin_btn.disabled = true
	_boon_sel.visible  = false
	if GameManager.is_boss_level():
		_wheel.apply_debuff()
		_debuff_lbl.visible = true
	elif _wheel.debuff_active:
		_wheel.remove_debuff()
		_debuff_lbl.visible = false
	_level_lbl.text      = "LEVEL COMPLETE"
	_next_lbl.text       = "Next: %d-%d" % [_pending_next_stage, _pending_next_level]
	_pending_level_complete = false
	_wheel.locked        = true
	_level_layer.visible = true

func _on_continue_level() -> void:
	_level_layer.visible = false
	_spin_btn.disabled   = false
	_wheel.locked        = false
	_update_hud()

# BOON SELECTOR ---------------------------------------------------------------

func _scale_card(btn: Button, target: Vector2) -> void:
	btn.pivot_offset = btn.size / 2.0
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
	tw.tween_property(btn, "scale", target, 0.12)

# Human-readable lines for a boon's passive effects. Single source of truth
# for both the boon card text and the curse-icon tooltip.
func _passive_descriptions(boon: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if boon.get("passive",  "") == "multiply_gold": out.append("1.5x all Gold")
	if boon.get("passive2", "") == "double_dark":   out.append("2x all Curses")
	return out

func _close_boon_selector() -> void:
	for btn: Button in _boon_btns:
		btn.scale = Vector2.ONE
	_boon_sel.visible = false
	_wheel.locked = false
	if _pending_level_complete:
		_show_level_complete_overlay()

func _show_boon_selector() -> void:
	_current_boons = _wheel.get_three_boons()
	for i in 3:
		_populate_card(_cards[i], _current_boons[i])
	_wheel.locked = true
	_boon_sel.visible = true

# CARD CONSTRUCTION ---------------------------------------------------------

func _build_card(btn: Button) -> Dictionary:
	btn.text = ""
	btn.clip_contents = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_stylebox_override("normal",  _card_sb(CARD_BG))
	btn.add_theme_stylebox_override("hover",   _card_sb(CARD_BG_HOVER))
	btn.add_theme_stylebox_override("pressed", _card_sb(CARD_BG_HOVER))

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	btn.add_child(margin)

	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 4)
	margin.add_child(vb)

	var eyebrow := _mk_label(12, TEXT_MUTED)
	vb.add_child(eyebrow)

	var name_lbl := _mk_label(20, TEXT_PRIMARY)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(name_lbl)

	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(spacer)

	var chip_style := StyleBoxFlat.new()
	chip_style.set_corner_radius_all(6)
	chip_style.set_border_width_all(2)
	chip_style.content_margin_top = 4
	chip_style.content_margin_bottom = 4
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_stylebox_override("panel", chip_style)
	vb.add_child(chip)

	var value := _mk_label(30, Color.WHITE)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.add_child(value)

	var effect := _mk_label(13, TEXT_MUTED)
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(effect)

	return {
		"eyebrow": eyebrow, "name": name_lbl, "value": value,
		"effect": effect, "chip_style": chip_style,
	}

func _populate_card(c: Dictionary, b: Dictionary) -> void:
	var fam := _family_color(b["type"])
	c["eyebrow"].text = _eyebrow(b)
	c["eyebrow"].add_theme_color_override("font_color", fam.lightened(0.1))
	c["name"].text  = b["name"]
	c["value"].text = _headline(b)
	c["value"].add_theme_color_override("font_color", fam.lightened(0.5))
	c["effect"].text = _effect(b)
	var cs: StyleBoxFlat = c["chip_style"]
	cs.bg_color     = fam.darkened(0.66)
	cs.border_color = fam.darkened(0.05)

func _mk_label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", _pixel_font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _card_sb(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(2)
	sb.border_color = CARD_BORDER
	return sb

func _style_skip_button() -> void:
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus"]:
		_skip_btn.add_theme_stylebox_override(state, empty)
	_skip_btn.focus_mode = Control.FOCUS_NONE

# Family accent color per boon type — echoes the wheel's value language.
func _family_color(type: String) -> Color:
	match type:
		"curse":   return Color(0.80, 0.22, 0.22)  # red
		"fixed":   return Color(0.94, 0.72, 0.18)  # gold
		"flex":    return Color(0.50, 0.78, 0.32)  # green
		"replace": return Color(0.64, 0.40, 0.86)  # violet
		"gamble":  return Color(0.98, 0.52, 0.18)  # risk orange
		_:         return Color(0.34, 0.72, 0.86)  # utility cyan

func _eyebrow(b: Dictionary) -> String:
	match b["type"]:
		"fixed":      return "FIXED"
		"flex":       return "FLEX"
		"curse":      return "CURSE"
		"replace":    return "TRANSMUTE"
		"extra_spin": return "BONUS"
		"remove":     return "CLEANSE"
		"gamble":     return "GAMBLE"
		_:            return String(b["type"]).to_upper()

func _headline(b: Dictionary) -> String:
	match b["type"]:
		"extra_spin": return "+1"
		"remove":     return "X"
		"gamble":     return "?"
		_:
			var v: int = b["value"]
			return ("+" if v >= 0 else "") + str(v)

func _effect(b: Dictionary) -> String:
	match b["type"]:
		"fixed":      return "Thin, high-value slice"
		"flex":       return "Fills the open space"
		"replace":    return "Turns a slice into 250"
		"extra_spin": return "Spin one more time"
		"remove":     return "Delete any slice"
		"gamble":     return "Random sign, %d-%d pts" % [_wheel.GAMBLE_MIN, _wheel.GAMBLE_MAX]
		"curse":
			var fx := _passive_descriptions(b)
			return " · ".join(fx) if not fx.is_empty() else "A heavy penalty"
		_:            return ""

func _on_boon_chosen(index: int) -> void:
	var boon: Dictionary = _current_boons[index]
	match boon["type"]:
		"replace":    _wheel.replace_random_section(boon["value"])
		"extra_spin": GameManager.add_spin()
		"gamble":     _wheel.add_gamble_section()
		"remove":
			_begin_remove_mode()
			return  # remove flow finishes the selector itself
		_:            _wheel.add_boon(boon)
	_close_boon_selector()

func _begin_remove_mode() -> void:
	for btn: Button in _boon_btns:
		btn.scale = Vector2.ONE
	_boon_sel.visible = false
	_spin_helper.text = "Click a section to remove it"
	_spin_helper.visible = true
	_wheel.locked = true        # block spinning; remove-clicks bypass this
	_wheel.enter_remove_mode()

func _on_section_removed() -> void:
	_spin_helper.visible = false
	_wheel.locked = false
	if _pending_level_complete:
		_show_level_complete_overlay()

func _on_skip() -> void:
	_close_boon_selector()

# GAME OVER ---------------------------------------------------------------

func _on_game_over(won: bool) -> void:
	_spin_btn.disabled = true
	_boon_sel.visible  = false
	_level_layer.visible = false
	_result_lbl.text = "YOU WIN!" if won else "YOU LOSE"
	_score_lbl.text  = "Final score: %d / %d" % [GameManager.score, GameManager.quota]
	_game_over.visible = true

# HUD ---------------------------------------------------------------

func _update_hud() -> void:
	_quota_lbl.text      = "%d / %d" % [GameManager.score, GameManager.quota]
	_quota_bar.max_value = GameManager.quota
	_quota_bar.value     = clamp(GameManager.score, 0, GameManager.quota)
	_spins_lbl.text      = "%d spins left" % GameManager.spins_left
	_stage_lbl.text      = "%d-%d" % [GameManager.stage, GameManager.level]

func _draw() -> void:
	var tip   := WHEEL_POS + Vector2(0, -WHEEL_RADIUS - 5)
	var left  := tip + Vector2(-14, -22)
	var right := tip + Vector2( 14, -22)
	draw_colored_polygon(PackedVector2Array([tip, left, right]), Color.WHITE)
	draw_polyline(PackedVector2Array([tip, left, right, tip]), Color.BLACK, 2.0)
