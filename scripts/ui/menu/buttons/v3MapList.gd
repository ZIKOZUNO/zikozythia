extends Control

signal search_updated
signal reset_filters
signal lock_type

# Zikozythia: continuous smooth scrolling (like the original client / a
# website). A float scroll position is chased every frame and cards are
# positioned and recycled around the visible window, instead of the old
# page-step collapse/expand animation.

var thread: Thread

var songs: Array = Rhythia.registry_song.get_items()

var search_text: String = ""
var author_search_text: String = ""
var difficulty_filter: Array = Rhythia.last_difficulty_filter
var show_broken_maps: bool = false
var show_online_maps: bool = true
var flip_display: bool = false
var flip_name: bool = false

var cur_map: int = 0
var page_size: int = 10

var favorite: Array = []
var easy: Array = []
var medium: Array = []
var hard: Array = []
var logic: Array = []
var amogus: Array = []
var unknown: Array = []

var disp: Array = []

var ready: bool = false

var scroll_up: bool = false
var scroll_down: bool = false

const ROW = 92.0
const CHASE = 14.0

var scroll_pos: float = 0.0
var target_pos: float = 0.0

var cards := {}

var drag_down: bool = false
var dragging: bool = false
var dragged: bool = false
var drag_start: Vector2 = Vector2()
var last_drag_pos: Vector2 = Vector2()
var drag_vel: float = 0.0

var size_x: int = 0

func is_fav(s: Song): return favorite.has(s)

func search_matches(s: Song):
	return (
		difficulty_filter.has(s.difficulty) and 
		( not s.is_online or show_online_maps) and 
		( not s.is_broken or show_broken_maps) and 
		(search_text == "" or s.name.to_lower().find(search_text.to_lower()) != - 1) and 
		(author_search_text == "" or s.creator.to_lower().find(author_search_text.to_lower()) != - 1)
	)

var has_been_pressed = false

func play_song():
	if not Rhythia.selected_song: return
	if has_been_pressed: return
	emit_signal("lock_type")
	has_been_pressed = true
	get_viewport().get_node("Menu").black_fade_target = true
	yield(get_tree().create_timer(0.35), "timeout")
	get_tree().change_scene("res://scenes/loaders/songload.tscn")

var pt = 1
func on_pressed(i):
	if dragged:
		dragged = false
		return
	if i < 0 or i >= disp.size(): return
	$Press.play()
	scroll_to(i)

	var s: Song = disp[i]
	if s != Rhythia.selected_song:
		Rhythia.select_song(s)
	else:
		if pt < 0.25:
			drag_down = false
			dragging = false
			play_song()
	pt = 0
	get_viewport().get_node("Menu/Main/Maps/Results").visible = true

func switch_to_play_screen():
	size_list()
	if Rhythia.menu_target == "res://scenes/menu/menu.tscn": return
	if disp.find(Rhythia.registry_song.get_item(Rhythia.selected_song.id)) == - 1:
		reset_filters()
	get_viewport().get_node("Menu/Sidebar").press(0, true)
	cur_map = disp.find(Rhythia.registry_song.get_item(Rhythia.selected_song.id))
	load_pg(true)

var was_maximized = OS.window_maximized
var was_fullscreen = OS.window_fullscreen

func _process(delta):
	if OS.window_maximized != was_maximized or OS.window_fullscreen != was_fullscreen:
		was_maximized = OS.window_maximized
		was_fullscreen = OS.window_fullscreen
		handle_window_resize()

	var max_pos = max(float(disp.size() - 1), 0.0)

	# held scroll buttons - continuous
	if scroll_down:
		target_pos += delta * 14.0
	if scroll_up:
		target_pos -= delta * 14.0

	# drag - 1:1 tracking like a website
	if drag_down:
		var mp = get_global_mouse_position()
		if not dragging and abs(mp.y - drag_start.y) > 12.0:
			dragging = true
		if dragging:
			var dy = mp.y - last_drag_pos.y
			last_drag_pos = mp
			target_pos -= dy / ROW
			target_pos = clamp(target_pos, 0.0, max_pos)
			scroll_pos = target_pos
			drag_vel = lerp(drag_vel, (dy / ROW) / max(delta, 0.001), 0.35)

	# smooth chase toward the target
	if not drag_down:
		var diff = target_pos - scroll_pos
		scroll_pos += diff * (1.0 - exp(-delta * CHASE))
		if abs(diff) < 0.001:
			scroll_pos = target_pos

	target_pos = clamp(target_pos, 0.0, max_pos)
	scroll_pos = clamp(scroll_pos, 0.0, max_pos)
	cur_map = int(round(scroll_pos))

	# select the centered song once the scroll settles
	if not drag_down and abs(target_pos - scroll_pos) < 0.08:
		var cm = int(round(scroll_pos))
		if cm >= 0 and cm < disp.size() and disp[cm] != Rhythia.selected_song:
			Rhythia.select_song(disp[cm])

	pt += delta
	_update_window()

