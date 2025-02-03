extends Node



func _ready():
	get_node("AnimationPlayer").play("loading")
	pass # replace with function body

func _on_Timer_timeout():
	get_node("info").show()
	if(globals.read_savemusic()==0):
		get_node("vol").show()
	elif(globals.read_savemusic()==1):
		get_node("mute").show()
	pass # replace with function body
