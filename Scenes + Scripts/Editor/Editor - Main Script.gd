extends Control
class_name Editor_Script

#region Node References & Variables
@onready var sub_viewport_container: SubViewportContainer = $VSplitContainer/HSplitContainer/Viewport/SubViewportContainer
@onready var sub_viewport: SubViewport = $VSplitContainer/HSplitContainer/Viewport/SubViewportContainer/SubViewport

# --- ASSIGN THESE IN THE INSPECTOR ---
@export_group("Game")
@export var environment: WorldEnvironment
@export var background: Sprite2D
@export var player: Sprite2D
@export var editor_camera: Camera2D

@export_group("Editor Tools")
@export var main_tilemap: TileMapLayer
@export var bg_tilemap: TileMapLayer
@export var main_layer_checkbox: CheckButton
@export var rectangle_tool_checkbox: CheckButton
@export var tileset_source_id: int = 0 # Default ID for tilesets is usually 0
@export var environment_options: OptionButton # Default ID for tilesets is usually 0

@export var tool_list: VBoxContainer 
@export var tool_label: Label


@export_group("Error")
@export var err_panel: Panel
@export var err_timer: Timer
@export var err_text: Label

enum SelectedTool { SELECT_TOOL, PLAYER_MOVE_TOOL, TILEMAP_PLACEMENT_TOOL, CARROT_PLACEMENT_TOOL, COLLISION_PLACEMENT_TOOL, COIN_PLACEMENT_TOOL, ENEMY_PLACEMENT_TOOL } 
var current_tool = SelectedTool.SELECT_TOOL

var _is_panning: bool = false
var _is_drawing: bool = false
var _is_erasing: bool = false
var _draw_start_pos: Vector2i

const MIN_ZOOM: float = 0.1
const MAX_ZOOM: float = 5.0
const ZOOM_STEP: float = 0.1


# Variable to hold the current active environment data
var current_env_index = 0
var current_env_data: LevelEnvironmentData
var active_light: DirectionalLight2D = null

# Variable to hold our current tile rotation/flip state
var _current_alt_tile: int = 0

# Mobile Multi-Touch Variables
var _touch_points: Dictionary = {}
var _start_zoom: Vector2 = Vector2.ONE
var _start_distance: float = 0.0
#endregion



#region Built-in Functions
func _ready():
	DisplayServer.window_request_attention()
	if typeof(GlobalProject.custom_environment) != TYPE_INT:
		GlobalProject.custom_environment = 0
		print_rich("[color=yellow]Old save format detected. Resetting environment to default.")
	
	if GlobalProject.custom_environment != 0:
		print("Environment is not default. Chaning to option ", GlobalProject.custom_environment)
		Call_Environment_Change(GlobalProject.custom_environment)
		if environment_options:
			environment_options.selected = GlobalProject.custom_environment
		
	
	GlobalProject.is_loading_embeded = false
	if player: player.global_position = GlobalProject.player_spawn
	var valid_tool_index = 0
	
	for child in tool_list.get_children():
		# This skips 'Tileset_Options' and only connects nodes starting with 'Tool_'
		if child is BaseButton and str(child.name).begins_with("Tool_"):
			child.pressed.connect(_on_tool_button_pressed.bind(valid_tool_index))
			valid_tool_index += 1
		else:
			print("Skipping non-tool: ", child.name)
	
	_on_tool_button_pressed(2)
	GlobalEditor.loading_scene_next_scene = ""
	if editor_camera:
		editor_camera.zoom = Vector2(0.5, 0.5)
		editor_camera.position = Vector2.ZERO
	GlobalProject.hide_bg_tiles_changed.connect(Hide_Tileset)
	GlobalProject.show_env_changed.connect(Show_Environment)
	
	await get_tree().process_frame
	Call_Load_Tilemap_Data()

