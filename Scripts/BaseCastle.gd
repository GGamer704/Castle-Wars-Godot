# BaseCastle.gd
extends StaticBody2D

@export var max_troops: int = 25
@export var regen_rate: float = 0.5
@export var initial_troops: int = 10
@export var attack_range: float = 200.0
@export var attack_cooldown: float = 5.0
@export var min_troops_to_attack: int = 5
@export var attack_percentage: float = 0.3
@export var troop_speed: float = 200.0

@export_enum("Player", "Enemy", "Neutral") var castle_owner: String = "Neutral"

var troops: int = 10
var timer := 0.0
var attack_timer := 0.0
var current_target: Node = null
var is_attacking: bool = false
var glow_time := 0.0

var showing_arrow: bool = false
var arrow_target_pos: Vector2
var dot_animation_time: float = 0.0
var arrow_timer: Timer = null
var arrow_fade_alpha: float = 1.0

var audio_player: AudioStreamPlayer = null
var capture_sound := preload("res://Audio/armor-impact-from-sword-393843.mp3")

@onready var label: Label = $Label
@onready var sprite: Sprite2D = $Sprite2D

var troop_group: Node2D = null

# New attack system - store attacks in flight
var incoming_attacks: Array = []  # Stores {troops: int, owner: String, arrival_time: float}
var attack_visuals: Array = []    # Stores visual representation data

var TroopDotScene := preload("res://Scenes/TroopDot.tscn")
var active_tweens: Array = []

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
	if get_parent():
		troop_group = Node2D.new()
		troop_group.name = "MovingTroops_" + name
		get_parent().call_deferred("add_child", troop_group)

func _process(delta: float) -> void:
	# Troop regeneration
	timer += delta
	if castle_owner != "Neutral" and timer >= 1.0 / regen_rate and troops < max_troops:
		troops += 1
		timer = 0.0
		update_visuals()

	# Enemy AI
	if castle_owner == "Enemy":
		attack_timer += delta
		if attack_timer >= attack_cooldown and not is_attacking:
			consider_attack()
			attack_timer = 0.0

	# Process incoming attacks
	process_incoming_attacks(delta)
	
	# Update visuals
	update_attack_visuals(delta)
	
	glow_time += delta
	update_castle_glow()
	
	if showing_arrow:
		dot_animation_time += delta * 3.0
		queue_redraw()

func _draw() -> void:
	if showing_arrow and current_target and is_instance_valid(current_target):
		draw_simplified_attack_arrow()
	
	if castle_owner == "Player" and is_selected():
		draw_attack_range()

func draw_attack_range() -> void:
	var range_color = Color(0.3, 0.7, 1.0, 0.2)
	var range_outline = Color(0.3, 0.7, 1.0, 0.4)
	
	draw_circle(Vector2.ZERO, attack_range, range_color)
	
	var segments = 64
	for i in segments:
		var angle1 = (i * TAU) / segments
		var angle2 = ((i + 1) * TAU) / segments
		var point1 = Vector2.from_angle(angle1) * attack_range
		var point2 = Vector2.from_angle(angle2) * attack_range
		
		if i % 2 == 0:
			draw_line(point1, point2, range_outline, 2.0)

func is_selected() -> bool:
	var main_scene = get_tree().current_scene
	if main_scene and is_instance_valid(main_scene) and "selected_castle" in main_scene:
		return main_scene.selected_castle == self
	return false

