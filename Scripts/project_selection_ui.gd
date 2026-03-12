extends Control

signal project_selected(data: ProjectData)

@onready var close_btn = find_child("CloseButton", true, false)
@onready var cards_margin = $Window/MainVBox/CardsMargin

var current_options = []
var _generated_for_week: int = -1

var _card_style_normal: StyleBoxFlat
var _card_style_hover: StyleBoxFlat
var _btn_style: StyleBoxFlat
var _btn_style_hover: StyleBoxFlat
var _btn_style_disabled: StyleBoxFlat

var _scroll: ScrollContainer
var _cards_container: VBoxContainer
var _scroll_ready: bool = false

var _overlay: ColorRect

# === TABS ===
var _active_tab: String = "projects"  # "projects" | "negotiations"
var _tab_projects_btn: Button
var _tab_nego_btn: Button
var _nego_container: VBoxContainer

func _ready():
	add_to_group("project_selection_ui")
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	z_index = 90
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_force_fullscreen_size()

	# === ДОБАВЛЯЕМ ЗАТЕМНЕНИЕ ФОНА (OVERLAY) ===
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.45)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)
	move_child(_overlay, 0) # Чётко кидаем на самый задний план, чтобы не блокировал окно

	_card_style_normal = _make_card_style(false)
	_card_style_hover = _make_card_style(true)

	_btn_style = StyleBoxFlat.new()
	_btn_style.bg_color = Color(1, 1, 1, 1)
	_btn_style.border_width_left = 2
	_btn_style.border_width_top = 2
	_btn_style.border_width_right = 2
	_btn_style.border_width_bottom = 2
	_btn_style.border_color = Color(0.17254902, 0.30980393, 0.5686275, 1)
	_btn_style.corner_radius_top_left = 20
	_btn_style.corner_radius_top_right = 20
	_btn_style.corner_radius_bottom_right = 20
	_btn_style.corner_radius_bottom_left = 20

	_btn_style_hover = StyleBoxFlat.new()
	_btn_style_hover.bg_color = Color(0.17254902, 0.30980393, 0.5686275, 1)
	_btn_style_hover.border_width_left = 2
	_btn_style_hover.border_width_top = 2
	_btn_style_hover.border_width_right = 2
	_btn_style_hover.border_width_bottom = 2
	_btn_style_hover.border_color = Color(0.17254902, 0.30980393, 0.5686275, 1)
	_btn_style_hover.corner_radius_top_left = 20
	_btn_style_hover.corner_radius_top_right = 20
	_btn_style_hover.corner_radius_bottom_right = 20
	_btn_style_hover.corner_radius_bottom_left = 20

	_btn_style_disabled = StyleBoxFlat.new()
	_btn_style_disabled.bg_color = Color(0.95, 0.95, 0.95, 1)
	_btn_style_disabled.border_width_left = 2
	_btn_style_disabled.border_width_top = 2
	_btn_style_disabled.border_width_right = 2
	_btn_style_disabled.border_width_bottom = 2
	_btn_style_disabled.border_color = Color(0.8, 0.8, 0.8, 1)
	_btn_style_disabled.corner_radius_top_left = 20
	_btn_style_disabled.corner_radius_top_right = 20
	_btn_style_disabled.corner_radius_bottom_right = 20
	_btn_style_disabled.corner_radius_bottom_left = 20

	if close_btn:
		close_btn.pressed.connect(_on_close_pressed)
		if UITheme: UITheme.apply_font(close_btn, "semibold")

	_setup_scroll_container()

func _force_fullscreen_size():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var vp_size = get_viewport().get_visible_rect().size
	position = Vector2.ZERO
	size = vp_size

