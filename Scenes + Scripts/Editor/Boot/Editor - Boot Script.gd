extends Control

@export var ball: Ball2D
@export var player: Bunny

@onready var slider: AnimationPlayer = $"Open Project/Slider"

var can_open_projects = true
var temp_name_hold = ""

func _ready():
	OS.set_low_processor_usage_mode(true)
	GlobalProject.is_loading_embeded = false
	GlobalEditor.Call_Config_Load()
	
	create_project_folder()
	create_config_directory()
	await get_tree().process_frame
	create_recent_project_list()

func  create_project_folder():
	var folder_path = GlobalEditor.project_data_folder
	var dir = DirAccess.open("user://")
	
	if not dir.dir_exists(folder_path):
		var error = dir.make_dir_recursive(folder_path)
		if error == OK:
			print("Created folder: ", folder_path)
		else:
			push_error("Failed to create folder. Error code: ", error)
	else:
		print_rich("Folder [color=yellow]already exists: [/color]", folder_path)

func create_config_directory():
	var target_path = GlobalEditor.editor_settings_folder
	
	if not DirAccess.dir_exists_absolute(target_path):
		var error = DirAccess.make_dir_recursive_absolute(target_path)
		if error == OK:
			print("Directory created.")
			create_empty_config_file()
		else:
			push_error("Failed to create directory.")
			GlobalEditor.config = null # Precautionary null
	else:
		create_empty_config_file()

func create_empty_config_file():
	var file_path = GlobalEditor.editor_settings_folder + "config.ini"
	var config = ConfigFile.new()
	
	# 1. Try to load the file if it exists, or just keep the empty object if not
	if FileAccess.file_exists(file_path):
		var error = config.load(file_path)
		if error == OK:
			GlobalEditor.config = config
			print("Config linked successfully.")
		else:
			push_error("Failed to load existing config.")
			GlobalEditor.config = null
	else:
		# 2. File doesn't exist, so we save the new one and then link it
		var error = config.save(file_path)
		if error == OK:
			GlobalEditor.config = config
			print("Empty config.ini created and linked at: ", file_path)
		else:
			push_error("Failed to save config file. Error: ", error)
			GlobalEditor.config = null

# UPDATED: Pulls and casts our saved ProjectMetaData resources from the config
func create_recent_project_list():
	var saved_recent = GlobalEditor.Get_Config_Variable("Editor", "recently_opened", [])
	var typed_recent: Array[ProjectMetaData] = []
	
	for item in saved_recent:
		if item is ProjectMetaData:
			typed_recent.append(item)
			
	GlobalEditor.recently_opened = typed_recent


func Game_Wiki_Pressed():
	OS.shell_open(GlobalEditor.wiki_loc)

func Call_Player():
	$Playable/JumpAnimation.play("Jump Up")

func Hide_Initial():
	if can_open_projects:
		$Content/Projects.hide(); player.hide(); $"Open Project".show(); slider.play("Slide_In")
		can_open_projects = false

func Show_Initial():
	$Content/Projects.show(); player.show(); slider.play("Slide_Out")
	can_open_projects = true

func Animation_Finished(anim_name: StringName):
	if anim_name == "Slide_Out":
		$"Open Project".hide()

func Open_Project_Button_Pressed():
	Hide_Initial()

func New_Project_Button_Pressed():
	$"Project Conf".show()


##New Project Line Edit
func _on_line_edit_text_changed(new_text: String) -> void:
	temp_name_hold = new_text


##New Project Confirm Dialogue
func _on_confirmation_dialog_confirmed() -> void:
	GlobalProject.Call_Reset_Variables(false)
	GlobalEditor.project_name = temp_name_hold
	print_rich("[color=DARK_SLATE_GRAY]Saved Project Name as [color=DARK_OLIVE_GREEN]", GlobalEditor.project_name)
	GlobalEditor.project_name_normalized = get_safe_filename(GlobalEditor.project_name)
	if OS.has_feature("editor"):
		print_rich("Saved Normalized Project Name as [color=green]", GlobalEditor.project_name_normalized)
	
	# --- RECENT PROJECTS SAVE LOGIC ---
	var new_meta = ProjectMetaData.new()
	new_meta.project_name = GlobalEditor.project_name
	
	# Format date as mm/dd/yy
	var date = Time.get_datetime_dict_from_system()
	var year_str = str(date["year"])
	var year_short = year_str.substr(year_str.length() - 2, 2)
	new_meta.creation_date = "%02d/%02d/%s" % [date["month"], date["day"], year_short]
	
	# Format Godot version
	var v_info = Engine.get_version_info()
	new_meta.godot_version = "%d.%d.%d" % [v_info.major, v_info.minor, v_info.patch]
	
	# Prevent duplicate project entries by removing older versions of the same name
	for i in range(GlobalEditor.recently_opened.size() - 1, -1, -1):
		if GlobalEditor.recently_opened[i].project_name == new_meta.project_name:
			GlobalEditor.recently_opened.remove_at(i)
	
	GlobalEditor.recently_opened.insert(0, new_meta) # Add to the top of the list
	
	if GlobalEditor.recently_opened.size() > 10: # Keep maximum limit to 10
		GlobalEditor.recently_opened.resize(10)
		
	# Store and save changes
	GlobalEditor.config.set_value("Editor", "recently_opened", GlobalEditor.recently_opened)
	GlobalEditor.Call_Config_Save()
	# ----------------------------------
	
	GlobalEditor.loading_scene_next_scene = "res://Scenes + Scripts/Editor/Main Editor.tscn"
	get_tree().change_scene_to_file("res://Scenes + Scripts/Editor/Loading/Editor Loading Scene.tscn")


func get_safe_filename(input_text: String) -> String:
	var regex = RegEx.new()
	# This pattern matches anything NOT in the sets: a-z, A-Z, 0-9, _, -
	# It effectively kills spaces and special Windows-forbidden characters.
	regex.compile("[^a-zA-Z0-9_-]") 
	
	var safe_name = regex.sub(input_text, "", true) # Replace matches with nothing
	return safe_name.strip_edges()
