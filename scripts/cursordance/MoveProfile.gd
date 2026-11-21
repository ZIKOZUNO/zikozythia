extends Reference

# Zikozythia: movement profile built from the player's own replays.
# Extracts "movement bursts" (how the player actually flicks and glides
# their cursor) so the humanized autoplay can move like them.

const MOVE_TH: float = 0.35
const MERGE_GAP: float = 90.0
const SHAPE_PTS: int = 12
const MAX_REPLAYS: int = 40
const MAX_SAMPLES_PER_REPLAY: int = 12000
const PROFILE_PATH: String = "user://moveprofile.json"

# A replay file is only usable if it was properly finalized by
# end_recording() - which writes Globals.RS_END (5) as the last byte.
static func is_valid_replay(path: String) -> bool:
	var f: File = File.new()
	if f.open(path, File.READ) != OK: return false
	var ok: bool = f.get_len() >= 120
	if ok:
		f.seek(f.get_len() - 1)
		ok = (f.get_8() == 5)
	f.close()
	return ok

# Lightweight .sspre cursor parser - only pulls the cursor samples out.
static func parse_cursor(path: String) -> Array:
	var out: Array = []
	var f: File = File.new()
	if f.open(path, File.READ) != OK: return out
	if f.get_buffer(4) != PoolByteArray([83, 115, 42, 82]):
		f.close()
		return out
	var sv: int = f.get_16()
	f.get_64()
	if sv >= 4: f.get_line()
	f.get_line()  # replay id
	f.get_line()  # mod state
	if sv >= 3:
		f.get_float()  # approach rate
		f.get_float()  # spawn distance
		f.get_float()  # fade length
		f.get_float()  # parallax
		f.get_float()  # ui parallax
		f.get_float()  # grid parallax
		f.get_float()  # fov
		f.get_8()      # cam unlock
		f.get_float()  # edge drift
	f.get_8()      # reserved
	f.get_32()     # end ms
	f.get_32()     # signal count
	var kind: int = f.get_8()
	while kind != 5 and not f.eof_reached():
		if kind == 0:  # RS_CURSOR
			var ms: float = float(f.get_32())
			var x: float = f.get_float()
			var y: float = f.get_float()
			out.append([ms, x, y])
		else:
			f.get_32()  # every other signal carries one u32
		kind = f.get_8()
	f.close()
	return out

# Splits a replay's cursor path into movement bursts and appends
# normalized entries to the library.
static func extract_bursts(samples: Array, bursts: Array) -> void:
	if samples.size() < 8: return
	if samples.size() > MAX_SAMPLES_PER_REPLAY:
		var stride: int = int(samples.size() / float(MAX_SAMPLES_PER_REPLAY)) + 1
		var thin: Array = []
		for i in range(0, samples.size(), stride):
			thin.append(samples[i])
		samples = thin
		if samples[samples.size() - 1] != samples_back(samples):
			samples.append(samples_back(samples))
	var burst_start: int = - 1
	var last_move_i: int = - 1
	for i in range(samples.size() - 1):
		var dt: float = float(samples[i + 1][0]) - float(samples[i][0])
		var dist: float = Vector2(samples[i][1], samples[i][2]).distance_to(Vector2(samples[i + 1][1], samples[i + 1][2]))
		var spd: float = dist / max(dt, 1.0) * 1000.0
		if spd > MOVE_TH:
			if burst_start == - 1: burst_start = i
			last_move_i = i + 1
		elif burst_start != - 1 and float(samples[i + 1][0]) - float(samples[last_move_i][0]) > MERGE_GAP:
			if last_move_i > burst_start: _add_burst(samples, burst_start, last_move_i, bursts)
			burst_start = - 1
	if burst_start != - 1 and last_move_i > burst_start:
		_add_burst(samples, burst_start, last_move_i, bursts)

static func samples_back(samples: Array):
	return samples[samples.size() - 1]

