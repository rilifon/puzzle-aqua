extends Control

@onready var Buttons: GridContainer = %ButtonsContainer


func _ready():
	Profile.dark_mode_toggled.connect(_on_dark_mode_changed)
	_on_dark_mode_changed(Profile.get_option("dark_mode"))
	SteamManager.steam.item_downloaded.connect(_item_downloaded)
	SteamManager.steam.item_installed.connect(_item_installed)


func _enter_tree() -> void:
	if not SteamManager.enabled:
		return
	call_deferred("reload_all_levels")

func get_authors(ids: Array) -> Array[String]:
	if ids.is_empty():
		return []
	var query_id: int = SteamManager.steam.createQueryUGCDetailsRequest(ids)
	SteamManager.steam.sendQueryUGCRequest(query_id)
	var ret: Array = await SteamManager.steam.ugc_query_completed
	if ret[1] != SteamManager.steam.RESULT_OK:
		push_warning("Failed to query UGC")
		SteamManager.steam.releaseQueryUGCRequest(query_id)
		return []
	var total: int = ret[2]
	var ans: Array[String] = []
	for i in total:
		var res: Dictionary = SteamManager.steam.getQueryUGCResult(query_id, i)
		if res.has("steam_id_owner"):
			ans.append(SteamManager.steam.getFriendPersonaName(res.steam_id_owner))
		else:
			ans.append("")
	SteamManager.steam.releaseQueryUGCRequest(query_id)
	return ans

func reload_all_levels() -> void:
	var ids: Array = SteamManager.steam.getSubscribedItems()
	%Explanation.visible = ids.is_empty()
	var authors: Array[String] = await get_authors(ids)
	for c in Buttons.get_children():
		Buttons.remove_child(c)
		c.queue_free()
	var button_class: PackedScene = load("res://game/workshop_menu/WorkshopLevelButton.tscn")
	for i in ids.size():
		var button := button_class.instantiate()
		button.id = ids[i]
		button.author = authors[i] if authors.size() > i else ""
		Buttons.add_child(button)
	for idx in Buttons.get_child_count():
		await Buttons.get_child(idx).get_vote()


func _item_installed(app_id: int, _id: int) -> void:
	if app_id == SteamManager.APP_ID:
		reload_all_levels()

func _item_downloaded(app_id: int, _id: int, _res: int) -> void:
	if app_id == SteamManager.APP_ID:
		reload_all_levels()

func _notification(what: int) -> void:
	if what == Node.NOTIFICATION_WM_GO_BACK_REQUEST:
		_back_logic()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"return"):
		_back_logic()

func _back_logic() -> void:
	_on_back_pressed()

func _on_back_pressed():
	AudioManager.play_sfx("button_back")
	TransitionManager.pop_scene()


func _on_open_workshop_pressed() -> void:
	AudioManager.play_sfx("button_pressed")
	SteamManager.overlay_or_browser("https://steamcommunity.com/app/2716690/workshop/")


func _on_dark_mode_changed(is_dark : bool):
	theme = Global.get_theme(is_dark)


func _on_button_mouse_entered():
	AudioManager.play_sfx("button_hover")
