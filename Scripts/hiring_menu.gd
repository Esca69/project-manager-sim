extends Control

@onready var card1 = %Card1
@onready var card2 = %Card2
@onready var card3 = %Card3

@onready var close_btn = find_child("CloseButton", true, false)

var generator_script = preload("res://Scripts/candidate_generator.gd").new()
var candidates = []

var _trait_containers: Array = []
var _level_containers: Array = []
var _extra_cards: Array = []
var _all_cards: Array = []

var _card_style_normal: StyleBoxFlat
var _card_style_hover: StyleBoxFlat

func _ready():
	visible = false

	if close_btn:
		close_btn.pressed.connect(_on_close_pressed)
		if UITheme: UITheme.apply_font(close_btn, "semibold")
	else:
		print("ОШИБКА: Не найдена кнопка CloseButton!")

	_card_style_normal = _make_card_style(false)
	_card_style_hover = _make_card_style(true)

	# Подключаем кнопки "Нанять" для 3 карточек из сцены
	var scene_cards = [card1, card2, card3]
	for i in range(scene_cards.size()):
		var card = scene_cards[i]
		if card == null:
			continue
		var btn = find_node_by_name(card, "HireButton")
		if btn:
			if not btn.is_connected("pressed", _on_hire_pressed):
				btn.pressed.connect(_on_hire_pressed.bind(i))
			if UITheme: UITheme.apply_font(btn, "semibold")

func _make_card_style(hover: bool) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_right = 20
	style.corner_radius_bottom_left = 20
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	if hover:
		style.bg_color = Color(0.96, 0.97, 1.0, 1)
		style.border_color = Color(0.17254902, 0.30980393, 0.5686275, 1)
	else:
		style.bg_color = Color(1, 1, 1, 1)
		style.border_color = Color(0.8784314, 0.8784314, 0.8784314, 1)
	if UITheme: UITheme.apply_shadow(style)
	return style

func _set_children_pass_filter(node: Node):
	for child in node.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_PASS
		_set_children_pass_filter(child)

# === ОТКРЫТИЕ С КОНКРЕТНОЙ РОЛЬЮ ===
func open_hiring_menu_for_role(role: String):
	generate_candidates_for_role(role)
	update_ui()
	if UITheme:
		UITheme.fade_in(self, 0.2)
	else:
		visible = true

func _on_close_pressed():
	if UITheme:
		UITheme.fade_out(self, 0.15)
	else:
		visible = false

# === ГЕНЕРАЦИЯ КАНДИДАТОВ ===
func generate_candidates_for_role(role: String):
	candidates.clear()
	var count = PMData.get_candidate_count()
	for i in range(count):
		var new_human = generator_script.generate_candidate_for_role(role)
		candidates.append(new_human)
	print("👤 Сгенерировано %d кандидатов" % count)

# === ОБНОВЛЕНИЕ UI ===
func update_ui():
	# Очищаем динамические элементы
	for tc in _trait_containers:
		if is_instance_valid(tc):
			tc.queue_free()
	_trait_containers.clear()

	for lc in _level_containers:
		if is_instance_valid(lc):
			lc.queue_free()
	_level_containers.clear()

	# Удаляем экстра-карточки от прошлого раза
	for ec in _extra_cards:
		if is_instance_valid(ec):
			ec.queue_free()
	_extra_cards.clear()

	# Собираем базовые карточки из сцены
	var scene_cards = [card1, card2, card3]
	_all_cards = []

	# Находим CardsContainer — родитель Card1
	var cards_container: VBoxContainer = null
	if card1:
		cards_container = card1.get_parent() as VBoxContainer

	var total = candidates.size()

	# === Заполняем 3 сценовые карточки ===
	for i in range(scene_cards.size()):
		var card = scene_cards[i]
		if card == null:
			continue

		if i >= total or candidates[i] == null:
			card.visible = false
			_all_cards.append(card)
			continue

		_fill_card(card, candidates[i], i)
		_all_cards.append(card)

	# === Создаём экстра-карточки для 4-го, 5-го и т.д. ===
	if total > 3 and cards_container != null:
		for i in range(3, total):
			if candidates[i] == null:
				continue
			var extra = _create_extra_card(candidates[i], i)
			cards_container.add_child(extra)
			_extra_cards.append(extra)
			_all_cards.append(extra)

