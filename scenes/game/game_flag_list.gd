extends Node

@export var _print_debug: bool

var flag_dictionary: Dictionary

func _ready():
	reset_flags()


func reset_flags():
	flag_dictionary["moves_player"] = [0]
	flag_dictionary["moves_rival"] = [0]
	flag_dictionary["_2_in_a_row_player"] = [false]
	flag_dictionary["_2_in_a_row_rival"] = [false]
	flag_dictionary["rival_fork"] = [false]
	flag_dictionary["player_fork"] = [false]
	
	flag_dictionary["game_over"] = [false] # true right after the lasrt move of a game, then false again
	flag_dictionary["end_states"] = [] # game state + player team + result + last move
	flag_dictionary["moves"] = [] # moves made this game in order
	flag_dictionary["last_game_winner"] = [-1] # 0 = tie, 1 = player, 2 = AI
	flag_dictionary["games_played"] = [0] # games finished this match
	flag_dictionary["player_score"] = [0]
	flag_dictionary["rival_score"] = [0]
	flag_dictionary["score_difference"] = [0]
	
	flag_dictionary["ai_move_flag"] = [""]


func set_flag_new_value(_flag: String, _value):
	if(!flag_dictionary.has(_flag)):
		push_error("GameFlagList: Flag '" + _flag + "' does not exist (set_new_flag_value).")
		return
	
	var _value_array: Array = flag_dictionary[_flag]
	
	_value_array.append(_value)
	var _previous_value = null
	if(_value_array.size() > 1):
		_previous_value = _value_array[_value_array.size() - 2]
	if(_print_debug): print("GameFlagList: Value for flag '" + _flag + "' changed from '" + str(_previous_value) + "' to '" + str(_value_array[_value_array.size() - 1]) + "'")
	
	if(_value_array.size() > 5):
		_value_array.remove_at(0)


func add_new_flag_value(_flag: String, _value):
	if(!flag_dictionary.has(_flag)):
		push_error("GameFlagList: Flag '" + _flag + "' does not exist (add_new_flag_value).")
		return
	
	var _value_array: Array = flag_dictionary[_flag]
	_value_array.append(_value)


func get_flag_current_value(_flag: String):
	if(!flag_dictionary.has(_flag)):
		return null
	
	var _value_array: Array = flag_dictionary[_flag]
	
	return _value_array[_value_array.size() - 1]
	

# flag does not have a history to revert to
func get_flag_absolute_value(_flag: String):
	if(!flag_dictionary.has(_flag)):
		return null
	
	return flag_dictionary[_flag]


func set_flag_previous_value(_flag: String) -> bool: # had a previous value?
	if(!flag_dictionary.has(_flag)):
		push_error("GameFlagList: Flag '" + _flag + "' does not exist (set_previous_flag_value).")
		return false
	
	var _value_array: Array = flag_dictionary[_flag]
	if(_value_array.size() > 1):
		if(_print_debug): print("GameFlagList: Rolledback flag '" + _flag + "' value from '" + str(_value_array[_value_array.size() - 1]) + "' to '" + str(_value_array[_value_array.size() - 2]) + "'")
		_value_array.remove_at(_value_array.size() - 1)
		return true
	if(_print_debug): print("GameFlagList: Flag '" + _flag + "' can't rollback because it doesn't have any previous values.")
	return false


func reset_flag_to(_flag: String, _value: Array):
	if(!flag_dictionary.has(_flag)):
		push_error("GameFlagList: Flag '" + _flag + "' does not exist (reset_flag).")
		return false
	
	flag_dictionary[_flag] = _value
	
