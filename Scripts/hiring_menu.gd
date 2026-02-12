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
			
			# === ТРЕЙТЫ — показываем всегда, но скрытые = заглушки ===
			var card_vbox = find_node_by_name(card, "CardVBox")
			if card_vbox and not data.traits.is_empty():
				var visible_count = PMData.get_visible_traits_count()
				
				if visible_count >= data.traits.size():
					# Все видно — показываем как есть
					var traits_row = TraitUIHelper.create_traits_row(data, self)
					card_vbox.add_child(traits_row)
					_trait_containers.append(traits_row)
				else:
					# Часть или все скрыты — создаём смешанную строку
					var flow = HFlowContainer.new()
					flow.add_theme_constant_override("h_separation", 12)
					flow.add_theme_constant_override("v_separation", 4)
					
					for t_idx in range(data.traits.size()):
						if t_idx < visible_count:
							# Видимый трейт — настоящее имя + кнопка ?
							var trait_id = data.traits[t_idx]
							var item = _create_visible_trait(trait_id, data, self)
							flow.add_child(item)
						else:
							# Скрытый трейт — заглушка "???"
							var item = _create_hidden_trait()
							flow.add_child(item)
					
					card_vbox.add_child(flow)
					_trait_containers.append(flow)
				
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

# Создаёт видимый трейт (настоящее имя + кнопка ?)
func _create_visible_trait(trait_id: String, emp: EmployeeData, parent: Control) -> HBoxContainer:
	# Используем TraitUIHelper напрямую для одного трейта
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	
	var color = Color(0.8980392, 0.22352941, 0.20784314, 1)
	if emp.is_positive_trait(trait_id):
		color = Color(0.29803923, 0.6862745, 0.3137255, 1)
	
	var name_text = EmployeeData.TRAIT_NAMES.get(trait_id, trait_id)
	var lbl = Label.new()
	lbl.text = name_text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 13)
	hbox.add_child(lbl)
	
	var help_btn = Button.new()
	help_btn.text = "?"
	help_btn.custom_minimum_size = Vector2(22, 22)
	help_btn.focus_mode = Control.FOCUS_NONE
	help_btn.add_theme_font_size_override("font_size", 11)
	help_btn.add_theme_color_override("font_color", Color(0.17254902, 0.30980393, 0.5686275, 1))
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(1, 1, 1, 1)
	btn_style.border_width_left = 2
	btn_style.border_width_top = 2
	btn_style.border_width_right = 2
	btn_style.border_width_bottom = 2
	btn_style.border_color = Color(0.17254902, 0.30980393, 0.5686275, 1)
	btn_style.corner_radius_top_left = 11
	btn_style.corner_radius_top_right = 11
	btn_style.corner_radius_bottom_right = 11
	btn_style.corner_radius_bottom_left = 11
	help_btn.add_theme_stylebox_override("normal", btn_style)
	
	var description = emp.get_trait_description(trait_id)
	var tooltip_ref: Array = [null]
	
	help_btn.mouse_entered.connect(func():
		if tooltip_ref[0] != null and is_instance_valid(tooltip_ref[0]):
			tooltip_ref[0].queue_free()
		var tp = TraitUIHelper._create_tooltip(description, color)
		parent.add_child(tp)
		var btn_global = help_btn.global_position
		tp.global_position = Vector2(btn_global.x + 28, btn_global.y - 10)
		tooltip_ref[0] = tp
	)
	
	help_btn.mouse_exited.connect(func():
		if tooltip_ref[0] != null and is_instance_valid(tooltip_ref[0]):
			tooltip_ref[0].queue_free()
		tooltip_ref[0] = null
	)
	
	hbox.add_child(help_btn)
	return hbox

# Создаёт скрытый трейт — заглушку "???"
func _create_hidden_trait() -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	
	var lbl = Label.new()
	lbl.text = "???"
	lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
	lbl.add_theme_font_size_override("font_size", 13)
	hbox.add_child(lbl)
	
	var help_btn = Button.new()
	help_btn.text = "?"
	help_btn.custom_minimum_size = Vector2(22, 22)
	help_btn.focus_mode = Control.FOCUS_NONE
	help_btn.disabled = true
	help_btn.add_theme_font_size_override("font_size", 11)
	help_btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.93, 0.93, 0.93, 1)
	btn_style.border_width_left = 2
	btn_style.border_width_top = 2
	btn_style.border_width_right = 2
	btn_style.border_width_bottom = 2
	btn_style.border_color = Color(0.7, 0.7, 0.7, 1)
	btn_style.corner_radius_top_left = 11
	btn_style.corner_radius_top_right = 11
	btn_style.corner_radius_bottom_right = 11
	btn_style.corner_radius_bottom_left = 11
	help_btn.add_theme_stylebox_override("normal", btn_style)
	help_btn.add_theme_stylebox_override("disabled", btn_style)
	
	hbox.add_child(help_btn)
	return hbox

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
	
	# XP за найм
	PMData.add_xp(5)
	print("🎯 PM +5 XP за найм сотрудника")
	
	candidates[index] = null
	update_ui()

func find_node_by_name(root, target_name):
	if root.name == target_name: return root
	for child in root.get_children():
		var found = find_node_by_name(child, target_name)
		if found: return found
	return null
