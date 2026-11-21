extends Control

func comma_sep(number):
	var string = str(number)
	var mod = string.length() % 3
	var res = ""
	
	for i in range(0, string.length()):
		if i != 0 and i % 3 == mod:
			res += ","
		res += string[i]
	
	return res

func get_time_ms(ms: float):
	var s = max(floor(ms / 1000), 0)
	var m = floor(s / 60)
	var rs = fmod(s, 60)
	return "%d:%02d" % [m, rs]

onready var difficulty_btns: Array = [
	$RS / H1 / ButtonDisp / NODIF, 
	$RS / H1 / ButtonDisp / EASY, 
	$RS / H1 / ButtonDisp / MEDIUM, 
	$RS / H1 / ButtonDisp / HARD, 
	$RS / H1 / ButtonDisp / LOGIC, 
	$RS / H1 / ButtonDisp / TASUKETE
]

func update(_s = null):
	if not Rhythia.selected_song: return
	$RS.visible = true
	var map: Song = Rhythia.selected_song

	$RS.visible = (map.id != "!DELETED")
	$RS / H2 / EndInfo.visible = true
	$RS / H1 / Info / Control / Actions.visible = true

	$RS / H1 / Info / Id / Id.text = map.id
	$RS / H1 / Info / Name / Name.text = map.name
	$RS / H1 / Info / SongName / SongName.text = map.song

	$RS / H1 / Info / Mapper / Mapper.text = map.creator
	$RS / HMid / Difficulty.text = map.custom_data.get("difficulty_name", 
		Globals.difficulty_names.get(map.difficulty, "INVALID DIFFICULTY ID")
	)
	$RS / HMid / Difficulty.modulate = Globals.difficulty_colors.get(map.difficulty, Color("#ffffff"))
	$RS / H1 / Info / Data / Data.text = "%s - %s notes" % [get_time_ms(map.last_ms), comma_sep(map.note_count)]
	
	$RS / HMid / Difficulty.visible = true
	
	$RS / H1 / Info / Mapper.visible = not Rhythia.single_map_mode_txt
	$RS / H1 / Info / Id.visible = not Rhythia.single_map_mode_txt
	$RS / H1 / Info / SMM.visible = Rhythia.single_map_mode

	

	var txt = ""
	if Rhythia.note_hitbox_size == 1.14: txt += tr("Default hitboxes, ")
	else: txt += tr("Hitboxes: %s, ") % Rhythia.note_hitbox_size
	if Rhythia.hitwindow_ms == 55: txt += tr("default hitwindow")
	else: txt += tr("hitwindow: %s ms") % Rhythia.hitwindow_ms
	$RS / HMid / Hitboxes.text = txt

	if map.creator == "DyamoDash":
		$RS / H1 / Info / Mapper / Mapper.text = map.creator + " ♡"
		$RS / HMid / Hitboxes.text = txt + "\nHave you seen the Dyamo easter egg?\nHold D Y A when starting the game!"

	
	for i in range(difficulty_btns.size()):
		var n: Panel = difficulty_btns[i]
		n.visible = (map.difficulty == i - 1)
		n.get_node("F").visible = Rhythia.is_favorite(map.id)
		if map.has_cover:
			n.get_node("Name").visible = false
			n.get_node("Cover").visible = true
			n.get_node("Cover").texture = map.cover
		else:
			n.get_node("Cover").visible = false
			n.get_node("Name").visible = true
			n.get_node("Name").text = map.name
	
	if map.warning != "":
		$RS / H1 / Info / Warning.visible = true
		$RS / H1 / Info / Warning.text = map.warning
		if map.is_broken:
			$RS / H1 / Info / Warning.set("custom_colors/font_color", Color(1, 0, 0))



		else:
			$RS / H1 / Info / Warning / Warning.set("custom_colors/font_color", Color(1, 1, 0))



	else: $RS / H1 / Info / Warning.visible = false
	$RS / H1 / Info / Run.disabled = false
	$RS / H1 / Info / Control / Actions.disabled = false
	$RS / H1 / Info / Control / PreviewMusic.disabled = false
	upd_watch_btn()
	
	$Actions / Convert.disabled = (
		$Actions / Convert.debounce or 
		Rhythia.selected_song.is_broken or 
		Rhythia.selected_song.is_builtin or 
		Rhythia.selected_song.converted or 
		Rhythia.selected_song.songType == Globals.MAP_SSPM2 or 
		Rhythia.selected_song.is_online
	)
	
	$Actions / Convert.visible = (
		not Rhythia.selected_song.is_builtin and 
		not Rhythia.selected_song.is_online and 
		Rhythia.selected_song.songType != Globals.MAP_SSPM2
	)
	
	$Actions / Difficulty.visible = (
		not Rhythia.selected_song.is_builtin and 
		not Rhythia.selected_song.is_online and (
			Rhythia.selected_song.songType == Globals.MAP_SSPM or 
			Rhythia.selected_song.songType == Globals.MAP_SSPM2
		)
	)
	
	if Rhythia.selected_song.songType == Globals.MAP_SSPM:
		$Actions / Convert.text = "Upgrade map to SSPM v2"
	else:
		$Actions / Convert.text = "Convert map to .sspm"
	
	
	if is_inside_tree():
		yield(get_tree(), "idle_frame")
		yield(get_tree(), "idle_frame")







