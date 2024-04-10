extends Node

@export var _print_debug: bool
@export var game_controller: Node
@export var game_logic: Node
@export var T3_calculations: Node
@export var game_flag_list: Node


var _ai_profile: String
var _board_stats: Array[SquareStats] # _square_stats 0 to 8
# _square_stats = x stats, o stats, tie stats
# x stats = wins, min moves, max moves
var _team: int
var _rival_team: int
var _game_state: Array[int]


func set_ai_profile(_profile: String):
	_ai_profile = _profile


# returns [move, flag activated by that move]
func get_move(game_state: Array[int], _is_team_x: bool) -> Array:
	_game_state = game_state
	if(_is_team_x):
		_team = 1
	else:
		_team = 2
		
	_rival_team
	if(_team == 1):
		_rival_team = 2
	else:
		_rival_team = 1
	
	# simulate the game to get the stats
	_board_stats = T3_calculations._simulate_game(_game_state, _team)
	
	# get the move from the ai profile
	var move_and_flags: Array
	match _ai_profile:
		"perfect":
			move_and_flags = _get_optimal_move()
		"poc_daisy":
			move_and_flags = _get_dumb_move()
		"poc_daisy2":
			move_and_flags = _get_daisy2_move()
		"poc_nikola":
			move_and_flags = _get_nikola_move()
		"poc_ingrid":
			move_and_flags = _get_tying_move()
	
	# make move
	if(_print_debug): print("T3AI: AI will move for team " + str(_team) + " on square " + str(move_and_flags[0]))
	
	return move_and_flags


func _is_board_empty() -> bool:
	if(_game_state == [0,0,0,0,0,0,0,0,0]):
		return true
	return false


func _is_first_player_move() -> bool:
	var moves_made: int
	for square in _game_state:
		if(square != 0):
			moves_made += 1
	if(moves_made < 2):
		return true
	return false


func _is_center_played() -> bool:
	if(_game_state[4] != 0):
		return true
	return false


func _get_available_moves() -> Array[int]:
	var _available_moves: Array[int]
	for i in _board_stats.size():
		if(game_logic.is_movement_valid(i)):
			_available_moves.append(i)
	return _available_moves


func _get_move_from_array(_moves: Array[int]) -> int:
	var _moves_size: int = _moves.size()
	var _picked_move: int
	# if there's just one move, pick it
	if(_moves_size == 1):
		_picked_move = _moves[0]
	# if there are more, pick one at random
	elif(_moves_size > 1):
		_picked_move = _moves[randi_range(0, _moves_size - 1)]
	# the array is empty
	else:
		_picked_move = -1
	
	return _picked_move


func _pick_immediate_winning_move(_available_moves: Array[int]) -> Array:
	var immediate_winning_moves: Array[int] = _get_immediate_winning_moves(_available_moves)
	var move_and_flag: Array
	var move: int
	var flag: String
	
	move = _get_move_from_array(immediate_winning_moves)
	if(move > -1):
		flag = "winning_move"
		if(_print_debug): print("T3AI: Picked inmediate winning move: " + str(move))
		return _add_move_and_flag(move, flag)
	if(_print_debug): print("T3AI: No immediate winning moves.")
	return _add_move_and_flag(move, flag)


func _get_immediate_winning_moves(_available_moves: Array[int]) -> Array[int]:
	# search for a move that makes you win immediately
	var _immediate_winning_moves: Array[int]
	for i in _available_moves:
		var _this_square_stats: SquareStats = _board_stats[i]
		var _this_square_min_moves_to_win: int
		if(_team == 1):
			_this_square_min_moves_to_win = _this_square_stats.min_moves_to_win_x
		else:
			_this_square_min_moves_to_win = _this_square_stats.min_moves_to_win_o
		if(_this_square_min_moves_to_win == 1):
			_immediate_winning_moves.append(i)
	
	return _immediate_winning_moves


func _pick_self_forced_forks_move(_available_moves: Array[int]) -> Array:
	var self_forced_forks_moves: Array[int] = _get_self_forced_forks_moves(_available_moves)
	var move_and_flag: Array
	var move: int
	var flag: String
	
	move = _get_move_from_array(self_forced_forks_moves)
	if(move > -1):
		flag = "self_forced_fork"
		if(_print_debug): print("T3AI: Picked self forced fork: " + str(move))
		return _add_move_and_flag(move, flag)
	if(_print_debug): print("T3AI: No self forced fork moves.")
	return _add_move_and_flag(move, flag)


