extends Node

@export var _print_debug: bool
@export var flag_list: Node
@export var main_game_controller: Node
@export var script_reader: Node
@export var code_parser: Node
@export var game_functions: Node

var _operators: Array[String] = ["=", "<", ">"]


func parse_flag(keywords: PackedStringArray):
	if(keywords[0] == "if"):
		_parse_if(keywords[1])
	if(keywords[0] == "flag"):
		_do_parse_flag(keywords[1])


func rollback_flag(keywords: PackedStringArray):
	var _parsed_operation: Array = _parse_flag_operation(keywords[0])
	var _flag: String = _parsed_operation[0]
	
	var _rollback_success: bool = flag_list.set_previous_flag_value(_flag)
	if(_rollback_success):
		_end_rollback()
	else:
		_stop_rollback()


func _get_flag_value(_flag: String):
	var _flag_value = flag_list.get_current_flag_value(_flag)
	
	if(_flag_value == null):
		# vn mode: only look for vn flags
		if(main_game_controller.get_mode() == 0):
			push_error("FlagController: Flag '" + _flag + "' does not exist in FlagList (_get_flag_value).")
		# vn mode: look for game flags too
		elif(main_game_controller.get_mode() == 1):
			_flag_value = game_functions.get_game_scene_instance().game_flag_list.get_flag_current_value(_flag)
			if(_flag_value == null):
				push_error("FlagController: Flag '" + _flag + "' does not exist in GameFlagList (_get_flag_value).")
		
	return _flag_value


func _do_parse_flag(_operation: String):
	var _parsed_operation: Array = _parse_flag_operation(_operation)
	var _flag: String = _parsed_operation[0]
	var _operator: String = _parsed_operation[1]
	var _value: String = _parsed_operation[2]
	
	# check if value is a flag
	var _value_is_flag: bool
	if(flag_list.flag_dictionary.has(_value)):
		_value_is_flag = true
	
	# parse value
	var _parsed_value
	if(_value_is_flag):
		_parsed_value = _get_flag_value(_flag)
	elif(_value.is_valid_int()):
		_parsed_value = int(_value)
	elif(_value == "true"):
		_parsed_value = true
	elif(_value == "false"):
		_parsed_value = false
	
	# operate
	if(_operator == "="):
		flag_list.set_new_flag_value(_flag, _parsed_value)
		if(_print_debug): print("FlagController: Flag '" + _flag + "' equaled to '" + str(_value) + "'. New value = " + str(_parsed_value))
	if(_operator == "+"):
		var _previous_value = _get_flag_value(_flag)
		flag_list.set_new_flag_value(_flag, _previous_value + _parsed_value)
		if(_print_debug): print("FlagController: Flag '" + _flag + "' + '" + str(_value) + "'. New value = " + str(_previous_value + _parsed_value))
	if(_operator == "-"):
		var _previous_value = _get_flag_value(_flag)
		flag_list.set_new_flag_value(_flag, _previous_value - _parsed_value)
		if(_print_debug): print("FlagController: Flag '" + _flag + "' - '" + str(_value) + "'. New value = " + str(_previous_value + _parsed_value))


func _parse_flag_operation(_operation: String) -> Array[String]:
	var _flag: String
	var _operator: String
	var _value: String
	
	# get operator
	var _separated_keywords: PackedStringArray
	_separated_keywords = _operation.split("=")
	if(_separated_keywords.size() > 1):
		_operator = "="
	else:
		_separated_keywords = _operation.split("+")
		if(_separated_keywords.size() > 1):
			_operator = "+"
		else:
			_separated_keywords = _operation.split("-")
			if(_separated_keywords.size() > 1):
				_operator = "-"
			# no operator
			else:
				_operator = "="
				_value = "true"
	
	# set flag and value
	if(_flag == ""): _flag = _separated_keywords[0]
	if(_value == ""): _value = _separated_keywords[1]
	
	return [_flag, _operator, _value]


func _parse_if(_operation: String):
	var _is_condition_met: bool = _check_condition(_operation)
	
	if(_is_condition_met):
		if(_print_debug): print("FlagController: Condition meet: " + _operation)
		_end()
	else:
		if(_print_debug): print("FlagController: Condition not meet: " + _operation + ". Jumping to the next endif.")
		script_reader.goto_endif()


func _check_condition(_operation: String) -> bool:
	var _parsed_operation: Array = _parse_operation(_operation)
	var _flag: String = _parsed_operation[0]
	var _operator: String = _parsed_operation[1]
	var _value: String = _parsed_operation[2]
	var _parsed_value = _parse_value(_value)

	var _parsed_flag = _get_flag_value(_flag)
	if(_operator == "="):
		if(_parsed_flag == _parsed_value):
			return true
	elif(_operator == "<"):
		if(_parsed_flag < _parsed_value):
			return true
	elif(_operator == ">"):
		if(_parsed_flag > _parsed_value):
			return true
	
	return false


func _parse_operation(_operation: String) -> Array[String]:
	var _flag: String
	var _operator: String
	var _value: String
	
	# parse the operation
	var _separated_keywords: PackedStringArray
	_separated_keywords = _operation.split("=")
	if(_separated_keywords.size() > 1):
		_operator = "="
	else:
		_separated_keywords = _operation.split("<")
		if(_separated_keywords.size() > 1):
			_operator = "<"
		else:
			_separated_keywords = _operation.split(">")
			if(_separated_keywords.size() > 1):
				_operator = ">"
			else: # no operator, it's just a flag check
				_flag = _operation
				_operator = "="
				_value = "true"
	
	if(_flag == ""): _flag = _separated_keywords[0]
	if(_value == ""): _value = _separated_keywords[1]
	
	return [_flag, _operator, _value]


func _parse_value(_value: String):
	# check if value is a flag
	var _flag_value = flag_list.get_current_flag_value(_value)
	if(_flag_value != null):
		_value = str(_flag_value)
	elif(main_game_controller.get_mode() == 1):
		_flag_value = game_functions.get_game_scene_instance().game_flag_list.get_flag_current_value(_value)
	if(_flag_value != null):
		_value = str(_flag_value)
	
	if(_value == "true"):
		return true
	elif(_value == "false"):
		return false
	elif(_value.is_valid_int()):
		return int(_value)
	else:
		return _value


func _end():
	code_parser.code_finished()


func _end_rollback():
	code_parser.rollback_finished(false)


func _stop_rollback():
	if(_print_debug): print("FlagController: Stopped rollback because can't revert flag value.")
	code_parser.stop_rollback()


func reset_game_flags():
	flag_list.reset_game_flags()
