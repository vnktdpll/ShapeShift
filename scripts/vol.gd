extends TextureButton


func _ready():
	connect("pressed", self , "_on_pressed")
	pass

func _on_pressed():
	globals.save1(1)
	Audio_player.stop_all()
	hide()
	get_node("../mute").show()
	pass


