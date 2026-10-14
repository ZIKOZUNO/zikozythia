extends Button








func _ready():
	connect("pressed", self, "_button_pressed")

func _button_pressed():
	OS.shell_open("https://www.github.com/Rhythia/Client/releases/latest")





