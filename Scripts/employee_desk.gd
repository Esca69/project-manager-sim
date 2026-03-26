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
	
	# ВСЕГДА открываем меню — неважно, занят стол или свободен
	var hud = get_tree().get_first_node_in_group("ui")
	if hud:
		var menu = hud.get_node_or_null("AssignmentMenu")
		if menu:
			menu.open_assignment_list(self)
		else:
			print("ОШИБКА: AssignmentMenu не найдено в HUD!")

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