func return_to_song_select():
	get_viewport().get_node("Menu/Sidebar").press(0, false)

# --- Zikozythia: autoplay + (mod-specific) replay buttons ---
var autoplay_btn: Button
var replay_btn: Button
var watch_replay_path: String = ""
var watch_replay_is_best: bool = false
var watch_started: bool = false

# A replay file is only usable if it was properly finalized:
# end_recording() writes Globals.RS_END as the very last byte of the file.
# Abandoned runs (quit via leave/restart) leave partial files we must skip.
func is_valid_replay(path: String) -> bool:
	var f: File = File.new()
	if f.open(path, File.READ) != OK: return false
	var ok: bool = f.get_len() >= 120
	if ok:
		f.seek(f.get_len() - 1)
		ok = f.get_8() == Globals.RS_END
	f.close()
	return ok

# The modifier string stored inside a replay file's header
func read_replay_mods(path: String) -> String:
	var f: File = File.new()
	if f.open(path, File.READ) != OK: return ""
	if f.get_buffer(4) != PoolByteArray([83, 115, 42, 82]):
		f.close()
		return ""
	var sv: int = f.get_16()
	f.get_64()
	if sv >= 4: f.get_line()
	f.get_line()  # replay id
	var state: String = f.get_line()
	f.close()
	return state

# Mod comparison key - drops per-run details (start offset, muted music)
# so only the actual modifiers (speed, mods, hitwindow, hitbox, ar) count.
func mods_key(state: String) -> String:
	var pts: Array = state.split(";", false)
	var res: String = ""
	var first: bool = true
	for p in pts:
		if p.begins_with("so:") or p == "silent": continue
		if not first: res += ";"
		res += p
		first = false
	return res

# Finds the replay to watch for this map, for the CURRENTLY equipped mods:
# 1) The replay linked to this map's personal best for the current mods
# 2) Otherwise the newest valid recording made with the same mods
func find_best_replay() -> String:
	if not Rhythia.selected_song: return ""
	var map: Song = Rhythia.selected_song
	if map.id == "!DELETED": return ""
	
	var cur_key: String = mods_key(Rhythia.generate_pb_str(true))
	
	var pb: Dictionary = map.get_pb(Rhythia.generate_pb_str(true))
	if pb.has("replay_id") and pb.replay_id != "":
		var p: String = Globals.p("user://replays/%s.sspre" % pb.replay_id)
		if is_valid_replay(p):
			watch_replay_is_best = true
			return p
	
	watch_replay_is_best = false
	var d: Directory = Directory.new()
	var rp: String = Globals.p("user://replays/")
	if d.dir_exists(rp) and d.open(rp) == OK:
		var newest: String = ""
		var newest_t: int = 0
		d.list_dir_begin(true)
		var fname: String = d.get_next()
		while fname != "":
			if (
				not d.current_is_dir() and 
				fname.get_extension() == "sspre" and 
				fname.begins_with(map.id + ".")
			):
				var full: String = rp + fname
				if mods_key(read_replay_mods(full)) == cur_key:
					var t: int = d.get_modified_time(full)
					if t > newest_t and is_valid_replay(full):
						newest_t = t
						newest = fname
			fname = d.get_next()
		d.list_dir_end()
		if newest != "": return rp + newest
	return ""

