extends ColorRect

onready var languageselect = $ChangeLanguage / SelectLanguageWindow / languageselector










func _ready():
	
	add_items()
	languageselect.selected = Rhythia.language

func add_items():
	languageselect.add_item("ENGLISH")
	languageselect.add_item("JAPANESE")
	languageselect.add_item("FRENCH")
	languageselect.add_item("SPANISH")
	languageselect.add_item("ITALIAN")
	languageselect.add_item("POLISH")

func _on_languageselector_item_selected(index):
	Rhythia.language = index
	TranslationServer.set_locale(Globals.locale[Rhythia.language])
