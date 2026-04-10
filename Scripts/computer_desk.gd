extends StaticBody2D

const PM_DESK_PROXIMITY_RADIUS: float = 200.0
var _is_player_in_radius: bool = false

func _ready():
	add_to_group("pm_desk")
	add_to_group("desk")

func _process(_delta):
	_check_proximity()

func _check_proximity():
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	var dist = global_position.distance_to(player.global_position)
	if dist <= PM_DESK_PROXIMITY_RADIUS:
		if not _is_player_in_radius:
			_is_player_in_radius = true
			TutorialManager.notify_player_near_pm_desk()
	else:
		_is_player_in_radius = false

func interact():
	var hud = get_tree().get_first_node_in_group("ui")
	if hud:
		hud.open_work_menu()