func draw_simplified_attack_arrow() -> void:
	if not current_target or not is_instance_valid(current_target):
		return
		
	var start_pos = Vector2.ZERO
	var end_pos = to_local(current_target.global_position)
	var line_vector = end_pos - start_pos
	var line_length = line_vector.length()
	
	if line_length > 10:
		var direction = line_vector.normalized()
		var base_color = get_owner_color()
		
		var line_width = 2.5
		
		var pulse = sin(dot_animation_time * 1.5) * 0.2 + 0.8
		var arrow_color = Color(
			base_color.r * pulse,
			base_color.g * pulse,
			base_color.b * pulse,
			arrow_fade_alpha * 0.8
		)
		
		draw_line(start_pos, end_pos, Color(arrow_color.r, arrow_color.g, arrow_color.b, 0.3 * arrow_fade_alpha), line_width + 2.0)
		draw_line(start_pos, end_pos, arrow_color, line_width)
		
		var num_particles = max(2, int(line_length / 60.0))
		for i in range(num_particles):
			var progress = fposmod(float(i) / num_particles + dot_animation_time * 0.4, 1.0)
			var particle_pos = start_pos + line_vector * progress
			var particle_size = 3.0 + sin(dot_animation_time * 2.0 + i) * 1.0
			var particle_alpha = 0.6 * arrow_fade_alpha
			
			draw_circle(particle_pos, particle_size + 1.0, Color(arrow_color.r, arrow_color.g, arrow_color.b, particle_alpha * 0.4))
			draw_circle(particle_pos, particle_size, Color(arrow_color.r + 0.2, arrow_color.g + 0.2, arrow_color.b + 0.2, particle_alpha))
		
		var arrow_length = 15.0
		var arrow_width = 0.4
		var arrow_point1 = end_pos - direction.rotated(arrow_width) * arrow_length
		var arrow_point2 = end_pos - direction.rotated(-arrow_width) * arrow_length
		
		var arrow_points = PackedVector2Array([end_pos, arrow_point1, arrow_point2])
		draw_colored_polygon(arrow_points, Color(arrow_color.r, arrow_color.g, arrow_color.b, 0.3 * arrow_fade_alpha))
		draw_colored_polygon(arrow_points, arrow_color)
		
		draw_line(end_pos, arrow_point1, arrow_color, 1.5)
		draw_line(end_pos, arrow_point2, arrow_color, 1.5)

func can_attack_target(target_castle: Node2D) -> bool:
	if not target_castle or not is_instance_valid(target_castle) or target_castle == self:
		return false
	
	var distance = global_position.distance_to(target_castle.global_position)
	return distance <= attack_range

func initiate_player_attack(target_castle: Node2D) -> bool:
	if castle_owner != "Player":
		return false
	
	if not target_castle or not is_instance_valid(target_castle):
		return false
	
	if troops <= 1:
		print("Not enough troops to attack!")
		return false
	
	if not can_attack_target(target_castle):
		print("Target castle is out of attack range!")
		return false
	
	# Calculate troops to send (half of current)
	var troops_to_send: int = max(1, troops / 2)
	
	# Immediately remove troops from this castle
	troops -= troops_to_send
	update_visuals()
	
	print("[ATTACK LAUNCHED] %s sending %d troops to %s (Remaining: %d)" % [name, troops_to_send, target_castle.name, troops])
	
	# Launch the attack
	launch_attack(target_castle, troops_to_send)
	
	return true

func launch_attack(target_castle: Node2D, troop_count: int) -> void:
	if not target_castle or not is_instance_valid(target_castle):
		return
	
	# Calculate travel time
	var distance = global_position.distance_to(target_castle.global_position)
	var travel_time = distance / troop_speed
	
	# Register attack with target castle
	if target_castle.has_method("register_incoming_attack"):
		target_castle.register_incoming_attack(troop_count, castle_owner, travel_time)
	
	# Create visuals
	create_attack_visuals(target_castle, troop_count, travel_time)
	
	# Show arrow
	current_target = target_castle
	show_attack_arrow(target_castle)

func register_incoming_attack(troop_count: int, attacker_owner: String, travel_time: float) -> void:
	var attack_data = {
		"troops": troop_count,
		"owner": attacker_owner,
		"time_remaining": travel_time
	}
	incoming_attacks.append(attack_data)
	print("[ATTACK REGISTERED] %s will receive %d troops from %s in %.2f seconds" % [name, troop_count, attacker_owner, travel_time])

func process_incoming_attacks(delta: float) -> void:
	for i in range(incoming_attacks.size() - 1, -1, -1):
		var attack = incoming_attacks[i]
		attack.time_remaining -= delta
		
		if attack.time_remaining <= 0:
			# Attack has arrived - resolve combat
			resolve_combat(attack.troops, attack.owner)
			incoming_attacks.remove_at(i)

