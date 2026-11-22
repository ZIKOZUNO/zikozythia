extends SceneTree

# Zikozythia self-check (headless):
#   Zikozythia.exe -s res://test_selfcheck.gd --no-window
# 1) compile-checks every touched script (with real reparse)
# 2) builds the movement profile from real replays
# 3) runs the humanized autoplay against a realistic synthetic map and
#    verifies the cursor actually lands on notes

func _initialize():
	var out: String = ""
	var scripts = [
		"res://scripts/cursordance/MoveProfile.gd", 
		"res://scripts/cursordance/Humanized.gd", 
		"res://scripts/content/game/Replay.gd", 
		"res://scripts/game/HUD.gd", 
		"res://scripts/game/Game.gd", 
		"res://scripts/game/BloomRig.gd", 
		"res://scripts/Rhythia.gd", 
		"res://scripts/ui/menu/SongInfoScreen.gd", 
		"res://scripts/ui/menu/buttons/EndInfo.gd", 
		"res://scripts/loaders/songload.gd", 
		"res://scripts/loaders/menuload.gd", 
		"res://scripts/init.gd", 
		"res://scripts/ui/menu/buttons/v3MapList.gd"
	]
	for s in scripts:
		var res = load(s)
		if res == null or not (res is Script):
			out += "FAIL load: %s\n" % s
			continue
		if s != "res://scripts/Rhythia.gd":
			# autoloads have live instances - reload would refuse (not a parse error)
			var err = res.reload()
			if int(err) != 0:
				out += "FAIL parse (%s): %s\n" % [err, s]
				continue
		out += "ok: %s\n" % s
	
	# --- mock autoloads (the real ones are heavy/interactive) ---
	var globals_mock = GDScript.new()
	globals_mock.source_code = "extends Node\nconst MAP_TXT = 0\nconst MAP_RAW = 1\nconst MAP_SSPM = 3\nconst MAP_SSPM2 = 5\nconst SPEED_NORMAL = 0\nvar speed_multi = [1.0, 0.05, 0.2, 0.5, 1.0, 1.25, 1.5, 2.0, 2.5, 3.0]\n"
	globals_mock.reload()
	var g = globals_mock.new()
	g.name = "Globals"
	root.add_child(g)
	
	var rhythia_mock = GDScript.new()
	rhythia_mock.source_code = "extends Node\nvar mod_mirror_x = false\nvar mod_mirror_y = false\nvar mod_speed_level = 0\nvar single_map_mode = false\n"
	rhythia_mock.reload()
	var r = rhythia_mock.new()
	r.name = "Rhythia"
	root.add_child(r)
	
	# --- movement profile from real replays ---
	var MoveProfileLib = load("res://scripts/cursordance/MoveProfile.gd")
	var t0 = OS.get_ticks_usec()
	var p = MoveProfileLib.load_or_build(true)
	var t1 = OS.get_ticks_usec()
	out += "profile build: %.0f ms\n" % ((t1 - t0) / 1000.0)
	if p == null:
		out += "PROFILE IS NULL (no valid replays found?)\n"
	else:
		out += "bursts: %s from %s replays | v50=%.2f v90=%.2f\n" % [p.bursts.size(), p.replay_count, float(p.stats.v50), float(p.stats.v90)]
	
	# --- synthetic map: streams + jumps, like a real chart ---
	var raw = ","
	var ms = 2000.0
	var x = 1.0
	var y = 1.0
	var note_ms: Array = []
	var note_x: Array = []
	var note_y: Array = []
	for i in range(900):
		if i % 7 == 6:
			# jump
			x = 0.3 + float(randi() % 3) * 0.7
			y = 0.3 + float(randi() % 3) * 0.7
			ms += 320.0 + float(randi() % 300)
		else:
			# stream step
			x = clamp(x + (float(randi() % 2) * 2.0 - 1.0) * 0.45, 0.2, 1.8)
			y = clamp(y + (float(randi() % 2) * 2.0 - 1.0) * 0.45, 0.2, 1.8)
			ms += 145.0 + float(randi() % 40)
		note_ms.append(ms)
		note_x.append(x)
		note_y.append(y)
		raw += "%s|%s|%s," % [x, y, ms]
	
	var SongLib = load("res://scripts/content/game/Song.gd")
	var song = SongLib.new("testmap", "Test Map", "tester")
	song.loadRawData(raw)
	song.songType = 1  # MAP_RAW
	song.musicFile = "res://test"
	var notes: Array = song.read_notes()
	out += "map notes: %s\n" % notes.size()
	# NOTE: loadRawData inverts coordinates (x = 2 - x, y = 2 - y) - the
	# song's notes are the ground truth, not the generator arrays
	for i in range(notes.size()):
		note_x[i] = notes[i][0]
		note_y[i] = notes[i][1]
	
	# --- humanized autoplay ---
	var HumanizedLib = load("res://scripts/cursordance/Humanized.gd")
	var mover = HumanizedLib.new(song, p)
	
	var worst: float = 0.0
	var worst_at: String = ""
	var frame: float = -2900.0
	var last_frame: float = frame
	var had_nan: bool = false
	var sample: float = 0.0
	var sample_frames: int = 0
	var ni: int = 0
	var lag_sum: float = 0.0
	var lag_n: int = 0
	while frame < ms + 200.0:
		var pos: Vector2 = mover.update(frame)
		if is_nan(pos.x) or is_nan(pos.y) or is_inf(pos.x) or is_inf(pos.y):
			had_nan = true
		# note arrival: within 8ms of a note time, cursor must be on it
		while ni < note_ms.size() and frame > note_ms[ni] + 8.0:
			ni += 1
		if ni < note_ms.size() and abs(frame - note_ms[ni]) <= 8.0:
			var dd: float = pos.distance_to(Vector2(note_x[ni], note_y[ni]))
			if dd > worst:
				worst = dd
				worst_at = "note %d (t=%.0f) cursor=(%.2f, %.2f) note=(%.2f, %.2f) prev_note=(%.2f, %.2f @%.0f) gap_dt=%.0f" % [
					ni, frame, pos.x, pos.y, note_x[ni], note_y[ni], 
					note_x[ni - 1] if ni > 0 else 0.0, note_y[ni - 1] if ni > 0 else 0.0, 
					note_ms[ni - 1] if ni > 0 else 0.0, 
					note_ms[ni] - (note_ms[ni - 1] if ni > 0 else note_ms[ni])
				]
			lag_sum += dd
			lag_n += 1
			sample += pos.x
			sample_frames += 1
		last_frame = frame
		frame += 16.7
	out += "arrival: worst=%.4f over %s note-hits (under 0.15 = visually on note)%s\n" % [worst, lag_n, " | NaN DETECTED!" if had_nan else ""]
	out += "worst at: %s\n" % worst_at
	# trajectory dump around the worst note
	var wn: int = int(worst_at.split(" ")[1].trim_prefix("note"))
	out += "trajectory around note %d:\n" % wn
	var t_start: float = note_ms[wn] - 120.0
	var t_end: float = note_ms[wn] + 60.0
	var f2: float = t_start
	var wni: int = wn - 2
	if wni < 0: wni = 0
	while f2 <= t_end:
		var pos: Vector2 = mover.update(f2)
		while wni < note_ms.size() and note_ms[wni] < f2: wni += 1
		var near: String = "-"
		if wni < note_ms.size() and abs(f2 - note_ms[wni]) <= 8.0: near = "<<< note %d (%.2f, %.2f)" % [wni, note_x[wni], note_y[wni]]
		out += "  t=%.0f cursor=(%.2f, %.2f) %s\n" % [f2, pos.x, pos.y, near]
		f2 += 16.7
	out += "autoplay cursor x-range sample: %.3f (should vary)\n" % sample
	out += "%s\n" % ("FAIL: runtime NaN in path!" if had_nan else "runtime path: clean")
	out += "TEST COMPLETE\n"
	
	var f: File = File.new()
	f.open("C:/Users/suneh/AppData/Local/Temp/opencode/test_out.txt", File.WRITE)
	f.store_string(out)
	f.close()
	quit()