func upd_watch_btn():
	if autoplay_btn == null or replay_btn == null: return
	watch_replay_path = find_best_replay()
	replay_btn.visible = (watch_replay_path != "")
	if watch_replay_path != "":
		if watch_replay_is_best:
			replay_btn.text = "Watch Best Replay"
			replay_btn.hint_tooltip = "Watch a replay of your best play on this map\nrecorded with your currently equipped modifiers\n(Change settings with Esc while watching)"
		else:
			replay_btn.text = "Watch Replay"
			replay_btn.hint_tooltip = "Watch a replay of this map recorded with your\ncurrently equipped modifiers\n(Change settings with Esc while watching)"
	autoplay_btn.hint_tooltip = "A bot will play this map to showcase it\n(Change settings with Esc while watching)"

func start_watch(path: String):
	if watch_started or not Rhythia.selected_song: return
	watch_started = true
	Rhythia.replay = Replay.new()
	Rhythia.replaying = true
	# An empty replay path makes the replay load as an autoplayer showcase
	Rhythia.replay_path = path
	get_viewport().get_node("Menu").black_fade_target = true
	yield(get_tree().create_timer(0.35), "timeout")
	get_tree().change_scene("res://scenes/loaders/songload.tscn")

func start_autoplay_watch():
	start_watch("")

func start_replay_watch():
	start_watch(watch_replay_path)

var _watch_refresh_t: float = 1.0
func _process(delta):
	# keep the buttons fresh - new replays can appear after every play
	_watch_refresh_t += delta
	if _watch_refresh_t >= 1.0:
		_watch_refresh_t = 0.0
		if autoplay_btn and visible and Rhythia.selected_song:
			upd_watch_btn()

func _make_watch_btns():
	var info: Control = $RS / H1 / Info
	var run: Button = info.get_node("Run")
	
	# half-width side-by-side row below the Start button
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "WatchRow"
	row.add_constant_override("separation", 8)
	row.size_flags_horizontal = Button.SIZE_FILL | Button.SIZE_EXPAND
	info.add_child(row)
	info.move_child(row, run.get_index() + 1)
	
	replay_btn = run.duplicate()
	replay_btn.name = "WatchReplay"
	replay_btn.script = null
	replay_btn.toggle_mode = false
	replay_btn.hint_tooltip = ""
	replay_btn.text = "Watch Replay"
	replay_btn.size_flags_horizontal = Button.SIZE_FILL | Button.SIZE_EXPAND
	row.add_child(replay_btn)
	
	autoplay_btn = run.duplicate()
	autoplay_btn.name = "WatchAutoplay"
	autoplay_btn.script = null
	autoplay_btn.toggle_mode = false
	autoplay_btn.hint_tooltip = ""
	autoplay_btn.text = "Watch Autoplay"
	autoplay_btn.size_flags_horizontal = Button.SIZE_FILL | Button.SIZE_EXPAND
	row.add_child(autoplay_btn)
	
	replay_btn.connect("pressed", self, "start_replay_watch")
	autoplay_btn.connect("pressed", self, "start_autoplay_watch")
	
	# compact replays menu to the right of the song title
	var title_row: Control = info.get_node("Name")
	replays_btn = run.duplicate()
	replays_btn.name = "ReplaysMenu"
	replays_btn.script = null
	replays_btn.toggle_mode = false
	replays_btn.hint_tooltip = "Preview your top 5 plays on this map"
	replays_btn.text = "Replays ▾"
	replays_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(replays_btn)
	replays_btn.connect("pressed", self, "_toggle_replays_box")

# --- Zikozythia: replays dropdown (top 5 plays preview) ---
var replays_btn: Button = null
var replays_box: PanelContainer = null
var replays_box_list: VBoxContainer = null

