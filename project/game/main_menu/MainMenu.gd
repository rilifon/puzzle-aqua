extends Control

enum STATES {MAIN_MENU, LEVEL_HUB, EXTRA_LEVEL_HUB}

const CAM_POS = {
	"desktop": {
		"menu": Vector2(1930, 1080),
		"level_hub": Vector2(1930, -1280),
		"extra_level_hub": Vector2(6610, 1080),
	},
	"mobile": {
		"menu": Vector2(360, 640),
		"level_hub": Vector2(360, -1136),
		"extra_level_hub": Vector2(360 + 2283, 640),
	},
}
const EPS = .001
const ZOOM_LERP = 4.0
const EXTRA_LEVEL_ZOOM = {
	"desktop": 2.1,
	"mobile": 1.7,
}
const LEVEL_ZOOM = {
	"desktop": 2.6,
	"mobile": 2.0,
}
const NORMAL_ZOOM = {
	"desktop": 1.0,
	"mobile": 1.0,
}
const ICONS = {
	"fish": preload("res://assets/images/ui/icons/double-fish.png"),
	"turtle": preload("res://assets/images/ui/icons/turtle.png"),
	"shrimp": preload("res://assets/images/ui/icons/shrimp.png"),
}

@onready var Version: Label = %Version
@onready var Camera = $Camera2D
@onready var LevelHub = $LevelHub
@onready var Settings = $SettingsScreen

var cam_target_zoom = NORMAL_ZOOM.desktop
var cur_state = STATES.MAIN_MENU

func _ready():
	%NewIndicator.hide()
	Global.dev_mode_toggled.connect(_dev_mode_toggled)
	Profile.dark_mode_toggled.connect(_on_dark_mode_changed)
	_on_dark_mode_changed(Profile.get_option("dark_mode"))
	if not SteamManager.enabled and not Global.is_mobile:
		%Workshop.disabled = true
	cam_target_zoom = NORMAL_ZOOM.mobile if Global.is_mobile else NORMAL_ZOOM.desktop
	var cam_pos = CAM_POS.mobile if Global.is_mobile else CAM_POS.desktop
	Camera.position = cam_pos.menu
	AudioManager.start_bgm_loop()
	UserData.current().save_stats()
	UserData.current().try_pending_uploads()
	
	if Global.is_demo:
		%MobileHBox.hide()
		assert(not Global.is_mobile)
		for but in [%ExtraLevelsButton, %RandomButton, %Workshop, %EditorButton]:
			but.disabled = true
			but.get_node("LockIcon").show()
		%LockDesc.show()
	elif not Global.is_mobile:
		%BuyFullGameButton.queue_free()
		%BuyFullGameSpace.queue_free()
		%LockDesc.queue_free()
	
	await get_tree().process_frame
	
	Version.text = "v" + Profile.VERSION
	Version.visible = Profile.SHOW_VERSION
	# Unlock and save all levels. To be used by devs.
	#_force_unlock_all_levels()

func _force_unlock_all_levels() -> void:
	for section in range(1, 7):
		for level in range(1, 9):
			var data := FileManager.load_campaign_level_data(section, level)
			var save := UserLevelSaveData.new(data.grid_data, true, 0, 0.0)
			save.save_completion(10, 60.0)
			FileManager.save_level(CampaignLevelLister.level_name(section, level), save)
	update_level_hub()


func _process(dt):
	var z = Camera.zoom.x
	if z != cam_target_zoom:
		z = lerp(z, cam_target_zoom, clamp(ZOOM_LERP*dt, 0.0, 1.0))
		if abs(z - cam_target_zoom) <= EPS:
			z = cam_target_zoom
		Camera.zoom.x = z
		Camera.zoom.y = z
	Global.alpha_fade_node(dt, %BackButton, not LevelHub.level_focused, 4.0, true)
	if has_node("%ExtraLevelHub"):
		Global.alpha_fade_node(dt, %BackExtra, not %ExtraLevelHub.level_focused, 4.0, true)

func _unhandled_input(event):
	if event.is_action_pressed(&"return"):
		_back_logic()


func _enter_tree() -> void:
	if Global.is_mobile:
		%DailyUnlockText.visible = not RecurringMarathon.is_unlocked()
	call_deferred("update_level_hub")
	call_deferred("update_profile_button")
	call_deferred("update_player_display_button")

func _back_logic() -> void:
	if Settings.active:
		Settings.toggle_pause()
	elif cur_state == STATES.MAIN_MENU:
		_on_exit_button_pressed()
	elif cur_state == STATES.LEVEL_HUB:
		if LevelHub.level_focused:
			LevelHub.get_focused_section()._on_back_button_pressed()
		else:
			_on_back_button_pressed()
	elif cur_state == STATES.EXTRA_LEVEL_HUB:
		if %ExtraLevelHub.level_focused:
			%ExtraLevelHub.get_focused_section()._on_back_button_pressed()
		else:
			_on_back_button_pressed()