func _get_self_forced_forks_moves(_available_moves: Array[int]) -> Array[int]:
	var _self_forks_moves: Array[int]
	for i in _available_moves:
		var _this_square_stats: SquareStats = _board_stats[i]
		
		# check if this move has rival forced forks
		var _this_square_self_forks: int
		if(_team == 1):
			_this_square_self_forks = _this_square_stats.forced_forks_x
		else:
			_this_square_self_forks = _this_square_stats.forced_forks_o
		if(_this_square_self_forks > 0):
			_self_forks_moves.append(i)
	return _self_forks_moves


func _pick_2row_move(_available_moves: Array[int]) -> Array:
	var _2row_moves: Array[int] = _get_2row_moves(_available_moves)
	var move_and_flag: Array
	var move: int
	var flag: String
	
	move = _get_move_from_array(_2row_moves)
	if(move > -1):
		flag = "2row_move"
		if(_print_debug): print("T3AI: Picked 2row move: " + str(move))
		return _add_move_and_flag(move, flag)
	if(_print_debug): print("T3AI: No 2row move.")
	return _add_move_and_flag(move, flag)


func _get_2row_moves(_available_moves: Array[int]) -> Array[int]:
	var _2row_moves: Array[int]
	# get squares with player pieces
	var player_occupied_squares: Array[int]
	for i in _game_state.size():
		if(_game_state[i] == _team):
			player_occupied_squares.append(i)
	# get if avaible moves are adjacent to a square with a player piece
	var lines: Array[Vector3] = game_logic.get_lines()
	for move in _available_moves:
		for player_occupied_square in player_occupied_squares:
			if(_are_squares_adjacent(move, player_occupied_square)):
				var line_blocked: bool
				for line in lines:
					var line_array: Array[int] = [line.x, line.y, line.z]
					if(move in line_array && player_occupied_square in line_array):
						for i in line_array.size():
							if(_game_state[line_array[i]] == _rival_team):
								line_blocked = true
								break
						if(line_blocked): break
				if(!line_blocked): _2row_moves.append(move)
				break
	
	return _2row_moves


func _pick_block(_available_moves: Array[int]) -> Array:
	var move: int = _get_block_move(_available_moves)
	var move_and_flag: Array
	var flag: String
	if(move > -1):
		flag = "block"
		if(_print_debug): print("T3AI: Picked block: " + str(move))
		return _add_move_and_flag(move, flag)
	if(_print_debug): print("T3AI: Nothing to block.")
	return _add_move_and_flag(move, flag)


func _get_block_move(_available_moves: Array[int]) -> int:
	var _block_moves: Array[int]
	var winning_lines: Array[Vector3] = game_logic.get_lines()
	var line_array: Array[int]
	for i in _available_moves:
		for line in winning_lines:
			line_array = [line.x, line.y, line.z]
			# rival as in the rival of the AI
			var rival_squares: int
			var empty_squares: int
			var empty_square: int
			for square in line_array:
				if(_game_state[square] == _rival_team):
					rival_squares += 1
				elif(_game_state[square] == 0):
					empty_squares += 1
					empty_square = square
			if(rival_squares == 2 && empty_squares == 1):
				_block_moves.append(empty_square)
	
	if(_block_moves.size() == 0): return -1
	return _block_moves[randi_range(0, _block_moves.size() - 1)]
	


func _pick_move_that_avoids_repeated_rival_game_state(_available_moves: Array[int]) -> Array:
	var _avoid_repeated_end_move: int = _get_move_that_avoids_repeated_rival_game_state(_available_moves)
	var move_and_flag: Array
	var move: int = _avoid_repeated_end_move
	var flag: String
	if(move > -1):
		flag = "block_repeated_rival_end"
		if(_print_debug): print("T3AI: Picked move that avoids repeated game state: " + str(move))
		return _add_move_and_flag(move, flag)
	if(_print_debug): print("T3AI: No end state to avoid yet.")
	return _add_move_and_flag(move, flag)

func _get_move_that_avoids_repeated_rival_game_state(_available_moves: Array[int]) -> int:
	var end_states: Array = game_flag_list.get_flag_absolute_value("end_states")
	if(end_states.size() == 0): return -1
	if(end_states[0].size() == 0): return -1
	var rival_moves_remaining: int
	var move: int
	
	var board_end_state: Array[int]
	var end_state_rival_team: int
	var result: int
	var last_move: int
	for end_state in end_states:
		board_end_state = end_state.duplicate()
		board_end_state.remove_at(board_end_state.size() - 1)
		board_end_state.remove_at(board_end_state.size() - 1)
		end_state_rival_team = end_state[9]
		result = end_state[10]
		last_move = end_state[11]
		
		
		# if the rival didn't win, skip this end_state
		if(result != end_state_rival_team): continue
		# if the last move's square is alreadu occupied, skip this end_state
		if(_game_state[last_move] != 0): continue
		# check if every rival square except the last move matches
		var unmatch: bool
		for i in _game_state.size():
			if(i == last_move): continue
			if(_game_state[i] == _rival_team):
				if(end_state[i] != end_state_rival_team):
					unmatch = true
			# if the rival movements don't match, skip
			elif(end_state[i] == end_state_rival_team):
				unmatch = true
		if(!unmatch):
			return last_move
		print("------------")
	return -1


