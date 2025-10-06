# SettingsPanel.gd
extends Control

@onready var music_slider = $VBoxContainer/MusicVolumeSlider
@onready var volume_label = $VBoxContainer/VolumeValueLabel

func _ready():
	# Configure the slider
	music_slider.min_value = 0.0
	music_slider.max_value = 1.0
	music_slider.step = 0.01
	music_slider.value = MusicManager.get_music_volume()
	
	# Connect slider signal
	music_slider.value_changed.connect(_on_music_volume_changed)
	
	# Update the label
	_update_volume_label()

func _on_music_volume_changed(value: float):
	MusicManager.set_music_volume(value)
	_update_volume_label()

func _update_volume_label():
	var percentage = int(music_slider.value * 100)
	volume_label.text = str(percentage) + "%"



func _on_close_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/menu.tscn")
