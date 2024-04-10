extends CanvasLayer

@onready var panel : ColorRect = $ColorRect
var tween : Tween

func fade(color: Color, time: float):
	self.visible = true
	
	# if fadeout, ensure panel is not transparent
	var initial_color: Color = panel.modulate
	if(color == Color.TRANSPARENT):
		initial_color = Color(initial_color.r, initial_color.g, initial_color.b, 1)
	# if fadein, ensure panel is final color with alpha 0
	else:
		initial_color = Color(color.r, color.g, color.b, 0)
	panel.modulate = initial_color
	
	tween = create_tween()
	tween.tween_property(panel, "modulate", color, time)

func skip():
	if(tween != null && tween.is_running()):
		tween.custom_step(999)
