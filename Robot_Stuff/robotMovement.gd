extends CharacterBody2D

# --- TUNING PARAMETERS ---
@export var SPEED = 400.0
@export var ACCELERATION = 4000.0
@export var FRICTION = 1500.0
@export var AIR_FRICTION = 500.0
@export var JUMP_VELOCITY = -600.0
@export var GRAVITY = 1500.0
@export var FAST_FALL_GRAVITY = 3000.0
@export var DASH_SPEED = 1000.0
@export var DASH_DURATION = 0.15

# --- DEBUG / CONTROL ---
@export var player_control: bool = true 

# --- RL AGENT VARIABLES ---
@onready var ai_controller = get_node_or_null("AIController2D")
var start_position : Vector2

# --- VISUALS ---
@onready var sprite: Sprite2D = $RobotSpritesheet
@onready var trail_scene = preload("uid://blrm6lcenja3h")
@export var max_speed_visual: float = 1200.0
@export var trail_min_speed: float = 600.0
@export var trail_fade_time: float = 0.3

# --- STATE ---
var can_dash = true
var is_dashing = false
var dash_timer = 0.0
var last_position: Vector2 
var anim_timer = 0.0

# --- INPUT SIGNALS ---
var input_x = 0.0
var input_y = 0.0 
var input_jump_pressed = false
var input_jump_held = false 
var input_dash = false

func _ready():
	# Calculate grid dimensions once
	grid_width = (grid_radius * 2) + 1
	sensor_array.resize(grid_width * grid_width)
	sensor_array.fill(0.0)
	
	start_position = global_position
	last_position = global_position 

func _physics_process(delta):
	
	if debug_view:
		get_grid_observation()
		queue_redraw()
	
	# 1. AI RESET HANDLING
	if ai_controller and ai_controller.needs_reset:
		ai_controller.reset() 
		reset_player()
		return

	# 2. UPDATE INPUTS
	if player_control:
		_get_player_input()

	# 3. MOVEMENT LOGIC
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false
			velocity *= 0.5 
	else:
		# 4. Apply Gravity
		if not is_on_floor():
			var current_grav = FAST_FALL_GRAVITY if not input_jump_held else GRAVITY
			velocity.y += current_grav * delta
		else:
			can_dash = true

		# 5. Handle Jump
		if input_jump_pressed and is_on_floor():
			velocity.y = JUMP_VELOCITY
		
		if velocity.y < 0 and not input_jump_held:
			velocity.y = move_toward(velocity.y, 0, 2000 * delta)

		# 6. Handle Dash Activation
		if input_dash and can_dash:
			start_dash()

		# 7. Horizontal Movement
		if input_x != 0:
			var accel = ACCELERATION if is_on_floor() else (ACCELERATION * 0.5)
			velocity.x = move_toward(velocity.x, input_x * SPEED, accel * delta)
		else:
			var fric = FRICTION if is_on_floor() else AIR_FRICTION
			velocity.x = move_toward(velocity.x, 0, fric * delta)

	# 8. PHYSICS UPDATE
	move_and_slide()
	
	# 9. TRAIL LOGIC 
	# Only spawn if fast enough AND moved far enough
	if velocity.length() > trail_min_speed and global_position.distance_to(last_position) > 1.0:
		spawn_trail_segment()
	
	last_position = global_position
	
	# 10. ANIMATION LOGIC
	_update_animation_logic(delta)
	
	# 11. DEATH CHECK
	if global_position.y > 1000:
		game_over()

func spawn_trail_segment():
	if trail_scene == null:
		return

	var segment = trail_scene.instantiate()
	
	# Important: clear points and set top_level to prevent artifacts
	segment.clear_points()
	segment.top_level = true 
	segment.global_position = Vector2.ZERO

	segment.add_point(last_position)
	segment.add_point(global_position)

	# Calculate speed ratio (0.0 to 1.0) based on min/max threshold
	var speed_ratio = clamp(inverse_lerp(trail_min_speed, max_speed_visual, velocity.length()), 0.0, 1.0)

	# Width: 0px -> 10px
	segment.width = lerp(0.0, 10.0, speed_ratio)
	
	# Color: Transparent White -> Opaque Light Blue
	var start_color = Color(1, 1, 1, 0)      # White, transparent
	var end_color   = Color(0.2, 0.8, 1, 1)  # Light Blue, opaque
	segment.default_color = start_color.lerp(end_color, speed_ratio)
	
	get_parent().add_child(segment)

