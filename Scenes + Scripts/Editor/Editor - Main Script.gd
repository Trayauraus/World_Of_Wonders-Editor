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
@export var eraser_checkbox: CheckBox
@export var undo_button: Button # <--- NEW UNDO BUTTON
@export var redo_button: Button # <--- NEW REDO BUTTON
@export var rotate_button: Button # <--- NEW ROTATE BUTTON
@export var mirror_button: Button # <--- NEW MIRROR BUTTON
@export var mobile_button_vseperator: VSeparator
@export var tileset_source_id: int = 0
@export var environment_options: OptionButton


@export var tool_list: VBoxContainer 
@export var tool_label: Label

# NEW: Property Lists
@export var world_properties_list: VBoxContainer
@export var property_list: VBoxContainer

@export_group("Object Placement Textures")
@export var carrot_texture: Texture2D
@export var coin_texture: Texture2D
@export var enemy_texture: Texture2D
@export var light_texture: Texture2D # <--- NEW FOR POINTLIGHTS
@export var object_container: Node2D

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

var _placed_visuals: Dictionary = {}
var _selected_object_data: Resource = null
var _selected_visual: CanvasItem = null

const MIN_ZOOM: float = 0.1
const MAX_ZOOM: float = 5.0
const ZOOM_STEP: float = 0.1

var current_env_index = 0
var current_env_data: LevelEnvironmentData
var active_light: DirectionalLight2D = null

var _current_alt_tile: int = 0

var _touch_points: Dictionary = {}
var _start_zoom: Vector2 = Vector2.ONE
var _start_distance: float = 0.0

# Collision Tool Setup
var collision_types = [
	"Environment - Lava", "Environment - Lava Darkened", "Environment - Desert",
	"Environment - Ice", "Environment - Grasslands", "Cave Area",
	"Wind - Deactivate", "Wind - Activate Left",
	"Wind - Activate Right", "Camera Zoom", "Winzone", "Deathzone",
	"Carrot Remover" # <--- NEW
]
var _current_collision_type_index: int = 0

# UI Tool Interaction States
var _is_drawing_collision: bool = false
var _collision_start_pos: Vector2 = Vector2.ZERO
var _temp_collision_visual: ColorRect = null

var _is_dragging_object: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _is_resizing_object: bool = false
var _resize_start_rect: Rect2
var _prop_spinboxes: Dictionary = {}
var _selection_handle: ColorRect = null

# PREVIEW SYSTEM VARIABLES
var preview_tilemap: TileMapLayer
var _preview_active: bool = false
#endregion


#region Built-in Functions
func _ready():
	DisplayServer.window_request_attention()
	
	if typeof(GlobalProject.custom_environment) != TYPE_INT:
		GlobalProject.custom_environment = 0
		print_rich("[color=yellow]Old save format detected. Resetting environment to default.")
	
	if GlobalProject.custom_environment != 0:
		Call_Environment_Change(GlobalProject.custom_environment)
		if environment_options:
			environment_options.selected = GlobalProject.custom_environment
		
	GlobalProject.is_loading_embeded = false
	if player: player.global_position = GlobalProject.player_spawn
	var valid_tool_index = 0
	
	for child in tool_list.get_children():
		if child is BaseButton and str(child.name).begins_with("Tool_"):
			child.pressed.connect(_on_tool_button_pressed.bind(valid_tool_index))
			valid_tool_index += 1
	
	# UNDO REDO CONNECTION
	if undo_button: undo_button.pressed.connect(GlobalProject.perform_undo)
	if redo_button: redo_button.pressed.connect(GlobalProject.perform_redo)
	GlobalProject.state_restored.connect(_on_state_restored)
	
	_on_tool_button_pressed(2)
	GlobalEditor.loading_scene_next_scene = ""
	if editor_camera:
		editor_camera.zoom = Vector2(0.5, 0.5)
		editor_camera.position = Vector2.ZERO
	GlobalProject.hide_bg_tiles_changed.connect(Hide_Tileset)
	GlobalProject.show_env_changed.connect(Show_Environment)
	
	# BUILD DYNAMIC PREVIEW TILEMAP LAYER
	if main_tilemap or bg_tilemap:
		preview_tilemap = TileMapLayer.new()
		preview_tilemap.name = "PreviewTileMapLayer"
		preview_tilemap.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		preview_tilemap.modulate = Color(1.0, 1.0, 1.0, 0.5)
		preview_tilemap.z_index = 100 # Draw over other layers
		if main_tilemap:
			main_tilemap.get_parent().add_child(preview_tilemap)
		elif bg_tilemap:
			main_tilemap.get_parent().add_child(preview_tilemap)
		preview_tilemap.tile_set = main_tilemap.tile_set
	
	await get_tree().process_frame
	Call_Load_Tilemap_Data()
	Call_Rebuild_Object_Visuals()
	
	await get_tree().process_frame
	if OS.has_feature("mobile"):
		if rotate_button:
			rotate_button.pressed.connect(_rotate_current_tile)
			rotate_button.show()
		
		if mobile_button_vseperator:
			mobile_button_vseperator.show()
		
		if mirror_button:
			mirror_button.pressed.connect(_mirror_current_tile)
			mirror_button.show()

func _process(_delta):
	# Update visual tile preview independently each frame
	if current_tool == SelectedTool.TILEMAP_PLACEMENT_TOOL:
		_update_tile_preview()
		_preview_active = true
	elif _preview_active:
		if is_instance_valid(preview_tilemap):
			preview_tilemap.clear()
		_preview_active = false


