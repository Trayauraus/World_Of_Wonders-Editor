##Global - Projects.gd
extends Node

@export var trigger_save: bool = false:
	set(value):
		# This code runs the moment you click the box in the Inspector
		Call_Project_Save("Manual_Test_Save")
		print("Save triggered from Inspector!")


var player_spawn: Vector2 = Vector2.ZERO

#region ---Project Arrays---

var carrot_locations: Array[CarrotUpgradeData]

var winzone_location: Array[WinzoneData]
var deathzone_locations: Array[DeathzoneData]

var custom_environment = 0

var custom_environment_call_change_zone: Array[EnvironmentChangeZoneData]

# CHANGED: Use highly efficient PackedByteArray instead of Array[TileDataResource]
var tilemap_array_main: PackedByteArray
var tilemap_array_bg: PackedByteArray

#endregion


#region Editor Data
var selected_tile_atlas_coords = Vector2i(-1, -1)


signal hide_bg_tiles_changed(new_value: bool)
var show_background: bool = false
var hide_bg_tiles: bool = false:
	set(value):
		if hide_bg_tiles != value: # Only trigger if the value actually changed
			hide_bg_tiles = value
			hide_bg_tiles_changed.emit(hide_bg_tiles)

signal show_env_changed(new_value: bool)
var show_env: bool = true:
	set(value):
		if show_env != value: # Only trigger if the value actually changed
			show_env = value
			show_env_changed.emit(show_env)

var show_collision: bool = false

var is_loading_embeded = false
#endregion

func Call_Reset_Variables(include_editor_var = true):
	player_spawn = Vector2.ZERO
	carrot_locations.clear()
	winzone_location.clear()
	deathzone_locations.clear()
	custom_environment = 0
	custom_environment_call_change_zone.clear()
	tilemap_array_main.clear()
	tilemap_array_bg.clear()
	
	if include_editor_var:
		GlobalEditor.project_name = ""
		GlobalEditor.project_name_normalized = ""
		GlobalEditor.can_edit_viewport = true
		GlobalEditor.selected_tool_id = 0
	print_rich("Global(s): Temp Data [color=orange]Reset")

##Saves project data in current state.
func Call_Project_Save(project_name_normalized: String = GlobalEditor.project_name_normalized) -> void:
	var folder_path = GlobalEditor.project_data_folder.path_join(project_name_normalized)
	DirAccess.make_dir_recursive_absolute(folder_path)
	
	# --- SAVE MAIN PROJECT DATA ---
	var save_path = folder_path.path_join(GlobalEditor.project_data)
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	
	if file:
		var data_to_save = {
			"project_name": GlobalEditor.project_name, 
			"project_version": ProjectSettings.get_setting("application/config/version"),
			"godot_version": Engine.get_version_info(),
			"time_when_saved": Time.get_date_string_from_system() if not OS.has_feature("editor") else 0,
			"last_device_processor": OS.get_processor_name() if not OS.has_feature("editor") else "",
			"last_screen_count": DisplayServer.get_screen_count() if not OS.has_feature("editor") else 0,
			"language": OS.get_locale() if not OS.has_feature("editor") else "",
			"player_spawn": player_spawn,
			"carrot_locations": carrot_locations,
			"winzone_location": winzone_location,
			"deathzone_locations": deathzone_locations,
			"custom_environment": custom_environment,
			"custom_environment_call_change_zone": custom_environment_call_change_zone
		}
		
		file.store_var(data_to_save, true)
		file.close()
		print_rich("Project data saved to: ", save_path, "   under the name: [color=orange]", GlobalEditor.project_name)
	else:
		push_error("Failed to save project data. Error code: ", FileAccess.get_open_error())

	# --- SAVE MAIN TILEMAP ---
	var main_tiles_path = folder_path.path_join(GlobalEditor.tiles_main_sav)
	var main_file = FileAccess.open(main_tiles_path, FileAccess.WRITE)
	if main_file:
		# Godot saves PackedByteArrays extremely efficiently natively
		main_file.store_var(tilemap_array_main, true)
		main_file.close()
		print("Main Tilemap saved to: ", main_tiles_path)
	else:
		push_error("Failed to save Main Tilemap. Error code: ", FileAccess.get_open_error())

	# --- SAVE BACKGROUND TILEMAP ---
	var bg_tiles_path = folder_path.path_join(GlobalEditor.tiles_bg_sav)
	var bg_file = FileAccess.open(bg_tiles_path, FileAccess.WRITE)
	if bg_file:
		bg_file.store_var(tilemap_array_bg, true)
		bg_file.close()
		print("Background Tilemap saved to: ", bg_tiles_path)
	else:
		push_error("Failed to save Background Tilemap. Error code: ", FileAccess.get_open_error())


