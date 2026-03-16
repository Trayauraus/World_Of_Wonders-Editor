extends PanelContainer

@export var main_node: Editor_Script
@export var main_tileset: TileMapLayer
@export var bg_tileset: TileMapLayer

@export var godot_ver_label: Label

func _ready():
	if godot_ver_label:
		Add_Version_Text()

func Add_Version_Text():
	var ver = Engine.get_version_info()
	# Format as string: Major.Minor.Patch
	godot_ver_label.text = "Godot Engine v" + str(ver.major) + "." + str(ver.minor) + "." + str(ver.patch)

func Call_Export():
	print("File Container: Save Called")
	if main_node and main_tileset and bg_tileset:
		main_node.Call_Save(main_tileset, true, false)
		await get_tree().process_frame
		main_node.Call_Save(bg_tileset, false, true)
	else: print_rich("File Container: [color=red] Export nodes missing.")
	GlobalProject.Call_Export()
