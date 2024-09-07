class_name SteamIntegration extends StoreIntegration

static func available() -> bool:
	return not Global.is_mobile and Engine.has_singleton(&"Steam")

var steam = null
var ld_id_to_steam_name := {}
var ld_steam_name_to_id := {}

func add_leaderboard_mappings(lds: Array[StoreIntegrations.LeaderboardMapping]) -> void:
	for ld in lds:
		if ld.steam_id != "":
			ld_id_to_steam_name[ld.id] = ld.steam_id

func _init() -> void:
	steam = Engine.get_singleton(&"Steam")

func authenticated() -> bool:
	return steam.loggedOn()

func _store_ld_find_result(steam_name: String) -> void:
	var ret: Array = await steam.leaderboard_find_result
	if not ret[1]:
		push_warning("Leaderboard not found: %s" % [steam_name])
	else:
		ld_steam_name_to_id[steam_name] = ret[0]

func leaderboard_create_if_not_exists(leaderboard_id: String, sort_method: StoreIntegrations.SortMethod) -> void:
	if not ld_id_to_steam_name.has(leaderboard_id):
		ld_id_to_steam_name[leaderboard_id] = leaderboard_id
	var steam_name: String = ld_id_to_steam_name[leaderboard_id]
	if not ld_steam_name_to_id.has(steam_name):
		steam.findOrCreateLeaderboard(steam_name, sort_method, 1)
		await _store_ld_find_result(steam_name)

func _get_ld_id(leaderboard_id: String) -> int:
	var steam_name: String = ld_id_to_steam_name.get(leaderboard_id, leaderboard_id)
	if not ld_steam_name_to_id.has(steam_name):
		steam.findLeaderboard(steam_name)
		await _store_ld_find_result(steam_name)
	return ld_steam_name_to_id.get(steam_name, -1)

func leaderboard_upload_score(leaderboard_id: String, score: float, keep_best: bool, steam_details: PackedInt32Array) -> bool:
	var id := await _get_ld_id(leaderboard_id)
	if id <= 0:
		return true
	steam.uploadLeaderboardScore(int(score), keep_best, steam_details, id)
	var ret: Array = await steam.leaderboard_score_uploaded
	if not ret[0]:
		push_warning("Failed to upload leaderboard entry for %d (%s) [%s]" % [id, leaderboard_id, ret])
		return false
	else:
		print("Did upload to leaderboard %d" % [id])
		return true

func leaderboard_upload_completion(leaderboard_id: String, time_secs: float, mistakes: int, keep_best: bool, steam_details: PackedInt32Array) -> bool:
	# We need to store both mistakes and time in the same score.
	# Mistakes take priority.
	return await leaderboard_upload_score(leaderboard_id, minf(time_secs, RecurringMarathon.MAX_TIME - 1) + minf(mistakes, 1000) * RecurringMarathon.MAX_TIME, keep_best, steam_details)

func leaderboard_download_completion(leaderboard_id: String, start: int, count: int) -> StoreIntegrations.LeaderboardData:
	var id := await _get_ld_id(leaderboard_id)
	if id <= 0:
		return null
	var total: int = steam.getLeaderboardEntryCount(id)
	var data := StoreIntegrations.LeaderboardData.new()
	if total == 0:
		return data
	steam.setLeaderboardDetailsMax(64)
	steam.downloadLeaderboardEntries(start, start + count - 1, steam.LEADERBOARD_DATA_REQUEST_GLOBAL, id)
	var ret: Array = await steam.leaderboard_scores_downloaded
	steam.setLeaderboardDetailsMax(0)
	var my_id: int = steam.getSteamID()
	for steam_data in ret[2]:
		if steam_data.steam_id == my_id:
			data.self_idx = data.entries.size()
		var entry := StoreIntegrations.LeaderboardEntry.new()
		entry.rank = steam_data.global_rank
		if steam_data.steam_id == my_id:
			entry.display_name = steam.getPersonaName()
		else:
			var nickname: String = steam.getPlayerNickname(steam_data.steam_id)
			entry.display_name = steam.getFriendPersonaName(steam_data.steam_id) if nickname.is_empty() else nickname
		entry.mistakes = steam_data.score / RecurringMarathon.MAX_TIME
		entry.secs = steam_data.score % RecurringMarathon.MAX_TIME
		var ld_details := LeaderboardDetails.from_arr(steam_data.get("details", PackedInt32Array()))
		entry.extra_data = {
			steam_id = steam_data.steam_id,
			flair = ld_details.flair,
		}
		data.entries.append(entry)
	return data
	