# === ЗАПОЛНИТЬ КАРТОЧКУ ИЗ СЦЕНЫ ===
func _fill_card(card: Control, data: EmployeeData, _index: int):
	card.visible = true
	card.modulate = Color.WHITE
	var btn = find_node_by_name(card, "HireButton")
	if btn: 
		btn.disabled = false
		btn.text = tr("HIRE_BTN")

	var name_lbl = find_node_by_name(card, "NameLabel")
	var role_lbl = find_node_by_name(card, "RoleLabel")
	var salary_lbl = find_node_by_name(card, "SalaryLabel")
	var skill_lbl = find_node_by_name(card, "SkillLabel")
	var traits_lbl = find_node_by_name(card, "TraitsLabel")

	# Hover
	if card is PanelContainer:
		card.add_theme_stylebox_override("panel", _card_style_normal)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		if card.mouse_entered.is_connected(_on_card_hover_enter):
			card.mouse_entered.disconnect(_on_card_hover_enter)
		if card.mouse_exited.is_connected(_on_card_hover_exit):
			card.mouse_exited.disconnect(_on_card_hover_exit)
		card.mouse_entered.connect(_on_card_hover_enter.bind(card))
		card.mouse_exited.connect(_on_card_hover_exit.bind(card))

	if name_lbl:
		name_lbl.text = data.employee_name
		if UITheme: UITheme.apply_font(name_lbl, "bold")
	if role_lbl:
		role_lbl.text = tr(data.job_title)
		if UITheme: UITheme.apply_font(role_lbl, "semibold")
	if salary_lbl:
		salary_lbl.text = tr("UI_SALARY") % data.monthly_salary
		if UITheme: UITheme.apply_font(salary_lbl, "bold")

	var skill_text = ""
	if data.skill_business_analysis > 0:
		skill_text = tr("ROLE_SHORT_BA") + ": " + PMData.get_blurred_skill(data.skill_business_analysis)
	elif data.skill_backend > 0:
		skill_text = tr("ROLE_SHORT_DEV") + ": " + PMData.get_blurred_skill(data.skill_backend)
	elif data.skill_qa > 0:
		skill_text = tr("ROLE_SHORT_QA") + ": " + PMData.get_blurred_skill(data.skill_qa)

	if skill_lbl:
		skill_lbl.text = skill_text
		if UITheme: UITheme.apply_font(skill_lbl, "regular")

	if traits_lbl:
		traits_lbl.text = ""
		traits_lbl.visible = false

	var card_vbox = find_node_by_name(card, "CardVBox")
	if card_vbox:
		var level_row = _create_level_badge(data)
		card_vbox.add_child(level_row)
		_level_containers.append(level_row)

	if card_vbox and not data.traits.is_empty():
		_add_traits_to(card_vbox, data)

	call_deferred("_set_children_pass_filter", card)

# === ДОБАВИТЬ ТРЕЙТЫ ===
func _add_traits_to(card_vbox: VBoxContainer, data: EmployeeData):
	var visible_count = PMData.get_visible_traits_count()

	if visible_count >= data.traits.size():
		var traits_row = TraitUIHelper.create_traits_row(data, self)
		card_vbox.add_child(traits_row)
		_trait_containers.append(traits_row)
	else:
		var flow = HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 12)
		flow.add_theme_constant_override("v_separation", 4)

		for t_idx in range(data.traits.size()):
			if t_idx < visible_count:
				var trait_id = data.traits[t_idx]
				var item = _create_visible_trait(trait_id, data, self)
				flow.add_child(item)
			else:
				var item = _create_hidden_trait(self)
				flow.add_child(item)

		card_vbox.add_child(flow)
		_trait_containers.append(flow)