func _pick_random_move(_available_moves: Array[int]):
	var move_and_flag: Array
	var move: int
	var flag: String
	
	move = _get_move_from_array(_available_moves)
	flag = "random_move"
	if(_print_debug): print("T3AI: Picked random move: " + str(move))
	return _add_move_and_flag(move, flag)



# adjacent in a possible 3 in a row line (2 and 3 are not considered adjacent)
func _are_squares_adjacent(a: int, b: int) -> bool:
	if(a == 0 && b in [1, 3, 4]):
		return true
	elif(a == 1 && b in [0, 2, 4]):
		return true
	elif(a == 2 && b in [1, 4, 5]):
		return true
	elif(a == 3 && b in [0, 4, 6]):
		return true
	elif(a == 4 && b in [1, 3, 5, 7]):
		return true
	elif(a == 5 && b in [2, 4, 8]):
		return true
	elif(a == 6 && b in [3, 4, 7]):
		return true
	elif(a == 7 && b in [4, 6, 8]):
		return true
	elif(a == 8 && b in [4, 5, 7]):
		return true
	return false


func _add_move_and_flag(move: int, flag: String) -> Array:
	var move_and_flag: Array
	move_and_flag.append(move)
	move_and_flag.append(flag)
	return move_and_flag


func _pick_block_nikola(_available_moves: Array[int]) -> Array:
	var move: int = _get_block_move_nikola(_available_moves)
	var move_and_flag: Array
	var flag: String
	if(move > -1):
		flag = "block"
		if(_print_debug): print("T3AI: Picked block: " + str(move))
		return _add_move_and_flag(move, flag)
	if(_print_debug): print("T3AI: Nothing to block.")
	return _add_move_and_flag(move, flag)


func _get_block_move_nikola(_available_moves: Array[int]) -> int:
	var _block_moves: Array[int]
	var winning_lines: Array[Vector3] = game_logic.get_lines()
	var line_array: Array[int]
	for i in _available_moves:
		for line in winning_lines:
			line_array = [line.x, line.y, line.z]
			# rival as in the rival of the AI
			var rival_squares: int
			var empty_squares: int
			var empty_square: int
			for j in line_array.size():
				var square: int = line_array[j]
				if(j in [0,3,6]):
					pass
				elif(_game_state[square] == _rival_team):
					rival_squares += 1
				elif(_game_state[square] == 0):
					empty_squares += 1
					empty_square = square
			if(rival_squares == 2 && empty_squares == 1):
				_block_moves.append(empty_square)
	
	if(_block_moves.size() == 0): return -1
	return _block_moves[randi_range(0, _block_moves.size() - 1)]










