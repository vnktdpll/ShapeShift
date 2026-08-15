extends TextureButton


func _ready():
	connect("pressed", self , "_on_pressed")
	pass

func _on_pressed():
	globals.save1(0)
	Audio_player.play("background", 2)
	get_node("../Timer 2").start()
	
	hide()
	get_node("../vol").show()
	pass

func _on_Timer_2_timeout():
	if(globals.read_savemusic()==0):
		Audio_player.play("background", 2)
	pass # replace with function body
