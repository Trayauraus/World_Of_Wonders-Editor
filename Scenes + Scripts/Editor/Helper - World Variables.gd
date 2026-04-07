## PropertiesUIController.gd
## Attach this to the VBoxContainer (Properties Panel)
extends VBoxContainer

@export_group("Player Settings")
@export var default_cave_button: Button
@export var ice_physics_button: Button

@export var force_light_button: Button

@export_group("Player References")
@export var player_light: Light2D

func _ready() -> void:
	# Initial Load from Global
	update_ui_from_global()
	if player_light:
		player_light.enabled = GlobalProject.force_light
	
	# Connect signals for the toggles
	if default_cave_button:
		default_cave_button.pressed.connect(_on_default_cave_pressed)
	
	if ice_physics_button:
		ice_physics_button.pressed.connect(_on_ice_physics_pressed)
	
	if force_light_button:
		force_light_button.pressed.connect(_on_force_light_pressed)

## Call this whenever a level is loaded to refresh the UI buttons
func update_ui_from_global() -> void:
	if ice_physics_button:
		_set_button_visual(ice_physics_button, GlobalProject.ice_physics)
	
	if force_light_button:
		_set_button_visual(force_light_button, GlobalProject.force_light)

func _on_default_cave_pressed():
	GlobalProject.is_cave_default = !GlobalProject.is_cave_default
	_set_button_visual(default_cave_button, GlobalProject.is_cave_default)
	print("Default Cave: ", GlobalProject.is_cave_default)

func _on_ice_physics_pressed() -> void:
	GlobalProject.ice_physics = !GlobalProject.ice_physics
	_set_button_visual(ice_physics_button, GlobalProject.ice_physics)
	print("Ice Physics: ", GlobalProject.ice_physics)

func _on_force_light_pressed() -> void:
	GlobalProject.force_light = !GlobalProject.force_light
	_set_button_visual(force_light_button, GlobalProject.force_light)
	print("Force Light: ", GlobalProject.force_light)
	if player_light:
		player_light.enabled = GlobalProject.force_light

## Simple helper to change button style/color based on toggle state
func _set_button_visual(btn: Button, active: bool) -> void:
	# You can toggle themes, colors, or icons here
	if active:
		btn.modulate = Color.WHITE # Or a "highlight" color
	else:
		btn.modulate = Color(0.6, 0.6, 0.6) # Dimmed