static func _add_burst(samples: Array, a: int, b: int, bursts: Array) -> void:
	if bursts.size() >= 200 * MAX_REPLAYS: return
	var start: Vector2 = Vector2(samples[a][1], samples[a][2])
	var end: Vector2 = Vector2(samples[b][1], samples[b][2])
	var disp: Vector2 = end - start
	var dd: float = disp.length()
	var dur: float = float(samples[b][0]) - float(samples[a][0])
	if dur < 25.0 or dd < 0.02: return
	
	var u: Vector2 = disp / dd
	var nn: Vector2 = Vector2(- u.y, u.x)
	
	# cumulative path length for even resampling
	var cum: Array = [0.0]
	var total: float = 0.0
	for i in range(a + 1, b + 1):
		total += Vector2(samples[i][1], samples[i][2]).distance_to(Vector2(samples[i - 1][1], samples[i - 1][2]))
		cum.append(total)
	if total < 0.001: return
	
	var s: PoolRealArray = PoolRealArray()
	var tf: PoolRealArray = PoolRealArray()
	var max_along: float = - 1.0
	var target: int = SHAPE_PTS
	var pt_i: int = 0
	for k in range(target):
		var fpath: float = float(k) / float(target - 1)
		var want: float = fpath * total
		while pt_i < cum.size() - 2 and cum[pt_i + 1] < want:
			pt_i += 1
		var seg: float = max(cum[pt_i + 1] - cum[pt_i], 0.0001)
		var fseg: float = clamp((want - cum[pt_i]) / seg, 0.0, 1.0)
		var p: Vector2 = Vector2(samples[a + pt_i][1], samples[a + pt_i][2]).linear_interpolate(
			Vector2(samples[a + pt_i + 1][1], samples[a + pt_i + 1][2]), fseg)
		var rel: Vector2 = p - start
		var along: float = rel.dot(u) / dd
		var perp: float = rel.dot(nn) / dd
		if along > max_along: max_along = along
		s.append(clamp(along, - 0.3, 1.4))
		s.append(clamp(perp, - 0.6, 0.6))
		var tfk: float = clamp((float(samples[a + pt_i][0]) - float(samples[a][0])) / dur, 0.0, 1.0)
		tf.append(tfk)
	
	# erratic bursts (loops, stutters) would look broken when replayed
	if max_along > 1.75 or max_along < 0.15: return
	
	bursts.append({
		"t": dur, 
		"d": dd, 
		"pl": total, 
		"os": max_along, 
		"s": s, 
		"tf": tf
	})

static func build() -> Dictionary:
	var replays: Array = []
	var d: Directory = Directory.new()
	var rp: String = "user://replays/"
	if d.dir_exists(rp) and d.open(rp) == OK:
		d.list_dir_begin(true)
		var fname: String = d.get_next()
		while fname != "":
			if not d.current_is_dir() and fname.get_extension() == "sspre":
				var full: String = rp + fname
				if is_valid_replay(full):
					replays.append([d.get_modified_time(full), full])
			fname = d.get_next()
		d.list_dir_end()
	
	# learn from the NEWEST recordings so the profile follows the player as
	# they improve or change playstyle (manual selection - no sort_custom)
	var chosen: Array = []
	for _r in range(min(MAX_REPLAYS, replays.size())):
		var best_i: int = - 1
		var best_t: int = - 1
		for i in range(replays.size()):
			if chosen.has(i): continue
			if int(replays[i][0]) > best_t:
				best_t = int(replays[i][0])
				best_i = i
		if best_i == - 1: break
		chosen.append(best_i)
	
	var bursts: Array = []
	var disp_speeds: Array = []
	var used: int = 0
	for ci in chosen:
		var samples: Array = parse_cursor(replays[ci][1])
		if samples.size() < 8: continue
		var before: int = bursts.size()
		extract_bursts(samples, bursts)
		if bursts.size() > before:
			used += 1
			for i in range(before, bursts.size()):
				disp_speeds.append(float(bursts[i].d) / max(float(bursts[i].t) / 1000.0, 0.001))
	
	disp_speeds.sort()
	var stats: Dictionary = {
		"v50": _pct(disp_speeds, 0.5), 
		"v90": _pct(disp_speeds, 0.9), 
		"v99": _pct(disp_speeds, 0.99), 
		"jit": 0.004
	}
	return {"bursts": bursts, "stats": stats, "replay_count": replays.size()}

static func _pct(arr: Array, p: float) -> float:
	if arr.size() == 0: return 4.0
	return float(arr[int(clamp(float(arr.size() - 1) * p, 0.0, float(arr.size() - 1)))])

static func load_or_build(force: bool = false):
	var f: File = File.new()
	var file_count: int = 0
	var rp: String = "user://replays/"
	if d_exists(rp):
		var d: Directory = Directory.new()
		d.open(rp)
		d.list_dir_begin(true)
		var fname: String = d.get_next()
		while fname != "":
			if not d.current_is_dir() and fname.get_extension() == "sspre":
				file_count += 1
			fname = d.get_next()
		d.list_dir_end()
	if not force and f.file_exists(PROFILE_PATH):
		if f.open(PROFILE_PATH, File.READ) == OK:
			var data = parse_json(f.get_as_text())
			f.close()
			if data != null and data.has("bursts") and data.bursts.size() > 0:
				if int(data.get("replay_count", - 1)) == file_count:
					return data
	var prof: Dictionary = build()
	if prof.bursts.size() == 0: return null
	prof.replay_count = file_count
	var sf: File = File.new()
	if sf.open(PROFILE_PATH, File.WRITE) == OK:
		sf.store_string(to_json(prof))
		sf.close()
	return prof

static func d_exists(path: String) -> bool:
	var d: Directory = Directory.new()
	return d.dir_exists(path)
