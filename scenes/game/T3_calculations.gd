extends Node

var _game_state: Array[int]
var ended: bool = false
var turnX: bool = true
var _lines: Array[Vector3]
var simulations: int

var _board_stats: Array[SquareStats] # _square_stats 0 to 8
var _square_stats: SquareStats
var _initial_team: int

# rotable positions ordered linearly
const _original_positions: Array[int] = [0, 1, 2, 3, 5, 6, 7, 8]
# rotable positions ordered clockwise instead of linearly
const _clockwise_ordered_positions: Array[int] = [0, 1, 2, 5, 8, 7, 6, 3]
# equivalent positions for _original_positions if rotated counterclockwise
const _rotated_positions: Array[int] = [6, 3, 0, 7, 1, 8, 5, 2]
# equivalent positions for _original_positions if reflected horizontally
const _reflected_h_positions: Array[int] = [2, 1, 0, 5, 3, 8, 7, 6]
# equivalent positions for _original_positions if reflected vertically
const _reflected_v_positions: Array[int] = [6, 7, 8, 3, 5, 0, 1, 2]
# equivalent positions for _original_positions if reflected diagonally (bottom-left corner folding to upper-right)
const _reflected_d1_positions: Array[int] = [0, 3, 6, 1, 7, 2, 5, 8]
# equivalent positions for _original_positions if reflected diagonally (upper-left corner folding to lower-right)
const _reflected_d2_positions: Array[int] = [8, 5, 2, 7, 1, 6, 3, 0]

func _ready():
	_initialize_lines()
	#_game_state.append_array([0,0,2])
	#_game_state.append_array([0,1,0])
	#_game_state.append_array([1,0,0])
	#var results: Array[SquareStats] = _simulate_game(_game_state, 2)
	#for i in results.size():
		#print(i)
		#results[i].print_fork_stats()


func _simulate_game(_received_game_state:Array[int], _team:int) -> Array[SquareStats]:
	_initial_team = _team
	simulations = 0
	var _n_moves_made: int
	_board_stats.clear()
	_board_stats.resize(9)
	# for each square
	var _rotaflections: Array[int]
	var _squares_filled_as_rotaflections: Array[int]
	for _square in 9:
		# if the square was already filled as a rotaflection of another one, skip it
		if(_squares_filled_as_rotaflections.has(_square)):
			continue
		
		_rotaflections.clear()
		_square_stats = SquareStats.new()
		# only simulate if the square is empty
		if(_received_game_state[_square] == 0):
			_rotaflections = _simulate_square(_square, _received_game_state, _team, _n_moves_made, 1, false)
		_board_stats[_square] = _square_stats
		
		# copy the same values in the rotation squares
		for n in _rotaflections:
			_squares_filled_as_rotaflections.append(n)
			_board_stats[n] = _square_stats
	
	return _board_stats
	

