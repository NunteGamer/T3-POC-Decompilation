extends Node

@export var character_list: Node
@export var name_list: ScriptResource
@export var csv_manager: Node
@export var csv_parser: Node
@export var script_reader: Node
@export var textbox_controller: Node
@export var chara_controller: Node
@export var camera_controller: Node
@export var name_label: RichTextLabel
@export var default_text_color: Color

var _names: Dictionary

func _ready():
	load_names()


func parse_name(_name: String, rollback: bool, _skip: int):
	# if the textbox is not present, wait for it to appear
	var _signal: Signal = textbox_controller.ensure_textbox_presence(_skip)
	if(_signal != null):
		await _signal
	
	# parse the name
	var display_name: String
	if(_names.has(_name)):
		display_name = _names[_name]["en"]
	else:
		push_error("ERROR: NameParser: Name '" + _name + "' is not on chara_names.csv. Using its raw name.")
		display_name = _name
	
	# format the text
	var formatted_name = "[center][font_size=30][color=#" + default_text_color.to_html() + "]" + display_name + "[/color][/font_size][/center]"
	name_label.text = formatted_name
	
	# highlight the speaker
	chara_controller.highlight_speaker(_name)
	
	# approach camera to the speaker
	camera_controller.approach_to(_name)
	
	# if no rollback, proceed to the next line, which should be the accompanying dialogue
	if(!rollback):
		script_reader.read_next_line()


func load_names():
	var csv_array: Array[PackedStringArray]
	csv_array = csv_manager.read_csv_file(name_list.get_script_path())
	var script_lines = csv_parser.parse_csv_array_as_chara_names(csv_array)
	
	# fill dictionary
	_names.clear()
	for script_line in script_lines:
		_names[script_line.code] = script_line.dialogue
		print("'" + str(script_line.code) + " = " + str(_names[script_line.code]) + "'")
