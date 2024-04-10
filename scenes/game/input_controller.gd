extends Node

@export var game_controller: Node
@export var board_controller: Node

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("submit"):
		_manage_submit()
	elif Input.is_action_just_pressed("autowin"):
		if Input.is_action_pressed("shift"):
			_skipmatch(1)
		else:
			_skipgame(1)
	elif Input.is_action_just_pressed("autolose"):
		if Input.is_action_pressed("shift"):
			_skipmatch(2)
		else:
			_skipgame(2)
	elif Input.is_action_just_pressed("autotie"):
		if Input.is_action_pressed("shift"):
			_skipmatch(0)
		else:
			_skipgame(0)
		


func _manage_submit():
	var _square_index: int = _get_selected_square_index()
	if(_square_index != -1):
		game_controller.square_clicked(_square_index)


func _get_selected_square_index() -> int:
	for n in 9:
		if(board_controller.squares_highlights[n].visible):
			return n
	return -1


func _skipgame(result: int):
	game_controller.skipgame(result)
	

func _skipmatch(result: int):
	game_controller.skipmatch(result)
	
