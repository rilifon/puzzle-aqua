extends Control

const IMAGES = {
	"dark": {
		"picker_pressed": preload("res://assets/images/ui/brush/brush_picker_pressed_dark.png"),
		"picker_hover": preload("res://assets/images/ui/brush/brush_picker_hover_dark.png"),
	},
	"normal": {
		"picker_pressed": preload("res://assets/images/ui/brush/brush_picker_pressed.png"),
		"picker_hover": preload("res://assets/images/ui/brush/brush_picker_hover.png"),
	}
}
const MARKER_SIZES = [
	{
		"width": 15,
		"icon": preload("res://assets/images/ui/icons/small_brush.png"),
	},
	{
		"width": 20,
		"icon": preload("res://assets/images/ui/icons/medium_brush.png"),
	},
	{
		"width": 30,
		"icon": preload("res://assets/images/ui/icons/large_brush.png"),
	},
]
const MARKER_COLORS = [Color(1.0,0.416,0.416), Color(0.1,0.2,1.0), Color(1.0,0.95,0.45), Color("#3adc6b")]

signal brushed_picked(mode : E.BrushMode)
signal marker_button_toggled(on : bool)
signal clear_markers
signal toggle_marker_visibility(off : bool)
signal toggle_marker_eraser(on : bool)
signal change_marker_width(width : float)
signal change_marker_color(color : Color)

var editor_mode := false
var active := true
var marker_color_idx = 0
var marker_size_idx = 0
var marker_mode_active = false

@onready var Images = {
	"self": $CenterContainer/HBoxContainer/PanelContainer/Images,
	E.BrushMode.Water: $CenterContainer/HBoxContainer/PanelContainer/Images/Water,
	E.BrushMode.NoWater: $CenterContainer/HBoxContainer/PanelContainer/Images/NoWater,
	E.BrushMode.Boat: $CenterContainer/HBoxContainer/PanelContainer/Images/Boat,
	E.BrushMode.NoBoat: $CenterContainer/HBoxContainer/PanelContainer/Images/NoBoat,
	E.BrushMode.Wall: $CenterContainer/HBoxContainer/PanelContainer/Images/Wall,
	E.BrushMode.Block: $CenterContainer/HBoxContainer/PanelContainer/Images/Block,
	E.BrushMode.CellHints: $CenterContainer/HBoxContainer/PanelContainer/Images/CellHints,
}
@onready var ButtonsContainer = $CenterContainer/HBoxContainer/PanelContainer/Buttons
@onready var Buttons = {
	E.BrushMode.Water: $CenterContainer/HBoxContainer/PanelContainer/Buttons/Water,
	E.BrushMode.NoWater: $CenterContainer/HBoxContainer/PanelContainer/Buttons/NoWater,
	E.BrushMode.Boat: $CenterContainer/HBoxContainer/PanelContainer/Buttons/Boat,
	E.BrushMode.NoBoat: $CenterContainer/HBoxContainer/PanelContainer/Buttons/NoBoat,
	E.BrushMode.Wall: $CenterContainer/HBoxContainer/PanelContainer/Buttons/Wall,
	E.BrushMode.Block: $CenterContainer/HBoxContainer/PanelContainer/Buttons/Block,
	E.BrushMode.CellHints: $CenterContainer/HBoxContainer/PanelContainer/Buttons/CellHints,
}
@onready var AnimPlayer: AnimationPlayer = $AnimationPlayer

func _ready():
	%PanelContainer.visible = true
	%MarkerContainer.visible = false
	Profile.dark_mode_toggled.connect(_on_dark_mode_changed)
	_on_dark_mode_changed(Profile.get_option("dark_mode"))
	setup(editor_mode, false)
	for button in E.BrushMode.values():
		(Buttons[button] as TextureButton).pressed.connect(_on_button_pressed.bind(button))
	AnimPlayer.play("startup")


func _unhandled_input(event):
	if not active:
		return
	if event.is_action_pressed("pick_prev_brush"):
		if not marker_mode_active:
			pick_previous_brush()
		else:
			pick_previous_marker_color()
	elif event.is_action_pressed("pick_next_brush"):
		if not marker_mode_active:
			pick_next_brush()
		else:
			pick_next_marker_color()
	elif event.is_action_pressed("toggle_marker_mode"):
		_on_marker_button_toggled(not marker_mode_active)
	if event is InputEventKey:
		if event.pressed and event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var valid := get_valid_buttons()
			if event.keycode - KEY_1 < valid.size():
				_on_button_pressed(valid[event.keycode - KEY_1])


func set_paint_mode_visible(status : bool):
	%MarkerButton.visible = status


func nowater_finger_anim(should_show: bool) -> void:
	if should_show:
		%NoWater/FingerAnim.show()
	else:
		%NoWater/FingerAnim.queue_free()



func disable():
	active = false
	hide()


func setup(editor_mode_: bool, fast_mode: bool) -> void:
	editor_mode = editor_mode_
	for editor_button in [E.BrushMode.Wall, E.BrushMode.Block, E.BrushMode.CellHints]:
		Images[editor_button].set_visible(editor_mode)
		Buttons[editor_button].set_visible(editor_mode)
	for editor_button in [E.BrushMode.NoWater, E.BrushMode.NoBoat]:
		Images[editor_button].set_visible(not editor_mode)
		Buttons[editor_button].set_visible(not editor_mode)
	for button in Buttons.keys():
		Buttons[button].button_pressed = (button == E.BrushMode.Water)
	custom_minimum_size = ButtonsContainer.size
	if fast_mode:
		AnimPlayer.advance(AnimPlayer.current_animation_length)


