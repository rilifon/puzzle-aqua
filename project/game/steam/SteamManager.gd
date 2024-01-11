extends Node

# TODO: Figure this out some other way
var enabled := false
const APP_ID := 2716690
var steam = null

var stats_received := false

func _init() -> void:
	if Engine.has_singleton("Steam"):
		steam = Engine.get_singleton("Steam")
	else:
		print("Steam is not available.")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if enabled:
		OS.set_environment("SteamAppId", str(APP_ID))
		OS.set_environment("SteamGameId", str(APP_ID))
		var res: Dictionary = SteamManager.steam.steamInit()
		print("Steam init: %s" % res)
		print("Steam running: %s" % SteamManager.steam.isSteamRunning())
		if res.status != SteamManager.steam.RESULT_OK:
			enabled = false
	if not enabled:
		set_process(false)
		set_process_input(false)
		return
	SteamManager.steam.current_stats_received.connect(_stats_received)
	SteamManager.steam.requestCurrentStats()

func _stats_received(game: int, result: int, user: int) -> void:
	if stats_received:
		return
	print("Steam stats received! (result = %d, game = %d, user = %d)" % [result, game, user])
	stats_received = true
	SteamStats.update_campaign_stats()

func store_stats() -> void:
	if not stats_received:
		SteamManager.steam.requestCurrentStats()
		return
	print("Storing steam stats")
	SteamManager.steam.storeStats()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		store_stats()
		SteamManager.steam.steamShutdown()


func _process(_dt: float) -> void:
	SteamManager.steam.run_callbacks()

class UploadResult:
	var id: int
	var success: bool
	func _init(id_: int, success_: bool) -> void:
		id = id_
		success = success_

var uploading := false

func upload_ugc_item(id: int, title: String, description: String, dir: String, preview_file: String) -> UploadResult:
	if uploading:
		return UploadResult.new(id, false)
	UploadingToWorkshop.start()
	dir = ProjectSettings.globalize_path(dir)
	preview_file = ProjectSettings.globalize_path(preview_file)
	uploading = true
	if id == -1:
		id = await _create_item_id()
	var success := false
	if id != -1:
		success = await _upload_item(id, title, description, dir, preview_file)
	uploading = false
	UploadingToWorkshop.stop()
	return UploadResult.new(id, success)

func _create_item_id() -> int:
	SteamManager.steam.createItem(SteamManager.APP_ID, SteamManager.steam.WORKSHOP_FILE_TYPE_COMMUNITY)
	var ret: Array = await SteamManager.steam.item_created
	var res: int = ret[0]
	var id: int = ret[1]
	var needs_tos: bool = ret[2]
	if res != SteamManager.steam.RESULT_OK:
		push_error("Failed to create item: %s" % res)
		return -1
	print("Successfully created item %d" % id)
	if needs_tos:
		SteamManager.steam.activateGameOverlayToWebPage("steam://url/CommunityFilePage/%d" % id)
	return id

func _upload_item(id: int, title: String, description: String, dir: String, preview_file: String) -> bool:
	var update_id: int = SteamManager.steam.startItemUpdate(SteamManager.APP_ID, id)
	SteamManager.steam.setItemContent(update_id, dir)
	SteamManager.steam.setItemTitle(update_id, title)
	SteamManager.steam.setItemDescription(update_id, description)
	SteamManager.steam.setItemPreview(update_id, preview_file)
	SteamManager.steam.submitItemUpdate(update_id, Time.get_datetime_string_from_system(true, true))
	UploadingToWorkshop.update_handle = update_id
	var ret: Array = await SteamManager.steam.item_updated
	var res: int = ret[0]
	var needs_tos: bool = ret[1]
	if res != SteamManager.steam.RESULT_OK:
		push_error("Failed to upload item: %s" % res)
		return false
	if needs_tos:
		SteamManager.steam.activateGameOverlayToWebPage("steam://url/CommunityFilePage/%d" % id)
	print("Successfuly updated item %d" % id)
	return true
