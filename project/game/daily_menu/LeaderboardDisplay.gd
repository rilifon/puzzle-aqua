class_name LeaderboardDisplay
extends Control

# Ex. DAILY
@export var tr_name: String
	
@onready var Leaderboards: TabContainer = %TabContainer

func _single(s_name: String) -> SingleDayLeaderboard:
	var obj: SingleDayLeaderboard = load(^"res://game/daily_menu/SingleDayLeaderboard.tscn").instantiate()
	obj.name = s_name
	return obj

func _ready() -> void:
	Profile.dark_mode_toggled.connect(_update_theme)
	_update_theme(Profile.get_option("dark_mode"))
	assert(tr_name != "")
	var curr := tr("%s_CURR" % [tr_name])
	var prev := tr("%s_PREV" % [tr_name])
	Leaderboards.add_child(_single("%s (%s)" % [curr, tr("ALL")]))
	Leaderboards.add_child(_single("%s (%s)" % [curr, tr("FRIENDS")]))
	Leaderboards.add_child(_single("%s (%s)" % [prev, tr("ALL")]))
	Leaderboards.add_child(_single("%s (%s)" % [prev, tr("FRIENDS")]))

func display(current_data: Array[RecurringMarathon.LeaderboardData], current_date: String, previous: Array[RecurringMarathon.LeaderboardData], previous_date: String) -> void:
	if current_data.size() >= 1:
		Leaderboards.get_child(0).display_day(current_data[0], current_date)
	if current_data.size() >= 2:
		Leaderboards.get_child(1).display_day(current_data[1], current_date)
	if previous.size() >= 1:
		Leaderboards.get_child(2).display_day(previous[0], previous_date)
	if previous.size() >= 2:
		Leaderboards.get_child(3).display_day(previous[1], previous_date)

func show_current_all() -> void:
	Leaderboards.current_tab = 0

func _update_theme(dark_mode: bool) -> void:
	theme = Global.get_font_theme(dark_mode)
	for tab in Leaderboards.get_children():
		tab.update_theme(dark_mode)