func _compact_mods(state: String) -> String:
	var pts: Array = state.split(";", false)
	var out: Array = []
	for p in pts:
		if p.begins_with("so:") or p == "silent" or p == "ar:1": continue
		elif p.begins_with("s:c"): out.append("%.2fx" % float(p.substr(3)))
		elif p == "s:---": out.append("%.2fx" % Globals.speed_multi[Globals.SPEED_MMM])
		elif p == "s:--": out.append("%.2fx" % Globals.speed_multi[Globals.SPEED_MM])
		elif p == "s:-": out.append("%.2fx" % Globals.speed_multi[Globals.SPEED_M])
		elif p == "s:=": pass
		elif p == "s:+": out.append("%.2fx" % Globals.speed_multi[Globals.SPEED_P])
		elif p == "s:++": out.append("%.2fx" % Globals.speed_multi[Globals.SPEED_PP])
		elif p == "s:+++": out.append("%.2fx" % Globals.speed_multi[Globals.SPEED_PPP])
		elif p == "s:++++": out.append("%.2fx" % Globals.speed_multi[Globals.SPEED_PPPP])
		elif p == "hp_old": out.append("OldHP")
		elif p.begins_with("hitw:"):
			if int(float(p.substr(5))) != 55: out.append("HW %d" % int(float(p.substr(5))))
		elif p.begins_with("hbox:"):
			if abs(float(p.substr(5)) - 1.14) > 0.001: out.append("HB %.2f" % float(p.substr(5)))
		elif p == "ar:-1": out.append("RevAR")
		elif p == "ar:0": out.append("AR 0")
		elif p == "m_sd": out.append("Sudden Death")
		elif p == "m_morehp": out.append("Energy+")
		elif p == "m_noregen": out.append("NoRegen")
		elif p == "m_mirror_x": out.append("MirrorX")
		elif p == "m_mirror_y": out.append("MirrorY")
		elif p == "m_nsight": out.append("Nearsight")
		elif p == "m_ghost": out.append("Ghost")
		elif p == "m_chaos": out.append("Chaos")
		elif p == "m_im": out.append("Inverted")
		elif p == "m_earthquake": out.append("Earthquake")
		elif p == "m_flashlight": out.append("Flashlight")
		elif p == "m_hardrock": out.append("Hard Rock")
		elif p == "m_nofail": out.append("NoFail")
	if out.empty(): return "No mods"
	var res: String = ""
	for i in range(out.size()):
		if i != 0: res += ", "
		res += out[i]
	return res

# counts hits / misses / give-ups from a replay's signal stream
func parse_replay_info(path: String) -> Dictionary:
	var info: Dictionary = {"ok": false, "mods": "", "hits": 0, "misses": 0, "gaveup": false}
	var f: File = File.new()
	if f.open(path, File.READ) != OK: return info
	if f.get_buffer(4) != PoolByteArray([83, 115, 42, 82]):
		f.close()
		return info
	var sv: int = f.get_16()
	f.get_64()
	if sv >= 4: f.get_line()
	f.get_line()
	info.mods = _compact_mods(f.get_line())
	if sv >= 3:
		for _s in range(7): f.get_float()
		f.get_8()
		f.get_float()
	f.get_8()
	f.get_32()
	f.get_32()
	var kind: int = f.get_8()
	while kind != 5 and not f.eof_reached():
		if kind == 1: info.hits += 1
		elif kind == 2: info.misses += 1
		elif kind == 4: info.gaveup = true
		if kind == 0:
			f.get_32()
			f.get_float()
			f.get_float()
		else:
			f.get_32()
		kind = f.get_8()
	f.close()
	info.ok = true
	return info

func _toggle_replays_box():
	if Rhythia.selected_song == null: return
	if replays_box != null and replays_box.visible:
		replays_box.visible = false
		return
	if replays_box == null: _build_replays_box()
	_fill_replays_box()
	# drop the box right below the Replays menu button
	var r: Rect2 = replays_btn.get_global_rect()
	replays_box.rect_position = r.position + Vector2(0, r.size.y + 6)
	replays_box.visible = true

