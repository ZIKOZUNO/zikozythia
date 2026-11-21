extends "res://scripts/cursordance/DanceMover.gd"

# Zikozythia: humanized autoplay.
# Instead of the mathematically perfect BouncyDanceMover, this generates a
# cursor path from the player's own recorded movement bursts (MoveProfile):
# same flick shapes, same acceleration rhythm, same overshoot and drift -
# but it always arrives on every note, regardless of skill ceiling.

const SHAPE_PTS: int = 12

var w_pos: PoolVector2Array
var w_ms: PoolRealArray
var cur: int = 0

func _init(notes: PoolVector3Array, prof: Dictionary, seed_str: String = ""):
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(seed_str)
	var bursts: Array = prof.get("bursts", [])
	var stats: Dictionary = prof.get("stats", {})
	var v50: float = float(stats.get("v50", 4.0))
	var v99: float = float(stats.get("v99", 14.0))
	var jit: float = max(float(stats.get("jit", 0.004)), 0.006)
	
	# keep the library small enough to search fast
	if bursts.size() > 500:
		var thin: Array = []
		var step: float = float(bursts.size()) / 500.0
		for i in range(500):
			thin.append(bursts[int(float(i) * step)])
		bursts = thin
	
	# mirror mods (same behaviour as BouncyDanceMover)
	var ml = Engine.get_main_loop()
	if ml != null and ml.root.has_node("Rhythia"):
		var R: Node = ml.root.get_node("Rhythia")
		if R.mod_mirror_x:
			for i in range(notes.size()):
				notes[i] = Vector3(2 - notes[i].x, notes[i].y, notes[i].z)
		if R.mod_mirror_y:
			for i in range(notes.size()):
				notes[i] = Vector3(notes[i].x, 2 - notes[i].y, notes[i].z)
	
	if notes.size() == 0: return
	
	w_pos = PoolVector2Array()
	w_ms = PoolRealArray()
	var pos: Vector2 = Vector2(notes[0].x, notes[0].y)
	w_pos.append(pos)
	w_ms.append(notes[0].z - 3000.0)
	
	for i in range(1, notes.size()):
		var a: Vector2 = pos
		var ta: float = notes[i - 1].z
		var b: Vector2 = Vector2(notes[i].x, notes[i].y)
		var tb: float = notes[i].z
		var dt: float = tb - ta
		var d: Vector2 = b - a
		var dist: float = d.length()
		
		if dt <= 30.0 or dist < 0.001:
			w_pos.append(b)
			w_ms.append(max(tb, w_ms[w_ms.size() - 1] + 1.0))
			pos = b
			continue
		
		var u: Vector2 = d / dist
		var nn: Vector2 = Vector2(- u.y, u.x)
		var vneed: float = dist / (dt / 1000.0)
		
		# how long the movement itself takes inside the gap
		var mdur: float
		if vneed > v99:
			mdur = dt * 0.95  # map is faster than anything recorded - just go
		else:
			var t_est: float = dist / max(v50, 0.5) * 1000.0 * 1.15
			mdur = clamp(t_est, min(dt * 0.35, 45.0), dt * 0.85)
		
		# build the movement points for this gap
		var seg_pos: Array = []
		var seg_ms: Array = []
		if dt < 70.0 or mdur < 30.0:
			# too short for a shape - one quick eased flick
			for k in range(6):
				var f: float = (float(k) + 1.0) / 6.0
				seg_pos.append(a.linear_interpolate(b, smoothstep(0.0, 1.0, f)))
				seg_ms.append(ta + f * (dt * 0.9))
		else:
			# closest matching burst from the player's own recordings
			var best: int = - 1
			var best_score: float = 1e18
			for k in range(bursts.size()):
				var bu: Dictionary = bursts[k]
				var sc: float = (
					abs(log((float(bu.d) + 0.02) / (dist + 0.02))) + 
					0.7 * abs(log((float(bu.t) + 8.0) / (mdur + 8.0)))
				)
				if sc < best_score:
					best_score = sc
					best = k
			
			if best != - 1:
				var bu: Dictionary = bursts[best]
				var s: Array = bu.s
				var tf: Array = bu.tf
				for k in range(SHAPE_PTS):
					var along: float = clamp(float(s[k * 2]), - 0.3, 1.4) * dist
					var perp: float = clamp(float(s[k * 2 + 1]), - 0.5, 0.5) * dist
					seg_pos.append(a + u * along + nn * perp)
					seg_ms.append(ta + float(tf[k]) * mdur)
			else:
				for k in range(SHAPE_PTS):
					var f: float = (float(k) + 1.0) / float(SHAPE_PTS)
					seg_pos.append(a.linear_interpolate(b, smoothstep(0.0, 1.0, f)))
					seg_ms.append(ta + f * mdur)
			
			# smooth the path so recorded jitter never looks broken
			for _sm in range(2):
				for k in range(1, seg_pos.size() - 1):
					seg_pos[k] = (seg_pos[k - 1] + seg_pos[k] * 2.0 + seg_pos[k + 1]) * 0.25
		
		# append the movement, keeping times strictly increasing
		for k in range(seg_pos.size()):
			w_pos.append(seg_pos[k])
			w_ms.append(max(seg_ms[k], w_ms[w_ms.size() - 1] + 0.25))
		
		# settle exactly onto the note
		w_pos.append(b)
		w_ms.append(max(tb, w_ms[w_ms.size() - 1] + 0.25))
		
		# idle drift around the note until the next one is due
		var idle_ms: float = max(tb - (ta + mdur), 0.0)
		var n_idle: int = int(clamp(idle_ms / 30.0, 1.0, 6.0))
		for k in range(1, n_idle + 1):
			var f2: float = float(k) / float(n_idle + 1)
			var wm: float = (ta + mdur) + f2 * idle_ms
			var tr: float = sin(wm * 0.02 + float(k)) * jit
			w_pos.append(b + nn * tr + Vector2(rng.randf_range(- jit, jit), rng.randf_range(- jit, jit)))
			w_ms.append(max(wm, w_ms[w_ms.size() - 1] + 0.25))
		
		pos = b
	
	# enforce strictly increasing times
	for i in range(1, w_ms.size()):
		if w_ms[i] <= w_ms[i - 1]:
			w_ms[i] = w_ms[i - 1] + 0.25

func _update(ms: float) -> Vector2:
	if w_ms.size() == 0: return Vector2(1, 1)
	if ms <= w_ms[0]: return w_pos[0]
	if ms >= w_ms[w_ms.size() - 1]: return w_pos[w_pos.size() - 1]
	if cur >= w_ms.size() - 2 or w_ms[cur] > ms: cur = 0
	while cur < w_ms.size() - 2 and w_ms[cur + 1] <= ms:
		cur += 1
	var f: float = (ms - w_ms[cur]) / max(w_ms[cur + 1] - w_ms[cur], 0.001)
	return w_pos[cur].linear_interpolate(w_pos[cur + 1], clamp(f, 0.0, 1.0))
