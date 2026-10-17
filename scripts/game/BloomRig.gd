extends Node

# Zikozythia layered bloom rig
# One render buffer per bloom layer (notes, cursor, border, background,
# effects) with cull-masked cameras. The blur chain runs INSIDE each layer's
# viewport as sequential back-buffer passes, so the whole pipeline completes
# within a single frame - the glow never lags behind moving objects.

const L_WORLD = 1
const L_NOTES = 2
const L_CURSOR = 4
const L_BORDER = 8
const L_BG = 16

const BASE_HEIGHT = 720
const BLUR_DIV = 3
const PASSES = 6

var layers := {}
var bloom_mat: ShaderMaterial
var chain_shader: Shader

onready var song = get_parent()

var trail_script = preload("res://scripts/game/CursorTrail.gd")

func _ready():
	if Rhythia.vr:
		set_process(false)
		return
	# run AFTER the gameplay camera (priority 1) so the bloom buffers always
	# render with the current frame's camera transform - no lag/trailing
	process_priority = 10
	bloom_mat = get_node("../Camera/Bloom").material
	chain_shader = load("res://assets/shaders/bloom_chain.shader")
	_build_layer("notes", L_NOTES)
	_build_layer("cursor", L_CURSOR)
	_build_layer("border", L_BORDER)
	_build_layer("background", L_BG)
	_build_layer("world", L_WORLD)
	_tag_static()

func _build_layer(lname: String, mask: int):
	var vp := Viewport.new()
	vp.name = "BloomBuf_" + lname
	# low-res layer buffers: the glow energy spreads into a wide soft halo
	# instead of stacking as a bright copy on top of the element
	vp.size = Vector2(BASE_HEIGHT * 16 / 9 / BLUR_DIV, BASE_HEIGHT / BLUR_DIV)
	vp.render_target_update_mode = Viewport.UPDATE_ALWAYS
	vp.msaa = Viewport.MSAA_DISABLED
	vp.hdr = false
	var cam := Camera.new()
	cam.name = "Cam_" + lname
	cam.current = true
	cam.cull_mask = mask
	vp.add_child(cam)

	# in-viewport blur chain: each pass samples the viewport's back-buffer
	var chain := []
	for j in range(PASSES):
		var bb := BackBufferCopy.new()
		bb.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
		bb.rect = Rect2(Vector2(-64, -64), Vector2(2560, 1536))
		vp.add_child(bb)

		var rect := ColorRect.new()
		rect.anchor_right = 1.0
		rect.anchor_bottom = 1.0
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat := ShaderMaterial.new()
		mat.shader = chain_shader
		rect.material = mat
		vp.add_child(rect)
		chain.append(mat)

	# the song scene is still setting up children during _ready - defer the add
	song.call_deferred("add_child", vp)
	layers[lname] = {"vp": vp, "cam": cam, "chain": chain}

func _tag_subtree(n: Node, bits: int):
	if n is VisualInstance:
		n.layers = bits
	for c in n.get_children():
		_tag_subtree(c, bits)

func _tag_once(node_path: String, bits: int):
	var n = get_node_or_null(node_path)
	if n and not n.has_meta("bloom_tagged"):
		_tag_subtree(n, bits)
		n.set_meta("bloom_tagged", true)

func _tag_static():
	_tag_once("../Game/Spawn/Outer", L_BORDER)
	_tag_once("../Game/Spawn/Inner", L_BORDER)
	_tag_once("../Game/Spawn/Notes", L_NOTES)
	_tag_once("../Game/Spawn/ASq", L_NOTES)
	_tag_once("../Game/Spawn/SpawnEffect", L_NOTES)
	_tag_once("../Game/Spawn/Note", L_NOTES)
	_tag_once("../Game/Spawn/Cursor", L_CURSOR)
	_tag_once("../Game/CursorTrail", L_CURSOR)

func _tag_dynamic():
	# cursor trail segments spawn under Game while playing
	var game = get_node_or_null("../Game")
	if game:
		for c in game.get_children():
			if c.has_meta("bloom_tagged"): continue
			if c.get_script() == trail_script:
				_tag_subtree(c, L_CURSOR)
				c.set_meta("bloom_tagged", true)
	# background worlds (incl. custom background) spawn as song root children
	var known = ["AbsCamera", "Camera", "AltCam", "Game", "SpinPos", "BloomRig"]
	for c in song.get_children():
		if c.has_meta("bloom_tagged"): continue
		if c.name in known: continue
		_tag_subtree(c, L_BG)
		c.set_meta("bloom_tagged", true)

