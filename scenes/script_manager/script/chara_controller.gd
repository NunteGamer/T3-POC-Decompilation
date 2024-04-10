extends Node

@export var debug_print: bool
@export var character_list: Node
@export var script_reader: Node
@export var code_parser: Node
@export var position_parser: Node
@export var camera_controller: Node
@export var charas_container: Node
@export var screen_camera: Camera2D
@export var sfx_controller: Node

var present_charas: Dictionary # chara_name : custom_character
var tween: Tween
var tween_rotation: Tween
var tween_highlight: Tween
var tweens_to_wait: int
var timer: SceneTreeTimer 
var time_to_finish: float

# chara horizontally at center of the screen, with feet under it
const _movement_speed: float = 2500
const _fade_duration = 0.25 # show and hide
const _highlight_fade_duration = 0.25
const _movement_duration = 0.5


func parse_chara(keywords: PackedStringArray, _skip: int):
	time_to_finish = 0
	
	# parse code instructions
	var code_instructions: Dictionary
	code_instructions = _parse_code_instructions(keywords, _skip, false)
	if(debug_print): print("CharaController: Parsing chara with keywords: '" + str(keywords) + "' and skip: " + str(_skip))
	
	# get or create the instance of the character
	var new_chara: bool
	new_chara = _get_chara_instance(code_instructions)
	code_instructions["new_chara"] = new_chara
	
	# if new_chara, make it fadein
	if(new_chara): _show_chara(code_instructions)
	
	# set chara position
	_parse_chara_position(code_instructions)
	
	# set chara depth
	_parse_chara_depth(code_instructions)
	
	# set chara state
	_parse_chara_state(code_instructions)
	
	# set timeout to call _code_finished
	if(debug_print): print("CharaController: Parse ended with time_to_finish: " + str(time_to_finish))
	timer = get_tree().create_timer(time_to_finish)
	timer.connect("timeout", _code_finished)


func rollback_chara(keywords: PackedStringArray, single_line: bool, _skip: int):
	time_to_finish = 0
	
	# parse code instructions
	var code_instructions: Dictionary
	code_instructions = _parse_code_instructions(keywords, _skip, true)
	if(debug_print): print("CharaController: Rollingback chara with keywords: '" + str(keywords) + "' and skip: " + str(_skip))
	
	var new_chara: bool
	new_chara = _get_chara_instance(code_instructions)
	code_instructions["new_chara"] = new_chara
	
	# if new_chara, make it fadein
	if(new_chara): _show_chara(code_instructions)
	
	# set chara state
	_rollback_chara_state(code_instructions)
	
	# set chara depth
	_rollback_chara_depth(code_instructions)
	
	# set chara position
	_rollback_chara_position(code_instructions)
	
	# call finished and either call another line or don't
	if(debug_print): print("CharaController: Rollback parse ended with time_to_finish: " + str(time_to_finish))
	timer = get_tree().create_timer(time_to_finish)
	timer.connect("timeout", Callable(_rollback_finished).bind(single_line))


func _parse_code_instructions(keywords: PackedStringArray, _skip: int, rollback: bool):
	var code_instructions: Dictionary
	code_instructions["chara_name"] = keywords[0]
	
	code_instructions["chara_state"] = ""
	code_instructions["chara_position"] = ""
	code_instructions["chara_depth"] = ""
	code_instructions["behind"] = ""
	if(keywords.size() > 1) : code_instructions["chara_state"] = keywords[1]
	if(keywords.size() > 2) : code_instructions["chara_position"] = keywords[2]
	if(keywords.size() > 3) : code_instructions["chara_depth"] = keywords[3]
	if(keywords.size() > 4) : code_instructions["behind"] = true
	
	# movement will be affected by intant
	# every other minor transition like fades will only be affected by full_instant
	code_instructions["instant"] = false
	code_instructions["full_instant"] = false
	if(_skip == 1):
		code_instructions["instant"] = true
	elif(_skip == 2):
		code_instructions["instant"] = true
		code_instructions["full_instant"] = true
	code_instructions["rollback"] = rollback
	code_instructions["previous_position_line_number"] = 0
	
	return code_instructions