func _build_replays_box():
	replays_box = PanelContainer.new()
	replays_box.theme = load("res://uitheme.tres")
	replays_box.custom_minimum_size = Vector2(460, 190)
	replays_box.mouse_filter = Control.MOUSE_FILTER_STOP
	var sc: ScrollContainer = ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_FILL
	replays_box.add_child(sc)
	replays_box_list = VBoxContainer.new()
	replays_box_list.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_FILL
	sc.add_child(replays_box_list)
	# parent to the menu root so the box floats over the panel content
	get_viewport().get_node("Menu").add_child(replays_box)
	replays_box.visible = false

# top 5: passed runs first, then highest accuracy, then newest
func _replay_rank_sort(a: Array, b: Array) -> bool:
	if a[0] != b[0]: return a[0] > b[0]
	if a[1] != b[1]: return a[1] > b[1]
	return a[2] > b[2]

func _fill_replays_box():
	for c in replays_box_list.get_children():
		replays_box_list.remove_child(c)
		c.queue_free()
	if Rhythia.selected_song == null: return
	var map: Song = Rhythia.selected_song
	var files: Array = []
	var d: Directory = Directory.new()
	var rp: String = Globals.p("user://replays/")
	if d.dir_exists(rp) and d.open(rp) == OK:
		d.list_dir_begin(true)
		var fname: String = d.get_next()
		while fname != "":
			if not d.current_is_dir() and fname.get_extension() == "sspre" and fname.begins_with(map.id + "."):
				var full: String = rp + fname
				var info: Dictionary = parse_replay_info(full)
				if not info.ok:
					fname = d.get_next()
					continue
				var total: int = info.hits + info.misses
				var acc: float = 0.0
				if total > 0: acc = float(info.hits) / float(total)
				files.append([1 if (map.note_count > 0 and info.hits + info.misses >= map.note_count) else 0, acc, d.get_modified_time(full), fname, full, info])
			fname = d.get_next()
		d.list_dir_end()
	files.sort_custom(self, "_replay_rank_sort")
	
	var shown: int = 0
	for fr in files:
		if shown >= 5: break
		shown += 1
		var fname: String = fr[3]
		var full: String = fr[4]
		var info: Dictionary = fr[5]
		var stamp: String = fname.substr(map.id.length() + 1).replace(".sspre", "").replace("_", "  ")
		var total: int = info.hits + info.misses
		var acc: float = float(fr[1])
		var status: String = "failed"
		if info.gaveup: status = "gave up"
		if fr[0] == 1: status = "passed"
		var star: String = ""
		if not map.pbs_loaded: map.load_pbs()
		var rid: String = fname.substr(0, fname.length() - 6)
		for k in map.pb_data:
			if map.pb_data[k].has("replay_id") and map.pb_data[k].replay_id == rid:
				star = "  ★"
				break
		var row: Button = Button.new()
		row.text = "%s   |   %s   |   %.1f%%  (%s/%s)   |   %s%s" % [stamp, info.mods, acc * 100.0, comma_sep(info.hits), comma_sep(total), status, star]
		row.custom_minimum_size = Vector2(0, 30)
		row.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_FILL
		row.connect("pressed", self, "_watch_from_box", [full])
		replays_box_list.add_child(row)
	if shown == 0:
		var empty: Label = Label.new()
		empty.text = "No replays recorded for this map yet."
		replays_box_list.add_child(empty)

func _watch_from_box(path: String):
	if replays_box != null: replays_box.visible = false
	start_watch(path)
# -----------------------------------------------------------


func _ready():
	_make_watch_btns()
	Rhythia.connect("selected_song_changed", self, "update")
	Rhythia.connect("mods_changed", self, "update")
	Rhythia.connect("favorite_songs_changed", self, "update")

	if Rhythia.selected_song: update()
	else:
		$RS.visible = false
		$RS / H2 / EndInfo.visible = false
		$RS / H1 / Info / Run.disabled = true
		$RS / H1 / Info / Control / Actions.disabled = true
		$RS / H1 / Info / Control / PreviewMusic.disabled = true
