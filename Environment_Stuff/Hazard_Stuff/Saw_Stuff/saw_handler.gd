extends Node2D

# --- RESOURCES ---
# Update these paths to match your folder structure
@onready var saw_scene = preload("res://Environment_Stuff/Hazard_Stuff/Saw_Stuff/saw_blade.tscn")
@onready var debris_cache = preload("res://Environment_Stuff/Hazard_Stuff/debris.tscn")

# --- SETTINGS ---
@export var automatic_saws: bool = false
@export var off_screen_margin: float = 100.0

# --- DIFFICULTY RAMP ---
@export_group("Difficulty Settings")
@export var max_spawn_rate: float = 2.0  # Saws might need to be less frequent than missiles
@export var min_spawn_rate: float = 0.5
@export var ramp_duration: float = 45.0

# --- SPEED SETTINGS ---
@export_group("Speed Settings")
@export var min_saw_speed: float = 300.0
@export var max_saw_speed: float = 900.0
@export var max_drag_distance: float = 500.0

# --- STATE ---
var is_dragging = false
var drag_start_pos = Vector2.ZERO
var spawn_timer = 0.0

# Difficulty State
var difficulty_time_elapsed: float = 0.0
var current_spawn_rate: float = 2.0

func _ready():
	add_to_group("spawners")
	reset_difficulty()
	
	if Global.use_particles:
		call_deferred("_warm_up_shaders")

func _warm_up_shaders():
	# This prevents the first saw hit from stuttering the game
	print("WARMING UP SHADERS: Spawning dummy debris...")
	
	if not debris_cache: return
	
	var dummy_debris = debris_cache.instantiate()
	get_tree().root.add_child(dummy_debris)
	dummy_debris.global_position = Vector2(0, -200) # Spawn off-screen
	dummy_debris.modulate.a = 0.01 
	dummy_debris.emitting = true
	
	# Clean up after a brief moment
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(dummy_debris):
		dummy_debris.queue_free()

func _unhandled_input(event):
	# Using Right Mouse Button for Saws? 
	# Or keep Left Mouse if you want them to share the input. 
	# Below is set to RIGHT MOUSE BUTTON to differentiate from Missiles.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			is_dragging = true
			drag_start_pos = get_global_mouse_position()
			
		elif is_dragging: 
			is_dragging = false
			calculate_and_fire(drag_start_pos, get_global_mouse_position())

func _process(delta):
	queue_redraw()
	
	if automatic_saws:
		difficulty_time_elapsed += delta
		var t = clamp(difficulty_time_elapsed / ramp_duration, 0.0, 1.0)
		current_spawn_rate = lerp(max_spawn_rate, min_spawn_rate, t)
		
		spawn_timer += delta
		if spawn_timer >= current_spawn_rate:
			spawn_timer = 0.0
			attempt_auto_spawn()

func reset_difficulty():
	difficulty_time_elapsed = 0.0
	spawn_timer = 0.0
	current_spawn_rate = max_spawn_rate

func attempt_auto_spawn():
	var player = get_tree().get_first_node_in_group("player")
	if not player: return

	var random_angle = randf_range(0, TAU)
	var direction = Vector2.from_angle(random_angle)
	
	var cam_rect = get_active_camera_rect()
	
	var dist_back = get_distance_to_edge(player.global_position, -direction, cam_rect)
	var spawn_pos = player.global_position - (direction * (dist_back + off_screen_margin))
	
	var dist_fwd = get_distance_to_edge(player.global_position, direction, cam_rect)
	var target_pos = player.global_position + (direction * (dist_fwd + off_screen_margin))
	
	var speed = randf_range(min_saw_speed, max_saw_speed)
	spawn_saw(spawn_pos, direction, target_pos, speed)

func calculate_and_fire(p1: Vector2, p2: Vector2):
	var direction = (p2 - p1).normalized()
	if direction == Vector2.ZERO: return 

	var camera_rect = get_active_camera_rect()

	var dist_to_spawn_edge = get_distance_to_edge(p1, -direction, camera_rect)
	var spawn_pos = p1 - (direction * (dist_to_spawn_edge + off_screen_margin))
	
	var dist_to_target_edge = get_distance_to_edge(p2, direction, camera_rect)
	var target_pos = p2 + (direction * (dist_to_target_edge + off_screen_margin))
	
	var drag_len = p1.distance_to(p2)
	var t = clamp(drag_len / max_drag_distance, 0.0, 1.0)
	var speed = lerp(min_saw_speed, max_saw_speed, t)
	
	spawn_saw(spawn_pos, direction, target_pos, speed)

func spawn_saw(pos, dir, target_pos, speed):
	if not saw_scene: return
	
	var saw = saw_scene.instantiate()
	
	# Apply custom speed
	if "speed" in saw:
		saw.speed = speed
		
	get_tree().root.add_child(saw)
	
	# Launch uses the same logic as missile
	if saw.has_method("launch"):
		saw.launch(pos, dir, target_pos)

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
		# Draw Gray line to distinguish from Red Missile line
		draw_line(local_start, local_mouse, Color.GRAY, 4.0)
