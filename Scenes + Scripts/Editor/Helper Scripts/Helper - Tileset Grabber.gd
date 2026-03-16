extends GridContainer
class_name Tile_Palleter

@export var main_tilemap: TileMapLayer
@export var bg_tilemap: TileMapLayer

@export var main_tilemap_check_button: CheckButton
@export var rectangle_check_button: CheckButton

@export_category("Script Connections")
@export var editor_script: Editor_Script

# TileMap State
var active_tilemap: TileMapLayer
var selected_tile_source_id = -1
var selected_tile_alternative = 0
var is_box_placement_mode: bool = false

func _ready():
	# Make sure an active tilemap is assigned before populating
	if main_tilemap:
		active_tilemap = main_tilemap
		
	Tilemap_Selected(0)

func Tilemap_Selected(index: int):
	match index:
		0:
			selected_tile_source_id = 4
		1:
			selected_tile_source_id = 5
		2:
			selected_tile_source_id = 6
	
	if editor_script:
		editor_script.tileset_source_id = selected_tile_source_id
	print("Selected tilemap source id ", selected_tile_source_id)
	
	# Update the palette whenever a new source is selected
	_populate_palette()

func _populate_palette():
	# 1. Clear out any existing buttons from the grid
	for child in get_children():
		child.queue_free()
		
	# Ensure we have a valid tilemap and tileset to read from
	if not active_tilemap or not active_tilemap.tile_set:
		push_warning("Active Tilemap or TileSet is missing!")
		return
		
	var tile_set = active_tilemap.tile_set
	
	if not tile_set.has_source(selected_tile_source_id):
		push_warning("Source ID " + str(selected_tile_source_id) + " not found in TileSet.")
		return
		
	var source = tile_set.get_source(selected_tile_source_id)
	
	# 2. Check if the source is an Atlas Source (standard tiles)
	if source is TileSetAtlasSource:
		var atlas_source = source as TileSetAtlasSource
		var atlas_texture = atlas_source.texture
		
		# 3. Loop through every tile created in this atlas source
		for i in range(atlas_source.get_tiles_count()):
			var atlas_coords = atlas_source.get_tile_id(i)
			var tile_region = atlas_source.get_tile_texture_region(atlas_coords)
			
			# Create an AtlasTexture to crop the image to just this tile
			var tile_icon = AtlasTexture.new()
			tile_icon.atlas = atlas_texture
			tile_icon.region = tile_region
			
			# Create a new Button to hold the tile image
			var btn = Button.new()
			
			btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
			btn.add_theme_stylebox_override("hover", StyleBoxFlat.new())
			btn.add_theme_stylebox_override("pressed", StyleBoxFlat.new())
			btn.add_theme_stylebox_override("hover_pressed", StyleBoxFlat.new())
			btn.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
			btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
			btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			btn.icon = tile_icon
			btn.custom_minimum_size = Vector2(16,16) #tile_region.size # Size button to fit tile
			#print(btn.custom_minimum_size)
			
			# Keep the button visuals neat
			btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			btn.focus_mode = Control.FOCUS_NONE # Optional: prevents UI focus boxes
			
			# 4. Connect the pressed signal to our selection function.
			# We use .bind() to pass the specific atlas_coords of this tile to the function.
			btn.pressed.connect(_on_tile_button_pressed.bind(atlas_coords))
			
			# Add the button as a child of this GridContainer
			add_child(btn)

func _on_tile_button_pressed(atlas_coords: Vector2i):
	# Save the location to your global editor singleton
	GlobalProject.selected_tile_atlas_coords = atlas_coords
	if OS.has_feature("editor"):
		print("Tile Selected! Atlas Coords: ", atlas_coords, " Source ID: ", selected_tile_source_id)