func resolve_combat(incoming_troops: int, attacker_owner: String) -> void:
	print("\n=== COMBAT RESOLUTION ===")
	print("Defender: %s (Owner: %s, Troops: %d)" % [name, castle_owner, troops])
	print("Attacker: %s (Troops: %d)" % [attacker_owner, incoming_troops])
	
	# Same owner = reinforcement
	if attacker_owner == castle_owner:
		troops = min(troops + incoming_troops, max_troops)
		print("RESULT: Reinforcement! New total: %d troops" % troops)
		update_visuals()
		return
	
	# Different owner = combat
	var defender_initial = troops
	var attacker_initial = incoming_troops
	
	# Calculate result: positive = attacker wins, negative = defender wins, zero = tie
	var result = incoming_troops - troops
	
	print("Combat calculation: %d (attacker) - %d (defender) = %d" % [attacker_initial, defender_initial, result])
	
	if result > 0:
		# Attacker wins - castle changes hands
		print("OUTCOME: Attacker WINS!")
		print("  Castle changes from %s to %s" % [castle_owner, attacker_owner])
		print("  Surviving troops: %d" % result)
		
		change_owner(attacker_owner)
		troops = result
		
		if audio_player and is_instance_valid(audio_player):
			audio_player.play()
	
	elif result < 0:
		# Defender wins - keeps castle with reduced troops
		print("OUTCOME: Defender WINS!")
		print("  Surviving troops: %d" % abs(result))
		
		troops = abs(result)
	
	else:
		# Exact tie - castle becomes neutral with 0 troops
		print("OUTCOME: DRAW!")
		print("  Castle becomes Neutral with 0 troops")
		
		change_owner("Neutral")
		troops = 0
	
	print("Final: %s owns %s with %d troops" % [castle_owner, name, troops])
	print("========================\n")
	
	update_visuals()

func create_attack_visuals(target_castle: Node2D, amount: int, travel_time: float) -> void:
	if not target_castle or not is_instance_valid(target_castle):
		return
	if not troop_group or not is_instance_valid(troop_group):
		return
	
	var start_pos = global_position
	var end_pos = target_castle.global_position
	
	var num_visuals = min(amount, 5)
	
	for i in range(num_visuals):
		var troop_visual = create_enhanced_troop_visual()
		if not troop_visual:
			continue
		
		troop_group.add_child(troop_visual)
		var spawn_offset = Vector2(randf_range(-25, 25), randf_range(-25, 25))
		troop_visual.global_position = start_pos + spawn_offset
		
		var visual_data = {
			"node": troop_visual,
			"start_pos": troop_visual.global_position,
			"end_pos": end_pos + Vector2(randf_range(-35, 35), randf_range(-35, 35)),
			"travel_time": travel_time + randf_range(-0.3, 0.3),
			"elapsed": 0.0
		}
		attack_visuals.append(visual_data)

func update_attack_visuals(delta: float) -> void:
	for i in range(attack_visuals.size() - 1, -1, -1):
		var visual = attack_visuals[i]
		visual.elapsed += delta
		
		var progress = visual.elapsed / visual.travel_time
		
		if progress >= 1.0:
			# Visual reached destination
			if visual.node and is_instance_valid(visual.node):
				visual.node.queue_free()
			attack_visuals.remove_at(i)
			
			# Check if all visuals are done
			if attack_visuals.is_empty():
				is_attacking = false
		else:
			# Animate the visual
			if visual.node and is_instance_valid(visual.node):
				var base_pos = visual.start_pos.lerp(visual.end_pos, progress)
				var wobble = sin(progress * PI * 3.0) * 15.0
				var perpendicular = (visual.end_pos - visual.start_pos).normalized().rotated(PI / 2)
				visual.node.global_position = base_pos + perpendicular * wobble
				
				var scale_factor = 1.0 + sin(progress * PI) * 0.3
				visual.node.scale = Vector2(scale_factor, scale_factor)

