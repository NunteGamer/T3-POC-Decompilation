extends Node

@export var _print_debug: bool
@export var code_parser: Node
@export var name_parser: Node
@export var dialogue_parser: Node
@export var textbox_controller: Node
var script_lines: Array[ScriptLine]
var _script_path: String
var _script_name: String

var line_number: int
var _reading_lines_forward: bool
var _reading_lines_backwards: bool
var skip: int # 0 = off, 1 = normal, 2 = absolute
var absolute_skip_one_way_finished: bool
var _text_is_typing: bool
var continues: int # times <continue> has been called consecutively, and thus added to this queue
var skipping_continue_dialogue: bool


func set_script_lines(_script_lines: Array[ScriptLine], script_name: String,  script_path: String):
	_script_path = script_path
	script_lines = _script_lines.duplicate()
	_script_name = script_name
	reset_scene()


func reset_scene():
	skip = 0
	_reading_lines_forward = false
	_reading_lines_backwards = false
	absolute_skip_one_way_finished = false
	line_number = -1 # read_next_line() will turn it to 0
	code_parser.reset_scene()


func input_to_read_next_line():
	# if lines are still being read. call skip and join the queue
	if(_reading_lines_forward):
		if(_print_debug): print("ScriptReader: SKIPPING to read next line")
		code_parser.finish_twens()
		skip = 1
		
		# manage skipping during <continue> tag
		if(_text_is_typing):
			if(_print_debug): print("ScriptReader: SKIPPING text typing")
			dialogue_parser.skip()
		
		return
	
	# if lines are being read backwards but input wants to read forward,
	# fully skip backwards and then forward
	if(_reading_lines_backwards):
		if(_print_debug): print("ScriptReader: Input forward while reading backwards: ABSOLUTE SKIP forward")
		code_parser.finish_twens()
		skip = 2
		absolute_skip_one_way_finished = false
		# cancel rollbacking continue dialogue in case it was true
		code_parser.rollbacking_continue_dialogue = false
		return
	
	# if lines are not being read, but text is being typed, show it at once
	if(_text_is_typing):
		if(_print_debug): print("ScriptReader: SKIPPING text typing")
		_text_is_typing = false
		dialogue_parser.skip()
		return
	
	# cancel rollbacking continue dialogue in case it was true
	code_parser.rollbacking_continue_dialogue = false
	# if lines are not being read nor text being typed, proceed
	read_next_line()

func input_to_read_previous_line():
	# if lines are still being read. call skip and join the queue
	if(_reading_lines_backwards):
		if(_print_debug): print("ScriptReader: SKIPPING to read previous line")
		code_parser.finish_twens()
		skip = 1
		return
	
	# if lines are being read backwards but input wants to read forward,
	# fully skip backwards and then forward
	if(_reading_lines_forward):
		if(_print_debug): print("ScriptReader: Input backwards while reading forward: ABSOLUTE SKIP backward")
		code_parser.finish_twens()
		skip = 2
		absolute_skip_one_way_finished = false
		return
	
	# if lines are not being read, proceed
	if(code_parser.rollbacking_continue_dialogue):
		#the last read line was a dialogue with <continue>

		# the rollback is being called while the dialogue is being typed
		# therefore, skip to the last stop, then rollback
		if(is_text_typing()):
			if(_print_debug): print("ScriptReader: Input backwards while reading <continue> dialogue forward: ABSOLUTE SKIP forward")
			code_parser.finish_twens()
			skip = 2
			absolute_skip_one_way_finished = false
			# activate this flag so it works as it should
			_reading_lines_backwards = true
			return
			
		# the reader is stopped at a stop line
		# therefore, it must re-read that stop line, not the previous one
		else:
			_read_line(true)
	else:
		read_previous_line()


func text_finished_typing(_continued_reading: bool):
	_text_is_typing = false
	# if the dialogue had a <continue> tag, lines_finished_reading() is never called
	# so it must be called now
	if(_continued_reading):
		if(_print_debug): print("ScriptReader: Calling lines_finished_reading() since _continued_reading is true")
		lines_finished_reading()
		


func is_text_typing():
	return _text_is_typing


func lines_finished_reading():
	# if absolute skip and just finished skipping one way, do the other way
	if(skip == 2 && !absolute_skip_one_way_finished):
		absolute_skip_one_way_finished = true
		if(_print_debug): print("ScriptReader: ABSOLUTE SKIPPING: Now skipping the other way")
		if(_reading_lines_forward):
			read_previous_line()
		elif (_reading_lines_backwards):
			read_next_line()
		return
	
	# normal lines finished reading
	skip = 0
	_reading_lines_forward = false
	_reading_lines_backwards = false
	absolute_skip_one_way_finished = false
	if(_print_debug): print("ScriptReader: Lines finished being read. Skip is false.")


