extends Resource
class_name CharacterResource

@export var code_name: String
@export var _display_name: String
@export var _packed_scene: PackedScene

func get_character() -> CustomCharacter:
	var character: CustomCharacter = CustomCharacter.new()
	character.code_name = code_name
	character.display_name = _display_name
	character.packed_scene = _packed_scene
	return character
