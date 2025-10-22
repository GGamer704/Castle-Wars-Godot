# end_panel.gd
extends Control

@onready var result_label = $Label
@onready var replay_button = $Button
@onready var main_menu_button = $Quit

# Preload the sound effects
@onready var victory_sound = preload("res://Audio/8-bit-victory-sound-101319.mp3")
@onready var defeat_sound = preload("res://Audio/8-bit-video-game-fail-version-2-145478.mp3")

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
	
	# Play victory sound
	play_sound(victory_sound)

# Call this function to show defeat screen  
func show_defeat():
	is_victory = false
	result_label.text = "Defeat!"
	result_label.modulate = Color.CRIMSON  # Red color for defeat
	visible = true
	
	# Play defeat sound
	play_sound(defeat_sound)

# Helper function to play sounds
func play_sound(sound_stream: AudioStream):
	var audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	audio_player.stream = sound_stream
	audio_player.play()
	# Clean up after sound finishes
	audio_player.finished.connect(audio_player.queue_free)

# Replay the current level
func _on_replay_pressed():
	# Get the current scene file path and reload it
	var _current_scene = get_tree().current_scene.scene_file_path
	get_tree().change_scene_to_file("res://Scenes/menu.tscn")

# Return to main menu
func _on_main_menu_pressed():
	get_tree().change_scene_to_file("res://Scenes/selectLeve.tscn")
