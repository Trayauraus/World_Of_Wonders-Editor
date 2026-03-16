extends Container

# Export variables for the toggle buttons (TG_ prefix)
@export_group("Toggle Options")
@export var tg_bg_button: Button
@export var tg_bg_tiles_button: Button
@export var tg_env_button: Button
@export var tg_collision_button: Button

@export var background: Sprite2D

func _ready() -> void:
	# Wait a frame to ensure GlobalProject is initialized
	await get_tree().process_frame
	_initialize_buttons()

## Setup button states from GlobalProject and connect signals
func _initialize_buttons() -> void:
	# Array of pairs: [Button Reference, Global Variable Name]
	# Mapping the TG buttons to their respective global settings
	var toggles = [
		[tg_bg_button, "show_background"],
		[tg_bg_tiles_button, "hide_bg_tiles"],
		[tg_env_button, "show_env"],
		[tg_collision_button, "show_collision"]
	]
	
	for data in toggles:
		var btn = data[0]
		var property_name = data[1]
		
		if is_instance_valid(btn):
			btn.toggle_mode = true
			
			# Load initial state from GlobalProject
			if property_name in GlobalProject:
				btn.button_pressed = GlobalProject.get(property_name)
			
			# Connect signal to update GlobalProject
			btn.toggled.connect(_on_button_toggled.bind(property_name))
		else:
			push_warning("OptionsContainer: Button for " + property_name + " is not assigned.")

## Callback triggered when any linked button is toggled
func _on_button_toggled(is_pressed: bool, property_name: String) -> void:
	if property_name in GlobalProject:
		# Update the global state
		GlobalProject.set(property_name, is_pressed)
		
		# Call global update/save logic if it exists
		if GlobalProject.has_method("on_settings_changed"):
			GlobalProject.on_settings_changed(property_name, is_pressed)
		
		if OS.has_feature("editor"): print_rich("OptionsContainer: [color=orange]", property_name, " set to [color=yellow]", is_pressed)
		
		
		if property_name == "show_background" and background: background.visible = is_pressed
