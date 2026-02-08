extends CanvasLayer
## HUD - Stylized PSX-aesthetic heads up display

@onready var health_bar: ProgressBar = $HealthStaminaContainer/VBoxContainer/HealthContainer/HealthBarBG/HealthBar
@onready var stamina_bar: ProgressBar = $HealthStaminaContainer/VBoxContainer/StaminaContainer/StaminaBarBG/StaminaBar
@onready var item_slot: Control = $ItemSlot
@onready var item_label: Label = $ItemSlot/Panel/VBoxContainer/ItemLabel
@onready var kill_feed: VBoxContainer = $KillFeed
@onready var scoreboard: Control = $Scoreboard
@onready var scoreboard_list: VBoxContainer = $Scoreboard/Panel/VBoxContainer/ScoreList
@onready var speed_boost_indicator: PanelContainer = $EffectsContainer/SpeedBoost
@onready var damage_boost_indicator: PanelContainer = $EffectsContainer/DamageBoost
@onready var shield_indicator: PanelContainer = $EffectsContainer/Shield
@onready var dual_swords_indicator: PanelContainer = $EffectsContainer/DualSwords
@onready var pause_menu: Control = $PauseMenu

var local_player: Node = null
var is_paused: bool = false
var kill_feed_entries: Array = []
const MAX_KILL_FEED_ENTRIES = 5
const KILL_FEED_DURATION = 5.0

# PSX color constants
const COLOR_RED := Color(0.85, 0.25, 0.35, 1.0)
const COLOR_GOLD := Color(0.75, 0.55, 0.2, 1.0)
const COLOR_CYAN := Color(0.2, 0.8, 0.9, 1.0)
const COLOR_TEXT := Color(0.95, 0.92, 0.88, 1.0)

func _ready() -> void:
	scoreboard.visible = false
	_apply_psx_theme()

	# Connect to game state signals
	GameState.player_killed.connect(_on_player_killed)
	GameState.score_updated.connect(_on_score_updated)

func _apply_psx_theme() -> void:
	# Health bar fill color
	var health_fill := PSXTheme.create_health_bar_style()
	health_bar.add_theme_stylebox_override("fill", health_fill)

	# Stamina bar fill color
	var stamina_fill := PSXTheme.create_stamina_bar_style()
	stamina_bar.add_theme_stylebox_override("fill", stamina_fill)

func _process(_delta: float) -> void:
	# Toggle scoreboard
	if Input.is_action_pressed("scoreboard"):
		scoreboard.visible = true
		_update_scoreboard()
	else:
		scoreboard.visible = false

	# Update item display, health, and effects continuously
	if local_player:
		_update_item()
		_update_health()
		_update_effects()

func set_local_player(player: Node) -> void:
	local_player = player

	if local_player:
		# Connect to player signals
		if local_player.has_signal("damage_taken"):
			local_player.damage_taken.connect(_on_player_damage_taken)

		# Connect to stamina
		if local_player.stamina:
			local_player.stamina.stamina_changed.connect(_on_stamina_changed)

		# Initial update
		_update_health()
		_update_stamina()
		_update_item()
		_update_effects()

func _update_health() -> void:
	if local_player:
		health_bar.max_value = local_player.max_health
		health_bar.value = local_player.health

		# Also show shield if any
		if local_player.shield_health > 0:
			health_bar.value = local_player.health + local_player.shield_health
			# Change bar color to indicate shield
			var shield_fill := PSXTheme.create_shield_bar_style()
			health_bar.add_theme_stylebox_override("fill", shield_fill)
		else:
			var health_fill := PSXTheme.create_health_bar_style()
			health_bar.add_theme_stylebox_override("fill", health_fill)

func _update_stamina() -> void:
	if local_player and local_player.stamina:
		stamina_bar.max_value = local_player.stamina.max_stamina
		stamina_bar.value = local_player.stamina.current_stamina

func _update_item() -> void:
	if local_player:
		if local_player.current_item != "":
			item_slot.visible = true
			var item_text = local_player.current_item.to_upper()
			if local_player.item_uses > 1:
				item_text += " x" + str(local_player.item_uses)
			item_label.text = item_text
		else:
			item_slot.visible = false

func _on_player_damage_taken(_amount: int, _attacker_id: int) -> void:
	_update_health()

func _on_stamina_changed(_current: float, _maximum: float) -> void:
	_update_stamina()

