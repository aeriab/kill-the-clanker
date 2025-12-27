extends Node2D

@onready var missile_scene = preload("res://Environment_Stuff/Hazard_Stuff/Missile_Stuff/missile.tscn")
@onready var explosion_cache = preload("res://Environment_Stuff/Hazard_Stuff/explosion.tscn")

# --- SETTINGS ---
@export var automatic_missiles: bool = false
@export var off_screen_margin: float = 100.0 

# --- DIFFICULTY RAMP ---
# Missiles start slow and get faster over time
@export_group("Difficulty Settings")
@export var max_spawn_rate: float = 1.0  # Start here (e.g., 1 missile every 2s)
@export var min_spawn_rate: float = 0.1  # Cap here (e.g., 1 missile every 0.5s)
@export var ramp_duration: float = 10.0  # Seconds to reach max difficulty

# --- STATE ---
var is_dragging = false
var drag_start_pos = Vector2.ZERO
var spawn_timer = 0.0

# Difficulty State
var difficulty_time_elapsed: float = 0.0
var current_spawn_rate: float = 2.0

func _ready():
	# Register to group so Player.gd can find us easily to call reset_difficulty()
	add_to_group("spawners")
	
	# Initial setup
	reset_difficulty()
	
	# Warm up shaders slightly later to ensure camera/viewport is ready
	call_deferred("_warm_up_shaders")

func _warm_up_shaders():
	print("WARMING UP SHADERS: Spawning dummy explosions...")
	
	# 1. Warm up the BASE Smoke (Standard Material)
	var dummy_smoke = explosion_cache.instantiate()
	get_tree().root.add_child(dummy_smoke)
	dummy_smoke.global_position = Vector2(0, 200) # Visible spot
	dummy_smoke.modulate.a = 0.01 # Nearly invisible, but still rendered
	dummy_smoke.emitting = true
	
	# 2. Warm up the FIRE Core (Duplicated Material)
	# We must simulate exactly what the Missile script does: duplicating the material
	var dummy_fire = explosion_cache.instantiate()
	get_tree().root.add_child(dummy_fire)
	dummy_fire.global_position = Vector2(50, 200) 
	dummy_fire.modulate.a = 0.01
	
	# FORCE MATERIAL DUPLICATION (This fixes the specific stutter you had!)
	var fire_mat = dummy_fire.process_material.duplicate()
	dummy_fire.process_material = fire_mat
	fire_mat.color = Color(1, 0.5, 0.1) # The orange color used in actual game
	
	dummy_fire.emitting = true

func _unhandled_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging = true
			drag_start_pos = get_global_mouse_position()
			
		elif is_dragging: 
			is_dragging = false
			calculate_and_fire(drag_start_pos, get_global_mouse_position())

func _process(delta):
	queue_redraw()
	
	if automatic_missiles:
		# 1. Update Difficulty Timer
		difficulty_time_elapsed += delta
		
		# Calculate how far along the ramp we are (0.0 to 1.0)
		var t = clamp(difficulty_time_elapsed / ramp_duration, 0.0, 1.0)
		
		# Smoothly interpolate the spawn rate
		current_spawn_rate = lerp(max_spawn_rate, min_spawn_rate, t)
		
		# 2. Handle Spawning
		spawn_timer += delta
		if spawn_timer >= current_spawn_rate:
			spawn_timer = 0.0
			attempt_auto_spawn()

# Call this from Player.gd -> game_over() or reset()
func reset_difficulty():
	difficulty_time_elapsed = 0.0
	spawn_timer = 0.0
	current_spawn_rate = max_spawn_rate

func attempt_auto_spawn():
	var player = get_tree().get_first_node_in_group("player")
	if not player: return

	# Random Angle Logic
	var random_angle = randf_range(0, TAU) # TAU is 2*PI (full circle)
	var direction = Vector2.from_angle(random_angle)
	
	var cam_rect = get_active_camera_rect()
	
	# Calculate Spawn Point (Behind Player relative to direction)
	var dist_back = get_distance_to_edge(player.global_position, -direction, cam_rect)
	var spawn_pos = player.global_position - (direction * (dist_back + off_screen_margin))
	
	# Calculate Explode Point (Ahead of Player relative to direction)
	var dist_fwd = get_distance_to_edge(player.global_position, direction, cam_rect)
	var explode_pos = player.global_position + (direction * (dist_fwd + off_screen_margin))
	
	spawn_missile(spawn_pos, direction, explode_pos)

func calculate_and_fire(p1: Vector2, p2: Vector2):
	var direction = (p2 - p1).normalized()
	if direction == Vector2.ZERO: return 

	var camera_rect = get_active_camera_rect()

	var dist_to_spawn_edge = get_distance_to_edge(p1, -direction, camera_rect)
	var spawn_pos = p1 - (direction * (dist_to_spawn_edge + off_screen_margin))
	
	var dist_to_explode_edge = get_distance_to_edge(p2, direction, camera_rect)
	var explode_pos = p2 + (direction * (dist_to_explode_edge + off_screen_margin))
	
	spawn_missile(spawn_pos, direction, explode_pos)

func spawn_missile(pos, dir, death_pos):
	var missile = missile_scene.instantiate()
	get_tree().root.add_child(missile)
	missile.launch(pos, dir, death_pos)

# --- MATH HELPER FUNCTIONS ---

func get_active_camera_rect() -> Rect2:
	var cam = get_viewport().get_camera_2d()
	var viewport_size = get_viewport_rect().size
	var center = Vector2.ZERO
	var zoom = Vector2.ONE
	
	if cam:
		center = cam.get_screen_center_position()
		zoom = cam.zoom
	
	var world_size = viewport_size / zoom
	var top_left = center - (world_size / 2.0)
	
	return Rect2(top_left, world_size)

func get_distance_to_edge(point: Vector2, travel_dir: Vector2, bounds: Rect2) -> float:
	var t_x = INF
	var t_y = INF
	
	if travel_dir.x != 0:
		if travel_dir.x > 0:
			t_x = (bounds.end.x - point.x) / travel_dir.x
		else:
			t_x = (bounds.position.x - point.x) / travel_dir.x
			
	if travel_dir.y != 0:
		if travel_dir.y > 0:
			t_y = (bounds.end.y - point.y) / travel_dir.y
		else:
			t_y = (bounds.position.y - point.y) / travel_dir.y
	
	return min(t_x, t_y)

func _draw():
	if is_dragging:
		var local_start = to_local(drag_start_pos)
		var local_mouse = to_local(get_global_mouse_position())
		draw_line(local_start, local_mouse, Color.RED, 2.0)