func _parse_chara_state(code_instructions: Dictionary):
	var chara_state: String = code_instructions["chara_state"]
	var chara_name: String = code_instructions["chara_name"]
	
	if(chara_state == "hide"):
		_hide_chara(code_instructions)
	elif(chara_state == "highlight"):
		highlight_speaker(chara_name)
	elif(chara_state != ""):
		if(debug_print): print("CharaController: Set chara '" + chara_name + "' to state '" + chara_state + "'. Current state: '" + present_charas[chara_name].current_state + "'")
		if(code_instructions["new_chara"]):
			call_set_chara(chara_name, chara_state)
		else:
			# if the state is the same it already is in, ignore
			if(chara_state == present_charas[chara_name].current_state): return
			_create_state_clone(code_instructions)


func _rollback_chara_state(code_instructions: Dictionary):
	var chara_name: String = code_instructions["chara_name"]
	
	var previous_state = script_reader.get_previous_chara_state(chara_name)
	if(debug_print): print("CharaController: Previous chara state for chara '" + chara_name + "': '" + previous_state + "'. Current state: '" + present_charas[chara_name].current_state + "'")
	
	# if the state is the same it already is in, ignore
	if(previous_state == present_charas[chara_name].current_state): return
	
	# if previous state is hide, it means the chara is talking offcamera,
	# so no state change is needed
	if(previous_state == "hide"): return
	
	# if previous state is none, it mans the chara didn't exist before that,
	# so it should hide
	if(previous_state == "none"):
		_hide_chara(code_instructions)
		return
	
	#call_set_chara(chara_name, previous_state)
	code_instructions["chara_state"] = previous_state
	_create_state_clone(code_instructions)


func _parse_chara_position(code_instructions: Dictionary):
	var chara_name: String = code_instructions["chara_name"]
	var new_chara_position: String = code_instructions["chara_position"]
	var new_chara: bool = code_instructions["new_chara"]
	var vector_pos: Vector2
	var anchor: float # normalized percentage point of the screen (-1, 1) for the position
	
	# if it's a new chara without specified position, default to center
	if(new_chara && (new_chara_position == "" || new_chara_position == "center")):
		code_instructions["vector_position"] = position_parser.get_center_offset()
		if(debug_print): print("CharaController: Chara '" + chara_name + "' is new, and position is either center or unspecified, so moved there instantly")
		_move_character(code_instructions)
		return
	
	# if chara position is unspecified, maintain current position
	elif(new_chara_position == ""):
		if(debug_print): print("CharaController: Chara '" + chara_name + "' position is unspecified, so current position is mantained")
		return
	
	# parse position to vector
	# get the anchor
	anchor = position_parser.parse_position(new_chara_position)
	# get the y
	vector_pos = position_parser.get_center_offset()
	# get the x, turning the anchor into the actual position
	vector_pos.x = screen_camera.anchor_to_pos(anchor)
	# save the values
	code_instructions["vector_position"] = vector_pos
	present_charas[chara_name].anchor = anchor
	
	# check if chara is already in that position
	if(present_charas[chara_name].position == vector_pos): 
		if(debug_print): print("CharaController: Chara '" + chara_name + "' is already in position '" + new_chara_position + "', so it won't be moved")
		return
		
	# apply position
	if(debug_print): print("CharaController: Applying chara position for chara '" + chara_name + "': " + new_chara_position)
	_manage_movement(code_instructions)


