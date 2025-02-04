class_name FlairButton
extends Control

signal pressed(s: Node)

var id

func setup(flair_data):
	id = flair_data.id
	%Flair.text = "  %s  " % flair_data.text
	%Flair.add_theme_color_override("font_color", flair_data.color)
	var contrast_color = Global.get_contrast_background(flair_data.color)
	%Flair.get_node("BG").modulate = contrast_color
	%Reason.text = flair_data.description


func press():
	$Button.set_pressed_no_signal(true)


func unpress():
	$Button.set_pressed_no_signal(false)

func is_pressed() -> bool:
	return $Button.button_pressed


func _on_button_toggled(_button_pressed: bool) -> void:
	pressed.emit(self)
