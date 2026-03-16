extends PanelContainer

func _ready():
	child_exiting_tree.connect(_on_child_free)
	
	show()
	
	var tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "self_modulate", Color.TRANSPARENT, 0.66)

func _on_child_free(_node: Node) -> void:
	queue_free()
