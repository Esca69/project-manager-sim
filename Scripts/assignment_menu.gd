extends Control

# Ссылка на стол, который сейчас ждёт назначения
var target_desk = null

@onready var item_list = $PanelWindow/MainVBox/ContentMargin/VBoxContainer/ItemList
@onready var close_btn = find_child("CloseButton", true, false)

var color_main = Color(0.17254902, 0.30980393, 0.5686275, 1)

var _overlay: ColorRect
var _was_paused: bool = false

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 90
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# === ЗАТЕМНЕНИЕ ФОНА ===
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.45)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)
	move_child(_overlay, 0)

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
	_was_paused = GameTime.is_game_paused
	GameTime.set_paused(true)
	target_desk = desk_node
	_refresh_list()
	if UITheme:
		UITheme.fade_in(self, 0.2)
	else:
		visible = true

# --- Заполняем ItemList сотрудниками ---
func _refresh_list():
	item_list.clear()
	
	var all_npcs = get_tree().get_nodes_in_group("npc")
	var found_any = false
	
	var current_employee_data = target_desk.assigned_employee if target_desk else null
	
	for npc in all_npcs:
		if npc.data:
			# ИСПРАВЛЕНИЕ: Используем get_display_name() вместо employee_name
			var display_name = npc.data.get_display_name() + " (" + tr(npc.data.job_title) + ")"
			
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
			_on_close_pressed()
			return
		
		if target_desk.assigned_employee:
			var old_npc = target_desk.unassign_employee()
			if old_npc and old_npc.has_method("release_from_desk"):
				old_npc.release_from_desk()
				# ИСПРАВЛЕНИЕ: Выводим локализованное имя в лог
				print(tr("LOG_EMP_RELEASED") % old_npc.data.get_display_name())
		
		var old_desk = _find_desk_with_npc(npc_node)
		if old_desk and old_desk != target_desk:
			old_desk.unassign_employee()
			# ИСПРАВЛЕНИЕ: Выводим локализованное имя в лог
			print(tr("LOG_EMP_MOVED_DESK") % [npc_node.data.get_display_name(), old_desk.name])
		
		target_desk.assign_employee(npc_node.data, npc_node)
		npc_node.move_to_desk(target_desk.seat_point.global_position)
		# ИСПРАВЛЕНИЕ: Выводим локализованное имя в лог
		print(tr("LOG_EMP_ORDER_DESK") % npc_node.data.get_display_name())
		
		# === ТУТОРИАЛ: уведомляем о назначении за стол ===
		TutorialManager.notify_worker_assigned()
	
	_on_close_pressed()

func _on_close_pressed():
	if not _was_paused:
		GameTime.set_paused(false)
	target_desk = null
	if UITheme:
		UITheme.fade_out(self, 0.15)
	else:
		visible = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and visible:
		_on_close_pressed()
		get_viewport().set_input_as_handled()
