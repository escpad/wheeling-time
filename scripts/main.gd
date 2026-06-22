extends Node2D

const WHEEL_POS    := Vector2(576, 324)
const WHEEL_RADIUS := 220.0

@onready var _wheel:       Node2D      = $Wheel
@onready var _spin_btn:    Button      = $SpinButton
@onready var _spin_helper: Label       = $SpinText
@onready var _quota_lbl:   Label       = $QuotaLabel
@onready var _quota_bar:   ProgressBar = $QuotaBar
@onready var _spins_lbl:   Label       = $SpinsLabel
@onready var _game_over:   CanvasLayer = $GameOverLayer
@onready var _result_lbl:  Label       = $"GameOverLayer/ResultLabel"
@onready var _score_lbl:   Label       = $"GameOverLayer/ScoreLabel"
@onready var _restart_btn: Button      = $"GameOverLayer/RestartBtn"
@onready var _boon_sel:    CanvasLayer = $BoonSelectorLayer
@onready var _boon_btns:   Array       = [
	$"BoonSelectorLayer/BoonBtn0",
	$"BoonSelectorLayer/BoonBtn1",
	$"BoonSelectorLayer/BoonBtn2",
]

var _current_boons: Array = []

func _ready() -> void:
	GameManager.start_game(5, 600)
	_spin_btn.pressed.connect(_wheel.start_spin)
	_wheel.spin_stopped.connect(_on_spin_stopped)
	_restart_btn.pressed.connect(GameManager.reload)
	GameManager.score_changed.connect(func(_s: int): _update_hud())
	GameManager.game_over.connect(_on_game_over)
	for i in 3:
		var idx := i
		_boon_btns[i].pressed.connect(func(): _on_boon_chosen(idx))
	_update_hud()

func _on_spin_stopped(_index: int, value: int) -> void:
	_spin_helper.visible = false
	GameManager.add_score(value)
	GameManager.use_spin()
	_update_hud()
	GameManager.check_and_end()
	if not GameManager.is_over():
		_show_boon_selector()

func _show_boon_selector() -> void:
	_current_boons = _wheel.get_three_boons()
	for i in 3:
		var b: Dictionary = _current_boons[i]
		var pts   := ("+" if b["value"] >= 0 else "") + str(b["value"]) + " pts"
		var extra := ("%d°" % b["degrees"]) if b["type"] != "flex" else "flex"
		_boon_btns[i].text = "%s\n%s  %s\n%s" % [b["name"], b["type"].capitalize(), extra, pts]
	_wheel.locked = true
	_boon_sel.visible = true

func _on_boon_chosen(index: int) -> void:
	_wheel.add_boon(_current_boons[index])
	_boon_sel.visible = false
	_wheel.locked = false

func _on_game_over(won: bool) -> void:
	_spin_btn.disabled = true
	_boon_sel.visible = false
	_result_lbl.text = "YOU WIN!" if won else "YOU LOSE"
	_score_lbl.text  = "Final score: %d / %d" % [GameManager.score, GameManager.quota]
	_game_over.visible = true

func _update_hud() -> void:
	_quota_lbl.text  = "%d / %d" % [GameManager.score, GameManager.quota]
	_quota_bar.value = clamp(GameManager.score, 0, GameManager.quota)
	_spins_lbl.text  = "%d spins left" % GameManager.spins_left

func _draw() -> void:
	var tip   := WHEEL_POS + Vector2(0, -WHEEL_RADIUS - 5)
	var left  := tip + Vector2(-14, -22)
	var right := tip + Vector2( 14, -22)
	draw_colored_polygon(PackedVector2Array([tip, left, right]), Color.WHITE)
	draw_polyline(PackedVector2Array([tip, left, right, tip]), Color.BLACK, 2.0)
