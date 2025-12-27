extends GPUParticles2D

func _ready():
	# Automatically clean up when the particle cycle finishes
	finished.connect(queue_free)