# choose at random between the move with:
# - most potential wins
# - fewer potential wins
# - fewer movements to win
func _get_optimal_move() -> Array:
	var _move: int = -1
	var flag: String
	var _available_moves: Array[int] = _get_available_moves()
	
	################### immediate winning ###################
	
	var _immediate_winning_moves: Array[int] = _get_immediate_winning_moves(_available_moves)
	_move = _get_move_from_array(_immediate_winning_moves)
	if(_move > -1):
		if(_print_debug): print("T3AI: Picked inmediate winning move: " + str(_move))
		return _add_move_and_flag(_move, flag)
	
	################### block ###################
	
	# search for moves that makes your rival win next turn
	var _non_immediate_losing_moves: Array[int] = _available_moves.duplicate()
	for i in _available_moves:
		var _this_square_stats: SquareStats = _board_stats[i]
		var _this_square_min_moves_to_lose: int
		if(_team == 1):
			_this_square_min_moves_to_lose = _this_square_stats.min_moves_to_win_o
		else:
			_this_square_min_moves_to_lose = _this_square_stats.min_moves_to_win_x
		
		if(_this_square_min_moves_to_lose == 2):
			_non_immediate_losing_moves.erase(i)
	
	# if there are no moves that don't cause immediate losing, pick at random
	if(_non_immediate_losing_moves.size() == 0):
		_move = _available_moves[randi_range(0, _available_moves.size() - 1)]
		if(_print_debug): print("T3AI: Picked a random move, since all is lost anyway: " + str(_move) + ". Pool: " + str(_available_moves))
	# if there is just one, pick it
	elif(_non_immediate_losing_moves.size() == 1):
		_move = _non_immediate_losing_moves[0]
		if(_print_debug): print("T3AI: Picked the only move that doesn't result in defeat: " + str(_move))
	
	if(_move > -1): 
		return _add_move_and_flag(_move, flag)
	
	################### remove moves with 0 wins ###################
	
	var _acceptable_moves: Array[int] = _available_moves
	
	for i in _acceptable_moves:
		var _this_square_stats: SquareStats = _board_stats[i]
		var _this_square_wins: int
		if(_team == 1):
			_this_square_wins = _this_square_stats.wins_x
		else:
			_this_square_wins = _this_square_stats.wins_o
		if(_this_square_wins == 0):
			_acceptable_moves.erase(i)
	
	# if there's only one move remaining, pick it
	if(_acceptable_moves.size() == 1):
		_move = _acceptable_moves[0]
		if(_print_debug): print("T3AI: Picked the only move with potential wins: " + str(_move))
		return _add_move_and_flag(_move, flag)
	
	################### remove moves with forced rival forks ###################
	var _previous_acceptable_moves: Array[int] = _acceptable_moves.duplicate()
	var _rival_forks_moves: Array[int]
	
	for i in _previous_acceptable_moves:
		var _this_square_stats: SquareStats = _board_stats[i]
		# check if this move has rival forced forks
		var _this_square_rival_forks: int
		if(_team == 1):
			_this_square_rival_forks = _this_square_stats.forced_forks_o
		else:
			_this_square_rival_forks = _this_square_stats.forced_forks_x
		if(_this_square_rival_forks > 0):
			_acceptable_moves.erase(i)
	
	# if there's only one move remaining, pick it
	if(_acceptable_moves.size() == 1):
		_move = _acceptable_moves[0]
		if(_print_debug): print("T3AI: Picked the only move without forced rival forks: " + str(_move))
	# if there aren't any moves remaining, pick from the previous acceptable ones
	elif(_acceptable_moves.size() == 0):
		_move = _previous_acceptable_moves[randi_range(0, _previous_acceptable_moves.size() - 1)]
		if(_print_debug): print("T3AI: Picked a random move with potential wins: " + str(_move) + " .Pool: " + str(_previous_acceptable_moves))
	
	if(_move > -1): 
		return _add_move_and_flag(_move, flag)
	
	#################### pick self forced forks ###################
	
	var _get_self_forks_moves: Array[int] = _get_self_forced_forks_moves(_acceptable_moves)
	_move = _get_move_from_array(_get_self_forks_moves)
	if(_move > -1):
		if(_print_debug): print("T3AI: Picked self forced fork: " + str(_move))
		return _add_move_and_flag(_move, flag)
		
	#################### pick a move with no rival wins ###################
	
	var _no_rival_wins_moves: Array[int]
	for i in _acceptable_moves:
		var _this_square_stats: SquareStats = _board_stats[i]
		
		var _this_square_rival_wins: int
		if(_team == 1):
			_this_square_rival_wins = _this_square_stats.wins_o
		else:
			_this_square_rival_wins = _this_square_stats.wins_x
		if(_this_square_rival_wins == 0):
			_no_rival_wins_moves.append(i)
	
	# if there is any, pick from them
	if(_no_rival_wins_moves.size() > 0):
		_move = _no_rival_wins_moves[randi_range(0, _no_rival_wins_moves.size() - 1)]
		if(_print_debug): print("T3AI: Picked a random move with no rival wins: " + str(_move) + ". Pool:" + str(_no_rival_wins_moves))
		return _add_move_and_flag(_move, flag)
	
	#################### pick a move with ties ###################
	
	var _tie_moves: Array[int]
	for i in _acceptable_moves:
		var _this_square_stats: SquareStats = _board_stats[i]
		
		var _this_square_tie_moves: int
		_this_square_tie_moves = _this_square_stats.ties
		if(_this_square_tie_moves > 0):
			_tie_moves.append(i)
	
	# if there is any, pick from them
	if(_tie_moves.size() > 0):
		_move = _tie_moves[randi_range(0, _tie_moves.size() - 1)]
		if(_print_debug): print("T3AI: Picked a random move with ties: " + str(_move) + ". Pool:" + str(_tie_moves))
		return _add_move_and_flag(_move, flag)
		
	
	
	#################### pick a random acceptable move ###################
	
	_move = _acceptable_moves[randi_range(0, _acceptable_moves.size() - 1)]
	if(_print_debug): print("T3AI: Picked a random acceptable move: " + str(_move) + ". Pool:" + str(_acceptable_moves))
	return _add_move_and_flag(_move, flag)
	




