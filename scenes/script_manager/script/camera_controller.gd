extends Node


@export var camera: Camera2D
@export var screen_camera: Camera2D
@export var main_game_controller: Node
@export var code_parser: Node
@export var bg_container: Node2D
@export var chara_controller: Node
@export var script_reader: Node
var original_pos: Vector2
var tween: Tween
const _approach_factor: float = 20 # magic number
var timer: SceneTreeTimer

var _anchor: float
var _pan: bool # pan towards next position (false = jump instantly)
var _auto: bool # move towards the speaker
var _zoom: bool # is zoomed
var _await: SceneTreeTimer

func _ready():
	original_pos = camera.position
	reset_camera_mode()


func reset_camera_mode():
	_pan = true
	_auto = true


func approach_to(chara_name: String):
	if(!_auto): return
	
	var duration: float
	if(_pan): duration = 0.25
	
	var final_pos: Vector2
	var distance_difference: float
	
	# if on game mode, fully center instead of just approaching
	var _actual_approach_factor: float = _approach_factor
	if(main_game_controller.get_mode() == 1):
		_actual_approach_factor = 1

	# calculate how much to move
	if(_zoom):
		var chara: CustomCharacter = chara_controller.get_present_chara(chara_name)
		if(chara == null):
			push_error("ERROR: Camera Controller: Chara to zoom in is not present: '" + chara_name + "'")
		final_pos = chara.script_container.face_marker.global_position - camera.offset
	else:
		var chara_pos: Vector2 = chara_controller.get_chara_position(chara_name)
		if(chara_pos != Vector2(9999, 9999)): # if this vector was returned, the chara is not present
			# distance between center and chara_pos
			distance_difference = abs(original_pos.x - chara_pos.x)
			var approach_distance: float = distance_difference/_actual_approach_factor
			if(chara_pos.x < original_pos.x):
				approach_distance *= -1
			final_pos =  Vector2(original_pos.x + approach_distance, original_pos.y)
	
	# if the camera is already there, return
	distance_difference = abs(final_pos.x - camera.position.x)
	if(distance_difference == 0): return
	
	_anchor = screen_camera.pos_to_anchor(final_pos.x)
	
	# move
	tween = get_tree().create_tween()
	tween.tween_method(_tween_camera_position, camera.position, final_pos, duration)
	
	# motion blur the background
	#background_container.set_motion_blur(20)
	#await tween.finished
	#background_container.set_motion_blur(0)


func _tween_camera_position(_new_position: Vector2):
	# this must be done manual instead of using tween_property in order
	# to keep all the nodes in sync
	camera.position = _new_position
	camera.force_update_scroll() # fix for godot bug
	bg_container.set_parallax_position()


func parse_camera(keywords: PackedStringArray):
	if(keywords[0] == "chara" && keywords.size() > 1):
		approach_to(keywords[1])
	else:
		_parse_camera_mode(keywords)


func _parse_camera_mode(keywords: PackedStringArray):
	if(keywords.size() < 2):
		push_error("ERROR: CameraController: Camera mode instruction lacks parameters: '" + str(keywords) + "'")
		return
	if(keywords[0] == "pan"):
		if(keywords[1] == "0"):
			_pan = false
		else:
			_pan = true
		return
	
	if(keywords[0] == "auto"):
		if(keywords[1] == "0"):
			_auto = false
		else:
			_auto = true
		return


func rollback_camera(keywords: PackedStringArray):
	if(keywords[0] == "chara"):
		pass
	else:
		_rollback_camera_mode(keywords)


func _rollback_camera_mode(keywords: PackedStringArray):
	var previous_keywords: PackedStringArray = script_reader.get_previous_double_code("camera",keywords[0])
	if(previous_keywords.size() == 0):
		# there is no previous camera instruction for this mode, so the previous one was the default
		if(keywords[0] == "pan"):
			previous_keywords.append("pan")
			previous_keywords.append("1")
		elif(keywords[0] == "auto"):
			previous_keywords.append("auto")
			previous_keywords.append("1")
	else:
		previous_keywords.remove_at(0)
	_parse_camera_mode(previous_keywords)


func parse_zoom(keywords: PackedStringArray, rollback: bool):
	_zoom = true
	
	var duration: float
	if(_pan): duration = 0.25
	var final_pos: Vector2
	var zoom: Vector2 = Vector2(1.5,1.5)
	var chara_name: String = keywords[0]
	if(chara_name == "reset"):
		_zoom = false
		zoom = Vector2(1,1)
		final_pos = Vector2.ZERO
	else:
		var chara: CustomCharacter = chara_controller.get_present_chara(chara_name)
		if(chara == null):
			push_error("ERROR: Camera Controller: Chara to zoom in is not present: '" + chara_name + "'")
		final_pos = chara.script_container.face_marker.global_position - camera.offset
	
	_anchor = screen_camera.pos_to_anchor(final_pos.x)
	
	tween = get_tree().create_tween()
	tween.tween_method(_tween_camera_global_position, camera.global_position, final_pos, duration)
	tween.set_parallel(true)
	tween.tween_method(_tween_camera_zoom, camera.zoom, zoom, duration)
	await tween.finished
	if(rollback):
		code_parser.rollback_finished(false)
	else:
		code_parser.code_finished()


func rollback_zoom():
	var keywords: PackedStringArray = script_reader.get_previous_code("zoom")
	if(keywords.size() == 0):
		keywords.append("reset")
	else:
		keywords.remove_at(0)
	parse_zoom(keywords, true)


func _tween_camera_global_position(_new_position: Vector2):
	# this must be done manual instead of using tween_property in order
	# to keep all the nodes in sync
	camera.global_position = _new_position


func _tween_camera_zoom(_new_zoom: Vector2):
	# this must be done manual instead of using tween_property in order
	# to keep all the nodes in sync
	camera.zoom = _new_zoom
	bg_container.set_parallax_position()


func parse_screenshake(keywords: PackedStringArray):
	var _duration: float = 1
	var _intensity: int = 1
	var _await_time: float = 0
	
	var _duration_set: bool
	for keyword in keywords:
		# keyword is a number, must be duration or intensity
		if(keyword.is_valid_float()):
			if(!_duration_set):
				_duration_set = true
				_duration = keyword.to_float()
			else:
				_intensity = keyword.to_int()
		elif(keyword == "wait"):
			_await_time = _duration
		elif(keyword == "hit"):
			_duration = 0.2
			_intensity = 3
	
	# call shake
	camera.shake(_duration, _intensity)
	
	# call code_finished
	if(_await_time > 0):
		_await = get_tree().create_timer(_await_time)
		await _await.timeout
	code_parser.code_finished()


func skip():
	if(tween != null): tween.custom_step(999)
	camera.cancel_screenshake()
	if(_await != null):
		_await.time_left = 0


func reposition_camera():
	var pos: Vector2 = Vector2(screen_camera.anchor_to_pos(_anchor), camera.position.y)
	camera.position = pos
	camera.force_update_scroll() # fix for godot bug
	
