extends Control

const LEVELBUTTON = preload("res://game/levelhub/LevelButton.tscn")
const ALPHA_SPEED = 3.0
const LERP = 2.0
const DIST_EPS = .4
const CENTRAL_POS = {
	"desktop": Vector2(-103, -135),
	"mobile": Vector2(-97, -135),
}
const RADIUS = 500
const ELLIPSE_RATIO = {
	"desktop": Vector2(1.1, .75),
	"mobile": Vector2(.65, 0.9),
}
const LEVELS_SCALE = {
	"desktop": Vector2(.5, .5),
	"mobile": Vector2(.4, .4),
}
const BACK_POSITION = {
	"desktop": Vector2(-885, -500),
	"mobile": Vector2(-380, -720),
}
const CAPTIONS_POSITION = {
	"desktop": Vector2(-900, 350),
	"mobile": Vector2(-400, 590),
}

const STYLES = {
	"normal": {
		"normal": {
			"normal": preload("res://assets/ui/SectionButton/NormalStyle.tres"),
			"hover": preload("res://assets/ui/SectionButton/HoverStyle.tres"),
			"pressed": preload("res://assets/ui/SectionButton/PressedStyle.tres"),
		},
		"completed": {
			"normal": preload("res://assets/ui/SectionButton/CompletedNormalStyle.tres"),
			"hover": preload("res://assets/ui/SectionButton/CompletedHoverStyle.tres"),
			"pressed": preload("res://assets/ui/SectionButton/CompletedPressedStyle.tres"),
		}
	},
	"dark": {
		"normal": {
			"normal": preload("res://assets/ui/SectionButton/NormalStyle.tres"),
			"hover": preload("res://assets/ui/SectionButton/HoverStyle.tres"),
			"pressed": preload("res://assets/ui/SectionButton/PressedStyle.tres"),
		},
		"completed": {
			"normal": preload("res://assets/ui/SectionButton/CompletedNormalDarkStyle.tres"),
			"hover": preload("res://assets/ui/SectionButton/CompletedHoverDarkStyle.tres"),
			"pressed": preload("res://assets/ui/SectionButton/CompletedPressedDarkStyle.tres"),
		}
	},
	
}

signal enable_focus(pos : Vector2, my_section : int)
signal disable_focus()
signal loaded_endless(button: LevelButton)

@onready var AnimPlayer = $AnimationPlayer
@onready var MainButton = $Button
@onready var ShaderEffect = $Button/ShaderEffect
@onready var Levels = $Levels
@onready var BackButton = $BackButton
@onready var MouseBlocker = $Button/MouseBlocker
@onready var OngoingSolution = %OngoingSolution
@onready var LevelCount = %LevelCount
@onready var SectionNumber = %SectionNumber
@onready var SelectALevel = %SelectALevel
@onready var LevelInfoContainer = %LevelInfoContainer
@onready var SectionName = %SectionName


var my_section := -1
var focused := false
var showing_level_info := false
var hub = null
var level_lister: LevelLister = null
var extra := false


func _ready():
	Profile.dark_mode_toggled.connect(_on_dark_mode_changed)
	_on_dark_mode_changed(Profile.get_option("dark_mode"))
	AnimPlayer.play("float")
	OngoingSolution.hide()
	ShaderEffect.material = ShaderEffect.material.duplicate()
	ShaderEffect.material.set_shader_parameter(&"rippleRate", randf_range(1.6, 3.5))
	Levels.modulate.a = 0.0
	LevelInfoContainer.modulate.a = 0.0
	%IconCaptions.modulate.a = 0.0
	SectionNumber.modulate.a = 1.0
	Levels.hide()
	MouseBlocker.hide()
	AnimPlayer.seek(randf_range(0.0, AnimPlayer.current_animation_length))
	BackButton.position = BACK_POSITION.mobile if Global.is_mobile else BACK_POSITION.desktop
	%IconCaptions.position = CAPTIONS_POSITION.mobile if Global.is_mobile else CAPTIONS_POSITION.desktop


func _process(dt):
	for node in [Levels, BackButton, %IconCaptions]:
		Global.alpha_fade_node(dt, node, focused, ALPHA_SPEED, true)
	for node in [OngoingSolution, LevelCount]:
		Global.alpha_fade_node(dt, node, not focused, ALPHA_SPEED)
	Global.alpha_fade_node(dt, LevelInfoContainer, showing_level_info and focused, ALPHA_SPEED)
	Global.alpha_fade_node(dt, SelectALevel, focused and not showing_level_info, ALPHA_SPEED)
	Global.alpha_fade_node(dt, SectionNumber, not focused, ALPHA_SPEED)
	Global.alpha_fade_node(dt, SectionName, not focused, ALPHA_SPEED)
	var central = CENTRAL_POS.mobile if Global.is_mobile else CENTRAL_POS.desktop
	if focused:
		if MainButton.position != central:
			MainButton.position = lerp(MainButton.position, central, clamp(LERP, 0.0, 1.0))
			if MainButton.position.distance_to(central) < DIST_EPS:
				MainButton.position = central
	for level in Levels.get_children():
		level.set_effect_alpha(Levels.modulate.a)