func enable_brush(brush_type : E.BrushMode) -> void:
	Images[brush_type].set_visible(true)
	Buttons[brush_type].set_visible(true)


func disable_brush(brush_type : E.BrushMode) -> void:
	Images[brush_type].set_visible(false)
	Buttons[brush_type].set_visible(false)


func get_valid_buttons() -> Array[E.BrushMode]:
	var valid_buttons: Array[E.BrushMode] = []
	for button_key in Buttons.keys():
		var button_node = Buttons[button_key]
		if button_node.visible:
			valid_buttons.push_back(button_key)
	return valid_buttons


func pick_next_brush() -> void:
	var valid_buttons := get_valid_buttons()
	assert(not valid_buttons.is_empty(), "No brush visible to pick next")
	
	var i = 0
	for button_key in valid_buttons:
		var button_node = Buttons[button_key]
		i += 1
		if button_node.button_pressed:
			break
	i = i % valid_buttons.size()
	_on_button_pressed(valid_buttons[i])


func pick_previous_brush() -> void:
	var valid_buttons := get_valid_buttons()
	assert(not valid_buttons.is_empty(), "No brush visible to pick next")
	
	var i = valid_buttons.size() - 1
	for button_key in valid_buttons:
		var button_node = Buttons[button_key]
		if button_node.button_pressed:
			break
		i += 1
	i = i % valid_buttons.size()
	_on_button_pressed(valid_buttons[i])


func unpress_marker_button():
	if %MarkerButton.button_pressed:
		%MarkerButton.button_pressed = false


func switch_eraser_mode():
	%Eraser.button_pressed = not %Eraser.button_pressed 


func switch_marker_visibility_mode():
	%Visibility.button_pressed = not %Visibility.button_pressed 


func return_marker_buttons_state():
	if %Eraser.button_pressed:
		switch_eraser_mode()
	if %Visibility.button_pressed:
		switch_marker_visibility_mode()


func pick_next_marker_color():
	return_marker_buttons_state()
	marker_color_idx = (marker_color_idx + 1)%MARKER_COLORS.size()
	var color = MARKER_COLORS[marker_color_idx]
	%MarkerColor.modulate = color
	change_marker_color.emit(color)


func pick_previous_marker_color():
	return_marker_buttons_state()
	marker_color_idx = (marker_color_idx - 1)%MARKER_COLORS.size()
	var color = MARKER_COLORS[marker_color_idx]
	%MarkerColor.modulate = color
	change_marker_color.emit(color)


func _on_button_pressed(mode: E.BrushMode):
	AudioManager.play_sfx("change_brush")
	if mode == E.BrushMode.NoWater and %NoWater.has_node("FingerAnim"):
		var player: AnimationPlayer = %NoWater/FingerAnim/AnimationPlayer
		if player.assigned_animation != "disappear":
			player.play(&"disappear")
	# Doing radio logic by hand since Godot`s isn`t working for some reason
	for button in Buttons.keys():
		Buttons[button].button_pressed = (button == mode)
	brushed_picked.emit(mode)


func _on_dark_mode_changed(is_dark):
	var color = Global.get_color(is_dark)
	var images = IMAGES.dark if is_dark else IMAGES.normal
	%Boat.modulate = color.dark
	%Wall.modulate = color.dark
	%Block.modulate = color.dark
	%CellHints.modulate = color.dark
	%Water.material.set_shader_parameter(&"water_color", color.water_color)
	%Water.material.set_shader_parameter(&"depth_color", color.depth_color)
	%Water.material.set_shader_parameter(&"ray_value", color.ray_value)
	%NoBoat.self_modulate = color.dark
	for button in Buttons.values():
		button.texture_pressed = images.picker_pressed
		button.texture_hover = images.picker_hover


func _on_button_mouse_entered():
	AudioManager.play_sfx("button_hover")


func _on_marker_button_toggled(button_pressed):
	AudioManager.play_sfx("change_brush")
	marker_mode_active = button_pressed
	%PanelContainer.visible = not button_pressed
	%MarkerContainer.visible = button_pressed
	if marker_mode_active:
		return_marker_buttons_state()
	marker_button_toggled.emit(button_pressed)


func _on_clear_pressed():
	return_marker_buttons_state()
	AudioManager.play_sfx("button_pressed")
	clear_markers.emit()


func _on_visibility_toggled(button_pressed):
	if button_pressed:
		AudioManager.play_sfx("button_back")
		%Visibility.modulate.a = 0.5
	else:
		AudioManager.play_sfx("button_pressed")
		%Visibility.modulate.a = 1.0
	toggle_marker_visibility.emit(button_pressed)


func _on_eraser_toggled(button_pressed):
	AudioManager.play_sfx("button_pressed")
	toggle_marker_eraser.emit(button_pressed)


func _on_brush_color_pressed():
	pick_next_marker_color()


func _on_brush_size_pressed():
	return_marker_buttons_state()
	marker_size_idx = (marker_size_idx + 1)%MARKER_SIZES.size()
	var data = MARKER_SIZES[marker_size_idx]
	%MarkerSize.icon = data.icon
	change_marker_width.emit(data.width)
