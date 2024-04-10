extends Node

@export var music_controller: Node

func parse_audio(keywords: PackedStringArray):
	
	match keywords[0]:
		"music":
			keywords.remove_at(0)
			music_controller.parse_music(keywords)
		"sfx":
			keywords.remove_at(0)
			_parse_music(keywords)
		"ambient":
			keywords.remove_at(0)
			_parse_music(keywords)


func _parse_music(keywords: PackedStringArray):
	pass


func _parse_sfx(keywords: PackedStringArray):
	pass


func _parse_ambient(keywords: PackedStringArray):
	pass