func _on_tool_button_pressed(tool_id: int):
	current_tool = tool_id as SelectedTool
	if OS.is_debug_build(): print("Selected Tool ID: ", current_tool, " Name: ", SelectedTool.keys()[tool_id])
	
	# Handle your logic here
	match current_tool:
		SelectedTool.SELECT_TOOL:
			print_rich("[color=orange]Select Mode Active")
			if tool_label: tool_label.text = "Select Tool"
			GlobalEditor.selected_tool_id = 0
			
		SelectedTool.PLAYER_MOVE_TOOL:
			print_rich("[color=orange]Player Move Active")
			if tool_label: tool_label.text = "Player Tool"
			GlobalEditor.selected_tool_id = 1
		
		SelectedTool.TILEMAP_PLACEMENT_TOOL:
			print_rich("[color=orange]Tilemap Placement Active")
			if tool_label: tool_label.text = "Tilemap Tool"
			GlobalEditor.selected_tool_id = 2
		
		SelectedTool.CARROT_PLACEMENT_TOOL:
			print_rich("[color=orange]Carrot Placement Active")
			if tool_label: tool_label.text = "Carrot Tool"
			GlobalEditor.selected_tool_id = 3
			
		SelectedTool.COLLISION_PLACEMENT_TOOL:
			print_rich("[color=orange]Collision Placement Active")
			if tool_label: tool_label.text = "Collision Tool"
			GlobalEditor.selected_tool_id = 4
			
		SelectedTool.COIN_PLACEMENT_TOOL:
			print_rich("[color=orange]Coin Placement Active")
			if tool_label: tool_label.text = "Coin Tool"
			GlobalEditor.selected_tool_id = 5
			
		SelectedTool.ENEMY_PLACEMENT_TOOL:
			print_rich("[color=orange]Enemy Placement Active")
			if tool_label: tool_label.text = "Enemy Tool"
			GlobalEditor.selected_tool_id = 6
	GlobalEditor.selected_tool_id += 1 #Add 1 so you don't have to deal with the id having the possibility of being 0

func _input(event: InputEvent) -> void:
	if not GlobalEditor.can_edit_viewport: return
	if not editor_camera: return
	
	# -- Save Via Ctrl-S --
	if Input.is_action_just_pressed("save"):
		if main_tilemap and bg_tilemap:
			Call_Save(main_tilemap, true, false)
			await get_tree().process_frame
			Call_Save(bg_tilemap, false, true)
	
	# Tile Rotation & Mirroring
	if event.is_action_pressed("rotate"):
		_rotate_current_tile()
	if event.is_action_pressed("mirror"):
		_mirror_current_tile()
	
	# --- Multi-touch Pan & Zoom (Mobile) ---
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_points[event.index] = event.position
		else:
			_touch_points.erase(event.index)

		if _touch_points.size() == 2:
			var keys = _touch_points.keys()
			_start_distance = _touch_points[keys[0]].distance_to(_touch_points[keys[1]])
			_start_zoom = editor_camera.zoom

	elif event is InputEventScreenDrag:
		if _touch_points.has(event.index):
			_touch_points[event.index] = event.position

			if _touch_points.size() == 2:
				var keys = _touch_points.keys()
				var p1 = _touch_points[keys[0]]
				var p2 = _touch_points[keys[1]]

				# Pan camera (half of relative movement to calculate average midpoint drag)
				editor_camera.position -= (event.relative / 2.0) / editor_camera.zoom

				# Zoom camera
				var current_distance = p1.distance_to(p2)
				if _start_distance > 5.0: # Prevent dividing by zero / extreme jitter
					var zoom_ratio = current_distance / _start_distance
					var new_zoom_val = clamp(_start_zoom.x * zoom_ratio, MIN_ZOOM, MAX_ZOOM)
					editor_camera.zoom = Vector2(new_zoom_val, new_zoom_val)
					if background:
						var sprite_scale_val = 1.0 / new_zoom_val
						background.scale = Vector2(sprite_scale_val * 1.7, sprite_scale_val * 1.7)

	# Camera Panning State (PC)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_is_panning = event.pressed
				
		# Camera Zooming (PC)
		elif event.is_pressed() and sub_viewport_container and sub_viewport_container.get_global_rect().has_point(get_global_mouse_position()):
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_apply_zoom(ZOOM_STEP)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_apply_zoom(-ZOOM_STEP)

	# Handle camera movement while panning (PC)
	elif event is InputEventMouseMotion and _is_panning:
		editor_camera.position -= event.relative / editor_camera.zoom
	
	# -- Placement Control --
	var is_mouse_event = event is InputEventMouseButton or event is InputEventMouseMotion
	
	# _touch_points.size() < 2 ensures we don't accidentally draw while doing a 2-finger pan/zoom on mobile.
	if is_mouse_event and not _is_panning and _touch_points.size() < 2:
		# Check if mouse is strictly inside the viewport area to avoid drawing over UI side panels
		if sub_viewport_container and sub_viewport_container.get_global_rect().has_point(get_global_mouse_position()):
			# Note: These IDs match your incremented GlobalEditor.selected_tool_id logic
			if GlobalEditor.selected_tool_id == 2:
				_handle_player_placement(event)
		
			if GlobalEditor.selected_tool_id == 3:
				_handle_tile_placement(event)
