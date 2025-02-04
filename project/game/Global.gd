extends Node

const THEME = {
	"desktop": {
		"normal": preload("res://assets/ui/GeneralTheme.tres"),
		"dark": preload("res://assets/ui/GeneralDarkTheme.tres"),
	},
	"mobile": {
		"normal": preload("res://assets/ui/MobileTheme.tres"),
		"dark": preload("res://assets/ui/MobileDarkTheme.tres"),
	},
	"font": {
		"normal": preload("res://assets/ui/DarkFont.tres"),
		"dark": preload("res://assets/ui/LightFont.tres"),
	},
}
const SETTINGS_THEME = {
	"desktop": {
		"normal": preload("res://assets/ui/SettingsTheme.tres"),
		"dark": preload("res://assets/ui/SettingsDarkTheme.tres"),
	},
	"mobile": {
		"normal": preload("res://assets/ui/SettingsMobileTheme.tres"),
		"dark": preload("res://assets/ui/SettingsMobileDarkTheme.tres"),
	},
}
const COLORS = {
	"normal": Color("#d9ffe2ff"),
	"satisfied": Color("#61fc89ff"),
	"error": Color("#ff6a6aff"),
}
const WATER_COLORS = {
	"normal": {
		"dark": Color(0, 0.035, 0.141),
		"bg": Color(0.851, 1, 0.886),
		"preview": Color(0.078, 0.365, 0.529),
		"water_color": Color(0.671, 1, 0.82),
		"depth_color": Color(0.078, 0.365, 0.529),
		"ray_value": 0.3,
		"cellhints_highlight": Color(0.016, 0.106, 0.22, 0.408),
	},
	"dark": {
		"dark": Color(0.671, 1, 0.82),
		"bg": Color(0.035, 0.212, 0.349),
		"preview": Color(0.275, 0.812, 0.702),
		"water_color": Color(0.671, 1, 0.82),
		"depth_color": Color(0.275, 0.812, 0.702),
		"ray_value": 1.0,
		"cellhints_highlight": Color(0.851, 1, 0.886, 0.408),
	}
}
const WATER_MATERIAL = preload("res://assets/shaders/WaterMaterial.tres")
const GRANULAR = 0.01

func load_tutorial(tut: String) -> PackedScene:
	match tut:
		"mouse1":
			if is_mobile:
				return load("res://database/tutorials/Mouse1Mobile.tscn")
			else:
				return load("res://database/tutorials/Mouse1.tscn")
		"mouse2":
			if is_mobile:
				return null
			else:
				return load("res://database/tutorials/Mouse2.tscn")
		"preview":
			if is_mobile:
				return load("res://database/tutorials/HoldPreview.tscn")
			else:
				return load("res://database/tutorials/HoverPreview.tscn")
		"together_separate":
			return load("res://database/tutorials/TogetherSeparate.tscn")
		"unknown_hints":
			return load("res://database/tutorials/UnknownHints.tscn")
		"boats":
			return load("res://database/tutorials/Boats.tscn")
		"cellhints":
			return load("res://database/tutorials/CellHints.tscn")
		"cellhints2":
			return load("res://database/tutorials/CellHints2.tscn")
		"cellhints_tog":
			return load("res://database/tutorials/CellHintsTogether.tscn")
		"cellhints_sep":
			return load("res://database/tutorials/CellHintsSeparate.tscn")
		"cellhints_unk":
			return load("res://database/tutorials/CellHintsUnknown.tscn")
	return null

signal dev_mode_toggled(status : bool)
signal starting_quit()

@onready var level_scene = load_mobile_compat("res://game/level/Level")

var _dev_mode := false
var dev_mode_label: Label
var is_mobile: bool = ProjectSettings.get_setting("liquidum/is_mobile")
# SteamManager changes this
var is_demo: bool = not is_mobile
var play_new_dif_again = -1
var custom_portrait = null
var shader_materials = {}

const DEMO_UNLOCKED := {
	1: 8,
	2: 5,
}