func _on_tool_button_pressed(tool_id: int):
	current_tool = tool_id as SelectedTool
	
	if world_properties_list and property_list:
		if current_tool == SelectedTool.SELECT_TOOL:
			world_properties_list.hide()
			property_list.show()
			_clear_selection()
		elif current_tool == SelectedTool.COLLISION_PLACEMENT_TOOL:
			world_properties_list.hide()
			property_list.show()
			_clear_selection()
			_build_collision_tool_ui()
		else:
			world_properties_list.show()
			property_list.hide()
			_clear_selection()

	match current_tool:
		SelectedTool.SELECT_TOOL:
			if tool_label: tool_label.text = "Select Tool"
			GlobalEditor.selected_tool_id = 0
		SelectedTool.PLAYER_MOVE_TOOL:
			if tool_label: tool_label.text = "Player Tool"
			GlobalEditor.selected_tool_id = 1
		SelectedTool.TILEMAP_PLACEMENT_TOOL:
			if tool_label: tool_label.text = "Tilemap Tool"
			GlobalEditor.selected_tool_id = 2
		SelectedTool.CARROT_PLACEMENT_TOOL:
			if tool_label: tool_label.text = "Carrot Tool"
			GlobalEditor.selected_tool_id = 3
		SelectedTool.COLLISION_PLACEMENT_TOOL:
			if tool_label: tool_label.text = "Collision Tool"
			GlobalEditor.selected_tool_id = 4
		SelectedTool.COIN_PLACEMENT_TOOL:
			if tool_label: tool_label.text = "Coin Tool"
			GlobalEditor.selected_tool_id = 5
		SelectedTool.ENEMY_PLACEMENT_TOOL:
			if tool_label: tool_label.text = "Enemy Tool"
			GlobalEditor.selected_tool_id = 6
	GlobalEditor.selected_tool_id += 1 

func _input(event: InputEvent) -> void:
	if not GlobalEditor.can_edit_viewport: return
	if not editor_camera: return
	
	if Input.is_action_just_pressed("save"):
		if main_tilemap and bg_tilemap:
			Call_Save(main_tilemap, true, false)
			await get_tree().process_frame
			Call_Save(bg_tilemap, false, true)
			
	# Keyboard Shortcut Support for Undo / Redo
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_Z and event.get_modifiers_mask() & KEY_MASK_CTRL:
			if event.shift_pressed:
				GlobalProject.perform_redo()
			else:
				GlobalProject.perform_undo()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_Y and event.get_modifiers_mask() & KEY_MASK_CTRL:
			GlobalProject.perform_redo()
			get_viewport().set_input_as_handled()
	
	if event.is_action_pressed("rotate"): _rotate_current_tile()
	if event.is_action_pressed("mirror"): _mirror_current_tile()
	
	if event is InputEventScreenTouch:
		if event.pressed: _touch_points[event.index] = event.position
		else: _touch_points.erase(event.index)

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
				editor_camera.position -= (event.relative / 2.0) / editor_camera.zoom
				var current_distance = p1.distance_to(p2)
				if _start_distance > 5.0:
					var zoom_ratio = current_distance / _start_distance
					var new_zoom_val = clamp(_start_zoom.x * zoom_ratio, MIN_ZOOM, MAX_ZOOM)
					editor_camera.zoom = Vector2(new_zoom_val, new_zoom_val)
					if background:
						var sprite_scale_val = 1.0 / new_zoom_val
						background.scale = Vector2(sprite_scale_val * 1.7, sprite_scale_val * 1.7)

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_is_panning = event.pressed
		elif event.is_pressed() and sub_viewport_container and sub_viewport_container.get_global_rect().has_point(get_global_mouse_position()):
			if event.button_index == MOUSE_BUTTON_WHEEL_UP: _apply_zoom(ZOOM_STEP)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: _apply_zoom(-ZOOM_STEP)

	elif event is InputEventMouseMotion and _is_panning:
		editor_camera.position -= event.relative / editor_camera.zoom
	
	var is_mouse_event = event is InputEventMouseButton or event is InputEventMouseMotion
	if is_mouse_event and not _is_panning and _touch_points.size() < 2:
		if sub_viewport_container and sub_viewport_container.get_global_rect().has_point(get_global_mouse_position()):
			if GlobalEditor.selected_tool_id == 1: _handle_object_selection(event)
			elif GlobalEditor.selected_tool_id == 2: _handle_player_placement(event)
			elif GlobalEditor.selected_tool_id == 3: _handle_tile_placement(event)
			elif GlobalEditor.selected_tool_id == 4: _handle_object_placement(event, "carrot")
			elif GlobalEditor.selected_tool_id == 5: _handle_collision_placement(event)
			elif GlobalEditor.selected_tool_id == 6: _handle_object_placement(event, "coin")
			elif GlobalEditor.selected_tool_id == 7: _handle_object_placement(event, "enemy")
#endregion

#region Custom Functions
func _save_undo_state():
	if main_tilemap: GlobalProject.tilemap_array_main = main_tilemap.get_tile_map_data_as_array()
	if bg_tilemap: GlobalProject.tilemap_array_bg = bg_tilemap.get_tile_map_data_as_array()
	GlobalProject.commit_undo_state()

func _on_state_restored():
	_clear_selection()
	if player: player.global_position = GlobalProject.player_spawn
	Call_Load_Tilemap_Data()
	Call_Rebuild_Object_Visuals()

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

	var new_transposed = not is_transposed
	var new_flip_h = is_flip_h
	var new_flip_v = is_flip_v

	if is_transposed: new_flip_v = not is_flip_v
	else: new_flip_h = not is_flip_h

	_current_alt_tile &= ~(TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_H | TileSetAtlasSource.TRANSFORM_FLIP_V)
	
	if new_transposed: _current_alt_tile |= TileSetAtlasSource.TRANSFORM_TRANSPOSE
	if new_flip_h: _current_alt_tile |= TileSetAtlasSource.TRANSFORM_FLIP_H
	if new_flip_v: _current_alt_tile |= TileSetAtlasSource.TRANSFORM_FLIP_V

func _mirror_current_tile() -> void:
	_current_alt_tile ^= TileSetAtlasSource.TRANSFORM_FLIP_H

func _handle_player_placement(event: InputEvent):
	if not player or not sub_viewport: return
	var is_placing = false
	var just_started = false
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed: 
			is_placing = true
			just_started = true
	elif event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): is_placing = true

	if is_placing:
		if just_started:
			_save_undo_state()
		var mouse_pos = sub_viewport.get_mouse_position()
		var world_pos = sub_viewport.get_canvas_transform().affine_inverse() * mouse_pos
		player.global_position = world_pos
		GlobalProject.player_spawn = world_pos