#endregion

#region Custom Functions
func _apply_zoom(amount: float) -> void:
	var new_zoom = clamp(editor_camera.zoom.x + amount, MIN_ZOOM, MAX_ZOOM)
	editor_camera.zoom = Vector2(new_zoom, new_zoom)
	if background:
		var sprite_scale_val = 1.0 / new_zoom
		background.scale = Vector2(sprite_scale_val * 1.7, sprite_scale_val * 1.7)

func _rotate_current_tile() -> void:
	var is_transposed = bool(_current_alt_tile & TileSetAtlasSource.TRANSFORM_TRANSPOSE)
	var is_flip_h = bool(_current_alt_tile & TileSetAtlasSource.TRANSFORM_FLIP_H)
	var is_flip_v = bool(_current_alt_tile & TileSetAtlasSource.TRANSFORM_FLIP_V)

	# Standard 90-degree clockwise rotation bitwise logic for Godot
	var new_transposed = not is_transposed
	var new_flip_h = is_flip_h
	var new_flip_v = is_flip_v

	if is_transposed:
		new_flip_v = not is_flip_v
	else:
		new_flip_h = not is_flip_h

	# Clear out the old transformation flags while keeping the base alternative ID intact
	_current_alt_tile &= ~(TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_H | TileSetAtlasSource.TRANSFORM_FLIP_V)
	
	# Apply the newly calculated flags
	if new_transposed: _current_alt_tile |= TileSetAtlasSource.TRANSFORM_TRANSPOSE
	if new_flip_h: _current_alt_tile |= TileSetAtlasSource.TRANSFORM_FLIP_H
	if new_flip_v: _current_alt_tile |= TileSetAtlasSource.TRANSFORM_FLIP_V

func _mirror_current_tile() -> void:
	# Toggling FLIP_H creates a horizontal mirror
	_current_alt_tile ^= TileSetAtlasSource.TRANSFORM_FLIP_H

func _handle_player_placement(event: InputEvent):
	if not player or not sub_viewport: return

	# 1. Check for Mouse Click or Drag
	var is_placing = false
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			is_placing = true
	elif event is InputEventMouseMotion:
		# If you want it to follow the mouse while holding the button down
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			is_placing = true

	if is_placing:
		# 2. Get mouse position relative to the subviewport
		var mouse_pos = sub_viewport.get_mouse_position()
		
		# 3. Convert viewport pos to world pos (accounting for Camera2D zoom/pan)
		var world_pos = sub_viewport.get_canvas_transform().affine_inverse() * mouse_pos
		
		# 4. Update the Sprite's position
		player.global_position = world_pos
		
		# 5. Save the position to your Global variable
		GlobalProject.player_spawn = world_pos
		
		if OS.has_feature("editor"):
			print("Player Spawn set to: ", world_pos)

