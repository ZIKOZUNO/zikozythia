extends Control

# Zikozythia - live bloom preview for the settings page.
# Renders a miniature gameplay scene (background, playfield border,
# approaching notes, cursor, hit effect) through the same layered bloom
# pipeline used in-game, and pushes the current bloom settings every frame
# so any change shows up instantly.

const L_WORLD = 1
const L_NOTES = 2
const L_CURSOR = 4
const L_BORDER = 8
const L_BG = 16

var bloom_mat: ShaderMaterial
var main_vp: Viewport
var aux := {}
var notes := []
var hit_note_tex

func _ready():
	rect_min_size = Vector2(550, 309)
	mouse_filter = MOUSE_FILTER_IGNORE

	var vc := ViewportContainer.new()
	vc.anchor_right = 1.0
	vc.anchor_bottom = 1.0
	vc.stretch = true
	add_child(vc)

	main_vp = Viewport.new()
	main_vp.size = Vector2(1100, 619)
	main_vp.own_world = true
	main_vp.render_target_update_mode = Viewport.UPDATE_ALWAYS
	main_vp.hdr = false
	vc.add_child(main_vp)

	var cam := Camera.new()
	cam.fov = 70.0
	cam.cull_mask = 0xFFFFF
	main_vp.add_child(cam)
	cam.translation = Vector3(1.5, 1.15, 3.05)
	cam.look_at(Vector3(1.5, -1.6, 0.0), Vector3(0, 1, 0))

	_build_world()

	for entry in [["notes", L_NOTES], ["cursor", L_CURSOR], ["border", L_BORDER], ["background", L_BG], ["world", L_WORLD]]:
		var vp := Viewport.new()
		vp.name = "Aux_" + String(entry[0])
		vp.size = Vector2(275, 155)
		vp.render_target_update_mode = Viewport.UPDATE_ALWAYS
		vp.hdr = false
		var acam := Camera.new()
		acam.current = true
		acam.cull_mask = entry[1]
		acam.fov = cam.fov
		acam.near = cam.near
		acam.far = cam.far
		vp.add_child(acam)
		acam.translation = cam.translation
		acam.look_at(Vector3(1.5, -1.6, 0.0), Vector3(0, 1, 0))
		main_vp.add_child(vp)
		aux[entry[0]] = {"vp": vp, "cam": acam}

	var rect := ColorRect.new()
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	rect.mouse_filter = MOUSE_FILTER_IGNORE
	bloom_mat = ShaderMaterial.new()
	bloom_mat.shader = load("res://assets/shaders/Bloom.shader")
	rect.material = bloom_mat
	main_vp.add_child(rect)

func _quad(parent: Node, pos: Vector3, sz: Vector2, col: Color, tex: Texture, layer: int, flat: bool):
	var mi := MeshInstance.new()
	var pm := PlaneMesh.new()
	pm.size = sz
	mi.mesh = pm
	var mat := SpatialMaterial.new()
	mat.flags_unshaded = true
	mat.flags_transparent = tex != null
	mat.cull_mode = SpatialMaterial.CULL_DISABLED
	mat.albedo_color = col
	if tex != null:
		mat.albedo_texture = tex
	mi.material_override = mat
	mi.layers = layer
	mi.translation = pos
	if flat:
		mi.rotation_degrees.x = -90
	parent.add_child(mi)
	return mi