# === СОЗДАТЬ ЭКСТРА-КАРТОЧКУ (4-я, 5-я...) ===
func _create_extra_card(data: EmployeeData, index: int) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(1400, 0)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.add_theme_stylebox_override("panel", _card_style_normal)

	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_entered.connect(func():
		card.add_theme_stylebox_override("panel", _card_style_hover)
	)
	card.mouse_exited.connect(func():
		card.add_theme_stylebox_override("panel", _card_style_normal)
	)

	var inner_margin = MarginContainer.new()
	inner_margin.add_theme_constant_override("margin_left", 15)
	inner_margin.add_theme_constant_override("margin_top", 15)
	inner_margin.add_theme_constant_override("margin_right", 15)
	inner_margin.add_theme_constant_override("margin_bottom", 15)
	card.add_child(inner_margin)

	var card_vbox = VBoxContainer.new()
	card_vbox.name = "CardVBox"
	card_vbox.add_theme_constant_override("separation", 10)
	inner_margin.add_child(card_vbox)

	var top_hbox = HBoxContainer.new()
	card_vbox.add_child(top_hbox)

	var left_info = VBoxContainer.new()
	top_hbox.add_child(left_info)

	var name_lbl = Label.new()
	name_lbl.text = data.employee_name
	name_lbl.add_theme_color_override("font_color", Color(0.17254902, 0.30980393, 0.5686275, 1))
	if UITheme: UITheme.apply_font(name_lbl, "bold")
	left_info.add_child(name_lbl)

	var role_lbl = Label.new()
	role_lbl.text = tr(data.job_title)
	role_lbl.add_theme_color_override("font_color", Color(0.17254902, 0.30980393, 0.5686275, 1))
	if UITheme: UITheme.apply_font(role_lbl, "semibold")
	left_info.add_child(role_lbl)

	var skill_text = ""
	if data.skill_business_analysis > 0:
		skill_text = tr("ROLE_SHORT_BA") + ": " + PMData.get_blurred_skill(data.skill_business_analysis)
	elif data.skill_backend > 0:
		skill_text = tr("ROLE_SHORT_DEV") + ": " + PMData.get_blurred_skill(data.skill_backend)
	elif data.skill_qa > 0:
		skill_text = tr("ROLE_SHORT_QA") + ": " + PMData.get_blurred_skill(data.skill_qa)

	var skill_lbl = Label.new()
	skill_lbl.text = skill_text
	skill_lbl.add_theme_color_override("font_color", Color(0.17254902, 0.30980393, 0.5686275, 1))
	if UITheme: UITheme.apply_font(skill_lbl, "regular")
	left_info.add_child(skill_lbl)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(spacer)

	var right_vbox = VBoxContainer.new()
	top_hbox.add_child(right_vbox)

	var salary_lbl = Label.new()
	salary_lbl.text = tr("UI_SALARY") % data.monthly_salary
	salary_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	salary_lbl.add_theme_color_override("font_color", Color(0.29803923, 0.6862745, 0.3137255, 1))
	salary_lbl.add_theme_font_size_override("font_size", 25)
	if UITheme: UITheme.apply_font(salary_lbl, "bold")
	right_vbox.add_child(salary_lbl)

	var hire_btn = Button.new()
	hire_btn.text = tr("HIRE_BTN")
	hire_btn.custom_minimum_size = Vector2(180, 40)
	hire_btn.focus_mode = Control.FOCUS_NONE
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(1, 1, 1, 1)
	btn_style.border_width_left = 2
	btn_style.border_width_top = 2
	btn_style.border_width_right = 2
	btn_style.border_width_bottom = 2
	btn_style.border_color = Color(0.17254902, 0.30980393, 0.5686275, 1)
	btn_style.corner_radius_top_left = 20
	btn_style.corner_radius_top_right = 20
	btn_style.corner_radius_bottom_right = 20
	btn_style.corner_radius_bottom_left = 20
	hire_btn.add_theme_stylebox_override("normal", btn_style)
	hire_btn.add_theme_color_override("font_color", Color(0.17254902, 0.30980393, 0.5686275, 1))
	if UITheme: UITheme.apply_font(hire_btn, "semibold")
	hire_btn.pressed.connect(_on_hire_pressed.bind(index))
	right_vbox.add_child(hire_btn)

	var sep = HSeparator.new()
	card_vbox.add_child(sep)

	# Бейдж уровня
	var level_row = _create_level_badge(data)
	card_vbox.add_child(level_row)
	_level_containers.append(level_row)

	# Трейты
	if not data.traits.is_empty():
		_add_traits_to(card_vbox, data)

	call_deferred("_set_children_pass_filter", card)
	return card

