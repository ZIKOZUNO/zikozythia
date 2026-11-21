extends SceneTree

# Zikozythia self-check: run with
#   Zikozythia.exe -s res://test_selfcheck.gd
# Writes results to C:/Users/suneh/AppData/Local/Temp/opencode/test_out.txt

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
		# a script with a parse error still loads - force a recompile to catch it.
		# NOTE: scripts with live instances (autoloads) refuse reload with
		# ERR_ALREADY_IN_USE - that is not a parse error.
		if s != "res://scripts/Rhythia.gd":
			var err = res.reload()
			if int(err) != 0:
				out += "FAIL parse (%s): %s\n" % [err, s]
				continue
		out += "ok: %s\n" % s
	
	var prof = load("res://scripts/cursordance/MoveProfile.gd")
	var t0 = OS.get_ticks_usec()
	var p = prof.load_or_build(true)
	var t1 = OS.get_ticks_usec()
	out += "profile build: %.0f ms\n" % ((t1 - t0) / 1000.0)
	if p == null:
		out += "PROFILE IS NULL (no valid replays found?)\n"
	else:
		out += "bursts: %s from %s replays\n" % [p.bursts.size(), p.replay_count]
		out += "stats: v50=%.2f v90=%.2f\n" % [float(p.stats.v50), float(p.stats.v90)]
		out += "TEST COMPLETE\n"
	var f = File.new()
	f.open("C:/Users/suneh/AppData/Local/Temp/opencode/test_out.txt", File.WRITE)
	f.store_string(out)
	f.close()
	quit()
