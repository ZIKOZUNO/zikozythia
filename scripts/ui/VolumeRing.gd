extends Control

# Zikozythia volume ring - shown while Alt is held.
# A white circle outline with a red arc that fills clockwise with the
# current master volume, and the percentage in the middle.

var pct: float = 0.5
var holding: bool = false
var fade: float = 0.0

func set_pct(p: float):
	var np = clamp(p, 0.0, 1.0)
	if abs(np - pct) > 0.0001:
		pct = np
		update()

func _process(delta):
	if holding:
		fade = 1.0
		modulate.a = min(modulate.a + (delta * 10.0), 1.0)
	elif fade > 0.0:
		fade = max(fade - (delta * 2.5), 0.0)
		modulate.a = fade
	visible = modulate.a > 0.02

func _draw():
	var c = rect_size * 0.5
	var r = (min(rect_size.x, rect_size.y) * 0.5) - 6.0
	# white outline ring
	draw_arc(c, r, 0.0, TAU, 64, Color(1, 1, 1, 0.5), 3.0, true)
	# red fill arc - grows clockwise from the top
	draw_arc(c, r, -PI * 0.5, (-PI * 0.5) + (TAU * pct), 64, Color(0.95, 0.1, 0.15, 0.98), 7.0, true)
	# percentage in the middle
	var font = get_font("", "Label")
	var txt = "%d%%" % int(round(pct * 100.0))
	var ts = font.get_string_size(txt)
	draw_string(font, c - (ts * 0.5) + Vector2(0, font.get_ascent() * 0.5), txt, Color(1, 1, 1, 0.95))
