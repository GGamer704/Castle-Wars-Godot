# BaseCastle.gd
extends StaticBody2D

@export var max_troops: int = 25
@export var regen_rate: float = 0.5  # Reduced from 1.0 - slower troop generation
@export var initial_troops: int = 10
@export var attack_range: float = 200.0  # Now used for both AI and player attacks
@export var attack_cooldown: float = 5.0  # Increased from 3.0 - slower attacks
@export var min_troops_to_attack: int = 5
@export var attack_percentage: float = 0.5
@export var troop_speed: float = 200.0

# Castle ownership
@export_enum("Player", "Enemy", "Neutral") var castle_owner: String = "Neutral"

var troops: int = 10
var timer := 0.0
var attack_timer := 0.0
var current_target: Node = null
var is_attacking: bool = false
var glow_time := 0.0

# Simplified attack arrow variables
var showing_arrow: bool = false
var arrow_target_pos: Vector2
var dot_animation_time: float = 0.0
var arrow_timer: Timer
var arrow_fade_alpha: float = 1.0

# Audio
var audio_player: AudioStreamPlayer
var capture_sound := preload("res://Audio/armor-impact-from-sword-393843.mp3")

@onready var label: Label = $Label
@onready var sprite: Sprite2D = $Sprite2D

# Visual components
var troop_group: Node2D
var moving_troops: Array = []

# Troop dot scene - moved from main
var TroopDotScene := preload("res://Scenes/TroopDot.tscn")

func _ready() -> void:
	add_to_group("Castles")
	troops = initial_troops
	setup_visual_components()
	setup_audio()
	update_visuals()
	attack_timer = randf() * attack_cooldown

func setup_audio() -> void:
	audio_player = AudioStreamPlayer.new()
	audio_player.stream = capture_sound
	add_child(audio_player)

func setup_visual_components() -> void:
	# Container for moving troops
	troop_group = Node2D.new()
	troop_group.name = "MovingTroops"
	get_parent().add_child(troop_group)

func _process(delta: float) -> void:
	# Troop regeneration (not for neutral castles)
	timer += delta
	if castle_owner != "Neutral" and timer >= 1.0 / regen_rate and troops < max_troops:
		troops += 1
		timer = 0.0
		update_visuals()

	# Enemy AI attack logic
	if castle_owner == "Enemy":
		attack_timer += delta
		if attack_timer >= attack_cooldown and not is_attacking:
			consider_attack()
			attack_timer = 0.0

	update_moving_troops(delta)
	
	# Visual effects
	glow_time += delta
	update_castle_glow()
	
	if showing_arrow:
		dot_animation_time += delta * 3.0
		queue_redraw()

func _draw() -> void:
	if showing_arrow and current_target:
		draw_simplified_attack_arrow()
	
	# Draw attack range indicator when selected (for player castles)
	if castle_owner == "Player" and is_selected():
		draw_attack_range()

func draw_attack_range() -> void:
	# Draw a subtle circle showing attack range
	var range_color = Color(0.3, 0.7, 1.0, 0.2)  # Light blue with transparency
	var range_outline = Color(0.3, 0.7, 1.0, 0.4)
	
	# Filled circle for range area
	draw_circle(Vector2.ZERO, attack_range, range_color)
	
	# Dotted outline for better visibility
	var segments = 64
	for i in segments:
		var angle1 = (i * TAU) / segments
		var angle2 = ((i + 1) * TAU) / segments
		var point1 = Vector2.from_angle(angle1) * attack_range
		var point2 = Vector2.from_angle(angle2) * attack_range
		
		# Only draw every other segment for dotted effect
		if i % 2 == 0:
			draw_line(point1, point2, range_outline, 2.0)

func is_selected() -> bool:
	# Check if this castle is currently selected in main scene
	var main_scene = get_tree().current_scene
	if main_scene and "selected_castle" in main_scene:
		return main_scene.selected_castle == self
	return false

