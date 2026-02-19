extends Panel

# Ссылка на стол, который сейчас ждёт назначения
var target_desk = null

@onready var item_list = $MainVBox/ContentMargin/VBoxContainer/ItemList
@onready var close_btn = find_child("CloseButton", true, false)

var color_main = Color(0.17254902, 0.30980393, 0.5686275, 1)

func _ready():
	visible = false
	
	# === УМНОЕ УДАЛЕНИЕ КНОПОК ===
	var all_buttons = find_children("*", "Button", true, false)
	for btn in all_buttons:
		if close_btn and btn != close_btn:
			btn.queue_free()
			
	if close_btn:
		if not close_btn.pressed.is_connected(_on_close_pressed):
			close_btn.pressed.connect(_on_close_pressed)

	if UITheme:
		UITheme.apply_font(item_list, "regular")
		var title_label = find_child("TitleLabel", true, false)
		if title_label:
			UITheme.apply_font(title_label, "bold")
			# Используем существующий ключ для выбора сотрудника
			title_label.text = tr("EMP_SELECT_TITLE")
			
	var list_style = StyleBoxFlat.new()
	list_style.bg_color = Color(1, 1, 1, 1)
	list_style.border_width_left = 2
	list_style.border_width_top = 2
	list_style.border_width_right = 2
	list_style.border_width_bottom = 2
	list_style.border_color = Color(0.85, 0.85, 0.85, 1)
	list_style.corner_radius_top_left = 10
	list_style.corner_radius_top_right = 10
	list_style.corner_radius_bottom_right = 10
	list_style.corner_radius_bottom_left = 10
	item_list.add_theme_stylebox_override("panel", list_style)
	
	item_list.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	var selected_style = StyleBoxFlat.new()
	selected_style.bg_color = Color(0.9, 0.94, 1.0, 1)
	selected_style.corner_radius_top_left = 4
	selected_style.corner_radius_top_right = 4
	selected_style.corner_radius_bottom_right = 4
	selected_style.corner_radius_bottom_left = 4
	
	item_list.add_theme_stylebox_override("selected", selected_style)
	item_list.add_theme_stylebox_override("selected_focus", selected_style)
	item_list.add_theme_stylebox_override("hovered", selected_style)

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
	
	var current_employee_data = target_desk.assigned_employee if target_desk else null
	
	for npc in all_npcs:
		if npc.data:
			# Переводим должность
			var display_name = npc.data.employee_name + " (" + tr(npc.data.job_title) + ")"
			
			if current_employee_data and npc.data == current_employee_data:
				# Добавляем метку текущего сотрудника
				display_name = "★ " + display_name + tr("ASSIGN_MENU_CURRENT")
			
			var index = item_list.add_item(display_name)
			item_list.set_item_metadata(index, npc)
			found_any = true
	
	if not found_any:
		var index = item_list.add_item(tr("ASSIGN_MENU_NO_STAFF"))
		item_list.set_item_disabled(index, true)
		item_list.set_item_selectable(index, false)

# --- Ищем стол, за которым уже сидит данный NPC ---
func _find_desk_with_npc(npc_node):
	var all_desks = get_tree().get_nodes_in_group("desk")
	for desk in all_desks:
		if "assigned_npc_node" in desk and desk.assigned_npc_node == npc_node:
			return desk
	return null

# --- Когда дважды кликнули по сотруднику в списке ---
func _on_item_list_item_activated(index):
	var npc_node = item_list.get_item_metadata(index)
	
	if npc_node == null:
		return
	
	if target_desk:
		if target_desk.assigned_npc_node == npc_node:
			print(tr("LOG_WARN_ALREADY_AT_DESK"))
			visible = false
			target_desk = null
			return
		
		if target_desk.assigned_employee:
			var old_npc = target_desk.unassign_employee()
			if old_npc and old_npc.has_method("release_from_desk"):
				old_npc.release_from_desk()
				print(tr("LOG_EMP_RELEASED") % old_npc.data.employee_name)
		
		var old_desk = _find_desk_with_npc(npc_node)
		if old_desk and old_desk != target_desk:
			old_desk.unassign_employee()
			print(tr("LOG_EMP_MOVED_DESK") % [npc_node.data.employee_name, old_desk.name])
		
		target_desk.assign_employee(npc_node.data, npc_node)
		npc_node.move_to_desk(target_desk.seat_point.global_position)
		print(tr("LOG_EMP_ORDER_DESK") % npc_node.data.employee_name)
	
	visible = false
	target_desk = null

func _on_close_pressed():
	visible = false
	target_desk = null