func _notification(what: int) -> void:
	if what == Node.NOTIFICATION_WM_GO_BACK_REQUEST:
		_back_logic()


func update_level_hub():
	LevelHub.update_sections()
	if has_node("%ExtraLevelHub"):
		%ExtraLevelHub.update_sections()
		check_for_new_dlc()


func check_for_new_dlc():
	%NewIndicator.hide()
	if Global.is_demo:
		return
	var idx = 1
	for dlc in Profile.get_all_dlc_info().values():
		if ExtraLevelLister.has_section(idx):
			if dlc.new:
				%NewIndicator.show()
				break
		else:
			break
		idx += 1


func update_profile_button() -> void:
	if not Global.is_mobile:
		if Global.custom_portrait and FileManager.current_profile == "fish":
			%ProfileButton.icon = Global.custom_portrait
		else:
			%ProfileButton.icon = ICONS[FileManager.current_profile]


func update_player_display_button() -> void:
	if not Global.is_mobile and SteamManager.enabled:
		%PlayerDisplayButton.update_flair()


func _on_editor_button_pressed():
	AudioManager.play_sfx("button_pressed")
	var editor_hub = load("res://game/editor_menu/EditorHub.tscn").instantiate()
	TransitionManager.push_scene(editor_hub)


func _on_profile_button_pressed():
	AudioManager.play_sfx("button_pressed")
	var profile := Global.load_mobile_compat("res://game/profile_menu/ProfileScreen").instantiate()
	TransitionManager.push_scene(profile)

func _on_workshop_pressed():
	AudioManager.play_sfx("button_pressed")
	var workshop: Node = load("res://game/workshop_menu/WorkshopMenu.tscn").instantiate()
	TransitionManager.push_scene(workshop)


func _on_exit_button_pressed():
	AudioManager.play_sfx("button_pressed")
	if ConfirmationScreen.start_confirmation(&"EXIT_CONFIRMATION"):
		if await ConfirmationScreen.pressed:
			Global.exit_game()


func _on_button_mouse_entered():
	AudioManager.play_sfx("button_hover")

func _on_play_pressed():
	var cam_pos = CAM_POS.mobile if Global.is_mobile else CAM_POS.desktop
	AudioManager.play_sfx("button_pressed")
	Camera.position = cam_pos.level_hub
	cur_state = STATES.LEVEL_HUB


func _on_back_button_pressed():
	var cam_pos = CAM_POS.mobile if Global.is_mobile else CAM_POS.desktop
	AudioManager.play_sfx("button_back")
	Camera.position = cam_pos.menu
	cur_state = STATES.MAIN_MENU
	check_for_new_dlc()


func _on_level_hub_enable_focus(pos, extra):
	Camera.position = pos
	if not extra:
		cam_target_zoom = LEVEL_ZOOM.mobile if Global.is_mobile else LEVEL_ZOOM.desktop
	else:
		cam_target_zoom = EXTRA_LEVEL_ZOOM.mobile if Global.is_mobile else EXTRA_LEVEL_ZOOM.desktop


func _on_level_hub_disable_focus():
	var cam_pos = CAM_POS.mobile if Global.is_mobile else CAM_POS.desktop
	Camera.position = cam_pos.level_hub
	cam_target_zoom = NORMAL_ZOOM.mobile if Global.is_mobile else NORMAL_ZOOM.desktop

func _to_extra_levels() -> void:
	var cam_pos = CAM_POS.mobile if Global.is_mobile else CAM_POS.desktop
	Camera.position = cam_pos.extra_level_hub
	cur_state = STATES.EXTRA_LEVEL_HUB
	cam_target_zoom = NORMAL_ZOOM.mobile if Global.is_mobile else NORMAL_ZOOM.desktop

func _on_extra_levels_pressed() -> void:
	AudioManager.play_sfx("button_pressed")
	_to_extra_levels()

func _on_random_button_pressed() -> void:
	AudioManager.play_sfx("button_pressed")
	TransitionManager.push_scene(Global.load_mobile_compat("res://game/random_menu/RandomHub").instantiate())


func _on_credits_button_pressed() -> void:
	AudioManager.play_sfx("button_pressed")
	TransitionManager.push_scene(Global.load_mobile_compat("res://game/credits/CreditsScreen").instantiate())


func _on_dark_mode_changed(is_dark : bool):
	theme = Global.get_theme(is_dark)

func _dev_mode_toggled(_on: bool) -> void:
	pass


func _on_weekly_button_streak_opened():
	%DailyButton.close_streak()


func _on_daily_button_streak_opened():
	%WeeklyButton.close_streak()


func _on_player_display_button_pressed():
	AudioManager.play_sfx("button_pressed")
	TransitionManager.push_scene(Global.load_mobile_compat("res://game/flairs/FlairPicker").instantiate())


func _on_buy_full_game_pressed() -> void:
	AudioManager.play_sfx("button_pressed")
	SteamManager.overlay_or_browser("https://store.steampowered.com/app/2716690/Liquidum?utm_source=demo")