func read_next_line():
	# check if there are more lines to be read
	if(line_number + 1 > script_lines.size() - 1):
		lines_finished_reading()
		return

	line_number += 1
	
	if(_print_debug): print("ScriptReader: Read next line: " + str(line_number) + " " + str(script_lines[line_number].csv_cell) + ") ------------------------------")
	_read_line.call_deferred(false)


func read_previous_line():
	var previous_line: ScriptLine
	var search_line_number = line_number - 1
	
	# check if there are previous lines
	if(search_line_number < 0):
		if(_print_debug): print("ScriptReader: No more previous lines to read (end of file) ------------------------------")
		lines_finished_reading()
		return
	
	# check if there are more previous readable lines
	var no_more_readable_lines: bool
	# check if there are any previous readable lines (dialogue or goback)
	previous_line = script_lines[search_line_number]
	while(previous_line.type != ScriptLine.Type.DIALOGUE):
		search_line_number -= 1
		if(search_line_number < 0):
			no_more_readable_lines = true
			break
		# check code
		if(previous_line.type == ScriptLine.Type.CODE):
			var keywords: PackedStringArray = previous_line.code.split(":")
			# check if it's a goback line
			if(keywords[0] == "goback"):
				break
			# check if it's a game function line. can't rollback over game functions
			elif(keywords[0] == "game"):
				no_more_readable_lines = true
				break
		previous_line = script_lines[search_line_number]
	
	if(no_more_readable_lines):
		if(_print_debug): print("ScriptReader: No more previous lines to read (no more readable lines) ------------------------------")
		return
	
	# there are previous dialogue lines, read the previous line
	line_number -= 1
	if(_print_debug): print("ScriptReader: Read previous line (" + str(line_number) + " - " + script_lines[line_number].id + ") ------------------------------")
	_read_line.call_deferred(true)


# making this func public without having to change the name
func read_line(rollback: bool):
	_read_line(rollback)


func _read_line(rollback: bool):
	if(rollback): _reading_lines_backwards = true
	else: _reading_lines_forward = true
	if(_print_debug): print("ScriptReader: Reading new line. Skip: " + str(skip))
	
	# manage skip call
	if(skip > 0): 
		code_parser.finish_twens()
	
	# if the line number is invalid, return
	if(line_number > script_lines.size() - 1 || line_number < 0):
		if(_print_debug): print("ScriptReader: Line number '" + str(line_number) + "' is invalid.")
		lines_finished_reading()
		return
	
	# get the line
	var current_line: ScriptLine = script_lines[line_number]
	
	# clear the dialogue textbox and maybe make the textbox disappear etc
	if(current_line.type != ScriptLine.Type.DIALOGUE && !skipping_continue_dialogue):
		await textbox_controller.manage_textbox_for_next_line(skip)
	
	
	# parse the line type
	
	# code
	if(current_line.type == ScriptLine.Type.CODE):
		# if absolute skip backwards, code instructions can be ignored
		if(skip == 2 && _reading_lines_forward && !absolute_skip_one_way_finished):
			if(_print_debug): print("ScriptReader: Ignoring CODE Call because of ABSOLUTE SKIP backwards")
			read_next_line()
			return
		
		# call code parser
		if(_print_debug): print("ScriptReader: CODE call")
		if(rollback):
			code_parser.rollback_code(current_line.code, false, skip)
		else:
			code_parser.parse_code(current_line.code, skip)
		return
		# after this call, a next or previous line will be read
	
	# name
	if(current_line.type == ScriptLine.Type.NAME):
		# if absolute skip forwards, name instructions can be ignored
		if(skip == 2 && _reading_lines_backwards && !absolute_skip_one_way_finished):
			if(_print_debug): print("ScriptReader: Ignoring NAME Call because of ABSOLUTE SKIP forward")
			read_previous_line()
			return
		
		# call parse name
		if(_print_debug): print("ScriptReader: NAME call")
		if(rollback):
			if(_print_debug): print("ScriptReader: Reading previous line instead of parsing name because rollback")
			read_previous_line()
		else:
			if(_print_debug): print("ScriptReader: Parse name '" + str(current_line.code) + "'")
			name_parser.parse_name(current_line.code, false, skip)
		return
		# after this call, a next or previous line will be read
	
	# dialogue
	if(current_line.type == ScriptLine.Type.DIALOGUE):
		# if dialogue line with continue tags has already been rollbacked, skip it this time
		if(rollback && code_parser.rollbacking_continue_dialogue):
			if(_print_debug): print("ScriptReader: Ignoring DIALOGUE Call because rollbacking_continue_dialogue is true")
			code_parser.rollbacking_continue_dialogue = false
			read_previous_line()
			return
		
		# if absolute skip forwards, dialogue instructions can be ignored,
		# and mark the point where line reading should finish
		if(skip == 2 && _reading_lines_backwards && !absolute_skip_one_way_finished):
			if(_print_debug): print("ScriptReader: Ignoring DIALOGUE Call because of ABSOLUTE SKIP forward")
			lines_finished_reading()
			return
		
		# call parse dialogue
		if(_print_debug): print("ScriptReader: DIALOGUE call")
		_text_is_typing = true
		
		dialogue_parser.parse_dialogue(current_line.dialogue)
		
		if(rollback):
			# call the name and chara state/position that precedes the dialogue
			var previous_name: String = _call_rollback_name()
			# this will call previous lines until it finds a type chara
			_call_rollback_chara(previous_name)
		
		# a finished dialogue line will end the reading
		lines_finished_reading()
		


