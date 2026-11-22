extends "res://scripts/cursordance/DanceMover.gd"

# Zikozythia: humanized autoplay.
# The base path is BouncyDanceMover - it provably flows through every note,
# so every hit looks real. Between notes, the path is bent toward the
# player's own recorded flick shapes (MoveProfile), fading to exactly zero
# at each note. Fast streams get a subtle hand wobble instead of full
# shapes, since an overshoot can't be corrected in time.

var base: BouncyDanceMover
var notes: PoolVector3Array
var bursts: Array = []
var jit: float = 0.005
var style: float = 0.8
var ci: int = 0
var shape_ci: int = - 1
var shape_tf: Array = []
var shape_al: Array = []
var shape_pe: Array = []

func _init(song: Song, prof: Dictionary):
	base = BouncyDanceMover.new(song)
	notes = PoolVector3Array()
	for n in song.read_notes():
		notes.append(Vector3(n[0], n[1], n[2]))
	bursts = prof.get("bursts", [])
	if bursts.size() > 500:
		var thin: Array = []
		var step: float = float(bursts.size()) / 500.0
		for i in range(500):
			thin.append(bursts[int(float(i) * step)])
		bursts = thin
	var stats: Dictionary = prof.get("stats", {})
	jit = max(float(stats.get("jit", 0.004)), 0.003)

func _pick_shape(dist: float, dur: float):
	var best: int = - 1
	var best_score: float = 1e18
	for k in range(bursts.size()):
		var bu: Dictionary = bursts[k]
		var sc: float = (
			abs(log((float(bu.d) + 0.02) / (dist + 0.02))) + 
			0.7 * abs(log((float(bu.t) + 8.0) / (dur + 8.0)))
		)
		if sc < best_score:
			best_score = sc
			best = k
	shape_tf = []
	shape_al = []
	shape_pe = []
	if best == - 1: return
	var bu: Dictionary = bursts[best]
	var s: Array = bu.s
	var tf: Array = bu.tf
	for k in range(s.size() / 2):
		shape_tf.append(clamp(float(tf[k]), 0.0, 1.0))
		shape_al.append(clamp(float(s[k * 2]), 0.0, 1.25))
		shape_pe.append(clamp(float(s[k * 2 + 1]), - 0.45, 0.45))
	# enforce monotonic timing and anchor both ends onto the notes
	if shape_tf.size() > 1:
		for k in range(1, shape_tf.size()):
			if shape_tf[k] <= shape_tf[k - 1]: shape_tf[k] = shape_tf[k - 1] + 0.001
		if shape_tf[shape_tf.size() - 1] > 1.0:
			for k in range(shape_tf.size()):
				shape_tf[k] = shape_tf[k] / shape_tf[shape_tf.size() - 1]
		shape_tf[0] = 0.0
		shape_al[0] = 0.0
		shape_al[shape_al.size() - 1] = 1.0

# (along, perp) of the selected shape at time fraction f (0 = prev note, 1 = note)
func _shape_at(f: float) -> Vector2:
	var n: int = shape_tf.size()
	if n == 0: return Vector2.ZERO
	if f <= shape_tf[0]: return Vector2(shape_al[0], shape_pe[0])
	if f >= shape_tf[n - 1]: return Vector2(shape_al[n - 1], shape_pe[n - 1])
	for k in range(n - 1):
		if f >= shape_tf[k] and f <= shape_tf[k + 1]:
			var span: float = max(shape_tf[k + 1] - shape_tf[k], 0.0001)
			var t: float = (f - shape_tf[k]) / span
			return Vector2(
				lerp(shape_al[k], shape_al[k + 1], t), 
				lerp(shape_pe[k], shape_pe[k + 1], t)
			)
	return Vector2(shape_al[n - 1], shape_pe[n - 1])

func _update(ms: float) -> Vector2:
	var p: Vector2 = base.update(ms)
	if notes.size() < 2: return p
	while ci < notes.size() - 2 and notes[ci + 1].z <= ms:
		ci += 1
	if ms < notes[0].z or ms > notes[notes.size() - 1].z: return p
	var a: Vector2 = Vector2(notes[ci].x, notes[ci].y)
	var b: Vector2 = Vector2(notes[ci + 1].x, notes[ci + 1].y)
	var ta: float = notes[ci].z
	var tb: float = notes[ci + 1].z
	var dt: float = tb - ta
	if dt <= 0.0: return p
	var f: float = clamp((ms - ta) / dt, 0.0, 1.0)
	var d: Vector2 = b - a
	var dist: float = d.length()
	if dist < 0.001: return p
	var u: Vector2 = d / dist
	var nn: Vector2 = Vector2(- u.y, u.x)
	var sway: float = sin(f * PI)
	
	if dt < 250.0:
		# streams: subtle hand wobble, no timing distortion
		return p + nn * sin(f * 3.0 + float(ci)) * 0.05 * sway + Vector2(sin(ms * 0.021), cos(ms * 0.017)) * jit
	
	# jumps / calm gaps: bend the path through the player's own flick shape
	if ci != shape_ci:
		shape_ci = ci
		_pick_shape(dist, dt)
	if shape_tf.size() < 2: return p
	var sp: Vector2 = _shape_at(f)
	var shaped: Vector2 = a + u * (sp.x * dist) + nn * (sp.y * dist)
	# hard cap: style may bend the path, but never far enough to look like
	# a miss - deviation from the straight note-to-note line stays small
	var line_pos: Vector2 = a.linear_interpolate(b, f)
	var dev: Vector2 = shaped - line_pos
	var max_dev: float = min(0.45 * dist, 0.35)
	if dev.length() > max_dev:
		shaped = line_pos + dev.normalized() * max_dev
	return p.linear_interpolate(shaped, clamp(style * sway, 0.0, 1.0)) + Vector2(sin(ms * 0.021), cos(ms * 0.017)) * jit
