extends TextureButton
var tmp_right

func _ready():
	connect("pressed", self , "_on_pressed")
	pass

func _on_pressed():
	tmp_right = get_node("../").get("temp")
	get_node("../").set("temp", tmp_right+1)