func _rollback_chara_position(code_instructions: Dictionary):
	# get the previous position
	var chara_name: String = code_instructions["chara_name"]
	var previous_position_and_line_number: Array = script_reader.get_previous_chara_position(chara_name)
	var previous_position = previous_position_and_line_number[0]
	code_instructions["previous_position_line_number"] = previous_position_and_line_number[1]
	if(debug_print): print("CharaController: Previous chara position for chara '" + chara_name + "': " + previous_position)
	
	# if previous position is none it means there isn't a previous position (chara is going to hide or can't rollback further),
	# so the chara should remain where it is
	if(previous_position == "none"):
		return
	
	# if the previous position is "", it means it was created with default value
	# and the position should default to center
	if(previous_position == ""):
		previous_position = "center"
	
	# parse the previous position to apply it
	code_instructions["chara_position"] = previous_position
	_parse_chara_position(code_instructions)


func _parse_chara_depth(code_instructions: Dictionary):
	if(code_instructions["chara_depth"] == ""): return # no chara depth specified
	
	var chara_depth: String = code_instructions["chara_depth"]
	var chara_name: String = code_instructions["chara_name"]
	var new_chara_position: String = code_instructions["chara_position"]
	var new_chara: bool = code_instructions["new_chara"]
	var vector_pos: Vector2
	var scale: Vector2
	
	# parse the depth into a scale
	scale = position_parser.parse_depth(chara_depth)

	# check if chara is already in that scale
	if(present_charas[chara_name].scale == scale): 
		if(debug_print): print("CharaController: Chara '" + chara_name + "' is already in depth '" + chara_depth + "', so it won't be scaled.")
		return
	
	# save the scale
	code_instructions["scale"] = scale
	present_charas[chara_name].scale = scale
	
	# apply scale
	if(debug_print): print("CharaController: Applying chara depth for chara '" + chara_name + "': " + chara_depth)
	_scale_character(code_instructions)


func _rollback_chara_depth(code_instructions: Dictionary):
	if(code_instructions["chara_depth"] == ""): return # no chara depth specified
	
	# get the previous position
	var chara_name: String = code_instructions["chara_name"]
	var previous_depth_and_line_number: Array = script_reader.get_previous_chara_depth(chara_name)
	var previous_depth = previous_depth_and_line_number[0]
	code_instructions["previous_depth_line_number"] = previous_depth_and_line_number[1]
	if(debug_print): print("CharaController: Previous chara depth for chara '" + chara_name + "': " + previous_depth)
	
	# if previous depth is none it means the chara is going to hide, so remain as is
	if(previous_depth == "none"):
		return
	
	# if the previous depth is "", it means it was created with deafult depth
	# so revert to default depth
	if(previous_depth == ""):
		previous_depth = "middle"
	
	# parse the previous depth to apply it
	code_instructions["chara_depth"] = previous_depth
	_parse_chara_depth(code_instructions)
	


func _scale_character(code_instructions: Dictionary):
	var chara_instance = present_charas[code_instructions["chara_name"]].instance
	var chara_name: String = code_instructions["chara_name"]
	var scale: Vector2 = code_instructions["scale"]
	var new_chara: bool = code_instructions["new_chara"]
	var rollback: bool = code_instructions["rollback"]
	
	# if chara is already at that scale, return
	if(chara_instance.scale == scale): return
	
	# also change the position y
	var _current_pos: Vector2 = present_charas[chara_name].position
	var _new_pos: Vector2 = _current_pos
	_new_pos.y = position_parser.get_center_offset().y
	# if it will get close, move down
	if(scale.y > 1):
		_new_pos.y += 150 * scale.y
	# if it will get far, move up
	elif(scale.y < 1):
		_new_pos.y -= 100 * scale.y
	
	# if chara is new, apply it instantly
	if(new_chara):
		chara_instance.scale = scale
		return
	
	# if a tween for fade state was created this instruction, appent to it,
	# otherwise create a new one
	if(tween == null || !tween.is_valid() || tween.get_total_elapsed_time() > 0):
		tween = create_tween()
	
	tween.tween_property(chara_instance, "scale", scale, _movement_duration).set_trans(Tween.TRANS_BACK)
	tween.set_parallel(true)
	tween.tween_property(chara_instance, "position", _new_pos, _movement_duration).set_trans(Tween.TRANS_BACK)
	tween.set_parallel(false)
	
	# set wait time to call next line, unless next line is chara movement,
	# in that case, wait 0 so the next movement is done simultanously
	if(rollback && !script_reader.is_previous_line_chara_movement(code_instructions["previous_position_line_number"])):
		time_to_finish += _movement_duration
	elif(!rollback && !script_reader.is_next_line_chara_movement()):
		time_to_finish += _movement_duration
	
	# call draw_chara_on_top with a small delay, unless instant or rollback
	if(code_instructions["instant"] || code_instructions["rollback"]):
		draw_chara_on_top(chara_name, false)
	else:
		draw_chara_on_top(chara_name, true)
	

