extends Node

@export var name_box: Control
@export var dialogue_box: Control
@export var _color_visible: Color
@export var _color_invisible: Color

@export var script_reader: Node
@export var dialogue_parser: Node

var _fade_duration: float = 0.25
var _namebox_presence: bool
var _dialoguebox_presence: bool

var _tween_namebox: Tween
var _tween_dialoguebox: Tween

func manage_textbox_presence():
	pass


# returns the signal tween.finished
# called from NameParser
func ensure_textbox_presence(_skip: int) -> Signal:
	return _show_textbox(_skip)


func _show_textbox(_skip: int) -> Signal:
	var _actual_fade_duration: float = _fade_duration
	if(_skip > 0):
		_actual_fade_duration = 0
	
	_tween_namebox = create_tween()
	var _color: Color = name_box.modulate
	_tween_namebox.tween_property(name_box, "modulate", Color(_color.r, _color.g, _color.b, 1), _actual_fade_duration)
	
	_tween_dialoguebox = create_tween()
	_color = dialogue_box.modulate
	_tween_dialoguebox.tween_property(dialogue_box, "modulate", Color(_color.r, _color.g, _color.b, 1), _actual_fade_duration)
	
	_namebox_presence = true
	_dialoguebox_presence = true
	return _tween_dialoguebox.finished
	


func _hide_textbox(_skip: int) -> Signal:
	var _actual_fade_duration: float = _fade_duration
	if(_skip > 0):
		_actual_fade_duration = 0
	
	_tween_namebox = create_tween()
	var _color: Color = name_box.modulate
	_tween_namebox.tween_property(name_box, "modulate", Color(_color.r, _color.g, _color.b, 0), _actual_fade_duration)
	
	_tween_dialoguebox = create_tween()
	_color = dialogue_box.modulate
	_tween_dialoguebox.tween_property(dialogue_box, "modulate", Color(_color.r, _color.g, _color.b, 0), _actual_fade_duration)
	
	_namebox_presence = false
	_dialoguebox_presence = false
	return _tween_dialoguebox.finished


func manage_textbox_for_next_line(_skip: int) -> Signal:
	dialogue_parser.clear_dialogue_label()
	
	var _does_chara_keep_speaking: Array[bool] = script_reader.does_character_keep_speaking()
	
	# if any character keeps speaking, do nothing
	if(_does_chara_keep_speaking[0] == true || _does_chara_keep_speaking[1] == true):
		# return a fake signal that will trigger inmediately, since we are doing nothing
		var _timer: SceneTreeTimer = get_tree().create_timer(0)
		return _timer.timeout
	# if text is still typing (<continue> tag), do nothing
	elif(script_reader.is_text_typing()):
		# return a fake signal that will trigger inmediately, since we are doing nothing
		var _timer: SceneTreeTimer = get_tree().create_timer(0)
		return _timer.timeout
	else:
		return _hide_textbox(_skip)
