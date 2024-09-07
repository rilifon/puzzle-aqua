class_name Hint
extends Control

signal left_clicked

const COLORS = {
	"normal": {
		"dark": Color("#000924ff"),
	},
	"dark": {
		"dark": Color(0.671, 1, 0.82),
	}
}
const ALPHA_SPEED = 4.0
const HIDE_ALPHA = 0.5
const HIGHLIGHT_SPEED = 5.0
const FADE_SPEED = 2.0

@export var is_cell_hint := false

@onready var Hints = {
	E.Walls.Top: $Hints/Top,
	E.Walls.Right: $Hints/Right,
	E.Walls.Bottom: $Hints/Bottom,
	E.Walls.Left:$Hints/Left,
}
@onready var ContentContainer = $VBoxContainer
@onready var EditorButtons = $VBoxContainer/EditorButtons
@onready var ToggleHintType: TextureButton = $VBoxContainer/EditorButtons/ToggleHintType
@onready var ToggleVisibility: TextureButton = $VBoxContainer/EditorButtons/ToggleVisibility
@onready var HintsContainer = $VBoxContainer/HintsContainer
@onready var Number = %Number
@onready var Boat = %Boat
@onready var DummyLabel = %DummyLabel
@onready var Highlight = %Highlight

var editor_mode := false
var hint_type : E.HintType = E.HintType.Hidden
var is_boat := false
var hint_value := 0.0
var hint_alpha := 1.0
var is_dummy := false
var highlight := false
var cur_status : E.HintStatus = E.HintStatus.Normal
var fade_out := false
var grid

func _ready():
	Profile.dark_mode_toggled.connect(update_dark_mode)
	Profile.bigger_hints_changed.connect(update_bigger_hint)
	Profile.hide_unknown_changed.connect(hide_unknown_changed)
	Highlight.modulate.a = 0.0
	disable_editor()
	DummyLabel.hide()
	set_boat(false)
	set_status(E.HintStatus.Normal)
	%Completed.modulate.a = 0
	for side in Hints.keys():
		set_hint_visibility(side, true)
	
	hint_alpha = 1.0 if ToggleHintType.is_pressed() else 0.0
	update_label()
	
	update_dark_mode(Profile.get_option("dark_mode"))
	update_bigger_hint(Profile.get_option("bigger_hints_font"))

func hide_unknown_changed(_on: bool) -> void:
	update_label()

func _process(dt):
	Global.alpha_fade_node(dt, Highlight, highlight, HIGHLIGHT_SPEED)
	Global.alpha_fade_node(dt, self, not fade_out, FADE_SPEED, false, 1.0, .3)
	
	
	if is_dummy:
		return
	
	if ToggleHintType.is_pressed():
		if hint_alpha < 1.0:
			hint_alpha = min(hint_alpha + ALPHA_SPEED*dt, 1.0)
			update_label()
	else:
		if hint_alpha > 0.0:
			hint_alpha = max(hint_alpha - ALPHA_SPEED*dt, 0.0)
			update_label()
	
	var allow_unknown = true
	if not Profile.get_option("progress_on_unknown"):
		allow_unknown = hint_value != -1
	var opt_highlight: bool = Profile.get_option("highlight_finished_cell_hint" if is_cell_hint else "highlight_finished_row_col")
	Global.alpha_fade_node(dt, %Completed, not editor_mode and cur_status == E.HintStatus.Satisfied and allow_unknown and opt_highlight)
	Global.alpha_fade_node(dt, HintsContainer, ToggleVisibility.is_pressed(), ALPHA_SPEED, false, 1.0, HIDE_ALPHA)


func update_dark_mode(is_dark : bool) -> void:
	var colors = COLORS.dark if is_dark else COLORS.normal
	%Hints.modulate = colors.dark
	%Boat.modulate = colors.dark
	%BigHintBoat.modulate = colors.dark


