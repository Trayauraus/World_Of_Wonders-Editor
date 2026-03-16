extends Control
class_name Editor_Script

#region Node References & Variables
@onready var sub_viewport_container: SubViewportContainer = $VSplitContainer/HSplitContainer/Viewport/SubViewportContainer
@onready var sub_viewport: SubViewport = $VSplitContainer/HSplitContainer/Viewport/SubViewportContainer/SubViewport
@onready var editor_camera: Camera2D = $VSplitContainer/HSplitContainer/Viewport/SubViewportContainer/SubViewport/Editor_Viewport_Camera

# --- ASSIGN THESE IN THE INSPECTOR ---
@export_group("Game")
@export var environment: WorldEnvironment
@export var background: Sprite2D

@export_group("Editor Tools")
@export var main_tilemap: TileMapLayer
@export var bg_tilemap: TileMapLayer
@export var main_layer_checkbox: CheckButton
@export var rectangle_tool_checkbox: CheckButton
@export var tileset_source_id: int = 0 # Default ID for tilesets is usually 0

@export_group("Error")
@export var err_panel: Panel
@export var err_timer: Timer
@export var err_text: Label


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
#endregion



#region Built-in Functions
func _ready() -> void:
	Call_Load_Tilemap_Data()
	GlobalEditor.loading_scene_next_scene = ""
	if editor_camera:
		editor_camera.zoom = Vector2(0.5, 0.5)
		editor_camera.position = Vector2.ZERO
	GlobalProject.hide_bg_tiles_changed.connect(Hide_Tileset)
	GlobalProject.show_env_changed.connect(Show_Environment)

func _input(event: InputEvent) -> void:
	if not GlobalEditor.can_edit_viewport: return
	if not editor_camera: return
	
	# Camera Panning State
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_is_panning = event.pressed
				
		# Camera Zooming
		elif event.is_pressed() and sub_viewport_container and sub_viewport_container.get_global_rect().has_point(get_global_mouse_position()):
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_apply_zoom(ZOOM_STEP)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_apply_zoom(-ZOOM_STEP)

	# Handle camera movement while panning
	elif event is InputEventMouseMotion and _is_panning:
		editor_camera.position -= event.relative / editor_camera.zoom
		
	# Handle Tile Placement and Tools
	var is_mouse_event = event is InputEventMouseButton or event is InputEventMouseMotion
	if is_mouse_event and not _is_panning:
		# Check if mouse is strictly inside the viewport area to avoid drawing over UI side panels
		if sub_viewport_container and sub_viewport_container.get_global_rect().has_point(get_global_mouse_position()):
			_handle_tile_placement(event)
#endregion

#region Custom Functions
func _apply_zoom(amount: float) -> void:
	var new_zoom = clamp(editor_camera.zoom.x + amount, MIN_ZOOM, MAX_ZOOM)
	editor_camera.zoom = Vector2(new_zoom, new_zoom)
	var sprite_scale_val = 1.0 / new_zoom
	background.scale = Vector2(sprite_scale_val * 1.7, sprite_scale_val * 1.7)

func _handle_tile_placement(event: InputEvent) -> void:
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
					_place_tile(active_tilemap, current_tile_pos, tileset_source_id, selected_atlas_coords)
			else:
				if _is_drawing and is_rect_mode:
					_fill_rect(active_tilemap, _draw_start_pos, current_tile_pos, tileset_source_id, selected_atlas_coords)
				_is_drawing = false
				
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_is_erasing = true
				if is_rect_mode:
					_draw_start_pos = current_tile_pos # Mark corner for rect tool
				else:
					_place_tile(active_tilemap, current_tile_pos, -1, Vector2i(-1, -1))
			else:
				if _is_erasing and is_rect_mode:
					_fill_rect(active_tilemap, _draw_start_pos, current_tile_pos, -1, Vector2i(-1, -1))
				_is_erasing = false

	# Handle dragging (Pencil Tool continuous drawing)
	elif event is InputEventMouseMotion:
		if not is_rect_mode:
			if _is_drawing:
				_place_tile(active_tilemap, current_tile_pos, tileset_source_id, selected_atlas_coords)
			elif _is_erasing:
				_place_tile(active_tilemap, current_tile_pos, -1, Vector2i(-1, -1))

func _get_tile_pos_under_mouse(tilemap: TileMapLayer) -> Vector2i:
	if not sub_viewport: return Vector2i.ZERO
	# 1. Get mouse position relative to the subviewport
	var mouse_pos = sub_viewport.get_mouse_position()
	# 2. Convert viewport pos to world pos taking the Camera2D zoom and pan into account
	var world_pos = sub_viewport.get_canvas_transform().affine_inverse() * mouse_pos
	# 3. Convert world position to local tilemap pos, then to tilemap grid coords
	return tilemap.local_to_map(tilemap.to_local(world_pos))

func _place_tile(tilemap: TileMapLayer, pos: Vector2i, source_id: int, atlas_coords: Vector2i) -> void:
	# Erase if atlas_coords are negative or source_id is -1
	if atlas_coords == Vector2i(-1, -1) or source_id == -1:
		tilemap.set_cell(pos, -1)
	else:
		tilemap.set_cell(pos, source_id, atlas_coords)

func _fill_rect(tilemap: TileMapLayer, start_pos: Vector2i, end_pos: Vector2i, source_id: int, atlas_coords: Vector2i) -> void:
	# Calculate lowest and highest bounds ensuring we loop in the correct direction
	var min_x = min(start_pos.x, end_pos.x)
	var max_x = max(start_pos.x, end_pos.x)
	var min_y = min(start_pos.y, end_pos.y)
	var max_y = max(start_pos.y, end_pos.y)
	
	for x in range(min_x, max_x + 1):
		for y in range(min_y, max_y + 1):
			_place_tile(tilemap, Vector2i(x, y), source_id, atlas_coords)


func Hide_Tileset(is_showing: bool, tileset_to_hide = bg_tilemap):
	if tileset_to_hide == bg_tilemap and bg_tilemap:
		if is_showing: bg_tilemap.hide()
		else: bg_tilemap.show()
	if tileset_to_hide == main_tilemap and main_tilemap:
		if is_showing: main_tilemap.hide()
		else: main_tilemap.show()
#endregion

#region Save & Load Functionality
func Call_Save(tilemap_to_save: TileMapLayer, is_main_tilemap: bool = true, call_final_save = true) -> void:
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
			environment.environment = null
			current_env_data = null
			return
		1: loaded_resource = load("res://Resources - WoW/WoW Environment Resources/Lava.tres")
		2: loaded_resource = load("res://Resources - WoW/WoW Environment Resources/Lava Dark.tres")
		3: loaded_resource = load("res://Resources - WoW/WoW Environment Resources/Desert.tres")
		4: loaded_resource = load("res://Resources - WoW/WoW Environment Resources/Ice.tres")
		5: loaded_resource = load("res://Resources - WoW/WoW Environment Resources/Grass.tres")

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
		
	# Example: Setting a light color from the data
	if current_env_data.dir_light_normal:
		var light_instance = current_env_data.dir_light_normal.instantiate()
		active_light = light_instance
		add_child(light_instance)
		
	print("Switched to environment with ambient color: ", current_env_data.ambient_color)


func Hide_Error():
	if err_panel: err_panel.hide()
