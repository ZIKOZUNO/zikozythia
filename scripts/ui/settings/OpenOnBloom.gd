extends TabContainer

# Zikozythia: settings open directly on the Bloom tab so the live
# preview is visible immediately.

func _ready():
	for i in range(get_tab_count()):
		var c = get_tab_control(i)
		if c and c.name == "Bloom":
			current_tab = i
			break
