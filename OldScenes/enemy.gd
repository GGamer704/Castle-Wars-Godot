extends StaticBody2D

@export var max_troops: int = 25
@export var regen_rate: float = 0.7
@export var player_scene: PackedScene  # Scene to swap to when captured by player
@export var attack_range: float = 500.0
@export var attack_cooldown: float = 3.0
@export var min_troops_to_attack: int = 5
@export var attack_percentage: float = 0.6
@export var troop_speed: float = 200.0

var troops: int = 10
var timer := 0.0
var attack_timer := 0.0
var castle_owner: String = "Enemy"
var current_target: Node = null
var is_attacking: bool = false
var glow_time := 0.0  # Timer for glow animation

# New variables for enhanced attack arrow
var showing_arrow: bool = false
var arrow_target_pos: Vector2
var dot_animation_time: float = 0.0
var arrow_pulse_time: float = 0.0
var arrow_timer: Timer

@onready var label: Label = $Label

# Visual components
var troop_group: Node2D
var moving_troops: Array = []

func _ready() -> void:
	add_to_group("Castles")
	update_label()
	attack_timer = randf() * attack_cooldown
	setup_visual_components()

func setup_visual_components() -> void:
	# Container for moving troops
	troop_group = Node2D.new()
	troop_group.name = "MovingTroops"
	get_parent().add_child(troop_group)

func _process(delta: float) -> void:
	timer += delta
	if castle_owner != "Neutral" and timer >= 1.0 / regen_rate and troops < max_troops:
		troops += 1
		timer = 0.0
		update_label()

	if castle_owner == "Enemy":
		attack_timer += delta
		if attack_timer >= attack_cooldown and not is_attacking:
			consider_attack()
			attack_timer = 0.0

	update_moving_troops(delta)

	# Glow animation
	glow_time += delta
	update_castle_glow()
	
	# Update arrow animation
	if showing_arrow:
		dot_animation_time += delta * 3.0
		arrow_pulse_time += delta * 2.0
		queue_redraw()

func _draw() -> void:
	if showing_arrow and current_target:
		var start_pos = Vector2.ZERO
		var end_pos = to_local(current_target.global_position)
		
		var line_vector = end_pos - start_pos
		var line_length = line_vector.length()
		
		if line_length > 10:
			var direction = line_vector.normalized()
			
			# Main line
			var line_color = Color(0.8, 0.0, 0.0, 0.8)  # Red color for enemy
			draw_line(start_pos, end_pos, line_color, 4.0)
			
			# Moving dots along the line
			var num_dots = int(line_length / 30.0) + 2
			for i in range(num_dots):
				var dot_progress = fposmod(float(i) / num_dots + dot_animation_time * 0.5, 1.0)
				var dot_pos = start_pos + line_vector * dot_progress
				var dot_alpha = sin(dot_progress * PI) * 0.8 + 0.2
				var dot_color = Color(1.0, 0.2, 0.2, dot_alpha)  # Red dots
				var dot_size = 6.0 + sin(dot_animation_time + i) * 2.0
				draw_circle(dot_pos, dot_size, dot_color)
			
			# Arrowhead with pulse
			var arrow_length = 25.0 + sin(arrow_pulse_time) * 5.0
			var arrow_angle = 0.4
			var arrow_point1 = end_pos - direction.rotated(arrow_angle) * arrow_length
			var arrow_point2 = end_pos - direction.rotated(-arrow_angle) * arrow_length
			var arrow_color = Color(0.8, 0.0, 0.0, 0.9)  # Red arrow
			var arrow_points = PackedVector2Array([end_pos, arrow_point1, arrow_point2])
			draw_colored_polygon(arrow_points, arrow_color)
			
			# Arrow outline
			var outline_color = Color(1.0, 0.5, 0.5, 1.0)  # Light red outline
			draw_line(end_pos, arrow_point1, outline_color, 2.0)
			draw_line(end_pos, arrow_point2, outline_color, 2.0)
			draw_line(arrow_point1, arrow_point2, outline_color, 2.0)
			
			# Glowing effect
			for i in range(3):
				var glow_size = 4.0 + i * 3.0
				var glow_alpha = 0.3 - i * 0.1
				var glow_color = Color(0.8, 0.0, 0.0, glow_alpha)  # Red glow
				draw_circle(end_pos, glow_size, glow_color)

# Glow effect
func update_castle_glow() -> void:
	if is_attacking and $Glow:
		$Glow.modulate = Color(1,0,0).lerp(Color(1,0.5,0), sin(glow_time * 5.0))

# AI logic
func consider_attack() -> void:
	if troops <= min_troops_to_attack:
		return

	var nearby_player_castles = get_tree().get_nodes_in_group("Castles").filter(func(c):
		return c.castle_owner == "Player" and global_position.distance_to(c.global_position) <= attack_range
	)
	var attack_multiplier = 1.0 + 0.5 * nearby_player_castles.size()
	var best_target = find_best_target()
	if best_target:
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
			score += 50.0
		elif target.castle_owner == "Neutral":
			score += 20.0

	var attack_force = int(float(troops - min_troops_to_attack) * attack_percentage)
	if attack_force > enemy_troops:
		score += 100.0
	return score

