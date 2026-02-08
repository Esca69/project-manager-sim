extends Control

# --- ССЫЛКИ НА UI ---
# Используем уникальные имена (%) для поиска главных карт
@onready var card1 = %Card1
@onready var card2 = %Card2
@onready var card3 = %Card3

# Кнопка закрытия
@onready var close_btn = find_child("CloseButton", true, false)

@onready var cards = [card1, card2, card3]

# --- ДАННЫЕ ---
var generator_script = preload("res://Scripts/candidate_generator.gd").new()
var candidates = []

# Список забавных особенностей
var funny_traits = [
	"Пьет 5 литров кофе в день",
	"Любит долгие совещания",
	"Печатает одним пальцем",
	"Боится красного цвета",
	"Всегда опаздывает на 1 минуту",
	"Спит с открытыми глазами",
	"Не верит в баги",
	"Кодит только под метал",
	"Любит покакать на работе"
]

func _ready():
	visible = false
	
	if close_btn:
		close_btn.pressed.connect(_on_close_pressed)
	else:
		print("ОШИБКА: Не найдена кнопка CloseButton (проверь имя в сцене)!")
	
	# Подключаем кнопки "Нанять"
	for i in range(cards.size()):
		var card = cards[i]
		# Ищем кнопку внутри карты по имени
		var btn = find_node_by_name(card, "HireButton")
		
		if btn:
			if not btn.is_connected("pressed", _on_hire_pressed):
				btn.pressed.connect(_on_hire_pressed.bind(i))
		else:
			print("ОШИБКА: Не найдена HireButton в карточке ", i)

func open_hiring_menu():
	generate_new_candidates()
	update_ui()
	visible = true

func _on_close_pressed():
	visible = false

func generate_new_candidates():
	candidates.clear()
	for i in range(3):
		# Генерируем нового кандидата (EmployeeData)
		var new_human = generator_script.generate_random_candidate()
		
		# [ИСПРАВЛЕНО] Записываем особенность в официальное поле
		if new_human:
			new_human.trait_text = funny_traits.pick_random()
			
		candidates.append(new_human)

func update_ui():
	for i in range(3):
		var card = cards[i]
		var data = candidates[i]
		
		# Ищем элементы UI по именам
		var name_lbl = find_node_by_name(card, "NameLabel")
		var role_lbl = find_node_by_name(card, "RoleLabel")
		var salary_lbl = find_node_by_name(card, "SalaryLabel")
		var skill_lbl = find_node_by_name(card, "SkillLabel")
		var traits_lbl = find_node_by_name(card, "TraitsLabel")
		var btn = find_node_by_name(card, "HireButton")
		
		if data != null:
			# --- КАНДИДАТ ЕСТЬ ---
			card.modulate = Color.WHITE
			if btn: btn.disabled = false
			
			if name_lbl: name_lbl.text = data.employee_name
			if role_lbl: role_lbl.text = data.job_title
			if salary_lbl: salary_lbl.text = "$ " + str(data.monthly_salary)
			
			# Навыки
			var skill_text = ""
			if data.skill_business_analysis > 0: skill_text = "BA: " + str(data.skill_business_analysis)
			elif data.skill_backend > 0: skill_text = "Backend: " + str(data.skill_backend)
			elif data.skill_qa > 0: skill_text = "QA: " + str(data.skill_qa)
			
			if skill_lbl: skill_lbl.text = skill_text
			
			# [ИСПРАВЛЕНО] Читаем особенность из официального поля
			if traits_lbl:
				traits_lbl.text = "Особенность: " + data.trait_text
				
		else:
			# --- КАНДИДАТА НЕТ (Уже нанят) ---
			card.modulate = Color(1, 1, 1, 0.5) # Полупрозрачный
			if btn: btn.disabled = true
			
			if name_lbl: name_lbl.text = "---"
			if role_lbl: role_lbl.text = "ВАКАНСИЯ ЗАКРЫТА"
			if salary_lbl: salary_lbl.text = ""
			if skill_lbl: skill_lbl.text = ""
			if traits_lbl: traits_lbl.text = ""

func _on_hire_pressed(index):
	var human_to_hire = candidates[index]
	if human_to_hire == null: return
	
	print("Нанимаем: ", human_to_hire.employee_name)
	
	# Логика спавна
	var office = get_tree().current_scene
	
	# Страховка поиска метода
	if not office.has_method("spawn_new_employee"):
		var office_manager = get_tree().get_first_node_in_group("office_manager")
		if office_manager and office_manager.has_method("spawn_new_employee"):
			office = office_manager
	
	if office.has_method("spawn_new_employee"):
		office.spawn_new_employee(human_to_hire)
	else:
		print("КРИТИЧЕСКАЯ ОШИБКА: Не найден метод spawn_new_employee!")
	
	# Убираем кандидата из списка
	candidates[index] = null
	update_ui()

# --- ВСПОМОГАТЕЛЬНАЯ ФУНКЦИЯ ---
# Находит узел по имени внутри дерева (рекурсивно)
func find_node_by_name(root, target_name):
	if root.name == target_name: return root
	for child in root.get_children():
		var found = find_node_by_name(child, target_name)
		if found: return found
	return null
