extends Node

@export var _print_debug: bool
@export var script_list: Node
@export var csv_manager: Node
@export var csv_parser: Node
@export var script_reader: Node
@export var camera_controller: Node

var skip_cooldown: float

var _vn_mode: bool

func _ready():
	_vn_mode = true
	run_script("proof_of_concept")


func _process(delta: float) -> void:
	if(_vn_mode):
		if Input.is_action_just_pressed("advance"):
			script_reader.input_to_read_next_line.call_deferred()
		elif Input.is_action_just_pressed("rollback"):
			script_reader.input_to_read_previous_line.call_deferred()
		elif (Input.is_action_pressed("skip") && skip_cooldown <= 0):
			skip_cooldown = 0.1
			script_reader.input_to_read_next_line.call_deferred()
		
		if(skip_cooldown > 0): skip_cooldown -= delta


func run_script(_name: String):
	var script_lines: Array[ScriptLine]
	script_lines = get_script_lines(_name)
	
	var script_path: String = script_list.get_script_path(_name)
	script_reader.set_script_lines(script_lines, _name, script_path)
	camera_controller.reset_camera_mode()
	script_reader.input_to_read_next_line.call_deferred()


func get_script_lines(_name:String) -> Array[ScriptLine]:
	var script_lines: Array[ScriptLine]
	var script_path: String = script_list.get_script_path(_name)
	if(script_path == ""):
		var error_text: String = "ERROR: ScriptManager: Script with name '" + _name + "' not found in ScriptList."
		if(_print_debug): print(error_text)
		push_error(error_text)
		return script_lines
	
	var csv_array: Array[PackedStringArray]
	csv_array = csv_manager.read_csv_file(script_path)
	script_lines = csv_parser.parse_csv_array_as_script(csv_array)
	if(_print_debug): print("ScriptManager: Script with name '" + _name + "' properly parsed. With number of lines: " + str(csv_array.size()))
	return script_lines


func set_vn_mode(_state: bool):
	_vn_mode = _state
