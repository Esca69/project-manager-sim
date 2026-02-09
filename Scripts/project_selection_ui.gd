extends Control

# Сигнал, который полетит в HUD, когда мы выберем проект
signal project_selected(data: ProjectData)

# --- ССЫЛКИ НА UI ---
@onready var card1 = %Card1
@onready var card2 = %Card2
@onready var card3 = %Card3

@onready var close_btn = find_child("CloseButton", true, false)

@onready var cards = [card1, card2, card3]

# --- ДАННЫЕ ---
var current_options = []

func _ready():
	visible = false
	
	if close_btn:
		close_btn.pressed.connect(_on_close_pressed)
	else:
		print("ОШИБКА: Не найдена кнопка CloseButton!")
	
	# Подключаем кнопки "Выбрать"
	for i in range(cards.size()):
		var card = cards[i]
		var btn = find_node_by_name(card, "SelectButton")
		
		if btn:
			if not btn.is_connected("pressed", _on_select_pressed):
				btn.pressed.connect(_on_select_pressed.bind(i))
		else:
			print("ОШИБКА: Не найдена SelectButton в карточке ", i)

# Функция открытия меню (генерирует новые варианты)
func open_selection():
	generate_new_projects()
	update_ui()
	visible = true

func _on_close_pressed():
	visible = false

func generate_new_projects():
	current_options.clear()
	for i in range(3):
		var proj = ProjectGenerator.generate_random_project(GameTime.day)
		current_options.append(proj)

func update_ui():
	for i in range(3):
		var card = cards[i]
		var data = current_options[i]
		
		# Ищем элементы UI по именам
		var name_lbl = find_node_by_name(card, "NameLabel")
		var work_lbl = find_node_by_name(card, "WorkLabel")
		var budget_lbl = find_node_by_name(card, "BudgetLabel")
		var soft_lbl = find_node_by_name(card, "SoftDeadlineLabel")
		var hard_lbl = find_node_by_name(card, "HardDeadlineLabel")
		var btn = find_node_by_name(card, "SelectButton")
		
		if data != null:
			# --- ПРОЕКТ ЕСТЬ ---
			card.modulate = Color.WHITE
			if btn: btn.disabled = false
			
			# Название
			if name_lbl: name_lbl.text = data.title
			
			# Необходимые работы
			if work_lbl:
				var ba_amount = 0
				var dev_amount = 0
				var qa_amount = 0
				
				for stage in data.stages:
					match stage.type:
						"BA": ba_amount = stage.amount
						"DEV": dev_amount = stage.amount
						"QA": qa_amount = stage.amount
				
				work_lbl.text = "Необходимые работы:    BA " + str(ba_amount) + "    DEV " + str(dev_amount) + "    QA " + str(qa_amount)
			
			# Бюджет
			if budget_lbl: budget_lbl.text = "Бюджет $" + str(data.budget)
			
			# Дедлайны (показываем дни от текущего дня)
			var soft_days = data.soft_deadline_day - GameTime.day
			var hard_days = data.deadline_day - GameTime.day
			
			if soft_lbl: soft_lbl.text = "Софт-дедлайн: " + str(soft_days) + " дней"
			if hard_lbl: hard_lbl.text = "Хард-дедлайн: " + str(hard_days) + " дней"
			
		else:
			# --- ПРОЕКТ УЖЕ ВЫБРАН ---
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
	visible = false

# --- ВСПОМОГАТЕЛЬНАЯ ФУНКЦИЯ ---
func find_node_by_name(root, target_name):
	if root.name == target_name: return root
	for child in root.get_children():
		var found = find_node_by_name(child, target_name)
		if found: return found
	return null
