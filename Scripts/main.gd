# main.gd
extends Node2D

var selected_castle: Node2D = null
var is_dragging: bool = false
var drag_start_pos: Vector2
var drag_current_pos: Vector2
var game_ended: bool = false

var dot_animation_time: float = 0.0
var drag_intensity: float = 0.0

var is_paused: bool = false
var current_speed: float = 1.0
var speed_options: Array = [1.0, 2.0, 4.0]
var current_speed_index: int = 0

var EndPanelScene := preload("res://Scenes/end_panel.tscn")
var end_panel_instance: Control = null

@onready var stats_label: Label = $Stats
@onready var pause_button: Button = $PauseButton
@onready var speed_button: Button = $SpeedButton

var game_state_timer: Timer = null

func _ready():
	end_panel_instance = EndPanelScene.instantiate()
	add_child(end_panel_instance)
	
	update_stats_display()
	setup_control_buttons()
	
	game_state_timer = Timer.new()
	game_state_timer.wait_time = 1.0
	game_state_timer.timeout.connect(_on_game_state_timer_timeout)
	game_state_timer.autostart = true
	game_state_timer.process_callback = Timer.TIMER_PROCESS_PHYSICS
	add_child(game_state_timer)
	
	# Initialize engine time scale
	Engine.time_scale = current_speed

func _unhandled_input(event: InputEvent) -> void:
	if game_ended or is_paused:
		return
		
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			toggle_pause()
			return
		elif event.keycode == KEY_S:
			cycle_speed()
			return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var clicked_castle = get_castle_at(event.position)
			
			if clicked_castle and is_instance_valid(clicked_castle) and clicked_castle.castle_owner == "Player":
				selected_castle = clicked_castle
				is_dragging = true
				drag_start_pos = event.position
				drag_current_pos = event.position
				drag_intensity = 0.0
				queue_redraw()
		else:
			if is_dragging and selected_castle and is_instance_valid(selected_castle):
				var target_castle = get_castle_at(event.position)
				
				if target_castle and is_instance_valid(target_castle) and target_castle != selected_castle:
					var success = selected_castle.initiate_player_attack(target_castle)
					if not success:
						show_range_violation_feedback(target_castle)
					else:
						call_deferred("update_stats_display")
				
			selected_castle = null
			is_dragging = false
			drag_intensity = 0.0
			queue_redraw()
	
	elif event is InputEventMouseMotion and is_dragging:
		drag_current_pos = event.position
		queue_redraw()

func _process(delta: float) -> void:
	if is_paused or game_ended:
		return
		
	# Note: delta is already affected by Engine.time_scale, so we don't need to multiply it
	if is_dragging:
		dot_animation_time += delta * 3.0
		drag_intensity = min(drag_intensity + delta * 3.0, 1.0)
		queue_redraw()

func _draw() -> void:
	if is_dragging and selected_castle and is_instance_valid(selected_castle) and not game_ended and not is_paused:
		draw_simplified_drag_arrow()