func _handle_tile_placement(event: InputEvent):
	if not main_tilemap or not bg_tilemap: return
	if not main_layer_checkbox or not rectangle_tool_checkbox: return

	var active_tilemap: TileMapLayer = main_tilemap if main_layer_checkbox.button_pressed else bg_tilemap
	var current_tile_pos = _get_tile_pos_under_mouse(active_tilemap)
	var selected_atlas_coords = GlobalProject.selected_tile_atlas_coords
	var is_rect_mode = rectangle_tool_checkbox.button_pressed

	var is_left_click = false
	var is_right_click = false
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if eraser_checkbox and eraser_checkbox.button_pressed: is_right_click = true
			else: is_left_click = true
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			is_right_click = true

	if event is InputEventMouseButton:
		if is_left_click:
			if event.pressed:
				_save_undo_state()
				_is_drawing = true
				if is_rect_mode: _draw_start_pos = current_tile_pos
				else: _place_tile(active_tilemap, current_tile_pos, tileset_source_id, selected_atlas_coords, _current_alt_tile)
			else:
				if _is_drawing and is_rect_mode: _fill_rect(active_tilemap, _draw_start_pos, current_tile_pos, tileset_source_id, selected_atlas_coords, _current_alt_tile)
				_is_drawing = false
				
		elif is_right_click:
			if event.pressed:
				_save_undo_state()
				_is_erasing = true
				if is_rect_mode: _draw_start_pos = current_tile_pos
				else: _place_tile(active_tilemap, current_tile_pos, -1, Vector2i(-1, -1), 0)
			else:
				if _is_erasing and is_rect_mode: _fill_rect(active_tilemap, _draw_start_pos, current_tile_pos, -1, Vector2i(-1, -1), 0)
				_is_erasing = false

	elif event is InputEventMouseMotion:
		if not is_rect_mode:
			if _is_drawing: _place_tile(active_tilemap, current_tile_pos, tileset_source_id, selected_atlas_coords, _current_alt_tile)
			elif _is_erasing: _place_tile(active_tilemap, current_tile_pos, -1, Vector2i(-1, -1), 0)

func _update_tile_preview():
	if not is_instance_valid(preview_tilemap): return
	if not main_tilemap or not bg_tilemap or not main_layer_checkbox or not rectangle_tool_checkbox: return
	
	var active_tilemap: TileMapLayer = main_tilemap if main_layer_checkbox.button_pressed else bg_tilemap
	
	if not sub_viewport: return
	var global_mouse = get_global_mouse_position()
	
	# Clear out the preview if mouse escapes the viewport area
	if sub_viewport_container and not sub_viewport_container.get_global_rect().has_point(global_mouse):
		preview_tilemap.clear()
		return
		
	var mouse_pos = sub_viewport.get_mouse_position()
	var world_pos = sub_viewport.get_canvas_transform().affine_inverse() * mouse_pos
	var current_tile_pos = active_tilemap.local_to_map(active_tilemap.to_local(world_pos))
	
	var selected_atlas_coords = GlobalProject.selected_tile_atlas_coords
	var is_rect_mode = rectangle_tool_checkbox.button_pressed
	var is_erasing_mode = eraser_checkbox and eraser_checkbox.button_pressed
	
	preview_tilemap.clear()
	
	# Always ensure tileset parity incase users swap sets
	if preview_tilemap.tile_set != active_tilemap.tile_set:
		preview_tilemap.tile_set = active_tilemap.tile_set
	
	# Apply Red-tint for Erasing / Normal tint for Drawing
	if _is_erasing or (is_erasing_mode and not _is_drawing):
		preview_tilemap.modulate = Color(1.0, 0.0, 0.0, 0.5) 
	else:
		preview_tilemap.modulate = Color(1.0, 1.0, 1.0, 0.5) 
		
	if (_is_drawing or _is_erasing) and is_rect_mode:
		var min_x = min(_draw_start_pos.x, current_tile_pos.x)
		var max_x = max(_draw_start_pos.x, current_tile_pos.x)
		var min_y = min(_draw_start_pos.y, current_tile_pos.y)
		var max_y = max(_draw_start_pos.y, current_tile_pos.y)
		for x in range(min_x, max_x + 1):
			for y in range(min_y, max_y + 1):
				preview_tilemap.set_cell(Vector2i(x, y), tileset_source_id, selected_atlas_coords, _current_alt_tile)
	else:
		preview_tilemap.set_cell(current_tile_pos, tileset_source_id, selected_atlas_coords, _current_alt_tile)

#endregion

#region Collision Logic Implementation
func _build_collision_tool_ui():
	if not property_list: return
	
	for child in property_list.get_children():
		child.queue_free()
		
	var title = Label.new()
	title.add_theme_font_size_override("font_size", 20)
	title.text = "Collision Type:"
	property_list.add_child(title)
	
	var opt = OptionButton.new()
	for ct in collision_types: opt.add_item(ct)
	opt.selected = _current_collision_type_index
	opt.item_selected.connect(func(idx): _current_collision_type_index = idx)
	property_list.add_child(opt)