func _setup_scroll_container():
	if cards_margin == null:
		push_error("project_selection_ui: cards_margin is null!")
		return

	cards_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL

	for child in cards_margin.get_children():
		child.queue_free()

	await get_tree().process_frame

	# === TAB BUTTONS ===
	var tab_bar = HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 8)
	cards_margin.add_child(tab_bar)

	_tab_projects_btn = _make_tab_button(tr("TAB_PROJECTS"), true)
	_tab_projects_btn.pressed.connect(_on_tab_projects)
	tab_bar.add_child(_tab_projects_btn)

	_tab_nego_btn = _make_tab_button(tr("TAB_NEGOTIATIONS"), false)
	_tab_nego_btn.pressed.connect(_on_tab_negotiations)
	tab_bar.add_child(_tab_nego_btn)

	# === PROJECTS SCROLL ===
	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.clip_contents = true
	cards_margin.add_child(_scroll)

	_cards_container = VBoxContainer.new()
	_cards_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cards_container.add_theme_constant_override("separation", 15)
	_scroll.add_child(_cards_container)

	# === NEGOTIATIONS SCROLL ===
	var nego_scroll = ScrollContainer.new()
	nego_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nego_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nego_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	nego_scroll.clip_contents = true
	nego_scroll.visible = false
	cards_margin.add_child(nego_scroll)

	_nego_container = VBoxContainer.new()
	_nego_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_nego_container.add_theme_constant_override("separation", 12)
	nego_scroll.add_child(_nego_container)

	_scroll_ready = true

func _make_tab_button(label: String, active: bool) -> Button:
	var btn = Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(200, 38)
	btn.focus_mode = Control.FOCUS_NONE
	btn.toggle_mode = false
	_apply_tab_style(btn, active)
	if UITheme: UITheme.apply_font(btn, "semibold")
	return btn

func _apply_tab_style(btn: Button, active: bool):
	var style_active = StyleBoxFlat.new()
	style_active.bg_color = Color(0.17254902, 0.30980393, 0.5686275, 1)
	style_active.corner_radius_top_left = 10
	style_active.corner_radius_top_right = 10
	style_active.corner_radius_bottom_right = 10
	style_active.corner_radius_bottom_left = 10

	var style_inactive = StyleBoxFlat.new()
	style_inactive.bg_color = Color(1, 1, 1, 1)
	style_inactive.border_width_left = 2
	style_inactive.border_width_top = 2
	style_inactive.border_width_right = 2
	style_inactive.border_width_bottom = 2
	style_inactive.border_color = Color(0.17254902, 0.30980393, 0.5686275, 1)
	style_inactive.corner_radius_top_left = 10
	style_inactive.corner_radius_top_right = 10
	style_inactive.corner_radius_bottom_right = 10
	style_inactive.corner_radius_bottom_left = 10

	if active:
		btn.add_theme_stylebox_override("normal", style_active)
		btn.add_theme_stylebox_override("hover", style_active)
		btn.add_theme_stylebox_override("pressed", style_active)
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
		btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	else:
		btn.add_theme_stylebox_override("normal", style_inactive)
		btn.add_theme_stylebox_override("hover", style_active)
		btn.add_theme_stylebox_override("pressed", style_active)
		btn.add_theme_color_override("font_color", Color(0.17254902, 0.30980393, 0.5686275, 1))
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
		btn.add_theme_color_override("font_pressed_color", Color.WHITE)

func _on_tab_projects():
	_active_tab = "projects"
	if _tab_projects_btn: _apply_tab_style(_tab_projects_btn, true)
	if _tab_nego_btn: _apply_tab_style(_tab_nego_btn, false)
	if _scroll: _scroll.visible = true
	if _nego_container and _nego_container.get_parent():
		_nego_container.get_parent().visible = false
	_rebuild_cards()

func _on_tab_negotiations():
	_active_tab = "negotiations"
	if _tab_projects_btn: _apply_tab_style(_tab_projects_btn, false)
	if _tab_nego_btn: _apply_tab_style(_tab_nego_btn, true)
	if _scroll: _scroll.visible = false
	if _nego_container and _nego_container.get_parent():
		_nego_container.get_parent().visible = true
	_rebuild_negotiations()

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

func open_selection():
	if get_parent():
		get_parent().move_child(self, -1)

	_force_fullscreen_size()

	if not _scroll_ready:
		await get_tree().process_frame
		await get_tree().process_frame
		if not _scroll_ready:
			push_error("project_selection_ui: scroll всё ещё не готов!")
			return

	var current_week = _get_current_week()

	if current_week != _generated_for_week:
		generate_new_projects()
		_generated_for_week = current_week

	# Всегда открываемся на вкладке проектов
	_on_tab_projects()

	if UITheme:
		UITheme.fade_in(self, 0.2)
	else:
		visible = true

func _on_close_pressed():
	if UITheme:
		UITheme.fade_out(self, 0.15)
	else:
		visible = false

