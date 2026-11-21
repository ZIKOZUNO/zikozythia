extends Spatial
class_name SongPlayerManager

signal hit
signal miss

var rawMapData: String
var notes: Array
var last_ms: float = 0
onready var colors: Array = Rhythia.selected_colorset.colors
onready var speed_multi = Globals.speed_multi[Rhythia.mod_speed_level]

var score: int = 0
var combo: int = 0
var combo_level: int = 1
var lvl_progress: int = 0
var song_has_failed: bool = false

export (StyleBox) var timer_fg_done

func comma_sep(number):
	var string = str(number)
	var mod = string.length() % 3
	var res = ""
	
	for i in range(0, string.length()):
		if i != 0 and i % 3 == mod:
			res += ","
		res += string[i]
	
	return res

func loadMapFile():
	var map: Song = Rhythia.selected_song
	last_ms = map.last_ms

	if map.should_reload_on_play:
		map.setup_from_file(map.initFile, map.musicFile)
	notes = map.read_notes()
	var file: File = File.new()
	var song: AudioStream = map.stream()
	
	
	
	$Spawn.spawn_notes(notes)
	
	get_node("Spawn/Music").stream = song

onready var head: Spatial = get_node("Avatar/Head")

var hits: float = 0
var misses: float = 0
var total_notes: float = 0
var energy: float = 6
var max_energy: float = 6
var energy_per_hit: float = 1
var max_combo: int = 0

func update_hud():
	$HUD.update_static_values()

var ending: bool = false
func end(end_type: int):
	if ending: return
	print("My god, what are you doing!?")
	ending = true
	if end_type == Globals.END_GIVEUP and Rhythia.record_replays and not Rhythia.replaying:
		Rhythia.replay.store_sig($Spawn.rms, Globals.RS_GIVEUP)
	if end_type != Globals.END_PASS:
		Rhythia.fail_asp.play()
	get_tree().paused = true
	if total_notes == 0: total_notes = 1
	update_hud()
	Rhythia.just_ended_song = true
	Rhythia.song_end_hits = hits
	Rhythia.song_end_misses = misses
	Rhythia.song_end_total_notes = total_notes
	Rhythia.song_end_position = min($Spawn.ms, last_ms)
	Rhythia.song_end_length = last_ms
	Rhythia.song_end_type = end_type
	Rhythia.song_end_combo = max_combo
	print("song max combo: ", max_combo)
	
	if Rhythia.record_replays and not Rhythia.replaying:
		Rhythia.replay.end_recording()
	
	if Rhythia.queue_active and end_type == Globals.END_PASS:
		if Rhythia.do_pb_check_and_set():
			Globals.notify(Globals.NOTIFY_SUCCEED, "new best!")
		var next = Rhythia.get_next()
		$Spawn.ms_offset += max($Spawn.ms - (Rhythia.start_offset - (3000 * $Spawn.speed_multi)), 0)
		if Rhythia.queue_active and next:
			$Spawn.ms = Rhythia.start_offset - (3000 * $Spawn.speed_multi)
			Rhythia.select_song(next)
			$HUD.set_song_name(Rhythia.selected_song.name)
			Rhythia.update_rpc_song()
			if Rhythia.record_replays and not Rhythia.replaying:
				Rhythia.replay = Replay.new()
				Rhythia.replay.start_recording(Rhythia.selected_song)
			
			$Spawn.notes_loaded = false
			$Spawn.chaos_rng = RandomNumberGenerator.new()
			$Spawn.earthquake_rng = RandomNumberGenerator.new()
			$Spawn.chaos_rng.seed = hash(Rhythia.selected_song.id)
			$Spawn.earthquake_rng.seed = hash(Rhythia.selected_song.id)
			$Spawn.music_started = false
			$Spawn.out_of_notes = false
			$Spawn.note_count = 0
			
			$Spawn.prev_ms = (Rhythia.start_offset - (3000 * $Spawn.speed_multi))
			$Spawn.next_ms = 0
			get_tree().paused = false
			$Spawn.emit_signal("ms_change", $Spawn.ms)
			loadMapFile()
			ending = false
			return
	elif Rhythia.restart_on_death and end_type == Globals.END_FAIL and not Rhythia.replaying:
		if Rhythia.do_pb_check_and_set():
			print("Logging PB, restarting death")
		"""
		Change this func and one in EndInfo.gd to display PB when giving up with restart_on_death (since its the only escape outside of passing)
		It saves the PB yet it shows you failed until you reload the song in the menu
		My poor brain is fuming with this code lmao

		- helmeto
		"""
		
		get_tree().change_scene("res://scenes/song.tscn")
	else:
		black_fade_target = true
		yield(get_tree().create_timer(0.35), "timeout")
		get_tree().change_scene("res://scenes/loaders/menuload.tscn")