func draw_simplified_drag_arrow() -> void:
	if not is_instance_valid(selected_castle):
		return
		
	var start_pos = to_local(selected_castle.global_position)
	var end_pos = to_local(drag_current_pos)
	var line_vector = end_pos - start_pos
	var line_length = line_vector.length()
	
	var target_castle = get_castle_at(drag_current_pos)
	var is_valid_target = target_castle and is_instance_valid(target_castle) and target_castle != selected_castle and selected_castle.can_attack_target(target_castle)
	var is_out_of_range = target_castle and is_instance_valid(target_castle) and target_castle != selected_castle and not selected_castle.can_attack_target(target_castle)
	
	if line_length > 10:
		var direction = line_vector.normalized()
		
		var line_width = 2.5 + drag_intensity * 1.0
		
		var base_color: Color
		if is_out_of_range:
			base_color = Color(1.0, 0.4, 0.4)
		elif is_valid_target:
			base_color = Color(0.4, 1.0, 0.4)
		else:
			base_color = Color(0.3, 0.7, 1.0)
		
		var pulse = sin(dot_animation_time * 1.2) * 0.2 + 0.8
		var arrow_color = Color(
			base_color.r * pulse,
			base_color.g * pulse,
			base_color.b * pulse,
			0.8
		)
		
		draw_line(start_pos, end_pos, Color(arrow_color.r, arrow_color.g, arrow_color.b, 0.3), line_width + 1.5)
		draw_line(start_pos, end_pos, arrow_color, line_width)
		
		var num_particles = max(2, int(line_length / 80.0))
		for i in range(num_particles):
			var progress = fposmod(float(i) / num_particles + dot_animation_time * 0.5, 1.0)
			var particle_pos = start_pos + line_vector * progress
			var particle_size = 3.0 + sin(dot_animation_time * 2.0 + i) * 1.0
			
			draw_circle(particle_pos, particle_size + 1.0, Color(arrow_color.r, arrow_color.g, arrow_color.b, 0.4))
			draw_circle(particle_pos, particle_size, Color(arrow_color.r + 0.3, arrow_color.g + 0.2, arrow_color.b + 0.1, 0.7))
		
		var arrow_length = 15.0 + drag_intensity * 5.0
		var arrow_width = 0.4
		var arrow_point1 = end_pos - direction.rotated(arrow_width) * arrow_length
		var arrow_point2 = end_pos - direction.rotated(-arrow_width) * arrow_length
		
		var arrow_points = PackedVector2Array([end_pos, arrow_point1, arrow_point2])
		draw_colored_polygon(arrow_points, Color(arrow_color.r, arrow_color.g, arrow_color.b, 0.3))
		draw_colored_polygon(arrow_points, arrow_color)
		
		draw_line(end_pos, arrow_point1, arrow_color, 1.5)
		draw_line(end_pos, arrow_point2, arrow_color, 1.5)
		
		if target_castle and is_instance_valid(target_castle) and target_castle != selected_castle:
			if is_valid_target:
				var ring_radius = 35.0 + sin(dot_animation_time * 1.5) * 5.0
				var ring_alpha = 0.6 * drag_intensity
				draw_arc(end_pos, ring_radius, 0, TAU, 24, Color(0.4, 1.0, 0.4, ring_alpha), 3.0)
			elif is_out_of_range:
				var cross_size = 25.0
				var cross_alpha = 0.8 * drag_intensity
				var cross_color = Color(1.0, 0.3, 0.3, cross_alpha)
				
				draw_line(end_pos + Vector2(-cross_size, -cross_size), end_pos + Vector2(cross_size, cross_size), cross_color, 4.0)
				draw_line(end_pos + Vector2(-cross_size, cross_size), end_pos + Vector2(cross_size, -cross_size), cross_color, 4.0)
				
				var warning_ring_radius = 40.0 + sin(dot_animation_time * 2.0) * 8.0
				draw_arc(end_pos, warning_ring_radius, 0, TAU, 24, Color(1.0, 0.2, 0.2, cross_alpha * 0.5), 2.0)

func show_range_violation_feedback(target_castle: Node2D) -> void:
	if not target_castle or not is_instance_valid(target_castle):
		return
	
	var feedback_node = CanvasLayer.new()
	add_child(feedback_node)
	
	var label = Label.new()
	label.text = "OUT OF RANGE"
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color.RED)
	label.position = target_castle.global_position + Vector2(-60, -40)
	feedback_node.add_child(label)
	
	var tween = create_tween()
	tween.parallel().tween_property(label, "position", label.position + Vector2(0, -30), 1.5)
	tween.parallel().tween_property(label, "modulate", Color.TRANSPARENT, 1.5)
	tween.tween_callback(func(): 
		if is_instance_valid(feedback_node):
			feedback_node.queue_free()
	)

func get_castle_at(pos: Vector2) -> Node2D:
	var castles = get_tree().get_nodes_in_group("Castles")
	for castle in castles:
		if not is_instance_valid(castle):
			continue
		var castle_pos = castle.global_position
		var size = Vector2(64, 64)
		var rect = Rect2(castle_pos - size/2, size)
		if rect.has_point(pos):
			return castle
	return null

func setup_control_buttons() -> void:
	if pause_button and is_instance_valid(pause_button):
		pause_button.text = "Pause || "
		pause_button.pressed.connect(_on_pause_button_pressed)
	
	if speed_button and is_instance_valid(speed_button):
		update_speed_button_text()
		speed_button.pressed.connect(_on_speed_button_pressed)

func toggle_pause() -> void:
	is_paused = !is_paused
	
	if is_paused:
		# Store current speed and set time scale to 0
		Engine.time_scale = 0.0
	else:
		# Restore the current speed
		Engine.time_scale = current_speed
	
	if pause_button and is_instance_valid(pause_button):
		if is_paused:
			pause_button.text = "Resume ▶️ "
		else:
			pause_button.text = "Pause || "

