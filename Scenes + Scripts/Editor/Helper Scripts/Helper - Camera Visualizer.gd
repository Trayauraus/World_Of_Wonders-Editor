extends SpinBox

@export var player_sprite: Sprite2D

# We'll create a custom Node2D to handle drawing the purple box
var debug_drawer: Node2D

func _ready():
	# Setup the debug drawer when the scene starts
	if player_sprite:
		# Explicitly connect the SpinBox signal to our function
		value_changed.connect(_on_spinner_value_changed)
		
		debug_drawer = Node2D.new()
		debug_drawer.name = "CameraDebugOutline"
		
		# Visibility layers in Godot use a bitmask. Layer 5 = 16.
		debug_drawer.visibility_layer = 16 
		
		# Connect the drawing signal to our custom drawing function
		debug_drawer.draw.connect(_on_debug_draw)
		
		# Add the drawer as a child of the sprite so it automatically follows the player
		player_sprite.add_child(debug_drawer)
		
		# Initial trigger
		_on_spinner_value_changed(value)

func _on_spinner_value_changed(new_value: float):
	# Print to console for debugging as requested
	GlobalProject.camera_zoom = new_value
	print("Camera Debug Zoom: ", new_value)
	
	if is_instance_valid(debug_drawer):
		# queue_redraw() tells Godot to fire the "draw" signal on the next frame
		debug_drawer.queue_redraw()

func _on_debug_draw():
	# Prevent division by zero
	if value <= 0: 
		return 
	
	# Get Project Settings base resolution
	var base_width = ProjectSettings.get_setting("display/window/size/viewport_width")
	var base_height = ProjectSettings.get_setting("display/window/size/viewport_height")
	var base_resolution = Vector2(base_width, base_height)
	
	# CORRECTION FACTOR:
	# Based on tests: Editor 2.0 == Game 2.4 (Ratio of 1.2)
	# If the previous version was too small, we divide the zoom to expand the box.
	var correction_ratio = 1.2
	var effective_zoom = value / correction_ratio
	
	# Camera zoom works inversely to visual size
	var camera_view_size = base_resolution / effective_zoom
	
	# Create a rectangle centered exactly over the player's origin
	var rect = Rect2(-camera_view_size / 2.0, camera_view_size)
	
	# Define a transparent purple color. 
	var transparent_purple = Color(0.631, 0.129, 0.941, 0.725) 
	
	# Draw the rectangle: rect, color, filled (false), line_width
	debug_drawer.draw_rect(rect, transparent_purple, false, 2.5)
