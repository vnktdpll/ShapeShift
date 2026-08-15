extends TextureButton


func _ready():
	connect("pressed", self , "_on_pressed")
	pass

func _on_pressed():
	OS.shell_open("https://play.google.com/store/apps/details?id=com.vinstudios.shapeshift")