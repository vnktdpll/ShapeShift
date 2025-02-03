extends Area2D
var shape=0
var score=0
var admob = null;
var admob_banner_id = "ca-app-pub-7852587909798327/1436601725"
var admob_interstitial_id = "ca-app-pub-7852587909798327/7479265893"

func _ready():
	set_fixed_process(true)
	connect("area_enter", self , "_on_area_enter")
	if(Globals.has_singleton("bbAdmob")):
		admob = Globals.get_singleton("bbAdmob")
		#You can call admob.init_admob_test or admob.init_admob_real
		#If the last argument is true, the banner ad will be at the top of the screen
		#Function prototype init_admob_banner_test(int instance_id, string app_banner_id, string app_interstitial_id, boolean isTop)
		admob.init_admob_test(get_instance_ID(), admob_banner_id, admob_interstitial_id, true)
	pass
func _input(event):
	pass

func _fixed_process(delta):
	if Input.is_action_pressed("ui_left"):
		set_pos(Vector2(120,840))
	elif Input.is_action_pressed("ui_right"):
		set_pos(Vector2(600,840))
	else:
		set_pos(Vector2(360,840))
	if Input.is_action_pressed("ui_up"):
		get_node("AnimatedSprite").set_animation("triangle")
		shape=1
	elif Input.is_action_pressed("ui_down"):
		get_node("AnimatedSprite").set_animation("circle")
		shape=2
	else:
		get_node("AnimatedSprite").set_animation("square")
		shape=0
	if(get_node("../").get("count")==1):
		get_tree().set_pause(true)
func _on_area_enter(other):
	if other.is_in_group("path"):
		if(other.get("pick")==shape):
			score=score+1
			if(globals.read_savemusic()==0):
				Audio_player.play("371274__mafon2__water-click")
			get_node("../CanvasLayer/UI/score").set_text(str(score))
		elif(other.get("pick")!=shape):
			if(globals.read_savemusic()==0):
				Audio_player.stop_all()
				Audio_player.play("fail")
			banner_ad()
			interstitial_ad()
			if(score>globals.read_savegame()):
				get_node("../CanvasLayer/new_best").show()
				Audio_player.play("high_score")
				get_node("../CanvasLayer/AnimationPlayer").play("new_best")
				globals.save(score)
			get_node("../Background1").set("layer", 1)
			get_node("../CanvasLayer/game_over_menu/score/score_game_menu").set_text(str(score))
			get_node("../CanvasLayer/game_over_menu/best/best_game_menu").set_text(str(globals.read_savegame()))
			get_node("..").set("count",1)
			get_tree().set_pause(true)
			get_node("../CanvasLayer/UI").hide()
			get_node("../CanvasLayer/game_over_menu").show()
			hide()
			
		other.queue_free()

func banner_ad():
	if admob != null:
		admob.show_banner()
		
func interstitial_ad():
	if admob != null:
		admob.show_interstitial()





