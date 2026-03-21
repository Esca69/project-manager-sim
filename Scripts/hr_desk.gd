extends StaticBody2D

const HR_PROXIMITY_RADIUS: float = 300.0
var _is_player_in_radius: bool = false

func _ready():
	add_to_group("hr_desk")
	add_to_group("desk")

func _process(_delta):
	_check_proximity()

func _check_proximity():
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	var dist = global_position.distance_to(player.global_position)
	if dist <= HR_PROXIMITY_RADIUS:
		if not _is_player_in_radius:
			_is_player_in_radius = true
			TutorialManager.notify_player_near_hr()
	else:
		_is_player_in_radius = false

func interact():
	# === ТУТОРИАЛ: блокировка на не-HR шагах ===
	if TutorialManager.is_active():
		if TutorialManager.current_step != TutorialManager.Step.STEP_5_HIRE_BA:
			return

	var hud = get_tree().get_first_node_in_group("ui")
	if hud:
		if hud.has_method("open_hr_search"):
			hud.open_hr_search()
		else:
			print("ОШИБКА: Метод open_hr_search не найден в HUD!")
	else:
		print("ОШИБКА: Не найден HUD (группа 'ui')!")
