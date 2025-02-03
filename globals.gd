extends Node
var savegame = File.new() #file
var save_path = "user://savegame.save" #place of the file
var save_data = {"highscore": 0} #variable to store data
var savemusic = File.new()
var save_path1 = "user://savemusic.save" #place of the file
var save_data1 = {"musicstate": 0}
var currentScene = null
var pressed_play = 0
var pressed_play_again = 0
var presssed_menu = 0
func _ready():
	if not savegame.file_exists(save_path):
		create_save()
	if not savemusic.file_exists(save_path1):
		create_save1()
	currentScene = get_tree().get_root().get_child(get_tree().get_root().get_child_count() -1)


func create_save():
	savegame.open(save_path, File.WRITE)
	savegame.store_var(save_data)
	savegame.close()

func save(high_score):
	save_data["highscore"] = high_score #data to save
	savegame.open(save_path, File.WRITE) #open file to write
	savegame.store_var(save_data) #store the data
	savegame.close() # close the file

func read_savegame():
	savegame.open(save_path, File.READ) #open the file
	save_data = savegame.get_var() #get the value
	savegame.close() #close the file
	return save_data["highscore"] #return the value

func create_save1():
	savemusic.open(save_path1, File.WRITE)
	savemusic.store_var(save_data1)
	savemusic.close()

func save1(music_state):
	save_data1["musicstate"] = music_state #data to save
	savemusic.open(save_path1, File.WRITE) #open file to write
	savemusic.store_var(save_data1) #store the data
	savemusic.close() # close the file

func read_savemusic():
	savemusic.open(save_path1, File.READ) #open the file
	save_data1 = savemusic.get_var() #get the value
	savemusic.close() #close the file
	return save_data1["musicstate"] #return the value

func nextscene(scene):
   #clean up the current scene
   currentScene.queue_free()
   #load the file passed in as the param "scene"
   var s = ResourceLoader.load(scene)
   #create an instance of our scene
   currentScene = s.instance()
   # add scene to root
   get_tree().get_root().add_child(currentScene)