func Call_Project_Load(project_name_normalized: String, include_tilemaps = true, replace_projectname_with_embeded = true) -> void:
	var folder_path = GlobalEditor.project_data_folder.path_join(project_name_normalized)
	
	if is_loading_embeded:
		folder_path = folder_path.replace(GlobalEditor.project_data_folder, GlobalEditor.embeded_level_folder)
		print_rich("[color=cyan]EMBEDDED LOAD ACTIVE:[/color] Path redirected to res://")
	
	# --- LOAD MAIN PROJECT DATA ---
	var load_path = folder_path.path_join(GlobalEditor.project_data)
	print_rich("[color=orange]Loading from folder: ", folder_path)
	
	if not FileAccess.file_exists(load_path):
		push_warning("No save file found at: ", load_path)
	else:
		var file = FileAccess.open(load_path, FileAccess.READ)
		if file:
			var loaded_data = file.get_var(true)
			file.close()
			
			if typeof(loaded_data) == TYPE_DICTIONARY:
				var saved_version = loaded_data.get("godot_version", {})
				print_rich("Loading level built in [color=STEEL_BLUE]Godot version: ", saved_version.get("string", "Unknown"))
				
				if replace_projectname_with_embeded:
					GlobalEditor.project_name = loaded_data.get("project_name", GlobalEditor.project_name)
				player_spawn = loaded_data.get("player_spawn", Vector2.ZERO)
				
				var loaded_carrots: Array[CarrotUpgradeData] = []
				loaded_carrots.assign(loaded_data.get("carrot_locations", []))
				carrot_locations = loaded_carrots
				
				var loaded_winzones: Array[WinzoneData] = []
				loaded_winzones.assign(loaded_data.get("winzone_location", []))
				winzone_location = loaded_winzones
				
				var loaded_deathzones: Array[DeathzoneData] = []
				loaded_deathzones.assign(loaded_data.get("deathzone_locations", []))
				deathzone_locations = loaded_deathzones
				
				custom_environment = loaded_data.get("custom_environment", 0)
				
				var loaded_env_zones: Array[EnvironmentChangeZoneData] = []
				loaded_env_zones.assign(loaded_data.get("custom_environment_call_change_zone", []))
				custom_environment_call_change_zone = loaded_env_zones
				print_rich("Level basic data loaded [color=lime]successfully!")
			else:
				push_error("Save file corrupted or invalid format.")
		else:
			push_error("Failed to load project file. Error code: ", FileAccess.get_open_error())

	if include_tilemaps:
		# --- LOAD MAIN TILEMAP ---
		var main_tiles_path = folder_path.path_join(GlobalEditor.tiles_main_sav)
		if FileAccess.file_exists(main_tiles_path):
			var main_file = FileAccess.open(main_tiles_path, FileAccess.READ)
			if main_file:
				var raw_data = main_file.get_var(true) 
				# CHANGED: Check for TYPE_PACKED_BYTE_ARRAY
				if typeof(raw_data) == TYPE_PACKED_BYTE_ARRAY:
					tilemap_array_main = raw_data
					print_rich("Main Tilemap loaded [color=lime]successfully!")
				else:
					push_error("Main Tilemap save file is incompatible or corrupted. Starting fresh.")
					tilemap_array_main.clear()
				main_file.close()
		else:
			print_rich("[color=yellow]No Main Tilemap file found. [/color]Starting fresh.")
			tilemap_array_main.clear()

		# --- LOAD BACKGROUND TILEMAP ---
		var bg_tiles_path = folder_path.path_join(GlobalEditor.tiles_bg_sav)
		if FileAccess.file_exists(bg_tiles_path):
			var bg_file = FileAccess.open(bg_tiles_path, FileAccess.READ)
			if bg_file:
				var raw_data = bg_file.get_var(true)
				if typeof(raw_data) == TYPE_PACKED_BYTE_ARRAY:
					tilemap_array_bg = raw_data
					print_rich("Background Tilemap loaded [color=lime]successfully!")
				else:
					push_error("Background Tilemap save file is incompatible or corrupted. Starting fresh.")
					tilemap_array_bg.clear()
				bg_file.close()
		else:
			print_rich("[color=yellow]No Background Tilemap file found. [/color] Starting fresh.")
			tilemap_array_bg.clear()

