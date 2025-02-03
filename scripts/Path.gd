extends Area2D
var pick
var velocity = Vector2()
var pick1

func _ready():
	set_fixed_process(true)
	randomize()
	pick=randi()%3
	if(pick==0):
		get_node("AnimatedSprite").set_animation("square")
	elif(pick==1):
		get_node("AnimatedSprite").set_animation("triangle")
	elif(pick==2):
		get_node("AnimatedSprite").set_animation("circle")
	pick1=randi()%3
	if(pick1==0):
		set_pos(Vector2(120,-120))
	elif(pick1==1):
		set_pos(Vector2(360,-120))
	elif(pick1==2):
		set_pos(Vector2(600,-120))
	add_to_group("path")
	yield(get_node("vis_notif"), "exit_screen")
	queue_free()
	
	
func _fixed_process(delta):
	translate(velocity * delta)
	pass


