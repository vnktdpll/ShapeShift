extends TextureButton


func _ready():
	connect("pressed", self , "_on_pressed")
	pass

func _on_pressed():
	get_tree().set_pause(false)
	get_node("../../../").set("count", 0)
	globals.set("presssed_menu", 1)
	globals.nextscene("res://scenes/game.tscn")
