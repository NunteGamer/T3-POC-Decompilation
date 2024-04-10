extends SubViewport

@export var face_marker: Marker2D
@export var body1: Sprite2D
@export var face1: Sprite2D
@export var face2: Sprite2D
@export var face3: Sprite2D
@export var face4: Sprite2D
@export var hair: Sprite2D


func set_chara(state:String):
	if(state == ""):
		body1.visible = true
		face1.visible = true
		hair.visible = true
	elif(state == "neutral"):
		body1.visible = true
		face1.visible = true
		hair.visible = true
	elif(state == "smiling"):
		body1.visible = true
		hair.visible = true
	elif(state == "angry"):
		body1.visible = true
		face2.visible = true
		hair.visible = true
	elif(state == "smug"):
		body1.visible = true
		face3.visible = true
		hair.visible = true
	elif(state == "sad"):
		body1.visible = true
		face4.visible = true
		hair.visible = true
	else:
		print_debug("State " + state + " does not exist.")
