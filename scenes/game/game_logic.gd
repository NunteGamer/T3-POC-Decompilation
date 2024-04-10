extends Node

@export var _print_debug: bool

var _game_state: Array[int]
var _is_turn_x: bool
var _lines: Array[Vector3]
var _game_over_state: int

func _ready() -> void:
	# load winning lines
	_initialize_lines()
	
	# initial blank game state and settings
	_game_state = [0,0,0,0,0,0,0,0,0]
	_is_turn_x = true


func reset_game():
	_game_over_state = -1
	_game_state = [0,0,0,0,0,0,0,0,0]
	_is_turn_x = true


func is_turn_x() -> bool:
	return _is_turn_x
	


func get_game_state() -> Array[int]:
	return _game_state


func is_movement_valid(_square_index) -> bool:
	if(_game_state[_square_index] == 0):
		return true
	else:
		return false


func apply_movement(_team_x, _square_index):
	var _new_state: int = 1
	if(!_team_x): _new_state = 2
	_game_state[_square_index] = _new_state
	
	var _is_over_result: Array[Vector4] = _is_game_over()
	if(_is_over_result[0][0] == -1): # not over
		_game_over_state = -1
		if(_print_debug): print("GameLogic: Game not over")
		advance_turn()
	elif(_is_over_result[0][0] == 0): # tie
		_game_over_state = 0
		if(_print_debug): print("GameLogic: Tie")
	elif(_is_over_result[0][0] == 1): # x wins
		_game_over_state = 1
		if(_print_debug): print("GameLogic: Win X")
	elif(_is_over_result[0][0] == 2): # o wins
		_game_over_state = 2
		if(_print_debug): print("GameLogic: Win O")
	
	if(_print_debug): 
		print("GameLogic: Current game state: " + str(_game_state))
		print("---------------------------------------------------")
	


func advance_turn():
	_is_turn_x = !_is_turn_x


# returns an array of Vector4(winner + the 3 squares)
# its an array because someone might line in more than one line
# if it returns (0,0,0,0), result is a tie
# if it return (-1,-1,-1,-1) game is not over
func _is_game_over() -> Array[Vector4]:
	# check if winner
	var _result: Array[Vector4]
	var _line_result: int
	for _line in _lines:
		_line_result = _check_if_line_is_winner(_line)
		if(_line_result != 0):
			_result.append(Vector4(_line_result,_line[0],_line[1],_line[2]))
		
	if(_result.size() > 0):
		return _result
	
	# check if tie
	for n in 9:
		if(_game_state[n] == 0):
			# empty square, so not a tie. return game not over
			_result.append(Vector4(-1,-1,-1,-1))
			return _result
	
	# game is a tie
	_result.append(Vector4(0,0,0,0))
	return _result
	

func get_game_over_state() -> int:
	return _game_over_state


func _check_if_line_is_winner(_squares: Vector3) -> int:
	var _s1: int = _game_state[_squares[0]]
	var _s2: int = _game_state[_squares[1]]
	var _s3: int = _game_state[_squares[2]]
	if(_s1 != 0 && _s2 == _s1 && _s3 == _s1):
		return _s1
	return 0


func _initialize_lines():
	_lines.append(Vector3(0,1,2))
	_lines.append(Vector3(3,4,5))
	_lines.append(Vector3(6,7,8))
	_lines.append(Vector3(0,3,6))
	_lines.append(Vector3(1,4,7))
	_lines.append(Vector3(2,5,8))
	_lines.append(Vector3(0,4,8))
	_lines.append(Vector3(2,4,6))


func get_lines() -> Array[Vector3]:
	return _lines


func get_game_over_result() -> Array[Vector4]:
	return _is_game_over()


func has_fork(team: int) -> bool:
	var row2_lines: int
	for line in _lines:
		var line_array: Array[int] = [line[0], line[1], line[2]]
		var team_squares: int
		var empty_squares: int
		for i in line_array.size():
			if(_game_state[line_array[i]] == team):
				team_squares += 1
			elif(_game_state[line_array[i]] == 0):
				empty_squares += 1
		if(team_squares == 2 && empty_squares == 1):
			row2_lines += 1
	if(row2_lines > 1):
		return true
	return false
	

# when skipping game
func set_team_win(team: int):
	if(team == 0):
		_game_state = [1,1,2,2,1,1,1,2,2]
	else:
		_game_state = [team,team,team,0,0,0,0,0,0]
	_game_over_state = team
