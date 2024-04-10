extends Node

@export var _print_debug: bool
@export var script_manager: Node
@export var script_reader: Node
@export var chara_controller: Node
@export var bg_controller: Node
@export var fade_controller: Node
@export var camera_controller: Node
@export var game_functions: Node
@export var custom_functions: Node
@export var flag_controller: Node
@export var audio_controller: Node

var timer: SceneTreeTimer
var _code_running: bool

# a dialogue with a continue tag has been rollbacked.
# flag it so the next rollback skips the line (or else the <continue> will move the line number forward)
var rollbacking_continue_dialogue: bool # checked and falsified by script_reader

func parse_code(code: String, skip: int):
	_code_running = true
	
	# split code into keywords
	var keywords: PackedStringArray = code.split(":")
	var function = keywords[0]
	
	# patch so if you rollback right after a <continue> dialogue, that dialogue is skipped, not repeated once first
	if(script_reader.is_text_typing()):
		rollbacking_continue_dialogue = true
	
	# call function parsers
	if(function == "chara"):
		keywords.remove_at(0)
		if(_print_debug): print("CodeParser: Parsing chara keywords '" + str(keywords) + "' with skip: " + str(skip))
		chara_controller.parse_chara(keywords, skip)
		
	elif(function == "bg"):
		keywords.remove_at(0)
		if(_print_debug): print("CodeParser: Parsing bg keywords '" + str(keywords) + "' with skip: " + str(skip))
		bg_controller.parse_bg(keywords, skip)
	
	elif(function == "fadein" || function == "fadeout"):
		if(_print_debug): print("CodeParser: Parsing fade")
		
		# parse skip
		var instant: bool
		if(skip > 0): instant = true
		# if a previous action was being skipped, stop the skip here, since this is a different action
		if(function == "fadein" && skip == 1):
			instant = false
			script_reader.end_skip()
		
		fade_controller.parse_fade(keywords, instant)
		
		# if the fade was being skipped, stop the skip after it finishes
		if(function == "fadeout" && skip == 1):
			script_reader.end_skip()
		
	elif(function == "wait"):
		# if param is "finished", call for wait until chara_controller tweens finish
		if(keywords[1] == "finish"):
			if(skip > 0):
				code_finished()
				return
			chara_controller.wait_for_tweens()
			return
	
		# wait in seconds
		var duration: float = float(keywords[1])
		if(skip > 0): duration = 0
		if(_print_debug): print("CodeParser: Parsing wait: " + str(duration) + ". Skip: " + str(skip))
		timer = get_tree().create_timer(duration)
		timer.connect("timeout", code_finished)
		
	elif(function == "camera"):
		keywords.remove_at(0)
		if(_print_debug): print("CodeParser: Parsing camera '" + str(keywords) + "' with skip: " + str(skip))
		camera_controller.parse_camera(keywords)
		code_finished()
		
	elif(function == "zoom"):
		keywords.remove_at(0)
		if(_print_debug): print("CodeParser: Parsing zoom '" + str(keywords) + "' with skip: " + str(skip))
		camera_controller.parse_zoom(keywords, false)
		
	elif(function == "screenshake" && skip == 0):
		keywords.remove_at(0)
		if(_print_debug): print("CodeParser: Parsing screenshake '" + str(keywords) + "' with skip: " + str(skip))
		camera_controller.parse_screenshake(keywords)
		
	elif(function == "goto"):
		if(_print_debug): print("CodeParser: Parsing goto '" + str(keywords[1]) + "'")
		_code_running = false
		script_reader.goto_id(keywords[1])
	
	elif(function == "script"):
		if(_print_debug): print("CodeParser: Parsing jump to script '" + str(keywords[1]) + "'")
		script_reader.reset_scene()
		script_manager.run_script(keywords[1])
		
	elif(function == "game"):
		if(_print_debug): print("CodeParser: Parsing game function with keywords '" + str(keywords) + "'")
		keywords.remove_at(0)
		game_functions.parse_game(keywords, skip)
		
	elif(function == "func"):
		if(_print_debug): print("CodeParser: Parsing custom function with keywords '" + str(keywords) + "'")
		keywords.remove_at(0)
		custom_functions.parse_function(keywords, skip, false)
		
	elif(function == "audio"):
		if(_print_debug): print("CodeParser: Parsing audio with keywords '" + str(keywords) + "'")
		keywords.remove_at(0)
		audio_controller.parse_audio(keywords)
		code_finished()
		
	elif(function == "if"):
		if(_print_debug): print("CodeParser: Parsing if with keywords '" + str(keywords) + "'")
		flag_controller.parse_flag(keywords)
		
	elif(function == "flag"):
		if(_print_debug): print("CodeParser: Parsing flag with keywords '" + str(keywords) + "'")
		flag_controller.parse_flag(keywords)
		code_finished()
		
	elif(function == "endif"):
		if(_print_debug): print("CodeParser: Endif.")
		code_finished()
		
	elif(function == "when"):
		# when consition was presumably met, read the next line
		code_finished()
		
	elif(function == "endwhen"):
		if(_print_debug): print("CodeParser: Calling GameFunctions to manage endwhen.")
		game_functions.manage_endwhen()
		
	elif(function == "stop"):
		if(script_reader.continues == 0):
			if(_print_debug): print("CodeParser: Stopping reading (stop tag).")
			code_finished_discontinued()
			script_reader.lines_finished_reading()
		# if there are continues in queue, call code_finished() to read the next line
		else:
			if(_print_debug): print("CodeParser: Not stopped reading because there are continues in queue.")
			script_reader.continues -= 1
			code_finished()
		
	else:
		push_error("CodeParser: Unknow function: '" + function + "'")






