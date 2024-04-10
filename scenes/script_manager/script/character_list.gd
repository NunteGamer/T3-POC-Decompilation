extends Node

@export var characters: Array[CharacterResource]

func get_character(code_name: String) -> CustomCharacter:
	for chara in characters:
		if(chara.code_name == code_name):
			return chara.get_character()
	
	for chara in characters:
		if(chara.code_name == "dummy"):
			return chara.get_character()
	
	# shouldn't be reachable as long as dummy is on the list
	return null
