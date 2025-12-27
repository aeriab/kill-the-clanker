extends CharacterBody2D

# --- TUNING PARAMETERS (The "Feel") ---
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
@export var player_control: bool = true  # Check this in Inspector to play manually

# --- STATE ---
var can_dash = true
var is_dashing = false
var dash_timer = 0.0

# --- INPUT SIGNALS ---
# (These are what the RL Agent will eventually control)
var input_x = 0.0
var input_y = 0.0  # Added for vertical dash aiming
var input_jump_pressed = false
var input_jump_held = false 
var input_dash = false

func _physics_process(delta):
	# 0. UPDATE INPUTS
	if player_control:
		_get_player_input()

	# 1. Handle Dashing Logic
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false
			velocity *= 0.5 # Slow down after dash
		move_and_slide()
		return # Skip gravity/movement logic while dashing

	# 2. Apply Gravity (Normal or Fast Fall)
	if not is_on_floor():
		# If jump is NOT held, apply FAST_FALL_GRAVITY. If jump IS held, apply normal GRAVITY.
		var current_grav = FAST_FALL_GRAVITY if not input_jump_held else GRAVITY
		velocity.y += current_grav * delta
	else:
		can_dash = true

	# 3. Handle Jump
	if input_jump_pressed and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	# Variable Jump Height (Cut velocity if button released early)
	if velocity.y < 0 and not input_jump_held:
		velocity.y = move_toward(velocity.y, 0, 2000 * delta)

	# 4. Handle Dash Activation
	if input_dash and can_dash:
		start_dash()

	# 5. Horizontal Movement
	# Only apply movement logic if we are NOT dashing.
	# This prevents friction from cancelling out the dash speed.
	if not is_dashing:
		if input_x != 0:
			var accel = ACCELERATION if is_on_floor() else (ACCELERATION * 0.5)
			velocity.x = move_toward(velocity.x, input_x * SPEED, accel * delta)
		else:
			var fric = FRICTION if is_on_floor() else AIR_FRICTION
			velocity.x = move_toward(velocity.x, 0, fric * delta)

	move_and_slide()

func start_dash():
	can_dash = false
	is_dashing = true
	dash_timer = DASH_DURATION
	
	# Calculate 8-way direction from inputs
	var dash_vector = Vector2(input_x, input_y).normalized()
	
	# If no direction held, dash forward (based on current velocity or default right)
	if dash_vector == Vector2.ZERO:
		dash_vector.x = 1.0 if velocity.x >= 0 else -1.0
		
	velocity = dash_vector * DASH_SPEED

func _get_player_input():
	# Maps Godot's default UI actions to our bot variables
	input_x = Input.get_axis("ui_left", "ui_right")
	input_y = Input.get_axis("ui_up", "ui_down") # Capture vertical input for dashing
	
	# Jump typically spacebar or Up
	input_jump_pressed = Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_up")
	input_jump_held = Input.is_action_pressed("ui_accept") or Input.is_action_pressed("ui_up")
	
	# Checks for "dash" action map, or physical Shift key as fallback
	if InputMap.has_action("dash"):
		input_dash = Input.is_action_just_pressed("dash")
	else:
		input_dash = Input.is_key_pressed(KEY_SHIFT) and not is_dashing
