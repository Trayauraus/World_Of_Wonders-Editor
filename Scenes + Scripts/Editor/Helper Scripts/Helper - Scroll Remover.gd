extends ScrollContainer

@onready var v_scroll = get_v_scroll_bar()

func _ready():
	# Initially hide the scrollbar opacity or visibility
	v_scroll.modulate.a = 0 
	
	# Connect mouse signals
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered():
	# Fade in the scrollbar
	var tween = create_tween()
	tween.tween_property(v_scroll, "modulate:a", 1.0, 0.2)

func _on_mouse_exited():
	# Fade out the scrollbar
	var tween = create_tween()
	tween.tween_property(v_scroll, "modulate:a", 0.0, 0.2)
