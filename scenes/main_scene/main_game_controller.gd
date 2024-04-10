extends Node

@export var screen_camera: Camera2D

var _mode: int # -1 = transition mode (so, none), 0 = VN, 1 = Game


func get_mode() -> int:
	return _mode


func change_to_transition_mode():
	_mode = -1


func change_to_game_mode():
	_mode = 1
	screen_camera.on_size_changed()


func change_to_vn_mode():
	_mode = 0
	screen_camera.on_size_changed()
