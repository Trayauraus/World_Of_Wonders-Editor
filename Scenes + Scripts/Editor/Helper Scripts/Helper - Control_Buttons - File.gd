extends PanelContainer

@export var main_node: Editor_Script
@export var main_tileset: TileMapLayer
@export var bg_tileset: TileMapLayer

@export var confirm_label: Label
@export var project_ver: Label

@export var dialogue_box: AcceptDialog


@export var open_project: Control
@export var slider_animations: AnimationPlayer


@export var click_timer: Timer

var click_count = 0
var temp_name_hold = ""

func _ready():
	if project_ver: project_ver.text = "Project Version: " + ProjectSettings.get_setting("application/config/version")
	if dialogue_box: dialogue_box.hide()


func Call_New_Project():
	if dialogue_box: dialogue_box.show()

func LEdit_Text_changed(new_text: String) -> void:
	temp_name_hold = new_text

func _on_confirmation_dialog_confirmed() -> void:
	if temp_name_hold == null or temp_name_hold == "": 
		print_rich("[color=red]Err On New Proj Confrm")
		if main_node: main_node.Call_Error_Occured("Cannot Load New Project")
		return
	GlobalProject.Call_Reset_Variables()
	
	GlobalEditor.project_name = temp_name_hold
	print_rich("[color=DARK_SLATE_GRAY]Saved Project Name as [color=DARK_OLIVE_GREEN]", GlobalEditor.project_name)
	GlobalEditor.project_name_normalized = get_safe_filename(GlobalEditor.project_name)
	if OS.has_feature("editor"):
		print_rich("Saved Normalized Project Name as [color=green]", GlobalEditor.project_name_normalized)
	
	GlobalEditor.loading_scene_next_scene = "res://Scenes + Scripts/Editor/Main Editor.tscn"
	get_tree().change_scene_to_file("res://Scenes + Scripts/Editor/Loading/Editor Loading Scene.tscn")

func get_safe_filename(input_text: String) -> String:
	var regex = RegEx.new()
	regex.compile("[^a-zA-Z0-9_-]") 
	
	var safe_name = regex.sub(input_text, "", true) # Replace matches with nothing
	return safe_name.strip_edges()


func Call_Open_Project():
	if open_project:
		open_project.show()
		if slider_animations:
			slider_animations.play("Slide_Panel_In")

func Call_Back_From_Open():
	if open_project:
		if slider_animations:
			slider_animations.play("Slide_Panel_Out")
		await slider_animations.animation_finished
		open_project.hide()

func Call_Save_Project():
	print("File Container: Save Called")
	if main_node and main_tileset and bg_tileset:
		main_node.Call_Save(main_tileset, true, false)
		await get_tree().process_frame
		main_node.Call_Save(bg_tileset, false, true)
	else: print_rich("File Container: [color=red] Export nodes missing.")

func Call_Quit_Project():
	if confirm_label: confirm_label.show()
	
	click_count += 1
	
	if click_count == 2: GlobalProject.Call_Reset_Variables(); get_tree().change_scene_to_file("res://Scenes + Scripts/Editor/Boot/Editor Boot Scene.tscn")
	
	if click_timer and not click_count == 2:
		click_timer.start()

func Click_Timer_Timeout():
	if confirm_label and click_count < 1: confirm_label.hide()
	if click_count > 0: click_count -=1; click_timer.start()