func _call_rollback_name() -> String:
	if(_print_debug): print("ScriptReader: Rollback name")
	
	# search back until the previous name is found
	var previous_line: ScriptLine
	var search_line_number = line_number - 1
	var no_previous_name: bool
	previous_line = script_lines[search_line_number]
	while(previous_line.type != ScriptLine.Type.NAME):
		search_line_number -= 1
		if(search_line_number < 0):
			no_previous_name = true
			break
		if(previous_line.type == ScriptLine.Type.CODE):
			var keywords: PackedStringArray = previous_line.code.split(":")
			# check if it's a game function line. can't rollback over game functions
			if(keywords[0] == "game"):
				no_previous_name = true
				break
		previous_line = script_lines[search_line_number]
	
	# check if name was found
	var chara_name: String
	# if a name was not found, try to get the previous chara used
	if(no_previous_name):
		var previous_chara = get_previous_chara()
		if(previous_chara == "none"):
			print("ERROR: ScriptReader: Dialogue without previous chara or name: '" + str(script_lines[line_number].dialogue["en"]) + "'")
			chara_name = ""
		print("ERROR: ScriptReader: Dialogue without previous name: '" + str(script_lines[line_number].dialogue["en"]) + "'. Using previous chara '" + previous_chara + "'")
		chara_name = previous_chara
	else:
		# name was found
		chara_name = previous_line.code
	
	# show the name
	name_parser.parse_name(chara_name, true, skip)
	if(_print_debug): print("ScriptReader: Rollbacked name: '" + chara_name + "'")
	
	return chara_name


func _call_rollback_chara(chara_name: String):
	if(_print_debug): print("ScriptReader: Rollback chara '" + chara_name + "'")
	
	# search back until the previous chara is found and call on it
	var search_line_number = line_number - 1
	var previous_line: ScriptLine = script_lines[search_line_number]
	var chara_found: bool
	while(!chara_found):
		# search the previous CODE line
		# if there isn't any, return ""
		while(previous_line.type != ScriptLine.Type.CODE):
			search_line_number -= 1
			if(search_line_number < 0): return ""
			previous_line = script_lines[search_line_number]
		
		# if the code is type chara and the name matches, exit the loop
		var keywords: PackedStringArray = previous_line.code.split(":")
		if(keywords[0] == "chara" && keywords[1] == chara_name):
			chara_found = true
			break
		# check if it's a game function line. can't rollback over game functions
		if(keywords[0] == "game"):
			return ""
		
		# prepare the next loop
		search_line_number -= 1
		if(search_line_number < 0): return ""
		previous_line = script_lines[search_line_number]
		
	# call rollback_code with single_line = true,
	# so this call doesn't cause further readings
	if(_print_debug): print("ScriptReader: Rollback chara code '" + previous_line.code + "'")
	if(chara_found):
		code_parser.rollback_code(previous_line.code, true, skip)


func end_skip():
	skip = 0
	skipping_continue_dialogue = false


func get_previous_chara() -> String:
	# search back until the previous state for that chara is found
	var search_line_number = line_number - 1
	if(search_line_number < 0): return "none"
	var previous_line: ScriptLine = script_lines[search_line_number]
	var chara_found: bool
	while(!chara_found):
		# search the previous CODE line
		# if there isn't any, return "none"
		while(previous_line.type != ScriptLine.Type.CODE):
				search_line_number -= 1
				if(search_line_number < 0): return "none"
				previous_line = script_lines[search_line_number]
		
		# if the line is for a chara, return its name
		var keywords: PackedStringArray = previous_line.code.split(":")
		if(keywords.size() > 1):
			if(keywords[0] == "chara"):
				return keywords[1]
		# check if it's a game function line. can't rollback over game functions
		if(keywords[0] == "game"):
			return "none"
		
		# prepare for the next loop
		search_line_number -= 1
		previous_line = script_lines[search_line_number]
		if(search_line_number < 0): return "none"
	
	# unreachable
	return ""
	