func set_section_name(section_name: String) -> void:
	if not section_name.is_empty():
		SectionNumber.hide()
		SectionName.text = section_name
		SectionName.show()

func setup_dlc_button() -> void:
	var info = Profile.get_dlc_info(my_section)
	%NewDLC.visible = info and info.new
	%BuyDLCButton.visible = focused
	if ExtraLevelLister.is_free(my_section):
		%BuyDLCButton.text = "DLC_FREE"
	else:
		%BuyDLCButton.text = "DLC_BUY"
	
func delete_dlc_button() -> void:
	if has_node("%BuyDLCButton"):
		%NewDLC.queue_free()
		%BuyDLCButton.queue_free()

func setup(hub_ref, section: int, unlocked_levels: int, extra_: bool) -> void:
	extra = extra_
	level_lister = ExtraLevelLister as LevelLister if extra else CampaignLevelLister as LevelLister
	var any_hard := false
	hub = hub_ref
	set_number(section)
	for button in Levels.get_children():
		Levels.remove_child(button)
		button.queue_free()
	var force_unlocked := {}
	if level_lister.section_disabled(section):
		for level in level_lister.get_disabled_section_free_trial(section):
			force_unlocked[level] = true
	var total_levels := level_lister.count_section_levels(my_section)
	%LockDesc.visible = not force_unlocked.is_empty() and force_unlocked.size() < total_levels
	if Global.is_demo:
		%LockDesc/Meaning.text = "LOCKED_DEMO"
	
	Levels.scale = LEVELS_SCALE.mobile if Global.is_mobile else LEVELS_SCALE.desktop
	
	var flavor := ExtraLevelLister.section_endless_flavor(section) if extra else -1
	for i in range(1, total_levels + 1):
		var button = LEVELBUTTON.instantiate()
		Levels.add_child(button)
		position_level_button(button, total_levels + int(flavor != -1), i)
		var has_unlock_anim = (my_section == hub.section_to_unlock and i == hub.level_to_unlock)
		button.setup(my_section, i, force_unlocked.has(i) or (i <= unlocked_levels and not has_unlock_anim), not force_unlocked.is_empty(), extra)
		button.mouse_exited.connect(_on_level_button_mouse_exited)
		button.mouse_entered.connect(_on_level_button_mouse_entered.bind(i))
		button.had_first_win.connect(_on_level_first_win)
		any_hard = any_hard or (not button.disabled and button.HardIcon.visible)
	
	if flavor != -1:
		assert(extra)
		var button = LEVELBUTTON.instantiate()
		Levels.add_child(button)
		position_level_button(button, total_levels + 1, total_levels + 1)
		var enabled: bool = force_unlocked.is_empty() and (ExtraLevelLister.count_completed_section_levels(section) == total_levels or Global.is_dev_mode() or Profile.get_option("unlock_everything"))
		button.setup(my_section, -1, enabled, not force_unlocked.is_empty(), true)
		button.mouse_exited.connect(_on_level_button_mouse_exited)
		button.mouse_entered.connect(_on_level_button_mouse_entered.bind(-1))
		button.loaded_endless.connect(_on_loaded_endless)
		any_hard = any_hard or (not button.disabled and button.HardIcon.visible)
	
	OngoingSolution.visible = level_lister.count_section_ongoing_solutions(my_section) > 0
	%OngoingDesc.visible = OngoingSolution.visible
	%HardLevelsDesc.visible = any_hard
	update_level_count_label()
	update_style_boxes(is_section_completed())

func _on_loaded_endless(button: LevelButton) -> void:
	loaded_endless.emit(button)

func enable() -> void:
	AnimPlayer.speed_scale = randf_range(.35, .55)
	MainButton.disabled = false
	ShaderEffect.show()
	LevelCount.show()


func disable() -> void:
	AnimPlayer.speed_scale = randf_range(.1, .15)
	MainButton.disabled = true
	ShaderEffect.hide()
	LevelCount.hide()
	if Global.is_demo and not Global.DEMO_UNLOCKED.has(my_section):
		%LockIcon.show()


func set_number(section: int) -> void:
	my_section = section
	SectionNumber.text = str(section)


func focus():
	if has_node("%BuyDLCButton"):
		%BuyDLCButton.show()
	AnimPlayer.pause()
	focused = true
	MouseBlocker.show()
	enable_focus.emit(global_position, my_section, extra)


func unfocus():
	if has_node("%BuyDLCButton"):
		%BuyDLCButton.hide()
	AnimPlayer.play("float")
	focused = false
	MouseBlocker.hide()
	disable_focus.emit()


func show_level_info(level_name: String, completed: bool, time: float, mistakes: int) -> void:
	showing_level_info = true
	%LevelName.text = level_name
	%BestTime.show()
	%BestMistakes.show()
	if completed:
		%Completed.text = tr("COMPLETED_LEVEL")
	else:
		%Completed.text = tr("NOT_COMPLETED_LEVEL")
	if time != -1:
		%BestTime.text = tr("BEST_TIME") % get_formatted_time(time)
	else:
		%BestTime.text = tr("BEST_TIME") % "-"
	if mistakes != -1:
		%BestMistakes.text = tr("BEST_MISTAKES") % str(mistakes)
	else:
		%BestMistakes.text = tr("BEST_MISTAKES") % "-"