func _handle_collision_placement(event: InputEvent):
	if not sub_viewport: return
	
	var mouse_pos = sub_viewport.get_mouse_position()
	var world_pos = sub_viewport.get_canvas_transform().affine_inverse() * mouse_pos
	
	var is_left_click = false
	var is_right_click = false
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if eraser_checkbox and eraser_checkbox.button_pressed: is_right_click = true
			else: is_left_click = true
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			is_right_click = true

	if event is InputEventMouseButton:
		if is_left_click:
			if event.pressed:
				_save_undo_state()
				_is_drawing_collision = true
				_collision_start_pos = world_pos
				
				var type_str = collision_types[_current_collision_type_index]
				_temp_collision_visual = ColorRect.new()
				_temp_collision_visual.color = _get_color_for_collision_type(type_str)
				_temp_collision_visual.position = world_pos
				_temp_collision_visual.size = Vector2.ZERO
				var parent = sub_viewport if object_container == null else object_container
				parent.add_child(_temp_collision_visual)
			else:
				if _is_drawing_collision:
					_is_drawing_collision = false
					if is_instance_valid(_temp_collision_visual):
						_temp_collision_visual.queue_free()
					
					var rect = Rect2(_collision_start_pos, world_pos - _collision_start_pos).abs()
					
					# Defaults to 128x128 if drawn smaller than a 16x16 box
					if rect.size.x < 16 or rect.size.y < 16:
						_place_collision(_collision_start_pos, Vector2(128, 128))
					else:
						_place_collision(rect.get_center(), rect.size)

		elif is_right_click and event.pressed:
			_save_undo_state()
			_remove_collision(world_pos)
			
	elif event is InputEventMouseMotion:
		if _is_drawing_collision and is_instance_valid(_temp_collision_visual):
			var rect = Rect2(_collision_start_pos, world_pos - _collision_start_pos).abs()
			_temp_collision_visual.position = rect.position
			_temp_collision_visual.size = rect.size

func _place_collision(pos: Vector2, shape_size: Vector2 = Vector2(128, 128)):
	var type_str = collision_types[_current_collision_type_index]
	var data: Resource
	
	if type_str == "Winzone":
		if GlobalProject.winzone_location.size() > 0:
			var old = GlobalProject.winzone_location[0]
			_remove_collision_visual(old)
		data = WinzoneData.new()
		data.location = pos
		data.set("shape_size", shape_size)
		GlobalProject.winzone_location.append(data)
		
	elif type_str == "Deathzone":
		data = DeathzoneData.new()
		data.location = pos
		data.set("shape_size", shape_size)
		GlobalProject.deathzone_locations.append(data)
		
	elif type_str == "Carrot Remover":
		data = CarrotRemoverZoneData.new()
		data.location = pos
		data.set("shape_size", shape_size)
		GlobalProject.carrot_remover_locations.append(data)
	
	elif type_str.begins_with("Cave"):
		data = CaveZoneData.new()
		data.location = pos
		data.set("shape_size", shape_size)
		data.set("cave_type", type_str)
		GlobalProject.cave_locations.append(data)
		
	elif type_str.begins_with("Wind"):
		data = WindZoneData.new()
		data.location = pos
		data.set("shape_size", shape_size)
		data.set("wind_type", type_str)
		GlobalProject.wind_locations.append(data)
		
	elif type_str == "Camera Zoom":
		data = CameraZoomZoneData.new()
		data.location = pos
		data.set("shape_size", shape_size)
		data.set("zoom_amount", 1.5)
		GlobalProject.camerazoom_locations.append(data)
		
	else:
		data = EnvironmentChangeZoneData.new()
		data.location = pos
		data.set("shape_size", shape_size)
		data.set("environment_type", type_str)
		GlobalProject.custom_environment_call_change_zone.append(data)
		
	_spawn_collision_visual(data, type_str)

func _remove_collision(pos: Vector2):
	var target_data: Resource = null
	var target_type_str = collision_types[_current_collision_type_index]
	
	var all_collisions = []
	all_collisions.append_array(GlobalProject.custom_environment_call_change_zone)
	all_collisions.append_array(GlobalProject.cave_locations)
	all_collisions.append_array(GlobalProject.wind_locations)
	all_collisions.append_array(GlobalProject.camerazoom_locations)
	all_collisions.append_array(GlobalProject.winzone_location)
	all_collisions.append_array(GlobalProject.deathzone_locations)
	all_collisions.append_array(GlobalProject.carrot_remover_locations)
	
	var hit_candidates = []
	for col in all_collisions:
		var size = col.get("shape_size")
		if size == null: size = Vector2(128, 128)
		var rect = Rect2(col.location - size / 2.0, size)
		if rect.has_point(pos):
			hit_candidates.append(col)
			
	if hit_candidates.size() > 0:
		for hit in hit_candidates:
			var hit_type = ""
			if hit is WinzoneData: hit_type = "Winzone"
			elif hit is DeathzoneData: hit_type = "Deathzone"
			elif hit is CarrotRemoverZoneData: hit_type = "Carrot Remover"
			elif hit is CaveZoneData: 
				var t = hit.get("cave_type")
				if t != null: hit_type = t
			elif hit is WindZoneData:
				var t = hit.get("wind_type")
				if t != null: hit_type = t
			elif hit is CameraZoomZoneData: hit_type = "Camera Zoom"
			else:
				var t = hit.get("environment_type")
				if t != null: hit_type = t
			
			if hit_type == target_type_str:
				target_data = hit
				break
				
		if target_data == null:
			target_data = hit_candidates[0]
			
		_remove_collision_visual(target_data)

func _remove_collision_visual(target_data: Resource):
	if target_data == _selected_object_data:
		_clear_selection()

	if target_data in GlobalProject.custom_environment_call_change_zone: GlobalProject.custom_environment_call_change_zone.erase(target_data)
	elif target_data in GlobalProject.cave_locations: GlobalProject.cave_locations.erase(target_data)
	elif target_data in GlobalProject.wind_locations: GlobalProject.wind_locations.erase(target_data)
	elif target_data in GlobalProject.camerazoom_locations: GlobalProject.camerazoom_locations.erase(target_data)
	elif target_data in GlobalProject.winzone_location: GlobalProject.winzone_location.erase(target_data)
	elif target_data in GlobalProject.deathzone_locations: GlobalProject.deathzone_locations.erase(target_data)
	elif target_data in GlobalProject.carrot_remover_locations: GlobalProject.carrot_remover_locations.erase(target_data)
		
	if _placed_visuals.has(target_data):
		var vis = _placed_visuals[target_data]
		if is_instance_valid(vis): vis.queue_free()
		_placed_visuals.erase(target_data)

