extends Node

@export var code_parser: Node
@export var game_functions: Node
@export var textbox_controller: Node


func parse_function(keywords: PackedStringArray, skip: int, rollback: bool):
	var func_name: String = keywords[0]
	
	if(func_name == "print_test"):
		print_test(keywords[1], skip, rollback)
		return
	if(func_name == "hide_textbox"):
		hide_textbox(skip, rollback)
		return
	


func print_test(text: String, _skip: int, rollback: bool):
	print(text)
	end(rollback)


func hide_textbox(_skip: int, rollback: bool):
	await textbox_controller.hide_textbox(_skip)
	end(rollback)


func end(rollback: bool):
	if(rollback):
		code_parser.rollback_finished(false)
	else:
		code_parser.code_finished()

