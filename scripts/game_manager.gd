extends Node

signal game_started
signal game_over(won: bool)
signal score_changed(new_score: int)
signal event(name: String, data: Dictionary)

var score:      int = 0
var spins_left: int = 0
var quota:      int = 0

func start_game(spin_count: int, quota_goal: int) -> void:
	score      = 0
	spins_left = spin_count
	quota      = quota_goal
	emit_signal("game_started")

func add_score(value: int) -> void:
	score += value
	emit_signal("score_changed", score)

func use_spin() -> void:
	spins_left -= 1

func is_over() -> bool:
	return score >= quota or spins_left <= 0

func check_and_end() -> void:
	if is_over():
		emit_signal("game_over", score >= quota)

func go_to_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)

func reload() -> void:
	get_tree().reload_current_scene()

func pause() -> void:
	get_tree().paused = true

func resume() -> void:
	get_tree().paused = false

func slow_mo(scale: float = 0.5) -> void:
	Engine.time_scale = scale

func normal_speed() -> void:
	Engine.time_scale = 1.0
