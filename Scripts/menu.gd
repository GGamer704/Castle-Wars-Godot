extends Control


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/selectLeve.tscn")


func _on_option_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/SettingsPanels.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_menu_button_about_to_popup() -> void:
	var menu = $MenuButton.get_popup()
	menu.clear()
	
	# Add menu items with shorter labels
	menu.add_item("📖 How to Play")
	menu.add_item("⚔️ Controls")
	menu.add_item("📊 Game Rules")
	menu.add_separator()
	menu.add_item("❌ Close Menu")
	
	# Connect to handle menu item selection
	if not menu.id_pressed.is_connected(_on_menu_item_selected):
		menu.id_pressed.connect(_on_menu_item_selected)

func _on_menu_item_selected(id: int) -> void:
	match id:
		0: show_tutorial_popup()
		1: show_controls_popup()
		2: show_rules_popup()
		4: pass # Close does nothing, menu auto-closes

func show_tutorial_popup() -> void:
	var popup = AcceptDialog.new()
	popup.title = "How to Play"
	popup.dialog_text = """GOAL: Capture all enemy (red) and neutral (white) castles!

🎯 QUICK START:
1. Click & hold your blue castle
2. Drag to target castle
3. Release to attack with half your troops

💡 TIP: Keep troops in your castles to regenerate more!"""
	
	popup.ok_button_text = "Got it!"
	add_child(popup)
	popup.popup_centered(Vector2i(400, 300))
	popup.confirmed.connect(func(): popup.queue_free())

func show_controls_popup() -> void:
	var popup = AcceptDialog.new()
	popup.title = "Controls"
	popup.dialog_text = """⚔️ ATTACK:
• Click and hold on your blue castle
• Drag to a target castle
• Release to send half your troops

⌨️ KEYBOARD SHORTCUTS:
• SPACE - Pause/Resume game
• S - Cycle speed (1x → 2x → 4x)

🎮 RANGE INDICATOR:
• Blue circle shows attack range
• Only visible when castle is selected"""
	
	popup.ok_button_text = "Got it!"
	add_child(popup)
	popup.popup_centered(Vector2i(450, 350))
	popup.confirmed.connect(func(): popup.queue_free())

func show_rules_popup() -> void:
	var popup = AcceptDialog.new()
	popup.title = "Game Rules"
	popup.dialog_text = """📏 RANGE LIMIT:
You can only attack castles within range (blue circle)

♻️ REGENERATION:
Your castles generate troops automatically (max 25)

⚔️ COMBAT:
When troops arrive, they fight. Higher numbers win!
Winner keeps remaining troops.

🛡️ REINFORCEMENT:
Send troops to your own castle to reinforce it

🏆 WIN: Capture all castles
💀 LOSE: Lose all your castles"""
	
	popup.ok_button_text = "Got it!"
	add_child(popup)
	popup.popup_centered(Vector2i(450, 400))
	popup.confirmed.connect(func(): popup.queue_free())