func draw_simplified_attack_arrow() -> void:
	var start_pos = Vector2.ZERO
	var end_pos = to_local(current_target.global_position)
	var line_vector = end_pos - start_pos
	var line_length = line_vector.length()
	
	if line_length > 10:
		var direction = line_vector.normalized()
		var base_color = get_owner_color()
		
		# Simpler line width
		var line_width = 2.5
		
		# Cleaner arrow color with subtle pulse
		var pulse = sin(dot_animation_time * 1.5) * 0.2 + 0.8
		var arrow_color = Color(
			base_color.r * pulse,
			base_color.g * pulse,
			base_color.b * pulse,
			arrow_fade_alpha * 0.8
		)
		
		# Single glow layer for subtle depth
		draw_line(start_pos, end_pos, Color(arrow_color.r, arrow_color.g, arrow_color.b, 0.3 * arrow_fade_alpha), line_width + 2.0)
		
		# Main arrow line
		draw_line(start_pos, end_pos, arrow_color, line_width)
		
		# Fewer, smaller moving particles
		var num_particles = max(2, int(line_length / 60.0))
		for i in range(num_particles):
			var progress = fposmod(float(i) / num_particles + dot_animation_time * 0.4, 1.0)
			var particle_pos = start_pos + line_vector * progress
			var particle_size = 3.0 + sin(dot_animation_time * 2.0 + i) * 1.0
			var particle_alpha = 0.6 * arrow_fade_alpha
			
			# Simple particle with subtle glow
			draw_circle(particle_pos, particle_size + 1.0, Color(arrow_color.r, arrow_color.g, arrow_color.b, particle_alpha * 0.4))
			draw_circle(particle_pos, particle_size, Color(arrow_color.r + 0.2, arrow_color.g + 0.2, arrow_color.b + 0.2, particle_alpha))
		
		# Smaller, cleaner arrowhead
		var arrow_length = 15.0
		var arrow_width = 0.4
		var arrow_point1 = end_pos - direction.rotated(arrow_width) * arrow_length
		var arrow_point2 = end_pos - direction.rotated(-arrow_width) * arrow_length
		
		# Arrowhead with simple glow
		var arrow_points = PackedVector2Array([end_pos, arrow_point1, arrow_point2])
		draw_colored_polygon(arrow_points, Color(arrow_color.r, arrow_color.g, arrow_color.b, 0.3 * arrow_fade_alpha))
		draw_colored_polygon(arrow_points, arrow_color)
		
		# Simple arrowhead outline
		draw_line(end_pos, arrow_point1, arrow_color, 1.5)
		draw_line(end_pos, arrow_point2, arrow_color, 1.5)

# Check if target castle is within attack range
func can_attack_target(target_castle: Node2D) -> bool:
	if not target_castle or target_castle == self:
		return false
	
	var distance = global_position.distance_to(target_castle.global_position)
	return distance <= attack_range

# NEW: Handle player-initiated attacks with range check
func initiate_player_attack(target_castle: Node2D) -> bool:
	if castle_owner != "Player":
		return false
	
	# Check if target is within attack range
	if not can_attack_target(target_castle):
		print("Target castle is out of attack range!")
		return false
		
	var troops_to_send = max(1, troops / 2)
	send_troops(target_castle, troops_to_send)
	
	# Spawn enhanced visual troop dots with player color (blue)
	spawn_enhanced_troop_dots(self, target_castle, int(troops_to_send), Color.CYAN)
	return true

# Enhanced troop dots spawning with better visuals (moved from main)
func spawn_enhanced_troop_dots(from_castle: Node2D, to_castle: Node2D, troop_count: int, color: Color) -> void:
	var max_dots = 35  # Slightly more for better effect
	var dots = min(max_dots, troop_count)
	
	var from_pos = from_castle.global_position
	var to_pos = to_castle.global_position
	
	# Get the main scene to add dots to
	var main_scene = get_tree().current_scene
	
	for i in range(dots):
		var dot = TroopDotScene.instantiate()
		
		# Start with slight spread around castle center for organic feel
		var spawn_offset = Vector2(randf_range(-20, 20), randf_range(-20, 20))
		dot.position = main_scene.to_local(from_pos + spawn_offset)
		
		# Target with slight spread for natural arrival
		var arrival_offset = Vector2(randf_range(-30, 30), randf_range(-30, 30))
		dot.target_pos = main_scene.to_local(to_pos + arrival_offset)
		
		# Enhanced color with slight variation
		var color_variation = Color(
			color.r + randf_range(-0.1, 0.1),
			color.g + randf_range(-0.1, 0.1),
			color.b + randf_range(-0.1, 0.1),
			color.a
		)
		dot.color = color_variation
		
		# Stagger the launch slightly for more natural feel
		dot.position.y += i * 2  # Slight delay effect
		
		main_scene.add_child(dot)

# Spawns moving troop dots between castles (keeping original for compatibility)
func spawn_troop_dots(from_castle: Node2D, to_castle: Node2D, troop_count: int, color: Color) -> void:
	spawn_enhanced_troop_dots(from_castle, to_castle, troop_count, color)

# Get color based on owner
func get_owner_color() -> Color:
	match castle_owner:
		"Player":
			return Color.BLUE
		"Enemy":
			return Color.RED
		"Neutral":
			return Color.WHITE
		_:
			return Color.WHITE