func _manage_movement(code_instructions: Dictionary):
	var chara_instance = present_charas[code_instructions["chara_name"]].instance
	var vector_pos: Vector2 = code_instructions["vector_position"]
	var new_chara: bool = code_instructions["new_chara"]
	
	# if chara is already there, return
	if(chara_instance.position == vector_pos): return
	
	# highlight all charas
	highlight_all_charas()
	
	# move chara
	var time_until_movement_starts: float
	time_until_movement_starts = _move_character(code_instructions)
	_add_spring_rotation(code_instructions, time_until_movement_starts)
	
	# make camera follow, unless the chara is just appearing
	if(!new_chara): make_camera_follow(code_instructions)
	
	# draw on top
	if(!code_instructions["behind"]):
		draw_chara_on_top(code_instructions["chara_name"], true)
	else:
		_draw_chara_behind(code_instructions["chara_name"])


func _move_character(code_instructions: Dictionary) -> float:
	var chara_name = code_instructions["chara_name"]
	var vector_pos: Vector2 = code_instructions["vector_position"]
	var rollback: bool = code_instructions["rollback"]
	var instant: bool = code_instructions["instant"]
	var new_chara: bool = code_instructions["new_chara"]
	var chara_instance = present_charas[chara_name].instance
	
	present_charas[chara_name].position = vector_pos
	
	# if instant or chara just appeared, don't animate the movement
	if(instant || new_chara):
		chara_instance.position = vector_pos
		if(debug_print): print("CharaController: Applied instant movement")
		return 0
	
	# position
	# if a tween for fade state was created this instruction, appent to it,
	# otherwise create a new one
	var time_until_movement_starts: float
	if(tween == null || !tween.is_valid() || tween.get_total_elapsed_time() > 0):
		tween = create_tween()
	else:
		# if the movement will wait until the state fade ends, so must the rotation
		time_until_movement_starts = _fade_duration
	
	tween.tween_property(chara_instance, "position", vector_pos, _movement_duration).set_trans(Tween.TRANS_BACK)
	# when the tween finishes, call check_chara_anchors to reposition
	# the charas if the windows size has changed during the animation
	tween.finished.connect(check_chara_anchors)
	
	# set wait time to call next line, unless next line is chara movement,
	# in that case, wait 0 so the next movement is done simultanously
	if(rollback && !script_reader.is_previous_line_chara_movement(code_instructions["previous_position_line_number"])):
		time_to_finish += _movement_duration
	elif(!rollback && !script_reader.is_next_line_chara_movement()):
		time_to_finish += _movement_duration
	if(debug_print): print("CharaController: Chara movement tween started. Time to finish increased to: " + str(time_to_finish))
	
	_play_chara_move(time_until_movement_starts)
	
	return time_until_movement_starts


func _play_chara_move(time_until_movement_starts: float):
	await get_tree().create_timer(time_until_movement_starts).timeout
	sfx_controller.play_chara_move()


