#Called Via GlobalProject
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
var coin_locations: Array[CoinData]
var enemy_locations: Array[EnemyData]

var winzone_location: Array[WinzoneData]
var deathzone_locations: Array[DeathzoneData]
var carrot_remover_locations: Array[CarrotRemoverZoneData]

# NEW ARRAYS: Added missing cave, wind, and camera data arrays
var cave_locations: Array[CaveZoneData]
var wind_locations: Array[WindZoneData]
var camerazoom_locations: Array[CameraZoomZoneData]

var custom_environment = 0

var custom_environment_call_change_zone: Array[EnvironmentChangeZoneData]

# CHANGED: Use highly efficient PackedByteArray instead of Array[TileDataResource]
var tilemap_array_main: PackedByteArray
var tilemap_array_bg: PackedByteArray

#endregion

#region ---Project Variables---
var camera_zoom:= 2.4
var player_dashes: int = 2
var ice_physics: bool = false
var force_light: bool = false

#endregion

#region ---Project Custom Music---
# We store the raw binary data of the file so it's permanently embedded in the save/export
var custom_music_data: PackedByteArray
var custom_music_extension: String = ""
var custom_music_name: String = ""
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

#region Undo / Redo System
var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []
const MAX_UNDO_STEPS = 256

signal state_restored
#endregion

func Call_Reset_Variables(include_editor_var = true):
	player_spawn = Vector2.ZERO
	camera_zoom = 2.4
	player_dashes = 2
	ice_physics = false
	force_light = false
	
	carrot_locations.clear()
	coin_locations.clear()
	enemy_locations.clear()
	
	winzone_location.clear()
	deathzone_locations.clear()
	carrot_remover_locations.clear()
	cave_locations.clear()
	wind_locations.clear()
	camerazoom_locations.clear()
	
	custom_environment = 0
	custom_environment_call_change_zone.clear()
	tilemap_array_main.clear()
	tilemap_array_bg.clear()
	
	# Reset Music Data
	custom_music_data.clear()
	custom_music_extension = ""
	custom_music_name = ""
	
	# Reset Undo/Redo Stacks
	undo_stack.clear()
	redo_stack.clear()
	
	if include_editor_var:
		GlobalEditor.project_name = ""
		GlobalEditor.project_name_normalized = ""
		GlobalEditor.can_edit_viewport = true
		GlobalEditor.selected_tool_id = 0
	print_rich("Global(s): Temp Data [color=orange]Reset")

