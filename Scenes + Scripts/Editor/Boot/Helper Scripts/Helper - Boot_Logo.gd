extends TextureRect

# Called when the node enters the scene tree for the first time.
func _ready():
	if GlobalEditor.intro_played: queue_free(); return
	pivot_offset = size / 2
	
	var tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.set_parallel()
	
	tween.tween_property(self, "scale", Vector2.ZERO, 0.8)
	tween.tween_property(self, "rotation", PI * 4, 0.8)
	
	await tween.finished
	queue_free()
