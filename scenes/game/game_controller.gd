extends Node

@export var _print_debug: bool
@export var _T3_scene: Node
@export var game_initializer: Node
@export var game_logic: Node
@export var T3_ai: Node
@export var condition_controller: Node
@export var game_flag_list: Node
@export var board_controller: Node
@export var game_ui_controller: Node

var _game_running: bool
var _player_turn: bool

var player_team: int
var _sets: int
var _remaining_sets: int
var _remaining_round_in_set: bool
var _score: Array[int]
var _current_game: int
var handicap_rival: int
var handicap_player: int

var _selected_piece_x: int
var _selected_piece_o: int

var _piece_moved: Signal

var _calculated_ai_move: int = -1

# flags
var _turn_n: int
var _moves_player: int
var _moves_rival: int

func start_game():
	_current_game = 1
	_remaining_sets = _sets
	if(_remaining_sets > 0):
		_remaining_round_in_set = true
	else:
		_remaining_round_in_set = false
	_reset_match_stats()
	
	game_flag_list.reset_flag_to("end_states", [])
	set_game_running(true) # this will call manage_is_turn
	_set_player_turn(true)
	
	_update_game_counter()
	game_ui_controller.show_ui()


func _reset_match_stats():
	_score = [0,0]
	if(handicap_rival > 0):
		_score[1] = handicap_rival
		handicap_rival = 0
	if(handicap_player > 0):
		_score[0] = handicap_player
		handicap_player = 0
	_reset_game_stats()
	game_flag_list.reset_flags()


func _reset_game_stats():
	board_controller.reset_pieces_positions()
	_selected_piece_x = 0
	_selected_piece_o = 0
	
	_turn_n = 0
	_moves_player = 0
	_moves_rival = 0
	
	game_logic.reset_game()
	_update_score()
	


func _reset_board() -> Signal:
	game_flag_list.reset_flag_to("moves", [])
	var _reset_board_finished: Signal = board_controller.reset_board(player_team, false)
	return _reset_board_finished


func square_clicked(_square_index: int):
	if(_print_debug): print("GameController: Square " + str(_square_index) + " clicked.")
	if(is_game_running() && game_logic.is_movement_valid(_square_index)):
		_set_player_turn(false)
		make_move(game_logic.is_turn_x(), _square_index)
		


func make_move(_team_x: bool, _square_index: int):
	if(_print_debug): print("GameController: Making move in square " + str(_square_index) + ". For team x? " + str(_team_x))
	
	# update game_state
	game_logic.apply_movement(_team_x, _square_index)
	game_flag_list.set_flag_new_value("moves", _square_index)
	
	# move the piece
	_piece_moved = move_piece(_team_x, _square_index)
	# after the animation finishes call _advance_turn
	_piece_moved.connect(_advance_turn)
	
	# update stats
	if(player_team == 1 && _team_x):
		_moves_player += 1
	elif(player_team == 2 && !_team_x):
		_moves_player += 1
	else:
		_moves_rival += 1


# after the piece movement animation finishes
func _advance_turn():
	if(_piece_moved != null && _piece_moved.is_connected(_advance_turn)):
		_piece_moved.disconnect(_advance_turn)
	
	_turn_n += 1
	_set_player_turn(true)
	_update_flags()
	
	if(!is_game_running()): return
	
	if(game_logic.get_game_over_state() != -1):
		_manage_game_over()
	else:
		manage_ia_turn()
	

func _manage_game_over():
	# current game is over
	_set_player_turn(false)
	
	# score
	var _results: Array[Vector4] = game_logic.get_game_over_result()
	_rise_score(_results[0][0])
	
	# save end state
	var game_state: Array[int] = game_logic.get_game_state()
	var result: int = _results[0][0]
	var last_move: int = game_flag_list.get_flag_current_value("moves")
	var end_state: Array[int]
	end_state = game_state.duplicate()
	end_state.append(player_team)
	end_state.append(result)
	end_state.append(last_move)
	game_flag_list.add_new_flag_value("end_states", end_state)
	
	
	# highling winning line
	var _highlight_finished: Signal = board_controller.highlight_winning_line(_results)
	_highlight_finished.connect(_do_manage_game_over)
	


func _do_manage_game_over():
	if(_remaining_round_in_set):
		_remaining_round_in_set = false
		if(_print_debug): print("GameController: Game is over. Starting next round in set.")
		_manage_restart_game()
		_update_game_counter()
	else:
		_remaining_sets -= 1
		if(_remaining_sets > 0):
			_remaining_round_in_set = true
			if(_print_debug): print("GameController: Game is over. Starting next set.")
			_manage_restart_game()
			_update_game_counter()
		else:
			# match is over
			_set_player_turn(false)
			_update_game_counter()
			await get_tree().create_timer(1.0).timeout
			if(_print_debug): print("GameController: Match is over.")
			game_ui_controller.hide_ui()
			_T3_scene.game_functions.manage_game_over()


func _update_game_counter():
	game_ui_controller.set_game_counter(_current_game, (_sets * 2))
	


func _rise_score(_winner):
	if(_winner == 1):
		if(player_team == 1):
			_score[0] += 1
		else:
			_score[1] += 1
	elif(_winner == 2):
		if(player_team == 2):
			_score[0] += 1
		else:
			_score[1] += 1
	
	game_flag_list.set_flag_new_value("player_score", _score[0])
	game_flag_list.set_flag_new_value("rival_score", _score[1])
	_update_score()


func _update_score():
	game_ui_controller.set_player_score(_score[0])
	game_ui_controller.set_rival_score(_score[1])


func _manage_restart_game():
	_current_game += 1
	_reset_game_stats()
	_change_player_team()
	await _reset_board()
	if(player_team == 1):
		_set_player_turn(true)
	else:
		manage_ia_turn()


