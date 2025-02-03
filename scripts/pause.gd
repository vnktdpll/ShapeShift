extends TextureButton


func _ready():
	connect("pressed", self , "_on_pressed")
	pass

func _on_pressed():
	get_tree().set_pause(true)
	get_node("../TextureFrame1").show()
	hide()
	get_node("../play").show()
	