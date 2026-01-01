extends AIController2D

# --- DEBUG SETTINGS ---
@export var debug_mode: bool = true
@export var debug_interval_frames: int = 60 
var _frame_counter: int = 0

@onready var player = get_parent()
@onready var raycast_container = $"../RayCastContainer"

func get_obs() -> Dictionary:
	var obs = []
	
	# Raw values for debug printing
	var raw_vel = player.velocity
	var raw_pos = player.global_position
	
	# --- 1. PROPRIOCEPTION ---
	obs.append(clamp(player.velocity.x / 1000.0, -1.0, 1.0))
	obs.append(clamp(player.velocity.y / 1000.0, -1.0, 1.0))
	obs.append(player.global_position.x / 1152.0)
	obs.append(player.global_position.y / 648.0)
	obs.append(1.0 if player.is_on_floor() else 0.0)
	obs.append(1.0 if player.can_dash else 0.0)
	
	var grid_obs = player.get_grid_observation()
	obs.append_array(grid_obs)
	
	# --- 2. EXTEROCEPTION (Walls) ---
	var ray_hits = [] 
	var ray_index = 0
	
	for ray in raycast_container.get_children():
		if ray is RayCast2D:
			ray.force_raycast_update()
			if ray.is_colliding():
				var dist = ray.global_position.distance_to(ray.get_collision_point())
				var max_len = ray.target_position.length()
				obs.append(1.0 - (dist / max_len))
				
				if debug_mode and _frame_counter % debug_interval_frames == 0:
					ray_hits.append("Ray %d: %.1f px" % [ray_index, dist])
			else:
				obs.append(0.0)
			ray_index += 1

	# --- DEBUG PRINT SNAPSHOT ---
	if debug_mode and _frame_counter % debug_interval_frames == 0:
		print("\n--- AI BRAIN SNAPSHOT (Frame %d) ---" % _frame_counter)
		print("SENSES:")
		print(" > Velocity: ", raw_vel)
		print(" > Position: ", raw_pos)
		print(" > Can Dash: ", player.can_dash)
		print(" > Raycasts Hit: ", ray_hits)
		var active_cells = grid_obs.count(1.0) 
		print(" > Grid Active Cells: ", active_cells) 
		print(" > TOTAL OBS SIZE: ", obs.size())

	return {"obs": obs}

func get_reward() -> float:
	var reward_var = 0.0
	# 1. Survival Reward
	reward_var += 0.1 

	# 2. Conservation Reward
	if player.can_dash:
		reward_var += 0.05
		
	# 3. Center Bias
	var dist_from_center = player.global_position.distance_to(player.start_position)
	if dist_from_center < 300.0:
		reward_var += 0.05
		
	return reward_var

# --- RESTORED CONTINUOUS ACTION SPACE ---
func get_action_space() -> Dictionary:
	return {
		# Continuous: Size 1 means "1 float value" (e.g., 0.5)
		"move_x": {"size": 1, "action_type": "continuous"}, 
		"move_y": {"size": 1, "action_type": "continuous"}, 
		
		# Discrete: Size 2 means "2 choices" (0 or 1)
		"jump":   {"size": 1, "action_type": "discrete"},
		"dash":   {"size": 1, "action_type": "discrete"} 
	}

func set_action(action) -> void:
	_frame_counter += 1
	
	# Extract Raw Float Values (Continuous returns an array like [0.5])
	var raw_x = action["move_x"][0]
	var raw_y = action["move_y"][0]
	var jump_act = action["jump"]
	var dash_act = action["dash"]

	# --- RESTORED LOGIC FROM OLD CODE ---
	# This creates a "deadzone". If output is weak (< 0.5), we stop. 
	# If strong (> 0.5), we snap to 1.0 or -1.0.
	player.input_x = 0.0 if abs(raw_x) < 0.5 else sign(raw_x)
	player.input_y = 0.0 if abs(raw_y) < 0.5 else sign(raw_y)

	player.input_jump_pressed = jump_act == 1
	player.input_jump_held = jump_act == 1 
	player.input_dash = dash_act == 1

	# --- UPDATED DEBUG FOR CONTINUOUS ---
	if debug_mode and _frame_counter % debug_interval_frames == 0:
		print("INTENTIONS:")
		print(" > Move X (Raw): %.2f -> Input: %.1f" % [raw_x, player.input_x])
		print(" > Move Y (Raw): %.2f -> Input: %.1f" % [raw_y, player.input_y])
		print(" > Actions: %s %s" % ["JUMP!" if jump_act else "...", "DASH!" if dash_act else "..."])
		print("---------------------------------------")

# --- DEBUG DRAWING ---
func _physics_process(_delta):
	queue_redraw()