func _ready() -> void:
	dev_mode_label = Label.new()
	dev_mode_label.text = "dev mode"
	dev_mode_label.position.x = get_viewport().get_visible_rect().size.x - 400
	dev_mode_label.position.y = get_viewport().get_visible_rect().size.y - 100
	dev_mode_label.visible = false
	add_child(dev_mode_label)
	if ProjectSettings.get_setting("liquidum/dev_mode"):
		toggle_dev_mode()
	check_cmdline_args()
	setup_shader_materials()
	Profile.dark_mode_toggled.connect(update_dark_mode)
	update_dark_mode(Profile.get_option("dark_mode"))

func _input(event):
	if event.is_action_pressed(&"toggle_fullscreen"):
		toggle_fullscreen()
	if event.is_action_pressed(&"toggle_dev_mode") and OS.is_debug_build():
		toggle_dev_mode()
	if event.is_action_pressed(&"dev_mode_screenshot") and OS.is_debug_build():
		var view := get_viewport()
		view.size = Vector2(3840, 2160)
		await get_tree().process_frame
		await get_tree().process_frame
		var img := view.get_texture().get_image()
		var i := 1
		while FileAccess.file_exists("res://screenshots/%02d.png" % i):
			i += 1
		img.save_png("res://screenshots/%02d.png" % i)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Global.exit_game()


func toggle_dev_mode():
	_dev_mode = not _dev_mode
	dev_mode_toggled.emit(_dev_mode)
	if not is_mobile:
		dev_mode_label.visible = _dev_mode

func is_fake_mobile() -> bool:
	return OS.is_debug_build() and is_mobile and not OS.get_name() in ["iOS", "Android"]

func check_cmdline_args():
	for arg in OS.get_cmdline_args():
		if arg == "--is-dev":
			if not _dev_mode:
				toggle_dev_mode()
		elif arg.find("=") > -1:
			var key_value = arg.split("=")
			var key = key_value[0]
			var value = key_value[1]
			if key == "--custom-portrait":
				var custom := load("res://assets/images/ui/icons/custom_portraits/%s.png" % [value])
				if custom == null:
					push_warning("Not a valid custom portrait: " + str(value))
					custom_portrait = false
				else:
					custom_portrait = custom


func setup_shader_materials():
	var v = 0.0 
	while v <= 1.0 + GRANULAR/2.0:
		shader_materials[v] = WATER_MATERIAL.duplicate()
		shader_materials[v].set_shader_parameter(&"level", v)
		v += GRANULAR
		v = snapped(v, GRANULAR)


func get_water_shader(level : float):
	assert(shader_materials.has(level),"Not a valid water shader level: " + str(level))
	return shader_materials[level]


func load_mobile_compat(scene: String) -> PackedScene:
	if is_mobile:
		return load(scene + "Mobile.tscn")
	else:
		return load(scene + ".tscn")


func exit_game() -> void:
	if get_window().mode == Window.MODE_WINDOWED:
		_store_window()
	FileManager.save_game()
	starting_quit.emit()
	call_deferred(&"_do_exit")


func _do_exit() -> void:
	var node := Global.load_mobile_compat("res://game/ui/Quitting").instantiate()
	get_tree().current_scene.hide()
	get_tree().root.add_child(node)


func is_dev_mode() -> bool:
	return OS.is_debug_build() and _dev_mode


func create_level(grid_: GridModel, level_name_: String, full_name_: String, description_: String, tracking_stats: Array[String], level_number := -1, section_number := -1) -> Level:
	var level : Level = level_scene.instantiate()
	level.grid = grid_
	level.level_name = level_name_
	level.full_name = full_name_
	level.level_number = level_number
	level.section_number = section_number
	level.description = description_
	level.add_playtime_tracking(tracking_stats)
	return level


func create_button(text: String) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.text = text
	return button


func is_fullscreen():
	return get_window().mode == Window.MODE_FULLSCREEN


func _store_window() -> void:
	if SteamManager.is_steam_deck():
		return
	var window := get_window()
	Profile.set_option("window_position", window.position)
	Profile.set_option("window_size", window.size)
	Profile.set_option("window_screen", window.current_screen)


