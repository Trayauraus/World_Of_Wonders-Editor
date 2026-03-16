extends Label

var time: float = 0.0

func _ready() -> void:
	visible_characters = text.length() - 3

func _process(delta: float) -> void:
	time += delta
	
	if (time > 0.4):
		time -= 0.4
	else:
		return
	
	visible_characters += 1
	if visible_characters > text.length():
		visible_characters = text.length() - 3
