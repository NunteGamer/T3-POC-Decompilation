extends Node2D

@export var bg: Sprite2D
@export var script_camera: Camera2D
@export var screen_camera: Camera2D
var blur_shader: ShaderMaterial

var _parallax_level: float
var _motion_blur: Vector2


func _ready() -> void:
	set_process_priority(-1)
	blur_shader = bg.material
	_parallax_level = 0.5
	set_parallax_position.call_deferred()


func _process(_delta):
	#if(camera.position != _previous_camera_pos || camera.zoom != _previous_camera_zoom):
		#_previous_camera_pos = camera.position
		#_previous_camera_zoom = camera.zoom
		##set_parallax_position()
		#screen_camera.center_screen_ui()
	pass


func set_parallax_position():
	# change the bg position to reduce its movement relative to the camera (parallax)
	var _bg_parallax_pos: Vector2 = script_camera.position * _parallax_level
	# just stored, not appied yet
	
	# change scale to reduce the effect of the camera zoom and create visual deepness
	var _cam_zoom: Vector2 = script_camera.zoom
	var _bg_parallax_scale: Vector2 = Vector2(1,1) - ((_cam_zoom - Vector2(1,1))/4)
	self.scale = _bg_parallax_scale
	
	# check if bg is too small to cover the screen on final_position
	var screen_size: Vector2 = screen_camera.get_screen_size()
	var screen_left_edge: float = screen_size.x/-2
	var screen_right_edge: float = screen_size.x/2
	var bg_left_edge: float = calculate_bg_edge(true, _bg_parallax_pos.x)
	var bg_right_edge: float  = calculate_bg_edge(false, _bg_parallax_pos.x)
	
	# if the bg is not covering up to the edge of the camera, move it
	if(bg_left_edge > screen_left_edge):
		# space needed to cover the difference between the screen edge and the left edge
		var _difference: float = abs(screen_left_edge) - abs(bg_left_edge)
		# undo the zoom scale for the actual difference that needs to be applied
		_difference /= _cam_zoom.x
		# apply it
		_bg_parallax_pos.x -= _difference
	elif(bg_right_edge < screen_right_edge):
		# space needed to cover the difference between the screen edge and the left edge
		var _difference: float = abs(screen_right_edge) - abs(bg_right_edge)
		# undo the zoom scale for the actual difference that needs to be applied
		_difference /= _cam_zoom.x
		# apply it
		_bg_parallax_pos.x += _difference
	
	# recalculate edges for debug purposes only, it case you need to make them visual
	bg_left_edge = calculate_bg_edge(true, _bg_parallax_pos.x)
	bg_right_edge = calculate_bg_edge(false, _bg_parallax_pos.x)
	
	# apply the final position
	self.position = _bg_parallax_pos
	
	# if zoom, blur the bg accordingly
	var _blur: Vector2 = (_bg_parallax_scale - Vector2(1,1)) * 6
	# if motion blur is being applied, add it to avoid overwriting it
	_blur += _motion_blur
	blur_shader.set_shader_parameter("step",  _blur)


func calculate_bg_edge(_left: bool, _bg_parallax_pos: float) -> float:
	var _sign: float = 1
	if(_left): _sign = -1
	var _edge_x: float
	var bg_size: Vector2 = bg.texture.get_size() * self.scale
	# get the position x of both edges of the bg and the camera
	# if bg was centered and without zoom, this would be it's edge position:
	_edge_x = bg_size.x/(2 * _sign)
	# if camera is not centered, it would be this:
	_edge_x -= script_camera.position.x
	# if camera zoom was added, it would be this:
	_edge_x *= script_camera.zoom.x
	# if bg was not centered but in the position we are going to apply it, it would be this:
	_edge_x += (_bg_parallax_pos * script_camera.zoom.x)
	return _edge_x


func set_motion_blur(intensity: float):
	var _cam_zoom: Vector2 = script_camera.zoom
	blur_shader.set_shader_parameter("step", Vector2(intensity * _cam_zoom.x,(intensity * _cam_zoom.y)/4))
	_motion_blur = blur_shader.get_shader_parameter("step")
