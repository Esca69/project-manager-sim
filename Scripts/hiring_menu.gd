extends Control

@onready var card1 = %Card1
@onready var card2 = %Card2
@onready var card3 = %Card3

@onready var close_btn = find_child("CloseButton", true, false)
@onready var title_label = $Window/MainVBox/HeaderPanel/TitleLabel # <--- Добавь эту строку

var generator_script = preload("res://Scripts/candidate_generator.gd").new()
var candidates = []

var _trait_containers: Array = []
var _level_containers: Array = []
var _extra_cards: Array = []
var _all_cards: Array = []

var _card_style_normal: StyleBoxFlat
var _card_style_hover: StyleBoxFlat

var _btn_style_normal: StyleBoxFlat
var _btn_style_hover: StyleBoxFlat

const COLOR_BLUE = Color(0.17254902, 0.30980393, 0.5686275, 1)
const COLOR_WHITE = Color(1, 1, 1, 1)

# === ДОБАВЛЕНО ДЛЯ ФОНА ===
var _overlay: ColorRect

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	z_index = 90
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_force_fullscreen_size()

	# === ДОБАВЛЯЕМ ЗАТЕМНЕНИЕ ФОНА ===
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.45)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)
	move_child(_overlay, 0) # Строго на самый задний план, чтобы не блокировал клики!

	if close_btn:
		close_btn.pressed.connect(_on_close_pressed)
		if UITheme: UITheme.apply_font(close_btn, "semibold")
	else:
		print("ОШИБКА: Не найдена кнопка CloseButton!")
	
	if title_label:
		title_label.text = tr("TITLE_HIRING_MENU") # <--- Добавь это

	_card_style_normal = _make_card_style(false)
	_card_style_hover = _make_card_style(true)
	
	# === СОЗДАЕМ КРАСИВЫЕ СТИЛИ ДЛЯ КНОПОК ===
	_btn_style_normal = StyleBoxFlat.new()
	_btn_style_normal.bg_color = COLOR_WHITE
	_btn_style_normal.border_width_left = 2
	_btn_style_normal.border_width_top = 2
	_btn_style_normal.border_width_right = 2
	_btn_style_normal.border_width_bottom = 2
	_btn_style_normal.border_color = COLOR_BLUE
	_btn_style_normal.corner_radius_top_left = 20
	_btn_style_normal.corner_radius_top_right = 20
	_btn_style_normal.corner_radius_bottom_right = 20
	_btn_style_normal.corner_radius_bottom_left = 20

	_btn_style_hover = StyleBoxFlat.new()
	_btn_style_hover.bg_color = COLOR_BLUE
	_btn_style_hover.border_width_left = 2
	_btn_style_hover.border_width_top = 2
	_btn_style_hover.border_width_right = 2
	_btn_style_hover.border_width_bottom = 2
	_btn_style_hover.border_color = COLOR_BLUE
	_btn_style_hover.corner_radius_top_left = 20
	_btn_style_hover.corner_radius_top_right = 20
	_btn_style_hover.corner_radius_bottom_right = 20
	_btn_style_hover.corner_radius_bottom_left = 20

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

func _force_fullscreen_size():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var vp_size = get_viewport().get_visible_rect().size
	position = Vector2.ZERO
	size = vp_size

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
			if child.tooltip_text == "":
				child.mouse_filter = Control.MOUSE_FILTER_PASS
			else:
				child.mouse_filter = Control.MOUSE_FILTER_STOP
		_set_children_pass_filter(child)

