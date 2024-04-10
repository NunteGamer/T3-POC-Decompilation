extends Node

@export var _print_debug: bool
@export var T3_scene: Node
@export var game_flag_list: Node
@export var game_controller: Node

# _full_conditions = array of _full_condition
# _full_condition = [id, _single_conditions (array of single_condition)]
# single_condition = [binary_operator,flag,operator,value]
var _full_conditions: Array

# Array[Array[id, Array[flag,operator,value]]]


func check_conditions() -> bool:
	# going through all the conditions (whens)
	for i in _full_conditions.size():
		# separating the _single_conditions from the id
		var _single_conditions: Array = _full_conditions[i][1]
		
		var _total_result: bool
		var _single_conditions_string: String
		# checking each individual condition for a particular when
		for _single_condition in _single_conditions:
			# saving all conditions as a string for a future print
			_single_conditions_string += str(_single_condition)
			
			# getting the result of that condition
			var _single_result: bool
			_single_result = _check_parsed_condition(_single_condition)
			var _binary_operator: String = _single_condition[0]
			if(_binary_operator == ""):
				_total_result = _single_result
			elif(_binary_operator == "&&"):
				_total_result = _total_result && _single_result
			elif(_binary_operator == "||"):
				_total_result = _total_result || _single_result
			
		# if that condition is meet, run thorugh the when script
		if(_total_result):
			if(_print_debug): print("ConditionController: Condition meet: " + str(_single_conditions_string))
			var fulfilled_condition_id: String = _full_conditions[i][0]
			_full_conditions.remove_at(i)
			game_controller.set_game_running(false)
			T3_scene.game_functions.call_goto_id(fulfilled_condition_id)
			return true
	return false

# turn raw full conditions into properly parsed full conditions with single conditions inside
func parse_full_conditions(_raw_full_conditions: Array):
	# _raw_full_conditions is an array with [id, raw_conditions as a single string]
	_full_conditions.clear()
	
	# for each full condition (when)
	for _raw_full_condition in _raw_full_conditions:
		var _full_condition: Array
		var _single_conditions: Array
		
		# add the id
		var id: String = _raw_full_condition[0]
		_full_condition.append(id)
		
		# get the individual conditions
		var _single_raw_conditions: PackedStringArray
		var _binary_operator = ""
		_single_raw_conditions = _raw_full_condition[1].split("&&")
		if(_single_raw_conditions.size() > 0):
			_binary_operator = "&&"
		else:
			_single_raw_conditions = _raw_full_condition[1].split("||")
			if(_single_raw_conditions.size() > 0):
				_binary_operator = "||"
		
		# parse each single condition
		for i in _single_raw_conditions.size():
			var _single_raw_condition: Array
			var _single_condition: Array
			
			var binary_operator_for_this: String = _binary_operator
			if(i == 0): binary_operator_for_this = "" # the first condition shouldn't have a binary operator
			
			_single_condition = _parse_single_condition(_single_raw_conditions[i], binary_operator_for_this)
			_single_conditions.append(_single_condition.duplicate())
		
		_full_condition.append(_single_conditions.duplicate())
		_full_conditions.append(_full_condition.duplicate())
	


# turn a raw single condition into an array [_binary_operator, _flag, _operator, _value]
func _parse_single_condition(_raw_condition: String, binary_operator: String) -> Array:
	_raw_condition = _raw_condition.strip_edges()
	var _parsed_single_condition: Array
	_parsed_single_condition.append(binary_operator)
	var _parsed_operation: Array[String]
	_parsed_operation = _parse_operation(_raw_condition)
	_parsed_single_condition.append_array(_parsed_operation)
	return _parsed_single_condition


# turn a raw operation ("flag=value") into an array [_flag, _operator, _value]
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


# the condition is not parsed, but it receives a parsed operation
func _check_parsed_condition(_operation: Array) -> bool:
	var _parsed_operation: Array = _operation
	var _flag: String = _parsed_operation[1]
	var _operator: String = _parsed_operation[2]
	var _value: String = _parsed_operation[3]
	var _parsed_value = _parse_value(_value)
	
	var _parsed_flag = game_flag_list.get_flag_current_value(_flag)
	
	if(_parsed_flag == null):
		# also check vn flags
		_parsed_flag = T3_scene.game_functions.get_flag_list().get_current_flag_value(_flag)
	
	if(_parsed_flag == null):
		push_error("ConditionController: Flag '" + _flag + "' does not exist in GameFlagList (_check_parsed_condition).")
	
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


func _parse_value(_value: String):
	if(_value == "true"):
		return true
	elif(_value == "false"):
		return false
	elif(_value.is_valid_int()):
		return int(_value)
	else:
		return _value