func _get_current_week() -> int:
	return ((GameTime.day - 1) / GameTime.DAYS_IN_WEEK) + 1

func generate_new_projects():
	current_options.clear()
	var count = 4
	if ClientManager.has_method("get_weekly_project_count"):
		count = ClientManager.get_weekly_project_count()
	for i in range(count):
		var proj = ProjectGenerator.generate_random_project(GameTime.day)
		current_options.append(proj)

# === ПРОВЕРКИ ОГРАНИЧЕНИЙ ===

func _is_project_limit_reached() -> bool:
	return not ProjectManager.can_take_more()

func _is_too_late_for_boss() -> bool:
	return GameTime.hour >= PMData.get_boss_cutoff_hour()

# === ПЕРЕСТРОЙКА КАРТОЧЕК ===
func _rebuild_cards():
	if _cards_container == null:
		push_error("project_selection_ui: _cards_container is null в _rebuild_cards!")
		return

	for child in _cards_container.get_children():
		_cards_container.remove_child(child)
		child.queue_free()

	# --- Плашка лимита проектов ---
	if _is_project_limit_reached():
		var limit_bar = _create_warning_bar(
			tr("PROJ_SEL_LIMIT_TITLE") % [ProjectManager.count_active_projects(), PMData.get_max_projects()],
			tr("PROJ_SEL_LIMIT_HINT"),
			Color(0.9, 0.5, 0.1, 1)
		)
		_cards_container.add_child(limit_bar)

	# --- Плашка "босс ушёл" ---
	if _is_too_late_for_boss():
		var cutoff = PMData.get_boss_cutoff_hour()
		var time_bar = _create_warning_bar(
			tr("PROJ_SEL_TIME_TITLE") % cutoff,
			tr("PROJ_SEL_TIME_HINT"),
			Color(0.7, 0.2, 0.2, 1)
		)
		_cards_container.add_child(time_bar)

	var has_any = false
	for i in range(current_options.size()):
		if current_options[i] == null:
			continue
		has_any = true
		var card = _create_card(current_options[i], i)
		_cards_container.add_child(card)

	if not has_any:
		var empty_lbl = Label.new()
		empty_lbl.text = tr("PROJ_SEL_WEEK_DONE")
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if UITheme: UITheme.apply_font(empty_lbl, "semibold")
		_cards_container.add_child(empty_lbl)

	if _scroll:
		_scroll.scroll_vertical = 0