# === ОТКРЫТИЕ С КОНКРЕТНОЙ РОЛЬЮ ===
func open_hiring_menu_for_role(role: String):
	_force_fullscreen_size()
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
		
		# --- ПРИМЕНЯЕМ КРАСИВЫЙ СИНИЙ СТИЛЬ ---
		btn.add_theme_stylebox_override("normal", _btn_style_normal)
		btn.add_theme_stylebox_override("hover", _btn_style_hover)
		btn.add_theme_stylebox_override("pressed", _btn_style_hover)
		btn.add_theme_color_override("font_color", COLOR_BLUE)
		btn.add_theme_color_override("font_hover_color", COLOR_WHITE)
		btn.add_theme_color_override("font_pressed_color", COLOR_WHITE)

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
		var type_badge = _create_employment_type_badge(data)
		level_row.add_child(type_badge)

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
	name_lbl.add_theme_color_override("font_color", COLOR_BLUE)
	if UITheme: UITheme.apply_font(name_lbl, "bold")
	left_info.add_child(name_lbl)

	var role_lbl = Label.new()
	role_lbl.text = tr(data.job_title)
	role_lbl.add_theme_color_override("font_color", COLOR_BLUE)
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
	skill_lbl.add_theme_color_override("font_color", COLOR_BLUE)
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
	
	# --- ПРИМЕНЯЕМ КРАСИВЫЙ СИНИЙ СТИЛЬ ---
	hire_btn.add_theme_stylebox_override("normal", _btn_style_normal)
	hire_btn.add_theme_stylebox_override("hover", _btn_style_hover)
	hire_btn.add_theme_stylebox_override("pressed", _btn_style_hover)
	hire_btn.add_theme_color_override("font_color", COLOR_BLUE)
	hire_btn.add_theme_color_override("font_hover_color", COLOR_WHITE)
	hire_btn.add_theme_color_override("font_pressed_color", COLOR_WHITE)
	
	if UITheme: UITheme.apply_font(hire_btn, "semibold")
	hire_btn.pressed.connect(_on_hire_pressed.bind(index))
	right_vbox.add_child(hire_btn)

	var sep = HSeparator.new()
	card_vbox.add_child(sep)

	# Бейдж уровня
	var level_row = _create_level_badge(data)
	card_vbox.add_child(level_row)
	_level_containers.append(level_row)
	var type_badge = _create_employment_type_badge(data)
	level_row.add_child(type_badge)

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
	match data.employee_level:
		0, 1, 2: # Junior
			grade_style.bg_color = Color(0.9, 0.95, 0.9, 1)
			grade_style.border_color = Color(0.29, 0.69, 0.31, 1)
		3, 4: # Middle
			grade_style.bg_color = Color(0.93, 0.93, 1.0, 1)
			grade_style.border_color = COLOR_BLUE
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
		3, 4: grade_lbl.add_theme_color_override("font_color", COLOR_BLUE)
		5, 6: grade_lbl.add_theme_color_override("font_color", Color(0.85, 0.55, 0.0, 1))
		7, 8, 9, 10: grade_lbl.add_theme_color_override("font_color", Color(0.6, 0.3, 0.7, 1))
		
	if UITheme: UITheme.apply_font(grade_lbl, "semibold")
	grade_margin.add_child(grade_lbl)

	hbox.add_child(grade_panel)
	return hbox

