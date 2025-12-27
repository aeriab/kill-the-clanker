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
# [CHANGED] We no longer need a reference to a single $Line2D child.
# Instead, we define how the spawned segments behave.
@export var max_speed_visual: float = 800.0
@export var trail_min_speed: float = 400.0 
@export var trail_fade_time: float = 0.3  # How long a segment lasts

# --- STATE ---
var can_dash = true
var is_dashing = false
var dash_timer = 0.0
var last_position: Vector2 # [NEW] To track where we were last frame

# --- INPUT SIGNALS ---
var input_x = 0.0
var input_y = 0.0 
var input_jump_pressed = false
var input_jump_held = false 
var input_dash = false

func _ready():
	start_position = global_position
	last_position = global_position # Initialize to prevent jump on spawn

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
	
	# 9. TRAIL LOGIC (Totally Redone)
	# We check if we are moving fast enough AND if we actually moved this frame
	if velocity.length() > trail_min_speed and global_position.distance_to(last_position) > 1.0:
		spawn_trail_segment()
	
	# Update last_position for the next frame
	last_position = global_position
	
	# 10. DEATH CHECK
	if global_position.y > 1000:
		game_over()

func spawn_trail_segment():
	# 1. Create a new temporary Line2D
	var segment = Line2D.new()
	segment.top_level = true # Independent of player movement
	segment.add_point(last_position)
	segment.add_point(global_position)
	
	# 2. Style it based on speed
	var speed_ratio = clamp(velocity.length() / max_speed_visual, 0.0, 1.0)
	segment.default_color = Color.WHITE.lerp(Color(0, 0.5, 1, 1), speed_ratio)
	segment.width = lerp(5.0, 12.0, speed_ratio)
	
	# Optional: Make joints round so segments connect smoothly
	segment.begin_cap_mode = Line2D.LINE_CAP_ROUND
	segment.end_cap_mode = Line2D.LINE_CAP_ROUND
	
	# 3. Add to the main scene (not the player, so it doesn't move with us)
	get_parent().add_child(segment)
	
	# 4. Animate it fading out and then delete it
	var tween = get_tree().create_tween()
	tween.tween_property(segment, "modulate:a", 0.0, trail_fade_time)
	tween.tween_callback(segment.queue_free)

func start_dash():
	can_dash = false
	is_dashing = true
	dash_timer = DASH_DURATION
	
	var dash_vector = Vector2(input_x, input_y).normalized()
	if dash_vector == Vector2.ZERO:
		dash_vector.x = 1.0 if velocity.x >= 0 else -1.0
		
	velocity = dash_vector * DASH_SPEED

func _get_player_input():
	input_x = Input.get_axis("ui_left", "ui_right")
	input_y = Input.get_axis("ui_up", "ui_down") 
	input_jump_pressed = Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_up")
	input_jump_held = Input.is_action_pressed("ui_accept") or Input.is_action_pressed("ui_up")
	
	if InputMap.has_action("dash"):
		input_dash = Input.is_action_just_pressed("dash")
	else:
		input_dash = Input.is_key_pressed(KEY_SHIFT) and not is_dashing

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
	last_position = start_position # [NEW] Reset this so we don't draw a huge line
	velocity = Vector2.ZERO
	is_dashing = false
	can_dash = true
	dash_timer = 0.0
	
	get_tree().call_group("spawners", "reset_difficulty")
	get_tree().call_group("missiles", "queue_free")