func rollback_code(code: String, single_line: bool, skip: int):
	_code_running = true
	
	# split code into keywords
	var keywords: PackedStringArray = code.split(":")
	var function = keywords[0]
	
	# call function parsers
	if(function == "chara"):
		keywords.remove_at(0)
		if(_print_debug): print("CodeParser: Rollingback chara keywords '" + str(keywords) + "' with skip: " + str(skip) + ", and single_line: " + str(single_line))
		chara_controller.rollback_chara(keywords, single_line, skip)
		
	elif(function == "bg"):
		keywords.remove_at(0)
		if(_print_debug): print("CodeParser: Rollingback bg keywords '" + str(keywords) + "' with skip: " + str(skip))
		bg_controller.rollback_bg(keywords, skip)
		
	elif(function == "fadein" || function == "fadeout"):
		if(_print_debug): print("CodeParser: Rollingback fade")
		
		# parse skip
		var instant: bool
		if(skip > 0): instant = true
		# if a previous action was being skipped, stop the skip here, since this is a different action
		if(function == "fadeout" && skip == 1):
			instant = false
			script_reader.end_skip()
		
		fade_controller.rollback_fade(keywords, instant)
		
		# if the fade was being skipped, stop the skip after it finishes
		if(function == "fadein" && skip == 1):
			script_reader.end_skip()
		
	elif(function == "wait"):
		# do nothing, keep reading backwards
		if(_print_debug): print("CodeParser: Ignoring wait because rollback")
		rollback_finished(false)
		
	elif(function == "camera"):
		keywords.remove_at(0)
		if(_print_debug): print("CodeParser: Rollingback camera '" + str(keywords) + "' with skip: " + str(skip))
		camera_controller.rollback_camera(keywords)
		rollback_finished(false)
		
	elif(function == "zoom"):
		keywords.remove_at(0)
		if(_print_debug): print("CodeParser: Rollingback zoom '" + str(keywords) + "' with skip: " + str(skip))
		camera_controller.rollback_zoom()
		
	elif(function == "screenshake"):
		# do nothing, keep reading backwards
		if(_print_debug): print("CodeParser: Ignoring screenshake because rollback")
		rollback_finished(false)
		
	elif(function == "goback"):
		if(_print_debug): print("CodeParser: Parsing goback to '" + str(keywords[1]))
		_code_running = false
		script_reader.goback_id(keywords[1])
		
	elif(function == "func"):
		if(_print_debug): print("CodeParser: Rollingback custom function with keywords '" + str(keywords) + "'")
		keywords.remove_at(0)
		custom_functions.parse_function(keywords, skip, true)
		
	elif(function == "if" || function ==  "endif"):
		# do nothing, keep reading backwards
		if(_print_debug): print("CodeParser: Ignoring if/endif because rollback")
		rollback_finished(false)
		
	elif(function == "flag"):
		if(_print_debug): print("CodeParser: Rollingback flag with keywords '" + str(keywords) + "'")
		keywords.remove_at(0)
		flag_controller.rollback_flag(keywords)
		
	elif(function == "stop"):
		# if we have not rollbacked the continue dialogue yet, all the code between here and that line should be skipped
		# (it will be called by the <continues> on that line)
		if(!rollbacking_continue_dialogue):
			if(_print_debug): print("CodeParser: Stop tag. Jumping to previous dialogue ID.")
			var continue_dialogue_id: String = script_reader.get_previous_dialogue_id()
			_code_running = false
			script_reader.change_line_number_to_id(continue_dialogue_id)
			script_reader.read_line(true)
			rollbacking_continue_dialogue = true
		# if rollbacking_continue_dialogue is true, it means that dialogue line has already been rollbacked
		# so next time, it should be skipped, but the lines between this stop and that dialogue should be called
		# so, for now, do nothing
		else:
			if(_print_debug): print("CodeParser: Ignoring stop because rollback and rollbacking_continue_dialogue")
			rollback_finished(false)
		
	else:
		if(_print_debug): print("CodeParser: Rollingback stopped. Code: '" + str(keywords) + "'")
		rollback_finished(true)


func code_finished():
	if(_print_debug): print("CodeParser: Code action finished. Now will read next line. -------------------------------------")
	_code_running = false
	script_reader.read_next_line()


func code_finished_discontinued():
	if(_print_debug): print("CodeParser: Code action finished. Won't continue. -------------------------------------")
	_code_running = false

# single_line = "should it keep reading backwards after it's finished or was this just calling for a single line?"
func rollback_finished(single_line: bool):
	_code_running = false
	if(single_line):
		if(_print_debug): print("CodeParser: Rollback action finished. -------------------------------------")
	else:
		if(_print_debug): print("CodeParser: Rollback action finished. Now will read previous line. -------------------------------------")
		script_reader.read_previous_line()


func stop_rollback():
	if(_print_debug): print("CodeParser: Rollback stopped. Now will read next line. -------------------------------------")
	_code_running = false
	script_reader.read_next_line()


func finish_twens():
	if(_print_debug): print("CodeParser: Call to end tweens (skip).")
	if(timer != null): timer.set_time_left(0)
	chara_controller.skip()
	fade_controller.skip()
	camera_controller.skip()


func reset_scene():
	finish_twens()
	chara_controller.reset_scene()


func is_code_running():
	return _code_running
