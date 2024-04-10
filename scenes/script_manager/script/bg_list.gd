extends Node

@export var bgs: Array[BackgroundResource]


func get_bg(_name: String) -> Texture:
	for bg in bgs:
		if(bg.get_bg_name() == _name):
			return bg.get_bg_texture()
	return null