func update_timer(ms: float, canSkip: bool = false):
	var qms = ms + $Spawn.ms_offset
	var lms = last_ms
	
	if Rhythia.queue_active:
		lms = Rhythia.queue_end_length + (3000 * (Rhythia.song_queue.size() - 1))
	
	var s = clamp(floor(qms / 1000), 0, lms / 1000)
	var m = floor(s / 60)
	var rs = fmod(s, 60)
	
	var ls = floor(lms / 1000)
	var lm = floor(ls / 60)
	var lrs = fmod(ls, 60)
	
	$HUD.update_timer(ms, canSkip)
	
	if Rhythia.queue_active:
		if ms >= last_ms + $Spawn.hit_window:
			get_node("Spawn/Music").volume_db -= (17 * get_process_delta_time())
		else:
			get_node("Spawn/Music").volume_db = Rhythia.music_volume_db
	
	if ms >= last_ms + $Spawn.hit_window:
		if Rhythia.queue_active and ms >= last_ms + max($Spawn.hit_window, 3000):
			get_node("Spawn/Music").stop()
			end(Globals.END_PASS)
		elif not Rhythia.queue_active and not get_node("Spawn/Music").playing:
			end(Globals.END_PASS)



var loaded = false

var giving_up: float = 0

# Zikozythia: keybind just-pressed tracking
var _rk_prev: bool = false
var _lk_prev: bool = false
var black_fade_target: bool = true
var black_fade: float = 1
var passed: bool = false

func _process(delta):
	
	if not Rhythia.queue_active and $Spawn.ms > last_ms:
		passed = true
			
		head.get_node("EyeL").visible = false
		head.get_node("HappyL").visible = true
			
		head.get_node("EyeR").visible = false
		head.get_node("HappyR").visible = true
		
	if passed:
		$Avatar / ArmR.translation.y += (1 - $Avatar / ArmR.translation.y) * 0.01
	
	if not ending and not Rhythia.ui_edit_mode:
		if Input.is_action_pressed("give_up"):
			giving_up += delta / 0.6
			if giving_up >= 1:
				if not Rhythia.queue_active and $Spawn.ms > last_ms: end(Globals.END_PASS)
				else: end(Globals.END_GIVEUP)
		else:
			giving_up = 0

	# Zikozythia: custom restart / leave keybinds (changeable in settings)
	var rk: bool = Input.is_key_pressed(Rhythia.restart_key)
	var lk: bool = Input.is_key_pressed(Rhythia.leave_key)
	if not ending and not get_tree().paused and not Rhythia.vr and not Rhythia.ui_edit_mode:
		if rk and not _rk_prev:
			_rk_prev = rk
			_lk_prev = lk
			# finalize the replay of the abandoned run so it stays watchable
			if Rhythia.record_replays and not Rhythia.replaying and Rhythia.replay != null and Rhythia.replay.recording:
				Rhythia.replay.end_recording()
			get_tree().reload_current_scene()
			return
		elif lk and not _lk_prev:
			_rk_prev = rk
			_lk_prev = lk
			if Rhythia.record_replays and not Rhythia.replaying and Rhythia.replay != null and Rhythia.replay.recording:
				Rhythia.replay.end_recording()
			ending = true
			black_fade_target = true
			yield(get_tree().create_timer(0.35), "timeout")
			get_tree().change_scene("res://scenes/loaders/menuload.tscn")
			return
	_rk_prev = rk
	_lk_prev = lk
	
	if Rhythia.replaying and Input.is_action_just_pressed("pause"):
		get_tree().paused = not get_tree().paused
	
	# Zikozythia: replay settings panel (shown while the replay is paused)
	if replay_panel:
		var show_panel: bool = Rhythia.replaying and get_tree().paused and not ending and not Rhythia.ui_edit_mode
		if replay_panel.visible != show_panel:
			replay_panel.visible = show_panel
			if not ending:
				if show_panel: Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
				else: Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	
	if get_tree().paused:
		$Spawn.last_usec = OS.get_ticks_usec()
	
	
	if black_fade_target and black_fade != 1:
		black_fade = min(black_fade + (delta / 0.3), 1)
		$BlackFade.color = Color(0, 0, 0, black_fade)
	elif not black_fade_target and black_fade != 0:
		black_fade = max(black_fade - (delta / 0.75), 0)
		$BlackFade.color = Color(0, 0, 0, black_fade)
	$BlackFade.visible = (black_fade != 0)
	

