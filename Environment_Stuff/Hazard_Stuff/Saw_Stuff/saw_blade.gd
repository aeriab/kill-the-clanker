extends Area2D

# Change this path to wherever your debris particle scene is located
@onready var debris_vfx = preload("res://Environment_Stuff/Hazard_Stuff/debris.tscn")

# --- SETTINGS ---
@export var speed = 600.0
# Removed blast_radius and knockback since this is an instant kill

var velocity = Vector2.ZERO
var max_travel_distance = 0.0
var current_travel_distance = 0.0

func _ready():
	# Auto-add to group so the Player script can clean them up easily
	add_to_group("saws")
	body_entered.connect(_on_impact)

func launch(start_pos: Vector2, direction: Vector2, target_pos: Vector2):
	# Same movement logic as Missile
	position = start_pos
	velocity = direction.normalized() * speed
	rotation = direction.angle() # Rotates the saw to face/move forward
	
	max_travel_distance = start_pos.distance_to(target_pos)
	current_travel_distance = 0.0

func _physics_process(delta):
	position += velocity * delta
	
	# Auto-destroy if it travels too far without hitting anything
	current_travel_distance += speed * delta
	if current_travel_distance >= max_travel_distance:
		shatter()

func _on_impact(body):
	if body == self: return
	
	# If we hit the player, kill them immediately
	if body.has_method("game_over"):
		body.game_over()
	
	# Destroy the saw regardless of what it hit (player or wall)
	shatter()

func shatter():
	# --- SPAWN VISUALS ---
	if Global.use_particles and debris_vfx:
		var debris = debris_vfx.instantiate()
		get_tree().root.add_child(debris)
		debris.global_position = global_position
		debris.emitting = true
	
	queue_free()