# === ПЛАШКА ПРЕДУПРЕЖДЕНИЯ ===
func _create_warning_bar(title_text: String, hint_text: String, color: Color) -> PanelContainer:
	var bar = PanelContainer.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bar_style = StyleBoxFlat.new()
	bar_style.bg_color = Color(color.r, color.g, color.b, 0.12)
	bar_style.border_width_left = 2
	bar_style.border_width_top = 2
	bar_style.border_width_right = 2
	bar_style.border_width_bottom = 2
	bar_style.border_color = color
	bar_style.corner_radius_top_left = 12
	bar_style.corner_radius_top_right = 12
	bar_style.corner_radius_bottom_right = 12
	bar_style.corner_radius_bottom_left = 12
	bar.add_theme_stylebox_override("panel", bar_style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_bottom", 10)
	bar.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	margin.add_child(vbox)

	var title_lbl = Label.new()
	title_lbl.text = title_text
	title_lbl.add_theme_color_override("font_color", color)
	if UITheme: UITheme.apply_font(title_lbl, "bold")
	vbox.add_child(title_lbl)

	var hint_lbl = Label.new()
	hint_lbl.text = hint_text
	hint_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
	hint_lbl.add_theme_font_size_override("font_size", 13)
	if UITheme: UITheme.apply_font(hint_lbl, "regular")
	vbox.add_child(hint_lbl)

	return bar

# === СОЗДАНИЕ КАРТОЧКИ ===
func _create_card(data: ProjectData, index: int) -> PanelContainer:
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _card_style_normal)

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
	card_vbox.add_theme_constant_override("separation", 5)
	margin.add_child(card_vbox)

	var top_hbox = HBoxContainer.new()
	card_vbox.add_child(top_hbox)

	var left_info = VBoxContainer.new()
	top_hbox.add_child(left_info)

	var cat_label = data.get_category_label()

	var client_text = ""
	if data.client_id != "":
		var client = data.get_client()
		if client:
			# ИСПРАВЛЕНИЕ: Используем get_display_name() клиента (эмодзи уже внутри)
			client_text = client.get_display_name() + "  —  "

	var name_lbl = Label.new()
	# ИСПРАВЛЕНИЕ: Используем get_display_title()
	name_lbl.text = client_text + cat_label + " " + data.get_display_title()
	name_lbl.add_theme_color_override("font_color", Color(0.17254902, 0.30980393, 0.5686275, 1))
	if UITheme: UITheme.apply_font(name_lbl, "bold")
	left_info.add_child(name_lbl)

	var work_lbl = Label.new()
	var parts = []
	for stage in data.stages:
		parts.append(tr("ROLE_SHORT_" + stage.type) + " " + PMData.get_blurred_work(stage.amount))
	work_lbl.text = tr("PROJ_SEL_WORK_LABEL") + "  " + "    ".join(parts)
	work_lbl.add_theme_color_override("font_color", Color(0.17254902, 0.30980393, 0.5686275, 1))
	if UITheme: UITheme.apply_font(work_lbl, "regular")
	left_info.add_child(work_lbl)

	# Метка "Обсуждение занимает N часов"
	var boss_hours = PMData.get_boss_meeting_hours()
	var time_lbl = Label.new()
	time_lbl.text = tr("PROJ_SEL_BOSS_MEETING") % boss_hours
	time_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55, 1))
	time_lbl.add_theme_font_size_override("font_size", 13)
	if UITheme: UITheme.apply_font(time_lbl, "regular")
	left_info.add_child(time_lbl)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(spacer)

	var right_info = VBoxContainer.new()
	top_hbox.add_child(right_info)

	var budget_lbl = Label.new()
	var budget_text = tr("PROJ_SEL_BUDGET_LABEL") % PMData.get_blurred_budget(data.budget)
	if data.client_id != "":
		var client = data.get_client()
		if client and client.get_budget_bonus_percent() > 0:
			budget_text += "  (❤+%d%%)" % client.get_budget_bonus_percent()
	budget_lbl.text = budget_text
	budget_lbl.add_theme_color_override("font_color", Color(0.29803923, 0.6862745, 0.3137255, 1))
	budget_lbl.add_theme_font_size_override("font_size", 20)
	budget_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if UITheme: UITheme.apply_font(budget_lbl, "bold")
	right_info.add_child(budget_lbl)

	var is_limit = _is_project_limit_reached()
	var is_late = _is_too_late_for_boss()
	var btn_blocked = is_limit or is_late

	var select_btn = Button.new()
	if is_limit:
		select_btn.text = tr("PROJ_SEL_BTN_LIMIT")
	elif is_late:
		select_btn.text = tr("PROJ_SEL_BTN_LATE")
	else:
		select_btn.text = tr("PROJ_SEL_BTN_SELECT")
		
	select_btn.custom_minimum_size = Vector2(180, 40)
	select_btn.disabled = btn_blocked

	if btn_blocked:
		select_btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
		select_btn.add_theme_stylebox_override("normal", _btn_style_disabled)
		select_btn.add_theme_stylebox_override("disabled", _btn_style_disabled)
	else:
		select_btn.add_theme_color_override("font_color", Color(0.17254902, 0.30980393, 0.5686275, 1))
		select_btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
		select_btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
		select_btn.add_theme_stylebox_override("normal", _btn_style)
		select_btn.add_theme_stylebox_override("hover", _btn_style_hover)
		select_btn.add_theme_stylebox_override("pressed", _btn_style_hover)
		select_btn.pressed.connect(_on_select_pressed.bind(index))

	if UITheme: UITheme.apply_font(select_btn, "semibold")
	right_info.add_child(select_btn)

	var deadlines_hbox = HBoxContainer.new()
	deadlines_hbox.add_theme_constant_override("separation", 40)
	card_vbox.add_child(deadlines_hbox)

	var soft_lbl = Label.new()
	soft_lbl.text = tr("PROJ_SEL_SOFT_DAYS") % [data.soft_days_budget, data.soft_deadline_penalty_percent]
	soft_lbl.add_theme_color_override("font_color", Color(1.0, 0.55, 0.0, 1))
	if UITheme: UITheme.apply_font(soft_lbl, "regular")
	deadlines_hbox.add_child(soft_lbl)

	var hard_lbl = Label.new()
	hard_lbl.text = tr("PROJ_SEL_HARD_DAYS") % data.hard_days_budget
	hard_lbl.add_theme_color_override("font_color", Color(0.8980392, 0.22352941, 0.20784314, 1))
	if UITheme: UITheme.apply_font(hard_lbl, "semibold")
	deadlines_hbox.add_child(hard_lbl)

	call_deferred("_set_children_pass_filter", card)

	return card