func get_previous_chara_state(chara_name: String) -> String:
	var already_used_goback_lines: Array[String]
	# search back until the previous state for that chara is found
	var search_line_number = line_number - 1
	if(search_line_number < 0): return ""
	var previous_line: ScriptLine = script_lines[search_line_number]
	var state_found: bool
	var blank_state_found: bool
	while(!state_found):
		# search the previous CODE line
		# if there isn't any, return ""
		while(previous_line.type != ScriptLine.Type.CODE):
				search_line_number -= 1
				# if there aren't lines left but there was a blank state, it means it was created with default state
				# otherwise, it means the chara didn't exist before this and should hide
				if(search_line_number < 0):
					if(blank_state_found): return ""
					return "none"
				previous_line = script_lines[search_line_number]
		
		# if the line is for that chara's name and has a state, return it
		var keywords: PackedStringArray = previous_line.code.split(":")
		if(keywords.size() > 2):
			if(keywords[0] == "chara" && keywords[1] == chara_name):
				return keywords[2]
		# if the line is for that chara's name but doesn't have a state,
		# it could either mean that a state was declared earlier or
		# that it was created with default state, so set blank_state_found to true and keep searching
		elif(keywords.size() > 1):
			if(keywords[0] == "chara" && keywords[1] == chara_name):
				blank_state_found = true
			# check if it's a goback line
			elif(keywords[0] == "goback" && !already_used_goback_lines.has(keywords[0])):
				# save already_used_goback_lines to avoid infinite loops;
				# we only want to go back one time, to undo the original goto
				already_used_goback_lines.append(keywords[1])
				search_line_number = _get_id_line_number(keywords[1])
				if(_print_debug): print("ScriptReader: going back to id '" + keywords[1] + "' while searching for previous state of chara: '" + chara_name + "'.")
		# check if it's a game function line. can't rollback over game functions
		if(keywords[0] == "game"):
			return "none"
		
		# prepare for the next loop
		search_line_number -= 1
		previous_line = script_lines[search_line_number]
		# if there aren't lines left but there was a blank state, it means it was created with default state
		# otherwise, it means the chara didn't exist before this and should hide
		if(search_line_number < 0): 
			if(blank_state_found): return ""
			return "none"
	
	# unreachable
	return ""


func get_previous_chara_position(chara_name: String) -> Array:
	# search back until the previous position for that chara is found
	var search_line_number = line_number - 1
	var previous_line: ScriptLine = script_lines[search_line_number]
	var position_found: bool
	var blank_position_found: bool
	
	while(!position_found):
		# search the previous CODE line
		# if there isn't any, return ""
		while(previous_line.type != ScriptLine.Type.CODE):
				search_line_number -= 1
				# if there aren't lines left but there was a blank position, it means it was created with default position
				# otherwise, it means the chara didn't exist before this
				if(search_line_number < 0): 
					if(blank_position_found): return ["", 0]
					return ["none", 0]
				previous_line = script_lines[search_line_number]
		
		# if the line is for that chara's name and has a position, return it
		var keywords: PackedStringArray = previous_line.code.split(":")
		if(keywords.size() > 3 && keywords[3] != ""):
			if(keywords[0] == "chara" && keywords[1] == chara_name):
				if(keywords[2] == "hide"):
					# if it's hide, it means the chara hided
					# and then reappeared without specifying position
					# therefore the position is the default one
					return ["", search_line_number]
				else:
					return [keywords[3], search_line_number]
		# if the line is for that chara's name but doesn't have a position,
		# it could either mean that a position was declared earlier or
		# that it was created with default position, so set blank_position_found to true and keep searching
		elif(keywords.size() > 1):
			if(keywords[0] == "chara" && keywords[1] == chara_name):
				blank_position_found = true
		# check if it's a game function line. can't rollback over game functions
		if(keywords[0] == "game"):
			return ["none", search_line_number]
		
		# prepare for the next loop
		search_line_number -= 1
		previous_line = script_lines[search_line_number]
		# if there aren't lines left but there was a blank position, it means it was created with default position
		# otherwise, it means the chara didn't exist before this
		if(search_line_number < 0): 
					if(blank_position_found): return ["", 0]
					return ["none", 0]
	
	# unreachable
	return ["", 0]


