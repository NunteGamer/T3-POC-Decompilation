extends SubViewport

@export var body1: Sprite2D
@export var face1: Sprite2D
@export var face2: Sprite2D
@export var eyes1: Sprite2D
@export var eyes2: Sprite2D

func set_chara(state:String):
	if(state == ""):
		body1.visible = true
		face1.visible = true
		#eyes1.visible = true
	elif(state == "smiling"):
		body1.visible = true
		face1.visible = true
		#eyes1.visible = true
	elif(state == "smiling_up"):
		body1.visible = true
		face1.visible = true
		#eyes2.visible = true
	elif(state == "angry"):
		body1.visible = true
		face2.visible = true
	else:
		print_debug("State " + state + " does not exist.")
