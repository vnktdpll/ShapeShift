extends TextureButton

func _ready():
	connect("pressed", self , "_on_pressed")
	pass

func _on_pressed():
	get_node("../../shapeshift").show()
	get_node("../../tap").show()
	get_node("../../tap_button").show()
	if(globals.read_savemusic()==0):
		get_node("../../vol").show()
	elif(globals.read_savemusic()==1):
		get_node("../../mute").show()
	get_node("../../info").show()
	get_node("../").hide()