func check_drag_on():
	drag_down = true
	dragging = false
	drag_vel = 0.0
	drag_start = get_global_mouse_position()
	last_drag_pos = drag_start

func check_drag_off():
	if dragging:
		dragged = true
		var max_pos = max(float(disp.size() - 1), 0.0)
		target_pos = clamp(target_pos - drag_vel * 0.22, 0.0, max_pos)
	drag_down = false
	dragging = false

func select_random():
	if disp.size() == 0: return
	cur_map = randi() % disp.size()
	load_pg(true)

func load_pg(select_cur: bool = false):
	size_list()
	for i in cards:
		cards[i].queue_free()
	cards.clear()

	if disp.size() == 0: return
	page_size = int((get_parent().rect_size.y / 90.0) * 1.5)
	if page_size % 2 != 0:
		page_size += 1

	cur_map = clamp(cur_map, 0, disp.size() - 1)
	target_pos = float(cur_map)
	scroll_pos = target_pos
	if select_cur:
		if disp[cur_map] != Rhythia.selected_song:
			Rhythia.select_song(disp[cur_map])
	_update_window()

func _update_window():
	if disp.size() == 0: return
	# row offset of the centered song, matching the original list layout
	var mid = int(floor(((page_size + 1) / 2) * 1.2))
	var lo = int(floor(scroll_pos)) - mid - 1
	var hi = int(ceil(scroll_pos)) + mid + 1

	for i in range(max(lo, 0), min(hi, disp.size() - 1) + 1):
		if not cards.has(i):
			var btn = make_song_button(i)
			btn.rect_min_size = Vector2(size_x - 50, 90)
			add_child(btn)
			btn.visible = true
			cards[i] = btn

	for i in cards:
		var btn = cards[i]
		var dist = abs(float(i) - scroll_pos)
		btn.rect_min_size.x = max(size_x - (15.0 * dist), size_x - 260.0)
		btn.rect_position.y = ((float(i) - scroll_pos + float(mid)) * ROW) - 2.0
		btn.get_node("Select").pressed = (btn.song == Rhythia.selected_song)

	var kill := []
	for i in cards:
		if i < lo or i > hi:
			kill.append(i)
	for i in kill:
		cards[i].queue_free()
		cards.erase(i)

func append_filtering_favorites(to: Array, from: Array):
	for s in from:
		if not is_fav(s) and search_matches(s):
			to.append(s)


func build_list():
	disp = []
	favorite = []
	for id in Rhythia.favorite_songs:
		var s = Rhythia.registry_song.get_item(id)
		if s and Rhythia.is_favorite(id) and search_matches(s):
			favorite.append(s)
	favorite.sort_custom(self, "sortsong")
	disp.append_array(favorite)
	if flip_display:
		append_filtering_favorites(disp, amogus)
		append_filtering_favorites(disp, logic)
		append_filtering_favorites(disp, hard)
		append_filtering_favorites(disp, medium)
		append_filtering_favorites(disp, easy)
		append_filtering_favorites(disp, unknown)
	else:
		append_filtering_favorites(disp, easy)
		append_filtering_favorites(disp, medium)
		append_filtering_favorites(disp, hard)
		append_filtering_favorites(disp, logic)
		append_filtering_favorites(disp, amogus)
		append_filtering_favorites(disp, unknown)

func reload_to_current_page(_a = null):
	build_list()
	load_pg()

func update_search_text(txt: String):
	search_text = txt
	if ready: reload_to_current_page()
	emit_signal("search_updated")

func update_author_search_text(txt: String):
	author_search_text = txt
	if ready: reload_to_current_page()
	emit_signal("search_updated")

func update_search_dfil(dfil: Array):
	difficulty_filter = dfil
	Rhythia.last_difficulty_filter = dfil
	if ready: reload_to_current_page()
	emit_signal("search_updated")

func update_search_showbroken(show: bool):
	show_broken_maps = show
	if ready: reload_to_current_page()

