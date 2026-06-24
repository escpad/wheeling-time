extends Node

const TOTAL_STAGES     := 3
const LEVELS_PER_STAGE := 3
const SPINS_PER_LEVEL  := 5

signal game_started
signal game_over(won: bool)
signal score_changed(new_score: int)
signal level_complete(new_stage: int, new_level: int)
signal event(name: String, data: Dictionary)

var score:      int = 0
var spins_left: int = 0
var quota:      int = 0
var stage:      int = 1
var level:      int = 1

func start_game() -> void:
	stage      = 1
	level      = 1
	score      = 0
	spins_left = SPINS_PER_LEVEL
	quota      = _quota_for(1, 1)
	emit_signal("game_started")

func _quota_for(s: int, l: int) -> int:
	return ((s - 1) * 3 + (l - 1) + 2) * 150

func is_boss_level() -> bool:
	return level == LEVELS_PER_STAGE

func advance_level() -> void:
	level += 1
	if level > LEVELS_PER_STAGE:
		level = 1
		stage += 1
	if stage > TOTAL_STAGES:
		emit_signal("game_over", true)
		return
	score      = 0
	spins_left = SPINS_PER_LEVEL
	quota      = _quota_for(stage, level)
	emit_signal("level_complete", stage, level)

func add_score(value: int) -> void:
	score += value
	emit_signal("score_changed", score)

func use_spin() -> void:
	spins_left -= 1

func is_over() -> bool:
	return score >= quota or spins_left <= 0

func check_and_end() -> void:
	if score >= quota:
		advance_level()
	elif spins_left <= 0:
		emit_signal("game_over", false)

# SCENE TRANSITIONS ---------------------------------------------------------------

func go_to_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)

func reload() -> void:
	get_tree().reload_current_scene()

# PAUSE / TIME SCALE ---------------------------------------------------------------

func pause() -> void:
	get_tree().paused = true

func resume() -> void:
	get_tree().paused = false

func slow_mo(scale: float = 0.5) -> void:
	Engine.time_scale = scale

func normal_speed() -> void:
	Engine.time_scale = 1.0