func _handle_tile_placement(event: InputEvent):
	# Guard clauses: Ensure you've dragged your nodes into the Inspector for this script
	if not main_tilemap or not bg_tilemap:
		return
	if not main_layer_checkbox or not rectangle_tool_checkbox:
		return

	# Determine the target layer and calculate correct tile coordinates
	var active_tilemap: TileMapLayer = main_tilemap if main_layer_checkbox.button_pressed else bg_tilemap
	var current_tile_pos = _get_tile_pos_under_mouse(active_tilemap)
	var selected_atlas_coords = GlobalProject.selected_tile_atlas_coords
	var is_rect_mode = rectangle_tool_checkbox.button_pressed

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_is_drawing = true
				if is_rect_mode:
					_draw_start_pos = current_tile_pos # Mark corner for rect tool
				else:
					_place_tile(active_tilemap, current_tile_pos, tileset_source_id, selected_atlas_coords, _current_alt_tile)
			else:
				if _is_drawing and is_rect_mode:
					_fill_rect(active_tilemap, _draw_start_pos, current_tile_pos, tileset_source_id, selected_atlas_coords, _current_alt_tile)
				_is_drawing = false
				
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_is_erasing = true
				if is_rect_mode:
					_draw_start_pos = current_tile_pos # Mark corner for rect tool
				else:
					_place_tile(active_tilemap, current_tile_pos, -1, Vector2i(-1, -1), 0)
			else:
				if _is_erasing and is_rect_mode:
					_fill_rect(active_tilemap, _draw_start_pos, current_tile_pos, -1, Vector2i(-1, -1), 0)
				_is_erasing = false

	# Handle dragging (Pencil Tool continuous drawing)
	elif event is InputEventMouseMotion:
		if not is_rect_mode:
			if _is_drawing:
				_place_tile(active_tilemap, current_tile_pos, tileset_source_id, selected_atlas_coords, _current_alt_tile)
			elif _is_erasing:
				_place_tile(active_tilemap, current_tile_pos, -1, Vector2i(-1, -1), 0)

func _get_tile_pos_under_mouse(tilemap: TileMapLayer) -> Vector2i:
	if not sub_viewport: return Vector2i.ZERO
	# 1. Get mouse position relative to the subviewport
	var mouse_pos = sub_viewport.get_mouse_position()
	# 2. Convert viewport pos to world pos taking the Camera2D zoom and pan into account
	var world_pos = sub_viewport.get_canvas_transform().affine_inverse() * mouse_pos
	# 3. Convert world position to local tilemap pos, then to tilemap grid coords
	return tilemap.local_to_map(tilemap.to_local(world_pos))

func _place_tile(tilemap: TileMapLayer, pos: Vector2i, source_id: int, atlas_coords: Vector2i, alt_tile: int = 0) -> void:
	# Erase if atlas_coords are negative or source_id is -1
	if atlas_coords == Vector2i(-1, -1) or source_id == -1:
		tilemap.set_cell(pos, -1)
	else:
		tilemap.set_cell(pos, source_id, atlas_coords, alt_tile)

func _fill_rect(tilemap: TileMapLayer, start_pos: Vector2i, end_pos: Vector2i, source_id: int, atlas_coords: Vector2i, alt_tile: int = 0) -> void:
	# Calculate lowest and highest bounds ensuring we loop in the correct direction
	var min_x = min(start_pos.x, end_pos.x)
	var max_x = max(start_pos.x, end_pos.x)
	var min_y = min(start_pos.y, end_pos.y)
	var max_y = max(start_pos.y, end_pos.y)
	
	for x in range(min_x, max_x + 1):
		for y in range(min_y, max_y + 1):
			_place_tile(tilemap, Vector2i(x, y), source_id, atlas_coords, alt_tile)