func _spawn_collision_visual(data: Resource, type_string: String):
	var parent = sub_viewport if object_container == null else object_container
	var rect = ColorRect.new()
	
	var shape_size = data.get("shape_size")
	if shape_size == null: shape_size = Vector2(128, 128)
	
	rect.size = shape_size
	rect.position = data.location - (shape_size / 2.0)
	rect.color = _get_color_for_collision_type(type_string)
	rect.clip_contents = true 
	
	var lbl = Label.new()
	lbl.text = type_string
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	rect.add_child(lbl)
	
	parent.add_child(rect)
	_placed_visuals[data] = rect
	_update_visual(data)

func _get_color_for_collision_type(type_string: String) -> Color:
	if type_string.begins_with("Environment - Lava Dark"): return Color(0.6, 0.1, 0.0, 0.4)
	if type_string.begins_with("Environment - Lava"): return Color(1.0, 0.4, 0.0, 0.4)
	if type_string.begins_with("Environment - Desert"): return Color(0.8, 0.8, 0.2, 0.4)
	if type_string.begins_with("Environment - Ice"): return Color(0.2, 0.8, 1.0, 0.4)
	if type_string.begins_with("Environment - Grass"): return Color(0.2, 0.8, 0.2, 0.4)
	if type_string.begins_with("Cave"): return Color(0.4, 0.2, 0.1, 0.5)
	if type_string.begins_with("Wind"): return Color(0.6, 0.8, 0.9, 0.4)
	if type_string.begins_with("Camera"): return Color(0.8, 0.2, 0.8, 0.4)
	if type_string == "Winzone": return Color(1.0, 0.8, 0.0, 0.5)
	if type_string == "Deathzone": return Color(1.0, 0.0, 0.0, 0.5)
	if type_string == "Carrot Remover": return Color(0.9, 0.4, 0.0, 0.5) # Orange-ish Red
	return Color(0.5, 0.5, 0.5, 0.4)
#endregion

#region Basic Object Handling
func _handle_object_placement(event: InputEvent, object_type: String):
	if not sub_viewport: return
	if event is InputEventMouseButton and event.pressed:
		var mouse_pos = sub_viewport.get_mouse_position()
		var world_pos = sub_viewport.get_canvas_transform().affine_inverse() * mouse_pos
		
		var is_left_click = false
		var is_right_click = false
		if event.button_index == MOUSE_BUTTON_LEFT:
			if eraser_checkbox and eraser_checkbox.button_pressed: is_right_click = true
			else: is_left_click = true
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			is_right_click = true
		
		if is_left_click: 
			_save_undo_state()
			_place_object(world_pos, object_type)
		elif is_right_click: 
			_save_undo_state()
			_remove_object(world_pos, object_type)

func _place_object(pos: Vector2, object_type: String):
	var parent = sub_viewport if object_container == null else object_container
	var sprite = Sprite2D.new()
	var data: Resource = null
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	match object_type:
		"carrot":
			data = CarrotUpgradeData.new()
			data.location = pos
			GlobalProject.carrot_locations.append(data)
			sprite.name = "Carrot_Placeholder"
			sprite.scale = Vector2(0.8,0.8)
			if carrot_texture: sprite.texture = carrot_texture
		"coin":
			data = CoinData.new()
			data.location = pos
			GlobalProject.coin_locations.append(data)
			sprite.name = "Coin_Placeholder"
			sprite.scale = Vector2(0.6,0.6)
			if coin_texture: sprite.texture = coin_texture
		"enemy":
			data = EnemyData.new()
			data.location = pos
			GlobalProject.enemy_locations.append(data)
			sprite.name = "Enemy_Placeholder"
			if enemy_texture: sprite.texture = enemy_texture
	
	sprite.global_position = pos
	parent.add_child(sprite)
	_placed_visuals[data] = sprite
	
	_update_visual(data)

func _remove_object(pos: Vector2, object_type: String):
	var array_to_check: Array = []
	match object_type:
		"carrot": array_to_check = GlobalProject.carrot_locations
		"coin": array_to_check = GlobalProject.coin_locations
		"enemy": array_to_check = GlobalProject.enemy_locations
		
	var closest_dist = 32.0 
	var target_data: Resource = null
	
	for item in array_to_check:
		var dist = item.location.distance_to(pos)
		if dist < closest_dist:
			closest_dist = dist
			target_data = item
			
	if target_data != null:
		if target_data == _selected_object_data:
			_clear_selection()
		array_to_check.erase(target_data)
		if _placed_visuals.has(target_data):
			var sprite = _placed_visuals[target_data]
			if is_instance_valid(sprite):
				sprite.queue_free()
			_placed_visuals.erase(target_data)

func _get_tile_pos_under_mouse(tilemap: TileMapLayer) -> Vector2i:
	if not sub_viewport: return Vector2i.ZERO
	var mouse_pos = sub_viewport.get_mouse_position()
	var world_pos = sub_viewport.get_canvas_transform().affine_inverse() * mouse_pos
	return tilemap.local_to_map(tilemap.to_local(world_pos))

func _place_tile(tilemap: TileMapLayer, pos: Vector2i, source_id: int, atlas_coords: Vector2i, alt_tile: int = 0) -> void:
	if atlas_coords == Vector2i(-1, -1) or source_id == -1: tilemap.set_cell(pos, -1)
	else: tilemap.set_cell(pos, source_id, atlas_coords, alt_tile)

func _fill_rect(tilemap: TileMapLayer, start_pos: Vector2i, end_pos: Vector2i, source_id: int, atlas_coords: Vector2i, alt_tile: int = 0) -> void:
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

#region Properties Editing & Selection logic