func get_previous_chara_depth(chara_name: String) -> Array:
	# search back until the previous depth for that chara is found
	var search_line_number = line_number - 1
	var previous_line: ScriptLine = script_lines[search_line_number]
	var depth_found: bool
	var blank_depth_found: bool
	
	while(!depth_found):
		# search the previous CODE line
		# if there isn't any, return ""
		while(previous_line.type != ScriptLine.Type.CODE):
				search_line_number -= 1
				# if there aren't lines left but there was a blank depth, it means it was created with default depth
				# otherwise, it means the chara didn't exist before this
				if(search_line_number < 0): 
					if(blank_depth_found): return ["", 0]
					return ["none", 0]
				previous_line = script_lines[search_line_number]
		
		# if the line is for that chara's name and has a position, return it
		var keywords: PackedStringArray = previous_line.code.split(":")
		if(keywords.size() > 4):
			if(keywords[0] == "chara" && keywords[1] == chara_name):
				if(keywords[2] == "hide"):
					# if it's hide, it means the chara hided
					# and then reappeared without specifying depth
					# therefore the depth is the default one
					return ["", search_line_number]
				else:
					return [keywords[4], search_line_number]
		# if the line is for that chara's name but doesn't have a depth,
		# it could either mean that a depth was declared earlier or
		# that it was created with default depth, so set blank_depth_found to true and keep searching
		elif(keywords.size() > 1):
			if(keywords[0] == "chara" && keywords[1] == chara_name):
				blank_depth_found = true
		# check if it's a game function line. can't rollback over game functions
		if(keywords[0] == "game"):
			return ["none", search_line_number]
		
		# prepare for the next loop
		search_line_number -= 1
		previous_line = script_lines[search_line_number]
		# if there aren't lines left but there was a blank depth, it means it was created with default depth
		# otherwise, it means the chara didn't exist before this
		if(search_line_number < 0): 
					if(blank_depth_found): return ["", 0]
					return ["none", 0]
	
	# unreachable
	return ["", 0]


func get_previous_dialogue_id() -> String:
	# search back until the previous dialogue is found
	var search_line_number = line_number - 1
	if(search_line_number < 0): return ""
	var previous_line: ScriptLine = script_lines[search_line_number]
	
	# search the previous DIALOGUE line
	# if there isn't any, return ""
	while(previous_line.type != ScriptLine.Type.DIALOGUE):
			search_line_number -= 1
			if(search_line_number < 0): return ""
			previous_line = script_lines[search_line_number]
	
	# dialogue line found. return its id
	return previous_line.id
	


func get_next_name() -> String:
	# search forward until the next name or dialogue
	var search_line_number = line_number + 1
	# if end of file, return none
	if(search_line_number > script_lines.size() - 1): return "none"

	# search for the next NAME or DIALOGUE line
	# if there isn't any, return "none"
	var next_line: ScriptLine = script_lines[search_line_number]
	while(next_line.type != ScriptLine.Type.NAME && next_line.type != ScriptLine.Type.DIALOGUE):
		search_line_number += 1
		if(search_line_number > script_lines.size() - 1): return "none"
		next_line = script_lines[search_line_number]
		
		if(next_line.type == ScriptLine.Type.CODE):
			var keywords: PackedStringArray = next_line.code.split(":")
			# check if it's a game function line. can't rollback over game functions
			if(keywords[0] == "game"):
				return "none"
	
	# if a name is found before a dialogue, return the name
	if(next_line.type == ScriptLine.Type.NAME):
		return next_line.code
	
	# if a dialogue is found before a name, it means the previous named character
	# keeps talking, so search the name back, not forward
	return get_previous_name()

func get_previous_name() -> String:
	# search backwards until the next name or dialogue
	var search_line_number = line_number - 1
	# if end of file, return none
	if(search_line_number < 0): return "none"

	# search for the next NAME line
	# if there isn't any, return "none"
	var next_line: ScriptLine = script_lines[search_line_number]
	while(next_line.type != ScriptLine.Type.NAME):
			search_line_number -= 1
			if(search_line_number < 0): return "none"
			next_line = script_lines[search_line_number]
			
			if(next_line.type == ScriptLine.Type.CODE):
				var keywords: PackedStringArray = next_line.code.split(":")
				# check if it's a game function line. can't rollback over game functions
				if(keywords[0] == "game"):
					return "none"
	
	# return the found name
	return next_line.code


