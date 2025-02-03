extends TextureButton


func _ready():
	connect("pressed", self , "_on_pressed")
	pass

func _on_pressed():
	get_tree().set_pause(false)
	hide()
	get_node("../pause").show()
	get_node("../TextureFrame1").hide()
