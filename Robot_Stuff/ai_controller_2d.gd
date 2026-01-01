extends AIController2D

@onready var player = get_parent()
@onready var raycast_container = $"../RayCastContainer"
#@onready var raycast_container: Node2D = $"../NewRayCastContainer"

# Define the 8 Dash Directions explicitly for easy mapping
# Godot 2D: Up is (0, -1), Down is (0, 1)
const DASH_DIRECTIONS = [
	Vector2.ZERO,      # 0: No Dash
	Vector2(0, -1),    # 1: Up
	Vector2(1, -1),    # 2: Up-Right
	Vector2(1, 0),     # 3: Right
	Vector2(1, 1),     # 4: Down-Right
	Vector2(0, 1),     # 5: Down
	Vector2(-1, 1),    # 6: Down-Left
	Vector2(-1, 0),    # 7: Left
	Vector2(-1, -1)    # 8: Up-Left
]

func get_obs() -> Dictionary:
	var obs = []
	
	# --- 1. PROPRIOCEPTION ---
	obs.append(clamp(player.velocity.x / 1000.0, -1.0, 1.0))
	obs.append(clamp(player.velocity.y / 1000.0, -1.0, 1.0))
	obs.append(player.global_position.x / 1152.0)
	obs.append(player.global_position.y / 648.0)
	obs.append(1.0 if player.is_on_floor() else 0.0)
	obs.append(1.0 if player.can_dash else 0.0)
	
	
	obs.append_array(player.get_grid_observation())
	
	
	# --- 2. EXTEROCEPTION (Walls) ---
	for ray in raycast_container.get_children():
		if ray is RayCast2D:
			ray.force_raycast_update()
			if ray.is_colliding():
				var dist = ray.global_position.distance_to(ray.get_collision_point())
				var max_len = ray.target_position.length()
				obs.append(1.0 - (dist / max_len))
			else:
				obs.append(0.0)
	#
	## --- 3. OBJECT TRACKING (Missiles) ---
	#var missiles = get_tree().get_nodes_in_group("missiles")
	#missiles.sort_custom(func(a, b): 
		#return a.global_position.distance_squared_to(player.global_position) < b.global_position.distance_squared_to(player.global_position)
	#)
	#
	#var max_targets = 12
	#var sensing_range = 1000.0 
	#
	#for i in range(max_targets):
		#if i < missiles.size() and is_instance_valid(missiles[i]):
			#var m = missiles[i]
			#var rel_pos = m.global_position - player.global_position
			#obs.append(clamp(rel_pos.x / sensing_range, -1.0, 1.0))
			#obs.append(clamp(rel_pos.y / sensing_range, -1.0, 1.0))
			#
			#var m_vel = Vector2.ZERO
			#if "velocity" in m: m_vel = m.velocity
			#obs.append(clamp((m_vel.x) / 1000.0, -1.0, 1.0))
			#obs.append(clamp((m_vel.y) / 1000.0, -1.0, 1.0))
		#else:
			#obs.append(0.0); obs.append(0.0); obs.append(0.0); obs.append(0.0)
			#
	print("OBSERVATION SHAPE: ", obs.size())
	return {"obs": obs}


func get_reward() -> float:
	var reward_var = 0.0
	# 1. Survival Reward (Keep this small per frame)
	reward_var += 0.1 

	# 2. Conservation Reward (Smaller than survival)
	if player.can_dash:
		reward_var += 0.05
		
	# 3. Center Bias (Optional: Keeps them from camping edges)
	# Normalized distance from center (0.0 to 1.0 approx)
	var dist_from_center = player.global_position.distance_to(player.start_position)
	if dist_from_center < 300.0:
		reward_var += 0.05
		
	return reward_var

#func get_reward() -> float:
	#var reward_placeholder = 1.0
	#if player.can_dash:
		#reward_placeholder += 0.7
	#return reward_placeholder


func get_action_space() -> Dictionary:
	var space = {
		"move_x": {"size": 3, "action_type": "discrete"},
		"jump":   {"size": 2, "action_type": "discrete"},
		"dash":   {"size": 9, "action_type": "discrete"}
	}
	print("ACTION SPACE SIZE: ", space.size(), " KEYS: ", space.keys())
	return space

func set_action(action) -> void:
	# 1. Handle Movement (Discrete Arrow Keys)
	var move_idx = action["move_x"]
	match move_idx:
		0: player.input_x = -1.0 # Left
		1: player.input_x = 0.0  # Neutral
		2: player.input_x = 1.0  # Right
	
	# Reset Y input (only used for dashing now)
	player.input_y = 0.0

	# 2. Handle Jump
	player.input_jump_pressed = action["jump"] == 1
	player.input_jump_held = action["jump"] == 1 

	# 3. Handle Directional Dash
	var dash_idx = action["dash"]
	
	if dash_idx > 0:
		# If AI wants to dash, we ACTIVATE dash and OVERRIDE inputs
		player.input_dash = true
		
		var direction = DASH_DIRECTIONS[dash_idx]
		
		# Force the player inputs to match the dash direction
		# This ensures the game engine dashes where the AI intends, 
		# ignoring the 'move_x' walking input for this frame.
		player.input_x = direction.x
		player.input_y = direction.y
	else:
		player.input_dash = false


# --- DEBUG ---
func _physics_process(_delta):
	queue_redraw()

#func _draw():
	#for ray in raycast_container.get_children():
		#if ray is RayCast2D:
			#var start = to_local(ray.global_position)
			#var end = to_local(ray.global_position + ray.target_position)
			#var color = Color.BLUE
			#if ray.is_colliding():
				#end = to_local(ray.get_collision_point())
				#color = Color.GREEN
			#draw_line(start, end, color, 2.0)
