extends PanelContainer
# Script handles all the editor buttons (file, options, export, help)

@onready var slide_animations: AnimationPlayer = $"../../Slide_Animations"
@onready var control_menu_dropdown: Control = $"../../Control_Menu_Dropdown"

@export var main_editor: VSplitContainer
@export var main_file_button: Button
@export var main_options_button: Button
@export var main_export_button: Button

func _ready():
	if not main_file_button: print_rich("[color=red]Cannot Find FileButton")

	if not main_options_button: print_rich("[color=red]Cannot Find OptionsButton")

	if not main_export_button: print_rich("[color=red]Cannot Find ExportButton")

	if control_menu_dropdown: control_menu_dropdown.hide()
	else: print_rich("[color=red]Cannot Find ControlDropdown_Menu")

func _on_file_button_pressed() -> void:
	Open_Menu(1)

func _on_options_button_pressed() -> void:
	Open_Menu(2)

func _on_export_button_pressed() -> void:
	Open_Menu(3)

func _on_help_button_pressed() -> void:
	OS.shell_open(GlobalEditor.wiki_loc)


func _on_back_button_pressed() -> void:
	Close_Menu()

func Open_Menu(menu_choice: int):
	GlobalEditor.can_edit_viewport = false
	
	control_menu_dropdown.show()
	slide_animations.play("Slide_In_Content")
	
	match menu_choice:
		1:
			if main_file_button:
				main_file_button.grab_focus()
		2:
			if main_options_button:
				main_options_button.grab_focus()
		3:
			if main_export_button:
				main_export_button.grab_focus()
	print_rich("Control Menu: Select Button [color=cyan]", menu_choice, " (Left To Right)")
	if main_editor:
		await slide_animations.animation_finished
		main_editor.hide()

func Close_Menu():
	GlobalEditor.can_edit_viewport = true
	main_editor.show()
	slide_animations.play("Slide_Out_Content")
	await slide_animations.animation_finished
	control_menu_dropdown.hide()
