extends Control

signal project_selected(data: ProjectData)

@onready var card1 = %Card1
@onready var card2 = %Card2
@onready var card3 = %Card3

@onready var close_btn = find_child("CloseButton", true, false)

@onready var cards = [card1, card2, card3]

# --- ДАННЫЕ ---
var current_options = []
var _generated_for_week: int = -1  # Номер недели, для которой уже сгенерировали

func _ready():
	visible = false
	
	if close_btn:
		close_btn.pressed.connect(_on_close_pressed)
	else:
		print("ОШИБКА: Не найдена кнопка CloseButton!")
	
	for i in range(cards.size()):
		var card = cards[i]
		var btn = find_node_by_name(card, "SelectButton")
		
		if btn:
			if not btn.is_connected("pressed", _on_select_pressed):
				btn.pressed.connect(_on_select_pressed.bind(i))
		else:
			print("ОШИБКА: Не найдена SelectButton в карточке ", i)

func open_selection():
	var current_week = _get_current_week()
	
	# Если неделя изменилась — генерируем новые проекты
	if current_week != _generated_for_week:
		generate_new_projects()
		_generated_for_week = current_week
	
	update_ui()
	visible = true

func _on_close_pressed():
	visible = false

func _get_current_week() -> int:
	# Неделя = ceil(day / 7)
	return ((GameTime.day - 1) / GameTime.DAYS_IN_WEEK) + 1

func generate_new_projects():
	current_options.clear()
	for i in range(3):
		var proj = ProjectGenerator.generate_random_project(GameTime.day)
		current_options.append(proj)

func update_ui():
	for i in range(3):
		var card = cards[i]
		var data = current_options[i]
		
		var name_lbl = find_node_by_name(card, "NameLabel")
		var work_lbl = find_node_by_name(card, "WorkLabel")
		var budget_lbl = find_node_by_name(card, "BudgetLabel")
		var soft_lbl = find_node_by_name(card, "SoftDeadlineLabel")
		var hard_lbl = find_node_by_name(card, "HardDeadlineLabel")
		var btn = find_node_by_name(card, "SelectButton")
		
		if data != null:
			card.modulate = Color.WHITE
			if btn: btn.disabled = false
			
			# Название + категория
			var cat_label = "[MICRO]" if data.category == "micro" else "[SIMPLE]"
			if name_lbl: name_lbl.text = cat_label + " " + data.title
			
			# Необходимые работы — размытие через навыки PM
			if work_lbl:
				var parts = []
				for stage in data.stages:
					parts.append(stage.type + " " + PMData.get_blurred_work(stage.amount))
				work_lbl.text = "Работы:  " + "    ".join(parts)
			
			# Бюджет — размытие через навыки PM
			if budget_lbl: budget_lbl.text = "Бюджет " + PMData.get_blurred_budget(data.budget)
			
			# Дедлайны
			var soft_days = data.soft_deadline_day - GameTime.day
			var hard_days = data.deadline_day - GameTime.day
			
			if soft_lbl:
				soft_lbl.text = "Софт: %d дн. (штраф -%d%%)" % [soft_days, data.soft_deadline_penalty_percent]
			if hard_lbl:
				hard_lbl.text = "Хард: %d дн. (провал = $0)" % hard_days
			
		else:
			card.modulate = Color(1, 1, 1, 0.5)
			if btn: btn.disabled = true
			
			if name_lbl: name_lbl.text = "---"
			if work_lbl: work_lbl.text = ""
			if budget_lbl: budget_lbl.text = ""
			if soft_lbl: soft_lbl.text = ""
			if hard_lbl: hard_lbl.text = ""

func _on_select_pressed(index):
	var selected = current_options[index]
	if selected == null: return
	
	print("Выбран проект: ", selected.title)
	emit_signal("project_selected", selected)
	
	# Убираем из списка (нельзя взять повторно)
	current_options[index] = null
	update_ui()

func find_node_by_name(root, target_name):
	if root.name == target_name: return root
	for child in root.get_children():
		var found = find_node_by_name(child, target_name)
		if found: return found
	return null
