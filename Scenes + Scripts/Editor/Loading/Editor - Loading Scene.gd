extends Control

@export var err_button: Button
@export var err_label: Label
@export var load_label: Label

@onready var progress_bar: ProgressBar = $Panel/ScrollContainer/VBox/VBox_Status/ProgressBar


func _ready() -> void:
	# Hide the error button initially and connect its pressed signal via code
	err_button.hide(); err_label.hide()
	err_button.pressed.connect(_on_err_button_pressed)
	
	# Give the UI a fraction of a second to render before the main thread freezes to load data
	await get_tree().create_timer(0.1).timeout
	
	_load_project_and_transition()

func _load_project_and_transition() -> void:
	# 1. Verify that we actually have a project name loaded into the GlobalEditor
	if GlobalEditor.project_name_normalized == null or GlobalEditor.project_name_normalized == "":
		_trigger_error("Loading Screen: Project name is missing or invalid!")
		return
		
	print_rich("Loading Screen: Starting load for project [color=orange]'", GlobalEditor.project_name_normalized, "'")
	
	# 2. Call the load function
	# Note: Because this isn't on a background thread, the game will wait here until it finishes reading the files.
	GlobalProject.Call_Project_Load(GlobalEditor.project_name_normalized)
	
	# Optional: Set progress bar to full visually once the load function finishes
	if progress_bar:
		progress_bar.value = 100
		
	# Pause for half a second so the user can see it hit 100% before flashing to the next scene
	await get_tree().create_timer(0.5).timeout
	
	# 3. Validate next scene and transition
	if GlobalEditor.loading_scene_next_scene != null and GlobalEditor.loading_scene_next_scene != "":
		var error_code = get_tree().change_scene_to_file(GlobalEditor.loading_scene_next_scene)
		
		if error_code == OK:
			if OS.has_feature("editor"):
				print_rich("Loading Screen: Changing scene to [color=orange]", GlobalEditor.loading_scene_next_scene)
		else:
			_trigger_error("Loading Screen: Failed to change scene! Godot Error Code: " + str(error_code))
	else:
		_trigger_error("Loading Screen: Next scene NOT FOUND")

func _trigger_error(message: String) -> void:
	print_rich("[color=red]" + message + "[/color]")
	err_button.show()
	err_label.show()
	load_label.text = "Load Failed!!!"
	if GlobalEditor.loading_scene_next_scene: err_label.text = "Next Scene Not Found"
	elif GlobalEditor.project_name_normalized == null or GlobalEditor.project_name_normalized == "": err_label.text = "Project Name (Normalized) Not Found"

func _on_err_button_pressed() -> void:
	# Instantly bounce back to the Boot scene if the user clicks the error button
	get_tree().change_scene_to_file("res://Scenes + Scripts/Editor/Boot/Editor Boot Scene.tscn")
