extends Control

# Загружаем генератор
var generator_script = preload("res://Scripts/candidate_generator.gd").new()

# Храним текущих кандидатов, чтобы знать, кого спавнить
var candidates = [] 

# Ссылки на карточки (Card1, Card2, Card3)
# ВАЖНО: Проверь пути! Если ты назвал их иначе, поправь здесь.
@onready var cards = [
	$Panel/CandidatesContainer/Card1,
	$Panel/CandidatesContainer/Card2,
	$Panel/CandidatesContainer/Card3
]

@onready var close_btn = $Panel/CloseButton

func _ready():
	visible = false # Скрыто при старте
	close_btn.pressed.connect(_on_close_pressed)
	
	# Подключаем кнопки "Нанять" у каждой карточки
	# Мы используем хитрый трюк: bind(i), чтобы кнопка знала свой номер (0, 1 или 2)
	for i in range(cards.size()):
		var btn = cards[i].get_node("VBox/HireButton")
		if not btn.is_connected("pressed", _on_hire_pressed):
			btn.pressed.connect(_on_hire_pressed.bind(i))

# Эта функция вызывается, когда мы открываем меню
func open_hiring_menu():
	generate_new_candidates()
	update_ui()
	visible = true

func _on_close_pressed():
	visible = false

# Генерируем 3 случайных людей
func generate_new_candidates():
	candidates.clear()
	for i in range(3):
		var new_human = generator_script.generate_random_candidate()
		candidates.append(new_human)

# Обновляем текст на карточках
func update_ui():
	for i in range(3):
		var card = cards[i]
		var data = candidates[i]
		
		# Ссылка на кнопку
		var btn = card.get_node("VBox/HireButton")
		
		if data != null:
			# ВАРИАНТ 1: Если кандидат ЕСТЬ — показываем данные
			card.get_node("VBox/NameLabel").text = data.employee_name
			card.get_node("VBox/RoleLabel").text = data.job_title
			card.get_node("VBox/SalaryLabel").text = str(data.monthly_salary) + " $/мес"
			
			# Навыки
			var skill_text = ""
			if data.skill_business_analysis > 0: skill_text = "BA: " + str(data.skill_business_analysis)
			elif data.skill_backend > 0: skill_text = "Backend: " + str(data.skill_backend)
			elif data.skill_qa > 0: skill_text = "QA: " + str(data.skill_qa)
			card.get_node("VBox/SkillLabel").text = skill_text
			
			# Включаем карточку
			btn.disabled = false
			card.modulate = Color(1, 1, 1, 1) # Яркая
			
		else:
			# ВАРИАНТ 2: Если кандидата НЕТ (null) — пишем "Нанят"
			card.get_node("VBox/NameLabel").text = "---"
			card.get_node("VBox/RoleLabel").text = "УЖЕ НАНЯТ"
			card.get_node("VBox/SalaryLabel").text = ""
			card.get_node("VBox/SkillLabel").text = ""
			
			# Выключаем кнопку и делаем карточку полупрозрачной
			btn.disabled = true
			card.modulate = Color(1, 1, 1, 0.5) # Тусклая

# Нажатие на кнопку "Нанять"
func _on_hire_pressed(index):
	var human_to_hire = candidates[index]
	
	if human_to_hire == null: return
	
	print("Нанимаем: ", human_to_hire.employee_name)
	
	# 1. Ищем Офис, чтобы заспавнить
	# (Предполагаем, что Office - это главная сцена)
	var office = get_tree().current_scene
	if office.has_method("spawn_new_employee"):
		office.spawn_new_employee(human_to_hire)
	else:
		print("ОШИБКА: Не могу найти office.spawn_new_employee!")
	
	# 2. Убираем кандидата из списка (чтобы нельзя было нанять дважды)
	candidates[index] = null
	
	# 3. Обновляем вид (кнопка станет серой)
	update_ui()