func linstep(a: float, b: float, x: float):
	if a == b: return float(x >= a)
	return clamp(abs((x - a) / (b - a)), 0, 1)

func get_point_amt() -> int:
	var spd = clamp(((speed_multi - 1) * 1.5) + 1, 0, 1.9)
	
	var hitbox_diff = Rhythia.note_hitbox_size - 1.14
	var hbo = clamp(linstep(1.14, 0, hitbox_diff), 0, 1)
	
	var hitwin_diff = Rhythia.note_hitbox_size - 55
	var hwi = clamp(linstep(55, 0, hitwin_diff), 0, 1)
	
	var mod = 1
	
	return int(floor((50 * spd * min(hbo, hwi) * mod) + 0.5) * combo_level)


func hit(col):
	emit_signal("hit", col)
	hits += 1
	total_notes += 1
	if not Rhythia.mod_no_regen: energy = clamp(energy + energy_per_hit, 0, max_energy)
	combo += 1

	if combo > max_combo: max_combo = combo

	var points = get_point_amt()
	if combo_level != 8:
		lvl_progress += 1
	if combo_level != 8 and lvl_progress == 10:
		lvl_progress = 0
		combo_level += 1
		if combo_level == 8: lvl_progress = 10
	update_hud()
	
	if Rhythia.hit_fov:
		if Rhythia.hit_fov_additive:
			$"../Camera".fov += Rhythia.hit_fov_amplifier
		elif Rhythia.hit_fov_exponential:
			$"../Camera".fov *= Rhythia.hit_fov_amplifier
		else:
			$"../Camera".fov = Rhythia.get("fov") - Rhythia.hit_fov_amplifier
	
	score += points
	return points

func miss(col):
	emit_signal("miss", col)
	misses += 1
	total_notes += 1
	energy = clamp(energy - 1, 0, max_energy)
	combo = 0
	lvl_progress = 0
	if combo_level != 1: combo_level -= 1
	update_hud()
	if energy == 0:
		if Rhythia.mod_nofail:
			if not song_has_failed:
				song_has_failed = true
				Rhythia.fail_asp.play()
		else:
			end(Globals.END_FAIL)


func _ready():
	Rhythia.song_end_pause_count = 0
	Rhythia.song_end_misses = 0
	get_tree().paused = true
	get_node("Spawn/Music").volume_db = Rhythia.music_volume_db
	if Rhythia.replaying: _build_replay_panel()
	if Rhythia.mod_sudden_death:
		max_energy = 1
	elif Rhythia.health_model == Globals.HP_OLD:
		energy_per_hit = 1
		if Rhythia.mod_extra_energy: max_energy = 10
		else: max_energy = 6
	elif Rhythia.health_model == Globals.HP_SOUNDSPACE:
		energy_per_hit = 0.5
		if Rhythia.mod_extra_energy: max_energy = 8
		else: max_energy = 5
	
	energy = max_energy

	var spinst = Rhythia.loaded_world.instance()
	get_parent().call_deferred("add_child", spinst)
	spinst.name = "Space"

	$BlackFade.visible = true
	$BlackFade.color = Color(0, 0, 0, black_fade)
	get_tree().paused = false
	$Spawn.connect("timer_update", self, "update_timer")

	$Spawn.connect("miss", self, "miss")
	loadMapFile()
	
	
	Rhythia.update_rpc_song()
	
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	black_fade_target = false
	$ForceMatLoad.visible = false
	$Spawn.active = true


# --- Zikozythia: replay settings panel ---
# While watching a replay, pressing Esc pauses it and opens this panel.
# Values are written into Rhythia.replay.settings, which the game reads
# live (Rhythia.fov / spawn_distance / parallax / ... use them when replaying).
var replay_panel: Control

func _replay_set(key: String, value):
	if not Rhythia.replaying or not Rhythia.replay: return
	Rhythia.replay.settings[key] = value
	# approach rate and spawn/fade settings are cached in the note manager
	if key == "approach_rate":
		$Spawn.approach_rate = value
		_replay_apply_fades()
	elif key == "spawn_distance" or key == "fade_length":
		_replay_apply_fades()

