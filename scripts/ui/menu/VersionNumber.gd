extends Label

func _ready():
	text = "Zikozythia [%s]" % ProjectSettings.get_setting("application/config/version")
	add_color_override("font_color", Color(0.95, 0.1, 0.15, 1))
