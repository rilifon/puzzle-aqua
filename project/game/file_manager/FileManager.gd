extends Node

const CURRENT_PROFILE := "user://cur_profile.txt"
const DATA_DIR := "res://database/levels"
const EXTRA_DIR := "res://database/extra_levels"
const DAILIES_DIR := "res://database/dailies"
const WEEKLIES_DIR := "res://database/weeklies"
const RANDOM_DIR := "res://database/random"
const DEFAULT_PROFILE := "fish"
const PROFILE_FILE := "profile.save"
const METADATA := ".metadata"
const JSON_EXT := ".json"
const LEVEL_FILE := "level.json"
const USER_DATA := "user.data"
const PREPROCESSED_JSON := "preprocessed.json"

var current_profile := DEFAULT_PROFILE

func _notification(what: int) -> void:
	if what == MainLoop.NOTIFICATION_CRASH:
		save_game()

func _ready() -> void:
	# This is very important, so let's do it early
	load_current_profile()

func save_game() -> void:
	save_current_profile()
	save_profile()
	UserData.save()

func load_game() -> void:
	StoreIntegrations.load_leaderboards_mapping_from_json("res://database/mappings/leaderboards.json")
	load_current_profile()
	load_profile()

func load_current_profile() -> void:
	if not FileAccess.file_exists(CURRENT_PROFILE):
		return change_current_profile(DEFAULT_PROFILE)
	var file := FileAccess.open(CURRENT_PROFILE, FileAccess.READ)
	var profile_name := file.get_as_text().strip_edges()
	if profile_name.is_valid_identifier():
		current_profile = profile_name
	else:
		current_profile = DEFAULT_PROFILE

func save_current_profile() -> void:
	var file := FileAccess.open(CURRENT_PROFILE, FileAccess.WRITE)
	file.store_string(current_profile)

func change_current_profile(profile: String) -> void:
	current_profile = profile
	save_current_profile()
	load_profile()

func get_current_profile() -> String:
	return current_profile

# Does not clear editor levels
func clear_whole_profile(profile: String) -> void:
	clear_profile(profile)
	CampaignLevelLister.clear_all_level_saves(profile)
	ExtraLevelLister.clear_all_level_saves(profile)
	clear_user_data(profile)
	if profile == current_profile:
		# Reload stuff if necessary
		change_current_profile(profile)

func _profile_dir(profile := "") -> String:
	if profile.is_empty():
		profile = current_profile
	return "user://%s" % profile

func _assert_dir(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)

