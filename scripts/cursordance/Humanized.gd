extends "res://scripts/cursordance/DanceMover.gd"

# Zikozythia: humanized autoplay.
# The note-tracking base is BouncyDanceMover (it provably reaches every
# note); a humanization layer built from the player's own replay stats is
# applied on top: a short "hand lag" (the cursor chases the ideal path
# instead of teleporting) plus a speed-scaled tremor - so it reads as a
# hand, not a laser. The layer can never break note tracking: worst case
# the cursor trails the ideal path by a few milliseconds.

var base: DanceMover
var lag_ms: float = 40.0
var jit: float = 0.006
var prev: Vector2 = Vector2.ZERO
var last_ms: float = - 1e9
var started: bool = false

func _init(song: Song, prof: Dictionary):
	base = BouncyDanceMover.new(song)
	var stats: Dictionary = prof.get("stats", {})
	var v90: float = max(float(stats.get("v90", 4.0)), 1.0)
	jit = max(float(stats.get("jit", 0.004)), 0.004)
	# faster players have snappier hands - shorter lag; the profile rebuilds
	# from your newest replays, so this follows you as you improve
	lag_ms = clamp(50.0 - v90 * 3.0, 15.0, 50.0)

func _update(ms: float) -> Vector2:
	var target: Vector2 = base.update(ms)
	if not started or ms < last_ms:
		prev = target
		last_ms = ms
		started = true
		return prev
	var dt_ms: float = max(ms - last_ms, 0.5)
	last_ms = ms
	# hand lag: chase the ideal path with a short delay
	var k: float = clamp(1.0 - exp(-dt_ms / lag_ms), 0.0, 1.0)
	var p: Vector2 = prev.linear_interpolate(target, k)
	# speed-scaled hand tremor
	var spd: float = p.distance_to(prev) / (dt_ms / 1000.0)
	var t: float = ms * 0.02
	var amp: float = jit * (0.3 + min(spd * 1.5, 1.2))
	var tremor: Vector2 = Vector2(sin(t * 2.3), cos(t * 1.6)) * amp
	prev = p + tremor
	return prev
