extends Node

# Zikozythia layered bloom rig
# Builds one low-resolution render buffer per bloom layer (notes, cursor,
# border, background, effects/world) using camera cull masks, keeps the buffer
# cameras locked to the active gameplay camera, tags every element into its
# layer, and feeds the buffers to the composite shader on the Bloom color rect.

const L_WORLD = 1
const L_NOTES = 2
const L_CURSOR = 4
const L_BORDER = 8
const L_BG = 16

# fixed 16:9 bloom buffers (higher res = smoother glow after upscaling)
const BUFFER_SIZE = Vector2(1280, 720)

var layers := {}
var bloom_mat: ShaderMaterial

onready var song = get_parent()

var trail_script = preload("res://scripts/game/CursorTrail.gd")

func _ready():
	if Rhythia.vr:
		set_process(false)
		return
	bloom_mat = get_node("../Camera/Bloom").material
	_build_layer("notes", L_NOTES)
	_build_layer("cursor", L_CURSOR)
	_build_layer("border", L_BORDER)
	_build_layer("background", L_BG)
	_build_layer("world", L_WORLD)
	_tag_static()

func _build_layer(lname: String, mask: int):
	var vp := Viewport.new()
	vp.name = "BloomBuf_" + lname
	vp.size = BUFFER_SIZE
	vp.render_target_update_mode = Viewport.UPDATE_ALWAYS
	vp.msaa = Viewport.MSAA_DISABLED
	vp.hdr = false
	var cam := Camera.new()
	cam.name = "Cam_" + lname
	cam.current = true
	cam.cull_mask = mask
	vp.add_child(cam)
	# the song scene is still setting up children during _ready - defer the add
	song.call_deferred("add_child", vp)
	layers[lname] = {"vp": vp, "cam": cam}

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

	var texel = Vector2(1.0 / BUFFER_SIZE.x, 1.0 / BUFFER_SIZE.y)
	bloom_mat.set_shader_param("bloom_texel", texel)
	bloom_mat.set_shader_param("bloom_threshold", Rhythia.bloom_threshold)
	bloom_mat.set_shader_param("bloom_saturation", Rhythia.bloom_saturation)

	bloom_mat.set_shader_param("notes_tex", layers["notes"]["vp"].get_texture())
	bloom_mat.set_shader_param("notes_strength", Rhythia.bloom_notes_strength)
	bloom_mat.set_shader_param("notes_radius", Rhythia.bloom_notes_radius)

	bloom_mat.set_shader_param("cursor_tex", layers["cursor"]["vp"].get_texture())
	bloom_mat.set_shader_param("cursor_strength", Rhythia.bloom_cursor_strength)
	bloom_mat.set_shader_param("cursor_radius", Rhythia.bloom_cursor_radius)

	bloom_mat.set_shader_param("border_tex", layers["border"]["vp"].get_texture())
	bloom_mat.set_shader_param("border_strength", Rhythia.bloom_border_strength)
	bloom_mat.set_shader_param("border_radius", Rhythia.bloom_border_radius)

	bloom_mat.set_shader_param("background_tex", layers["background"]["vp"].get_texture())
	bloom_mat.set_shader_param("background_strength", Rhythia.bloom_background_strength)
	bloom_mat.set_shader_param("background_radius", Rhythia.bloom_background_radius)

	bloom_mat.set_shader_param("world_tex", layers["world"]["vp"].get_texture())
	bloom_mat.set_shader_param("world_strength", Rhythia.bloom_world_strength)
	bloom_mat.set_shader_param("world_radius", Rhythia.bloom_world_radius)
