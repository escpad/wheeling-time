# MusicPlayer — autoload that loops background music for the whole session.
# Setup: Project Settings → Autoload → add this file as "MusicPlayer".
# Being an autoload, the track keeps playing across scene reloads (restarts).

extends Node

const TRACK_PATH := "res://assets/Apero Hour.mp3"
const VOLUME_DB  := -8.0

var _player: AudioStreamPlayer

func _ready() -> void:
	var stream: AudioStream = load(TRACK_PATH)
	if stream is AudioStreamMP3:
		stream.loop = true   # force loop regardless of import setting
	_player = AudioStreamPlayer.new()
	_player.stream    = stream
	_player.volume_db = VOLUME_DB
	add_child(_player)
	_player.play()

func set_volume(db: float) -> void:
	_player.volume_db = db

func toggle() -> void:
	_player.stream_paused = not _player.stream_paused
