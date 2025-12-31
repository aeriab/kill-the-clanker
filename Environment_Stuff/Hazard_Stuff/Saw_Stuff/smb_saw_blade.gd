extends Sprite2D

# Radians per second (approx 6.0 is one full circle per second)
@export var min_spin_speed: float = 15.0
@export var max_spin_speed: float = 30.0

var current_spin_speed: float = 0.0

func _ready():
	# Pick a random speed
	current_spin_speed = randf_range(min_spin_speed, max_spin_speed)
	
	# Optional: 50% chance to spin clockwise vs counter-clockwise
	if randf() > 0.5:
		current_spin_speed *= -1

func _process(delta):
	rotate(current_spin_speed * delta)
