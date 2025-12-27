extends AIController2D

# References
@onready var player = get_parent()
@onready var raycast_container = $"../RayCastContainer" # We will make this in Step 4

# --- 1. OBSERVATION (The Eyes) ---
# We must return a Dictionary with a key "obs" containing an Array of numbers.
func get_obs() -> Dictionary:
	var obs = []
	
	# A. Proprioception (Body Awareness)
	# Normalize values to be roughly between -1.0 and 1.0 for better learning
	obs.append(player.velocity.x / 1000.0)
	obs.append(player.velocity.y / 1000.0)
	obs.append(1.0 if player.is_on_floor() else 0.0)
	obs.append(1.0 if player.can_dash else 0.0)
	
	# B. Exteroception (Vision via Raycasts)
	# Iterate through all raycasts to see walls/hazards
	for ray in raycast_container.get_children():
		if ray is RayCast2D:
			ray.force_raycast_update()
			# If hitting something, return distance (normalized). If clear, return 0.
			if ray.is_colliding():
				var dist = ray.global_position.distance_to(ray.get_collision_point())
				obs.append(1.0 - (dist / ray.target_position.length()))
			else:
				obs.append(0.0)
				
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
	# Map the AI's output directly to the Player's variables
	player.input_x = clamp(action["move_x"][0], -1.0, 1.0)
	player.input_y = clamp(action["move_y"][0], -1.0, 1.0)
	player.input_jump_pressed = action["jump"] == 1
	player.input_jump_held = action["jump"] == 1 # Simple hold logic
	player.input_dash = action["dash"] == 1