# CHANGED: Gets the pure binary data natively from Godot (instantly fast)
func Call_Save_TileMapLayer_As_Array(layer_node: TileMapLayer, is_main_tilemap: bool = true) -> PackedByteArray:
	var data_array: PackedByteArray = layer_node.get_tile_map_data_as_array()
	
	if is_main_tilemap:
		tilemap_array_main = data_array
	else:
		tilemap_array_bg = data_array
	
	print("Saved Tilemap Data for: ", "Main" if is_main_tilemap else "Background")
	return data_array

# CHANGED: Loads the pure binary data natively back into the map
func Call_Load_TileMapLayer_Data(layer_node: TileMapLayer, data_array: PackedByteArray):
	layer_node.clear()
	if not data_array.is_empty():
		layer_node.set_tile_map_data_from_array(data_array)

## Exports the entire project to a single .wowlv file for easy sharing
func Call_Export(project_name_normalized: String = GlobalEditor.project_name_normalized) -> void:
	var base_export_dir: String
	
	if OS.has_feature("editor"):
		base_export_dir = ProjectSettings.globalize_path("user://Export")
	else:
		base_export_dir = OS.get_executable_path().get_base_dir().path_join("WoW Exports")
		
	var export_folder = base_export_dir.path_join(project_name_normalized)
	DirAccess.make_dir_recursive_absolute(export_folder)
	
	var path = project_name_normalized if project_name_normalized != "" else "Default_Name"
	var export_file_path = export_folder.path_join(path + ".wowlv")
	
	# CHANGED: No need to pack tiles manually anymore, just use the PackedByteArrays directly
	var export_data = {
		"project_name": GlobalEditor.project_name, 
		"project_version": ProjectSettings.get_setting("application/config/version"),
		"godot_version": Engine.get_version_info(),
		"time_when_saved": Time.get_date_string_from_system(),
		"player_spawn": player_spawn,
		"carrot_locations": carrot_locations,
		"winzone_location": winzone_location,
		"deathzone_locations": deathzone_locations,
		"custom_environment": custom_environment,
		"custom_environment_call_change_zone": custom_environment_call_change_zone,
		"tilemap_array_main_packed": tilemap_array_main, # Just pass them directly
		"tilemap_array_bg_packed": tilemap_array_bg      # ZSTD will compress these incredibly well
	}
	
	var file = FileAccess.open_compressed(export_file_path, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if file:
		file.store_var(export_data, true)
		file.close()
		print_rich("Project [color=green]successfully[/color] exported as a tiny compressed binary file to: [color=orange]", export_file_path)
		if not OS.has_feature("android"):
			if DisplayServer.clipboard_has():
				var clipboard_text = DisplayServer.clipboard_get()
				if clipboard_text != export_file_path: DisplayServer.clipboard_set(export_file_path)
			else: DisplayServer.clipboard_set(export_file_path) 
			OS.shell_open("file://" + export_file_path.get_base_dir())
			DisplayServer.window_request_attention()
	else:
		push_error("Failed to export project. Error code: ", FileAccess.get_open_error())
