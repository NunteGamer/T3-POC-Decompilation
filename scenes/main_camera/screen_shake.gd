extends Node

@export var camera: Camera2D
var _intensity: int = 3

var original_position: Vector2
var shake_remaining_time: float


func _process(delta: float) -> void:
	# while there is shake time, keep calling do_shake
	if(shake_remaining_time > 0):
		_do_shake()
		# reduce shake time
		shake_remaining_time -= delta
		# if no more shake time, center the camera
		if(shake_remaining_time <= 0):
			camera.position = original_position


func shake(_duration: float, _intensity_level: int):
	# initialize shake
	original_position = camera.position
	shake_remaining_time = _duration
	# turn intensity level into pixels
	if(_intensity_level == 1):
		_intensity = 5
	elif(_intensity_level == 2):
		_intensity = 10
	elif(_intensity_level == 3):
		_intensity = 20


func _do_shake():
	var factor_x = randi_range(-_intensity, _intensity)
	var factor_y = randi_range(-_intensity, _intensity)
	camera.position = Vector2(original_position.x + factor_x, original_position.y + factor_y)


func cancel():
	shake_remaining_time = 0
	
