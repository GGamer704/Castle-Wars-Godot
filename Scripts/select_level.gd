extends Control


func _on_level_1_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/levels/main.tscn")



func _on_level_2_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/levels/level_1.tscn")


func _on_level_3_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/levels/level_2.tscn")


func _on_level_4_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/levels/level_3.tscn")


func _on_level_5_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/levels/level_4.tscn")

func _on_level_6_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/levels/level_5.tscn")

func _on_level_7_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/levels/level_6.tscn")

func _on_level_8_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/levels/level_7.tscn")

func _on_level_9_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/levels/level_8.tscn")

func _on_level_10_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/levels/level_9.tscn")
 
 #Go tu menu button
func _on_quit_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/menu.tscn")
