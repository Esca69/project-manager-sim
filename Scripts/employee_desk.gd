extends StaticBody2D

# Данные сотрудника, который тут сидит (если null - стол свободен)
var assigned_employee: EmployeeData = null

# Ссылка на NPC-ноду, которая сейчас сидит за столом
var assigned_npc_node = null

# Ссылки на узлы
@onready var name_tag = $NameTag
@onready var seat_point = $SeatPosition # Точка, куда мы направляем человека

func _ready():
	update_desk_visuals()

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
	
	return old_npc  # Возвращаем ноду старого NPC, чтобы меню могло его "��тпустить"

func update_desk_visuals():
	if assigned_employee:
		name_tag.text = assigned_employee.employee_name
		name_tag.modulate = Color.GREEN
	else:
		name_tag.text = "СВОБОДНО"
		name_tag.modulate = Color.WHITE
