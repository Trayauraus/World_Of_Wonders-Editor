##Global - Editor.gd
extends Node

const wiki_loc = "https://trayauraus.github.io/World_Of_Wonders/"

var loading_scene_next_scene: String = ""

#region Project_Data
const project_data_folder = "user://Project Data"
const project_data = "project_data.dat"
const tiles_main_sav = "tileset_main.tlst"
const tiles_bg_sav = "tileset_bg.tlst"
#endregion

#region Editor Settings/Config
const editor_settings_folder = "user://Editor Data/Configs/"
var config: ConfigFile = null #For Editor Setting ONLY

# UPDATED: Now holds our new Custom Resource
var recently_opened: Array[ProjectMetaData] = []
#endregion

var intro_played = false

#region GameData
var project_name = ""
var project_name_normalized = ""

var can_edit_viewport = true
var selected_tool_id = 0
#endregion


## Loads the ConfigFile itself. Accepts the file name as an input parameter.
func Call_Config_Load(file_name: String = "config.ini") -> void:
	config = ConfigFile.new()
	var path = editor_settings_folder.path_join(file_name)
	
	var error = config.load(path)
	if error != OK:
		if error == ERR_FILE_NOT_FOUND:
			print("Config file '", file_name, "' not found. A new one will be created upon saving.")
		else:
			push_error("Failed to load config '", file_name, "'. Error code: ", error)


## Loads a specific variable/value from the loaded config.
func Get_Config_Variable(section: String, variable_name: String, default_value: Variant = null) -> Variant:
	# Failsafe: If config isn't loaded yet, load it
	if config == null:
		print("Config is not initialized! Loading default config.ini first...")
		Call_Config_Load("config.ini")
		
	return config.get_value(section, variable_name, default_value)


# Saves the ConfigFile. Now also accepts the file name as an input parameter for consistency.
func Call_Config_Save(file_name: String = "config.ini") -> void:
	if config != null:
		# Important: Godot will fail to save if the folder doesn't exist yet!
		if not DirAccess.dir_exists_absolute(editor_settings_folder):
			DirAccess.make_dir_recursive_absolute(editor_settings_folder)
			
		# Construct path safely using path_join
		var path = editor_settings_folder.path_join(file_name)
		
		var error = config.save(path)
		if error != OK:
			push_error("Failed to save config '", file_name, "'. Error code: ", error)
		else:
			print("Config saved successfully to: ", path)
	else:
		print("Config is not initialized! Nothing to save.")
