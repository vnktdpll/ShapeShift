extends Node2D
var path
var menu
var count=0
var color
var vel=300
var admob = null;
var admob_banner_id = "ca-app-pub-7852587909798327/1436601725"
var admob_interstitial_id = "ca-app-pub-7852587909798327/7479265893"
onready var path_res = preload("res://scenes/Path.tscn")
onready var menu_res = preload("res://scenes/loading_menu.tscn")
func _ready():
	set_fixed_process(true)
	if(globals.read_savemusic()==0):
		Audio_player.play("background", 2)
		get_node("Timer 2").start()
	randomize()
	color=randi()%8
	if(color==0):
		get_node("Background1/Background").set_animation("blue")
	elif(color==1):
		get_node("Background1/Background").set_animation("green")
	elif(color==2):
		get_node("Background1/Background").set_animation("yellow")
	elif(color==3):
		get_node("Background1/Background").set_animation("bottle_green")
	elif(color==4):
		get_node("Background1/Background").set_animation("light_blue")
	elif(color==5):
		get_node("Background1/Background").set_animation("light_green")
	elif(color==6):
		get_node("Background1/Background").set_animation("pink")
	elif(color==7):
		get_node("Background1/Background").set_animation("saffron")
	if(globals.pressed_play_again==0):
		menu = menu_res.instance()
		add_child(menu)
		if(Globals.has_singleton("bbAdmob")):
			admob = Globals.get_singleton("bbAdmob")
			#You can call admob.init_admob_test or admob.init_admob_real
			#If the last argument is true, the banner ad will be at the top of the screen
			#Function prototype init_admob_banner_test(int instance_id, string app_banner_id, string app_interstitial_id, boolean isTop)
			admob.init_admob_test(get_instance_ID(), admob_banner_id, admob_interstitial_id, false)
			
func _fixed_process(delta):
	if(globals.pressed_play == 1):
		show()
		get_node("CanvasLayer/UI").show()
		on_click_play()
	if(globals.read_savemusic()==1):
		Audio_player.stop_all()
	

func on_click_play():
	path=path_res.instance()
	add_child(path)
	path.set("velocity",Vector2(0,vel))
	globals.set("pressed_play" , 0)
	
func _on_Timer_timeout():
	vel=vel+5
	if(vel%2==0 && vel>=900):
		get_node("Timer").set_wait_time(get_node("Timer").get_wait_time()+1)
	pass


func _on_Area2D_area_enter( area ):
	if(count==0):
		path=path_res.instance()
		add_child(path)
		path.set("velocity",Vector2(0,vel))

	

func _on_Area2D1_area_enter( area ):
	banner_ad()
	interstitial_ad()
	count=1
	if(globals.read_savemusic()==0):
		Audio_player.stop_all()
		Audio_player.play("fail")
	if(get_node("player").get("score")>globals.read_savegame()):
		get_node("CanvasLayer/new_best").show()
		get_node("CanvasLayer/AnimationPlayer").play("new_best")
		if(globals.read_savemusic()==0):
			Audio_player.play("high_score")
		globals.save(get_node("player").get("score"))
	get_node("Background1").set("layer", 1)
	get_node("CanvasLayer/game_over_menu/score/score_game_menu").set_text(str(get_node("player").get("score")))
	get_node("CanvasLayer/game_over_menu/best/best_game_menu").set_text(str(globals.read_savegame()))
	get_node("CanvasLayer/UI").hide()
	get_node("CanvasLayer/game_over_menu").show()
	get_node("player").hide()
	
	
	
func _on_sq_area_area_enter( area ):
	if(path.get("pick")!=0):
			count=0


func _on_tri_area_area_enter( area ):
	if(path.get("pick")!=1):
		count=0


func _on_cir_area_area_enter( area ):
	if(path.get("pick")!=2):
		count=0
		

func queuefree():
	path.queue_free()

func banner_ad():
	if admob != null:
		admob.show_banner()
		
func interstitial_ad():
	if admob != null:
		admob.show_interstitial()



func _on_Timer_2_timeout():
	if(globals.read_savemusic()==0):
		Audio_player.play("background", 2)
	pass # replace with function body


