extends Node

@export var _print_debug: bool

var flag_dictionary: Dictionary


func _ready():
	reset_game_flags()


# temporal flags to be used only during games
func reset_game_flags():
	flag_dictionary["game_reaction_1"] = [false]
	flag_dictionary["game_reaction_2"] = [false]
	flag_dictionary["game_reaction_3"] = [false]
	flag_dictionary["game_reaction_4"] = [false]
	flag_dictionary["game_reaction_5"] = [false]
	flag_dictionary["game_reaction_6"] = [false]
	flag_dictionary["game_reaction_7"] = [false]
	flag_dictionary["game_reaction_8"] = [false]
	flag_dictionary["game_reaction_9"] = [false]


func set_new_flag_value(_flag: String, _value):
	if(!flag_dictionary.has(_flag)):
		push_error("FlagList: Flag '" + _flag + "' does not exist (set_new_flag_value).")
		return
	
	var _value_array: Array = flag_dictionary[_flag]
	
	_value_array.append(_value)
	var _previous_value = null
	if(_value_array.size() > 1):
		_previous_value = _value_array[_value_array.size() - 2]
	if(_print_debug): print("FlagList: Value for flag '" + _flag + "' changed from '" + str(_previous_value) + "' to '" + str(_value_array[_value_array.size() - 1]) + "'")
	
	if(_value_array.size() > 5):
		_value_array.remove_at(0)


func get_current_flag_value(_flag: String):
	if(!flag_dictionary.has(_flag)):
		return null
	
	var _value_array: Array = flag_dictionary[_flag]
	return _value_array[_value_array.size() - 1]


func set_previous_flag_value(_flag: String) -> bool: # had a previous value?
	if(!flag_dictionary.has(_flag)):
		push_error("FlagList: Flag '" + _flag + "' does not exist (set_previous_flag_value).")
		return false
	
	var _value_array: Array = flag_dictionary[_flag]
	if(_value_array.size() > 1):
		if(_print_debug): print("FlagList: Rolledback flag '" + _flag + "' value from '" + str(_value_array[_value_array.size() - 1]) + "' to '" + str(_value_array[_value_array.size() - 2]) + "'")
		_value_array.remove_at(_value_array.size() - 1)
		return true
	if(_print_debug): print("FlagList: Flag '" + _flag + "' can't rollback because it doesn't have any previous values.")
	return false
