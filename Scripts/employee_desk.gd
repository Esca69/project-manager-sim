extends StaticBody2D

# Данные сотрудника, который тут сидит (если null - стол свободен)
var assigned_employee: EmployeeData = null

# Ссылка на NPC-ноду, которая сейчас сидит за столом
var assigned_npc_node = null

# Ссылки на узлы
@onready var name_tag = $NameTag
@onready var seat_point = $SeatPosition # Точка, куда мы направляем человека

const DESK_PROXIMITY_RADIUS: float = 260.0
var _is_player_in_radius: bool = false

# === СИСТЕМА УЛУЧШЕНИЙ РАБОЧЕГО МЕСТА ===
var desk_upgrades: Dictionary = {
	"second_monitor": false,
	"desk_plant": false,
	"software_ba": false,
	"software_ba_active": false,
	"software_dev": false,
	"software_dev_active": false,
	"software_qa": false,
	"software_qa_active": false,
	"ai_subscription": false,
	"ai_subscription_active": false,
}

const DESK_UPGRADE_CONFIG = {
	"second_monitor": {
		"type": "one_time",
		"cost": 250,
		"efficiency_bonus": 0.10,
		"mood_bonus": 0.0,
		"xp_multiplier": 1.0,
		"role_lock": "",
		"name_key": "DESK_UPG_SECOND_MONITOR",
		"desc_key": "DESK_UPG_SECOND_MONITOR_DESC",
		"emoji": "🖥️",
	},
	"desk_plant": {
		"type": "one_time",
		"cost": 100,
		"efficiency_bonus": 0.0,
		"mood_bonus": 3.0,
		"xp_multiplier": 1.0,
		"role_lock": "",
		"name_key": "DESK_UPG_DESK_PLANT",
		"desc_key": "DESK_UPG_DESK_PLANT_DESC",
		"emoji": "🌱",
	},
	"software_ba": {
		"type": "subscription",
		"daily_cost": 10,
		"efficiency_bonus": 0.10,
		"mood_bonus": 0.0,
		"xp_multiplier": 1.0,
		"role_lock": "Business Analyst",
		"name_key": "DESK_UPG_SOFTWARE_BA",
		"desc_key": "DESK_UPG_SOFTWARE_BA_DESC",
		"emoji": "📊",
	},
	"software_dev": {
		"type": "subscription",
		"daily_cost": 15,
		"efficiency_bonus": 0.10,
		"mood_bonus": 0.0,
		"xp_multiplier": 1.0,
		"role_lock": "Backend Developer",
		"name_key": "DESK_UPG_SOFTWARE_DEV",
		"desc_key": "DESK_UPG_SOFTWARE_DEV_DESC",
		"emoji": "💻",
	},
	"software_qa": {
		"type": "subscription",
		"daily_cost": 7,
		"efficiency_bonus": 0.10,
		"mood_bonus": 0.0,
		"xp_multiplier": 1.0,
		"role_lock": "QA Engineer",
		"name_key": "DESK_UPG_SOFTWARE_QA",
		"desc_key": "DESK_UPG_SOFTWARE_QA_DESC",
		"emoji": "🧪",
	},
	"ai_subscription": {
		"type": "subscription",
		"daily_cost": 25,
		"efficiency_bonus": 0.15,
		"mood_bonus": 0.0,
		"xp_multiplier": 0.5,
		"role_lock": "",
		"name_key": "DESK_UPG_AI_SUB",
		"desc_key": "DESK_UPG_AI_SUB_DESC",
		"emoji": "🤖",
	},
}

func is_upgrade_active(upgrade_id: String) -> bool:
	var config = DESK_UPGRADE_CONFIG.get(upgrade_id)
	if config == null:
		return false
	if config.type == "one_time":
		return desk_upgrades.get(upgrade_id, false)
	elif config.type == "subscription":
		return desk_upgrades.get(upgrade_id, false) and desk_upgrades.get(upgrade_id + "_active", false)
	return false

func get_daily_subscription_cost() -> int:
	var total = 0
	for upgrade_id in DESK_UPGRADE_CONFIG:
		var config = DESK_UPGRADE_CONFIG[upgrade_id]
		if config.type != "subscription":
			continue
		if is_upgrade_active(upgrade_id):
			total += config.daily_cost
	return total

