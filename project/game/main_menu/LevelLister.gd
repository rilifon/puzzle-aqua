class_name LevelLister
extends Node

func level_name(_section: int, _level: int) -> String:
	return GridModel.must_be_implemented()

func has_section(_section: int) -> int:
	return GridModel.must_be_implemented()

func count_all_game_sections() -> int:
	return GridModel.must_be_implemented()

func get_max_unlocked_level(_section: int) -> int:
	return GridModel.must_be_implemented()

func get_disabled_section_free_trial(_section: int) -> Array:
	return GridModel.must_be_implemented()

func count_section_levels(_section: int) -> int:
	return GridModel.must_be_implemented()

func get_max_unlocked_levels(_section: int) -> int:
	return GridModel.must_be_implemented()

func count_completed_section_levels(_section: int) -> int:
	return GridModel.must_be_implemented()

func count_section_ongoing_solutions(_section: int) -> int:
	return GridModel.must_be_implemented()
	
func get_level_user_save(_section: int, _level: int) -> UserLevelSaveData:
	return GridModel.must_be_implemented()

func get_level_data(_section: int, _level: int) -> LevelData:
	return GridModel.must_be_implemented()

# Stat stored on steam stats
func level_stat(_section: int, _level: int) -> String:
	return GridModel.must_be_implemented()

# Section name, if it has one
func section_name(_section: int) -> String:
	return GridModel.must_be_implemented()

func section_disabled(_section: int) -> bool:
	return GridModel.must_be_implemented()

func is_hard(_section: int, _level: int) -> bool:
	return GridModel.must_be_implemented()

func count_completed_levels(_profile_name: String) -> int:
	return GridModel.must_be_implemented()

func clear_all_level_saves(_profile_name: String) -> void:
	return GridModel.must_be_implemented()
