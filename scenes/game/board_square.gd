extends Area2D

@export var game_controller: Node
@export var highlight: ColorRect

var _cursor_inside: bool


func _ready() -> void:
	self.connect("mouse_entered", _on_mouse_entered)
	self.connect("mouse_exited", _on_mouse_exited)


func _on_mouse_entered():
	_cursor_inside = true
	if(!game_controller.is_playable()): return
	highlight.visible = true
	
	game_controller.board_controller.game_audio_controller.play_square_highlight()


func _on_mouse_exited():
	_cursor_inside = false
	if(!game_controller.is_playable()): return
	highlight.visible = false


func unhighlight():
	highlight.visible = false


func reactivate():
	if(_cursor_inside):
		highlight.visible = true
	else:
		highlight.visible = false

