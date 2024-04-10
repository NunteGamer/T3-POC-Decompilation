extends Node

@export var screen_subviewport: SubViewport

# _center_offset.y is to adjust where the feet of the charas should be
const _center_offset: Vector2 = Vector2(0, 900)

func parse_position(position: String) -> float:
	var vector_position_with_anchor: Vector3
	vector_position_with_anchor.y = _center_offset.y
	vector_position_with_anchor.z = 0
	var anchor: float
	
	# parse position string to percentage
	if(position == "center"):
		anchor = 0
	elif(position == "right"):
		anchor = 0.5
	elif(position == "right2"):
		anchor = 1 #0.8
	elif(position == "left"):
		anchor = -0.5
	elif(position == "left2"):
		anchor = -1
	else:
		if(position == "hide"):
			push_error("ERROR: PositionParser: Unrecognized chara position '" + position + "'. Did you set 'hide' as position instead of state?")
		else:
			push_error("ERROR: PositionParser: Unrecognized chara position '" + position + "'")
	return anchor


func parse_depth(_depth: String) -> Vector2:
	var _scale: Vector2
	match _depth:
		"back":
			_scale = Vector2(0.9, 0.9)
		"front":
			_scale = Vector2(1.2, 1.2)
		"middle":
			_scale = Vector2(1, 1)
		
	return _scale


func get_center_offset() -> Vector2:
	return _center_offset