# Update all visual elements
func update_visuals() -> void:
	update_label()
	update_sprite_color()

func update_label() -> void:
	if label:
		label.text = str(troops)
		label.modulate = get_owner_color()

func update_sprite_color() -> void:
	if sprite:
		# Load the appropriate sprite texture based on castle owner
		match castle_owner:
			"Player":
				sprite.texture = load("res://Sprites/player_castle.png")
				sprite.modulate = Color.WHITE  # No color tint needed with custom sprites
			"Enemy":
				sprite.texture = load("res://Sprites/enemy_castle.png")
				sprite.modulate = Color.WHITE
			"Neutral":
				sprite.texture = load("res://Sprites/ruin_castle.png")
				sprite.modulate = Color.WHITE
			_:
				sprite.texture = load("res://Sprites/ruin_castle.png")
				sprite.modulate = Color.WHITE

func update_castle_glow() -> void:
	if is_attacking and has_node("Glow"):
		var glow_node = get_node("Glow")
		var base_color = get_owner_color()
		var bright_color = Color(base_color.r + 0.5, base_color.g + 0.3, base_color.b, 1.0)
		glow_node.modulate = base_color.lerp(bright_color, sin(glow_time * 5.0))

# Change castle ownership
func change_owner(new_owner: String) -> void:
	castle_owner = new_owner
	update_visuals()
	
	# Reset attack timer for new enemy castles
	if castle_owner == "Enemy":
		attack_timer = randf() * attack_cooldown

# Troop management
func send_troops(target: Node, amount: int) -> void:
	if amount > 0 and amount <= troops:
		troops -= amount
		update_visuals()
		
		# Create visual attack if this is an enemy castle
		if castle_owner == "Enemy":
			current_target = target
			show_attack_arrow(target)
			create_moving_troops(target, amount)
		
		target.receive_troops(amount, castle_owner)

func receive_troops(amount: int, sender_owner: String) -> void:
	if sender_owner == castle_owner:
		# Friendly reinforcement
		troops += amount
	else:
		# Battle! Defending troops fight attacking troops
		troops -= amount
		if troops <= 0:
			# Castle captured by attacker
			var leftover_troops = abs(troops)
			change_owner(sender_owner)
			audio_player.play()  # Play capture sound
			troops = leftover_troops
	
	update_visuals()

# Enemy AI logic
func consider_attack() -> void:
	if castle_owner != "Enemy" or troops <= min_troops_to_attack:
		return

	var best_target = find_best_target()
	if best_target:
		var nearby_player_castles = get_tree().get_nodes_in_group("Castles").filter(func(c):
			return c.castle_owner == "Player" and global_position.distance_to(c.global_position) <= attack_range
		)
		var attack_multiplier = 1.0 + 0.5 * nearby_player_castles.size()
		execute_visual_attack(best_target, attack_multiplier)

func find_best_target() -> Node:
	var castles = get_tree().get_nodes_in_group("Castles")
	var best_target: Node = null
	var best_score: float = -1.0

	for castle in castles:
		if castle == self or castle.castle_owner == "Enemy":
			continue
		var distance = global_position.distance_to(castle.global_position)
		if distance > attack_range:
			continue
		var score = calculate_attack_score(castle, distance)
		if score > best_score:
			best_score = score
			best_target = castle
	return best_target

func calculate_attack_score(target: Node, distance: float) -> float:
	var score: float = 0.0
	score += (attack_range - distance) / attack_range * 100.0
	var enemy_troops = target.troops if "troops" in target else 0
	var troops_advantage = max(0, troops - enemy_troops - min_troops_to_attack)
	score += troops_advantage * 10.0

	if "castle_owner" in target:
		if target.castle_owner == "Player":
			score += 50.0  # Prioritize player castles
		elif target.castle_owner == "Neutral":
			score += 20.0  # Also target neutral for expansion

	var attack_force = int(float(troops - min_troops_to_attack) * attack_percentage)
	if attack_force > enemy_troops:
		score += 100.0  # Bonus for likely victory
	return score

func execute_visual_attack(target: Node, multiplier: float = 1.0) -> void:
	var available_troops = troops - min_troops_to_attack
	var attack_force = int(float(available_troops) * attack_percentage * multiplier)
	attack_force = max(1, min(attack_force, available_troops))

	if attack_force > 0:
		current_target = target
		is_attacking = true
		troops -= attack_force
		update_visuals()
		show_attack_arrow(target)
		create_moving_troops(target, attack_force)
		print("Enemy castle attacking with ", attack_force, " troops!")