func execute_visual_attack(target: Node, multiplier: float = 1.0) -> void:
	var available_troops = troops - min_troops_to_attack
	var attack_force = int(float(available_troops) * attack_percentage * multiplier)
	attack_force = max(1, min(attack_force, available_troops))

	if attack_force > 0:
		current_target = target
		is_attacking = true
		troops -= attack_force
		update_label()
		show_attack_arrow(target)
		create_moving_troops(target, attack_force)
		print("Enemy castle attacking with ", attack_force, " troops!")

# Enhanced attack arrow visual
func show_attack_arrow(target: Node) -> void:
	if target:
		showing_arrow = true
		current_target = target
		dot_animation_time = 0.0
		arrow_pulse_time = 0.0
		queue_redraw()
		
		# Create timer for hiding arrow
		arrow_timer = Timer.new()
		add_child(arrow_timer)
		arrow_timer.wait_time = 1.0
		arrow_timer.one_shot = true
		arrow_timer.timeout.connect(_on_arrow_timeout)
		arrow_timer.start()

func _on_arrow_timeout() -> void:
	showing_arrow = false
	current_target = null
	queue_redraw()
	if arrow_timer:
		arrow_timer.queue_free()
		arrow_timer = null

# Moving troops visuals
func create_moving_troops(target: Node, amount: int) -> void:
	var start_pos = global_position
	var end_pos = target.global_position
	var distance = start_pos.distance_to(end_pos)
	var travel_time = distance / troop_speed

	for i in range(min(amount, 10)):
		var troop_visual = create_troop_visual()
		troop_group.add_child(troop_visual)
		troop_visual.global_position = start_pos + Vector2(randf_range(-20,20), randf_range(-20,20))
		var troop_data = {
			"visual": troop_visual,
			"start_pos": troop_visual.global_position,
			"end_pos": end_pos + Vector2(randf_range(-30,30), randf_range(-30,30)),
			"travel_time": travel_time + randf_range(-0.2,0.2),
			"elapsed_time": 0.0,
			"target": target,
			"amount": amount if i == 0 else 0
		}
		moving_troops.append(troop_data)

# Pulsing troop visuals (Fixed for Godot 4)
func create_troop_visual() -> Node2D:
	var troop = Node2D.new()
	var circle = ColorRect.new()
	circle.size = Vector2(10,10)
	circle.position = Vector2(-5,-5)
	circle.color = Color(150/255.0, 0, 0) # dark red
	troop.add_child(circle)
	
	# Pulse animation (Fixed for Godot 4)
	# Call create_tween() on the main castle node (self) since it's in the scene tree
	var tween = self.create_tween()
	tween.set_loops() # Makes it loop indefinitely
	tween.tween_property(circle, "scale", Vector2(1.3, 1.3), 0.5)
	tween.tween_property(circle, "scale", Vector2.ONE, 0.5)
	
	return troop

# Update troop movement
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
				troop_data.visual.global_position = troop_data.start_pos.lerp(troop_data.end_pos, progress)

# Sending and receiving troops
func send_troops(target: Node, amount: int) -> void:
	if amount > 0 and amount <= troops:
		troops -= amount
		update_label()
		target.receive_troops(amount, castle_owner)

func receive_troops(amount: int, sender_owner: String) -> void:
	if sender_owner == castle_owner:
		troops += amount
	else:
		troops -= amount
		if troops <= 0:
			castle_owner = sender_owner
			troops = abs(troops)
			if castle_owner == "Player":
				update_castle_scene()
	update_label()

# Label update
func update_label() -> void:
	if label:
		label.text = str(troops)
		if castle_owner == "Neutral":
			label.modulate = Color.WHITE
		elif castle_owner == "Player":
			label.modulate = Color.BLUE
		else:
			label.modulate = Color.RED

# Transform to player castle
func update_castle_scene() -> void:
	if castle_owner == "Player" and player_scene:
		var parent = get_parent()
		var new_castle = player_scene.instantiate()
		new_castle.position = position
		new_castle.rotation = rotation
		new_castle.scale = scale
		if new_castle.has_method("set_troops"):
			new_castle.set_troops(troops)
		elif "troops" in new_castle:
			new_castle.troops = troops
		if "castle_owner" in new_castle:
			new_castle.castle_owner = castle_owner
		parent.add_child(new_castle)
		if new_castle.has_method("update_label"):
			new_castle.update_label()
		queue_free()

func _exit_tree() -> void:
	if is_instance_valid(troop_group):
		troop_group.queue_free()

# AI difficulty adjustment
func set_ai_aggression(aggression_level: float) -> void:
	attack_cooldown = 5.0 / aggression_level
	attack_percentage = clamp(0.4 * aggression_level, 0.2, 0.8)
	min_troops_to_attack = max(2, int(8.0 / aggression_level))
