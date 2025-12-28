extends AIController2D

@onready var player = get_parent()
@onready var raycast_container = $"../RayCastContainer"

func get_obs() -> Dictionary:
	var obs = []
	
	# --- 1. PROPRIOCEPTION (Body Awareness) ---
	
	# A. Velocity (Normalized)
	obs.append(clamp(player.velocity.x / 1000.0, -1.0, 1.0))
	obs.append(clamp(player.velocity.y / 1000.0, -1.0, 1.0))
	
	# B. Global Position (Normalized to Screen Size)
	# Assuming a 1920x1080 resolution. 0.0 is top/left, 1.0 is bottom/right.
	var screen_x = 1152.0
	var screen_y = 648.0
	obs.append(player.global_position.x / screen_x)
	obs.append(player.global_position.y / screen_y)
	
	# C. Status Flags
	obs.append(1.0 if player.is_on_floor() else 0.0)
	obs.append(1.0 if player.can_dash else 0.0)
	
	# --- 2. EXTEROCEPTION (The Eyes) ---
	# We iterate through all rays. For each ray, we add TWO numbers:
	# 1. Proximity (How close is it? 0.0 = Far, 1.0 = Touching)
	# 2. Danger Level (0.0 = Empty/Safe, 1.0 = Hazard)
	
	for ray in raycast_container.get_children():
		if ray is RayCast2D:
			ray.force_raycast_update()
			
			if ray.is_colliding():
				var collider = ray.get_collider()
				var dist = ray.global_position.distance_to(ray.get_collision_point())
				var max_len = ray.target_position.length()
				
				# Input 1: Proximity (Inverted distance)
				obs.append(1.0 - (dist / max_len))
				
				# Input 2: Object Identity
				if collider.is_in_group("missiles"):
					obs.append(1.0) # DANGER!
				elif collider.is_in_group("platform"):
					obs.append(-1.0) # Safe / Wall
				else:
					obs.append(0.0) # Unknown object
			else:
				# Ray hit nothing
				obs.append(0.0) # Proximity: 0 (Far away)
				obs.append(0.0) # Identity: 0 (Nothing)
				
	return {"obs": obs}

# --- 2. REWARD (The Motivation) ---
func get_reward() -> float:
	# Basic Survival Reward: +1 point for every frame it stays alive
	return 1.0

# --- 3. ACTIONS (The Hands) ---
# The RL brain sends an array of numbers. We map them to player inputs.
func get_action_space() -> Dictionary:
	return {
		"move_x": {"size": 1, "action_type": "continuous"}, # Float -1 to 1
		"move_y": {"size": 1, "action_type": "continuous"}, # Float -1 to 1 (for dash aim)
		"jump":   {"size": 1, "action_type": "discrete"},   # 0 or 1
		"dash":   {"size": 1, "action_type": "discrete"}    # 0 or 1
	}

func set_action(action) -> void:
	var raw_x = action["move_x"][0]
	player.input_x = 0.0 if abs(raw_x) < 0.5 else sign(raw_x)
	
	# REVISED: Add a "Deadzone" to snap aiming to -1, 0, or 1
	# If the AI output is weak (between -0.5 and 0.5), we treat it as 0 (Neutral)
	# Otherwise, we snap it to hard -1.0 (Up) or 1.0 (Down)
	var raw_y = action["move_y"][0]
	player.input_y = 0.0 if abs(raw_y) < 0.5 else sign(raw_y)

	player.input_jump_pressed = action["jump"] == 1
	player.input_jump_held = action["jump"] == 1 
	player.input_dash = action["dash"] == 1


# --- ADD THESE TO THE BOTTOM OF YOUR SCRIPT ---

func _physics_process(_delta):
	queue_redraw() # Forces the _draw() function to run every frame

func _draw():
	# Loop through the rays just like in get_obs()
	for ray in raycast_container.get_children():
		if ray is RayCast2D:
			# Calculate start and end points in local coordinates
			var start_pos = to_local(ray.global_position)
			var end_pos = to_local(ray.global_position + ray.target_position)
			var color = Color.BLUE # Default: Blue for empty/unknown
			
			if ray.is_colliding():
				var collider = ray.get_collider()
				end_pos = to_local(ray.get_collision_point()) # Shorten line to hit point
				
				if collider.is_in_group("platform"):
					color = Color.GREEN
				elif collider.is_in_group("missiles"):
					color = Color.RED
			
			# Draw the line
			draw_line(start_pos, end_pos, color, 2.0)
