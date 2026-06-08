extends StaticBody2D

# ===================================================
# === FRONTDOOR =====================================
# ===================================================
# Detects when the player approaches the office entrance.
# Triggers tutorial transition: Step 0 → Step 1.

const FRONTDOOR_PROXIMITY_RADIUS: float = 200.0
var _is_player_in_radius: bool = false

func _ready():
	add_to_group("frontdoor")

func _process(_delta):
	_check_proximity()

func _check_proximity():
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	var dist = global_position.distance_to(player.global_position)
	if dist <= FRONTDOOR_PROXIMITY_RADIUS:
		if not _is_player_in_radius:
			_is_player_in_radius = true
			TutorialManager.notify_player_entered_office()
	else:
		_is_player_in_radius = false
