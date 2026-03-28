extends VBoxContainer
class_name Tile_Palleter

@export var main_tilemap: TileMapLayer
@export var bg_tilemap: TileMapLayer

@export var main_tilemap_check_button: CheckButton
@export var rectangle_check_button: CheckButton

@export_group("Palette Settings")
## The size used for standard square tiles
@export var default_tile_size: Vector2 = Vector2(18, 18)
## The size used for door segments (prevents compression)
@export var door_tile_size: Vector2 = Vector2(48, 12)

@export_category("Script Connections")
@export var editor_script: Editor_Script

# TileMap State
var active_tilemap: TileMapLayer
var selected_tile_source_id = -1
var selected_tile_alternative = 0
var is_box_placement_mode: bool = false

# Define our sections with their start/end vectors. 
var sections = [
	{"name": "Lava Tiles", "start": Vector2i(0, 0), "end": Vector2i(9, 9)},
	{"name": "Desert Tiles", "start": Vector2i(11, 0), "end": Vector2i(20, 9)},
	{"name": "Ice Tiles", "start": Vector2i(22, 0), "end": Vector2i(31, 9)},
	{"name": "Grassland Tiles", "start": Vector2i(0, 11), "end": Vector2i(9, 20)},
	{"name": "Clouds Tiles", "start": Vector2i(11, 11), "end": Vector2i(20, 20)},
	{"name": "Cave Tiles", "start": Vector2i(22, 11), "end": Vector2i(31, 20)},
	{"name": "Background Tiles", "start": Vector2i(11, 22), "end": Vector2i(20, 31)},
	{"name": "Door Tiles", "start": Vector2i(22, 22), "end": Vector2i(25, 31), "is_door": true},
	{"name": "Misc Tiles", "start": Vector2i(0, 22), "end": Vector2i(9, 31)}
]

func _ready():
	if main_tilemap:
		active_tilemap = main_tilemap
	Tilemap_Selected(0)

func Tilemap_Selected(index: int):
	# index 0 = Source ID 1, index 1 = Source ID 2, etc.
	selected_tile_source_id = index + 1
	if editor_script:
		editor_script.tileset_source_id = selected_tile_source_id
	_populate_palette()

func _populate_palette():
	for child in get_children():
		child.queue_free()
		
	if not active_tilemap or not active_tilemap.tile_set:
		return
		
	var tile_set = active_tilemap.tile_set
	if not tile_set.has_source(selected_tile_source_id):
		return
		
	var source = tile_set.get_source(selected_tile_source_id)
	
	if source is TileSetAtlasSource:
		var atlas_source = source as TileSetAtlasSource
		var atlas_texture = atlas_source.texture
		
		# Gather all tiles
		var all_tiles = []
		for i in range(atlas_source.get_tiles_count()):
			var atlas_coords = atlas_source.get_tile_id(i)
			if atlas_coords == Vector2i(11, 31): continue 
			all_tiles.append(atlas_coords)
			
		var is_first_section_ui = true
		
		# We use a counter for generic naming (Tileset #1, Tileset #2...)
		var generic_section_index = 1
		
		for section in sections:
			var section_tiles = []
			for coords in all_tiles:
				if coords.x >= section.start.x and coords.x <= section.end.x and \
				   coords.y >= section.start.y and coords.y <= section.end.y:
					section_tiles.append(coords)
			
			if section_tiles.size() == 0: continue
				
			# Separator
			if not is_first_section_ui:
				add_child(HSeparator.new())
				
			# Label
			var label = Label.new()
			
			# Logic for Dynamic Naming:
			# If the source ID is 1, use the specific names. 
			# Otherwise, use generic numbering.
			if selected_tile_source_id == 1:
				label.text = section.name
			else:
				label.text = "Tileset Split #" + str(generic_section_index)
			
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			add_child(label)
			
			var is_door_section = section.has("is_door") and section["is_door"]
			
			# Container Logic
			var tile_container: Container
			if is_door_section:
				tile_container = VBoxContainer.new()
				tile_container.add_theme_constant_override("separation", 0) # Seamless stack
			else:
				tile_container = HFlowContainer.new()
				
			tile_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			add_child(tile_container)
			
			for atlas_coords in section_tiles:
				var tile_region = atlas_source.get_tile_texture_region(atlas_coords)
				var tile_icon = AtlasTexture.new()
				tile_icon.atlas = atlas_texture
				tile_icon.region = tile_region
				
				var btn = Button.new()
				# Styling
				btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
				btn.add_theme_stylebox_override("hover", StyleBoxFlat.new())
				btn.add_theme_stylebox_override("pressed", StyleBoxFlat.new())
				btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				btn.icon = tile_icon
				btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				
				# Handle Sizing and Alignment
				if is_door_section:
					btn.custom_minimum_size = door_tile_size
					btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
					btn.expand_icon = true 
				else:
					btn.custom_minimum_size = default_tile_size
				
				btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
				btn.focus_mode = Control.FOCUS_NONE 
				btn.pressed.connect(_on_tile_button_pressed.bind(atlas_coords))
				
				tile_container.add_child(btn)
			
			is_first_section_ui = false
			generic_section_index += 1

func _on_tile_button_pressed(atlas_coords: Vector2i):
	GlobalProject.selected_tile_atlas_coords = atlas_coords
	if OS.has_feature("editor"):
		print("Tile Selected: ", atlas_coords)