func _update_visual(data: Resource):
	if not _placed_visuals.has(data): return
	var vis = _placed_visuals[data]
	if not is_instance_valid(vis): return
	
	var target_color = Color.WHITE
	
	if data is CarrotUpgradeData:
		if data.dash_count == 1: target_color = Color(0.639, 0.765, 0.0)
		elif data.dash_count == 0: target_color = Color(0.475, 0.569, 0.0)
		
	elif data is EnemyData:
		match data.tank_variant:
			1: target_color = Color(1.0, 0.549, 0.067)  # Lava
			2: target_color = Color(0.551, 0.512, 0.0)  # Desert
			3: target_color = Color(0.0, 0.559, 0.531)  # Ice
			4: target_color = Color(0.055, 0.682, 0.0)  # Grassy
			_: target_color = Color.WHITE
		_update_light(vis, data.emits_light)

	elif data is CoinData:
		var base_scale = 0.6
		var final_scale = data.coin_size
		
		if data.coin_variant == 1: # Big Yellow
			final_scale = data.coin_size * 1.5
		elif data.coin_variant == 2: # Blue / Special
			target_color = Color(0.0, 0.315, 0.355)
			
		vis.scale = Vector2(base_scale * final_scale, base_scale * final_scale)
		_update_light(vis, data.emits_light)
	
	# Only colorizing sprites (Rectangles already get colors applied internally via color property)
	if not vis is ColorRect:
		vis.set_meta("base_color", target_color)
		if _selected_object_data == data:
			vis.modulate = target_color.lerp(Color.AQUA, 0.6)
		else:
			vis.modulate = target_color

func _update_light(node: Node, emits: bool):
	var light = node.get_node_or_null("EditorLight")
	if emits:
		if not light:
			light = PointLight2D.new()
			light.name = "EditorLight"
			if light_texture: 
				light.texture = light_texture
			light.color = Color(1.0, 1.0, 0.8, 0.6) # Subtle editor visibility
			node.add_child(light)
	else:
		if light:
			light.queue_free()

func _handle_object_selection(event: InputEvent):
	if not sub_viewport: return
	var mouse_pos = sub_viewport.get_mouse_position()
	var world_pos = sub_viewport.get_canvas_transform().affine_inverse() * mouse_pos

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# 1. Check for Resize handle click FIRST
				if _selected_object_data != null and _selected_visual is ColorRect:
					var size = _selected_object_data.get("shape_size")
					if size != null:
						var rect = Rect2(_selected_object_data.location - size / 2.0, size)
						var br_corner = rect.end
						
						# Dynamically size the detection margin based on zoom to ensure clickability
						var detect_margin = max(16.0 / (editor_camera.zoom.x if editor_camera else 1.0), 16.0)
						var br_rect = Rect2(br_corner - Vector2(detect_margin, detect_margin), Vector2(detect_margin*2, detect_margin*2))
						
						if br_rect.has_point(world_pos):
							_save_undo_state()
							_is_resizing_object = true
							_resize_start_rect = rect
							return

				# 2. If not resizing, try to Select an object
				_select_object_at(world_pos)
				
				# 3. If an object is now selected, initiate drag logic
				if _selected_object_data != null:
					_save_undo_state()
					_is_dragging_object = true
					_drag_offset = _selected_object_data.location - world_pos
			else:
				# 4. Release Drag / Resize locks
				_is_dragging_object = false
				_is_resizing_object = false
				
	elif event is InputEventMouseMotion:
		# Process Mouse Movement for Resizing
		if _is_resizing_object and _selected_object_data != null:
			var new_end = world_pos
			var new_rect = Rect2(_resize_start_rect.position, new_end - _resize_start_rect.position).abs()
			new_rect.size.x = max(new_rect.size.x, 16)
			new_rect.size.y = max(new_rect.size.y, 16)
			
			_update_collision_size(_selected_object_data, new_rect.size)
			_update_object_pos(_selected_object_data, new_rect.get_center())
			_refresh_spinboxes()
			
		# Process Mouse Movement for Moving an object
		elif _is_dragging_object and _selected_object_data != null:
			var new_loc = world_pos + _drag_offset
			_update_object_pos(_selected_object_data, new_loc)
			_refresh_spinboxes()

func _refresh_spinboxes():
	if _selected_object_data == null: return
	if _prop_spinboxes.has("Pos X"): _prop_spinboxes["Pos X"].set_value_no_signal(_selected_object_data.location.x)
	if _prop_spinboxes.has("Pos Y"): _prop_spinboxes["Pos Y"].set_value_no_signal(_selected_object_data.location.y)
	
	var size = _selected_object_data.get("shape_size")
	if size != null:
		if _prop_spinboxes.has("Width"): _prop_spinboxes["Width"].set_value_no_signal(size.x)
		if _prop_spinboxes.has("Height"): _prop_spinboxes["Height"].set_value_no_signal(size.y)

func _select_object_at(pos: Vector2):
	var hit_candidates: Array = []
	
	# 1. Gather all small point-based objects within click radius
	for c in GlobalProject.carrot_locations:
		if c.location.distance_to(pos) <= 32.0: hit_candidates.append(c)
	for c in GlobalProject.coin_locations:
		if c.location.distance_to(pos) <= 32.0: hit_candidates.append(c)
	for e in GlobalProject.enemy_locations:
		if e.location.distance_to(pos) <= 32.0: hit_candidates.append(e)
		
	# 2. Gather all large area-based objects that contain the click point
	var all_cols = []
	all_cols.append_array(GlobalProject.custom_environment_call_change_zone)
	all_cols.append_array(GlobalProject.cave_locations)
	all_cols.append_array(GlobalProject.wind_locations)
	all_cols.append_array(GlobalProject.camerazoom_locations)
	all_cols.append_array(GlobalProject.winzone_location)
	all_cols.append_array(GlobalProject.deathzone_locations)
	all_cols.append_array(GlobalProject.carrot_remover_locations)
	
	for col in all_cols:
		var size = col.get("shape_size")
		if size == null: size = Vector2(128, 128)
		var rect = Rect2(col.location - size / 2.0, size)
		if rect.has_point(pos):
			hit_candidates.append(col)

	# If we hit nothing at all, clear and abort
	if hit_candidates.is_empty():
		_clear_selection()
		return

	var target_data: Resource = null
	
	# 3. Cycling Logic: 
	# If we already have something selected and it's in our hits, select the NEXT one in the list.
	if _selected_object_data != null and hit_candidates.has(_selected_object_data):
		var current_idx = hit_candidates.find(_selected_object_data)
		var next_idx = (current_idx + 1) % hit_candidates.size()
		target_data = hit_candidates[next_idx]
	else:
		# Otherwise, just pick the first hit item
		target_data = hit_candidates[0]

	# If the target is the exact same as what we already have selected (e.g., only 1 item clicked), just return.
	if target_data != null and target_data == _selected_object_data:
		return 

	# 4. Apply the new selection
	_clear_selection()

	if target_data != null:
		_selected_object_data = target_data
		_selected_visual = _placed_visuals.get(target_data)
		if is_instance_valid(_selected_visual): 
			# Safely highlight by lerping instead of outright overriding
			if not _selected_visual is ColorRect:
				var base_col = _selected_visual.get_meta("base_color", Color.WHITE)
				_selected_visual.modulate = base_col.lerp(Color.AQUA, 0.6)
			
			# Generate a little anchor handle for zones
			if _selected_visual is ColorRect:
				_selection_handle = ColorRect.new()
				_selection_handle.color = Color.WHITE
				_selection_handle.size = Vector2(16, 16)
				_selection_handle.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
				_selection_handle.position = _selected_visual.size - Vector2(16, 16)
				_selected_visual.add_child(_selection_handle)
				
		_build_property_ui(target_data)