func _on_player_killed(killer_id: int, victim_id: int) -> void:
	var killer_name = GameState.player_names.get(killer_id, "Player " + str(killer_id))
	var victim_name = GameState.player_names.get(victim_id, "Player " + str(victim_id))

	_add_kill_feed_entry(killer_name + " killed " + victim_name)

func _add_kill_feed_entry(text: String) -> void:
	var entry = Label.new()
	entry.text = text
	entry.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	entry.add_theme_font_size_override("font_size", 11)
	entry.add_theme_color_override("font_color", COLOR_TEXT)
	kill_feed.add_child(entry)
	kill_feed_entries.append(entry)

	# Remove old entries
	while kill_feed_entries.size() > MAX_KILL_FEED_ENTRIES:
		var old_entry = kill_feed_entries.pop_front()
		old_entry.queue_free()

	# Auto-remove after duration
	await get_tree().create_timer(KILL_FEED_DURATION).timeout
	if is_instance_valid(entry):
		kill_feed_entries.erase(entry)
		entry.queue_free()

func _on_score_updated(_peer_id: int, _score: int) -> void:
	if scoreboard.visible:
		_update_scoreboard()

func _update_scoreboard() -> void:
	# Clear existing entries
	for child in scoreboard_list.get_children():
		child.queue_free()

	# Add players sorted by score
	var leaderboard = GameState.get_leaderboard()
	for entry in leaderboard:
		var row = HBoxContainer.new()

		# Player name
		var name_label = Label.new()
		name_label.text = entry.name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.add_theme_color_override("font_color", COLOR_TEXT)
		row.add_child(name_label)

		# Kills
		var kills_label = Label.new()
		kills_label.text = str(entry.score)
		kills_label.custom_minimum_size = Vector2(60, 0)
		kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		kills_label.add_theme_font_size_override("font_size", 12)
		kills_label.add_theme_color_override("font_color", COLOR_RED)
		row.add_child(kills_label)

		# Team if applicable
		if GameState.game_mode == GameState.GameMode.TEAM_BATTLE:
			var team_label = Label.new()
			team_label.text = "RED" if entry.team == GameState.Team.RED else ("BLUE" if entry.team == GameState.Team.BLUE else "-")
			team_label.custom_minimum_size = Vector2(50, 0)
			team_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			team_label.add_theme_font_size_override("font_size", 12)
			if entry.team == GameState.Team.RED:
				team_label.add_theme_color_override("font_color", COLOR_RED)
			else:
				team_label.add_theme_color_override("font_color", COLOR_CYAN)
			row.add_child(team_label)

		scoreboard_list.add_child(row)

func _update_effects() -> void:
	if not local_player:
		return

	# Speed boost (active when timer > 0)
	speed_boost_indicator.visible = local_player.speed_boost_timer > 0
	if speed_boost_indicator.visible:
		var label = speed_boost_indicator.get_node("Label")
		label.text = "SPEED %.0f" % local_player.speed_boost_timer

	# Damage boost (active when timer > 0, separate from dual swords)
	damage_boost_indicator.visible = local_player.damage_boost_timer > 0
	if damage_boost_indicator.visible:
		var label = damage_boost_indicator.get_node("Label")
		label.text = "DMG %.0f" % local_player.damage_boost_timer

	# Shield (active when shield_health > 0)
	shield_indicator.visible = local_player.shield_health > 0
	if shield_indicator.visible:
		var label = shield_indicator.get_node("Label")
		label.text = "SHIELD %.0f" % local_player.shield_health

	# Dual swords (active when timer > 0)
	dual_swords_indicator.visible = local_player.dual_swords_timer > 0
	if dual_swords_indicator.visible:
		var label = dual_swords_indicator.get_node("Label")
		label.text = "DUAL %.0f" % local_player.dual_swords_timer

func toggle_pause() -> void:
	is_paused = not is_paused
	pause_menu.visible = is_paused

	if is_paused:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_resume_pressed() -> void:
	toggle_pause()

func _on_quit_pressed() -> void:
	is_paused = false
	pause_menu.visible = false
	NetworkManager.disconnect_game()
	GameState.set_match_phase(GameState.MatchPhase.MENU)
	GameState.reset_match()
	get_tree().change_scene_to_file("res://src/ui/main_menu/main_menu.tscn")
