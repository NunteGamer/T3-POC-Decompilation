extends Node

@export var lexicon_label: RichTextLabel
@export var lexicon_box: Control

func _ready() -> void:
	# link click
	lexicon_label.connect("meta_clicked", _on_meta_clicked)


# link click
func _on_meta_clicked(_meta):
	_parse_meta(_meta)


func _parse_meta(_meta):
	pass


func show_lexicon_box():
	lexicon_box.visible = true


func hide_lexicon_box():
	lexicon_box.visible = false
