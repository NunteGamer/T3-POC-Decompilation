extends Node2D

@export var sprite_2d: Sprite2D
@export var sprite_x: Texture2D
@export var sprite_o: Texture2D

func set_sprite(sprite: String):
	if(sprite == "x"):
		sprite_2d.texture = sprite_x
	elif(sprite == "o"):
		sprite_2d.texture = sprite_o