func _clear_selection():
	if is_instance_valid(_selected_visual): 
		if not _selected_visual is ColorRect:
			var base_col = _selected_visual.get_meta("base_color", Color.WHITE)
			_selected_visual.modulate = base_col
			
		if is_instance_valid(_selection_handle):
			_selection_handle.queue_free()
			_selection_handle = null
			
	_selected_object_data = null
	_selected_visual = null
	
	if property_list:
		for child in property_list.get_children(): child.queue_free()
		var empty_lbl = Label.new()
		empty_lbl.text = "No object selected."
		property_list.add_child(empty_lbl)

func _build_property_ui(data: Resource):
	if not property_list: return
	for child in property_list.get_children(): child.queue_free()
	_prop_spinboxes.clear()
		
	var title = Label.new()
	title.add_theme_font_size_override("font_size", 20)
	property_list.add_child(title)
	
	if data is CarrotUpgradeData:
		title.text = "Carrot"
		_create_property_spinbox("Dash Count", data.dash_count, 0, 10, 1, func(val): 
			data.dash_count = int(val)
			_update_visual(data)
		)
		
	elif data is CoinData:
		title.text = "Coin"
		_create_property_checkbox("Emits Light", data.emits_light, func(val): 
			data.emits_light = val
			_update_visual(data)
		)
		var coin_opts = ["Normal", "Big Yellow", "Blue / Special"]
		_create_property_optionbutton("Coin Variant", coin_opts, data.coin_variant, func(val): 
			data.coin_variant = int(val)
			_update_visual(data)
		)
		_create_property_spinbox("Coin Size", data.coin_size, 0.1, 100.0, 0.1, func(val): 
			data.coin_size = val
			_update_visual(data)
		)
		
	elif data is EnemyData:
		title.text = "Enemy"
		var tank_opts = ["Normal", "Lava", "Desert", "Ice", "Grassy"]
		_create_property_optionbutton("Tank Variant", tank_opts, data.tank_variant, func(val): 
			data.tank_variant = int(val)
			_update_visual(data)
		)
		_create_property_spinbox("Speed", data.speed, 0.0, 500.0, 0.1, func(val): data.speed = val)
		_create_property_checkbox("Emits Light", data.emits_light, func(val): 
			data.emits_light = val
			_update_visual(data)
		)
		
	elif data is EnvironmentChangeZoneData or data is WinzoneData or data is DeathzoneData or data is CaveZoneData or data is WindZoneData or data is CameraZoomZoneData or data is CarrotRemoverZoneData:
		var title_text = ""
		if data is WinzoneData: title_text = "Winzone"
		elif data is DeathzoneData: title_text = "Deathzone"
		elif data is CarrotRemoverZoneData: title_text = "Carrot Remover"
		elif data is CameraZoomZoneData: 
			title_text = "Camera Zoom"
			var z_amt = data.get("zoom_amount")
			if z_amt == null: z_amt = 1.0
			_create_property_spinbox("Zoom Level", z_amt, 0.1, 10.0, 0.1, func(val): data.set("zoom_amount", val))
		elif data is CaveZoneData:
			var c_type = data.get("cave_type")
			title_text = c_type if c_type != null else "Cave"
		elif data is WindZoneData:
			var w_type = data.get("wind_type")
			title_text = w_type if w_type != null else "Wind"
		else:
			var e_type = data.get("environment_type")
			title_text = e_type if e_type != null else "Zone"
			
		title.text = str(title_text)
			
		var current_size = data.get("shape_size")
		if current_size == null: current_size = Vector2(128, 128)
		
		var safe_size_x = current_size.x
		var safe_size_y = current_size.y
		
		_create_property_spinbox("Width", safe_size_x, 16, 4096, 16, func(val): 
			var y_val = data.get("shape_size")
			if y_val == null: y_val = Vector2(128, 128)
			_update_collision_size(data, Vector2(val, y_val.y))
		)
		_create_property_spinbox("Height", safe_size_y, 16, 4096, 16, func(val): 
			var x_val = data.get("shape_size")
			if x_val == null: x_val = Vector2(128, 128)
			_update_collision_size(data, Vector2(x_val.x, val))
		)

	_create_property_spinbox("Pos X", data.location.x, -99999, 99999, 1, func(val): _update_object_pos(data, Vector2(val, data.location.y)))
	_create_property_spinbox("Pos Y", data.location.y, -99999, 99999, 1, func(val): _update_object_pos(data, Vector2(data.location.x, val)))

func _update_collision_size(data: Resource, new_size: Vector2):
	data.set("shape_size", new_size)
	if _placed_visuals.has(data):
		var vis = _placed_visuals[data]
		if is_instance_valid(vis):
			vis.size = new_size
			vis.position = data.location - (new_size / 2.0)
			if vis == _selected_visual and is_instance_valid(_selection_handle):
				_selection_handle.position = new_size - Vector2(16, 16)

