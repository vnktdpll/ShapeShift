extends TextureButton



func _ready():
	connect("pressed", self , "_on_pressed")
	pass

func _on_pressed():
	get_node("../shapeshift").hide()
	get_node("../tap").hide()
	get_node("../tap_button").hide()
	get_node("../vol").hide()
	get_node("../mute").hide()
	hide()
	get_node("../Info_container").show()
