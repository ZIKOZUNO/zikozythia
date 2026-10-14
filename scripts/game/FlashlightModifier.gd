extends Spatial

export var lspd = 0.025
var target: Vector3
var tps: float
var top: float
onready var Game: SongPlayerManager = $".."

func _process(delta):
	
	
	target = Vector3(
		$"../Spawn/Cursor/Mesh".global_translation.x, 
		$"../Spawn/Cursor/Mesh".global_translation.y, 
		- 0.1
	)
	if Rhythia.get("cam_unlock") == true:
		if Game.combo >= 100:
			
			tps = 0.05
			top = 1
		elif Game.combo >= 50:
			
			tps = 0.055
			top = 1
		else:
			
			tps = 0.06
			top = 1
	else:
		if Game.combo >= 100:
			
			tps = 0.025
			top = 1
		elif Game.combo >= 50:
			
			tps = 0.03
			top = 1
		else:
			
			tps = 0.04
			top = 1
	
	
	global_translation = lerp(global_translation, target, lspd * 40)
	$Sprite.pixel_size = lerp($Sprite.pixel_size, tps, lspd / 2)
	$Sprite.opacity = lerp($Sprite.opacity, top, lspd / 2)
	
