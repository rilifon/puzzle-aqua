class_name FlairManager


static func get_flair_amount():
	return get_flair_list().size()

static func _monthly_flairs() -> Array[SelectableFlair]:
	var S := TranslationServer.get_translation_object(TranslationServer.get_locale())
	var arr: Array[SelectableFlair] = []
	var data := UserData.current()
	var cur_year := 2024
	var cur_month := 1
	var rng := RandomNumberGenerator.new()
	for i in data.monthly_good_dailies.size():
		cur_month += 1
		if cur_month == 13:
			cur_month = 1
			cur_year += 1
		if data.monthly_good_dailies[i] >= 15:
			rng.seed = RandomHub.consistent_hash("%d-%d" % [cur_month, cur_year])
			arr.append(SelectableFlair.new(
				"pro_%d_%d" % [cur_month, cur_year],
				"pro",
				Color.from_hsv(rng.randf(), 0.663, 0.804, 1),
				S.tr("MONTHLY_FLAIR_DESC").format({
					month=S.tr("MONTH_%02d" % [cur_month]),
					year=cur_year,
				})
			))
	return arr

# Memoize for 60 seconds
static var _list: Array[SelectableFlair] = []
static var _last_update: int = -1000000

static func get_flair_list() -> Array[SelectableFlair]:
	if _last_update >= Time.get_ticks_msec() - 60000:
		return _list
	var data := UserData.current()
	var arr: Array[SelectableFlair] = []
	if SteamManager.enabled and RecurringMarathon.DEV_IDS.has(SteamManager.steam.getSteamID()):
		arr.append(SelectableFlair.new(
			"dev",
			"dev",
			Color(0.0784314, 0.364706, 0.529412, 1),
			"DEVELOPER_FLAIR_DESCRIPTION",
		))
	arr.append_array(_monthly_flairs())
	if data.best_streak[RecurringMarathon.Type.Daily] >= 30:
		arr.append(SelectableFlair.new(
			"best_streak_30_plus",
			"30🔥",
			Color.ORANGE_RED,
			"FLAIR_30_STREAK_DESC",
		))
	if data.random_levels_completed[RandomHub.Difficulty.Insane] >= 100:
		arr.append(SelectableFlair.new(
			"insane_100",
			"100",
			Color.BLACK,
			"FLAIR_100_DESC",
		))
	if CampaignLevelLister.all_campaign_levels_completed():
		arr.append(SelectableFlair.new(
			"main_campaign_finished",
			"won",
			Color.GREEN,
			"FLAIR_WON_DESC",
		))
	var extra_section := 1
	while ExtraLevelLister.has_section(extra_section):
		if not ExtraLevelLister.is_free(extra_section) and not ExtraLevelLister.section_disabled(extra_section):
			arr.append(SelectableFlair.new(
				"dlc_bought",
				"❤",
				Color.HOT_PINK,
				"FLAIR_DLC_DESC",
			))
			break
		extra_section += 1
	if SteamManager.enabled and Steam.isSubscribedApp(827940):
		arr.append(SelectableFlair.new(
			"marvinc_bought",
			"inc",
			Color.GREEN,
			"FLAIR_INC_DESC",
		))
	if SteamManager.enabled and Steam.isSubscribedApp(1636730):
		arr.append(SelectableFlair.new(
			"functional_bought",
			"λ",
			Color.GRAY,
			"FLAIR_FUNCTIONAL_DESC",
		))
	_list = arr
	return _list

static func get_current_flair() -> SelectableFlair:
	var list = get_flair_list()
	if list.size() > 0:
		var flair_id = str(UserData.current().selected_flair)
		for flair in get_flair_list():
			if flair.id == flair_id:
				return flair
		#Not a valid flair, choosing first as sslected
		var first = get_flair_list().front()
		set_selected_flair_id(first.id)
		return first
	else:
		return null

static func set_selected_flair_id(id: String) -> void:
	UserData.current().selected_flair = id
	UserData.save()