func _update_animation_logic(delta):
	# 1. HANDLE ROW (Dash Availability)
	# Row 0 (Top) if dash is ready, Row 1 (Bottom) if cooldown
	sprite.frame_coords.y = 0 if can_dash else 1

	# 2. HANDLE COLUMN (Movement State)
	var start_col = 0
	var end_col = 1
	var anim_speed = 0.5 
	
	if not is_on_floor():
		# Falling/Jumping: Columns 7-8 (Indices 6-7)
		start_col = 6
		end_col = 7
		anim_speed = 0.1
	elif abs(velocity.x) > 10:
		# Running: Columns 3-6 (Indices 2-5)
		start_col = 2
		end_col = 5
		anim_speed = 0.15
	else:
		# Standing Still: Columns 1-2 (Indices 0-1)
		start_col = 0
		end_col = 1
		anim_speed = 0.8 

	# 3. CYCLE THE ANIMATION
	anim_timer += delta
	if anim_timer > anim_speed:
		anim_timer = 0
		sprite.frame_coords.x += 1
	
	# Loop within the designated range
	if sprite.frame_coords.x > end_col or sprite.frame_coords.x < start_col:
		sprite.frame_coords.x = start_col

	# 4. FACE DIRECTION (Flip Sprite)
	if input_x != 0:
		sprite.flip_h = input_x < 0

func start_dash():
	can_dash = false
	is_dashing = true
	dash_timer = DASH_DURATION
	
	var dash_vector = Vector2(input_x, input_y).normalized()
	if dash_vector == Vector2.ZERO:
		dash_vector.x = 1.0 if velocity.x >= 0 else -1.0
		
	velocity = dash_vector * DASH_SPEED

func _get_player_input():
	# 1. Axis Movement (DIRECTION ONLY)
	# "up" maps ONLY to the Up Arrow. "jump" maps to Space + Up Arrow.
	# This ensures Spacebar does NOT affect your dash direction.
	input_x = Input.get_axis("left", "right")
	input_y = Input.get_axis("up", "down") 
	
	# 2. Context Sensitive JUMP (Ground Only)
	# We use the new "jump" map (Space or Up Arrow)
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		input_jump_pressed = true
	else:
		input_jump_pressed = false
		
	# Variable Jump Height
	input_jump_held = Input.is_action_pressed("jump")
	
	# 3. Context Sensitive DASH (Air Only)
	# If you mapped Space to "dash" as well, this ensures it only dashes in the air.
	if not is_on_floor() and Input.is_action_just_pressed("dash"):
		input_dash = true
	else:
		input_dash = false
# --- NEW FUNCTIONS FOR AI ---

func game_over():
	if ai_controller:
		ai_controller.reward -= 10.0
		ai_controller.done = true
		ai_controller.needs_reset = true
	else:
		reset_player()



###########################################################################################################################
# --- SENSOR SETTINGS ---
@export_group("AI Perception")
@export var debug_view: bool = true   # Toggle this to see the grid
@export var grid_radius: int = 5      # 5 cells left/right/up/down (11x11 total)
@export var cell_size: float = 40.0   # How big one "pixel" of the grid is in world space

# --- OFFSET SETTINGS (NEW) ---
# Shift (20, 20) to center the player in the tile.
# Shift (20, 80) to move the player DOWN 2 tiles (so AI sees more above).
@export var grid_center_offset: Vector2 = Vector2(20, 60)


# Data container
var sensor_array: Array = []
var grid_width: int = 0