func cycle_speed() -> void:
	current_speed_index = (current_speed_index + 1) % speed_options.size()
	current_speed = speed_options[current_speed_index]
	
	# Apply the new speed to the engine (unless paused)
	if not is_paused:
		Engine.time_scale = current_speed
	
	update_speed_button_text()

func update_speed_button_text() -> void:
	if speed_button and is_instance_valid(speed_button):
		speed_button.text = "Speed: %.0fx" % current_speed

func _on_pause_button_pressed() -> void:
	toggle_pause()

func _on_speed_button_pressed() -> void:
	cycle_speed()

func _on_button_pressed() -> void:
	# Reset time scale when leaving the scene
	Engine.time_scale = 1.0
	
	if is_instance_valid(game_state_timer):
		game_state_timer.stop()
	get_tree().change_scene_to_file("res://Scenes/menu.tscn")

func _on_game_state_timer_timeout():
	if game_ended or is_paused:
		return
	
	check_game_state()
	call_deferred("update_stats_display")

func get_player_castles() -> Array:
	var castles = get_tree().get_nodes_in_group("Castles")
	var result = []
	for castle in castles:
		if is_instance_valid(castle) and castle.castle_owner == "Player":
			result.append(castle)
	return result

func get_enemy_castles() -> Array:
	var castles = get_tree().get_nodes_in_group("Castles")
	var result = []
	for castle in castles:
		if is_instance_valid(castle) and castle.castle_owner == "Enemy":
			result.append(castle)
	return result

func get_neutral_castles() -> Array:
	var castles = get_tree().get_nodes_in_group("Castles")
	var result = []
	for castle in castles:
		if is_instance_valid(castle) and castle.castle_owner == "Neutral":
			result.append(castle)
	return result

func update_stats_display() -> void:
	if not stats_label or not is_instance_valid(stats_label):
		return
	
	var player_castles = get_player_castles()
	var enemy_castles = get_enemy_castles()
	var neutral_castles = get_neutral_castles()
	
	var player_troops = 0
	var enemy_troops = 0
	var neutral_troops = 0
	
	for castle in player_castles:
		if not is_instance_valid(castle):
			continue
		if castle.has_method("get_troop_count"):
			player_troops += castle.get_troop_count()
		elif "troop_count" in castle:
			player_troops += castle.troop_count
		elif "troops" in castle:
			player_troops += castle.troops
	
	for castle in enemy_castles:
		if not is_instance_valid(castle):
			continue
		if castle.has_method("get_troop_count"):
			enemy_troops += castle.get_troop_count()
		elif "troop_count" in castle:
			enemy_troops += castle.troop_count
		elif "troops" in castle:
			enemy_troops += castle.troops
	
	for castle in neutral_castles:
		if not is_instance_valid(castle):
			continue
		if castle.has_method("get_troop_count"):
			neutral_troops += castle.get_troop_count()
		elif "troop_count" in castle:
			neutral_troops += castle.troop_count
		elif "troops" in castle:
			neutral_troops += castle.troops
	
	var stats_text = "Player Castles: %d\nNeutral Castles: %d\nEnemy Castles: %d\nPlayer Troops: %d\nNeutral Troops: %d\nEnemy Troops: %d" % [
		player_castles.size(),
		neutral_castles.size(),
		enemy_castles.size(),
		player_troops,
		neutral_troops,
		enemy_troops
	]
	
	stats_label.text = stats_text

func check_game_state() -> void:
	if game_ended:
		return
		
	var player_castles = get_player_castles()
	var enemy_castles = get_enemy_castles()
	var neutral_castles = get_neutral_castles()
	
	if player_castles.is_empty():
		print("Game Over - Player Lost!")
		game_ended = true
		# Reset time scale
		Engine.time_scale = 1.0
		if is_instance_valid(game_state_timer):
			game_state_timer.stop()
		var t = get_tree().create_timer(2.0)
		t.timeout.connect(func(): 
			if is_instance_valid(end_panel_instance):
				end_panel_instance.show_defeat()
		)
		
	elif enemy_castles.is_empty() and neutral_castles.is_empty():
		print("Victory - Player Won!")
		game_ended = true
		# Reset time scale
		Engine.time_scale = 1.0
		if is_instance_valid(game_state_timer):
			game_state_timer.stop()
		var t = get_tree().create_timer(2.0)
		t.timeout.connect(func(): 
			if is_instance_valid(end_panel_instance):
				end_panel_instance.show_victory()
		)
