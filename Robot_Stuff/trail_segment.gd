extends Line2D

# How long it takes to disappear
@export var fade_duration: float = 0.3

func _ready():
	# Standard "Fade and Die" logic
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_duration)
	tween.tween_callback(queue_free)
