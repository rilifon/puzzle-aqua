class_name LogIntegration
extends StoreIntegration

static func available() -> bool:
	return false

func leaderboard_create_if_not_exists(leaderboard_id: String, sort_method: StoreIntegrations.SortMethod) -> void:
	print("leaderboard_create_if_not_exists(%s, %s)" % [leaderboard_id, StoreIntegrations.SortMethod.find_key(sort_method)])

func leaderboard_upload_score(leaderboard_id: String, score: float, keep_best: bool, steam_details: PackedInt32Array) -> bool:
	print("leaderboard_upload_score(%s, %.1f, %s, %s)" % [leaderboard_id, score, keep_best, steam_details])
	return true

func leaderboard_upload_completion(leaderboard_id: String, time_secs: float, mistakes: int, keep_best: bool, steam_details: PackedInt32Array) -> bool:
	print("leaderboard_upload_completion(%s, %.1f, %d, %s, %s)" % [leaderboard_id, time_secs, mistakes, keep_best, steam_details])
	return true

func leaderboard_download_completion(leaderboard_id: String, start: int, count: int) -> StoreIntegrations.LeaderboardData:
	print("leaderboard_download_completion(%s, %d, %d)" % [leaderboard_id, start, count])
	return null

func leaderboard_show(leaderboard_id: String, google_timespan: int, google_collection: int) -> void:
	print("leaderboard_show(%s, %d, %d)" % [leaderboard_id, google_timespan, google_collection])

func achievement_set(ach_id: String, steps: int, total_steps: int) -> void:
	print("achievement_set(%s, %d/%d)" % [ach_id, steps, total_steps])
	
func achievement_show_all() -> void:
	print("achievement_show_all()")