func _build_world():
	var grid_tex = load("res://assets/images/grid_outer.png")
	var cursor_tex = load("res://assets/images/cursors/circle.png")
	var note_col := Color(1, 0.75, 0.9)
	var cset = Rhythia.get("selected_colorset")
	if cset and cset.get("colors") and cset.colors.size() > 0:
		note_col = cset.colors[cset.colors.size() - 1]

	# background
	_quad(main_vp, Vector3(1.5, -0.02, -4.0), Vector2(26, 26), Color(0.045, 0.012, 0.05), null, L_BG, true)
	_quad(main_vp, Vector3(-1.6, 0.0, -3.2), Vector2(0.5, 0.5), Color(0.7, 0.12, 0.2), null, L_BG, true)
	_quad(main_vp, Vector3(4.6, 0.0, -5.4), Vector2(0.4, 0.4), Color(0.55, 0.1, 0.16), null, L_BG, true)
	_quad(main_vp, Vector3(0.2, 0.0, -7.4), Vector2(0.7, 0.7), Color(0.5, 0.35, 0.6), null, L_BG, true)

	# playfield border
	_quad(main_vp, Vector3(1.5, 0.0, -1.5), Vector2(4.4, 4.4), Color(1, 1, 1, 0.9), grid_tex, L_BORDER, true)

	# notes approaching
	for i in range(3):
		var n = _quad(main_vp, Vector3(0.55 + i * 0.95, -1.55 + (i % 2) * -0.9, -7.5 + i * 2.0), Vector2(0.62, 0.62), note_col, null, L_NOTES, false)
		notes.append(n)

	# cursor + trail hint
	_quad(main_vp, Vector3(1.05, -1.85, -1.15), Vector2(0.55, 0.55), Color(1, 1, 1), cursor_tex, L_CURSOR, false)
	_quad(main_vp, Vector3(0.62, -1.6, -1.16), Vector2(0.3, 0.3), Color(1, 0.5, 0.65), cursor_tex, L_CURSOR, false)

	# hit effect sparkle
	_quad(main_vp, Vector3(2.25, -1.1, -1.1), Vector2(0.5, 0.5), Color(1, 0.85, 0.4), null, L_WORLD, false)

func _process(delta):
	if not visible:
		return
	for n in notes:
		n.translation.z += delta * 1.35
		if n.translation.z > -1.4:
			n.translation.z = -8.2
	# keep the note colors in sync with the selected colorset
	var cset = Rhythia.get("selected_colorset")
	if cset and cset.get("colors") and cset.colors.size() > 0:
		var col: Color = cset.colors[cset.colors.size() - 1]
		for n in notes:
			n.material_override.albedo_color = col
	if bloom_mat == null:
		return
	bloom_mat.set_shader_param("bloom_texel", Vector2(1.0 / 275.0, 1.0 / 155.0))
	bloom_mat.set_shader_param("bloom_threshold", Rhythia.bloom_threshold)
	bloom_mat.set_shader_param("bloom_saturation", Rhythia.bloom_saturation)
	bloom_mat.set_shader_param("notes_tex", aux["notes"]["vp"].get_texture())
	bloom_mat.set_shader_param("notes_strength", Rhythia.bloom_notes_strength)
	bloom_mat.set_shader_param("notes_radius", Rhythia.bloom_notes_radius)
	bloom_mat.set_shader_param("cursor_tex", aux["cursor"]["vp"].get_texture())
	bloom_mat.set_shader_param("cursor_strength", Rhythia.bloom_cursor_strength)
	bloom_mat.set_shader_param("cursor_radius", Rhythia.bloom_cursor_radius)
	bloom_mat.set_shader_param("border_tex", aux["border"]["vp"].get_texture())
	bloom_mat.set_shader_param("border_strength", Rhythia.bloom_border_strength)
	bloom_mat.set_shader_param("border_radius", Rhythia.bloom_border_radius)
	bloom_mat.set_shader_param("background_tex", aux["background"]["vp"].get_texture())
	bloom_mat.set_shader_param("background_strength", Rhythia.bloom_background_strength)
	bloom_mat.set_shader_param("background_radius", Rhythia.bloom_background_radius)
	bloom_mat.set_shader_param("world_tex", aux["world"]["vp"].get_texture())
	bloom_mat.set_shader_param("world_strength", Rhythia.bloom_world_strength)
	bloom_mat.set_shader_param("world_radius", Rhythia.bloom_world_radius)
