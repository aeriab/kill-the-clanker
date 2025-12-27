extends Area2D

@onready var explosion_vfx = preload("res://Environment_Stuff/Hazard_Stuff/explosion.tscn")

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

func launch(start_pos: Vector2, direction: Vector2, target_explode_pos: Vector2):
	position = start_pos
	velocity = direction.normalized() * speed
	rotation = direction.angle()
	
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
	
	# --- SPAWN VISUALS ---
	if explosion_vfx:
		# 1. The Smoke (Base Explosion)
		var smoke_part = explosion_vfx.instantiate()
		get_tree().root.add_child(smoke_part)
		smoke_part.global_position = global_position
		smoke_part.emitting = true
		
		# 2. The Fire (Colored Core Explosion)
		var fire_part = explosion_vfx.instantiate()
		get_tree().root.add_child(fire_part)
		fire_part.global_position = global_position
		
		# VISUAL TWEAKS:
		# Make the fire slightly smaller so it sits inside the smoke
		fire_part.scale = Vector2(0.7, 0.7) 
		# Tint it Orange-Red (Red=1, Green=0.5, Blue=0)
		fire_part.modulate = Color(1, 0.5, 0.1)
		# Optional: Ensure it draws on top of the smoke
		fire_part.z_index = smoke_part.z_index + 1
		
		fire_part.emitting = true
	
	queue_free()