func _update_object_pos(data: Resource, new_pos: Vector2):
	data.location = new_pos
	if _placed_visuals.has(data):
		var vis = _placed_visuals[data]
		if is_instance_valid(vis):
			if vis is ColorRect:
				var size = data.get("shape_size")
				if size == null: size = Vector2(128, 128)
				vis.position = new_pos - (size / 2.0)
			else: 
				vis.global_position = new_pos

func _create_property_spinbox(label_text: String, start_val: float, min_val: float, max_val: float, step: float, callback: Callable):
	var hbox = HBoxContainer.new()
	var lbl = Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var spin = SpinBox.new()
	spin.min_value = min_val
	spin.max_value = max_val
	spin.step = step
	spin.value = start_val
	spin.value_changed.connect(func(val):
		_save_undo_state()
		callback.call(val)
	)
	
	_prop_spinboxes[label_text] = spin
	
	hbox.add_child(lbl)
	hbox.add_child(spin)
	property_list.add_child(hbox)

func _create_property_optionbutton(label_text: String, options: Array, start_val: int, callback: Callable):
	var hbox = HBoxContainer.new()
	var lbl = Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var opt = OptionButton.new()
	for o in options: opt.add_item(o)
	opt.selected = start_val
	opt.item_selected.connect(func(idx):
		_save_undo_state()
		callback.call(idx)
	)
	
	hbox.add_child(lbl)
	hbox.add_child(opt)
	property_list.add_child(hbox)

func _create_property_checkbox(label_text: String, start_val: bool, callback: Callable):
	var hbox = HBoxContainer.new()
	var lbl = Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var chk = CheckBox.new()
	chk.button_pressed = start_val
	chk.toggled.connect(func(val):
		_save_undo_state()
		callback.call(val)
	)
	hbox.add_child(lbl)
	hbox.add_child(chk)
	property_list.add_child(hbox)
#endregion

#region Save & Load Functionality
func Call_Save(tilemap_to_save: TileMapLayer, is_main_tilemap: bool = true, call_final_save = true) -> void:
	if player: GlobalProject.player_spawn = player.global_position
	GlobalProject.Call_Save_TileMapLayer_As_Array(tilemap_to_save, is_main_tilemap)
	await get_tree().process_frame
	if call_final_save:
		GlobalProject.Call_Project_Save()

func Call_Load_Tilemap_Data():
	if main_tilemap: GlobalProject.Call_Load_TileMapLayer_Data(main_tilemap, GlobalProject.tilemap_array_main)
	if bg_tilemap: GlobalProject.Call_Load_TileMapLayer_Data(bg_tilemap, GlobalProject.tilemap_array_bg)

func Call_Rebuild_Object_Visuals():
	for key in _placed_visuals:
		if is_instance_valid(_placed_visuals[key]): _placed_visuals[key].queue_free()
	_placed_visuals.clear()
	
	var parent = sub_viewport if object_container == null else object_container
	
	for c in GlobalProject.carrot_locations:
		var s = Sprite2D.new()
		s.name = "Carrot_Placeholder"
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.scale = Vector2(0.8,0.8)
		if carrot_texture: s.texture = carrot_texture
		s.global_position = c.location
		parent.add_child(s)
		_placed_visuals[c] = s
		_update_visual(c)
		
	for c in GlobalProject.coin_locations:
		var s = Sprite2D.new()
		s.name = "Coin_Placeholder"
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.scale = Vector2(0.6,0.6)
		if coin_texture: s.texture = coin_texture
		s.global_position = c.location
		parent.add_child(s)
		_placed_visuals[c] = s
		_update_visual(c)
		
	for e in GlobalProject.enemy_locations:
		var s = Sprite2D.new()
		s.name = "Enemy_Placeholder"
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if enemy_texture: s.texture = enemy_texture
		s.global_position = e.location
		parent.add_child(s)
		_placed_visuals[e] = s
		_update_visual(e)
		
	for c in GlobalProject.custom_environment_call_change_zone:
		var etype = c.get("environment_type")
		if etype == null: etype = "Unknown Zone"
		_spawn_collision_visual(c, etype)
	for c in GlobalProject.cave_locations:
		var ctype = c.get("cave_type")
		if ctype == null: ctype = "Cave"
		_spawn_collision_visual(c, ctype)
	for c in GlobalProject.wind_locations:
		var wtype = c.get("wind_type")
		if wtype == null: wtype = "Wind"
		_spawn_collision_visual(c, wtype)
	for c in GlobalProject.camerazoom_locations:
		_spawn_collision_visual(c, "Camera Zoom")
	for w in GlobalProject.winzone_location:
		_spawn_collision_visual(w, "Winzone")
	for d in GlobalProject.deathzone_locations:
		_spawn_collision_visual(d, "Deathzone")
	for cr in GlobalProject.carrot_remover_locations:
		_spawn_collision_visual(cr, "Carrot Remover")
#endregion

#region Error Calls
func Call_Error_Occured(error_message = ""):
	if not err_panel or not err_timer or not err_text: return
	err_panel.show()
	err_text.text = ("Error Msg: " if error_message != "" else "") + error_message
	err_timer.start()

func Hide_Error():
	if err_panel: err_panel.hide()
#endregion

func Show_Environment(is_showing: bool):
	if is_showing == false: Call_Environment_Change(0, false)
	else: Call_Environment_Change(current_env_index, false)

func Call_Environment_Change(index: int = 0, update_current_index = true):
	if not environment: return
	if update_current_index: current_env_index = index

	var loaded_resource: Resource
	if active_light:
		if OS.has_feature("editor"): print_rich("[color=orange]Removed[/color] ", active_light)
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
	if loaded_resource is LevelEnvironmentData:
		current_env_data = loaded_resource
		apply_environment_settings()

func apply_environment_settings():
	if not current_env_data: return
	if current_env_data.world_env_normal: environment.environment = current_env_data.world_env_normal