##Saves project data in current state.
func Call_Project_Save(project_name_normalized: String = GlobalEditor.project_name_normalized) -> void:
	var folder_path: String = ""
	
	# Differentiate Mobile Path vs PC/Editor Path
	if OS.has_feature("android") or OS.has_feature("ios"):
		# Ensure we ask for permissions to read/write external storage if on Android
		if OS.has_feature("android"):
			OS.request_permissions()
			
		var docs_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
		folder_path = docs_dir.path_join("WoW Projects").path_join(project_name_normalized)
	else:
		folder_path = GlobalEditor.project_data_folder.path_join(project_name_normalized)
		
	DirAccess.make_dir_recursive_absolute(folder_path)
	
	# --- SAVE MAIN PROJECT DATA ---
	var save_path = folder_path.path_join(GlobalEditor.project_data)
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	
	if file:
		var data_to_save = {
			#Misc
			"project_name": GlobalEditor.project_name, 
			"project_version": ProjectSettings.get_setting("application/config/version"),
			"godot_version": Engine.get_version_info(),
			"time_when_saved": Time.get_date_string_from_system() if not OS.has_feature("editor") else str("Editor Build"),
			"last_device_processor": OS.get_processor_name() if not OS.has_feature("editor") else "Editor Build",
			"last_screen_count": DisplayServer.get_screen_count() if not OS.has_feature("editor") else -1,
			"language": OS.get_locale() if not OS.has_feature("editor") else "Editor Build, English",
			
			# Arrays (CONVERTED TO DICTIONARIES FOR CROSS-PROJECT COMPATIBILITY)
			"player_spawn": player_spawn,
			"carrot_locations": _res_array_to_dict_array(carrot_locations),
			"coin_locations": _res_array_to_dict_array(coin_locations),
			"enemy_locations": _res_array_to_dict_array(enemy_locations),
			"winzone_location": _res_array_to_dict_array(winzone_location),
			"deathzone_locations": _res_array_to_dict_array(deathzone_locations),
			"carrot_remover_locations": _res_array_to_dict_array(carrot_remover_locations),
			"cave_locations": _res_array_to_dict_array(cave_locations),
			"wind_locations": _res_array_to_dict_array(wind_locations),
			"camerazoom_locations": _res_array_to_dict_array(camerazoom_locations),
			
			"custom_environment": custom_environment,
			"custom_environment_call_change_zone": _res_array_to_dict_array(custom_environment_call_change_zone),
			
			#Variables
			"camera_zoom": camera_zoom,
			"player_dashes": player_dashes,
			"ice_physics": ice_physics,
			"force_light": force_light,
			
			# Save Custom Music
			"custom_music_data": custom_music_data,
			"custom_music_extension": custom_music_extension,
			"custom_music_name": custom_music_name
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
	var folder_path: String = ""
	
	if is_loading_embeded:
		# Embedded levels remain packaged inside res://
		var base_path = GlobalEditor.project_data_folder.path_join(project_name_normalized)
		folder_path = base_path.replace(GlobalEditor.project_data_folder, GlobalEditor.embeded_level_folder)
		print_rich("[color=cyan]EMBEDDED LOAD ACTIVE:[/color] Path redirected to res://")
	else:
		# Differentiate Mobile Path vs PC/Editor Path for normal loading
		if OS.has_feature("android") or OS.has_feature("ios"):
			# Ensure permissions are checked on mobile load too
			if OS.has_feature("android"):
				OS.request_permissions()
				
			var docs_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
			folder_path = docs_dir.path_join("WoW Projects").path_join(project_name_normalized)
		else:
			folder_path = GlobalEditor.project_data_folder.path_join(project_name_normalized)
			
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
				
				##Arrays - Rebuilding Resources from Saved Dictionaries
				var loaded_carrots: Array[CarrotUpgradeData] = []
				loaded_carrots.assign(_dict_array_to_res_array(loaded_data.get("carrot_locations", []), CarrotUpgradeData))
				carrot_locations = loaded_carrots
				
				var loaded_coins: Array[CoinData] = []
				loaded_coins.assign(_dict_array_to_res_array(loaded_data.get("coin_locations", []), CoinData))
				coin_locations = loaded_coins
				
				var loaded_enemies: Array[EnemyData] = []
				loaded_enemies.assign(_dict_array_to_res_array(loaded_data.get("enemy_locations", []), EnemyData))
				enemy_locations = loaded_enemies
				
				var loaded_winzones: Array[WinzoneData] = []
				loaded_winzones.assign(_dict_array_to_res_array(loaded_data.get("winzone_location", []), WinzoneData))
				winzone_location = loaded_winzones
				
				var loaded_deathzones: Array[DeathzoneData] = []
				loaded_deathzones.assign(_dict_array_to_res_array(loaded_data.get("deathzone_locations", []), DeathzoneData))
				deathzone_locations = loaded_deathzones
				
				var loaded_carrot_removers: Array[CarrotRemoverZoneData] = []
				loaded_carrot_removers.assign(_dict_array_to_res_array(loaded_data.get("carrot_remover_locations", []), CarrotRemoverZoneData))
				carrot_remover_locations = loaded_carrot_removers
				
				var loaded_caves: Array[CaveZoneData] = []
				loaded_caves.assign(_dict_array_to_res_array(loaded_data.get("cave_locations", []), CaveZoneData))
				cave_locations = loaded_caves
				
				var loaded_winds: Array[WindZoneData] = []
				loaded_winds.assign(_dict_array_to_res_array(loaded_data.get("wind_locations", []), WindZoneData))
				wind_locations = loaded_winds
				
				var loaded_camerazooms: Array[CameraZoomZoneData] = []
				loaded_camerazooms.assign(_dict_array_to_res_array(loaded_data.get("camerazoom_locations", []), CameraZoomZoneData))
				camerazoom_locations = loaded_camerazooms
				
				custom_environment = loaded_data.get("custom_environment", 0)
				
				var loaded_env_zones: Array[EnvironmentChangeZoneData] = []
				loaded_env_zones.assign(_dict_array_to_res_array(loaded_data.get("custom_environment_call_change_zone", []), EnvironmentChangeZoneData))
				custom_environment_call_change_zone = loaded_env_zones
				
				##Variables
				camera_zoom = loaded_data.get("camera_zoom", camera_zoom)
				player_dashes = loaded_data.get("player_dashes", 2)
				ice_physics = loaded_data.get("ice_physics", false)
				force_light = loaded_data.get("force_light", false)
				
				## Load Custom Music Data
				custom_music_data = loaded_data.get("custom_music_data", PackedByteArray())
				custom_music_extension = loaded_data.get("custom_music_extension", "")
				custom_music_name = loaded_data.get("custom_music_name", "")
				
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
			
	# Clear Undo stacks after a fresh load
	undo_stack.clear()
	redo_stack.clear()

func Call_Save_TileMapLayer_As_Array(layer_node: TileMapLayer, is_main_tilemap: bool = true) -> PackedByteArray:
	if not layer_node: return PackedByteArray()
	var data_array: PackedByteArray = layer_node.get_tile_map_data_as_array()
	
	if is_main_tilemap:
		tilemap_array_main = data_array
	else:
		tilemap_array_bg = data_array
	
	return data_array

func Call_Load_TileMapLayer_Data(layer_node: TileMapLayer, data_array: PackedByteArray):
	if not layer_node: return
	layer_node.clear()
	if not data_array.is_empty():
		layer_node.set_tile_map_data_from_array(data_array)

## Exports the entire project to a single .wowlv file for easy sharing
func Call_Export(project_name_normalized: String = GlobalEditor.project_name_normalized) -> void:
	# 1. Prepare the data packet
	var export_data = {
		"project_name": GlobalEditor.project_name, 
		"project_version": ProjectSettings.get_setting("application/config/version"),
		"godot_version": Engine.get_version_info(),
		"time_when_saved": Time.get_date_string_from_system(),
		
		"player_spawn": player_spawn,
		"carrot_locations": _res_array_to_dict_array(carrot_locations),
		"coin_locations": _res_array_to_dict_array(coin_locations),
		"enemy_locations": _res_array_to_dict_array(enemy_locations),
		"winzone_location": _res_array_to_dict_array(winzone_location),
		"deathzone_locations": _res_array_to_dict_array(deathzone_locations),
		"carrot_remover_locations": _res_array_to_dict_array(carrot_remover_locations),
		"cave_locations": _res_array_to_dict_array(cave_locations),
		"wind_locations": _res_array_to_dict_array(wind_locations),
		"camerazoom_locations": _res_array_to_dict_array(camerazoom_locations),
		
		"custom_environment": custom_environment,
		"custom_environment_call_change_zone": _res_array_to_dict_array(custom_environment_call_change_zone),
		
		"camera_zoom": camera_zoom,
		"player_dashes": player_dashes,
		"ice_physics": ice_physics,
		"force_light": force_light,
		
		"custom_music_data": custom_music_data,
		"custom_music_extension": custom_music_extension,
		"custom_music_name": custom_music_name,
		
		"tilemap_array_main_packed": tilemap_array_main,
		"tilemap_array_bg_packed": tilemap_array_bg
	}
	
	# 2. Determine base directory and file names
	var base_export_dir: String
	if OS.has_feature("editor"):
		base_export_dir = ProjectSettings.globalize_path("user://Export")
	else:
		base_export_dir = OS.get_executable_path().get_base_dir().path_join("WoW Exports")
		
	var export_folder = base_export_dir.path_join(project_name_normalized)
	DirAccess.make_dir_recursive_absolute(export_folder)
	
	var default_filename = project_name_normalized if project_name_normalized != "" else "Default_Name"
	var default_export_file_path = export_folder.path_join(default_filename + ".wowlv")
	
	# 3. Define the actual file saving logic
	var perform_save = func(target_path: String):
		var file = FileAccess.open_compressed(target_path, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
		if file:
			file.store_var(export_data, true)
			file.close()
			print_rich("Project [color=green]successfully[/color] exported to: [color=orange]", target_path)
			
			# Open folder automatically on PC/Editor
			if not OS.has_feature("android") and not OS.has_feature("ios"):
				OS.shell_open("file://" + target_path.get_base_dir())
				DisplayServer.window_request_attention()
		else:
			push_error("Failed to export project. Error code: ", FileAccess.get_open_error())

	# 4. ROUTING: Check for Editor, Mobile, or Desktop
	if OS.has_feature("editor"):
		# EDITOR MODE: Save immediately to the default location, no questions asked.
		print_rich("[color=cyan]Editor Mode Detected:[/color] Auto-exporting to default location...")
		perform_save.call(default_export_file_path)
		
	elif OS.has_feature("android") or OS.has_feature("ios"):
		# MOBILE MODE: Use FileDialog node
		var fd = FileDialog.new()
		fd.use_native_dialog = false
		fd.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		fd.access = FileDialog.ACCESS_FILESYSTEM
		fd.current_dir = export_folder
		fd.current_file = default_filename + ".wowlv"
		fd.filters = PackedStringArray(["*.wowlv ; WoW Level File"])
		
		fd.file_selected.connect(func(path: String):
			perform_save.call(path)
			fd.queue_free()
		)
		fd.canceled.connect(func():
			print("Export cancelled by user.")
			fd.queue_free()
		)
		
		add_child(fd)
		fd.popup_centered_ratio(0.85)
		
	else:
		# PC EXPORT MODE: Use Native OS Dialog
		DisplayServer.file_dialog_show(
			"Export Level", 
			export_folder, 
			default_filename + ".wowlv", 
			false, 
			DisplayServer.FILE_DIALOG_MODE_SAVE_FILE, 
			PackedStringArray(["*.wowlv ; WoW Level File"]), 
			func(status: bool, selected_paths: PackedStringArray, selected_filter_index: int):
				if status and selected_paths.size() > 0:
					perform_save.call(selected_paths[0])
				else:
					print("Export cancelled by user.")
		)


# ==============================================================================
# --- CUSTOM MUSIC HELPER FUNCTIONS ---
# ==============================================================================

func Store_Custom_Music_From_Path(path: String) -> bool:
	if FileAccess.file_exists(path):
		custom_music_data = FileAccess.get_file_as_bytes(path)
		custom_music_extension = path.get_extension().to_lower()
		custom_music_name = path.get_file()
		print_rich("[color=lime]Successfully loaded custom audio: [/color]", custom_music_name)
		return true
	return false

func Get_Custom_Music_Stream() -> AudioStream:
	if custom_music_data.is_empty():
		return null
		
	if custom_music_extension == "ogg":
		var stream = AudioStreamOggVorbis.load_from_buffer(custom_music_data)
		if stream: stream.loop = true
		return stream
		
	elif custom_music_extension == "mp3":
		var stream = AudioStreamMP3.new()
		stream.data = custom_music_data
		stream.loop = true
		return stream
		
	return null

func Clear_Custom_Music() -> void:
	custom_music_data.clear()
	custom_music_extension = ""
	custom_music_name = ""

# ==============================================================================
# --- UNDO / REDO SNAPSHOT HELPERS ---
# ==============================================================================
func _sync_tilemaps_from_editor():
	# Access the main editor script to get current tile data
	var editor = get_tree().get_first_node_in_group("Editor")
	if editor and editor is Editor_Script:
		Call_Save_TileMapLayer_As_Array(editor.main_tilemap, true)
		Call_Save_TileMapLayer_As_Array(editor.bg_tilemap, false)

func commit_undo_state():
	# Sync before capturing
	_sync_tilemaps_from_editor()
	undo_stack.append(_create_state_dict())
	if undo_stack.size() > MAX_UNDO_STEPS:
		undo_stack.pop_front()
	redo_stack.clear()

func perform_undo():
	if undo_stack.is_empty(): return
	
	# 1. Capture what is CURRENTLY on the screen (the "before undo" state)
	_sync_tilemaps_from_editor()
	redo_stack.append(_create_state_dict())
	
	# 2. Get the state to revert to
	var state = undo_stack.pop_back()
	_apply_state_dict(state)
	state_restored.emit()
	print_rich("[color=yellow]Undo Performed.[/color] Undo Stack: ", undo_stack.size(), " | Redo Stack: ", redo_stack.size())

func perform_redo():
	if redo_stack.is_empty(): return
	
	# 1. Capture what is CURRENTLY on the screen (the "before redo" state)
	_sync_tilemaps_from_editor()
	undo_stack.append(_create_state_dict())
	
	# 2. Re-apply the redone state
	var state = redo_stack.pop_back()
	_apply_state_dict(state)
	state_restored.emit()
	print_rich("[color=cyan]Redo Performed.[/color] Undo Stack: ", undo_stack.size(), " | Redo Stack: ", redo_stack.size())

func _create_state_dict() -> Dictionary:
	return {
		"player_spawn": player_spawn,
		"carrot_locations": _res_array_to_dict_array(carrot_locations),
		"coin_locations": _res_array_to_dict_array(coin_locations),
		"enemy_locations": _res_array_to_dict_array(enemy_locations),
		"winzone_location": _res_array_to_dict_array(winzone_location),
		"deathzone_locations": _res_array_to_dict_array(deathzone_locations),
		"carrot_remover_locations": _res_array_to_dict_array(carrot_remover_locations),
		"cave_locations": _res_array_to_dict_array(cave_locations),
		"wind_locations": _res_array_to_dict_array(wind_locations),
		"camerazoom_locations": _res_array_to_dict_array(camerazoom_locations),
		"custom_environment_call_change_zone": _res_array_to_dict_array(custom_environment_call_change_zone),
		"tilemap_array_main": tilemap_array_main.duplicate(),
		"tilemap_array_bg": tilemap_array_bg.duplicate()
	}

func _apply_state_dict(state: Dictionary):
	player_spawn = state["player_spawn"]
	
	var loaded_carrots: Array[CarrotUpgradeData] = []
	loaded_carrots.assign(_dict_array_to_res_array(state["carrot_locations"], CarrotUpgradeData))
	carrot_locations = loaded_carrots
	
	var loaded_coins: Array[CoinData] = []
	loaded_coins.assign(_dict_array_to_res_array(state["coin_locations"], CoinData))
	coin_locations = loaded_coins
	
	var loaded_enemies: Array[EnemyData] = []
	loaded_enemies.assign(_dict_array_to_res_array(state["enemy_locations"], EnemyData))
	enemy_locations = loaded_enemies
	
	var loaded_winzones: Array[WinzoneData] = []
	loaded_winzones.assign(_dict_array_to_res_array(state["winzone_location"], WinzoneData))
	winzone_location = loaded_winzones
	
	var loaded_deathzones: Array[DeathzoneData] = []
	loaded_deathzones.assign(_dict_array_to_res_array(state["deathzone_locations"], DeathzoneData))
	deathzone_locations = loaded_deathzones
	
	var loaded_carrot_removers: Array[CarrotRemoverZoneData] = []
	loaded_carrot_removers.assign(_dict_array_to_res_array(state["carrot_remover_locations"], CarrotRemoverZoneData))
	carrot_remover_locations = loaded_carrot_removers
	
	var loaded_caves: Array[CaveZoneData] = []
	loaded_caves.assign(_dict_array_to_res_array(state["cave_locations"], CaveZoneData))
	cave_locations = loaded_caves
	
	var loaded_winds: Array[WindZoneData] = []
	loaded_winds.assign(_dict_array_to_res_array(state["wind_locations"], WindZoneData))
	wind_locations = loaded_winds
	
	var loaded_camerazooms: Array[CameraZoomZoneData] = []
	loaded_camerazooms.assign(_dict_array_to_res_array(state["camerazoom_locations"], CameraZoomZoneData))
	camerazoom_locations = loaded_camerazooms
	
	var loaded_env_zones: Array[EnvironmentChangeZoneData] = []
	loaded_env_zones.assign(_dict_array_to_res_array(state["custom_environment_call_change_zone"], EnvironmentChangeZoneData))
	custom_environment_call_change_zone = loaded_env_zones
	
	tilemap_array_main = state["tilemap_array_main"].duplicate()
	tilemap_array_bg = state["tilemap_array_bg"].duplicate()


# ==============================================================================
# --- CROSS-PROJECT DATA CONVERSION HELPERS ---
# ==============================================================================

func _res_array_to_dict_array(arr: Array) -> Array:
	var out = []
	for item in arr:
		if item == null: continue
		var dict = {}
		for prop in item.get_property_list():
			var p_name = prop["name"]
			if (prop["usage"] & PROPERTY_USAGE_STORAGE) > 0 and not p_name in ["script", "resource_local_to_scene", "resource_path", "resource_name", "Resource"]:
				dict[p_name] = item.get(p_name)
		out.append(dict)
	return out

func _dict_array_to_res_array(raw_array: Array, resource_class: Variant) -> Array:
	var out = []
	for dict in raw_array:
		var res = resource_class.new()
		for key in dict:
			res.set(key, dict[key])
		out.append(res)
	return out
