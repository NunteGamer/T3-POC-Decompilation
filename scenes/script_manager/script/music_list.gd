extends Node

@export var musics: Array[AudioResource]

func get_music(name: String) -> AudioResource:
	for music in musics:
		if(music.name == name):
			return music
	
	push_error("MusicList: The music '" + name + "' is not on the list.")
	return null
