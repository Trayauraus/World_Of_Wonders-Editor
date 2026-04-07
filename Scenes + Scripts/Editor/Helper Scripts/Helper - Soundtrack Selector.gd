extends Button

@export var level_soundtrack_label: Label

func _ready():
	var custom_stream = GlobalProject.Get_Custom_Music_Stream()
	if custom_stream != null:
		if level_soundtrack_label:
			# Use the variable saved in the Global script
			level_soundtrack_label.text = "🎵 " + GlobalProject.custom_music_name

func _pressed():
	# Define the file filters (extensions allowed)
	var filters = PackedStringArray(["*.ogg ; OGG Vorbis", "*.mp3 ; MP3 Audio"])
	
	# This opens the ACTUAL system dialog (Windows/Mac/Linux native)
	DisplayServer.file_dialog_show(
		"Import Background Music", # Title
		"",                         # Initial directory (empty = default)
		"",                         # Default filename
		false,                      # Multiple selection (false)
		DisplayServer.FILE_DIALOG_MODE_OPEN_FILE, 
		filters,
		_on_native_file_selected    # The callback function below
	)

func _on_native_file_selected(status: bool, selected_paths: PackedStringArray, _selected_filter_index: int):
	if status and selected_paths.size() > 0:
		var path = selected_paths[0]
		if GlobalProject.Store_Custom_Music_From_Path(path):
			if level_soundtrack_label:
				level_soundtrack_label.text = "🎵 " + GlobalProject.custom_music_name

func _on_file_dialog_file_selected(path: String) -> void:
	if GlobalProject.Store_Custom_Music_From_Path(path):
		if level_soundtrack_label:
			level_soundtrack_label.text = "🎵 " + GlobalProject.custom_music_name