func get_previous_bg() -> String:
	# search backwards until the next name or dialogue
	var search_line_number = line_number - 1
	# if end of file, return none
	if(search_line_number < 0): return "none"

	# search for the next CODE line
	# if there isn't any, return "none"
	var next_line: ScriptLine = script_lines[search_line_number]
	var bg_found: bool
	while(!bg_found):
		while(next_line.type != ScriptLine.Type.CODE):
			search_line_number -= 1
			if(search_line_number < 0): return "none"
			next_line = script_lines[search_line_number]
		var keywords: PackedStringArray = next_line.code.split(":")
		
		if(keywords[0] == "bg"):
			bg_found = true
			return keywords[1]
		elif(keywords[0] == "game"):
					return "none"
		else: 
			search_line_number -= 1
			if(search_line_number < 0): return "none"
			next_line = script_lines[search_line_number]
	# shouldn't be able to get here
	return "none"


func get_previous_code(_keyword: String) -> PackedStringArray:
	var keywords: PackedStringArray
	# search backwards until the next code
	var search_line_number = line_number - 1
	# if end of file, return none
	if(search_line_number < 0): return keywords

	# search for the next CODE line
	# if there isn't any, return "none"
	var next_line: ScriptLine = script_lines[search_line_number]
	var found: bool
	while(!found):
		while(next_line.type != ScriptLine.Type.CODE):
			search_line_number -= 1
			# if no more lines, return empty
			if(search_line_number < 0): 
				keywords.clear()
				return keywords
			next_line = script_lines[search_line_number]
		
		keywords = next_line.code.split(":")
		if(keywords.size() > 0 && keywords[0] == _keyword):
			found = true
			return keywords
		else: 
			search_line_number -= 1
			if(search_line_number < 0):
				keywords.clear()
				return keywords
			next_line = script_lines[search_line_number]
	# shouldn't be able to get here
	keywords.clear()
	return keywords


func get_previous_double_code(_keyword1: String, _keyword2: String) -> PackedStringArray:
	var keywords: PackedStringArray
	# search backwards until the next code with multiple keywords
	var search_line_number = line_number - 1
	# if end of file, return none
	if(search_line_number < 0): return keywords

	# search for the next CODE line
	# if there isn't any, return "none"
	var next_line: ScriptLine = script_lines[search_line_number]
	var found: bool
	while(!found):
		while(next_line.type != ScriptLine.Type.CODE):
			search_line_number -= 1
			if(search_line_number < 0): return keywords
			next_line = script_lines[search_line_number]
		
		keywords = next_line.code.split(":")
		if(keywords.size() > 1 && keywords[0] == _keyword1 && keywords[1] == _keyword2):
			found = true
			return keywords
		else: 
			search_line_number -= 1
			if(search_line_number < 0):
				keywords.clear()
				return keywords
			next_line = script_lines[search_line_number]
	# shouldn't be able to get here
	keywords.clear()
	return keywords


func get_next_double_code(_keyword1: String, _keyword2: String) -> PackedStringArray:
	var keywords: PackedStringArray
	# search backwards until the next code with multiple keywords
	var search_line_number = line_number + 1
	# if end of file
	if(search_line_number > script_lines.size() - 1): return keywords

	# search for the next CODE line
	var next_line: ScriptLine = script_lines[search_line_number]
	var found: bool
	while(!found):
		while(next_line.type != ScriptLine.Type.CODE):
			search_line_number += 1
			if(search_line_number > script_lines.size() - 1): return keywords
			next_line = script_lines[search_line_number]
		
		keywords = next_line.code.split(":")
		if(keywords.size() > 1 && keywords[0] == _keyword1 && keywords[1] == _keyword2):
			found = true
			return keywords
		else: 
			search_line_number += 1
			if(search_line_number < 0):
				keywords.clear()
				return keywords
			next_line = script_lines[search_line_number]
	# shouldn't be able to get here
	keywords.clear()
	return keywords


func get_next_double_code_id(_keyword1: String, _keyword2: String) -> String:
	var _id: String
	var keywords: PackedStringArray
	# search backwards until the next code with multiple keywords
	var search_line_number = line_number + 1
	# if end of file
	if(search_line_number > script_lines.size() - 1): return _id

	# search for the next CODE line
	var next_line: ScriptLine = script_lines[search_line_number]
	var found: bool
	while(!found):
		while(next_line.type != ScriptLine.Type.CODE):
			search_line_number += 1
			if(search_line_number > script_lines.size() - 1): return _id
			next_line = script_lines[search_line_number]
		
		keywords = next_line.code.split(":")
		if(keywords.size() > 1 && keywords[0] == _keyword1 && keywords[1] == _keyword2):
			found = true
			_id = next_line.id
			return _id
		else: 
			search_line_number += 1
			if(search_line_number > script_lines.size() - 1): return _id
			next_line = script_lines[search_line_number]
	# shouldn't be able to get here
	return _id