func _load_json_data(dir_name: String, file_name: String, error_non_existing := true) -> Variant:
	file_name = "%s/%s" % [dir_name, file_name]
	var file := FileAccess.open(file_name, FileAccess.READ)
	if file == null:
		if error_non_existing or FileAccess.get_open_error() != Error.ERR_FILE_NOT_FOUND:
			push_error("Error trying to open %s whilst loading: %d" % [file_name, FileAccess.get_open_error()])
		return null
	var json := JSON.new()
	if json.parse(file.get_as_text()) != Error.OK:
		push_error("Error parsing JSON on line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return null
	return json.get_data()

func _save_json_data(dir_name: String, file_name: String, data: Variant) -> void:
	_assert_dir(dir_name)
	assert(data is Dictionary or data is Array)
	var file := FileAccess.open("%s/%s" % [dir_name, file_name], FileAccess.WRITE)
	if file == null:
		push_error("Error trying to open file %s/%s whilst saving: %d" % [dir_name, file_name, FileAccess.get_open_error()])
	file.store_string(JSON.stringify(data))

func _delete_file(dir_name: String, file_name: String) -> void:
	file_name = "%s/%s" % [dir_name, file_name]
	if FileAccess.file_exists(file_name):
		DirAccess.remove_absolute(file_name)

# TODO: Rename to settings
func load_profile() -> void:
	if not FileAccess.file_exists("%s/%s" % [_profile_dir(), PROFILE_FILE]):
		push_warning("Profile file not found. Starting a new profile file.")
		save_profile()
	Profile.set_save_data(_load_json_data(_profile_dir(), PROFILE_FILE))

func save_profile() -> void:
	var profile_data := Profile.get_save_data()
	_save_json_data(_profile_dir(), PROFILE_FILE, profile_data)
	if not Global.is_mobile:
		var override := Profile.get_override()
		var err := override.save(ProjectSettings.get_setting_with_override(&"application/config/project_settings_override"))
		if err != OK:
			push_error("Error while writing override: %s" % [err])

func clear_profile(profile: String) -> void:
	_delete_file(_profile_dir(profile), PROFILE_FILE)


func _level_dir(profile := "") -> String:
	return "%s/levels" % _profile_dir(profile)

func _recurring_dir(profile := "") -> String:
	return "%s/recurring" % [_profile_dir(profile)]

func _level_file(level: String) -> String:
	return "%s.save" % level

func has_level(level_name: String) -> bool:
	return FileAccess.file_exists("%s/%s" % [_level_dir(), _level_file(level_name)])

func load_level(level_name: String, profile := "") -> UserLevelSaveData:
	return UserLevelSaveData.load_data(_load_json_data(_level_dir(profile), _level_file(level_name), false))

func save_level(level_name: String, data: UserLevelSaveData) -> void:
	_save_json_data(_level_dir(), _level_file(level_name), data.get_data())

func clear_level(level_name: String, profile := "") -> void:
	_delete_file(_level_dir(profile), _level_file(level_name))

func level_has_solution(level_name: String, profile: String) -> bool:
	return not load_level(level_name, profile).grid_data.is_empty()


func _editor_metadata_dir(profile := "") -> String:
	return "%s/editor" % _profile_dir(profile)


func _editor_level_dir(id: String, profile := "") -> String:
	return "%s/%s" % [_editor_metadata_dir(profile), id]

func load_editor_levels() -> Dictionary:
	var ans = {}
	if DirAccess.dir_exists_absolute(_editor_metadata_dir()):
		for file in DirAccess.get_files_at(_editor_metadata_dir()):
			if file.ends_with(METADATA):
				var id := file.substr(0, file.length() - METADATA.length())
				ans[id] = EditorLevelMetadata.load_data(_load_json_data(_editor_metadata_dir(), file))
	return ans

func save_editor_level(id: String, metadata: EditorLevelMetadata, data: LevelData) -> void:
	if metadata != null:
		_save_json_data(_editor_metadata_dir(), id + METADATA, metadata.get_data())
	if data != null:
		_save_json_data(_editor_level_dir(id), LEVEL_FILE, data.get_data())

func load_editor_level(id: String) -> LevelData:
	var data := LevelData.load_data(_load_json_data(_editor_level_dir(id), LEVEL_FILE))
	return data

func load_editor_level_metadata(id: String) -> EditorLevelMetadata:
	return EditorLevelMetadata.load_data(_load_json_data(_editor_metadata_dir(), id + METADATA))


func clear_editor_level(id: String, profile := "") -> void:
	var level_dir := _editor_level_dir(id, profile)
	_delete_file(level_dir, LEVEL_FILE)
	_delete_file(_editor_metadata_dir(profile), id + METADATA)
	if DirAccess.dir_exists_absolute(level_dir):
		DirAccess.remove_absolute(level_dir)

func _no_tutorial(data: LevelData) -> void:
	if data != null:
		assert(data.tutorial.is_empty(), "Level can't have tutorial")
		data.tutorial = ""

func _has_difficulty(data: LevelData) -> void:
	if data != null:
		assert(data.difficulty != -1, "Random level must have difficulty")
		if data.difficulty == -1:
			data.difficulty = RandomHub.Difficulty.Easy

func load_workshop_level(dir: String) -> LevelData:
	var data := LevelData.load_data(_load_json_data(dir, LEVEL_FILE))
	_no_tutorial(data)
	return data

const RANDOM := "random.json"

func load_random_level() -> LevelData:
	var data := LevelData.load_data(_load_json_data(_level_dir(), RANDOM))
	_has_difficulty(data)
	_no_tutorial(data)
	return data

func save_random_level(data: LevelData) -> void:
	_has_difficulty(data)
	_no_tutorial(data)
	_save_json_data(_level_dir(), RANDOM, data.get_data())

func _endless_json(section: int) -> String:
	return ExtraLevelLister.endless_level_name(section) + JSON_EXT

func load_extra_endless_level(section: int) -> LevelData:
	var data := LevelData.load_data(_load_json_data(_level_dir(), _endless_json(section)))
	_no_tutorial(data)
	return data

func save_extra_endless_level(section: int, data: LevelData) -> void:
	_no_tutorial(data)
	_save_json_data(_level_dir(), _endless_json(section), data.get_data())

func _daily_basename(date: String) -> String:
	return "daily_%s" % date

func has_recurring_level_data(level_name: String) -> bool:
	return FileAccess.file_exists("%s/%s%s" % [_recurring_dir(), level_name, JSON_EXT])

func load_recurring_level_data(level_name: String) -> LevelData:
	var data := LevelData.load_data(_load_json_data(_recurring_dir(), level_name + JSON_EXT))
	_no_tutorial(data)
	return data

func save_recurring_level_data(level_name: String, data: LevelData) -> void:
	_no_tutorial(data)
	_save_json_data(_recurring_dir(), level_name + JSON_EXT, data.get_data())

func load_daily_level(date: String) -> LevelData:
	var data := LevelData.load_data(_load_json_data(_level_dir(), _daily_basename(date) + JSON_EXT))
	_no_tutorial(data)
	return data

func save_daily_level(date: String, data: LevelData) -> void:
	_no_tutorial(data)
	_save_json_data(_level_dir(), _daily_basename(date) + JSON_EXT, data.get_data())

func has_daily_level(date: String) -> bool:
	return FileAccess.file_exists("%s/%s%s" % [_level_dir(), _daily_basename(date), JSON_EXT])

func _extra_level_data_dir(section: int) -> String:
	return "%s/%02d" % [EXTRA_DIR, section]

func has_extra_level_data(section: int, level: int) -> bool:
	return FileAccess.file_exists("%s/%s" % [_extra_level_data_dir(section), _level_data_file(level)])

func load_extra_level_data(section: int, level: int) -> LevelData:
	var data := LevelData.load_data(_load_json_data(_extra_level_data_dir(section), _level_data_file(level)))
	assert(not data.full_name.is_empty())
	return data

func _campaign_level_data_dir(section: int) -> String:
	return "%s/%02d" % [DATA_DIR, section]

func _level_data_file(level: int) -> String:
	return "%02d.json" % level

func has_campaign_level(section: int, level: int) -> bool:
	return FileAccess.file_exists("%s/%s" % [_campaign_level_data_dir(section), _level_data_file(level)])

func load_campaign_level_data(section: int, level: int) -> LevelData:
	var data := LevelData.load_data(_load_json_data(_campaign_level_data_dir(section), _level_data_file(level)))
	assert(not data.full_name.is_empty())
	return data

# If this becomes very used, we can cache it
func _load_user_data() -> UserData:
	return UserData.load_data(_load_json_data(_profile_dir(), USER_DATA, false))

func _save_user_data(data: UserData) -> void:
	_save_json_data(_profile_dir(), USER_DATA, data.get_data())

func clear_user_data(profile: String) -> void:
	_delete_file(_profile_dir(profile), USER_DATA)

func load_dailies(year: int) -> PreprocessedDailies:
	return PreprocessedDailies.load_data(_load_json_data(DAILIES_DIR, str(year) + JSON_EXT))

func save_dailies(year: int, data: PreprocessedDailies) -> void:
	_save_json_data(DAILIES_DIR, str(year) + JSON_EXT, data.get_data())

func _dif_filename(dif: RandomHub.Difficulty) -> String:
	return RandomHub.Difficulty.find_key(dif).to_lower() + JSON_EXT

func load_preprocessed_difficulty(dif: RandomHub.Difficulty) -> PreprocessedDifficulty:
	return PreprocessedDifficulty.load_data(dif, _load_json_data(RANDOM_DIR, _dif_filename(dif)))

func save_preprocessed_difficulty(data: PreprocessedDifficulty) -> void:
	_save_json_data(RANDOM_DIR, _dif_filename(data.difficulty), data.get_data())

func load_preprocessed_endless(section: int) -> PreprocessedEndless:
	return PreprocessedEndless.load_data(_load_json_data(_extra_level_data_dir(section), PREPROCESSED_JSON))

func save_preprocessed_endless(section: int, data: PreprocessedEndless) -> void:
	_save_json_data(_extra_level_data_dir(section), PREPROCESSED_JSON, data.get_data())

func load_preprocessed_weeklies(year: int) -> PreprocessedWeeklies:
	return PreprocessedWeeklies.load_data(_load_json_data(WEEKLIES_DIR, str(year) + JSON_EXT))

func save_preprocessed_weeklies(year: int, data: PreprocessedWeeklies) -> void:
	_save_json_data(WEEKLIES_DIR, str(year) + JSON_EXT, data.get_data())

func _flavor_dir(s_name: String) -> String:
	return "res://database/flavors/%s" % [s_name]

func has_flavor_seed(s_name: String, level: int) -> bool:
	return FileAccess.file_exists("%s/%s" % [_flavor_dir(s_name), _level_data_file(level)])

func load_flavor_seed(s_name: String, level: int) -> LevelData:
	var data := LevelData.load_data(_load_json_data(_flavor_dir(s_name), _level_data_file(level)))
	assert(not data.full_name.is_empty())
	_no_tutorial(data)
	return data
