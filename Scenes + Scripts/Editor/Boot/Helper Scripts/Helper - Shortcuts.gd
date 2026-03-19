extends HBoxContainer

@export var main_script: Control


func Call_Open_UserData():
	var dir = ProjectSettings.globalize_path("user://Project Data")
	OS.shell_open(dir)
	print("Opened user data folder.")

func Call_Select_Embeded_Level():
	print("Called Embeded Level Loader")
	get_tree().change_scene_to_file("res://Scenes + Scripts/Editor/Built In/Built In Level Loader.tscn")

func Call_Open_Settings():
	if not main_script: print_rich("[color=red]Helper - Shortcuts: Error finding main_script"); return
	
	print("Settings opened.")
	pass
