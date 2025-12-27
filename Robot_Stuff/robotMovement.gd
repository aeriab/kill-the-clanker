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
# We try to get the node, but keep it optional in case you are testing without it
@onready var ai_controller = get_node_or_null("AIController2D")
var start_position : Vector2

# --- STATE ---
var can_dash = true
var is_dashing = false
var dash_timer = 0.0

# --- INPUT SIGNALS ---
var input_x = 0.0
var input_y = 0.0 
var input_jump_pressed = false
var input_jump_held = false 
var input_dash = false

func _ready():
	# Remember where we spawned so we can reset here later
	start_position = global_position

func _physics_process(delta):
	# 1. AI RESET HANDLING
	# If the RL agent says the episode is done, we reset everything before moving
	if ai_controller and ai_controller.needs_reset:
		ai_controller.reset() # This updates the AI internal state
		reset_player()
		return

	# 2. UPDATE INPUTS
	if player_control:
		_get_player_input()
	# If player_control is False, we assume the AIController has 
	# written values to input_x, input_jump_pressed, etc.

	# 3. Handle Dashing Logic
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false
			velocity *= 0.5 
		move_and_slide()
		return 

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
	if not is_dashing:
		if input_x != 0:
			var accel = ACCELERATION if is_on_floor() else (ACCELERATION * 0.5)
			velocity.x = move_toward(velocity.x, input_x * SPEED, accel * delta)
		else:
			var fric = FRICTION if is_on_floor() else AIR_FRICTION
			velocity.x = move_toward(velocity.x, 0, fric * delta)

	move_and_slide()
	
	# 8. DEATH CHECK (Falling off screen)
	# Check if we fell below the screen (assuming positive Y is down)
	# Adjust '1000' to be slightly below your actual screen height
	if global_position.y > 1000:
		game_over()

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
	# Punish the AI for dying
	if ai_controller:
		ai_controller.reward -= 10.0
		ai_controller.done = true
		ai_controller.needs_reset = true
	else:
		# If playing manually without AI, just reset immediately
		reset_player()

func reset_player():
	# Reset Physics State
	global_position = start_position
	velocity = Vector2.ZERO
	is_dashing = false
	can_dash = true
	dash_timer = 0.0
	
	# TODO: You should also clear hazards here!
	get_tree().call_group("missiles", "queue_free")