func _add_spring_rotation(code_instructions: Dictionary, time_until_movement_starts: float):
	var chara_instance = present_charas[code_instructions["chara_name"]].instance
	var vector_pos: Vector2 = code_instructions["vector_position"]
	var instant: bool = code_instructions["instant"]
	
	if(instant): return
	
	# spring effect rotation
	var direction: float = -1 # -1 = moving right
	if(vector_pos.x < chara_instance.position.x): direction = 1
	# higher degrees according to distance
	var distance = abs(chara_instance.position.x - vector_pos.x)
	var magic_number = 200
	var degrees = distance / magic_number
	
	tween_rotation = create_tween()
	const _rotation_duration = _movement_duration * 0.25
	tween_rotation.tween_property(chara_instance, "rotation_degrees", degrees * direction, _rotation_duration).set_trans(Tween.TRANS_QUART).set_delay(time_until_movement_starts)
	tween_rotation.tween_property(chara_instance, "rotation_degrees", 0, _rotation_duration).set_trans(Tween.TRANS_QUART)
	tween_rotation.tween_property(chara_instance, "rotation_degrees", degrees * -direction, _rotation_duration).set_trans(Tween.TRANS_QUART)
	tween_rotation.tween_property(chara_instance, "rotation_degrees", 0, _rotation_duration).set_trans(Tween.TRANS_QUART)
	if(debug_print): print("CharaController: Spring rotation added.")


func make_camera_follow(code_instructions: Dictionary):
	var chara_name: String = code_instructions["chara_name"]
	var rollback: bool = code_instructions["rollback"]
	
	# make camera follow if next speaker is chara
	if(rollback):
		var previous_name: String = script_reader.get_previous_name()
		if(previous_name == chara_name || previous_name == ""):
			camera_controller.approach_to(previous_name)
			if(debug_print): print("CharaController: Moving camera along chara '" + chara_name + "'")
		else:
			if(debug_print): print("CharaController: Previous speaker is '" + previous_name + "' but current chara is '" + chara_name + "', so not moving camera along")
		
	else:
		var next_name: String = script_reader.get_next_name()
		if(next_name == code_instructions["chara_name"] || next_name == ""):
			camera_controller.approach_to(next_name)
			if(debug_print): print("CharaController: Moving camera along chara '" + chara_name + "'")
		else:
			if(debug_print): print("CharaController: Next speaker is '" + next_name + "' but current chara is '" + chara_name + "', so not moving camera along")


func _hide_chara(code_instructions: Dictionary):
	var chara_name: String = code_instructions["chara_name"]
	var full_instant: bool = code_instructions["full_instant"]
	var chara_instance = present_charas[chara_name].instance
	
	var duration = _fade_duration
	if(full_instant): duration = 0
	
	tween = create_tween()
	tween.tween_property(chara_instance, "modulate", Color.TRANSPARENT, duration)
	tween.tween_callback(Callable(_destroy_chara_instance).bind(chara_instance))
	present_charas.erase(chara_name)
	if(debug_print): print("CharaController: Chara '" + chara_name + "' removed from present_charas.")
	if(code_instructions["rollback"]):
		if(debug_print): print("CharaController: Hide fade started. Time to finish not increased, since it's rollback.")
	else:
		time_to_finish += duration
		if(debug_print): print("CharaController: Hide fade started. Time to finish increased to: " + str(time_to_finish))


func _destroy_chara_instance(chara_instance):
	chara_instance.queue_free()


func _get_chara_instance(code_instructions: Dictionary) -> bool: # returns if new_chara
	var chara_name: String = code_instructions["chara_name"]
	
	# if chara instance exists
	if(present_charas.has(chara_name)):
		if(debug_print): print("CharaController: Chara instance of '" + chara_name + "' exists.")
		return false
	
	# if chara instance doesn't exist: instantiate it
	var custom_character: CustomCharacter = character_list.get_character(chara_name)
	if(custom_character.code_name == "dummy"):
		print_debug("ERROR: Character '" + chara_name +"' is not on character_list.")
	var chara_scene: PackedScene = custom_character.packed_scene
	
	# instantiate chara
	var chara_instance
	chara_instance = chara_scene.instantiate()
	present_charas[chara_name] = custom_character
	present_charas[chara_name].instance = chara_instance
	charas_container.add_child.call_deferred(chara_instance)
	present_charas[chara_name].svp_container = chara_instance.get_child(0)
	present_charas[chara_name].tint_container = chara_instance.get_child(0).get_child(0)
	present_charas[chara_name].script_container = chara_instance.get_child(0).get_child(0).get_child(0)
	present_charas[chara_name].anchor = 0
	call_set_chara(chara_name, "")
	if(debug_print): print("CharaController: Chara '" + chara_name + "' instantiated")
	return true


