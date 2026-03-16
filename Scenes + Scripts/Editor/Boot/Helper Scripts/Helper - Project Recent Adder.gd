extends VBoxContainer

func _ready():
	# Wait a frame to ensure GlobalEditor arrays are properly populated
	await get_tree().process_frame
	await get_tree().process_frame
	populate_recent_projects()

func populate_recent_projects():
	# Clear out any placeholder children 
	for child in get_children():
		child.queue_free()

	# Loop through our loaded metadata array
	for meta in GlobalEditor.recently_opened:
		if not meta is ProjectMetaData:
			continue
			
		# Container to hold the button and the info labels below it
		var project_vbox = VBoxContainer.new()
		project_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# The core open button
		var btn = Button.new()
		
		
		# 1. Create a reusable style for the "Normal" state
		var style_normal = StyleBoxFlat.new()
		style_normal.bg_color = Color(0.451, 0.212, 0.0, 1.0) # Your brown color
		style_normal.set_corner_radius_all(4) # Optional: rounded corners

		# 2. Create a style for the "Hover" state (usually a bit lighter)
		var style_hover = style_normal.duplicate()
		style_hover.bg_color = style_normal.bg_color.lightened(0.2)

		# 3. Apply them to the button
		btn.add_theme_stylebox_override("normal", style_normal)
		btn.add_theme_stylebox_override("hover", style_hover)
		btn.add_theme_stylebox_override("pressed", style_normal) # Or make it darker

		# If you want the text to be a specific color (e.g., White)
		btn.add_theme_color_override("font_color", Color.WHITE)
		
		
		
		btn.text = meta.project_name
		
		# Bind the metadata to our custom pressed function
		btn.pressed.connect(_on_recent_project_pressed.bind(meta))
		
		# HBox to hold the left and right labels underneath
		var hbox = HBoxContainer.new()
		
		# Left Label - showing the Project Ver and Date (since you requested both)
		var left_lbl = Label.new()
		left_lbl.text = "Date: " + meta.creation_date + " | Ver: " + meta.project_version
		left_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL # Pushes right side away
		left_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		# Right Label - showing the Godot Ver
		var right_lbl = Label.new()
		right_lbl.text = "Godot: " + meta.godot_version
		right_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		
		# Construct the UI hierarchy
		hbox.add_child(left_lbl)
		hbox.add_child(right_lbl)
		
		project_vbox.add_child(btn)
		project_vbox.add_child(hbox)
		
		# Wrapping everything in a margin container gives us some visual padding 
		# between projects in the list
		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_bottom", 12)
		margin.add_child(project_vbox)
		
		add_child(margin)


# Matches the core logic of "_on_confirmation_dialog_confirmed" from the Boot Script
func _on_recent_project_pressed(meta: ProjectMetaData):
	GlobalProject.Call_Reset_Variables(true)
	GlobalEditor.project_name = meta.project_name
	GlobalEditor.project_name_normalized = get_safe_filename(GlobalEditor.project_name)
	
	print_rich("[color=DARK_SLATE_GRAY]Loaded Recent Project Name as [color=DARK_OLIVE_GREEN]", GlobalEditor.project_name)
	
	GlobalEditor.loading_scene_next_scene = "res://Scenes + Scripts/Editor/Main Editor.tscn"
	get_tree().change_scene_to_file("res://Scenes + Scripts/Editor/Loading/Editor Loading Scene.tscn")

# Need this safe filename helper function here as well
func get_safe_filename(input_text: String) -> String:
	var regex = RegEx.new()
	regex.compile("[^a-zA-Z0-9_-]") 
	var safe_name = regex.sub(input_text, "", true)
	return safe_name.strip_edges()
