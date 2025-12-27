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
	start_position = global_position
	last_position = global_position 

func _physics_process(delta):
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