# ---------------------------------------------------------
# 1. THE SENSOR LOGIC
# ---------------------------------------------------------
func get_grid_observation() -> Array:
	sensor_array.fill(0.0)
	
	# 1. CALCULATE GRID ORIGIN (World Space)
	# This is the top-left corner of the entire grid in the game world
	var total_size = grid_width * cell_size
	var grid_origin = global_position - Vector2(total_size / 2.0, total_size / 2.0)
	
	# Apply the manual offset (Centering + Vertical Bias)
	# We SUBTRACT the offset to move the grid "up/left" relative to player
	# effectively moving the player "down/right" inside the grid.
	grid_origin += (Vector2(cell_size/2.0, cell_size/2.0) - grid_center_offset)

	# --- PHASE 2: SCAN HAZARDS ---
	# We pass the 'grid_origin' so hazards can be mapped relative to it
	
	# Scan Missiles (Small Radius)
	for m in get_tree().get_nodes_in_group("missiles"):
		_map_object_to_grid(m, 0.5, 10.0, grid_origin) 

	# Scan Saws (Large Radius)
	for s in get_tree().get_nodes_in_group("saws"):
		_map_object_to_grid(s, 1.0, 25.0, grid_origin)
		
	return sensor_array

func _map_object_to_grid(obj: Node2D, value: float, obj_radius: float, grid_origin: Vector2):
	# Calculate position relative to the GRID ORIGIN (Top-Left), not the player
	var pos_in_grid = obj.global_position - grid_origin
	
	# Calculate the bounds of the object in "Grid Coordinates"
	var min_x = floor((pos_in_grid.x - obj_radius) / cell_size)
	var max_x = floor((pos_in_grid.x + obj_radius) / cell_size)
	var min_y = floor((pos_in_grid.y - obj_radius) / cell_size)
	var max_y = floor((pos_in_grid.y + obj_radius) / cell_size)

	# Loop through the affected cells
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			if x >= 0 and x < grid_width and y >= 0 and y < grid_width:
				var index = (y * grid_width) + x
				if value > sensor_array[index]:
					sensor_array[index] = value

# ---------------------------------------------------------
# 2. THE VISUALIZATION
# ---------------------------------------------------------
func _draw():
	if not debug_view: return
	
	# Re-calculate origin for drawing (Must match the Logic above exactly!)
	var total_size = grid_width * cell_size
	# We calculate the local offset from the player (0,0) to the grid top-left
	var local_origin = -Vector2(total_size / 2.0, total_size / 2.0)
	local_origin += (Vector2(cell_size/2.0, cell_size/2.0) - grid_center_offset)
	
	for y in range(grid_width):
		for x in range(grid_width):
			var index = (y * grid_width) + x
			var cell_value = sensor_array[index]
			
			var cell_pos = local_origin + Vector2(x * cell_size, y * cell_size)
			var rect = Rect2(cell_pos, Vector2(cell_size, cell_size))
			
			if cell_value == 0.0:
				draw_rect(rect, Color(1, 1, 1, 0.1), false, 1.0)
			elif cell_value == 0.3: # Platform
				draw_rect(rect, Color(0, 0.6, 1.0, 0.5), true)
			elif cell_value == 0.5: # Missile
				draw_rect(rect, Color(1, 0.5, 0, 0.5), true)
			elif cell_value == 1.0: # Saw
				draw_rect(rect, Color(1, 0, 0, 0.5), true)
				
	# OPTIONAL: Draw a crosshair at the exact center so you can align it
	draw_line(Vector2(-10, 0), Vector2(10, 0), Color.GREEN, 2.0)
	draw_line(Vector2(0, -10), Vector2(0, 10), Color.GREEN, 2.0)
	
	for ray in raycast_container.get_children():
		if ray is RayCast2D:
			var start = to_local(ray.global_position)
			var end = to_local(ray.global_position + ray.target_position)
			var color = Color.BLUE
			if ray.is_colliding():
				end = to_local(ray.get_collision_point())
				color = Color.GREEN
			draw_line(start, end, color, 2.0)

@onready var raycast_container: Node2D = $RayCastContainer







func reset_player():
	global_position = start_position
	last_position = start_position 
	velocity = Vector2.ZERO
	is_dashing = false
	can_dash = true
	dash_timer = 0.0
	anim_timer = 0.0 # Reset animation timer
	
	get_tree().call_group("spawners", "reset_difficulty")
	get_tree().call_group("missiles", "queue_free")
	get_tree().call_group("saws", "queue_free")
