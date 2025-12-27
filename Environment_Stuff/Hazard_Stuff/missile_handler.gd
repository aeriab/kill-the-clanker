extends Node2D

@onready var missile_scene = preload("res://Environment_Stuff/Hazard_Stuff/missile.tscn")

# How far off-screen should it spawn/die?
const OFF_SCREEN_MARGIN = 100.0 

var is_dragging = false
var drag_start_pos = Vector2.ZERO

func _unhandled_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging = true
			drag_start_pos = get_global_mouse_position()
			
		elif is_dragging: 
			is_dragging = false
			calculate_and_fire(drag_start_pos, get_global_mouse_position())

func calculate_and_fire(p1: Vector2, p2: Vector2):
	var direction = (p2 - p1).normalized()
	
	if direction == Vector2.ZERO:
		return 

	# 1. Get the Camera's Viewport in World Coordinates
	var camera_rect = get_active_camera_rect()

	# 2. Calculate Spawn Position (Backwards from Start Click)
	# We look in the NEGATIVE direction to find the edge behind us
	var dist_to_spawn_edge = get_distance_to_edge(p1, -direction, camera_rect)
	var spawn_pos = p1 - (direction * (dist_to_spawn_edge + OFF_SCREEN_MARGIN))
	
	# 3. Calculate Explode Position (Forwards from End Click)
	# We look in the POSITIVE direction to find the edge ahead of us
	var dist_to_explode_edge = get_distance_to_edge(p2, direction, camera_rect)
	var explode_pos = p2 + (direction * (dist_to_explode_edge + OFF_SCREEN_MARGIN))
	
	spawn_missile(spawn_pos, direction, explode_pos)

func spawn_missile(pos, dir, death_pos):
	var missile = missile_scene.instantiate()
	get_tree().root.add_child(missile)
	missile.launch(pos, dir, death_pos)

# --- MATH HELPER FUNCTIONS ---

func get_active_camera_rect() -> Rect2:
	# Finds the area the camera is currently seeing in World Space
	var cam = get_viewport().get_camera_2d()
	var viewport_size = get_viewport_rect().size
	
	# Fallback if no camera is found (assumes centered at 0,0)
	var center = Vector2.ZERO
	var zoom = Vector2.ONE
	
	if cam:
		center = cam.get_screen_center_position()
		zoom = cam.zoom
	
	# Calculate world size accounting for Zoom
	var world_size = viewport_size / zoom
	var top_left = center - (world_size / 2.0)
	
	return Rect2(top_left, world_size)

func get_distance_to_edge(point: Vector2, travel_dir: Vector2, bounds: Rect2) -> float:
	# Calculates how far 'point' can travel along 'travel_dir' before hitting 'bounds'
	var t_x = INF
	var t_y = INF
	
	# Check Horizontal Walls (Left/Right)
	if travel_dir.x != 0:
		if travel_dir.x > 0:
			# Moving Right -> Distance to Right Edge
			t_x = (bounds.end.x - point.x) / travel_dir.x
		else:
			# Moving Left -> Distance to Left Edge
			t_x = (bounds.position.x - point.x) / travel_dir.x
			
	# Check Vertical Walls (Top/Bottom)
	if travel_dir.y != 0:
		if travel_dir.y > 0:
			# Moving Down -> Distance to Bottom Edge
			t_y = (bounds.end.y - point.y) / travel_dir.y
		else:
			# Moving Up -> Distance to Top Edge
			t_y = (bounds.position.y - point.y) / travel_dir.y
	
	# The real intersection is whichever wall we hit first (the smaller distance)
	return min(t_x, t_y)

# --- VISUALIZATION ---
func _process(_delta):
	queue_redraw()

func _draw():
	if is_dragging:
		var local_start = to_local(drag_start_pos)
		var local_mouse = to_local(get_global_mouse_position())
		draw_line(local_start, local_mouse, Color.RED, 2.0)
