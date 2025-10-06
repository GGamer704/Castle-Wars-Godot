# castle.gd
extends StaticBody2D

@export var max_troops: int = 10
@export var regen_rate: float = 1.0
@export var player_scene: PackedScene

var troops: int = 10
var timer: float = 0.0
var castle_owner: String = "Neutral"  # Neutral by default

@onready var label: Label = $Label

func _ready() -> void:
	add_to_group("Castles")
	update_label()

func _process(delta: float) -> void:
	timer += delta
	if castle_owner != "Neutral" and timer >= 1.0 / regen_rate and troops < max_troops:
		troops += 1
		timer = 0.0
		update_label()

func send_troops(target: Node, amount: int) -> void:
	if amount > 0 and amount <= troops:
		troops -= amount
		update_label()
		target.receive_troops(amount, castle_owner)

func receive_troops(amount: int, sender_owner: String) -> void:
	if sender_owner == castle_owner:
		# Friendly reinforcement
		troops += amount
	else:
		# Battle: defending troops fight attacking troops
		troops -= amount
		if troops <= 0:
			# Castle captured by attacker
			castle_owner = sender_owner
			troops = abs(troops)  # Leftover attackers become garrison
			if castle_owner == "Player":
				update_castle_scene()  # Swap to player castle
	
	update_label()

func update_label() -> void:
	if label:
		label.text = str(troops)
		if castle_owner == "Neutral":
			label.modulate = Color.WHITE
		elif castle_owner == "Player":
			label.modulate = Color.BLUE  # Fixed: was green color but using blue values
		else:
			label.modulate = Color.RED  # Red for enemy

func update_castle_scene() -> void:
	if castle_owner == "Player" and player_scene:
		var parent = get_parent()
		var new_castle = player_scene.instantiate()
		new_castle.position = position
		new_castle.rotation = rotation
		new_castle.scale = scale
		
		# Transfer state to new castle
		if new_castle.has_method("set_troops"):
			new_castle.set_troops(troops)
		elif "troops" in new_castle:
			new_castle.troops = troops
			
		if "castle_owner" in new_castle:
			new_castle.castle_owner = castle_owner
			
		# Add the new castle and remove this one
		parent.add_child(new_castle)
		
		# Call update_label on new castle if it has the method
		if new_castle.has_method("update_label"):
			new_castle.update_label()
			
		queue_free()  # Remove the old neutral castle
