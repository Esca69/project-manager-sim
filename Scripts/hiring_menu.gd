extends Control

# Старые карточки из сцены — скрываем, используем динамические
@onready var card1 = %Card1
@onready var card2 = %Card2
@onready var card3 = %Card3

@onready var close_btn = find_child("CloseButton", true, false)

var generator_script = preload("res://Scripts/candidate_generator.gd").new()
var candidates = []

var _trait_containers: Array = []
var _level_containers: Array = []
var _dynamic_cards: Array = []

var _card_style_normal: StyleBoxFlat
var _card_style_hover: StyleBoxFlat

# Контейнер для динамических карточек
var _scroll: ScrollContainer
var _cards_container: VBoxContainer
var _cards_parent: Control  # Родитель, куда вставим ScrollContainer

func _ready():
	visible = false

	if close_btn:
		close_btn.pressed.connect(_on_close_pressed)
		if UITheme: UITheme.apply_font(close_btn, "semibold")
	else:
		print("ОШИБКА: Не найдена кнопка CloseButton!")

	_card_style_normal = _make_card_style(false)
	_card_style_hover = _make_card_style(true)

	# Скрываем старые захардкоженные карточки из сцены
	if card1: card1.visible = false
	if card2: card2.visible = false
	if card3: card3.visible = false

	# Находим родителя карточек и создаём динамический контейнер
	call_deferred("_setup_dynamic_container")

func _setup_dynamic_container():
	# Ищем контейнер, в котором лежали старые карточки
	_cards_parent = null
	if card1:
		_cards_parent = card1.get_parent()

	if _cards_parent == null:
		# Фоллбэк: ищем CardsMargin или подобный контейнер
		var window = find_child("Window", true, false)
		if window:
			var main_vbox = window.get_node_or_null("MainVBox")
			if main_vbox:
				for child in main_vbox.get_children():
					if child is MarginContainer:
						_cards_parent = child
						break
				if _cards_parent == null:
					_cards_parent = main_vbox

	if _cards_parent == null:
		push_error("hiring_menu: не найден родитель для карточек!")
		return

	# Создаём ScrollContainer + VBoxContainer для динамических карточек
	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.clip_contents = true

	_cards_container = VBoxContainer.new()
	_cards_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cards_container.add_theme_constant_override("separation", 15)

	_scroll.add_child(_cards_container)
	_cards_parent.add_child(_scroll)

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

# === ГЕНЕРАЦИЯ КАНДИДАТОВ — ДИНАМИЧЕСКОЕ КОЛИЧЕСТВО ===
func generate_candidates_for_role(role: String):
	candidates.clear()
	var count = PMData.get_candidate_count()
	for i in range(count):
		var new_human = generator_script.generate_candidate_for_role(role)
		candidates.append(new_human)
	print("👤 Сгенерировано %d кандидатов (навык: %d)" % [count, count])

# === ОБНОВЛЕНИЕ UI — ДИНАМИЧЕСКИЕ КАРТОЧКИ ===
func update_ui():
	# Очищаем старые динамические элементы
	for tc in _trait_containers:
		if is_instance_valid(tc):
			tc.queue_free()
	_trait_containers.clear()

	for lc in _level_containers:
		if is_instance_valid(lc):
			lc.queue_free()
	_level_containers.clear()

	# Удаляем старые динамические карточки
	for dc in _dynamic_cards:
		if is_instance_valid(dc):
			dc.queue_free()
	_dynamic_cards.clear()

	# Скрываем старые карточки из сцены (на всякий случай)
	if card1: card1.visible = false
	if card2: card2.visible = false
	if card3: card3.visible = false

	if _cards_container == null:
		push_error("hiring_menu: _cards_container is null в update_ui!")
		return

	# Генерируем динамические карточки
	for i in range(candidates.size()):
		var data = candidates[i]
		if data == null:
			continue

		var card = _create_candidate_card(data, i)
		_cards_container.add_child(card)
		_dynamic_cards.append(card)

	if _scroll:
		_scroll.scroll_vertical = 0

