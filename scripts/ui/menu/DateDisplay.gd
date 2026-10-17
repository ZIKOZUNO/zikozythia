extends Label

# Zikozythia: shows the current date in the top-right corner of the song
# select screen, right of the search bar - hidden while playing, in settings,
# or when disabled.

var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
var days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
var _last: String = ""

func _process(_d):
	var maps = get_node_or_null("../Main/Maps")
	visible = Rhythia.show_date and maps != null and maps.is_visible_in_tree()
	if not visible:
		return
	var dt = OS.get_datetime()
	var txt = "%s %d. %s %d" % [days[dt.weekday], dt.day, months[dt.month - 1], dt.year]
	if txt != _last:
		_last = txt
		text = txt
