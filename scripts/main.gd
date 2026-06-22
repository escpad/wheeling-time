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

func _ready() -> void:
	GameManager.start_game(5, 600)
	_spin_btn.pressed.connect(_wheel.start_spin)
	_wheel.spin_stopped.connect(_on_spin_stopped)
	_restart_btn.pressed.connect(GameManager.reload)
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.game_over.connect(_on_game_over)
	_update_hud()

func _on_spin_stopped(_index: int, value: int) -> void:
	_spin_helper.visible = false
	GameManager.add_score(value)
	GameManager.use_spin()
	GameManager.check_and_end()

func _on_score_changed(_new_score: int) -> void:
	_update_hud()

func _on_game_over(won: bool) -> void:
	_spin_btn.disabled = true
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