func toggle_fullscreen():
	if (is_mobile and not OS.is_debug_build()) or SteamManager.is_steam_deck():
		return
	var window = get_window()
	if window.mode == Window.MODE_WINDOWED:
		_store_window()
	window.mode = Window.MODE_FULLSCREEN if window.mode == Window.MODE_WINDOWED else Window.MODE_WINDOWED
	Profile.set_option("fullscreen", window.mode != Window.MODE_WINDOWED, true)
	window.borderless =  window.mode != Window.MODE_WINDOWED
	if window.mode == Window.MODE_WINDOWED:
		var wpos := Profile.get_vec2i("window_position")
		var wsize := Profile.get_vec2i("window_size")
		if wpos != Vector2i(-1, -1) and wsize != Vector2i(-1, -1):
			window.position = wpos
			window.size = wsize
		else:
			var s_size = DisplayServer.screen_get_size()
			var size = s_size*.8
			window.size = size
			window.position = Vector2(s_size.x/2 - size.x/2, size.y/2)


func shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in a.size():
		var j := rng.randi_range(i, a.size() - 1)
		var tmp = a[i]
		a[i] = a[j]
		a[j] = tmp


func wait_for_thread(t: Thread) -> Variant:
	while t.is_started() and t.is_alive():
		await get_tree().create_timer(0.5).timeout
	return t.wait_to_finish()

func wait(secs: float) -> void:
	await get_tree().create_timer(secs).timeout

#Checks if a certain tutorial exists in the current mode
func has_tutorial(tutorial_name):
	return load_tutorial(tutorial_name) != null


func get_tutorial(tutorial_name):
	var scene := load_tutorial(tutorial_name)
	if scene == null:
		return false
	else:
		return scene.instantiate()

func alpha_fade_node(dt: float, node: Node, show: bool, alpha_speed := 1.0, toggle_visibility := false, max_alpha := 1.0, min_alpha := 0.0) -> void:
	if show:
		node.modulate.a = min(node.modulate.a + alpha_speed*dt, max_alpha)
	else:
		node.modulate.a = max(node.modulate.a - alpha_speed*dt, min_alpha)
	if toggle_visibility:
		if node.modulate.a > 0.0:
			node.show()
		else:
			node.hide()


func get_theme(is_dark : bool):
	if is_mobile:
		if is_dark:
			return THEME.mobile.dark
		else:
			return THEME.mobile.normal
	else:
		if is_dark:
			return THEME.desktop.dark
		else:
			return THEME.desktop.normal


func get_font_theme(is_dark : bool):
	if is_dark:
		return THEME.font.dark
	else:
		return THEME.font.normal


func get_settings_theme(is_dark : bool):
	if is_mobile:
		if is_dark:
			return SETTINGS_THEME.mobile.dark
		else:
			return SETTINGS_THEME.mobile.normal
	else:
		if is_dark:
			return SETTINGS_THEME.desktop.dark
		else:
			return SETTINGS_THEME.desktop.normal


func get_color(is_dark : bool):
	if is_dark:
		return WATER_COLORS.dark
	else:
		return WATER_COLORS.normal


func update_dark_mode(is_dark : bool) -> void:
	var colors = get_color(is_dark)
	for water in shader_materials.values():
		water.set_shader_parameter(&"water_color", colors.water_color)
		water.set_shader_parameter(&"depth_color", colors.depth_color)
		water.set_shader_parameter(&"ray_value", colors.ray_value)

#Return 1 if best constrast is white, 0 if black
func get_best_contrast(color) -> bool:
	var l_rgb = []
	for c in [color.r, color.g, color.b]:
		c = c/12.92 if c <= 0.04045 else pow(((c+0.055)/1.055), 2.4)
		l_rgb.append(c)
	var luminance = 0.2126 * l_rgb[0] + 0.7152 * l_rgb[1] + 0.0722 * l_rgb[2]
	return luminance < .179

func get_contrast_background(color) -> Color:
	var colors = WATER_COLORS.normal
	var c = colors.bg if get_best_contrast(color) else colors.dark
	return c