func is_next_line_chara_movement() -> bool:
	# search forward until the next chara
	var search_line_number = line_number + 1
	# if end of file, return false
	if(search_line_number > script_lines.size() - 1): return false
	
	# check if next line is a chara movement
	var next_line: ScriptLine = script_lines[search_line_number]
	if(next_line.type == ScriptLine.Type.CODE):
		var keywords: PackedStringArray = next_line.code.split(":")
		if(keywords[0] == "chara"):
			if(keywords.size() > 2 && keywords[3] != ""):
				return true
			elif(keywords.size() > 3 && keywords[4] != ""):
				return true
	
	return false

func is_previous_line_chara_movement(previous_line_number: int) -> bool:
	# search forward until the next chara
	var search_line_number = previous_line_number - 1
	# if end of file, return false
	if(search_line_number < 0): return false

	# check if next line is a chara movement
	var previous_line: ScriptLine = script_lines[search_line_number]
	if(previous_line.type == ScriptLine.Type.CODE):
		var keywords: PackedStringArray = previous_line.code.split(":")
		if(keywords[0] == "chara"):
			if(keywords.size() > 2 && keywords[3] != ""):
				return true
			elif(keywords.size() > 3 && keywords[4] != ""):
				return true
	
	return false


# returns [this chara keeps speaking, any character keeps speaking]
func does_character_keep_speaking() -> Array[bool]:
	var _chara_name: String = get_previous_name()
	# search forward until the next chara. start from the current line, since this will be called on the next line after a dialogue
	var search_line_number = line_number
	# if end of file, return false
	if(search_line_number > script_lines.size() - 1): return [false, false]
	
	# check if next line is _chara_name
	var next_line: ScriptLine = script_lines[search_line_number]
	if(next_line.type == ScriptLine.Type.NAME):
		if(next_line.code == _chara_name):
			return [true, true]
		else:
			return [false, true]
	
	# check if there is a function that breaks the chara monologue before the next chara dialogue
	search_line_number -= 1 # start from the previous line
	var _dialogue_interrupted: bool
	while(!_dialogue_interrupted):
		search_line_number += 1
		if(search_line_number > script_lines.size() - 1): return [false, false]
		
		next_line = script_lines[search_line_number]
		if(next_line.type == ScriptLine.Type.CODE):
			var keywords: PackedStringArray = next_line.code.split(":")
			
			if(keywords[0] == "chara"):
				# if it's a change of position or a new chara appearing
				if(keywords.size() > 3 || keywords.size() == 2):
					return [false, false]
				if(keywords[2] == "hide"):
					return [false, false]
			
			if(keywords[0] == "game"):
				return [false, false]
			if(keywords[0] == "zoom"):
				return [false, false]
			if(keywords[0] == "wait"):
				return [false, false]
			if(keywords[0] == "endwhen"):
				return [false, false]
			if(keywords.size() > 1 && keywords[0] == "camera" && keywords[1] == "chara"):
				return [false, false]
		
		elif(next_line.type == ScriptLine.Type.NAME):
			if(next_line.code == _chara_name):
				return [true, true]
			else:
				return [false, true]
		
		# same character keeps speaking withoput repeating the name
		elif(next_line.type == ScriptLine.Type.DIALOGUE):
			return [true, true]
			
	# unreachable
	return [false, false]


func get_error_position() -> String:
	return _script_path + " - line: " + str(line_number) + " - csv_cell: " + str(script_lines[line_number].csv_cell)


func goto_id(id: String):
	# check that the goto line has an id to return to it
	var _id: String = script_lines[line_number].id
	if(_id == ""):
		var error_text: String = "ERROR: GOTO doesn't have an ID at " + str(script_lines[line_number].csv_cell)
		if(_print_debug): print(error_text)
		push_error(error_text)
		read_next_line()
		return
	
	# change line_number to the line with the received id
	line_number = _get_id_line_number(id)
	
	# check that the id exists
	if(line_number == -1):
		var error_text: String = "ERROR: ID " + id + " not found."
		if(_print_debug): print(error_text)
		push_error(error_text)
		read_next_line()
		return
	
	# insert goback line as a reverse goto to make rollback possible
	var goback_line: ScriptLine = ScriptLine.new()
	goback_line.code = "goback:" + _id
	script_lines.insert(line_number, goback_line)
	
	# advance line_number, since it has been pushed by the goback line
	line_number += 1
	
	if(_print_debug): print("ScriptLine: goto_id calling _read_line")
	_read_line(false)


