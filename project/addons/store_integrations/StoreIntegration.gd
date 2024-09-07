class_name StoreIntegration
extends Node

static func available() -> bool:
	return false

func process(_dt: float) -> void:
	pass

func authenticated() -> bool:
	return false

func add_leaderboard_mappings(lds: Array[StoreIntegrations.LeaderboardMapping]) -> void:
	pass

func leaderboard_create_if_not_exists(_leaderboard_id: String, _sort_method: StoreIntegrations.SortMethod) -> void:
	await null

func leaderboard_upload_completion(_leaderboard_id: String, _time_secs: float, _mistakes: int, _keep_best: bool, _steam_details: PackedInt32Array) -> bool:
	await null
	return true

func leaderboard_upload_score(_leaderboard_id: String, _score: float, _keep_best: bool, _steam_details: PackedInt32Array) -> bool:
	await null
	return true

func leaderboard_show(_leaderboard_id: String, _google_timespan: int, _google_collection: int) -> void:
	await null

func leaderboard_download_completion(_leaderboard_id: String, _start: int, _count: int) -> StoreIntegrations.LeaderboardData:
	await null
	return null

func achievement_set(_ach_id: String, _steps: int, _total_steps: int) -> void:
	await null

func achievement_show_all() -> void:
	await null