func update_search_showonline(show: bool):
	show_online_maps = show
	if ready: reload_to_current_page()

func update_search_flipped(flip: bool):
	flip_display = flip
	if ready: reload_to_current_page()

func update_search_flip_name(flip: bool):
	flip_name = flip
	easy.sort_custom(self, "sortsongsimple")
	medium.sort_custom(self, "sortsongsimple")
	hard.sort_custom(self, "sortsongsimple")
	logic.sort_custom(self, "sortsongsimple")
	amogus.sort_custom(self, "sortsongsimple")
	if ready: reload_to_current_page()

func sortab(a, b): return a < b

func sortsongsimple(a: Song, b: Song):
	if flip_name:
		if a.name != b.name: return a.name.to_lower() > b.name.to_lower()
		else: return a.id > b.id
	else:
		if a.name != b.name: return a.name.to_lower() < b.name.to_lower()
		else: return a.id < b.id

func sortsong(a: Song, b: Song):
	var ad = a.difficulty
	var bd = b.difficulty
	if ad == - 1: ad = 255
	if bd == - 1: bd = 255
	if ad != bd:
		if flip_display: return ad > bd
		else: return ad < bd
	else: return sortsongsimple(a, b)

func reset_filters():
	print("resetting filters")
	emit_signal("reset_filters")
	update_search_dfil([Globals.DIFF_UNKNOWN, Globals.DIFF_EASY, Globals.DIFF_MEDIUM, Globals.DIFF_HARD, Globals.DIFF_LOGIC, Globals.DIFF_AMOGUS])
	update_search_showbroken(false)

	update_search_flipped(false)
	update_search_flip_name(false)

func prepare_songs():
	for i in range(songs.size()):
		var map: Song = songs[i]
		var add_to: Array
		match map.difficulty:
			Globals.DIFF_EASY: add_to = easy
			Globals.DIFF_MEDIUM: add_to = medium
			Globals.DIFF_HARD: add_to = hard
			Globals.DIFF_LOGIC: add_to = logic
			Globals.DIFF_AMOGUS: add_to = amogus
			_: add_to = unknown
		
		if add_to.find(map) == - 1:
			add_to.append(map)
	easy.sort_custom(self, "sortsongsimple")
	medium.sort_custom(self, "sortsongsimple")
	hard.sort_custom(self, "sortsongsimple")
	logic.sort_custom(self, "sortsongsimple")
	amogus.sort_custom(self, "sortsongsimple")

func make_song_button(id: int = - 1):
	if id < 0 or id >= disp.size():
		var btn: Panel = $EMPTY.duplicate()
		btn.rect_min_size = Vector2(int(size_x - (page_size / 2) * 10), 0)
		return btn
	var map: Song = disp[id]
	if map == null: return
	var btn: Panel
	match map.difficulty:
		Globals.DIFF_EASY: btn = $EASY.duplicate()
		Globals.DIFF_MEDIUM: btn = $MEDIUM.duplicate()
		Globals.DIFF_HARD: btn = $HARD.duplicate()
		Globals.DIFF_LOGIC: btn = $LOGIC.duplicate()
		Globals.DIFF_AMOGUS: btn = $AMOGUS.duplicate()
		_: btn = $NODIF.duplicate()
	btn.rect_min_size = Vector2(size_x - 50, 0)
	btn.get_node("Label").visible = false
	if map.has_cover:
		btn.get_node("Cover").visible = true
		btn.get_node("Cover").texture = map.cover
	btn.get_node("Name").visible = true
	if map.name.length() > 55:
		btn.get_node("Name").text = strip_diacritics(map.name)
	else:
		btn.get_node("Name").text = map.name
	btn.song = map
	if map.warning != "" or map.is_broken:
		if map.is_broken: btn.get_node("Name").modulate = Color(1, 0.4, 0.4)
		else: btn.get_node("Name").modulate = Color(1, 1, 0.2)
	var rbtn: Button = btn.get_node("Select")
	if is_fav(map): btn.get_node("F").visible = true
	btn.get_node("Cloud").visible = map.is_online
	rbtn.disabled = false
	rbtn.connect("pressed", self, "on_pressed", [id])
	
	rbtn.action_mode = 1
	rbtn.connect("button_down", self, "check_drag_on")
	rbtn.connect("button_up", self, "check_drag_off")
	rbtn.keep_pressed_outside = true
	if map == Rhythia.selected_song:
		btn.get_node("Select").pressed = true
	return btn