func _get_dumb_move() -> Array:
	var move: int = -1
	var flag: String
	var move_and_flag: Array
	var _available_moves: Array[int] = _get_available_moves()
	
	if(_is_first_player_move()):
		# pick upper right corner
		if(_game_state[2] == 0):
			move = 2
		# if it's occupied, pick the lower right corner
		else:
			move = 8
		if(_print_debug): print("T3AI: Picked corner")
		return _add_move_and_flag(move, flag)
	
	################### immediate winning ###################
	
	move_and_flag = _pick_immediate_winning_move(_available_moves)
	if(move_and_flag[0] > -1): return move_and_flag
	
	################### avoid repeated end state ###################
	
	move_and_flag = _pick_move_that_avoids_repeated_rival_game_state(_available_moves)
	if(move_and_flag[0] > -1): return move_and_flag
	
	################### make 2 in a row ###################
	
	move_and_flag = _pick_2row_move(_available_moves)
	if(move_and_flag[0] > -1): return move_and_flag
	
	################### play random ###################
	
	return _pick_random_move(_available_moves)
	


func _get_daisy2_move() -> Array:
	var move: int = -1
	var flag: String
	var move_and_flag: Array
	var _available_moves: Array[int] = _get_available_moves()
	
	if(_is_first_player_move()):
		# pick center
		if(_game_state[4] == 0):
			move = 4
		if(_print_debug): print("T3AI: Picked center")
		return _add_move_and_flag(move, flag)
	
	################### immediate winning ###################
	
	move_and_flag = _pick_immediate_winning_move(_available_moves)
	if(move_and_flag[0] > -1): return move_and_flag
	
	################### avoid repeated end state ###################
	
	move_and_flag = _pick_move_that_avoids_repeated_rival_game_state(_available_moves)
	if(move_and_flag[0] > -1): return move_and_flag
	
	#################### pick self forced forks ###################

	move_and_flag = _pick_self_forced_forks_move(_available_moves)
	if(move_and_flag[0] > -1): return move_and_flag
	
	################### make 2 in a row ###################
	
	move_and_flag = _pick_2row_move(_available_moves)
	if(move_and_flag[0] > -1): return move_and_flag
	
	################### play random ###################
	
	return _pick_random_move(_available_moves)
	


func _get_nikola_move() -> Array:
	var move: int = -1
	var flag: String
	var move_and_flag: Array
	var _available_moves: Array[int] = _get_available_moves()
	
	if(_is_first_player_move()):
		# pick center
		if(_game_state[4] == 0):
			move = 4
		if(_print_debug): print("T3AI: Picked center")
		return _add_move_and_flag(move, flag)
		
	################### immediate winning ###################
	
	move_and_flag = _pick_immediate_winning_move(_available_moves)
	if(move_and_flag[0] > -1): return move_and_flag
	
	################### avoid repeated end state ###################
	
	move_and_flag = _pick_move_that_avoids_repeated_rival_game_state(_available_moves)
	if(move_and_flag[0] > -1): return move_and_flag
	
	################### block ###################
	
	move_and_flag = _pick_block_nikola(_available_moves)
	if(move_and_flag[0] > -1): return move_and_flag
	
	#################### pick self forced forks ###################
	var score: Array[int] = game_controller.get_score().duplicate()
	if(score[1] < score[0]):
		move_and_flag = _pick_self_forced_forks_move(_available_moves)
		if(move_and_flag[0] > -1): return move_and_flag
	
	################### play random ###################
	
	return _pick_random_move(_available_moves)


func _get_tying_move() -> Array:
	var move: int = -1
	var flag: String
	var move_and_flag: Array
	var _available_moves: Array[int] = _get_available_moves()
	
	
	################### immediate winning ###################
	
	move_and_flag = _pick_immediate_winning_move(_available_moves)
	if(move_and_flag[0] > -1): return move_and_flag
	
	################### block ###################
	
	move_and_flag = _pick_block(_available_moves)
	if(move_and_flag[0] > -1): return move_and_flag
	
	################### avoid repeated end state ###################
	
	move_and_flag = _pick_move_that_avoids_repeated_rival_game_state(_available_moves)
	if(move_and_flag[0] > -1): return move_and_flag
	
	#################### pick self forced forks ###################
	
	if(randf() > 0.4):
		move_and_flag = _pick_self_forced_forks_move(_available_moves)
		if(move_and_flag[0] > -1): return move_and_flag
	
	################### play random ###################
	
	return _pick_random_move(_available_moves)