func spawn_enhanced_troop_dots(from_castle: Node2D, to_castle: Node2D, troop_count: int, color: Color) -> void:
	if not from_castle or not is_instance_valid(from_castle):
		return
	if not to_castle or not is_instance_valid(to_castle):
		return
	
	var max_dots = 35
	var dots = min(max_dots, troop_count)
	
	var from_pos = from_castle.global_position
	var to_pos = to_castle.global_position
	
	var main_scene = get_tree().current_scene
	if not main_scene or not is_instance_valid(main_scene):
		return
	
	for i in range(dots):
		var dot = TroopDotScene.instantiate()
		
		var spawn_offset = Vector2(randf_range(-20, 20), randf_range(-20, 20))
		dot.position = main_scene.to_local(from_pos + spawn_offset)
		
		var arrival_offset = Vector2(randf_range(-30, 30), randf_range(-30, 30))
		dot.target_pos = main_scene.to_local(to_pos + arrival_offset)
		
		var color_variation = Color(
			clamp(color.r + randf_range(-0.1, 0.1), 0.0, 1.0),
			clamp(color.g + randf_range(-0.1, 0.1), 0.0, 1.0),
			clamp(color.b + randf_range(-0.1, 0.1), 0.0, 1.0),
			color.a
		)
		dot.color = color_variation
		dot.position.y += i * 2
		
		main_scene.add_child(dot)

func spawn_troop_dots(from_castle: Node2D, to_castle: Node2D, troop_count: int, color: Color) -> void:
	spawn_enhanced_troop_dots(from_castle, to_castle, troop_count, color)

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

func update_visuals() -> void:
	update_label()
	update_sprite_color()

func update_label() -> void:
	if label and is_instance_valid(label):
		label.text = str(troops)
		match castle_owner:
			"Player":
				label.modulate = Color.CYAN
			"Enemy":
				label.modulate = Color.RED
			"Neutral":
				label.modulate = Color.WHITE
			_:
				label.modulate = Color.WHITE

func update_sprite_color() -> void:
	if not sprite or not is_instance_valid(sprite):
		return
	
	match castle_owner:
		"Player":
			if ResourceLoader.exists("res://Sprites/player_castle.png"):
				sprite.texture = load("res://Sprites/player_castle.png")
			sprite.modulate = Color.WHITE
		"Enemy":
			if ResourceLoader.exists("res://Sprites/enemy_castle.png"):
				sprite.texture = load("res://Sprites/enemy_castle.png")
			sprite.modulate = Color.WHITE
		"Neutral":
			if ResourceLoader.exists("res://Sprites/ruin_castle.png"):
				sprite.texture = load("res://Sprites/ruin_castle.png")
			sprite.modulate = Color.WHITE
		_:
			if ResourceLoader.exists("res://Sprites/ruin_castle.png"):
				sprite.texture = load("res://Sprites/ruin_castle.png")
			sprite.modulate = Color.WHITE

func update_castle_glow() -> void:
	if is_attacking and has_node("Glow"):
		var glow_node = get_node("Glow")
		if is_instance_valid(glow_node):
			var base_color = get_owner_color()
			var bright_color = Color(
				min(base_color.r + 0.5, 1.0),
				min(base_color.g + 0.3, 1.0),
				base_color.b,
				1.0
			)
			glow_node.modulate = base_color.lerp(bright_color, abs(sin(glow_time * 5.0)))

func change_owner(new_owner: String) -> void:
	castle_owner = new_owner
	update_visuals()
	
	if castle_owner == "Enemy":
		attack_timer = randf() * attack_cooldown

func get_troop_count() -> int:
	return troops

func consider_attack() -> void:
	if castle_owner != "Enemy" or troops <= min_troops_to_attack:
		return
	
	var best_target = find_best_target()
	if best_target and is_instance_valid(best_target):
		var nearby_player_castles = get_nearby_player_castles()
		var attack_multiplier = 1.0 + 0.5 * nearby_player_castles.size()
		execute_visual_attack(best_target, attack_multiplier)

func get_nearby_player_castles() -> Array:
	var result = []
	var castles = get_tree().get_nodes_in_group("Castles")
	for c in castles:
		if is_instance_valid(c) and c.castle_owner == "Player":
			if global_position.distance_to(c.global_position) <= attack_range:
				result.append(c)
	return result

func find_best_target() -> Node:
	var castles = get_tree().get_nodes_in_group("Castles")
	var best_target: Node = null
	var best_score: float = -1.0
	
	for castle in castles:
		if not is_instance_valid(castle):
			continue
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
	if not target or not is_instance_valid(target):
		return -1.0
	
	var score: float = 0.0
	
	score += (attack_range - distance) / attack_range * 100.0
	
	var enemy_troops = 0
	if "troops" in target:
		enemy_troops = target.troops
	elif target.has_method("get_troop_count"):
		enemy_troops = target.get_troop_count()
	
	var troops_advantage = max(0, troops - enemy_troops - min_troops_to_attack)
	score += troops_advantage * 10.0
	
	if "castle_owner" in target:
		if target.castle_owner == "Player":
			score += 50.0
		elif target.castle_owner == "Neutral":
			score += 20.0
	
	var attack_force = int(float(troops - min_troops_to_attack) * attack_percentage)
	if attack_force > enemy_troops:
		score += 100.0
	
	return score

