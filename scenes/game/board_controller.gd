extends Node

var piece_scene: PackedScene = preload("res://scenes/game/piece.tscn")
var board_square: PackedScene = preload("res://scenes/game/board_square.tscn")
@export var game_controller: Node
@export var T3_scene_container: Node2D
@export var board_areas: Control
@export var squares_highlights: Array[ColorRect]
@export var winning_lines: Array[Node2D]
@export var tie_lines: Node2D
@export var game_audio_controller: Node

var _color: Color

var _board_square_areas: Array[Area2D]
var pieces_x: Array[Node2D]
var pieces_o: Array[Node2D]
var pieces_positions_x: float = 250
var pieces_positions_y: float = 580
var pieces_x_positions: Array[int]
var pieces_o_positions: Array[int]

var board_squares_offset: float = 284

var _tween: Tween
var _pieces_reset_duration: float =  0.25
var _piece_movement_duration: float = 0.5
var _highlight_fade_duration: float = 0.5


func instantiate_board_elements():
	_instantiate_pieces()
	_instantiate_board_square_areas()


func _instantiate_pieces():
	for n in 5:
		_instantiate_piece(true, n, false)
	
	for n in 5:
		_instantiate_piece(false, n, true)


func _instantiate_piece(top: bool, piece_index: int, is_x: bool):
	var piece_instance: Node2D = piece_scene.instantiate()
	T3_scene_container.add_child(piece_instance)
	var pos_y: float = pieces_positions_y
	if(top): pos_y *= -1
	piece_instance.position = Vector2(pieces_positions_x * (piece_index - 2), pos_y)
	if(is_x):
		piece_instance.set_sprite("x")
		pieces_x.append(piece_instance)
	else:
		piece_instance.set_sprite("o")
		pieces_o.append(piece_instance)


func _instantiate_board_square_areas():
	for n in 9:
		instantiate_board_square_area(n)


func instantiate_board_square_area(square_index: int):
	var board_square_instance: Area2D = board_square.instantiate()
	board_square_instance.game_controller = game_controller
	board_areas.add_child(board_square_instance)
	
	var pos: Vector2
	match square_index:
		0:
			pos = Vector2(-board_squares_offset, -board_squares_offset)
		1:
			pos = Vector2(0, -board_squares_offset)
		2:
			pos = Vector2(board_squares_offset, -board_squares_offset)
		3:
			pos = Vector2(-board_squares_offset, 0)
		4:
			pos = Vector2(0, 0)
		5:
			pos = Vector2(board_squares_offset, 0)
		6:
			pos = Vector2(-board_squares_offset, board_squares_offset)
		7:
			pos = Vector2(0, board_squares_offset)
		8:
			pos = Vector2(board_squares_offset, board_squares_offset)
	
	board_square_instance.position = pos
	board_square_instance.highlight = squares_highlights[square_index]
	_board_square_areas.append(board_square_instance)


func unhighlight_squares():
	for _square in _board_square_areas:
		_square.unhighlight()


func reactivate_squares():
	for _square in _board_square_areas:
		_square.reactivate()


func reset_board(_player_team: int, _instantly: bool) -> Signal:
	var pos_y: float = pieces_positions_y
	var _final_pos: Vector2
	var _top: bool
	if(_player_team == 2):
		_top = true
	
	var _duration: float
	var sound_timer_duration: float
	_tween = create_tween()
	if(!_instantly): _play_piece_move()
	for _piece_index in pieces_x.size():
		# x
		pos_y = pieces_positions_y
		if(_top): pos_y *= -1
		_tween.set_parallel(false)
		if(!_instantly): _duration = _pieces_reset_duration + randf_range(0,0.2)
		_final_pos = Vector2(pieces_positions_x * (_piece_index - 2), pos_y)
		_tween.tween_property(pieces_x[_piece_index], "position", _final_pos, _duration)
		# o
		pos_y = pieces_positions_y
		if(!_top): pos_y *= -1
		_tween.set_parallel(true)
		if(!_instantly): _duration = _pieces_reset_duration + randf_range(0,0.2)
		_final_pos = Vector2(pieces_positions_x * (_piece_index - 2), pos_y)
		_tween.tween_property(pieces_o[_piece_index], "position", _final_pos, _duration)
		
		# call move piece for next piece
		if(!_instantly && _piece_index < pieces_x.size() - 1):
			sound_timer_duration += _duration
			var timer: SceneTreeTimer = get_tree().create_timer(sound_timer_duration)
			timer.connect("timeout", _play_piece_move)
		
	_tween.set_parallel(false)
	
	return _tween.finished