# === ЧИП ТИПА ЗАНЯТОСТИ ===
# === ЧИП ТИПА ЗАНЯТОСТИ ===
func _create_employment_type_badge(data: EmployeeData) -> PanelContainer:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2

	var lbl_text = ""
	var text_color: Color
	var tooltip_description = ""
	var tooltip_color: Color

	if data.employment_type == "freelancer":
		style.bg_color = Color(1.0, 0.95, 0.88, 1)
		style.border_color = Color(0.9, 0.55, 0.2, 1)
		text_color = Color(0.9, 0.55, 0.2, 1)
		tooltip_color = Color(0.9, 0.55, 0.2, 1)
		lbl_text = tr("EMPLOYMENT_TYPE_FREELANCER")
		tooltip_description = tr("TOOLTIP_FREELANCER")
	else:
		style.bg_color = Color(0.9, 0.93, 1.0, 1)
		style.border_color = Color(0.17254902, 0.30980393, 0.5686275, 1)
		text_color = Color(0.17254902, 0.30980393, 0.5686275, 1)
		tooltip_color = Color(0.17254902, 0.30980393, 0.5686275, 1)
		lbl_text = tr("EMPLOYMENT_TYPE_CONTRACTOR")
		var sev_min = int(data.monthly_salary * EmployeeData.SEVERANCE_MIN_MULTIPLIER)
		var sev_max = int(data.monthly_salary * EmployeeData.SEVERANCE_MAX_MULTIPLIER)
		tooltip_description = tr("TOOLTIP_CONTRACTOR") % [sev_min, sev_max]

	panel.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 2)
	panel.add_child(margin)

	var lbl = Label.new()
	lbl.text = lbl_text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", text_color)
	if UITheme: UITheme.apply_font(lbl, "semibold")
	margin.add_child(lbl)

	# === КАСТОМНЫЙ ТУЛТИП (как у кнопки "?") ===
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	lbl.mouse_filter = Control.MOUSE_FILTER_PASS

	var tooltip_ref: Array = [null]

	panel.mouse_entered.connect(func():
		if tooltip_ref[0] != null and is_instance_valid(tooltip_ref[0]):
			tooltip_ref[0].queue_free()
		var tp = TraitUIHelper._create_tooltip(tooltip_description, tooltip_color)
		self.add_child(tp)
		var panel_global = panel.global_position
		tp.global_position = Vector2(panel_global.x + panel.size.x + 10, panel_global.y - 5)
		tooltip_ref[0] = tp
	)

	panel.mouse_exited.connect(func():
		if tooltip_ref[0] != null and is_instance_valid(tooltip_ref[0]):
			tooltip_ref[0].queue_free()
		tooltip_ref[0] = null
	)

	return panel

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
	help_btn.add_theme_color_override("font_color", COLOR_BLUE)

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = COLOR_WHITE
	btn_style.border_width_left = 2
	btn_style.border_width_top = 2
	btn_style.border_width_right = 2
	btn_style.border_width_bottom = 2
	btn_style.border_color = COLOR_BLUE
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
		print("🔴 [HIRE] index %d >= candidates.size() %d — ОТМЕНА" % [index, candidates.size()])
		return
	var human_to_hire = candidates[index]
	if human_to_hire == null:
		print("🔴 [HIRE] candidates[%d] == null — уже нанят" % index)
		return

	print("🟡 [HIRE] Нанимаем: ", human_to_hire.employee_name)

	# === ДИАГНОСТИКА: Дерево сцен ===
	print("🟡 [HIRE] current_scene = ", get_tree().current_scene)
	print("🟡 [HIRE] current_scene name = ", get_tree().current_scene.name if get_tree().current_scene else "NULL")
	
	# Ищем офис по группе
	var office = get_tree().get_first_node_in_group("office")
	print("🟡 [HIRE] office (по группе 'office') = ", office)
	
	# Дополнительно: выведем ВСЕ ноды в группе office
	var all_offices = get_tree().get_nodes_in_group("office")
	print("🟡 [HIRE] Все ноды в группе 'office': ", all_offices)
	
	if not office:
		office = get_tree().current_scene
		print("🟡 [HIRE] Фоллбек на current_scene: ", office)

	if office and office.has_method("spawn_new_employee"):
		print("🟢 [HIRE] Вызываю spawn_new_employee на: ", office)
		office.spawn_new_employee(human_to_hire)
	else:
		print("🔴 [HIRE] КРИТИЧЕСКАЯ ОШИБКА: Не найден метод spawn_new_employee!")
		if office:
			print("🔴 [HIRE]   office = ", office, " | script = ", office.get_script())
			print("🔴 [HIRE]   has spawn_new_employee: ", office.has_method("spawn_new_employee"))
		else:
			print("🔴 [HIRE]   office = NULL")
		
		# АВАРИЙНЫЙ ПОИСК: ищем по всему дереву ноду со скриптом office
		print("🔴 [HIRE] Пробуем аварийный поиск по дереву...")
		var root = get_tree().root
		var found = _find_node_with_method(root, "spawn_new_employee")
		if found:
			print("🟢 [HIRE] НАЙДЕНО аварийно: ", found, " | Путь: ", found.get_path())
			found.spawn_new_employee(human_to_hire)
		else:
			print("🔴 [HIRE] Нода со spawn_new_employee НЕ НАЙДЕНА нигде в дереве!")
			return

	PMData.add_xp(5)
	print("🎯 PM +5 XP за найм сотрудника")

	var bm = get_node_or_null("/root/BossManager")
	if bm:
		bm.track_hire()

	# Лог найма
	if EventLog:
		var type_text = tr("EMPLOYMENT_TYPE_FREELANCER") if human_to_hire.employment_type == "freelancer" else tr("EMPLOYMENT_TYPE_CONTRACTOR")
		EventLog.add(tr("LOG_HIRE_EMPLOYEE") % [type_text, human_to_hire.employee_name, human_to_hire.job_title, human_to_hire.monthly_salary])

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

# === АВАРИЙНЫЙ ПОИСК НОДЫ С МЕТОДОМ ===
func _find_node_with_method(node: Node, method_name: String) -> Node:
	if node.has_method(method_name):
		return node
	for child in node.get_children():
		var found = _find_node_with_method(child, method_name)
		if found:
			return found
	return null

func find_node_by_name(root, target_name):
	if root.name == target_name: return root
	for child in root.get_children():
		var found = find_node_by_name(child, target_name)
		if found: return found
	return null

# === ОБРАБОТКА ВВОДА (ESC) ===
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and visible:
		_on_close_pressed()
		get_viewport().set_input_as_handled()