func move_piece(_team_x: bool, _square_index: int) -> Signal:
	# get the piece to move
	var _piece_index: int
	if(_team_x):
		# get the piece node
		_piece_index = _selected_piece_x
		_selected_piece_x += 1
	else:
		# get the piece node
		_piece_index = _selected_piece_o
		_selected_piece_o += 1
	
	# call move it
	return board_controller.move_piece(_piece_index, _team_x, _square_index)
	


func manage_ia_turn():
	if(game_logic.get_game_over_state() != -1): return
	
	# if it's not the player's turn
	if(!((game_logic.is_turn_x() && player_team == 1) || (!game_logic.is_turn_x() && player_team == 2))):
		_set_player_turn(false)
		var _team: int
		if(game_logic.is_turn_x()):
			_team = 1
		else:
			_team = 2
		
		if(_print_debug): print("GameController: Managing IA turn for team " + str(_team))
		var move_and_flag: Array = T3_ai.get_move(game_logic.get_game_state(), game_logic.is_turn_x())
		_calculated_ai_move = move_and_flag[0]
		var flag: String = move_and_flag[1]
		game_flag_list.set_flag_new_value("ai_move_flag", flag)
		# if a condition is meet, the game will stop before the AI makes its move
		# and the AI will immediatelly play when the game is resumed
		if(!condition_controller.check_conditions()):
			_play_ai_move()
		


func _play_ai_move():
	# think the move (wait)
	if(_turn_n > 0): await get_tree().create_timer(randf_range(0.5,1.5)).timeout
	
	make_move(game_logic.is_turn_x(), _calculated_ai_move)
	game_flag_list.set_flag_new_value("moves", _calculated_ai_move)
	_calculated_ai_move = -1


# reposition pieces on window resize
func reposition_pieces():
	board_controller.reposition_pieces()
	


func is_game_running() -> bool:
	return _game_running


func set_game_running(_state: bool):
	_game_running = _state
	
	# when the game resumes running, check make the calls to keep it going
	if(_game_running):
		if(_player_turn): board_controller.reactivate_squares()
		
		if(game_logic.get_game_over_state() != -1):
			_manage_game_over()
		elif(_calculated_ai_move == -1):
			manage_ia_turn()
		else:
			_play_ai_move()
			
	


func is_playable() -> bool:
	if(_game_running && _player_turn):
		return true
	return false


func _set_player_turn(_state: bool):
	_player_turn = _state
	if(!_player_turn):
		board_controller.unhighlight_squares()
	else:
		board_controller.reactivate_squares()


func _get_rival_team(_player_team: int) -> int:
	var _rival_team: int = 1
	if(_player_team == 1):
		_rival_team = 2
	return _rival_team


func _update_flags():
	game_flag_list.set_flag_new_value("moves_player", _moves_player)
	game_flag_list.set_flag_new_value("moves_rival", _moves_rival)
	game_flag_list.set_flag_new_value("_2_in_a_row_player", _is_team_2_in_a_row(player_team))
	game_flag_list.set_flag_new_value("_2_in_a_row_rival", _is_team_2_in_a_row(_get_rival_team(player_team)))
	
	# specific moves
	var rival_fork: bool = game_logic.has_fork(_get_rival_team(player_team))
	game_flag_list.set_flag_new_value("rival_fork", rival_fork)
	var player_fork: bool = game_logic.has_fork(player_team)
	game_flag_list.set_flag_new_value("player_fork", player_fork)
	
	# game over
	var game_over_state: int = game_logic.get_game_over_state()
	if(game_over_state != -1):
		game_flag_list.set_flag_new_value("game_over", true)
		game_flag_list.set_flag_new_value("score_difference", abs(_score[0] - _score[1]))
		
		var winner: int = 0
		if(game_over_state == player_team):
			winner = 1
		elif(game_over_state == _get_rival_team(player_team)):
			winner = 2
		game_flag_list.set_flag_new_value("last_game_winner", winner)
		var games_played: int = game_flag_list.get_flag_current_value("games_played")
		game_flag_list.set_flag_new_value("games_played", games_played + 1)
	
	condition_controller.check_conditions()
	game_flag_list.set_flag_new_value("game_over", false)


func _is_team_2_in_a_row(_team: int):
	var _game_state = game_logic.get_game_state()
	var _lines: Array[Vector3] = game_logic.get_lines()
	var _rival_team: int = _get_rival_team(_team)
	
	for _line in _lines:
		var _pieces_in_a_row: int
		
		for i in 3:
			var _square: int = _line[i]
			if(_game_state[_square] == _team):
				_pieces_in_a_row += 1
			elif(_game_state[_square] == _rival_team):
				_pieces_in_a_row = -99
		if(_pieces_in_a_row == 2):
			return true
	return false


func _change_player_team():
	if(player_team == 1):
		player_team = 2
	else:
		player_team = 1


func _set_sets(sets: int):
	_sets = sets


func skipgame(result: int):
	game_flag_list.set_flag_new_value("moves", 0)
	if(result == 1):
		game_logic.set_team_win(player_team)
	elif(result == 2):
		game_logic.set_team_win(_get_rival_team(player_team))
	else:
		game_logic.set_team_win(0)
	_advance_turn()


func skipmatch(result: int):
	_remaining_sets = 0
	_remaining_round_in_set = false
	if(result == 1):
		_score[0] = _sets
		_score[1] = 0
	elif(result == 2):
		_score[1] = _sets
		_score[0] = 0
	else:
		_score[1] = _sets
		_score[0] = _sets
	skipgame(result)


func get_score() -> Array[int]:
	return _score