func update_bigger_hint(is_big: bool) -> void:
	if is_big and not editor_mode:
		Number.add_theme_font_size_override("normal_font_size", 190)
		DummyLabel.add_theme_font_size_override("font_size", 230)
	else:
		Number.add_theme_font_size_override("normal_font_size", 128)
		DummyLabel.add_theme_font_size_override("font_size", 160)
	if is_boat:
		if is_big and not editor_mode:
			%BigHintBoat.show()
			Boat.hide()
		else:
			Boat.show()
			%BigHintBoat.hide()


func set_boat(value):
	is_boat = value
	if Profile.get_option("bigger_hints_font") and not editor_mode:
		%BigHintBoat.visible = value
		Boat.hide()
	else:
		Boat.visible = value
		%BigHintBoat.hide()


func set_value(new_value : float) -> void:
	hint_value = new_value
	update_label()


func set_highlight(value: bool) -> void:
	highlight = value


func set_hint_type(new_type : E.HintType) -> void:
	hint_type = new_type
	update_label()

func should_be_visible() -> bool:
	return ToggleVisibility.is_pressed()

func should_have_type() -> bool:
	return ToggleHintType.is_pressed()

func set_visibility(vis: bool, type: bool) -> void:
	ToggleVisibility.set_pressed(vis)
	ToggleHintType.set_pressed(type)


func alpha_t(text : String, alpha : float) -> String:
	var color = Global.COLORS.normal
	color.a = alpha
	return "[color=%s]%s[/color]" % ["#"+color.to_html(true),text]


func update_label() -> void:
	Number.text = ""
	var value = str(hint_value) if hint_value != -1 else "?"
	var hidden_or_zero := hint_type == E.HintType.Hidden or hint_type == E.HintType.Zero
	if not editor_mode and hint_value == -1 and hidden_or_zero  and Profile.get_option("hide_unknown"):
		value = " "
	if editor_mode and (value == "0" or value == "?"):
		value = "  "+value+"  " 
	if is_boat:
		set_visible(hint_value != -1 or not hidden_or_zero)
	match hint_type:
		E.HintType.Zero, E.HintType.Hidden:
			Number.text += value
			DummyLabel.text = "?"
		E.HintType.Together:
			if editor_mode:
				Number.text += alpha_t("{ ", hint_alpha) + value + alpha_t(" }", hint_alpha)
			else:
				Number.text += "{ " + value + " }"
				DummyLabel.text = "{ ? }"
		E.HintType.Separated:
			if editor_mode:
				Number.text += alpha_t("- ", hint_alpha) + value + alpha_t(" -", hint_alpha)
			else:
				Number.text += "- " + value + " -"
				DummyLabel.text = "- ? -"
	Number.text = "[center]"+Number.text+"[/center]"


func no_hint() -> void:
	Number.text = ""
	hide()


func dummy_hint() -> void:
	is_dummy = true
	show()
	DummyLabel.show()
	ContentContainer.hide()


func set_hint_visibility(which : E.Walls, value : bool) -> void:
	Hints[which].visible = value


func set_status(status: E.HintStatus) -> void:
	cur_status = status
	if hint_value == -1 and not Profile.get_option("progress_on_unknown"):
		Number.add_theme_color_override("default_color", Global.COLORS.normal)
	else:
		match status:
			E.HintStatus.Normal:
				Number.add_theme_color_override("default_color", Global.COLORS.normal)
			E.HintStatus.Satisfied:
				Number.add_theme_color_override("default_color", Global.COLORS.satisfied)
			E.HintStatus.Wrong:
				Number.add_theme_color_override("default_color", Global.COLORS.error)


func enable_editor() -> void:
	editor_mode = true
	EditorButtons.show()
	if is_boat:
		ToggleVisibility.set_pressed(false)
	ToggleHintType.set_pressed(false)
	update_bigger_hint(Profile.get_option("bigger_hints_font"))


func disable_editor() -> void:
	editor_mode = false
	EditorButtons.hide()


func toggle_fade():
	if not grid or grid.disabled:
		return
	fade_out = not fade_out


func _on_gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			toggle_fade()
		elif hint_value != -1:
			left_clicked.emit()
