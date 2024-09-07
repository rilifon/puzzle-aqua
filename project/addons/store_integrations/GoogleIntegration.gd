class_name GoogleIntegration extends StoreIntegration

static func available() -> bool:
	return Engine.has_singleton(&"GodotGooglePlayGameServices")

var google = null
var ld_id_to_google_id := {}

func _init() -> void:
	google = Engine.get_singleton(&"GodotGooglePlayGameServices")

func authenticated() -> bool:
	# TODO
	return true

func add_leaderboard_mappings(lds: Array[StoreIntegrations.LeaderboardMapping]) -> void:
	for ld in lds:
		if ld.google_id != "":
			ld_id_to_google_id[ld.id] = ld.google_id

func _ld_map(id: String) -> String:
	if ld_id_to_google_id.has(id):
		return ld_id_to_google_id[id]
	elif id.begins_with("daily_"):
		return "daily"
	elif id.begins_with("weekly_"):
		return "weekly"
	return ""

func leaderboard_upload_score(leaderboard_id: String, score: float, _keep_best: bool, _steam_details: PackedInt32Array) -> bool:
	var id := _ld_map(leaderboard_id)
	if not id.is_empty():
		google.leaderboardsSubmitScore(id, score)
		var res: Array = await google.leaderboardsScoreSubmitted
		if len(res) >= 2 and res[1] == id and res[0] != true:
			return false
	return true

func leaderboard_upload_completion(leaderboard_id: String, time_secs: float, mistakes: int, keep_best: bool, steam_details: PackedInt32Array) -> bool:
	# 1h penalty, and Google uses milliseconds
	return await leaderboard_upload_score(leaderboard_id, (time_secs + 60 * 60 * mistakes) * 1000.0, keep_best, steam_details)

func leaderboard_show(leaderboard_id: String, timespan: int, collection: int) -> void:
	var id := _ld_map(leaderboard_id)
	if not id.is_empty():
		google.leaderboardsShowForTimeSpanAndCollection(id, timespan, collection)

func achievement_show_all() -> void:
	google.achievementsShow()
