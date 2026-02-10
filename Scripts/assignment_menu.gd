extends Panel

# Ссылка на стол, который сейчас ждёт назначения
var target_desk = null

@onready var item_list = $MainVBox/ContentMargin/VBoxContainer/ItemList

func _ready():
	visible = false

# --- Вызывает Стол, когда хочет посадить/заменить сотрудника ---
func open_assignment_list(desk_node):
	target_desk = desk_node
	_refresh_list()
	visible = true

# --- Заполняем ItemList сотрудниками ---
func _refresh_list():
	item_list.clear()
	
	var all_npcs = get_tree().get_nodes_in_group("npc")
	var found_any = false
	
	# Кто сейчас сидит за этим столом? (чтобы пометить его в списке)
	var current_employee_data = target_desk.assigned_employee if target_desk else null
	
	for npc in all_npcs:
		if npc.data:
			var display_name = npc.data.employee_name + " (" + npc.data.job_title + ")"
			
			# Помечаем текущего сотрудника этого стола
			if current_employee_data and npc.data == current_employee_data:
				display_name = "★ " + display_name + "  [текущий]"
			
			var index = item_list.add_item(display_name)
			item_list.set_item_metadata(index, npc)
			found_any = true
	
	if not found_any:
		var index = item_list.add_item("⚠ Нет доступных сотрудников!")
		item_list.set_item_disabled(index, true)
		item_list.set_item_selectable(index, false)

# --- Ищем стол, за которым уже сидит данный NPC ---
func _find_desk_with_npc(npc_node):
	var all_desks = get_tree().get_nodes_in_group("desk")
	for desk in all_desks:
		# Проверяем, что у стола ЕСТЬ свойство assigned_npc_node
		# (computer_desk и другие столы его не имеют)
		if "assigned_npc_node" in desk and desk.assigned_npc_node == npc_node:
			return desk
	return null

# --- Ког��а дважды кликнули по сотруднику в списке ---
func _on_item_list_item_activated(index):
	var npc_node = item_list.get_item_metadata(index)
	
	# Защита: если metadata пуст
	if npc_node == null:
		return
	
	if target_desk:
		# --- ЕСЛИ ВЫБРАЛИ ТОГО ЖЕ, КТО УЖЕ СИДИТ ЗА ЭТИМ СТОЛОМ ---
		if target_desk.assigned_npc_node == npc_node:
			print("Этот сотрудник уже сидит за этим столом!")
			visible = false
			target_desk = null
			return
		
		# --- ШАГ 1: Если за ЭТИМ столом уже кто-то сидит — освобождаем его ---
		if target_desk.assigned_employee:
			var old_npc = target_desk.unassign_employee()
			if old_npc and old_npc.has_method("release_from_desk"):
				old_npc.release_from_desk()
				print("🔄 ", old_npc.data.employee_name, " освобождён от текущего стола")
		
		# --- ШАГ 2: Если этот NPC уже сидит за ДРУГИМ столом — снимаем его оттуда ---
		var old_desk = _find_desk_with_npc(npc_node)
		if old_desk and old_desk != target_desk:
			old_desk.unassign_employee()
			print("🔄 ", npc_node.data.employee_name, " снят со стола: ", old_desk.name)
		
		# --- ШАГ 3: Назначаем нового ---
		target_desk.assign_employee(npc_node.data, npc_node)
		npc_node.move_to_desk(target_desk.seat_point.global_position)
		print("✅ ", npc_node.data.employee_name, " получил приказ идти к столу!")
	
	visible = false
	target_desk = null

# --- Кнопка "Закрыть" или "X" ---
func _on_close_pressed():
	visible = false
	target_desk = null