func show_endless_info() -> void:
	showing_level_info = true
	%LevelName.text = "ENDLESS"
	var data := UserData.current()
	var completed := data.get_endless_completed(my_section)
	if completed > 0:
		%Completed.text = tr("TIMES_COMPLETED") % [completed]
	else:
		%Completed.text = tr("NOT_COMPLETED_LEVEL")
	%BestTime.hide()
	%BestMistakes.hide()

func hide_level_info():
	showing_level_info = false


func get_formatted_time(time: float) -> String:
	var t = int(time)
	var hours = t/3600
	var minutes = t%3600/60
	var seconds = t%60
	if hours > 0:
		return "%02d:%02d:%02d" % [hours,minutes,seconds]
	else:
		return "%02d:%02d" % [minutes,seconds]


func position_level_button(button, total_levels, i):
	var angle = PI + i*2*PI/float(total_levels)
	var sc = Levels.scale.x
	var ellipse = ELLIPSE_RATIO.mobile if Global.is_mobile else ELLIPSE_RATIO.desktop
	button.position = Vector2(
		cos(angle)*RADIUS*ellipse.x/sc,
		sin(angle)*RADIUS*ellipse.y/sc,
	)


func unlock():
	AnimPlayer.play("unlock")


func unlock_level(level):
	Levels.get_child(level - 1).unlock()


func disable_level(level):
	Levels.get_child(level - 1).disable()


func is_section_completed():
	return level_lister.count_completed_section_levels(my_section) >=\
		   level_lister.count_section_levels(my_section)


func update_level_count_label():
	LevelCount.text = "%d/%d" % \
		[level_lister.count_completed_section_levels(my_section),\
		 level_lister.count_section_levels(my_section)]


func update_style_boxes(completed : bool):
	var style_theme = STYLES.dark if Profile.get_option("dark_mode") else STYLES.normal
	var styles = style_theme.completed if completed else style_theme.normal
	MainButton.add_theme_stylebox_override("normal", styles.normal)
	MainButton.add_theme_stylebox_override("hover", styles.hover)
	MainButton.add_theme_stylebox_override("pressed", styles.pressed)


func _on_button_pressed():
	AudioManager.play_sfx("zoom_in")
	if extra:
		var data = Profile.get_dlc_info(my_section)
		if data:
			data.new = false
			Profile.set_dlc_info(my_section, data, true)
			if has_node("%NewDLC"):
				%NewDLC.queue_free()
	focus()


func _on_back_button_pressed():
	assert(focused)
	AudioManager.play_sfx("zoom_out")
	unfocus()


func _on_level_button_mouse_entered(level_number : int):
	if level_number == -1:
		show_endless_info()
		return
	var save = FileManager.load_level(level_lister.level_name(my_section, level_number))
	var data = FileManager.load_extra_level_data(my_section, level_number) if extra else FileManager.load_campaign_level_data(my_section, level_number)
	if save:
		show_level_info(data.full_name, save.is_completed(), save.best_time_secs, save.best_mistakes)
	else:
		show_level_info(data.full_name, false, -1, -1)


func _on_level_button_mouse_exited():
	hide_level_info()


func _on_level_first_win(button):
	var section = button.my_section
	if level_lister.section_disabled(section):
		return
	var completed_levels := level_lister.count_completed_section_levels(section)
	var section_levels := level_lister.count_section_levels(section)
	if Global.is_demo:
		section_levels = Global.DEMO_UNLOCKED.get(section)
	if extra:
		if level_lister.get_max_unlocked_level(section) < section_levels:
			hub.prepare_to_unlock_level(section, level_lister.get_max_unlocked_level(section))
	elif completed_levels < section_levels - level_lister.get_max_unlocked_levels(section):
		hub.prepare_to_unlock_level(section, level_lister.get_max_unlocked_level(section))
	elif (completed_levels == section_levels - level_lister.get_max_unlocked_levels(section)) and \
		 section < level_lister.count_all_game_sections():
		hub.unlock_section(section)


func _on_button_mouse_entered():
	if not focused and not $Button.disabled:
		AudioManager.play_sfx("button_hover")


func _on_dark_mode_changed(_is_dark : bool):
	if level_lister:
		update_style_boxes(is_section_completed())
	else:
		update_style_boxes(false)


func _on_buy_dlc_button_mouse_entered():
	AudioManager.play_sfx("button_hover")


func _on_buy_dlc_button_pressed() -> void:
	if Global.is_mobile:
		ExtraLevelLister.purchase_section(my_section)
	else:
		var link := "https://store.steampowered.com/app/%s?utm_source=liquidum&utm_medium=menu" % [ExtraLevelLister.steam_dlc(my_section)]
		SteamManager.overlay_or_browser(link)
