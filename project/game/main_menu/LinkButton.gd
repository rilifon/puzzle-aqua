extends ModulateTextureButton

@export var link: String

func _on_button_pressed() -> void:
	OS.shell_open(link)


func _on_pressed():
	OS.shell_open(link)
