extends TextureButton


func _ready():
	connect("pressed", self , "_on_pressed")
	pass

func _on_pressed():
	get_tree().set_pause(false)
	get_node("../../../").set("count", 0)
	globals.set("pressed_play_again", 1)
	globals.set("pressed_play", 1)
	#globals.nextscene("res://scenes/game.tscn")
	get_tree().reload_current_scene()
	