# === СОЗДАНИЕ КАРТОЧКИ КАНДИДАТА (ПРОГРАММНО) ===
func _create_candidate_card(data: EmployeeData, index: int) -> PanelContainer:
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _card_style_normal)

	# Hover
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_entered.connect(func():
		card.add_theme_stylebox_override("panel", _card_style_hover)
	)
	card.mouse_exited.connect(func():
		card.add_theme_stylebox_override("panel", _card_style_normal)
	)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	card.add_child(margin)

	var card_vbox = VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 6)
	margin.add_child(card_vbox)

	# === ИМЯ ===
	var name_lbl = Label.new()
	name_lbl.text = data.employee_name
	name_lbl.add_theme_color_override("font_color", Color(0.17254902, 0.30980393, 0.5686275, 1))
	name_lbl.add_theme_font_size_override("font_size", 18)
	if UITheme: UITheme.apply_font(name_lbl, "bold")
	card_vbox.add_child(name_lbl)

	# === РОЛЬ ===
	var role_lbl = Label.new()
	role_lbl.text = data.job_title
	role_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 1))
	role_lbl.add_theme_font_size_override("font_size", 14)
	if UITheme: UITheme.apply_font(role_lbl, "semibold")
	card_vbox.add_child(role_lbl)

	# === БЕЙДЖ УРОВНЯ ===
	var level_row = _create_level_badge(data)
	card_vbox.add_child(level_row)
	_level_containers.append(level_row)

	# === НАВЫКИ (размытие через PMData) ===
	var skill_text = ""
	if data.skill_business_analysis > 0:
		skill_text = "BA: " + PMData.get_blurred_skill(data.skill_business_analysis)
	elif data.skill_backend > 0:
		skill_text = "Backend: " + PMData.get_blurred_skill(data.skill_backend)
	elif data.skill_qa > 0:
		skill_text = "QA: " + PMData.get_blurred_skill(data.skill_qa)

	var skill_lbl = Label.new()
	skill_lbl.text = skill_text
	skill_lbl.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2, 1))
	skill_lbl.add_theme_font_size_override("font_size", 14)
	if UITheme: UITheme.apply_font(skill_lbl, "regular")
	card_vbox.add_child(skill_lbl)

	# === ТРЕЙТЫ ===
	if not data.traits.is_empty():
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

	# === НИЖНЯЯ СТРОКА: ЗАРПЛАТА + КНОПКА ===
	var bottom_hbox = HBoxContainer.new()
	bottom_hbox.add_theme_constant_override("separation", 10)
	card_vbox.add_child(bottom_hbox)

	var salary_lbl = Label.new()
	salary_lbl.text = "💰 $%d / мес." % data.monthly_salary
	salary_lbl.add_theme_color_override("font_color", Color(0.29803923, 0.6862745, 0.3137255, 1))
	salary_lbl.add_theme_font_size_override("font_size", 16)
	salary_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if UITheme: UITheme.apply_font(salary_lbl, "bold")
	bottom_hbox.add_child(salary_lbl)

	var hire_btn = Button.new()
	hire_btn.text = "Нанять"
	hire_btn.custom_minimum_size = Vector2(140, 38)
	hire_btn.focus_mode = Control.FOCUS_NONE

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(1, 1, 1, 1)
	btn_style.border_width_left = 2
	btn_style.border_width_top = 2
	btn_style.border_width_right = 2
	btn_style.border_width_bottom = 2
	btn_style.border_color = Color(0.29803923, 0.6862745, 0.3137255, 1)
	btn_style.corner_radius_top_left = 16
	btn_style.corner_radius_top_right = 16
	btn_style.corner_radius_bottom_right = 16
	btn_style.corner_radius_bottom_left = 16

	var btn_style_hover = btn_style.duplicate()
	btn_style_hover.bg_color = Color(0.29803923, 0.6862745, 0.3137255, 1)

	hire_btn.add_theme_stylebox_override("normal", btn_style)
	hire_btn.add_theme_stylebox_override("hover", btn_style_hover)
	hire_btn.add_theme_stylebox_override("pressed", btn_style_hover)
	hire_btn.add_theme_color_override("font_color", Color(0.29803923, 0.6862745, 0.3137255, 1))
	hire_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	hire_btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	hire_btn.add_theme_font_size_override("font_size", 14)
	if UITheme: UITheme.apply_font(hire_btn, "semibold")

	hire_btn.pressed.connect(_on_hire_pressed.bind(index))
	bottom_hbox.add_child(hire_btn)

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
	match grade:
		"Junior":
			grade_style.bg_color = Color(0.9, 0.95, 0.9, 1)
			grade_style.border_color = Color(0.29, 0.69, 0.31, 1)
		"Middle":
			grade_style.bg_color = Color(0.93, 0.93, 1.0, 1)
			grade_style.border_color = Color(0.17254902, 0.30980393, 0.5686275, 1)
		"Senior":
			grade_style.bg_color = Color(1.0, 0.95, 0.88, 1)
			grade_style.border_color = Color(0.85, 0.55, 0.0, 1)
		"Lead":
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
	grade_lbl.text = "%s  Ур. %d" % [grade, data.employee_level]
	grade_lbl.add_theme_font_size_override("font_size", 12)
	match grade:
		"Junior": grade_lbl.add_theme_color_override("font_color", Color(0.29, 0.69, 0.31, 1))
		"Middle": grade_lbl.add_theme_color_override("font_color", Color(0.17254902, 0.30980393, 0.5686275, 1))
		"Senior": grade_lbl.add_theme_color_override("font_color", Color(0.85, 0.55, 0.0, 1))
		"Lead": grade_lbl.add_theme_color_override("font_color", Color(0.6, 0.3, 0.7, 1))
	if UITheme: UITheme.apply_font(grade_lbl, "semibold")
	grade_margin.add_child(grade_lbl)

	hbox.add_child(grade_panel)
	return hbox

func _create_visible_trait(trait_id: String, emp: EmployeeData, parent: Control) -> HBoxContainer:
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
		var tp = TraitUIHelper._create_tooltip("Неизвестное качество сотрудника.\nИзучите навык «Чтение людей» в дереве навыков PM.", gray_color)
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

	var office = get_tree().current_scene

	if not office.has_method("spawn_new_employee"):
		var office_manager = get_tree().get_first_node_in_group("office_manager")
		if office_manager and office_manager.has_method("spawn_new_employee"):
			office = office_manager

	if office.has_method("spawn_new_employee"):
		office.spawn_new_employee(human_to_hire)
	else:
		print("КРИТИЧЕСКАЯ ОШИБКА: Не найден метод spawn_new_employee!")

	PMData.add_xp(5)
	print("🎯 PM +5 XP за найм сотрудника")

	# === Трекинг найма для BossManager ===
	var bm = get_node_or_null("/root/BossManager")
	if bm:
		bm.track_hire()

	candidates[index] = null

	# Анимация исчезновения карточки
	if index < _dynamic_cards.size():
		var card = _dynamic_cards[index]
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
