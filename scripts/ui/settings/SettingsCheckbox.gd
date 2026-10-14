extends CheckBox

export (String) var target

func upd():

	pressed = Rhythia.get(target)

func _pressed():
	

	if pressed != Rhythia.get(target):
		Rhythia.set(target, pressed)

		if target == "enable_oldmenu":
			Globals.confirm_prompt.open(
				"You must restart for the changes to take effect", 
				"Notice", 
				[{text = "Quit"}]
			)
			Globals.confirm_prompt.s_alert.play()
			var option = yield(Globals.confirm_prompt, "option_selected")
			Globals.confirm_prompt.close()
			Globals.confirm_prompt.s_next.play()
			Rhythia.save_settings()
			get_tree().quit()


func _ready():
	upd()
