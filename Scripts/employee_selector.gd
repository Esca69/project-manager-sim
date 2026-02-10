extends Panel

# Сигнал: "Я выбрал вот этого человека"
signal employee_selected(data: EmployeeData)

@onready var item_list = $MainVBox/ContentMargin/VBoxContainer/ItemList

# Текущий фильтр по типу этапа ("BA", "DEV", "QA" или "" = все)
var _filter_stage_type: String = ""

func _ready():
	visible = false

func open_list(stage_type: String = ""):
	_filter_stage_type = stage_type
	item_list.clear()
	visible = true
	
	var npcs = get_tree().get_nodes_in_group("npc")
	
	for npc in npcs:
		if npc.data:
			# Фильтрация по роли
			if _filter_stage_type != "" and not _matches_stage_type(npc.data, _filter_stage_type):
				continue
			
			# --- [НОВОЕ] Проверяем, занят ли сотрудник на ЛЮБОМ проекте ---
			var is_busy = _is_employee_assigned_to_any_project(npc.data)
			
			var display_name = npc.data.employee_name + " (" + npc.data.job_title + ")"
			
			if is_busy:
				display_name += " — 🔒 Занят на проекте"
			
			var index = item_list.add_item(display_name)
			item_list.set_item_metadata(index, npc.data)
			
			# Если занят — делаем строку недоступной
			if is_busy:
				item_list.set_item_disabled(index, true)
				item_list.set_item_selectable(index, false)
				# Серый цвет для занятых
				item_list.set_item_custom_fg_color(index, Color(0.6, 0.6, 0.6, 1))
	
	# Если после фильтрации список пуст — показываем подсказку
	if item_list.item_count == 0:
		var role_name = _get_role_name(_filter_stage_type)
		item_list.add_item("⚠ Нет сотрудников с ролью " + role_name)
		item_list.set_item_disabled(0, true)
		item_list.set_item_selectable(0, false)

# --- [НОВОЕ] Проверяем, назначен ли сотрудник на ЛЮБОЙ этап ЛЮБОГО проекта ---
func _is_employee_assigned_to_any_project(emp_data: EmployeeData) -> bool:
	for project in ProjectManager.active_projects:
		# Проверяем только незавершённые проекты
		if project.state == ProjectData.State.FINISHED:
			continue
		if project.state == ProjectData.State.FAILED:
			continue
		
		for stage in project.stages:
			for worker in stage.workers:
				if worker == emp_data:
					return true
	
	return false

func _matches_stage_type(data: EmployeeData, stage_type: String) -> bool:
	match stage_type:
		"BA":
			return data.job_title == "Business Analyst"
		"DEV":
			return data.job_title == "Backend Developer"
		"QA":
			return data.job_title == "QA Engineer"
	return true

func _get_role_name(stage_type: String) -> String:
	match stage_type:
		"BA": return "Business Analyst"
		"DEV": return "Backend Developer"
		"QA": return "QA Engineer"
	return stage_type

func _on_cancel_button_pressed():
	visible = false

func _on_item_list_item_activated(index):
	var data = item_list.get_item_metadata(index)
	
	if data == null:
		return
	
	emit_signal("employee_selected", data)
	visible = false

func _on_button_pressed():
	pass