func _on_select_pressed(index: int):
	if index < 0 or index >= current_options.size():
		return
	var selected = current_options[index]
	if selected == null:
		return

	if _is_project_limit_reached():
		return
	if _is_too_late_for_boss():
		return

	# ИСПРАВЛЕНИЕ: Берем локализованное имя для логов
	print("⏱ Начинаем обсуждение проекта: ", selected.get_display_title())

	current_options[index] = null
	_on_close_pressed()

	emit_signal("project_selected", selected)

# === ОБРАБОТКА ВВОДА (ESC) ===
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and visible:
		_on_close_pressed()
		get_viewport().set_input_as_handled()

# ============================================================
#              ВКЛАДКА ПЕРЕГОВОРЫ
# ============================================================

func _rebuild_negotiations():
	if _nego_container == null:
		return
	for child in _nego_container.get_children():
		child.queue_free()

	# Заголовок — текущее доверие
	var trust_lbl = Label.new()
	trust_lbl.text = tr("NEGO_TRUST") % BossManager.boss_trust
	trust_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	trust_lbl.add_theme_color_override("font_color", Color(0.85, 0.55, 0.0, 1))
	trust_lbl.add_theme_font_size_override("font_size", 18)
	if UITheme: UITheme.apply_font(trust_lbl, "bold")
	_nego_container.add_child(trust_lbl)

	# === ЗАГОЛОВОК: Повышение ЗП ===
	var salary_header = _make_section_header(tr("NEGO_SECTION_SALARY"))
	_nego_container.add_child(salary_header)

	# Карточки повышения ЗП
	var raises = [
		{"label_key": "NEGO_RAISE_5", "desc_key": "NEGO_RAISE_5_DESC", "cost": 10, "mult": 1.05},
		{"label_key": "NEGO_RAISE_10", "desc_key": "NEGO_RAISE_10_DESC", "cost": 17, "mult": 1.10},
		{"label_key": "NEGO_RAISE_15", "desc_key": "NEGO_RAISE_15_DESC", "cost": 25, "mult": 1.15},
	]
	for r in raises:
		var card = _make_nego_card(
			tr(r["label_key"]),
			tr(r["desc_key"]),
			r["cost"],
			true,  # повторяемый
			func():
				PMData.monthly_salary = int(PMData.monthly_salary * r["mult"])
				BossManager.change_trust(-r["cost"])
				EventLog.add(tr("LOG_PM_RAISE") % PMData.monthly_salary)
				_rebuild_negotiations()
		)
		_nego_container.add_child(card)

	# === ЗАГОЛОВОК: Партнёрство ===
	var partner_section = _make_section_header(tr("NEGO_SECTION_PARTNERSHIP"))
	_nego_container.add_child(partner_section)

	# Карточки партнёрства
	var partner_items = [
		{"label_key": "NEGO_PARTNER_1", "desc_key": "NEGO_PARTNER_1_DESC", "cost": 30, "required_tier": 0, "result_tier": 1},
		{"label_key": "NEGO_PARTNER_2", "desc_key": "NEGO_PARTNER_2_DESC", "cost": 50, "required_tier": 1, "result_tier": 2},
		{"label_key": "NEGO_PARTNER_3", "desc_key": "NEGO_PARTNER_3_DESC", "cost": 80, "required_tier": 2, "result_tier": 3},
	]
	for p in partner_items:
		var is_purchased = PMData.partner_tier >= p["result_tier"]
		var is_available = PMData.partner_tier == p["required_tier"]
		var is_locked = PMData.partner_tier < p["required_tier"]

		if is_purchased:
			var card = _make_nego_card_purchased(tr(p["label_key"]), tr(p["desc_key"]))
			_nego_container.add_child(card)
		elif is_locked:
			var card = _make_nego_card_locked(tr(p["label_key"]), tr(p["desc_key"]))
			_nego_container.add_child(card)
		else:
			var result_tier = p["result_tier"]
			var card = _make_nego_card(
				tr(p["label_key"]),
				tr(p["desc_key"]),
				p["cost"],
				false,
				func():
					PMData.partner_tier = result_tier
					BossManager.change_trust(-p["cost"])
					EventLog.add(tr("LOG_PM_PARTNER_UP") % PMData.get_partner_name())
					_rebuild_negotiations()
			)
			_nego_container.add_child(card)

