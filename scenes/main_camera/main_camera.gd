extends Camera2D

@export var screen_shake: Node

func shake(duration: float, intensity: int):
	screen_shake.shake(duration, intensity)


func cancel_screenshake():
	screen_shake.cancel()
