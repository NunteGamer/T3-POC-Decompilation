extends Camera2D

@export var main_game_controller: Node
@export var screen_texture_rect: TextureRect
@export var screen_svc: SubViewportContainer
@export var screen_sv: SubViewport
@export var camera_controler: Node
@export var bg_container: Node2D
@export var charas_container: Node
@export var ui_layer: CanvasLayer
@export var dialogue_label: RichTextLabel

var _screen_size: Vector2
var game_scene: Node

func _ready() -> void:
	# change window resolution
	DisplayServer.window_set_size(Vector2(1440, 1080))
	
	# subscribe to size_changed
	get_tree().root.connect("size_changed", on_size_changed)
	
	# resize and center nodes
	on_size_changed()


func on_size_changed():
	_screen_size = get_screen_size()
	
	if(main_game_controller.get_mode() == 0):
		center_screen_svc(false)
		center_ui(false)
		
	# reposition the charas to match their anchors
	charas_container.reposition_charas()
	# reposition bg to fill the whole screen
	bg_container.set_parallax_position()
	camera_controler.reposition_camera()
	if(main_game_controller.get_mode() == 1):
		reposition_screen_svc(false)
		position_game_scene(false, false)
		reposition_pieces()
		reposition_ui(false)


# return either the window size or the texture rect size; the smaller of the two
func get_screen_size() -> Vector2:
	var _window_size: Vector2 = get_tree().root.get_visible_rect().size
	_screen_size = Vector2(min(_window_size.x, screen_texture_rect.size.x), min(_window_size.y, screen_texture_rect.size.y))
	return _screen_size


func anchor_to_pos(_anchor: float) -> float:
	# given an anchor, get the matching x position
	var _position_x: float
	_position_x = (get_screen_size().x/2) * _anchor
	return _position_x


func pos_to_anchor(_position_x: float) -> float:
	# given a pos, return the matching anchor
	var _anchor: float
	_anchor = _position_x / (get_screen_size().x/2)
	return _anchor


func center_screen_svc(_just_get_the_position: bool) -> Vector2:
	# get the difference in size between the svc and the mask(max screen size)
	var _difference: float = screen_svc.size.x - screen_texture_rect.size.x
	# -half the difference will leave the svc at the center of the screen
	var _center_position_x: float = _difference/-2
	
	var _final_pos: Vector2 = Vector2(_center_position_x, screen_svc.position.y)
	
	if(!_just_get_the_position):
		screen_svc.position = _final_pos
	return _final_pos
	


func reposition_screen_svc(_just_get_the_position: bool) -> Vector2:
	# get the centered position of the svc
	var _centered_position: Vector2 = center_screen_svc(true)
	# get the position of the game scene (left edge)
	var _game_scene_position: Vector2 = position_game_scene(false, true)
	
	# calculate the distance between the game scene left edge and the screen left edge
	# _game_scene_position.x should either be a negative number or 0
	var _vn_space: float = _screen_size.x/2 + _game_scene_position.x
	# get the center point
	var _center_of_vn_space: float = _vn_space/-2 + _game_scene_position.x
	# add it to the centered position of the svc to get the final offset position
	var _offset: float = _centered_position.x + _center_of_vn_space
	# set it
	var _final_pos: Vector2 = Vector2(_offset, screen_svc.position.y)
	if(!_just_get_the_position):
		screen_svc.position = _final_pos
	return _final_pos
	


func center_ui(_just_get_the_position: bool) -> Vector2:
	var _centered_position: Vector2 = Vector2(0, 0)
	if(!_just_get_the_position):
		ui_layer.offset = _centered_position
		dialogue_label.size.x = 1000
	return _centered_position
	


func reposition_ui(_just_get_the_position: bool) -> Vector2:
	var _centered_position: Vector2 = Vector2(0, 0)
	
	# get the position of the game scene (left edge)
	var _game_scene_position: Vector2 = position_game_scene(false, true)
	
	var _actual_screen_size: Vector2 = get_screen_size()
	var _left_screen_edge: float = _actual_screen_size.x/2
	# 1584 is the max position for _left_screen_edge, when the screen is widest
	var _distance_from_max_left_screen_edge: float = _left_screen_edge - 1584
	# this is basically a magic number
	var _offset_x: float = _distance_from_max_left_screen_edge/-3

	var _final_pos: Vector2 = Vector2(_offset_x, ui_layer.offset.y)
	if(!_just_get_the_position):
		ui_layer.offset = _final_pos
		# change dialogue label size, so text doesn't overflow
		var _vn_space: float = _screen_size.x/2 + _game_scene_position.x
		
		# 500 is the fixed offset of the dialogue box from the center
		var left_dialogue_box_edge: float = _left_screen_edge + (_vn_space/2) - 500 + _offset_x
		
		# distance from the left of the dialogue box to the left window edge
		var left_margin: float = _left_screen_edge - left_dialogue_box_edge
		
		dialogue_label.size.x = _vn_space - abs(left_margin*2)
	
	return _final_pos
	


func position_game_scene(_offscreen: bool, _just_get_the_position: bool):
	var _actual_screen_size: Vector2 = get_screen_size()
	var _screen_half_size: float = _actual_screen_size.x/2
	
	
	# the texture rect centered y is -half the screen height
	var _center_y: float = _actual_screen_size.y/-2
	
	# aspect ratio 1000:1125 (0.888)
	var _game_minimum_size: float = _actual_screen_size.y * 0.888
	
	# get the target center x,the position of the left edge of the texture rect
	# in order for it to be take the right half of the screen,
	# or more if the right side is smaller than _game_minimum_size
	var _target_center_x: float = 0 # texture left edge in the middle of the screen
	
	# if screen too narrow, move the texture to the left so the whole board fits onscreen
	if(_screen_half_size < _game_minimum_size):
		# left edge at right screen edge
		_target_center_x += _screen_half_size
		# left edge at minimun game size from right screen edge
		_target_center_x -= _game_minimum_size
	
	# apply the position to the texture rect
	var _final_pos: Vector2 = Vector2(_target_center_x, _center_y)
	if(_just_get_the_position):
		if(_offscreen):
			return Vector2(_screen_half_size, _final_pos.y)
		else:
			return _final_pos
	if(_offscreen):
		# if _offscreen, place the texture offscreen
		game_scene.T3_scene_texture_rect.position = Vector2(_screen_half_size, _final_pos.y)
	else:
		game_scene.T3_scene_texture_rect.position = _final_pos
	
	
	# now we must position the board inside the texture rect
	# the T3 board pos = 0 is the board centered on the texture's left edge
	var _T3_scene_offset_target_position_x: float
	if(_screen_half_size < _game_minimum_size):
		# if the screen is too narrow, position in the center of the visible texture,
		# which is half of the game's minimum size (starting from the left edge of the texture)
		_T3_scene_offset_target_position_x = _game_minimum_size/2
	else:
		# if the screen is wide enough, position it at half the game's minimum size from the center
		# this means the board will be near the center of the screen, leaving empty space to the right side
		_T3_scene_offset_target_position_x = _screen_half_size/2
	game_scene.T3_scene_offset.position = Vector2(_T3_scene_offset_target_position_x, game_scene.T3_scene_offset.position.y)
	
	
	if(_offscreen): return _final_pos


func reposition_pieces():
	game_scene.game_controller.reposition_pieces()
