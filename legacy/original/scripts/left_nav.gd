extends TextureButton
var tmp_left

func _ready():
	connect("pressed", self , "_on_pressed")
	pass

func _on_pressed():
	tmp_left = get_node("../").get("temp")
	get_node("../").set("temp", tmp_left-1)
