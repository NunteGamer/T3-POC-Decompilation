extends Node

@export var screen_camera: Camera2D
@export var chara_controller: Node

func reposition_charas():
	var _screen_size: Vector2 = screen_camera.get_screen_size()
	var _screen_sv_size: Vector2 = screen_camera.get_screen_size()
	
	var present_charas: Dictionary = chara_controller.get_present_charas()
	var new_position: Vector2
	# run though all the present charas
	for chara_name in present_charas:
		# their fixed position should be half the window size, or half the sv size, if it's smaller
		# ignore the y axis
		var chara: CustomCharacter = present_charas[chara_name]
		new_position = Vector2(min((_screen_size.x/2), (_screen_sv_size.x/2)) * chara.anchor, chara.instance.position.y)
		chara.instance.position = new_position
		chara.position = new_position