func _replay_apply_fades():
	var s: Spatial = $Spawn
	if Rhythia.mod_ghost:
		s.fade_out_enabled = true
		s.fade_out_start = ((18.0 / 50) * s.approach_rate)
		s.fade_out_end = ((6.0 / 50) * s.approach_rate)
	elif Rhythia.half_ghost:
		s.fade_out_enabled = true
		s.fade_out_start = ((12.0 / 50.0) * s.approach_rate)
		s.fade_out_end = ((3.0 / 50.0) * s.approach_rate)
		s.fade_out_base = 0.8
	if Rhythia.mod_nearsighted:
		s.fade_in_enabled = true
		s.fade_in_start = ((30.0 / 50.0) * s.approach_rate)
		s.fade_in_end = ((5.0 / 50.0) * s.approach_rate)
	else:
		s.fade_in_enabled = Rhythia.get("fade_length") != 0
		if s.fade_in_enabled:
			s.fade_in_start = Rhythia.get("spawn_distance")
			s.fade_in_end = Rhythia.get("spawn_distance") * (1.0 - Rhythia.get("fade_length"))

func _replay_spin_changed(key: String, sb: SpinBox):
	var v: float = sb.value
	if key == "fade_length": v = v / 100
	_replay_set(key, v)

func _replay_cam_unlock(cb: CheckBox):
	_replay_set("cam_unlock", cb.pressed)

func _build_replay_panel():
	replay_panel = PanelContainer.new()
	replay_panel.name = "ReplaySettings"
	replay_panel.pause_mode = Node.PAUSE_MODE_PROCESS
	replay_panel.theme = load("res://uitheme.tres")
	replay_panel.anchor_left = 1.0
	replay_panel.anchor_right = 1.0
	replay_panel.margin_left = -380.0
	replay_panel.margin_right = -15.0
	replay_panel.margin_top = 15.0
	replay_panel.margin_bottom = 15.0
	replay_panel.grow_horizontal = 0
	replay_panel.grow_vertical = 1
	replay_panel.visible = false
	add_child(replay_panel)
	
	var margin: MarginContainer = MarginContainer.new()
	margin.set("custom_constants/margin_left", 12)
	margin.set("custom_constants/margin_right", 12)
	margin.set("custom_constants/margin_top", 12)
	margin.set("custom_constants/margin_bottom", 12)
	replay_panel.add_child(margin)
	
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_constant_override("separation", 8)
	margin.add_child(vbox)
	
	var title: Label = Label.new()
	title.text = "Replay Settings (Esc)"
	vbox.add_child(title)
	
	# [label, setting key, min, max, step]
	var specs: Array = [
		["Approach Rate", "approach_rate", -500.0, 500.0, 0.1], 
		["Spawn Distance", "spawn_distance", 2.0, 1000.0, 0.01], 
		["Fade Length (%)", "fade_length", 0.0, 100.0, 0.01], 
		["Parallax", "parallax", 0.0, 50.0, 0.01], 
		["UI Parallax", "ui_parallax", 0.0, 50.0, 0.01], 
		["Grid Parallax", "grid_parallax", 0.0, 50.0, 0.01], 
		["FOV", "fov", 30.0, 150.0, 0.01], 
		["Cursor Drift", "edge_drift", 0.0, 1.0, 0.01]
	]
	for spec in specs:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_constant_override("separation", 10)
		vbox.add_child(row)
		
		var lbl: Label = Label.new()
		lbl.text = spec[0]
		lbl.rect_min_size = Vector2(140, 0)
		lbl.valign = Label.VALIGN_CENTER
		row.add_child(lbl)
		
		var sb: SpinBox = SpinBox.new()
		sb.min_value = spec[2]
		sb.max_value = spec[3]
		sb.step = spec[4]
		sb.rect_min_size = Vector2(180, 32)
		var key: String = spec[1]
		var cur: float = Rhythia.replay.settings.get(key, Rhythia.get(key))
		if key == "fade_length": sb.value = cur * 100
		else: sb.value = cur
		sb.connect("changed", self, "_replay_spin_changed", [key, sb])
		sb.size_flags_horizontal = 3
		row.add_child(sb)
	
	var cb: CheckBox = CheckBox.new()
	cb.text = "Unlock Camera"
	cb.pressed = bool(Rhythia.replay.settings.get("cam_unlock", Rhythia.get("cam_unlock")))
	cb.connect("pressed", self, "_replay_cam_unlock", [cb])
	vbox.add_child(cb)
	
	var hint: Label = Label.new()
	hint.text = "Changes apply live. Notes that already spawned\nkeep their position. Esc resumes the replay."
	hint.set("custom_colors/font_color", Color(1, 1, 1, 0.6))
	vbox.add_child(hint)
# ------------------------------------------

