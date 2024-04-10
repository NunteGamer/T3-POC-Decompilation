extends Resource
class_name ScriptResource

@export var _name: String
@export var _path: String


func get_script_name() -> String:
	return _name

func get_script_path() -> String:
	return _path