# === БЕЙДЖ УРОВНЯ ===
func _create_level_badge(data: EmployeeData) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	var grade_panel = PanelContainer.new()
	var grade_style = StyleBoxFlat.new()
	grade_style.corner_radius_top_left = 10
	grade_style.corner_radius_top_right = 10
	grade_style.corner_radius_bottom_right = 10
	grade_style.corner_radius_bottom_left = 10

	var grade = data.get_grade_name()
	# ИСПРАВЛЕНИЕ: Проверяем по уровню, чтобы не зависеть от перевода слова "Junior"
	match data.employee_level:
		0, 1, 2: # Junior
			grade_style.bg_color = Color(0.9, 0.95, 0.9, 1)
			grade_style.border_color = Color(0.29, 0.69, 0.31, 1)
		3, 4: # Middle
			grade_style.bg_color = Color(0.93, 0.93, 1.0, 1)
			grade_style.border_color = Color(0.17254902, 0.30980393, 0.5686275, 1)
		5, 6: # Senior
			grade_style.bg_color = Color(1.0, 0.95, 0.88, 1)
			grade_style.border_color = Color(0.85, 0.55, 0.0, 1)
		7, 8, 9, 10: # Lead
			grade_style.bg_color = Color(0.95, 0.9, 0.98, 1)
			grade_style.border_color = Color(0.6, 0.3, 0.7, 1)

	grade_style.border_width_left = 2
	grade_style.border_width_top = 2
	grade_style.border_width_right = 2
	grade_style.border_width_bottom = 2
	grade_panel.add_theme_stylebox_override("panel", grade_style)

	var grade_margin = MarginContainer.new()
	grade_margin.add_theme_constant_override("margin_left", 8)
	grade_margin.add_theme_constant_override("margin_top", 2)
	grade_margin.add_theme_constant_override("margin_right", 8)
	grade_margin.add_theme_constant_override("margin_bottom", 2)
	grade_panel.add_child(grade_margin)

	var grade_lbl = Label.new()
	grade_lbl.text = tr("ROSTER_GRADE_LEVEL") % [grade, data.employee_level]
	grade_lbl.add_theme_font_size_override("font_size", 12)
	
	match data.employee_level:
		0, 1, 2: grade_lbl.add_theme_color_override("font_color", Color(0.29, 0.69, 0.31, 1))
		3, 4: grade_lbl.add_theme_color_override("font_color", Color(0.17254902, 0.30980393, 0.5686275, 1))
		5, 6: grade_lbl.add_theme_color_override("font_color", Color(0.85, 0.55, 0.0, 1))
		7, 8, 9, 10: grade_lbl.add_theme_color_override("font_color", Color(0.6, 0.3, 0.7, 1))
		
	if UITheme: UITheme.apply_font(grade_lbl, "semibold")
	grade_margin.add_child(grade_lbl)

	hbox.add_child(grade_panel)
	return hbox

func _on_card_hover_enter(card: PanelContainer):
	card.add_theme_stylebox_override("panel", _card_style_hover)

func _on_card_hover_exit(card: PanelContainer):
	card.add_theme_stylebox_override("panel", _card_style_normal)

func _create_visible_trait(trait_id: String, emp: EmployeeData, parent: Control) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)

	var color = Color(0.8980392, 0.22352941, 0.20784314, 1)
	if emp.is_positive_trait(trait_id):
		color = Color(0.29803923, 0.6862745, 0.3137255, 1)

	var name_text = EmployeeData.TRAIT_NAMES.get(trait_id, trait_id)
	var lbl = Label.new()
	lbl.text = tr(name_text)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 13)
	if UITheme: UITheme.apply_font(lbl, "regular")
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

func _create_hidden_trait(parent: Control) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)

	var lbl = Label.new()
	lbl.text = "???"
	lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
	lbl.add_theme_font_size_override("font_size", 13)
	if UITheme: UITheme.apply_font(lbl, "regular")
	hbox.add_child(lbl)

	var help_btn = Button.new()
	help_btn.text = "?"
	help_btn.custom_minimum_size = Vector2(22, 22)
	help_btn.focus_mode = Control.FOCUS_NONE
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

	var tooltip_ref: Array = [null]
	var gray_color = Color(0.5, 0.5, 0.5, 1)

	help_btn.mouse_entered.connect(func():
		if tooltip_ref[0] != null and is_instance_valid(tooltip_ref[0]):
			tooltip_ref[0].queue_free()
		var tp = TraitUIHelper._create_tooltip(tr("ROSTER_HIDDEN_TRAIT_TOOLTIP"), gray_color)
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

func _on_hire_pressed(index):
	if index >= candidates.size():
		return
	var human_to_hire = candidates[index]
	if human_to_hire == null: return

	print("Нанимаем: ", human_to_hire.employee_name)

		# Ищем офис по группе — надёжнее чем current_scene
	var office = get_tree().get_first_node_in_group("office")
	
	if not office:
		office = get_tree().current_scene

	if office and office.has_method("spawn_new_employee"):
		office.spawn_new_employee(human_to_hire)
	else:
		print("КРИТИЧЕСКАЯ ОШИБКА: Не найден метод spawn_new_employee!")
		print("  current_scene = ", get_tree().current_scene)
		print("  office group = ", get_tree().get_first_node_in_group("office"))

	PMData.add_xp(5)
	print("🎯 PM +5 XP за найм сотрудника")

	var bm = get_node_or_null("/root/BossManager")
	if bm:
		bm.track_hire()

	candidates[index] = null

	# Анимация исчезновения
	if index < _all_cards.size():
		var card = _all_cards[index]
		if is_instance_valid(card):
			var tw = card.create_tween()
			tw.tween_property(card, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
			tw.tween_callback(func():
				card.visible = false
				card.modulate.a = 1.0
			)

func find_node_by_name(root, target_name):
	if root.name == target_name: return root
	for child in root.get_children():
		var found = find_node_by_name(child, target_name)
		if found: return found
	return null