func call_set_chara(chara_name: String, chara_state: String):
	# invisibilize the sprites, then call set_chara to make visible the required ones
	make_children_invisible(present_charas[chara_name].script_container)
	present_charas[chara_name].script_container.set_chara(chara_state)
	present_charas[chara_name].current_state = chara_state


func make_children_invisible(node):
	# make every children on the node tree invisible
	for child in node.get_children():
		if("visible" in child):
			child.visible = false
		make_children_invisible(child)


func _create_state_clone(code_instructions: Dictionary): # create a subviewportcontainer clone so it can fadein over the old state one
	var chara_name = code_instructions["chara_name"]
	var custom_character: CustomCharacter = character_list.get_character(chara_name)
	var chara_scene: PackedScene = custom_character.packed_scene
	
	# instantiate chara
	var new_chara_instance
	new_chara_instance = chara_scene.instantiate()
	
	# get the new subviewport and subviewportcontainer
	var subviewport: SubViewport = new_chara_instance.get_child(0).get_child(0).get_child(0)
	var tint_container: SubViewportContainer = new_chara_instance.get_child(0).get_child(0)
	var subviewportcontainer: SubViewportContainer = new_chara_instance.get_child(0)
	
	# reparent the subviewports in the old chara instance (to keep its position and rotation)
	subviewportcontainer.get_parent().remove_child(subviewportcontainer)
	present_charas[chara_name].instance.add_child.call_deferred(subviewportcontainer)
	var old_subviewportcontainer: SubViewportContainer = present_charas[chara_name].svp_container
	
	# copy the tint
	tint_container.modulate = present_charas[chara_name].tint_container.modulate
	
	# substitute the references with the new containers
	present_charas[chara_name].svp_container = subviewportcontainer
	present_charas[chara_name].tint_container = tint_container
	present_charas[chara_name].script_container = subviewport
	
	# change the state of the newly created chara
	call_set_chara(chara_name, code_instructions["chara_state"]) # set default state
	
	# make the new subviewportcontainer fadein over the old one
	var wait_time: float = _fadein_state_clone(code_instructions)
	if(debug_print): print("CharaController: Chara '" + chara_name + "' state clone created. Time to finish increased to: " + str(time_to_finish))
	
	# when the fadein ends, destroy the old subviewportcontainer and the new empty instance (we took the svc from it)
	await get_tree().create_timer(wait_time + _fade_duration).timeout
	if(old_subviewportcontainer != null): old_subviewportcontainer.queue_free()


func _fadein_state_clone(code_instructions: Dictionary) -> float: # returns the wait time until the movement ends and the fadein starts
	var chara_name: String = code_instructions["chara_name"]
	var rollback = code_instructions["rollback"]
	var full_instant = code_instructions["full_instant"]
	var chara_container = present_charas[chara_name].svp_container
	
	# make character transparent to fade in from there
	chara_container.modulate = Color.TRANSPARENT
	
	var duration = _fade_duration
	if(full_instant): duration = 0
	
	# append to the movement tween if it was declared this instruction, so the state fade comes after the movement,
	# otherwise create a new tween or it will thrown an error
	# if rollback, also create a new one so it doesn't mix with other character's tweens
	if(tween != null && tween.is_valid() && tween.get_total_elapsed_time() == 0 && !rollback):
		# add to the queue so they play after the movement ends
		tween.set_parallel(false)
		tween.tween_property(chara_container, "modulate", Color.TRANSPARENT, 0)
		tween.tween_property(chara_container, "modulate", Color.WHITE, duration)
		tween.set_parallel(true)

		time_to_finish += duration
		return _movement_duration
	
	# if the chara is not moving, play instantly
	tween = create_tween()
	tween.tween_property(chara_container, "modulate", Color.TRANSPARENT, 0)
	tween.tween_property(chara_container, "modulate", Color.WHITE, duration)
	time_to_finish += duration
	return 0