func _input(ev: InputEvent):
	if is_visible_in_tree() and ev is InputEventMouseButton and ev.is_pressed():
		if ev.button_index == BUTTON_WHEEL_UP:
			target_pos = max(target_pos - 1.0, 0.0)
		elif ev.button_index == BUTTON_WHEEL_DOWN:
			target_pos = min(target_pos + 1.0, max(float(disp.size() - 1), 0.0))
	if ev is InputEventKey and ev.is_pressed():
		
		if ev.scancode == KEY_F2:
			print("F2")
			select_random()
		

func handle_window_resize():

	if ready: size_list()

func firstload():

	get_parent().get_parent().get_parent().get_node("ScrollControl/P").connect("button_down", self, "pg_down_cont")
	get_parent().get_parent().get_parent().get_node("ScrollControl/M").connect("button_down", self, "pg_up_cont")
	get_parent().get_parent().get_parent().get_node("ScrollControl/P").connect("button_up", self, "pg_down_stop")
	get_parent().get_parent().get_parent().get_node("ScrollControl/M").connect("button_up", self, "pg_up_stop")
	
	get_parent().get_parent().get_node("T/Random").connect("pressed", self, "select_random")
	prepare_songs()
	reload_to_current_page()
	ready = true
	Rhythia.connect("favorite_songs_changed", self, "reload_to_current_page")
	Rhythia.connect("download_done", self, "update_clouds")
	get_viewport().connect("size_changed", self, "handle_window_resize")
	Rhythia.emit_signal("map_list_ready")

func update_clouds():
	for btn in cards.values():
		if btn.has_node("Cloud") and btn.song:
			btn.get_node("Cloud").visible = btn.song.is_online

func pg_up():
	target_pos = max(target_pos - 1.0, 0.0)

func pg_down():
	target_pos = min(target_pos + 1.0, max(float(disp.size() - 1), 0.0))

func pg_up_cont():
	scroll_up = true
	
func pg_up_stop():
	scroll_up = false

func pg_down_cont():
	scroll_down = true

func pg_down_stop():
	scroll_down = false

func scroll_to(i: int):
	if i < 0 or i >= disp.size(): return
	target_pos = float(i)

func _ready():
	thread = Thread.new()
	thread.start(self, "_load_covers")

	randomize()
	if not visible: return
	$EASY.visible = false
	$MEDIUM.visible = false
	$HARD.visible = false
	$LOGIC.visible = false
	$AMOGUS.visible = false
	$NODIF.visible = false
	$EMPTY.visible = false

	difficulty_filter = Rhythia.last_difficulty_filter

	Engine.iterations_per_second = 60
	call_deferred("firstload")
	
	

	size_list()
	
	print("size_x: ", size_x)

func _exit_tree():
	thread.wait_to_finish()

func size_list():
	size_x = get_viewport_rect().size.x / 2.8
	$"..".rect_min_size.x = size_x

func _load_covers():
	var allmaps: Array = Rhythia.registry_song.get_items()
	for i in range(allmaps.size()):
		allmaps[i]._get_cover()

func strip_diacritics(s: String):








	var pool: PoolByteArray = s.to_utf8()

	var output_bytes: Array = []
	
	
	var byte_values_to_remove = [
		128, 129, 130, 131, 132, 133, 134, 
		135, 136, 137, 138, 139, 140, 141, 
		142, 143, 144, 145, 146, 147, 148, 
		149, 150, 151, 152, 153, 154, 155, 
		156, 157, 158, 159, 160, 161, 162, 
		163, 164, 165, 166, 167, 168, 169, 
		170, 171, 172, 173, 174, 175, 176, 
		177, 178, 179, 180, 181, 182, 183, 
		184, 185, 186, 187, 188, 189, 190, 
		191, 128, 129, 130, 131, 132, 133, 
		134, 135, 136, 137, 138, 139, 140, 
		141, 142, 143, 144, 145, 146, 147, 
		148, 149, 150, 151, 152, 153, 154, 
		155, 156, 157, 158, 159, 160, 161
	]
	

	var removed: bool = false
	for i in range(pool.size() - 1, - 1, - 1):
		if removed:
			removed = false
			continue
		var byte_value = pool[i]
		var prev_byte = - 1
		if i != 0:
			prev_byte = pool[i - 1]
		
		if byte_value in byte_values_to_remove:
			
			if prev_byte == 204 or prev_byte == 205:
				removed = true
				continue
		output_bytes.insert(0, byte_value)
	
	return PoolByteArray(output_bytes).get_string_from_utf8()
