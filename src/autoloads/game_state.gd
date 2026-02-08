extends Node
## GameState - Manages match state, scores, teams, and game phases
## Autoload singleton for game-wide state management

signal match_phase_changed(phase: MatchPhase)
signal score_updated(peer_id: int, score: int)
signal player_killed(killer_id: int, victim_id: int)
signal team_score_updated(team: Team, score: int)
signal game_mode_changed(mode: GameMode)

enum GameMode { FREE_FOR_ALL, TEAM_BATTLE }
enum MatchPhase { MENU, LOBBY, STARTING, PLAYING, ENDED }
enum Team { NONE, RED, BLUE }

var game_mode: GameMode = GameMode.FREE_FOR_ALL
var match_phase: MatchPhase = MatchPhase.MENU
var player_scores: Dictionary = {}  # peer_id -> int
var player_teams: Dictionary = {}   # peer_id -> Team
var player_names: Dictionary = {}   # peer_id -> String
var team_scores: Dictionary = { Team.RED: 0, Team.BLUE: 0 }

# Match settings
var kills_to_win: int = 10
var match_time_limit: float = 300.0  # 5 minutes
var match_timer: float = 0.0

# Player settings
var mouse_sensitivity: float = 0.01
var player_fov: float = 90.0
var aspect_ratio: int = 0  # 0=Auto, 1=16:9, 2=4:3, 3=21:9

func _ready() -> void:
	NetworkManager.player_disconnected.connect(_on_player_disconnected)

func reset_match() -> void:
	player_scores.clear()
	team_scores = { Team.RED: 0, Team.BLUE: 0 }
	match_timer = 0.0

func set_game_mode(mode: GameMode) -> void:
	game_mode = mode
	game_mode_changed.emit(mode)

func set_match_phase(phase: MatchPhase) -> void:
	match_phase = phase
	match_phase_changed.emit(phase)

func register_player(peer_id: int, player_name: String = "") -> void:
	if player_name.is_empty():
		player_name = "Player " + str(peer_id)
	player_names[peer_id] = player_name
	player_scores[peer_id] = 0
	player_teams[peer_id] = Team.NONE

func unregister_player(peer_id: int) -> void:
	player_scores.erase(peer_id)
	player_teams.erase(peer_id)
	player_names.erase(peer_id)

func set_player_team(peer_id: int, team: Team) -> void:
	player_teams[peer_id] = team

func get_player_team(peer_id: int) -> Team:
	return player_teams.get(peer_id, Team.NONE)

func add_kill(killer_id: int, victim_id: int) -> void:
	if killer_id in player_scores:
		player_scores[killer_id] += 1
		score_updated.emit(killer_id, player_scores[killer_id])

		# Update team score if in team mode
		if game_mode == GameMode.TEAM_BATTLE:
			var killer_team = get_player_team(killer_id)
			if killer_team != Team.NONE:
				team_scores[killer_team] += 1
				team_score_updated.emit(killer_team, team_scores[killer_team])

	player_killed.emit(killer_id, victim_id)
	_check_win_condition()

func get_score(peer_id: int) -> int:
	return player_scores.get(peer_id, 0)

func get_team_score(team: Team) -> int:
	return team_scores.get(team, 0)

func get_leaderboard() -> Array:
	var leaderboard = []
	for peer_id in player_scores:
		leaderboard.append({
			"id": peer_id,
			"name": player_names.get(peer_id, "Unknown"),
			"score": player_scores[peer_id],
			"team": player_teams.get(peer_id, Team.NONE)
		})
	leaderboard.sort_custom(func(a, b): return a.score > b.score)
	return leaderboard

func _check_win_condition() -> void:
	if match_phase != MatchPhase.PLAYING:
		return

	if game_mode == GameMode.FREE_FOR_ALL:
		for peer_id in player_scores:
			if player_scores[peer_id] >= kills_to_win:
				_end_match()
				return
	else:
		for team in team_scores:
			if team_scores[team] >= kills_to_win:
				_end_match()
				return

func _end_match() -> void:
	set_match_phase(MatchPhase.ENDED)

func _on_player_disconnected(peer_id: int) -> void:
	unregister_player(peer_id)

# Network sync functions
@rpc("authority", "call_local", "reliable")
func sync_game_state(mode: int, phase: int, scores: Dictionary, teams: Dictionary, t_scores: Dictionary) -> void:
	game_mode = mode as GameMode
	match_phase = phase as MatchPhase
	player_scores = scores
	player_teams = teams
	team_scores = t_scores

func broadcast_state() -> void:
	if NetworkManager.is_server():
		sync_game_state.rpc(game_mode, match_phase, player_scores, player_teams, team_scores)
