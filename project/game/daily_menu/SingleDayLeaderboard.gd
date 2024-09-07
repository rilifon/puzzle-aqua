class_name SingleDayLeaderboard
extends ScrollContainer

@onready var Grid: GridContainer = %Grid
var cur_downloader: ImageDowloader = null
var steam_downloader: SteamDownloader = null

func _ready() -> void:
	clear_leaderboard()
	for c in ["Icon1", "Pos1", "NameContainer1", "Mistakes1", "Time1"]:
		Grid.get_node(c).hide()

func clear_leaderboard() -> void:
	# Leave the first five for copying so we don't need to programatically set stuff
	while Grid.get_child_count() > 10:
		var c := Grid.get_child(Grid.get_child_count() - 1)
		Grid.remove_child(c)
		c.queue_free()

class ImageDowloader extends Node:
	static var cache: Dictionary = {}
	var icons: Array[TextureRect] = []
	var urls: Array[String] = []
	var reqs: Array[HTTPRequest] = []
	var canceled := false
	var next_download_to_start := 0
	var current_downloads := 0
	func cancel() -> void:
		canceled = true
		for req in reqs:
			req.cancel_request()
		queue_free()
	func add_image(icon: TextureRect, url: String) -> void:
		if ImageDowloader.cache.has(url):
			var img := Image.new()
			img.load_jpg_from_buffer(ImageDowloader.cache[url])
			if is_instance_valid(icon):
				icon.texture = ImageTexture.create_from_image(img)
			return
		icons.append(icon)
		urls.append(url)
		var req := HTTPRequest.new()
		reqs.append(req)
		add_child(req)
		req.request_completed.connect(_request_completed.bind(icons.size() - 1, req))
	func continue_downloads() -> void:
		if not is_inside_tree():
			return
		while current_downloads < 5 and next_download_to_start < reqs.size():
			current_downloads += 1
			reqs[next_download_to_start].request(urls[next_download_to_start])
			next_download_to_start += 1
	func _request_completed(result: int, _response_code: int, _headers, body: PackedByteArray, i: int, req: HTTPRequest) -> void:
		print("[%d] Finished downloading %s" % [i, urls[i]])
		remove_child(req)
		req.queue_free()
		current_downloads -= 1
		continue_downloads()
		
		if result != OK:
			return
		var img := Image.new()
		var err
		if urls[i].ends_with(".png"):
			err = img.load_png_from_buffer(body)
		else:
			err = img.load_jpg_from_buffer(body)
		if err == OK:
			ImageDowloader.cache[urls[i]] = body
			img.generate_mipmaps()
			icons[i].texture = ImageTexture.create_from_image(img)
		else:
			push_warning("Failed to download image from %s" % [urls[i]])

class SteamDownloader extends Node:
	var icons: Array[TextureRect] = []
	var steam_ids: Array[int] = []
	static var mutex := DumbMutex.new()
	# id(int) -> Image
	static var cache: Dictionary = {}
	var free_if_done := false
	var canceled := false
	func cancel() -> void:
		canceled = true
		queue_free()
	func _process(_dt: float) -> void:
		if canceled or not is_inside_tree():
			queue_free()
			return
		if icons.is_empty():
			if free_if_done:
				queue_free()
			return
		var icon: TextureRect = icons.pop_front()
		var steam_id: int = steam_ids.pop_front()
		if not is_instance_valid(icon):
			return
		var image: Image = null
		if SteamDownloader.cache.has(steam_id):
			image = SteamDownloader.cache[steam_id]
		else:
			await SteamDownloader.mutex.lock()
			if SteamManager.steam.requestUserInformation(steam_id, false):
				await SteamManager.steam.persona_state_change
			SteamManager.steam.getPlayerAvatar(SteamManager.steam.AVATAR_LARGE, steam_id)
			var ret: Array = await SteamManager.steam.avatar_loaded
			if not canceled and ret != null and len(ret) > 2 and ret[1] > 0:
				image = Image.create_from_data(ret[1], ret[1], false, Image.FORMAT_RGBA8, ret[2])
				image.generate_mipmaps()
				SteamDownloader.cache[steam_id] = image
			SteamDownloader.mutex.unlock()
		if not canceled and image != null and is_instance_valid(icon):
			icon.texture = ImageTexture.create_from_image(image)

	func add_image(icon: TextureRect, steam_id: int) -> void:
		icons.append(icon)
		steam_ids.append(steam_id)

func set_date(date: String) -> void:
	Grid.get_node("Date").text = date

func display_day(data: RecurringMarathon.LeaderboardData, date: String) -> void:
	clear_leaderboard()
	if cur_downloader != null:
		remove_child(cur_downloader)
		cur_downloader.cancel()
	if steam_downloader != null and is_instance_valid(steam_downloader):
		remove_child(steam_downloader)
		steam_downloader.cancel()
	cur_downloader = ImageDowloader.new()
	add_child(cur_downloader)
	steam_downloader = SteamDownloader.new() if SteamManager.enabled else null
	# It is bugged and probably crashing the game
	steam_downloader = null
	if steam_downloader != null:
		add_child(steam_downloader)
	Grid.get_node("Date").text = date
	for i in data.list.size():
		var item: RecurringMarathon.ListEntry = data.list[i]
		var icon := Grid.get_node("Icon1").duplicate()
		if item.texture != null:
			icon.texture = item.texture
			icon.modulate = item.texture_modulate
		elif steam_downloader != null and item.image_steam_id != -1:
			steam_downloader.add_image(icon, item.image_steam_id)
		elif item.image_url != "":
			cur_downloader.add_image(icon, item.image_url)
		if i != data.self_idx:
			icon.get_node("PlayerBG").queue_free()
		var pos := Grid.get_node("Pos1").duplicate()
		pos.text = "%d." % item.global_rank
		var name_ := Grid.get_node("NameContainer1").duplicate()
		name_.get_node("Name").text = item.text
		name_.get_node("Name").tooltip_text = item.text
		var flair: Label = name_.get_node("Flair")
		var sflair: SelectableFlair = FlairManager.create_flair(item.flair.id) if item.flair != null else null
		flair.visible = sflair != null
		if sflair != null:
			flair.tooltip_text = sflair.description
			flair.text = " %s " % [sflair.text]
			flair.add_theme_color_override("font_color", sflair.color)
			var contrast_color := Global.get_contrast_background(sflair.color)
			contrast_color.a = 0.75
			flair.get_node("BG").modulate = contrast_color
			var plus: Label = flair.get_node("Plus")
			plus.visible = item.flair.extra_flairs > 0
			plus.text = "+%d" % [item.flair.extra_flairs]
		var mistakes := Grid.get_node("Mistakes1").duplicate()
		mistakes.text = str(item.mistakes)
		var time := Grid.get_node("Time1").duplicate()
		time.text = Level.time_str(item.secs)
		for c in [icon, pos, name_, mistakes, time]:
			c.show()
			Grid.add_child(c)
		await Global.get_tree().process_frame
	cur_downloader.continue_downloads()
	if steam_downloader != null:
		steam_downloader.free_if_done = true
	update_theme(Profile.get_option("dark_mode"))

func update_theme(_dark_mode: bool) -> void:
	pass
