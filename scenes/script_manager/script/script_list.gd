extends Node

@export var scripts: Array[ScriptResource]

func get_script_path(_name: String) -> String:
	for script in scripts:
		if(script.get_script_name() == _name):
			return script.get_script_path()
	return ""
