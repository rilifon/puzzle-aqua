class_name AppleIntegration extends StoreIntegration

signal event(data: Dictionary)
signal authenticate_event(data: Dictionary)
signal identity_verification_event(data: Dictionary)

static func available() -> bool:
	return Engine.has_singleton("GameCenter")

var apple = null
var ld_id_to_apple_id := {}
var _authenticated := false
var display_name := ""

class WaitWithTimeout:
	signal finished
	var _finished := false
	func _init(sig: Signal, timeout: float) -> void:
		_wait_sig(sig)
		_wait_timeout(timeout)
	func _wait_sig(sig: Signal) -> void:
		var res = await sig
		_try_complete(res)
	func _wait_timeout(timeout: float) -> void:
		await Global.wait(timeout)
		_try_complete(null)
	func _try_complete(res) -> void:
		if not _finished:
			_finished = true
			finished.emit(res)

func _try_authenticate() -> bool:
	if _authenticated:
		return true
	_authenticated = apple.is_authenticated()
	if _authenticated:
		return true
	var res = apple.authenticate()
	if res == OK:
		print("Authenticating with apple")
		var resp = await WaitWithTimeout.new(authenticate_event, 3).finished
		_authenticated = resp is Dictionary and resp.result == "ok"
	else:
		print("Failed apple.authenticate() call")
	assert(apple.is_authenticated() == _authenticated)
	return _authenticated

func _init() -> void:
	apple = Engine.get_singleton("GameCenter")
	_authenticated = apple.is_authenticated()


func _ready() -> void:
	await _try_authenticate()
	await StatsTracker.instance().update_campaign_stats()
	print("Apple ready")

func authenticated() -> bool:
	return _authenticated

func _process(_dt: float) -> void:
	while apple.get_pending_event_count() > 0:
		var new_event: Dictionary = apple.pop_pending_event()
		print("Apple event: %s" % [new_event])
		if new_event["type"] == "authentication" and new_event.result == "ok":
			display_name = new_event.get("displayName", new_event.get("alias", ""))
		if new_event["type"] == "authentication":
			authenticate_event.emit(new_event)
		elif new_event["type"] == "identity_verification_signature":
			identity_verification_event.emit(new_event)
		else:
			event.emit(new_event)

func add_leaderboard_mappings(lds: Array[StoreIntegrations.LeaderboardMapping]) -> void:
	for ld in lds:
		ld_id_to_apple_id[ld.id] = ld.apple_id

func _ld_map(id: String) -> String:
	if ld_id_to_apple_id.has(id):
		return ld_id_to_apple_id[id]
	elif id.begins_with("daily_"):
		return "daily"
	elif id.begins_with("weekly_"):
		return "weekly"
	return ""

func leaderboard_upload_score(leaderboard_id: String, score: float, _keep_best: bool, _steam_details: PackedInt32Array) -> bool:
	var id := _ld_map(leaderboard_id)
	if id != "":
		var res = apple.post_score({
			score = score,
			category = id,
		})
		if res != OK:
			push_warning("Error calling post_score: %s" % [res])
			return false
		else:
			var resp: Dictionary = await event
			if resp != null and resp.get("type") == "post_score" and resp.get("result") != "ok":
				return false
	return true

func leaderboard_upload_completion(leaderboard_id: String, time_secs: float, mistakes: int, keep_best: bool, steam_details: PackedInt32Array) -> bool:
	# 1h penalty
	return await leaderboard_upload_score(leaderboard_id, time_secs + 60 * 60 * mistakes, keep_best, steam_details)

func leaderboard_show(leaderboard_id: String, _google_timespan: int, _google_collection: int) -> void:
	if not await _try_authenticate():
		return
	var id := _ld_map(leaderboard_id)
	var res
	if id != "":
		res = apple.show_game_center({"view": "leaderboards", "leaderboard_name": id})
	else:
		res = apple.show_game_center({})
	if res != OK:
		push_warning("Error calling show_game_center: %s" % [res])
	else:
		await event

func achievement_set(ach_id: String, steps: int, total_steps: int) -> void:
	var res = apple.award_achievement({
		name = ach_id,
		progress = 100.0 * float(steps) / float(total_steps),
	})
	if res != OK:
		push_warning("Error calling award_achievement: %s" % [res])
	else:
		var resp: Dictionary = await event
		if resp.result != "ok":
			push_warning("Error setting achievement: %s" % [resp.error_code])

func achievement_show_all() -> void:
	await leaderboard_show("", 0, 0)