func Hide_Tileset(is_showing: bool, tileset_to_hide = bg_tilemap):
	if tileset_to_hide == bg_tilemap and bg_tilemap:
		if is_showing: bg_tilemap.hide()
		else: bg_tilemap.show()
	if tileset_to_hide == main_tilemap and main_tilemap:
		if is_showing: main_tilemap.hide()
		else: main_tilemap.show()
#endregion

#region Save & Load Functionality
##Tilemap, Is_Main, Call Global Save
func Call_Save(tilemap_to_save: TileMapLayer, is_main_tilemap: bool = true, call_final_save = true) -> void:
	if player: GlobalProject.player_spawn = player.global_position
	
	GlobalProject.Call_Save_TileMapLayer_As_Array(tilemap_to_save, is_main_tilemap)
	await get_tree().process_frame
	# Save the actual project state after caching the array
	if call_final_save:
		GlobalProject.Call_Project_Save()

func Call_Load_Tilemap_Data():
	if main_tilemap:
		GlobalProject.Call_Load_TileMapLayer_Data(main_tilemap, GlobalProject.tilemap_array_main)
	if bg_tilemap:
		GlobalProject.Call_Load_TileMapLayer_Data(bg_tilemap, GlobalProject.tilemap_array_bg)
#endregion

#region Error Calls
func Call_Error_Occured(error_message = ""):
	if not err_panel: return
	if not err_timer: return
	if not err_text: return
	

	err_panel.show()
	var msg = "Error Msg: " if error_message != "" else ""
	err_text.text = msg  + error_message
	err_timer.start()
#endregion


func Show_Environment(is_showing: bool):
	if is_showing == false: Call_Environment_Change(0, false)
	else: Call_Environment_Change(current_env_index, false)

func Call_Environment_Change(index: int = 0, update_current_index = true):
	if not environment: print("Environment Not Found"); return
	if update_current_index:
		current_env_index = index

	# 1. Extract the resource based on the index
	var loaded_resource: Resource
	
	if active_light:
		if OS.has_feature("editor"):
			print_rich("[color=orange]Removed[/color] ", active_light)
		active_light.queue_free()
		active_light = null
	
	match index:
		0: 
			GlobalProject.custom_environment = 0
			environment.environment = null
			current_env_data = null
			return
		1: loaded_resource = load("res://Resources - WoW/WoW Environment Resources/Lava.tres"); GlobalProject.custom_environment = 1
		2: loaded_resource = load("res://Resources - WoW/WoW Environment Resources/Lava Dark.tres"); GlobalProject.custom_environment = 2
		3: loaded_resource = load("res://Resources - WoW/WoW Environment Resources/Desert.tres"); GlobalProject.custom_environment = 3
		4: loaded_resource = load("res://Resources - WoW/WoW Environment Resources/Ice.tres"); GlobalProject.custom_environment = 4
		5: loaded_resource = load("res://Resources - WoW/WoW Environment Resources/Grass.tres"); GlobalProject.custom_environment = 5

	if not GlobalProject.show_env: return
	# 2. Save to the typed variable
	if loaded_resource is LevelEnvironmentData:
		current_env_data = loaded_resource
		apply_environment_settings()

func apply_environment_settings():
	if not current_env_data:
		return
	
	
	# Example: Applying the WorldEnvironment
	if current_env_data.world_env_normal:
		environment.environment = current_env_data.world_env_normal
		
	# Example: Setting a light color from the data. Currently Disabled
	#if current_env_data.dir_light_normal:
	#   var light_instance = current_env_data.dir_light_normal.instantiate()
	#   active_light = light_instance
	#   add_child(light_instance)
		
	print("Switched to environment with ambient color: ", current_env_data.ambient_color)


func Hide_Error():
	if err_panel: err_panel.hide()