func _make_section_header(text: String) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", Color(0.17254902, 0.30980393, 0.5686275, 1))
	lbl.add_theme_font_size_override("font_size", 14)
	if UITheme: UITheme.apply_font(lbl, "bold")
	return lbl

func _make_nego_card(title: String, desc: String, cost: int, repeatable: bool, on_buy: Callable) -> PanelContainer:
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(1, 1, 1, 1)
	card_style.border_width_left = 2
	card_style.border_width_top = 2
	card_style.border_width_right = 2
	card_style.border_width_bottom = 2
	card_style.border_color = Color(0.8784314, 0.8784314, 0.8784314, 1)
	card_style.corner_radius_top_left = 14
	card_style.corner_radius_top_right = 14
	card_style.corner_radius_bottom_right = 14
	card_style.corner_radius_bottom_left = 14
	if UITheme: UITheme.apply_shadow(card_style)
	card.add_theme_stylebox_override("panel", card_style)

	var m = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 16)
	m.add_theme_constant_override("margin_top", 12)
	m.add_theme_constant_override("margin_right", 16)
	m.add_theme_constant_override("margin_bottom", 12)
	card.add_child(m)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	m.add_child(hbox)

	# Левая часть — текст
	var left_vbox = VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(left_vbox)

	var title_lbl = Label.new()
	title_lbl.text = title
	title_lbl.add_theme_color_override("font_color", Color(0.17254902, 0.30980393, 0.5686275, 1))
	title_lbl.add_theme_font_size_override("font_size", 15)
	if UITheme: UITheme.apply_font(title_lbl, "bold")
	left_vbox.add_child(title_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = desc
	desc_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
	desc_lbl.add_theme_font_size_override("font_size", 13)
	if UITheme: UITheme.apply_font(desc_lbl, "regular")
	left_vbox.add_child(desc_lbl)

	var cost_lbl = Label.new()
	cost_lbl.text = tr("NEGO_COST") % cost
	cost_lbl.add_theme_color_override("font_color", Color(0.85, 0.55, 0.0, 1))
	cost_lbl.add_theme_font_size_override("font_size", 13)
	if UITheme: UITheme.apply_font(cost_lbl, "semibold")
	left_vbox.add_child(cost_lbl)

	# Правая часть — кнопка
	var can_afford = BossManager.boss_trust >= cost

	var buy_btn = Button.new()
	buy_btn.custom_minimum_size = Vector2(130, 40)
	buy_btn.focus_mode = Control.FOCUS_NONE
	buy_btn.disabled = not can_afford

	if can_afford:
		var btn_style_n = StyleBoxFlat.new()
		btn_style_n.bg_color = Color(0.29803923, 0.6862745, 0.3137255, 1)
		btn_style_n.corner_radius_top_left = 10
		btn_style_n.corner_radius_top_right = 10
		btn_style_n.corner_radius_bottom_right = 10
		btn_style_n.corner_radius_bottom_left = 10

		buy_btn.text = tr("PROJ_SEL_BTN_SELECT") if repeatable else "🤝 Deal"
		buy_btn.add_theme_stylebox_override("normal", btn_style_n)
		buy_btn.add_theme_stylebox_override("hover", btn_style_n)
		buy_btn.add_theme_color_override("font_color", Color.WHITE)
		buy_btn.add_theme_color_override("font_hover_color", Color.WHITE)
		buy_btn.pressed.connect(on_buy)
	else:
		var btn_style_dis = StyleBoxFlat.new()
		btn_style_dis.bg_color = Color(0.9, 0.9, 0.9, 1)
		btn_style_dis.corner_radius_top_left = 10
		btn_style_dis.corner_radius_top_right = 10
		btn_style_dis.corner_radius_bottom_right = 10
		btn_style_dis.corner_radius_bottom_left = 10

		buy_btn.text = tr("NEGO_NOT_ENOUGH")
		buy_btn.add_theme_stylebox_override("normal", btn_style_dis)
		buy_btn.add_theme_stylebox_override("disabled", btn_style_dis)
		buy_btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))

	if UITheme: UITheme.apply_font(buy_btn, "semibold")
	hbox.add_child(buy_btn)

	return card

