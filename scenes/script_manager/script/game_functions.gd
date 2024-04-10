extends Node

@export var main_game_controller: Node
@export var script_manager: Node
@export var script_reader: Node
@export var main_scene: Node
@export var screen_camera: Camera2D
@export var code_parser: Node
@export var flag_controller: Node
var _T3_scene: PackedScene = preload("res://scenes/game/T3_scene.tscn")
var _game_scene_instance: Node
var _board_slidein_duration: float = 0.5

var _tween: Tween
signal _game_finished_showing


func parse_game(keywords: PackedStringArray, skip: int):
	# if the is no second keyword, append an empty one
	
	match keywords[0]:
		"show":
			_manage_show_game(keywords[1])
		"set":
			_manage_set_game(keywords[1], true)
		"ai":
			_set_ai(keywords[1])
			end(false)
		"start":
			_manage_start_game()
		"hide":
			hide_game()
		"end":
			end(false)


func _manage_start_game():
	flag_controller.reset_game_flags()
	_game_scene_instance.game_initializer.start_game()
	end_discontinued()
	script_manager.set_vn_mode(false)
	


func _manage_show_game(_game_id: String):
	# call end when the board finishes appearing
	connect("_game_finished_showing", Callable(end).bind(false), CONNECT_ONE_SHOT)
	
	_instantiate_game_scene()
	_manage_set_game(_game_id, false)
	_show_game()


func _manage_set_game(_game_id: String, _call_end_on_finished: bool):
	_initialize_game(_game_id, _call_end_on_finished)
	_game_scene_instance.condition_controller.parse_full_conditions(script_reader.get_game_conditions())



func _instantiate_game_scene():
	# instantiate game scene
	_game_scene_instance = _T3_scene.instantiate()
	# set the reference to this script
	_game_scene_instance.game_functions = self


func _initialize_game(_game_id: String, _call_end_on_finished: bool):
	var _game_initializer: Node = _game_scene_instance.game_initializer
	
	# set the game settings
	match _game_id:
		"poc_daisy":
			_game_initializer.set_player_team(2)
			_game_initializer.set_ai_profile("poc_daisy")
			_game_initializer.set_sets(3)
			_game_initializer.set_handicap(true, 1)
		"poc_nikola":
			_game_initializer.set_player_team(1)
			_game_initializer.set_ai_profile("poc_nikola")
			_game_initializer.set_sets(3)
		"poc_ingrid":
			_game_initializer.set_player_team(2)
			_game_initializer.set_ai_profile("poc_ingrid")
			_game_initializer.set_sets(3)
		
	_initial_reset_board.call_deferred(_call_end_on_finished)
	
	

func _initial_reset_board(_call_end_on_finished: bool):
	var _board_reseted: Signal = _game_scene_instance.game_initializer.apply_initial_board_configuration()
	if(_call_end_on_finished): _board_reseted.connect(Callable(end).bind(false))


func _set_ai(profile: String):
	_game_scene_instance.game_initializer.set_ai_profile(profile)


func _show_game():
	# add instance to scene
	screen_camera.add_child(_game_scene_instance)
	
	# set the screen_camera's reference to the game scene
	screen_camera.game_scene = _game_scene_instance
	
	# stop centering the viewports and such until the transition is finished
	main_game_controller.change_to_transition_mode()
	
	_tween = create_tween()
	_tween.set_parallel(true)
	var _final_pos: Vector2
	# tween the board position towards the final centered position
	_final_pos = screen_camera.position_game_scene(true, false)
	_tween.tween_property(_game_scene_instance.T3_scene_texture_rect, "position", _final_pos, _board_slidein_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# also move the vn svc to the side
	_final_pos = screen_camera.reposition_screen_svc(true)
	_tween.tween_property(screen_camera.screen_svc, "position", _final_pos, _board_slidein_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# also reposition the UI
	_final_pos = screen_camera.reposition_ui(true)
	_tween.set_parallel(true)
	_tween.tween_property(screen_camera.ui_layer, "offset", _final_pos, _board_slidein_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.set_parallel(false)
	
	# wait for the tween to finish
	await _tween.finished
	# set the position again in case the window was resized
	screen_camera.position_game_scene(false, false)
	# change game mode so the two scenes get centered appropiately on screen size change
	main_game_controller.change_to_game_mode()
	
	emit_signal("_game_finished_showing")


func hide_game():
	# stop centering the viewports and such until the transition is finished
	main_game_controller.change_to_transition_mode()
	
	_tween = create_tween()
	_tween.set_parallel(true)
	var _final_pos: Vector2
	
	# tween the board position towards the final hidden position
	_final_pos = screen_camera.position_game_scene(true, true)
	_tween.tween_property(_game_scene_instance.T3_scene_texture_rect, "position", _final_pos, _board_slidein_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# also move the vn svc to the center
	_final_pos = screen_camera.center_screen_svc(true)
	_tween.tween_property(screen_camera.screen_svc, "position", _final_pos, _board_slidein_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# also reposition the UI
	_final_pos = screen_camera.center_ui(true)
	_tween.set_parallel(true)
	_tween.tween_property(screen_camera.ui_layer, "offset", _final_pos, _board_slidein_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.set_parallel(false)
	
	# schedule destroy game instance
	_tween.connect("finished", _destroy_game_instance)
	
	# wait for the tween to finish
	await _tween.finished
	# set the position again in case the window was resized
	screen_camera.position_game_scene(true, false)
	# change vn mode so the two scenes get centered appropiately on screen size change
	main_game_controller.change_to_vn_mode()
	
	script_manager.set_vn_mode(true)
	end(false)
	


func _destroy_game_instance():
	_game_scene_instance.queue_free()


func end(rollback: bool):
	if(rollback):
		code_parser.rollback_finished(false)
	else:
		code_parser.code_finished()


func end_discontinued():
	code_parser.code_finished_discontinued()


func call_goto_id(_id: String):
	script_reader.goto_id(_id)
	script_manager.set_vn_mode(true)
	


func manage_endwhen():
	_game_scene_instance.game_controller.set_game_running(true)
	script_manager.set_vn_mode(false)
	end_discontinued()


func manage_game_over():
	var _id: String = script_reader.get_next_double_code_id("game", "end")
	if(_id == ""):
		push_error("GameFunctions: There is no game:end")
		return
	
	var _id_line_number: int = script_reader._get_id_line_number(_id)
	script_reader.set_line_number(_id_line_number)
	script_manager.set_vn_mode(true)
	script_reader.read_next_line()


func get_game_scene_instance() -> Node:
	return _game_scene_instance


func get_flag_list() -> Node:
	return flag_controller.flag_list