# be very CAREFUL when using this. it doesn't add a goback line
# this is used to rollback continue/stop tags
func change_line_number_to_id(id: String):
	# check that the goto line has an id to return to it
	var _id: String = script_lines[line_number].id
	if(_id == ""):
		var error_text: String = "ERROR: GOTO doesn't have an ID at " + str(script_lines[line_number].csv_cell)
		if(_print_debug): print(error_text)
		push_error(error_text)
		read_next_line()
		return
	
	# change line_number to the line with the received id
	line_number = _get_id_line_number(id)
	
	# check that the id exists
	if(line_number == -1):
		var error_text: String = "ERROR: ID " + id + " not found."
		if(_print_debug): print(error_text)
		push_error(error_text)
		read_next_line()
		return


func goto_endif(): # returns wether it found an endif or not
	if(_print_debug): print("ScriptReader: Searching for the next endif.")
	# search forward until the next endif
	var search_line_number = line_number
	# save the current line id
	var _id: String = script_lines[line_number].id
	
	# search for the next CODE line
	# if there isn't any, return false
	var next_line: ScriptLine = script_lines[search_line_number]
	var _found: bool
	while(!_found):
		search_line_number += 1
		# if end of file, it wasn't found (error)
		if(search_line_number > script_lines.size() - 1): 
			if(_print_debug): print("ERROR: ScriptReader: Endif not found for if: " + script_lines[line_number].code)
			push_error("ERROR: ScriptReader: Endif not found for if: " + script_lines[line_number].code)
		
		# check if it's an endif
		next_line = script_lines[search_line_number]
		if(next_line.type == ScriptLine.Type.CODE):
			var keywords: PackedStringArray = next_line.code.split(":")
			if(keywords[0] == "endif"):
				_found = true
	
	if(_print_debug): print("ScriptReader: Endif found at: " + str(next_line.csv_cell) + ". Line number: " + str(line_number))
	
	# jump lines
	line_number = search_line_number
	# insert goback line as a reverse goto to make rollback possible
	var goback_line: ScriptLine = ScriptLine.new()
	goback_line.code = "goback:" + _id
	script_lines.insert(line_number, goback_line)
	
	# advance line_number, since it has been pushed by the goback line
	line_number += 1

	code_parser.code_finished()


func goback_id(id: String):
	# remove the goback line, since the goto is going to be reversed
	# so it's not needed anymore (and will cause bugs if it remains)
	script_lines.remove_at(line_number)
	
	# change line_number to the line with the received id
	line_number = _get_id_line_number(id)
	
	# check that the id exists
	if(line_number == -1):
		var error_text: String = "ERROR: ID " + id + " not found on goback."
		if(_print_debug): print(error_text)
		push_error(error_text)
		
		read_previous_line()
		return
	
	# reduce line_number, since we want to skip the goto line we are returning to
	line_number -= 1
	
	_read_line(true)


func get_game_conditions() -> Array:
	var _conditions: Array
	var _condition_array: Array[String]
	
	# search forward until the next name or dialogue
	var search_line_number = line_number + 1
	# if end of file
	if(search_line_number > script_lines.size() - 1): 
		return _conditions
	
	# search for the next CODE line
	var next_line: ScriptLine = script_lines[search_line_number]
	var _found_game_end: bool
	while(!_found_game_end):
		search_line_number += 1
		# if end of file
		if(search_line_number > script_lines.size() - 1): 
			return _conditions
		
		# check if it's a when
		next_line = script_lines[search_line_number]
		if(next_line.type == ScriptLine.Type.CODE):
			var keywords: PackedStringArray = next_line.code.split(":")
			if(keywords[0] == "when"):
				keywords.remove_at(0)
				var _keywords_string: String
				for _keyword in keywords:
					_keywords_string += str(_keyword)
				_condition_array = [next_line.id, _keywords_string]
				_conditions.append(_condition_array)
		
			# check if it's a game:end
			if(keywords.size() > 1):
				if(keywords[0] == "game" && keywords[1] == "end"):
					_found_game_end = true
		
	return _conditions


func _get_id_line_number(id: String) -> int:
	var i: int
	while(i < script_lines.size()):
		if(script_lines[i].id == id):
			return i
		i += 1
	
	return -1


func set_line_number(_number: int):
	line_number = _number


func continue_read_next_line(skipping: bool):
	# a <continue> is currently being procesed
	if(_print_debug): print("ScriptReader: Continuing reading next line because of <continue> tag.")
	if(skipping && skip == 0):
		skip = 1
		skipping_continue_dialogue = true
	
	if(is_text_typing() && code_parser.is_code_running()):
		if(_print_debug): print("ScriptReader: Continue added to queue.")
		continues += 1
	else:
		if(_print_debug): print("ScriptReader: Continue NOT added to queue.")
	read_next_line()
