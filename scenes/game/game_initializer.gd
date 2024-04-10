extends Node

@export var game_controller: Node
@export var board_controller: Node
@export var T3_ai: Node

func _ready() -> void:
	board_controller.instantiate_board_elements()


func set_player_team(_team: int):
	game_controller.player_team = _team


func apply_initial_board_configuration() -> Signal:
	return board_controller.reset_board(game_controller.player_team, true)


func set_ai_profile(_id: String):
	T3_ai.set_ai_profile(_id)


func set_sets(_sets: int):
	game_controller._set_sets(_sets)


func set_handicap(rival: bool, handicap: int):
	if(rival): game_controller.handicap_rival = handicap
	else: game_controller.handicap_player = handicap


func start_game():
	game_controller.start_game()

