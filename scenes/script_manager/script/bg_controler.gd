extends Node

@export var _print_debug: bool
@export var script_reader: Node
@export var code_parser: Node
@export var bg_list: Node
@export var bg_container: Node2D
@export var bg_sprite2D: Sprite2D


func parse_bg(keywords: PackedStringArray, _skip: bool):
	var _bg_name: String = keywords[0]
	set_bg(_bg_name)
	code_parser.code_finished()

func rollback_bg(_keywords: PackedStringArray, _skip: bool):
	var previous_bg: String = script_reader.get_previous_bg()
	if(previous_bg == "none"):
		if(_print_debug): print("ERROR? BGController: Not found a previous BG on rollback.'")
		code_parser.rollback_finished(false)
		return
	
	set_bg(previous_bg)
	code_parser.rollback_finished(false)


func set_bg(_bg_name: String):
	var _texture: Texture = bg_list.get_bg(_bg_name)
	
	if(_texture == null):
		var error_text: String = "ERROR: BGController: BG with name '" + _bg_name + "' not found or doesn't have a texture."
		if(_print_debug): print(error_text)
		push_error(error_text)
		return
	bg_sprite2D.texture = _texture
	if(_print_debug): print("BGController: BG set with name '" + _bg_name + "'")
