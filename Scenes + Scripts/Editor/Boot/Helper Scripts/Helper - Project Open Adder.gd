extends VBoxContainer


# The path to the folder containing all project folders
const PROJECT_DATA_DIR = "user://Project Data"

func _ready() -> void:
	# Populate the container when the node enters the scene tree
	load_project_buttons()

func load_project_buttons() -> void:
	# 1. Clear existing items if the function is called multiple times
	for child in get_children():
		child.queue_free()
		
	# 2. Open the Project Data directory
	var dir = DirAccess.open(PROJECT_DATA_DIR)
	if dir:
		# Iterate through all folders inside the directory
		for folder_name in dir.get_directories():
			var folder_path = PROJECT_DATA_DIR + "/" + folder_name
			var dat_file_path = folder_path + "/project_data.dat"
			
			# Ensure the .dat file exists inside the folder
			if FileAccess.file_exists(dat_file_path):
				_create_ui_for_project(folder_name, dat_file_path)
	else:
		push_warning("Could not access directory: ", PROJECT_DATA_DIR)

func _create_ui_for_project(folder_name: String, dat_file_path: String) -> void:
	# 1. Read the .dat file
	var file = FileAccess.open(dat_file_path, FileAccess.READ)
	var data = file.get_var()
	
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Project data is not a dictionary in: ", dat_file_path)
		return
		
	# 2. Extract Variables
	# Defaulting to the folder name if the project_name key is somehow missing
	var proj_name = data.get("project_name", folder_name) 
	
	# Assuming there might be a project_version key. Default to "1.0" if it doesn't exist
	var proj_version = data.get("project_version", "1.0") 
	var godot_ver_string = "Unknown"
	
	# Safely extract the Godot version string if the nested dictionary exists
	if data.has("godot_version") and typeof(data["godot_version"]) == TYPE_DICTIONARY:
		godot_ver_string = data["godot_version"].get("string", "Unknown")

	# 3. Create the UI Elements
	# We use a nested VBoxContainer to keep the button and label grouped together
	var item_container = VBoxContainer.new()
	item_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var btn = Button.new()
	btn.text = proj_name
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Connect the pressed signal, passing the project name as a bound argument
	btn.pressed.connect(_on_project_button_pressed.bind(proj_name))
	
	var lbl = Label.new()
	lbl.text = "Project Version: %s | Godot: %s" % [proj_version, godot_ver_string]
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 12) # Make it look like a subtitle
	lbl.modulate = Color(0.8, 0.8, 0.8) # Dim the text slightly
	
	# 4. Add the nodes to the scene tree
	item_container.add_child(btn)
	item_container.add_child(lbl)
	
	# Optional: Adding a MarginContainer to give spacing between project items
	var spacing_margin = MarginContainer.new()
	spacing_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacing_margin.add_theme_constant_override("margin_bottom", 10)
	spacing_margin.add_child(item_container)
	
	add_child(spacing_margin)

func _on_project_button_pressed(selected_project_name: String) -> void:
	# 1. Call the reset function on the singleton
	GlobalProject.Call_Reset_Variables(true)
	
	# 2. Update Editor globals with the normalized name
	GlobalEditor.project_name = selected_project_name
	GlobalEditor.project_name_normalized = selected_project_name.replace(" ", "")
	if OS.has_feature("editor"):
		print_rich("[color=cyan]Loading Project: ", selected_project_name)
	
	GlobalEditor.loading_scene_next_scene = "res://Scenes + Scripts/Editor/Main Editor.tscn"
	get_tree().change_scene_to_file("res://Scenes + Scripts/Editor/Loading/Editor Loading Scene.tscn")
