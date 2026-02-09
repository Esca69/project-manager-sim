extends Panel

# Сигнал: "Я выбрал вот этого человека"
signal employee_selected(data: EmployeeData)

@onready var item_list = $MainVBox/ContentMargin/VBoxContainer/ItemList

# Текущий фильтр по типу этапа ("BA", "DEV", "QA" или "" = все)
var _filter_stage_type: String = ""

func _ready():
	visible = false # Скрыт по умолчанию

# --- С фильтрацией по типу этапа ---
# stage_type: "BA", "DEV", "QA" или "" (показать всех)
func open_list(stage_type: String = ""):
	_filter_stage_type = stage_type
	item_list.clear()
	visible = true
	
	# 1. Ищем всех NPC в сцене (по группе "npc")
	var npcs = get_tree().get_nodes_in_group("npc")
	
	for npc in npcs:
		# Проверяем, есть ли у NPC данные (паспорт)
		if npc.data:
			# 2. Фильтрация: если задан тип — показываем только подходящих
			if _filter_stage_type != "" and not _matches_stage_type(npc.data, _filter_stage_type):
				continue
			
			# 3. Добавляем строчку в список
			var index = item_list.add_item(npc.data.employee_name + " (" + npc.data.job_title + ")")
			
			# 4. Прячем ссылку на данные ВНУТРИ строки
			item_list.set_item_metadata(index, npc.data)
	
	# Если после фильтрации список пуст — показываем подсказку
	if item_list.item_count == 0:
		var role_name = _get_role_name(_filter_stage_type)
		item_list.add_item("⚠ Нет сотрудников с ролью " + role_name)
		item_list.set_item_disabled(0, true)
		item_list.set_item_selectable(0, false)

# Проверяет, подходит ли сотрудник для данного типа этапа
func _matches_stage_type(data: EmployeeData, stage_type: String) -> bool:
	match stage_type:
		"BA":
			return data.job_title == "Business Analyst"
		"DEV":
			return data.job_title == "Backend Developer"
		"QA":
			return data.job_title == "QA Engineer"
	return true

# Возвращает читаемое название роли для подсказки
func _get_role_name(stage_type: String) -> String:
	match stage_type:
		"BA": return "Business Analyst"
		"DEV": return "Backend Developer"
		"QA": return "QA Engineer"
	return stage_type

# Когда нажали н�� кнопку "Отмена" или "X"
func _on_cancel_button_pressed():
	visible = false

# Когда кликнули по элементу списка
func _on_item_list_item_activated(index):
	var data = item_list.get_item_metadata(index)
	
	# Защита: если metadata пуст (например кликнули на подсказку)
	if data == null:
		return
	
	emit_signal("employee_selected", data)
	visible = false

func _on_button_pressed():
	pass
