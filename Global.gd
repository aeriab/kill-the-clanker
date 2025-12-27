extends Node



var use_particles: bool = false









# This script will be active across all scenes because it's an Autoload.

func _unhandled_input(event):
	# Check if the 'reload_scene' action was just pressed
	if event.is_action_pressed("reload_scene"):
		reload_current_scene()
		# Optionally, set 'event.accepted = true' if you want to prevent other nodes from using this input

func reload_current_scene():
	get_tree().reload_current_scene()
