# end_panel.gd
extends Control

@onready var result_label = $Label
@onready var replay_button = $Button
@onready var main_menu_button = $Quit

var is_victory: bool = false

func _ready():
	# Hide the panel initially
	visible = false
	
	# Connect button signals
	replay_button.pressed.connect(_on_replay_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)

# Call this function to show victory screen
func show_victory():
	is_victory = true
	result_label.text = "Victory!"
	result_label.modulate = Color.GOLD  # Golden color for victory
	visible = true
	
	# Optional: Add victory sound effect here
	# AudioManager.play_victory_sound()

# Call this function to show defeat screen  
func show_defeat():
	is_victory = false
	result_label.text = "Defeat!"
	result_label.modulate = Color.CRIMSON  # Red color for defeat
	visible = true
	
	# Optional: Add defeat sound effect here
	# AudioManager.play_defeat_sound()

# Replay the current level
func _on_replay_pressed():
	# Get the current scene file path and reload it
	var _current_scene = get_tree().current_scene.scene_file_path
	get_tree().change_scene_to_file("res://Scenes/menu.tscn")

# Return to main menu
func _on_main_menu_pressed():
	get_tree().change_scene_to_file("res://Scenes/selectLevel.tscn")
