# ui_sound_manager.gd
extends Node

var click_sound: AudioStream

func _ready():
	click_sound = preload("res://Audio/cassette-recorder-stop-button-mechanical-click-sound-359987.mp3")
	# Wait for scene tree to be ready
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(node):
	if node is Button:
		node.pressed.connect(_on_button_pressed)  # Remove .bind(node)

func _on_button_pressed():  # No parameter needed
	var audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	audio_player.stream = click_sound
	audio_player.play()
	audio_player.finished.connect(audio_player.queue_free)
