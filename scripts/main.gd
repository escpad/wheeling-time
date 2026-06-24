extends Node2D

const WHEEL_POS    := Vector2(576, 324)
const WHEEL_RADIUS := 220.0

var _pixel_font: Font = preload("res://assets/BoldPixels.ttf")

@onready var _wheel:          Node2D      = $Wheel
@onready var _spin_btn:       Button      = $SpinButton
@onready var _spin_helper:    Label       = $SpinText
@onready var _quota_lbl:      Label       = $QuotaLabel
@onready var _quota_bar:      ProgressBar = $QuotaBar
@onready var _spins_lbl:      Label       = $SpinsLabel
@onready var _stage_lbl:      Label       = $StageLevelLabel
@onready var _debuff_lbl:     Label       = $DebuffLabel
@onready var _curse_tracker:  VBoxContainer = $CurseTracker
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
	for i in 3:
		var idx := i
		var btn: Button = _boon_btns[i]
		btn.pressed.connect(func(): _on_boon_chosen(idx))
		btn.mouse_entered.connect(func(): _scale_card(btn, Vector2(1.06, 1.06)))
		btn.mouse_exited.connect(func(): _scale_card(btn, Vector2.ONE))
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
	_level_layer.visible = true

func _on_continue_level() -> void:
	_level_layer.visible = false
	_spin_btn.disabled   = false
	_update_hud()

# BOON SELECTOR ---------------------------------------------------------------

func _scale_card(btn: Button, target: Vector2) -> void:
	btn.pivot_offset = btn.size / 2.0
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
	tw.tween_property(btn, "scale", target, 0.12)

func _show_boon_selector() -> void:
	_current_boons = _wheel.get_three_boons()
	for i in 3:
		var b: Dictionary = _current_boons[i]
		var pts   := ("+" if b["value"] >= 0 else "") + str(b["value"]) + " pts"
		var extra: String = ("%d°" % b["degrees"]) if b["type"] in ["fixed", "curse"] else b["type"]
		var passive := ""
		if b["type"] == "curse":
			if b.get("passive",  "") == "multiply_gold": passive += "\n1.5x all Gold"
			if b.get("passive2", "") == "double_dark":   passive += "\n2x all Curses"
		_boon_btns[i].text = "%s\n%s  %s\n%s%s" % [b["name"], b["type"].capitalize(), extra, pts, passive]
	_wheel.locked = true
	_boon_sel.visible = true

func _on_boon_chosen(index: int) -> void:
	var boon: Dictionary = _current_boons[index]
	if boon["type"] == "replace":
		_wheel.replace_random_section(boon["value"])
	else:
		_wheel.add_boon(boon)
	if boon["type"] == "curse":
		_add_curse_icon(boon)
	for btn: Button in _boon_btns:
		btn.scale = Vector2.ONE
	_boon_sel.visible = false
	_wheel.locked = false
	if _pending_level_complete:
		_show_level_complete_overlay()

func _add_curse_icon(boon: Dictionary) -> void:
	var abbrev := ""
	for word in boon["name"].split(" "):
		abbrev += word[0].to_upper()
	var effects: Array[String] = []
	if boon.get("passive",  "") == "multiply_gold": effects.append("1.5x all Gold")
	if boon.get("passive2", "") == "double_dark":   effects.append("2x all Curses")
	var icon := PanelContainer.new()
	icon.custom_minimum_size = Vector2(40, 40)
	icon.tooltip_text = "%s\n%s" % [boon["name"], "\n".join(effects)]
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.25, 0.0, 0.35)
	style.corner_radius_top_left     = 4
	style.corner_radius_top_right    = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left  = 4
	icon.add_theme_stylebox_override("panel", style)
	var lbl := Label.new()
	lbl.text = abbrev
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", _pixel_font)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	icon.add_child(lbl)
	_curse_tracker.add_child(icon)

func _on_skip() -> void:
	for btn: Button in _boon_btns:
		btn.scale = Vector2.ONE
	_boon_sel.visible = false
	_wheel.locked = false
	if _pending_level_complete:
		_show_level_complete_overlay()

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
