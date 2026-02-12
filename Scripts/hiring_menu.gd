extends Control

@onready var card1 = %Card1
@onready var card2 = %Card2
@onready var card3 = %Card3

@onready var close_btn = find_child("CloseButton", true, false)

@onready var cards = [card1, card2, card3]

var generator_script = preload("res://Scripts/candidate_generator.gd").new()
var candidates = []

var _trait_containers: Array = []

func _ready():
	visible = false
	
	if close_btn:
		close_btn.pressed.connect(_on_close_pressed)
	else:
		print("ОШИБКА: Не найдена кнопка CloseButton!")
	
	for i in range(cards.size()):
		var card = cards[i]
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
		var new_human = generator_script.generate_random_candidate()
		candidates.append(new_human)

func update_ui():
	for tc in _trait_containers:
		if is_instance_valid(tc):
			tc.queue_free()
	_trait_containers.clear()
	
	for i in range(3):
		var card = cards[i]
		var data = candidates[i]
		
		var name_lbl = find_node_by_name(card, "NameLabel")
		var role_lbl = find_node_by_name(card, "RoleLabel")
		var salary_lbl = find_node_by_name(card, "SalaryLabel")
		var skill_lbl = find_node_by_name(card, "SkillLabel")
		var traits_lbl = find_node_by_name(card, "TraitsLabel")
		var btn = find_node_by_name(card, "HireButton")
		
		if data != null:
			card.modulate = Color.WHITE
			if btn: btn.disabled = false
			
			if name_lbl: name_lbl.text = data.employee_name
			if role_lbl: role_lbl.text = data.job_title
			if salary_lbl: salary_lbl.text = "$ " + str(data.monthly_salary)
			
			# === НАВЫКИ — размытие через PMData ===
			var skill_text = ""
			if data.skill_business_analysis > 0:
				skill_text = "BA: " + PMData.get_blurred_skill(data.skill_business_analysis)
			elif data.skill_backend > 0:
				skill_text = "Backend: " + PMData.get_blurred_skill(data.skill_backend)
			elif data.skill_qa > 0:
				skill_text = "QA: " + PMData.get_blurred_skill(data.skill_qa)
			
			if skill_lbl: skill_lbl.text = skill_text
			
			# Скрываем старый TraitsLabel
			if traits_lbl:
				traits_lbl.text = ""
				traits_lbl.visible = false
			
			# === ТРЕЙТЫ — фильтрация по навыку PM ===
			var card_vbox = find_node_by_name(card, "CardVBox")
			if card_vbox:
				var visible_count = PMData.get_visible_traits_count()
				
				if visible_count == 0 or data.traits.is_empty():
					# Ничего не показываем — PM ещё не умеет читать людей
					pass
				else:
					# Создаём временный EmployeeData с ограниченным набором трейтов
					var display_data = data.duplicate()
					if visible_count < data.traits.size():
						display_data.traits = data.traits.slice(0, visible_count)
					
					var traits_row = TraitUIHelper.create_traits_row(display_data, self)
					card_vbox.add_child(traits_row)
					_trait_containers.append(traits_row)
				
		else:
			card.modulate = Color(1, 1, 1, 0.5)
			if btn: btn.disabled = true
			
			if name_lbl: name_lbl.text = "---"
			if role_lbl: role_lbl.text = "ВАКАНСИЯ ЗАКРЫТА"
			if salary_lbl: salary_lbl.text = ""
			if skill_lbl: skill_lbl.text = ""
			if traits_lbl:
				traits_lbl.text = ""
				traits_lbl.visible = false

func _on_hire_pressed(index):
	var human_to_hire = candidates[index]
	if human_to_hire == null: return
	
	print("Нанимаем: ", human_to_hire.employee_name)
	
	var office = get_tree().current_scene
	
	if not office.has_method("spawn_new_employee"):
		var office_manager = get_tree().get_first_node_in_group("office_manager")
		if office_manager and office_manager.has_method("spawn_new_employee"):
			office = office_manager
	
	if office.has_method("spawn_new_employee"):
		office.spawn_new_employee(human_to_hire)
	else:
		print("КРИТИЧЕСКАЯ ОШИБКА: Не найден метод spawn_new_employee!")
	
	candidates[index] = null
	update_ui()

func find_node_by_name(root, target_name):
	if root.name == target_name: return root
	for child in root.get_children():
		var found = find_node_by_name(child, target_name)
		if found: return found
	return null
