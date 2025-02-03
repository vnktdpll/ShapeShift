extends Container
var temp=0


func _ready():
	set_fixed_process(true)
	pass

func _fixed_process(delta):
	if(temp==0):
		get_node("Right_nav").show()
		get_node("Left_nav").hide()
		get_node("Objective").show()
		get_node("info_pic").hide()
		get_node("info_pic1").hide()
		get_node("info_pic2").hide()
		get_node("info_pic3").hide()
	elif(temp==1):
		get_node("Right_nav").show()
		get_node("Left_nav").show()
		get_node("info_pic").show()
		get_node("Objective").hide()
		get_node("info_pic1").hide()
		get_node("info_pic2").hide()
		get_node("info_pic3").hide()
	elif(temp==2):
		get_node("Right_nav").show()
		get_node("Left_nav").show()
		get_node("info_pic1").show()
		get_node("Objective").hide()
		get_node("info_pic").hide()
		get_node("info_pic2").hide()
		get_node("info_pic3").hide()
	elif(temp==3):
		get_node("Right_nav").show()
		get_node("info_pic2").show()
		get_node("Objective").hide()
		get_node("info_pic").hide()
		get_node("info_pic1").hide()
		get_node("info_pic3").hide()
	elif(temp==4):
		get_node("Left_nav").show()
		get_node("info_pic3").show()
		get_node("Objective").hide()
		get_node("info_pic").hide()
		get_node("info_pic1").hide()
		get_node("info_pic2").hide()
		get_node("Right_nav").hide()