func execute_visual_attack(target: Node, multiplier: float = 1.0) -> void:
	if not target or not is_instance_valid(target):
		return
	
	var available_troops = troops - min_troops_to_attack
	var attack_force = int(float(available_troops) * attack_percentage * multiplier)
	attack_force = max(1, min(attack_force, available_troops))
	
	if attack_force > 0:
		is_attacking = true
		
		# Remove troops immediately
		troops -= attack_force
		update_visuals()
		
		print("[ENEMY ATTACK] %s sending %d troops (Remaining: %d)" % [name, attack_force, troops])
		
		# Launch the attack
		launch_attack(target, attack_force)

func show_attack_arrow(target: Node) -> void:
	if not target or not is_instance_valid(target):
		return
	
	showing_arrow = true
	current_target = target
	dot_animation_time = 0.0
	arrow_fade_alpha = 1.0
	queue_redraw()
	
	if arrow_timer and is_instance_valid(arrow_timer):
		arrow_timer.stop()
		arrow_timer.queue_free()
	
	arrow_timer = Timer.new()
	add_child(arrow_timer)
	arrow_timer.wait_time = 1.2
	arrow_timer.one_shot = true
	arrow_timer.timeout.connect(_on_arrow_fade_start)
	arrow_timer.start()

func _on_arrow_fade_start() -> void:
	var fade_tween = create_tween()
	active_tweens.append(fade_tween)
	fade_tween.tween_property(self, "arrow_fade_alpha", 0.0, 0.3)
	fade_tween.tween_callback(_on_arrow_timeout)
	fade_tween.finished.connect(func():
		if active_tweens.has(fade_tween):
			active_tweens.erase(fade_tween)
	)

func _on_arrow_timeout() -> void:
	showing_arrow = false
	current_target = null
	arrow_fade_alpha = 1.0
	queue_redraw()
	
	if arrow_timer and is_instance_valid(arrow_timer):
		arrow_timer.queue_free()
		arrow_timer = null

func create_enhanced_troop_visual() -> Node2D:
	var troop = Node2D.new()
	var base_color = get_owner_color()
	
	var circle = ColorRect.new()
	circle.size = Vector2(10, 10)
	circle.position = Vector2(-5, -5)
	circle.color = base_color
	troop.add_child(circle)
	
	var core = ColorRect.new()
	core.size = Vector2(5, 5)
	core.position = Vector2(-2.5, -2.5)
	core.color = Color(1.0, 1.0, 1.0, 0.8)
	troop.add_child(core)
	
	var tween = troop.create_tween()
	tween.set_loops()
	tween.tween_property(circle, "scale", Vector2(1.4, 1.4), 0.4)
	tween.tween_property(circle, "scale", Vector2.ONE, 0.4)
	
	var rotation_tween = troop.create_tween()
	rotation_tween.set_loops()
	rotation_tween.tween_property(troop, "rotation", TAU, 2.0)
	
	return troop

func set_troops(amount: int) -> void:
	troops = clamp(amount, 0, max_troops)
	update_visuals()

func set_ai_aggression(aggression_level: float) -> void:
	if castle_owner == "Enemy":
		attack_cooldown = 5.0 / max(0.1, aggression_level)
		attack_percentage = clamp(0.4 * aggression_level, 0.2, 0.8)
		min_troops_to_attack = max(2, int(8.0 / max(0.1, aggression_level)))

func _exit_tree() -> void:
	for tween in active_tweens:
		if is_instance_valid(tween):
			tween.kill()
	active_tweens.clear()
	
	if arrow_timer and is_instance_valid(arrow_timer):
		arrow_timer.stop()
		arrow_timer.queue_free()
		arrow_timer = null
	
	if troop_group and is_instance_valid(troop_group):
		troop_group.queue_free()
		troop_group = null
	
	if audio_player and is_instance_valid(audio_player):
		audio_player.stop()