# Simplified attack arrow visual with fade-out effect
func show_attack_arrow(target: Node) -> void:
	if target:
		showing_arrow = true
		current_target = target
		dot_animation_time = 0.0
		arrow_fade_alpha = 1.0
		queue_redraw()
		
		# Create timer for fading out arrow
		arrow_timer = Timer.new()
		add_child(arrow_timer)
		arrow_timer.wait_time = 1.2  # Shorter duration
		arrow_timer.one_shot = true
		arrow_timer.timeout.connect(_on_arrow_fade_start)
		arrow_timer.start()

func _on_arrow_fade_start() -> void:
	# Start fade out animation
	var fade_tween = create_tween()
	fade_tween.tween_property(self, "arrow_fade_alpha", 0.0, 0.3)
	fade_tween.tween_callback(_on_arrow_timeout)

func _on_arrow_timeout() -> void:
	showing_arrow = false
	current_target = null
	arrow_fade_alpha = 1.0
	queue_redraw()
	if arrow_timer:
		arrow_timer.queue_free()
		arrow_timer = null

# Enhanced moving troops visuals
func create_moving_troops(target: Node, amount: int) -> void:
	var start_pos = global_position
	var end_pos = target.global_position
	var distance = start_pos.distance_to(end_pos)
	var travel_time = distance / troop_speed

	for i in range(min(amount, 12)):  # Slightly more visual troops
		var troop_visual = create_enhanced_troop_visual()
		troop_group.add_child(troop_visual)
		var spawn_offset = Vector2(randf_range(-25,25), randf_range(-25,25))
		troop_visual.global_position = start_pos + spawn_offset
		var troop_data = {
			"visual": troop_visual,
			"start_pos": troop_visual.global_position,
			"end_pos": end_pos + Vector2(randf_range(-35,35), randf_range(-35,35)),
			"travel_time": travel_time + randf_range(-0.3,0.3),
			"elapsed_time": 0.0,
			"target": target,
			"amount": amount if i == 0 else 0,
			"trail_points": []
		}
		moving_troops.append(troop_data)

func create_enhanced_troop_visual() -> Node2D:
	var troop = Node2D.new()
	var base_color = get_owner_color()
	
	# Main troop circle with glow
	var circle = ColorRect.new()
	circle.size = Vector2(12,12)
	circle.position = Vector2(-6,-6)
	circle.color = base_color
	troop.add_child(circle)
	
	# Inner bright core
	var core = ColorRect.new()
	core.size = Vector2(6,6)
	core.position = Vector2(-3,-3)
	core.color = Color(1.0, 1.0, 1.0, 0.8)
	troop.add_child(core)
	
	# Pulsing glow effect
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(circle, "scale", Vector2(1.4, 1.4), 0.4)
	tween.tween_property(circle, "scale", Vector2.ONE, 0.4)
	
	# Rotation for dynamic feel
	var rotation_tween = create_tween()
	rotation_tween.set_loops()
	rotation_tween.tween_property(troop, "rotation", TAU, 2.0)
	
	return troop

func update_moving_troops(delta: float) -> void:
	for i in range(moving_troops.size()-1, -1, -1):
		var troop_data = moving_troops[i]
		troop_data.elapsed_time += delta
		var progress = troop_data.elapsed_time / troop_data.travel_time
		
		if progress >= 1.0:
			if troop_data.amount > 0 and troop_data.target:
				troop_data.target.receive_troops(troop_data.amount, castle_owner)
			if is_instance_valid(troop_data.visual):
				troop_data.visual.queue_free()
			moving_troops.remove_at(i)
			if moving_troops.is_empty():
				is_attacking = false
		else:
			if is_instance_valid(troop_data.visual):
				# Smooth curved movement with slight wobble
				var base_pos = troop_data.start_pos.lerp(troop_data.end_pos, progress)
				var wobble = sin(progress * PI * 3.0) * 15.0
				var perpendicular = (troop_data.end_pos - troop_data.start_pos).normalized().rotated(PI/2)
				troop_data.visual.global_position = base_pos + perpendicular * wobble
				
				# Scale based on progress for dynamic feel
				var scale_factor = 1.0 + sin(progress * PI) * 0.3
				troop_data.visual.scale = Vector2(scale_factor, scale_factor)

# Helper methods
func set_troops(amount: int) -> void:
	troops = amount
	update_visuals()

func set_ai_aggression(aggression_level: float) -> void:
	if castle_owner == "Enemy":
		attack_cooldown = 5.0 / aggression_level  # Updated base value
		attack_percentage = clamp(0.4 * aggression_level, 0.2, 0.8)
		min_troops_to_attack = max(2, int(8.0 / aggression_level))

func _exit_tree() -> void:
	if is_instance_valid(troop_group):
		troop_group.queue_free()