func _show_chara(code_instructions: Dictionary):
	var chara_name: String = code_instructions["chara_name"]
	var instant: bool = code_instructions["instant"]
	var chara_container = present_charas[chara_name].svp_container
	
	# make character transparent to fade in from there
	chara_container.modulate = Color.TRANSPARENT
	
	# no fade
	if(instant):
		chara_container.modulate = Color.WHITE
		if(debug_print): print("CharaController: Chara '" + chara_name + "' shown instantly")
		return
	
	# fade
	tween = create_tween()
	tween.tween_property(chara_container, "modulate", Color.WHITE, _fade_duration)
	time_to_finish += _fade_duration
	if(debug_print): print("CharaController: Chara '" + chara_name + "' fadein started. Time to finish increased to: " + str(time_to_finish))


func skip():
	var skipped: bool
	if(tween != null):
		skipped = true
		if(tween != null): tween.custom_step(999)
		if(tween_rotation != null): tween_rotation.custom_step(999)
		if(tween_highlight != null): tween_highlight.custom_step(999)
	if(timer != null): 
		skipped = true
		timer.set_time_left(0)
	if(debug_print && skipped): print("CharaController: Chara action skipped")


func _code_finished():
	if(debug_print): print("CharaController: Chara action finished")
	code_parser.code_finished()


func _rollback_finished(single_line: bool):
	if(debug_print): print("CharaController: Rollback action finished. Single line: " + str(single_line))
	code_parser.rollback_finished(single_line)


func get_present_charas() -> Dictionary:
	return present_charas


func get_present_chara(_name: String) -> CustomCharacter:
	for chara_name in present_charas:
		if(chara_name == _name):
			return present_charas[chara_name]
	return null


func get_chara_position(chara_name: String) -> Vector2:
	# if the chara is not present, return as a procy for a null value
	if(!present_charas.has(chara_name)): return Vector2(9999, 9999)
	
	return present_charas[chara_name].instance.position


func highlight_speaker(chara_name: String):
	if(debug_print): print("CharaController: Highlight chara '" + chara_name + "'")
	
	# if the chara is not present, return
	if(!present_charas.has(chara_name)): return
	
	# gray out all other present charas
	for c_name in present_charas:
		if(c_name == chara_name): continue
		tween_highlight = create_tween()
		tween_highlight.tween_property(present_charas[c_name].svp_container, "modulate", Color(0.9, 0.9, 0.9, 1), _highlight_fade_duration)
	
	# highlight the speaking chara if it wasn't already
	tween_highlight = create_tween()
	if(present_charas[chara_name].svp_container.modulate != Color.WHITE):
		tween_highlight.tween_property(present_charas[chara_name].svp_container, "modulate", Color.WHITE, _highlight_fade_duration)
		
	# also highlight with scale bounce
	var _scale: Vector2 = Vector2(1, 1)
	tween_highlight.set_parallel(true)
	tween_highlight.tween_property(present_charas[chara_name].svp_container, "scale", _scale * 1.02, _highlight_fade_duration/2).set_ease(Tween.EASE_IN_OUT)
	tween_highlight.set_parallel(false)
	tween_highlight.tween_property(present_charas[chara_name].svp_container, "scale", _scale, _highlight_fade_duration/2).set_ease(Tween.EASE_IN_OUT)
	
	# draw chara on top
	draw_chara_on_top(chara_name, false)
	
	sfx_controller.play_chara_highlight()


func highlight_all_charas():
	if(debug_print): print("CharaController: Highlight all charas")
	for chara_name in present_charas:
		tween_highlight = create_tween()
		tween_highlight.tween_property(present_charas[chara_name].svp_container, "modulate", Color.WHITE, _highlight_fade_duration)