func _simulate_square(_square: int, _previous_game_state:Array[int], _team:int, _n_moves_made: int, _multiplier: int, _forced_move: bool) -> Array[int]:
	simulations += 1
	# duplicate the game state
	var _current_game_state: Array[int] = _previous_game_state.duplicate()
	
	# how many of the remaining squares are rotations or reflections
	var _rotaflections: Array[int] = _get_rotaflections(_current_game_state.duplicate(), _square)
	
	# for each rotation, multiply the results to avoid recalculating them
	# ignore if _n_moves_made == 0, since _multiplier should only apply to submoves
	if(_n_moves_made > 0):
		_multiplier += _rotaflections.size()
	
	# make a move in this square
	_current_game_state[_square] = _team
	_n_moves_made += 1
	
	# check if the game is over
	var _is_over_result: Array[Vector4] = _is_game_over(_current_game_state)
	# if the game is not over, do some checks and change the player and simulate the next move
	if(_is_over_result[0][0] == -1): # not over
		# chek if this move allows the rival to win on their turn (dead end)
		var _future_game_state: Array[int]
		var _dead_end: bool
		var _rival_team: int = 1
		var _forced_next_move: int = -1
		if(_team == 1): _rival_team = 2
		for i in 9:
			_future_game_state = _current_game_state.duplicate()
			if(_future_game_state[i] == 0):
				_future_game_state[i] = _rival_team
				if(_is_game_over(_future_game_state)[0][0] == _rival_team):
					_dead_end = true
					break
		if(_dead_end):
			# increase a win for the opposing team and return
			if(_team == 1):
				_increase_stat(2, _n_moves_made + 1, _multiplier)
			else:
				_increase_stat(1, _n_moves_made + 1, _multiplier)
			return _rotaflections
		
		# if it's not a dead end, check if the move creates a fork (2+ ways to win) or forces the rival to block (1 win)
		if(!_dead_end):
			var _wins: int
			for i in 9:
				_future_game_state = _current_game_state.duplicate()
				if(_future_game_state[i] == 0):
					_future_game_state[i] = _team
					if(_is_game_over(_future_game_state)[0][0] == _team):
						_forced_next_move = i
						_wins += 1
			# this move creates forks
			if(_wins > 1):
				if(_team == 1):
					_square_stats.potential_forks_x += 1
					# if the fork is the direct response of the rival (_n_moves_made <= 2), count it as forced
					if(_forced_move || _n_moves_made <= 2):
						_square_stats.forced_forks_x += 1
				else:
					_square_stats.potential_forks_o += 1
					# if the fork is the direct response of the rival (_n_moves_made <= 2), count it as forced
					if(_forced_move || _n_moves_made <= 2):
						_square_stats.forced_forks_o += 1
			
			# if the player can win on their next move, they are forcing the rival to block
			# it's only really a forced move if it will happen as the first move or as a response to it, or if it's mantaining a chain of forced moves on the initial team
			if(_wins >= 1 && (_n_moves_made <= 2 || _forced_move)):
				_forced_move = true
			elif(_wins == 0  && _team != _initial_team):
				_forced_move = false
		
		# change player
		var _next_player: int = 1
		if _team == 1:
			_next_player = 2
		# simulate next movement for each square
		var _next_move_rotaflections: Array[int]
		if(_forced_next_move == -1):
			for i in 9:
				# only simulate if the square is empty
				if(_current_game_state[i] == 0):
					# skip if this square is a rotaflection of a previous one
					if(!_rotaflections.has(i)):
						# add it's rotaflections to the array, so they won't be calculated next
						_next_move_rotaflections += _simulate_square(i, _current_game_state, _next_player, _n_moves_made, _multiplier, _forced_move)
		# a block is forced, or else the rival will win
		else:
			for i in 9:
				# only simulate if the square is empty
				if(_current_game_state[i] == 0):
					# if it's the forced block move, simulate it
					if(i == _forced_next_move):
						_next_move_rotaflections += _simulate_square(_forced_next_move, _current_game_state, _next_player, _n_moves_made, _multiplier, _forced_move)
					# otherwise, mark it as a loss
					else:
						_increase_stat(_team, _n_moves_made + 2, _multiplier)
	# if the game is over, note it and continue to the next square
	else:
		if(_is_over_result[0][0] == 0): # tie
			_increase_stat(0, _n_moves_made, _multiplier)
		elif(_is_over_result[0][0] == 1): # x wins
			_increase_stat(1, _n_moves_made, _multiplier)
		elif(_is_over_result[0][0] == 2): # o wins
			_increase_stat(2, _n_moves_made, _multiplier)
	
	return _rotaflections


func _increase_stat(_received_team: int, _n_moves_made: int, _multiplier: int):
	if(_received_team == 0): # tie
		_square_stats.ties += 1 * _multiplier
		# save if it was min or max number of moves
		if(_square_stats.min_moves_to_tie > _n_moves_made):
			_square_stats.min_moves_to_tie = _n_moves_made
		if(_square_stats.max_moves_to_tie < _n_moves_made):
			_square_stats.max_moves_to_tie = _n_moves_made
	elif(_received_team == 1): # x
		_square_stats.wins_x += 1 * _multiplier
		# save if it was min or max number of moves
		if(_square_stats.min_moves_to_win_x > _n_moves_made):
			_square_stats.min_moves_to_win_x = _n_moves_made
		if(_square_stats.max_moves_to_win_x < _n_moves_made):
			_square_stats.max_moves_to_win_x = _n_moves_made
	elif(_received_team == 2): # o
		_square_stats.wins_o += 1 * _multiplier
		# save if it was min or max number of moves
		if(_square_stats.min_moves_to_win_o > _n_moves_made):
			_square_stats.min_moves_to_win_o = _n_moves_made
		if(_square_stats.max_moves_to_win_o < _n_moves_made):
			_square_stats.max_moves_to_win_o = _n_moves_made


func _get_rotaflections(_received_game_state:Array[int], _square:int) -> Array[int]:
	var _rotations: Array[int] = _get_rotations(_received_game_state.duplicate(), _square)
	var _reflections: Array[int] = _get_reflections(_received_game_state.duplicate(), _square)
	
	# add them to a single array, avoiding repeats
	var _rotaflections: Array[int] = _rotations
	for _reflection in _reflections:
		if(!_rotations.has(_reflection)):
			_rotaflections.append(_reflection)
	
	return _rotaflections


