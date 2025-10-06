extends StaticBody2D

@export var max_troops: int = 25
@export var regen_rate: float = 1.0
var troops: int = 10
var timer := 0.0
var castle_owner: String = "Player"

@onready var label: Label = $Label

func _ready() -> void:
	add_to_group("Castles")  # Add this line to ensure it's in the group
	label.text = str(troops)

func _process(delta: float) -> void:
	timer += delta
	if timer >= 1.0 / regen_rate and troops < max_troops:
		troops += 1
		timer = 0.0
	
	if label:
		label.text = str(troops)

func send_troops(target: Node, amount: int) -> void:
	if amount > 0 and amount <= troops:
		troops -= amount
		if label:
			label.text = str(troops)
		target.receive_troops(amount, castle_owner)

func receive_troops(amount: int, sender_owner: String) -> void:
	if sender_owner == castle_owner:
		# Friendly reinforcement
		troops += amount
	else:
		# Battle! Defending troops fight attacking troops
		troops -= amount
		if troops <= 0:
			# Castle captured - attacker takes control
			castle_owner = sender_owner
			troops = abs(troops)  # Remaining attacking troops become garrison
	
	if label:
		label.text = str(troops)
