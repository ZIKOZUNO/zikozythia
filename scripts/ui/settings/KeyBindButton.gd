extends Button

# Zikozythia keybind capture button - click it, press any key, done.
# ESC cancels. The scancode is stored in Rhythia (target) and saved.

export (String) var target
export (String) var display

var listening: bool = false

func _ready():
	connect("pressed", self, "_on_pressed")
	_update_text()

func _on_pressed():
	listening = true
	text = display + ": press a key..."

func _input(ev):
	if not listening:
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.scancode != KEY_ESCAPE:
			Rhythia.set(target, int(ev.scancode))
			Rhythia.save_settings()
		listening = false
		_update_text()
		get_viewport().set_input_as_handled()

func _update_text():
	var name = OS.get_keycode_string(int(Rhythia.get(target)))
	if name == "":
		name = "?"
	text = display + ": " + name
