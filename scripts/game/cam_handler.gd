extends Spatial

var state = (Rhythia.replaying and Rhythia.alt_cam)
var debug: bool = OS.has_feature("debug")

func _ready():
	PhysicsServer.set_active( not Rhythia.visual_mode and (Rhythia.get("cam_unlock") or Rhythia.vr))
	
	
	if state:
		$Camera.current = false
		$AltCam.current = true
		$AltCam.set_enabled(true)
		$Game / Avatar.visible = true
		$Game / Avatar / Animations.play("Idle")
		$Game / Avatar / Head / Blinking.play("Blink")
	else:
		$AltCam.set_enabled(false)
		$Game / Avatar.visible = false
		$Camera.current = true
		$AltCam.current = false
	
	if Rhythia.mod_flashlight:
		$Game / Mask.visible = true
	else:
		$Game / Mask.visible = false
	
	
	if Rhythia.is_lacunella_enabled():
		$Game / Avatar / Head / Accessories / CubellaHair.visible = true

	
	if Rhythia.vhs_shader:
		$Camera / VHS.visible = true
		$AltCam / VHS.visible = true
	else:
		$Camera / VHS.visible = false
		$AltCam / VHS.visible = false

	# Zikozythia: CapoRhythia-style layered bloom (params handled by BloomRig)
	if Rhythia.bloom_shader:
		$Camera / Bloom.visible = true
		$AltCam / Bloom.visible = true
	else:
		$Camera / Bloom.visible = false
		$AltCam / Bloom.visible = false

func _process(delta):
	if Input.is_action_just_pressed("debug_freecam_toggle") and debug:
		state = not state
		_ready()
	if Input.is_action_just_pressed("retry"):
		get_tree().reload_current_scene()
