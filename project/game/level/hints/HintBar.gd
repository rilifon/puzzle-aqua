class_name HintBar
extends Control

const HINT = preload("res://game/level/hints/Hint.tscn")
const WATER_COUNT_VISIBLE := 1
const WATER_TYPE_VISIBLE := 2
const BOAT_COUNT_VISIBLE := 4
const BOAT_TYPE_VISIBLE := 8

signal mouse_entered_hint(idx : int)
signal left_clicked_hint(idx : int)

@export var is_horizontal := false
@export_range(0.0, 1.0) var max_alpha: float = 1.0

@onready var Horizontal = $Horizontal
@onready var Vertical = $Vertical

func _ready():
	Profile.hide_unknown_changed.connect(hide_unknown_changed)
	Vertical.visible = not is_horizontal
	Horizontal.visible = is_horizontal
	for child in Vertical.get_children():
		Vertical.remove_child(child)
		child.queue_free()
	for child in Horizontal.get_children():
		Horizontal.remove_child(child)
		child.queue_free()


func setup(grid, hints : Array, editor_mode : bool, swap_water_boat := false) -> void:
	var bar = Horizontal if is_horizontal else Vertical
	# Let's not remove all children to keep the current visibility when adding/removing rows
	# Removing then adding does not keep the same value, but that's fine enough
	while bar.get_child_count() > hints.size():
		var child := bar.get_child(bar.get_child_count() - 1)
		bar.remove_child(child)
		child.queue_free()
	while bar.get_child_count() < hints.size():
		var i := bar.get_child_count()
		var container := (VBoxContainer.new() as BoxContainer) if is_horizontal else (HBoxContainer.new() as BoxContainer)
		container.alignment = BoxContainer.ALIGNMENT_END
		container.add_theme_constant_override("separation", 0)
		bar.add_child(container)
		var boat_hint = create_hint(grid, container, editor_mode, true, hints[i].boat_count, hints[i].boat_count_type)
		var water_hint = create_hint(grid, container, editor_mode, false, hints[i].water_count, hints[i].water_count_type)
		boat_hint.mouse_entered.connect(_on_hint_mouse_entered.bind(i))
		water_hint.mouse_entered.connect(_on_hint_mouse_entered.bind(i))
		if not editor_mode:
			water_hint.left_clicked.connect(_on_hint_left_clicked.bind(i))
		if swap_water_boat:
			boat_hint.move_to_front()
			container.alignment = BoxContainer.ALIGNMENT_BEGIN
	update_hint_walls()

	await get_tree().process_frame
	custom_minimum_size = bar.size

func get_water_hint(i: int) -> Hint:
	var bar = Horizontal if is_horizontal else Vertical
	for c in bar.get_child(i).get_children():
		if not c.is_boat:
			return c
	return null

func hide_unknown_changed(_on: bool) -> void:
	update_hint_walls()

func update_hint_walls() -> void:
	# It looks a bit weird with this
	if true:
		return
	var bar = Horizontal if is_horizontal else Vertical
	var hide_unknown: bool = Profile.get_option("hide_unknown")
	for i in bar.get_child_count():
		var hint: Hint = get_water_hint(i)
		var is_hidden := hide_unknown and hint.can_be_hidden()
		var is_prev_hidden: bool = hide_unknown and (i == 0 or get_water_hint(i - 1).can_be_hidden())
		var is_next_hidden: bool = hide_unknown and (i == bar.get_child_count() - 1 or get_water_hint(i + 1).can_be_hidden())
		hint.set_hint_visibility(E.Walls.Top, not is_horizontal and not (is_hidden and is_prev_hidden))
		hint.set_hint_visibility(E.Walls.Bottom, not is_horizontal and not (is_hidden and is_next_hidden))
		hint.set_hint_visibility(E.Walls.Left, is_horizontal and not (is_hidden and is_prev_hidden))
		hint.set_hint_visibility(E.Walls.Right, is_horizontal and not (is_hidden and is_next_hidden))


func startup(editor_mode : bool, delay : float, fast_startup : bool) -> void:
	if not editor_mode and not fast_startup:
		modulate.a = 0.0
		await get_tree().create_timer(delay).timeout
		create_tween().tween_property(self, 'modulate:a', max_alpha, 1)
	else:
		modulate.a = max_alpha


func create_hint(grid : Node, container : Container, editor_mode : bool, is_boat: float, hint_value : float, type: E.HintType) -> Node:
	var new_hint = HINT.instantiate()
	new_hint.grid = grid
	container.add_child(new_hint)
	new_hint.set_boat(is_boat)
	#Set value
	if hint_value == -1 and is_boat and\
	   (type == E.HintType.Hidden or type == E.HintType.Zero):
		new_hint.no_hint()
	else:
		new_hint.set_value(hint_value)
		new_hint.set_hint_type(type)
	#Set graphical hints
	if is_horizontal:
		new_hint.set_hint_visibility(E.Top, false)
		new_hint.set_hint_visibility(E.Bottom, false)
	else:
		new_hint.set_hint_visibility(E.Left, false)
		new_hint.set_hint_visibility(E.Right, false)
	if editor_mode:
		new_hint.enable_editor()
	else:
		new_hint.disable_editor()

	return new_hint


func should_be_visible() -> Array[int]:
	var bar = Horizontal if is_horizontal else Vertical
	var ans: Array[int] = []
	for container in bar.get_children():
		var val := 0
		for child in container.get_children():
			if child.should_be_visible():
				val |= BOAT_COUNT_VISIBLE if child.is_boat else WATER_COUNT_VISIBLE
			if child.should_have_type():
				val |= BOAT_TYPE_VISIBLE if child.is_boat else WATER_TYPE_VISIBLE 
		ans.append(val)
	return ans


func set_visibility(arr: Array[int]) -> void:
	var bar = Horizontal if is_horizontal else Vertical
	assert(arr.size() == bar.get_child_count())
	for i in arr.size():
		for child in bar.get_child(i).get_children():
			if child.is_boat:
				child.set_visibility(bool(arr[i] & BOAT_COUNT_VISIBLE), bool(arr[i] & BOAT_TYPE_VISIBLE))
			else:
				child.set_visibility(bool(arr[i] & WATER_COUNT_VISIBLE), bool(arr[i] & WATER_TYPE_VISIBLE))


func remove_all_highlights() -> void:
	var bar = Horizontal if is_horizontal else Vertical
	for hint_container in bar.get_children():
		for hint in hint_container.get_children():
			hint.set_highlight(false)


func highlight_hints(idx : int) -> void:
	var bar = Horizontal if is_horizontal else Vertical
	var i = 0
	for hint_container in bar.get_children():
		for hint in hint_container.get_children():
			hint.set_highlight(i == idx)
		i += 1


func get_hint(idx : int, is_boat : bool) -> Node:
	var bar = Horizontal if is_horizontal else Vertical
	assert(idx < bar.get_child_count(), "Not a valid index to get hint:" + str(idx))
	for child in bar.get_child(idx).get_children():
		if child.is_boat == is_boat:
			return child
	#"Couldn't find hint of this type
	return null


func _on_hint_mouse_entered(idx : int) -> void:
	mouse_entered_hint.emit(idx)

func _on_hint_left_clicked(idx : int) -> void:
	left_clicked_hint.emit(idx)