func buy_upgrade(upgrade_id: String) -> bool:
	var config = DESK_UPGRADE_CONFIG.get(upgrade_id)
	if config == null:
		return false
	var gs = get_node_or_null("/root/GameState")
	if gs == null:
		return false
	var cost = config.get("cost", config.get("daily_cost", 0))
	if gs.company_balance < cost:
		return false
	gs.add_expense(cost)
	gs.daily_event_expenses.append({"reason": "SUMMARY_DESK_UPGRADE", "amount": cost})
	if config.type == "one_time":
		desk_upgrades[upgrade_id] = true
	elif config.type == "subscription":
		desk_upgrades[upgrade_id] = true
		desk_upgrades[upgrade_id + "_active"] = true
	var el = get_node_or_null("/root/EventLog")
	if el:
		el.add(tr("LOG_DESK_UPGRADE_BOUGHT") % tr(config.name_key), el.LogType.PROGRESS)
	return true

func toggle_subscription(upgrade_id: String):
	if not desk_upgrades.get(upgrade_id, false):
		return
	var active_key = upgrade_id + "_active"
	desk_upgrades[active_key] = not desk_upgrades.get(active_key, false)
	var el = get_node_or_null("/root/EventLog")
	if el and desk_upgrades[active_key]:
		var config = DESK_UPGRADE_CONFIG.get(upgrade_id, {})
		el.add(tr("LOG_DESK_SUB_ACTIVATED") % tr(config.get("name_key", upgrade_id)), el.LogType.PROGRESS)
	elif el:
		var config = DESK_UPGRADE_CONFIG.get(upgrade_id, {})
		el.add(tr("LOG_DESK_SUB_PAUSED") % tr(config.get("name_key", upgrade_id)), el.LogType.INFO)

func _ready():
	add_to_group("desk")
	update_desk_visuals()

func _process(_delta):
	if not TutorialManager.is_active():
		return
	if TutorialManager.current_step != TutorialManager.Step.STEP_6_SEAT_WORKER:
		_is_player_in_radius = false
		return
	# Only trigger on free desks
	if assigned_employee != null:
		return
	# Skip hidden (not purchased) desks
	if not visible:
		return
	_check_proximity()

func _check_proximity():
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	var dist = global_position.distance_to(player.global_position)
	if dist <= DESK_PROXIMITY_RADIUS:
		if not _is_player_in_radius:
			_is_player_in_radius = true
			TutorialManager.notify_player_near_free_desk()
	else:
		_is_player_in_radius = false

# Эту функцию вызывает Игрок через interact()
func interact():
	print("Игрок трогает стол...")

	var hud = get_tree().get_first_node_in_group("ui")
	if hud:
		var panel = hud.get_node_or_null("DeskPanel")
		if panel:
			panel.open_for_desk(self)
		else:
			# Fallback: открываем AssignmentMenu напрямую (обратная совместимость)
			var menu = hud.get_node_or_null("AssignmentMenu")
			if menu:
				menu.open_assignment_list(self)
			else:
				print("ОШИБКА: DeskPanel и AssignmentMenu не найдены в HUD!")

# Эту функцию вызовет Меню, когда мы выберем нового человека
func assign_employee(data: EmployeeData, npc_node = null):
	assigned_employee = data
	assigned_npc_node = npc_node
	update_desk_visuals()

# Освобождаем стол (старый сотрудник "встаёт")
func unassign_employee():
	var old_npc = assigned_npc_node
	
	assigned_employee = null
	assigned_npc_node = null
	update_desk_visuals()
	
	return old_npc  # Возвращаем ноду старого NPC, чтобы меню могло его "отпустить"

func update_desk_visuals():
	if assigned_employee:
		# ИСПРАВЛЕНИЕ: Выводим локализованное имя на плашке стола
		name_tag.text = assigned_employee.get_display_name()
		name_tag.modulate = Color.GREEN
	else:
		name_tag.text = tr("DESK_AVAILABLE")
		name_tag.modulate = Color.WHITE