func _update_chain(k: String, radius: float, threshold: float):
	var chain = layers[k]["chain"]
	var bsz = layers[k]["vp"].size
	var texel = Vector2(1.0 / bsz.x, 1.0 / bsz.y)
	# blur runs at a third of the base resolution so the glow energy spreads
	# into a wide soft halo; the composite upscales it with bilinear sampling
	var offsets = [
		clamp(radius * 0.05, 0.5, 1.0),
		clamp(radius * 0.1, 1.0, 3.0),
		clamp(radius * 0.25, 2.0, 6.0),
		clamp(radius * 0.5, 4.0, 12.0),
		clamp(radius * 1.0, 8.0, 24.0),
		clamp(radius * 2.0, 16.0, 48.0)
	]
	for j in range(PASSES):
		var mat = chain[j]
		mat.set_shader_param("texel", texel)
		mat.set_shader_param("offset", offsets[j])
		mat.set_shader_param("threshold", threshold)
		mat.set_shader_param("threshold_enabled", j == 0)

func _process(_d):
	if layers.empty(): return
	if not layers["notes"]["vp"].is_inside_tree():
		return  # deferred adds not run yet
	var mode = Viewport.UPDATE_ALWAYS if Rhythia.bloom_shader else Viewport.UPDATE_DISABLED
	for k in layers:
		layers[k]["vp"].render_target_update_mode = mode
	if not Rhythia.bloom_shader: return

	var cam = get_viewport().get_camera()
	if cam:
		for k in layers:
			var c = layers[k]["cam"]
			c.global_transform = cam.global_transform
			c.fov = cam.fov
			c.near = cam.near
			c.far = cam.far
	_tag_dynamic()

	# keep the buffers matching the screen aspect so the glow stays
	# aligned with the elements on any display (at low res)
	var vs = get_viewport().size
	if vs.x > 1.0 and vs.y > 1.0:
		var want = Vector2(int((BASE_HEIGHT * float(vs.x) / float(vs.y)) / BLUR_DIV), BASE_HEIGHT / BLUR_DIV)
		for k in layers:
			if layers[k]["vp"].size != want:
				layers[k]["vp"].size = want
				VisualServer.viewport_set_size(layers[k]["vp"].get_viewport_rid(), int(want.x), int(want.y))
		bloom_mat.set_shader_param("bloom_texel", Vector2(1.0 / want.x, 1.0 / want.y))

	bloom_mat.set_shader_param("bloom_saturation", Rhythia.bloom_saturation)

	_update_chain("notes", Rhythia.bloom_notes_radius, Rhythia.bloom_threshold)
	bloom_mat.set_shader_param("notes_tex", layers["notes"]["vp"].get_texture())
	bloom_mat.set_shader_param("notes_strength", Rhythia.bloom_notes_strength)

	_update_chain("cursor", Rhythia.bloom_cursor_radius, Rhythia.bloom_threshold)
	bloom_mat.set_shader_param("cursor_tex", layers["cursor"]["vp"].get_texture())
	bloom_mat.set_shader_param("cursor_strength", Rhythia.bloom_cursor_strength)

	_update_chain("border", Rhythia.bloom_border_radius, Rhythia.bloom_threshold)
	bloom_mat.set_shader_param("border_tex", layers["border"]["vp"].get_texture())
	bloom_mat.set_shader_param("border_strength", Rhythia.bloom_border_strength)

	_update_chain("background", Rhythia.bloom_background_radius, Rhythia.bloom_threshold)
	bloom_mat.set_shader_param("background_tex", layers["background"]["vp"].get_texture())
	bloom_mat.set_shader_param("background_strength", Rhythia.bloom_background_strength)

	_update_chain("world", Rhythia.bloom_world_radius, Rhythia.bloom_threshold)
	bloom_mat.set_shader_param("world_tex", layers["world"]["vp"].get_texture())
	bloom_mat.set_shader_param("world_strength", Rhythia.bloom_world_strength)