func draw_chara_on_top(chara_name: String, _wait: bool):	
	# wait a bit if changing depth so the effect looks nice
	if(_wait): await get_tree().create_timer(0.25).timeout
	
	if(present_charas.has(chara_name)):
		if(debug_print): print("CharaController: Chara '" + chara_name + "' draw on top")
		
		# lower the order of all the charas at the same or lower scale
		var _highest_order_at_this_scale: int = -9999
		var _lowest_order_at_next_scale: int = 0
		for chara in present_charas:
			if(chara == chara_name): continue
			# if chara has equal or lower scale
			if(present_charas[chara].scale.x <= present_charas[chara_name].scale.x):
				present_charas[chara].order -= 1
				# update _highest_order_at_this_scale
				if(present_charas[chara].order > _highest_order_at_this_scale):
					_highest_order_at_this_scale = present_charas[chara].order
			# also save the lowest order in case all of the charas 
			elif(present_charas[chara].order < _lowest_order_at_next_scale):
				_lowest_order_at_next_scale = present_charas[chara].order
			
		# set the order as +1 the highest order of the rest
		if(_highest_order_at_this_scale == -9999):
			_highest_order_at_this_scale = _lowest_order_at_next_scale - 2
		present_charas[chara_name].order = _highest_order_at_this_scale + 1
		
		_draw_charas_in_order()
		
	else:
		if(debug_print): print("CharaController: Chara '" + chara_name + "' is not presnt, so it wasn't drawn on top")


func _draw_chara_behind(chara_name: String):
	var _lowest_order_at_this_scale: int = 99999
	for chara in present_charas:
		if(chara == chara_name): continue
		# if chara has lower scale
		if(present_charas[chara].scale.x < present_charas[chara_name].scale.x):
			# lower one point
			present_charas[chara].order -= 1
		# if chara has same scale
		elif(present_charas[chara].scale.x == present_charas[chara_name].scale.x):
			#save the lower scale
			if(present_charas[chara].order < _lowest_order_at_this_scale):
				_lowest_order_at_this_scale = present_charas[chara].order
	# apply order
	present_charas[chara_name].order = _lowest_order_at_this_scale - 1
	
	_draw_charas_in_order()


func _draw_charas_in_order():
	# make a list of all the present characters ordered by their order
	var _ordered_chara_list: Array[CustomCharacter]
	for p_chara in present_charas:
		var _ordered: bool
		for i in _ordered_chara_list.size():
			if(_ordered_chara_list[i].order > present_charas[p_chara].order):
				_ordered_chara_list.insert(i, present_charas[p_chara])
				_ordered = true
		if(!_ordered):
			_ordered_chara_list.append(present_charas[p_chara])
	
	# redraw all the character on their order
	for o_chara in _ordered_chara_list:
		charas_container.remove_child.call_deferred(o_chara.instance)
		charas_container.add_child.call_deferred(o_chara.instance)


func check_chara_anchors():
	charas_container.reposition_charas()


func reset_scene():
	for chara_name in present_charas:
		present_charas[chara_name].instance.queue_free()
	present_charas.clear()


func wait_for_tweens():
	tweens_to_wait = 0
	if(tween != null && tween.is_running()):
		tween.connect("finished", _tween_finished)
		tweens_to_wait += 1
	if(tween_rotation != null && tween.is_running()):
		tween_rotation.connect("finished", _tween_finished)
		tweens_to_wait += 1
	if(tween_highlight != null && tween.is_running()):
		tween_highlight.connect("finished", _tween_finished)
		tweens_to_wait += 1
	if(debug_print): print("CharaController: Waiting for " + str(tweens_to_wait) + " tweens.")
	if(tweens_to_wait == 0):
		_tween_finished()


func _tween_finished():
	tweens_to_wait -= 1
	if(debug_print): print("CharaController: 1 tween finished. Remaining: " + str(tweens_to_wait))
	if(tweens_to_wait > 0): return
	if(debug_print): print("CharaController: Wait for tweens finished")
	code_parser.code_finished()