func move_piece(_piece_index: int, _team_x: bool, _square_index: int) -> Signal:
	var _piece: Node2D
	if(_team_x):
		pieces_x_positions[_piece_index] = _square_index
		_piece = pieces_x[_piece_index]
	else:
		pieces_o_positions[_piece_index] = _square_index
		_piece = pieces_o[_piece_index]
	
	
	var _pos: Vector2 = squares_highlights[_square_index].global_position + squares_highlights[0].size/4 # idk why 4 instead of 2
	_tween = create_tween()
	_tween.tween_property(_piece, "global_position", _pos, _piece_movement_duration)
	_tween.connect("finished", reposition_pieces)
	_tween.connect("finished", _play_piece_place)
	
	game_audio_controller.play_piece_move()
	
	return _tween.finished


func _play_piece_place():
	game_audio_controller.play_piece_place()



func _play_piece_move():
	game_audio_controller.play_piece_move()


func reposition_pieces():
	var _pos: Vector2
	var _piece: Node2D
	var _square_index: int
	
	for i in pieces_x_positions.size():
		_square_index = pieces_x_positions[i]
		if(_square_index != -1):
			_piece = pieces_x[i]
			_pos = squares_highlights[_square_index].global_position + squares_highlights[0].size/4 # idk why 4 instead of 2
			_piece.global_position = _pos
			
	for i in pieces_o_positions.size():
		_square_index = pieces_o_positions[i]
		if(_square_index != -1):
			_piece = pieces_o[i]
			_pos = squares_highlights[_square_index].global_position + squares_highlights[0].size/4 # idk why 4 instead of 2
			_piece.global_position = _pos


func reset_pieces_positions():
	pieces_x_positions = [-1,-1,-1,-1,-1]
	pieces_o_positions = [-1,-1,-1,-1,-1]


func highlight_winning_line(_game_over_results: Array[Vector4]) -> Signal:
	var _winning_lines_squares: Array[Vector2]
	
	# tie
	if(_game_over_results[0][0] == 0):
		game_audio_controller.play_tie_line()
		
		_color = tie_lines.modulate
		_tween = create_tween()
		_tween.tween_property(tie_lines, "modulate", Color(_color.r, _color.g, _color.b, 1), _highlight_fade_duration)
		_tween.tween_property(tie_lines, "modulate", Color(_color.r, _color.g, _color.b, 0), _highlight_fade_duration)
		return _tween.finished
	
	game_audio_controller.play_winning_line()
	
	# get the extremes of the winning lines
	for _game_over_result in _game_over_results:
		# ensure the first number is the lower index
		var _winning_line_squares: Vector2
		_winning_line_squares = Vector2(_game_over_result[1], _game_over_result[3])
		if(_winning_line_squares.x > _winning_line_squares.y):
			_winning_line_squares = Vector2(_game_over_result[3], _game_over_result[1])
		# append
		_winning_lines_squares.append(_winning_line_squares)
	
	# get the lines to highlight
	var _winning_lines: Array[Node2D]
	for _winning_line_squares in _winning_lines_squares:
		match _winning_line_squares:
			Vector2(0,2):
				_winning_lines.append(winning_lines[0])
			Vector2(3,5):
				_winning_lines.append(winning_lines[1])
			Vector2(6,8):
				_winning_lines.append(winning_lines[2])
			Vector2(0,6):
				_winning_lines.append(winning_lines[3])
			Vector2(1,7):
				_winning_lines.append(winning_lines[4])
			Vector2(2,8):
				_winning_lines.append(winning_lines[5])
			Vector2(0,8):
				_winning_lines.append(winning_lines[6])
			Vector2(2,6):
				_winning_lines.append(winning_lines[7])
	
	# highlight the lines
	_tween = create_tween()
	_tween.set_parallel(true)
	for _winning_line in _winning_lines:
		_color = _winning_line.modulate
		_tween.tween_property(_winning_line, "modulate", Color(_color.r, _color.g, _color.b, 1), _highlight_fade_duration)
	_tween.set_parallel(false)
	for _winning_line in _winning_lines:
		_color = _winning_line.modulate
		_tween.tween_property(_winning_line, "modulate", Color(_color.r, _color.g, _color.b, 0), _highlight_fade_duration)
		_tween.set_parallel(true)
	_tween.set_parallel(false)
	
	return _tween.finished
