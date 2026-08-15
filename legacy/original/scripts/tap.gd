extends TextureButton


func _ready():
	connect("pressed", self , "_on_pressed")
	pass

func _on_pressed():
	get_node("../tap").hide()
	globals.set("pressed_play" ,1)
	get_node("../shapeshift").hide()
	get_node("../vol").hide()
	get_node("../mute").hide()
	get_node("../info").hide()
	