func _make_nego_card_purchased(title: String, desc: String) -> PanelContainer:
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.93, 0.98, 0.93, 1)
	card_style.border_width_left = 2
	card_style.border_width_top = 2
	card_style.border_width_right = 2
	card_style.border_width_bottom = 2
	card_style.border_color = Color(0.29803923, 0.6862745, 0.3137255, 0.5)
	card_style.corner_radius_top_left = 14
	card_style.corner_radius_top_right = 14
	card_style.corner_radius_bottom_right = 14
	card_style.corner_radius_bottom_left = 14
	card.add_theme_stylebox_override("panel", card_style)

	var m = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 16)
	m.add_theme_constant_override("margin_top", 12)
	m.add_theme_constant_override("margin_right", 16)
	m.add_theme_constant_override("margin_bottom", 12)
	card.add_child(m)

	var hbox = HBoxContainer.new()
	m.add_child(hbox)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 3)
	hbox.add_child(vbox)

	var t_lbl = Label.new()
	t_lbl.text = title
	t_lbl.add_theme_color_override("font_color", Color(0.2, 0.6, 0.2, 1))
	t_lbl.add_theme_font_size_override("font_size", 14)
	if UITheme: UITheme.apply_font(t_lbl, "bold")
	vbox.add_child(t_lbl)

	var d_lbl = Label.new()
	d_lbl.text = desc
	d_lbl.add_theme_color_override("font_color", Color(0.4, 0.5, 0.4, 1))
	d_lbl.add_theme_font_size_override("font_size", 12)
	if UITheme: UITheme.apply_font(d_lbl, "regular")
	vbox.add_child(d_lbl)

	var status_lbl = Label.new()
	status_lbl.text = tr("NEGO_PURCHASED")
	status_lbl.add_theme_color_override("font_color", Color(0.2, 0.7, 0.2, 1))
	status_lbl.add_theme_font_size_override("font_size", 13)
	if UITheme: UITheme.apply_font(status_lbl, "semibold")
	hbox.add_child(status_lbl)

	return card

func _make_nego_card_locked(title: String, desc: String) -> PanelContainer:
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.96, 0.96, 0.96, 1)
	card_style.border_width_left = 2
	card_style.border_width_top = 2
	card_style.border_width_right = 2
	card_style.border_width_bottom = 2
	card_style.border_color = Color(0.8, 0.8, 0.8, 1)
	card_style.corner_radius_top_left = 14
	card_style.corner_radius_top_right = 14
	card_style.corner_radius_bottom_right = 14
	card_style.corner_radius_bottom_left = 14
	card.add_theme_stylebox_override("panel", card_style)

	var m = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 16)
	m.add_theme_constant_override("margin_top", 12)
	m.add_theme_constant_override("margin_right", 16)
	m.add_theme_constant_override("margin_bottom", 12)
	card.add_child(m)

	var hbox = HBoxContainer.new()
	m.add_child(hbox)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 3)
	hbox.add_child(vbox)

	var t_lbl = Label.new()
	t_lbl.text = title
	t_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
	t_lbl.add_theme_font_size_override("font_size", 14)
	if UITheme: UITheme.apply_font(t_lbl, "bold")
	vbox.add_child(t_lbl)

	var d_lbl = Label.new()
	d_lbl.text = desc
	d_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	d_lbl.add_theme_font_size_override("font_size", 12)
	if UITheme: UITheme.apply_font(d_lbl, "regular")
	vbox.add_child(d_lbl)

	var locked_lbl = Label.new()
	locked_lbl.text = tr("NEGO_LOCKED")
	locked_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
	locked_lbl.add_theme_font_size_override("font_size", 12)
	if UITheme: UITheme.apply_font(locked_lbl, "regular")
	hbox.add_child(locked_lbl)

	return card
