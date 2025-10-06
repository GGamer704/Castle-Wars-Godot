# MusicManager.gd
extends Node

var audio_player: AudioStreamPlayer
var music_volume: float = 1.0  # Store volume as linear value (0.0 to 1.0)

func _ready():
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	
	# Load saved volume from settings
	load_volume_settings()
	
	var music = preload("res://Audio/Videogame Fantasy (3dec9aef427a47629c514f504059f7fb).mp3")
	audio_player.stream = music
	if audio_player.stream:
		audio_player.stream.loop = true
	audio_player.play()

func set_music_volume(linear_volume: float):
	music_volume = clamp(linear_volume, 0.0, 1.0)
	# Convert linear volume to decibels
	if music_volume > 0:
		audio_player.volume_db = linear_to_db(music_volume)
	else:
		audio_player.volume_db = -80  # Effectively mute
	
	# Save the setting
	save_volume_settings()

func get_music_volume() -> float:
	return music_volume

func save_volume_settings():
	var config = ConfigFile.new()
	config.set_value("audio", "music_volume", music_volume)
	config.save("user://settings.cfg")

func load_volume_settings():
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		music_volume = config.get_value("audio", "music_volume", 1.0)
		set_music_volume(music_volume)

func play_music(music_resource):
	audio_player.stream = music_resource
	if audio_player.stream:
		audio_player.stream.loop = true
	audio_player.play()

func stop_music():
	audio_player.stop()
