extends VBoxContainer

@export var enable_embeded_only = false
# The path to the folder containing all project folders
@export var PROJECT_DATA_DIR = "user://Project Data"

func _ready() -> void:
	if enable_embeded_only: GlobalProject.is_loading_embeded = true
	# Populate the container when the node enters the scene tree
	load_project_buttons()

func Return_To_Title():
	get_tree().change_scene_to_file("res://Scenes + Scripts/Editor/Boot/Editor Boot Scene.tscn")

func load_project_buttons() -> void:
	# 1. Clear existing items if the function is called multiple times
	for child in get_children():
		child.queue_free()
		
	# Clean the path to prevent trailing slash issues in the virtual filesystem
	var safe_dir_path = PROJECT_DATA_DIR.trim_suffix("/")
		
	# 2. Open the Project Data directory
	var dir = DirAccess.open(safe_dir_path)
	if dir:
		# Prevent picking up navigation folders like "." or ".." 
		dir.include_hidden = false
		dir.include_navigational = false
		
		# Iterate through all folders inside the directory
		for folder_name in dir.get_directories():
			# Pass the folder name directly to create the UI
			_create_ui_for_project(folder_name)
	else:
		var err = DirAccess.get_open_error()
		push_warning("Could not access directory: ", safe_dir_path, " | Error code: ", err)
		push_warning("NOTE: If this is an exported build, ensure '", safe_dir_path, "' is added to your Export Filters!")

func _create_ui_for_project(folder_name: String) -> void:
	# 1. Create the UI Elements
	# We use a VBoxContainer to keep things organized in case you want to add elements later
	var item_container = VBoxContainer.new()
	item_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var btn = Button.new()
	btn.text = folder_name # Name the button using the folder name
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	# Connect the pressed signal, passing the folder name as the bound argument
	btn.pressed.connect(_on_project_button_pressed.bind(folder_name))
	
	# 2. Add the node to the container
	item_container.add_child(btn)
	
	# 3. Adding a MarginContainer to give spacing between project items
	var spacing_margin = MarginContainer.new()
	spacing_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacing_margin.add_theme_constant_override("margin_bottom", 10)
	spacing_margin.add_child(item_container)
	
	# Add the final margin container to this script's VBoxContainer
	add_child(spacing_margin)

func _on_project_button_pressed(selected_project_name: String) -> void:
	# 1. Call the reset function on the singleton
	GlobalProject.Call_Reset_Variables(true)
	
	# 2. Update Editor globals with the folder name
	GlobalEditor.project_name = selected_project_name
	
	# Use identical normalization logic to the boot script
	GlobalEditor.project_name_normalized = get_safe_filename(selected_project_name)
	
	# --- RECENT PROJECTS SAVE LOGIC ---
	var new_meta = ProjectMetaData.new()
	new_meta.project_name = GlobalEditor.project_name
	
	# Format date as mm/dd/yy (Treating as "Last Opened" date)
	var date = Time.get_datetime_dict_from_system()
	var year_str = str(date["year"])
	var year_short = year_str.substr(year_str.length() - 2, 2)
	new_meta.creation_date = "%02d/%02d/%s" % [date["month"], date["day"], year_short]
	
	# Format Godot version
	var v_info = Engine.get_version_info()
	new_meta.godot_version = "%d.%d.%d" % [v_info.major, v_info.minor, v_info.patch]
	
	# Prevent duplicate project entries by removing older versions of the same name
	for i in range(GlobalEditor.recently_opened.size() - 1, -1, -1):
		if GlobalEditor.recently_opened[i].project_name == new_meta.project_name:
			GlobalEditor.recently_opened.remove_at(i)
	
	GlobalEditor.recently_opened.insert(0, new_meta) # Add to the top of the list
	
	if GlobalEditor.recently_opened.size() > 10: # Keep maximum limit to 10
		GlobalEditor.recently_opened.resize(10)
		
	# Store and save changes
	if not GlobalProject.is_loading_embeded:
		if GlobalEditor.config and not GlobalEditor.recently_opened.is_empty():
			GlobalEditor.config.set_value("Editor", "recently_opened", GlobalEditor.recently_opened)
			GlobalEditor.Call_Config_Save()
		else: 
			print_rich("[color=orange]Project Open:[/color] Experienced weird error as config was not loaded. Current level was [color=red]NOT[/color] added to recent list. [color=yellow]Attempting to resolve..."); 
			GlobalEditor.Call_Config_Load(); 
			await get_tree().process_frame;
	
	# ----------------------------------
	
	if OS.has_feature("editor"):
		print_rich("[color=cyan]Loading Project: ", selected_project_name)
	
	GlobalEditor.loading_scene_next_scene = "res://Scenes + Scripts/Editor/Main Editor.tscn"
	get_tree().change_scene_to_file("res://Scenes + Scripts/Editor/Loading/Editor Loading Scene.tscn")

# Added safe filename helper to keep name normalization consistent across all UI
func get_safe_filename(input_text: String) -> String:
	var regex = RegEx.new()
	regex.compile("[^a-zA-Z0-9_-]") 
	var safe_name = regex.sub(input_text, "", true)
	return safe_name.strip_edges()