func _get_rotations(_received_game_state:Array[int], _square:int) -> Array[int]:
	# if center square return empty
	var _rotations: Array[int]
	if(_square == 4): return _rotations
	
	# get the index of the square number in the _original_positions array
	var _index_in_original_positions: int = _original_positions.find(_square)
		
	var _rotated_game_state: Array[int] = _received_game_state.duplicate()
	# rotate the board up to 3 times, from index + 2 (next possible rotation) to end of _clockwise_ordered_positions, in steps of 2
	# i is the index in _clockwise_ordered_positions of the square being rotated to
	for i in range(_index_in_original_positions + 2, _clockwise_ordered_positions.size(), +2):
		_rotated_game_state = _rotate_state(_rotated_game_state)
		# if the rotated board is the same as the received one, return the equivalent square
		if(_received_game_state == _rotated_game_state):
			_rotations.append(_clockwise_ordered_positions[i])
		
	return _rotations


func _rotate_state(_received_game_state:Array[int]) -> Array[int]:
	var _rotated_game_state: Array[int]
	_rotated_game_state = _received_game_state.duplicate()
	# create a rotated board
	for i in _original_positions.size():
		_rotated_game_state[_rotated_positions[i]] = _received_game_state[_original_positions[i]]
	return _rotated_game_state


func _get_reflections(_received_game_state:Array[int], _square:int) -> Array[int]:
	var _reflections: Array[int]
	
	# get the index of the square number in the _original_positions array
	var _index_in_original_positions: int = _original_positions.find(_square)
	
	# decide wich reflections need checking
	# (square 0 will check reflection_h with square 2, so square 2 doesn't need to do it again)
	var _get_reflection_h: bool
	var _get_reflection_v: bool
	var _get_reflection_d1: bool
	var _get_reflection_d2: bool
	match _square:
		0:
			_get_reflection_h = true
			_get_reflection_v = true
			_get_reflection_d2 = true
		1: 
			_get_reflection_v = true
			_get_reflection_d1 = true
			_get_reflection_d2 = true
		2: 
			_get_reflection_v = true
			_get_reflection_d1 = true
		3: 
			_get_reflection_h = true
			_get_reflection_d1 = true
			_get_reflection_d2 = true
		5: 
			_get_reflection_d1 = true
		6: 
			_get_reflection_h = true
		_:
			return _reflections
	
	var _reflected_game_state: Array[int]
	if(_get_reflection_h):
		_reflected_game_state = _received_game_state.duplicate()
		for i in _original_positions.size():
			_reflected_game_state[_reflected_h_positions[i]] = _received_game_state[_original_positions[i]]
		if(_received_game_state == _reflected_game_state):
			_reflections.append(_reflected_h_positions[_index_in_original_positions])
	
	if(_get_reflection_v):
		_reflected_game_state = _received_game_state.duplicate()
		for i in _original_positions.size():
			_reflected_game_state[_reflected_v_positions[i]] = _received_game_state[_original_positions[i]]
		if(_received_game_state == _reflected_game_state):
			_reflections.append(_reflected_v_positions[_index_in_original_positions])
	
	if(_get_reflection_d1):
		_reflected_game_state = _received_game_state.duplicate()
		for i in _original_positions.size():
			_reflected_game_state[_reflected_d1_positions[i]] = _received_game_state[_original_positions[i]]
		if(_received_game_state == _reflected_game_state):
			_reflections.append(_reflected_d1_positions[_index_in_original_positions])
	
	if(_get_reflection_d2):
		_reflected_game_state = _received_game_state.duplicate()
		for i in _original_positions.size():
			_reflected_game_state[_reflected_d2_positions[i]] = _received_game_state[_original_positions[i]]
		if(_received_game_state == _reflected_game_state):
			_reflections.append(_reflected_d2_positions[_index_in_original_positions])
	
	return _reflections


# returns an array of Vector4(winner + the 3 squares)
# its an array because someone might line in more than one line
# if it returns (0,0,0,0), result is a tie
# if it return (-1,-1,-1,-1) game is not over
func _is_game_over(_received_game_state: Array[int]) -> Array[Vector4]:
	# check if winner
	var _result: Array[Vector4]
	var _line_result: int
	for _line in _lines:
		_line_result = _check_if_line_is_winner(_line, _received_game_state)
		if(_line_result != 0):
			_result.append(Vector4(_line_result,_line[0],_line[1],_line[2]))
		
	if(_result.size() > 0):
		return _result
	
	# check if tie
	for n in 9:
		if(_received_game_state[n] == 0):
			# empty square, so not a tie. return game not over
			_result.append(Vector4(-1,-1,-1,-1))
			return _result
	
	# game is a tie
	_result.append(Vector4(0,0,0,0))
	return _result


func _check_if_line_is_winner(_squares: Vector3, _received_game_state: Array[int]) -> int:
	var _s1: int = _received_game_state[_squares[0]]
	var _s2: int = _received_game_state[_squares[1]]
	var _s3: int = _received_game_state[_squares[2]]
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
	_lines.append(Vector3(0,4,8))
	_lines.append(Vector3(2,4,6))
