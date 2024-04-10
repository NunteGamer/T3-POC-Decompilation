extends Node

@export var game_ui: Control
@export var rival_score_label: Label
@export var player_score_label: Label
@export var game_counter_label: Label

var _fade_duration: float = 0.5
var _tween: Tween
var _color: Color


func show_ui():
	_tween = create_tween()
	_color = game_ui.modulate
	_tween.tween_property(game_ui, "modulate", Color(_color.r, _color.g, _color.b, 1), _fade_duration)


func hide_ui():
	_tween = create_tween()
	_color = game_ui.modulate
	_tween.tween_property(game_ui, "modulate", Color(_color.r, _color.g, _color.b, 0), _fade_duration)


func set_rival_score(_score: int):
	rival_score_label.text = str(_score)


func set_player_score(_score: int):
	player_score_label.text = str(_score)


func set_game_counter(_current_game: int, _total_games: int):
	game_counter_label.text = str(_current_game) + "/" + str(_total_games)
