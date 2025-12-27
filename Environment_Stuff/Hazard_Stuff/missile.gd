extends Area2D

# --- SETTINGS ---
@export var speed = 600.0
@export var blast_radius = 250.0  
@export var max_knockback = 1500.0 

var velocity = Vector2.ZERO

# New variables for tracking distance
var max_travel_distance = 0.0
var current_travel_distance = 0.0

func _ready():
	body_entered.connect(_on_impact)

# UPDATED LAUNCH FUNCTION
func launch(start_pos: Vector2, direction: Vector2, target_explode_pos: Vector2):
	position = start_pos
	velocity = direction.normalized() * speed
	rotation = direction.angle()
	
	# Calculate exactly how far we need to go before auto-exploding
	max_travel_distance = start_pos.distance_to(target_explode_pos)
	current_travel_distance = 0.0

func _physics_process(delta):
	# Move
	var move_step = velocity * delta
	position += move_step
	
	# Track distance to handle the "Auto-Explode" logic
	current_travel_distance += speed * delta
	
	if current_travel_distance >= max_travel_distance:
		explode()

func _on_impact(body):
	if body == self: return
	explode()

func explode():
	var player = get_tree().get_first_node_in_group("player")
	
	if player:
		var dist = global_position.distance_to(player.global_position)
		if dist < blast_radius:
			var force_percent = 1.0 - (dist / blast_radius)
			var push_dir = global_position.direction_to(player.global_position)
			player.velocity += push_dir * max_knockback * force_percent
			
	queue_free()
