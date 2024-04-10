extends Node

@export var debug_print: bool
@export var code_parser: Node
@export var fade: CanvasLayer

var timer: SceneTreeTimer

func parse_fade(keywords: PackedStringArray, instant:bool):
	if(keywords[0] == "fadein"):
		keywords.remove_at(0)
		_manage_fadein(keywords, false, instant)
	elif(keywords[0] == "fadeout"):
		keywords.remove_at(0)
		_manage_fadeout(keywords, false, instant)

func rollback_fade(keywords: PackedStringArray, instant:bool):
	if(keywords[0] == "fadein"):
		keywords.remove_at(0)
		_manage_fadeout(keywords, true, instant)
	elif(keywords[0] == "fadeout"):
		keywords.remove_at(0)
		_manage_fadein(keywords, true, instant)


func _manage_fadein(keywords: PackedStringArray, rollback:bool, instant:bool):
	var duration: float = 1 # default duration
	var color: Color = Color.BLACK # default color
	var color_name: String = "default"
	
	# get duration if it was stated
	if(keywords.size() > 1):
		duration = float(keywords[1])
	if(instant): duration = 0
	
	# get color if it was stated
	if(keywords.size() > 0 && keywords[0] != ""):
		color_name = keywords[0]
		if(color_name == "black"):
			color = Color.BLACK
		elif(color_name == "white"):
			color = Color.WHITE
	
	# call fade
	fade.fade(color, duration)
	if(debug_print): print("FadeController: Fading in to color '" + color_name + "' ('" + str(color) + "'). Duration: " + str(duration) + ". Instant: " + str(instant))
	
	# set timer to call code finished
	timer = get_tree().create_timer(duration)
	if(rollback):
		timer.connect("timeout", _on_rollback_fade_timer_ends)
	else:
		timer.connect("timeout", _on_fade_timer_ends)

func _manage_fadeout(keywords: PackedStringArray, rollback:bool, instant:bool):
	# get duration if it was stated
	var duration = 1
	if(keywords.size() > 1):
		duration = float(keywords[1])
	if(instant): duration = 0
	
	# call fade
	fade.fade(Color.TRANSPARENT, duration)
	if(debug_print): print("FadeController: Fading out. Duration: " + str(duration) + ". Instant: " + str(instant))
	
	# set timer to call code finished
	timer = get_tree().create_timer(duration)
	if(rollback):
		timer.connect("timeout", _on_rollback_fade_timer_ends)
	else:
		timer.connect("timeout", _on_fade_timer_ends)

func _on_fade_timer_ends():
	if(debug_print): print("FadeController: Fade finished")
	code_parser.code_finished()

func _on_rollback_fade_timer_ends():
	if(debug_print): print("FadeController: Rollback fade finished")
	code_parser.rollback_finished(false)

func skip():
	fade.skip()
	if(timer != null): 
		timer.set_time_left(0)
		if(debug_print): print("FadeController: Fade skipped")
