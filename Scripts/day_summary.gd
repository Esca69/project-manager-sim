extends Control

# === ЦВЕТА (из проекта) ===
const COLOR_BLUE = Color(0.17254902, 0.30980393, 0.5686275, 1)
const COLOR_GREEN = Color(0.29803923, 0.6862745, 0.3137255, 1)
const COLOR_RED = Color(0.8980392, 0.22352941, 0.20784314, 1)
const COLOR_ORANGE = Color(1.0, 0.55, 0.0, 1)
const COLOR_GRAY = Color(0.5, 0.5, 0.5, 1)
const COLOR_DARK = Color(0.2, 0.2, 0.2, 1)
const COLOR_WHITE = Color(1, 1, 1, 1)
const COLOR_BORDER = Color(0.8784314, 0.8784314, 0.8784314, 1)
const COLOR_WINDOW_BORDER = Color(0, 0, 0, 1)
const COLOR_LOCKED_BG = Color(0.94, 0.94, 0.94, 1)

# === НОДЫ ===
var _overlay: ColorRect
var _scroll: ScrollContainer
var _content_vbox: VBoxContainer
var _continue_btn: Button

# Пауза
var _was_paused_before: bool = false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	z_index = 100
	_build_ui()

func open():
	_was_paused_before = get_tree().paused
	get_tree().paused = true
	_populate()
	visible = true

func _close():
	visible = false
	if not _was_paused_before:
		get_tree().paused = false
	GameTime.start_night_skip()

# === ПОСТРОЕНИЕ КАРКАСА UI ===
func _build_ui():
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.5)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var window = PanelContainer.new()
	window.custom_minimum_size = Vector2(900, 700)
	var window_style = StyleBoxFlat.new()
	window_style.bg_color = COLOR_WHITE
	window_style.border_width_left = 3
	window_style.border_width_top = 3
	window_style.border_width_right = 3
	window_style.border_width_bottom = 3
	window_style.border_color = COLOR_WINDOW_BORDER
	window_style.corner_radius_top_left = 22
	window_style.corner_radius_top_right = 22
	window_style.corner_radius_bottom_right = 20
	window_style.corner_radius_bottom_left = 20
	window.add_theme_stylebox_override("panel", window_style)
	center.add_child(window)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 0)
	window.add_child(main_vbox)

	var header_panel = Panel.new()
	header_panel.custom_minimum_size = Vector2(0, 45)
	var header_style = StyleBoxFlat.new()
	header_style.bg_color = COLOR_BLUE
	header_style.border_color = COLOR_WINDOW_BORDER
	header_style.corner_radius_top_left = 20
	header_style.corner_radius_top_right = 20
	header_panel.add_theme_stylebox_override("panel", header_style)
	main_vbox.add_child(header_panel)

	var title_label = Label.new()
	title_label.text = "Итоги дня"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.set_anchors_preset(Control.PRESET_CENTER)
	title_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	title_label.add_theme_color_override("font_color", COLOR_WHITE)
	title_label.add_theme_font_size_override("font_size", 16)
	header_panel.add_child(title_label)

	var content_margin = MarginContainer.new()
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_left", 20)
	content_margin.add_theme_constant_override("margin_top", 15)
	content_margin.add_theme_constant_override("margin_right", 20)
	content_margin.add_theme_constant_override("margin_bottom", 15)
	main_vbox.add_child(content_margin)

	var inner_vbox = VBoxContainer.new()
	inner_vbox.add_theme_constant_override("separation", 10)
	content_margin.add_child(inner_vbox)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inner_vbox.add_child(_scroll)

	_content_vbox = VBoxContainer.new()
	_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_vbox.add_theme_constant_override("separation", 12)
	_scroll.add_child(_content_vbox)

	var btn_margin = MarginContainer.new()
	btn_margin.add_theme_constant_override("margin_top", 5)
	btn_margin.add_theme_constant_override("margin_bottom", 5)
	inner_vbox.add_child(btn_margin)

	var btn_center = CenterContainer.new()
	btn_margin.add_child(btn_center)

	_continue_btn = Button.new()
	_continue_btn.text = "Продолжить →"
	_continue_btn.custom_minimum_size = Vector2(250, 40)
	_continue_btn.focus_mode = Control.FOCUS_NONE

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = COLOR_WHITE
	btn_style.border_width_left = 2
	btn_style.border_width_top = 2
	btn_style.border_width_right = 2
	btn_style.border_width_bottom = 2
	btn_style.border_color = COLOR_BLUE
	btn_style.corner_radius_top_left = 20
	btn_style.corner_radius_top_right = 20
	btn_style.corner_radius_bottom_right = 20
	btn_style.corner_radius_bottom_left = 20
	_continue_btn.add_theme_stylebox_override("normal", btn_style)

	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = COLOR_BLUE
	btn_hover.border_width_left = 2
	btn_hover.border_width_top = 2
	btn_hover.border_width_right = 2
	btn_hover.border_width_bottom = 2
	btn_hover.border_color = COLOR_BLUE
	btn_hover.corner_radius_top_left = 20
	btn_hover.corner_radius_top_right = 20
	btn_hover.corner_radius_bottom_right = 20
	btn_hover.corner_radius_bottom_left = 20
	_continue_btn.add_theme_stylebox_override("hover", btn_hover)
	_continue_btn.add_theme_stylebox_override("pressed", btn_hover)

	_continue_btn.add_theme_color_override("font_color", COLOR_BLUE)
	_continue_btn.add_theme_color_override("font_hover_color", COLOR_WHITE)
	_continue_btn.add_theme_color_override("font_pressed_color", COLOR_WHITE)
	_continue_btn.add_theme_font_size_override("font_size", 15)
	_continue_btn.pressed.connect(_close)
	btn_center.add_child(_continue_btn)

# === НАПОЛНЕНИЕ ДАННЫМИ ===
func _populate():
	for child in _content_vbox.get_children():
		child.queue_free()
	_build_date_label()
	_build_separator()
	_build_finance_section()
	_build_separator()
	_build_projects_section()
	_build_separator()
	_build_employees_section()

# === ДАТА ===
func _build_date_label():
	var lbl = Label.new()
	lbl.text = "📅 " + GameTime.get_date_string()
	lbl.add_theme_color_override("font_color", COLOR_BLUE)
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content_vbox.add_child(lbl)

func _build_separator():
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	_content_vbox.add_child(sep)

# === ЗАГЛУШКА 🔒 ===
func _add_locked_hint(skill_name: String):
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_LOCKED_BG
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.82, 0.82, 0.82, 1)
	panel.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var lbl = Label.new()
	lbl.text = "🔒 Изучите навык «%s» в дереве навыков PM, чтобы видеть детализацию" % skill_name
	lbl.add_theme_color_override("font_color", COLOR_GRAY)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	margin.add_child(lbl)

	_content_vbox.add_child(panel)

# === СЕКЦИЯ ФИНАНСОВ ===
func _build_finance_section():
	var section = _create_section_label("💰 Финансы")
	_content_vbox.add_child(section)

	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 5)
	_content_vbox.add_child(grid)

	var balance_start = GameState.balance_at_day_start
	var income = GameState.daily_income
	var expenses = GameState.daily_expenses
	var balance_end = GameState.company_balance

	_add_finance_row(grid, "Баланс на начало дня:", "$%d" % balance_start, COLOR_DARK)
	_add_finance_row(grid, "📈 Доходы за день:", "+$%d" % income, COLOR_GREEN)
	_add_finance_row(grid, "📉 Расходы за день:", "-$%d" % expenses, COLOR_RED)

	if PMData.can_see_expense_details():
		var salary_details = GameState.daily_salary_details
		if salary_details.size() > 0:
			var details_lbl = Label.new()
			details_lbl.text = "    Зарплаты:"
			details_lbl.add_theme_color_override("font_color", COLOR_GRAY)
			details_lbl.add_theme_font_size_override("font_size", 12)
			_content_vbox.add_child(details_lbl)
			for entry in salary_details:
				var emp_name: String = entry["name"]
				var amount: int = entry["amount"]
				var det_lbl = Label.new()
				det_lbl.text = "        • %s — $%d" % [emp_name, amount]
				det_lbl.add_theme_color_override("font_color", COLOR_GRAY)
				det_lbl.add_theme_font_size_override("font_size", 12)
				_content_vbox.add_child(det_lbl)
	else:
		if GameState.daily_expenses > 0:
			_add_locked_hint("Учёт расходов")

	var total_color = COLOR_GREEN if balance_end >= balance_start else COLOR_RED
	_add_finance_row(grid, "Баланс на конец дня:", "$%d" % balance_end, total_color, true)

func _add_finance_row(grid: GridContainer, label_text: String, value_text: String, value_color: Color, bold: bool = false):
	var lbl = Label.new()
	lbl.text = label_text
	lbl.add_theme_color_override("font_color", COLOR_DARK)
	lbl.add_theme_font_size_override("font_size", 15 if bold else 14)
	grid.add_child(lbl)

	var val = Label.new()
	val.text = value_text
	val.add_theme_color_override("font_color", value_color)
	val.add_theme_font_size_override("font_size", 16 if bold else 14)
	grid.add_child(val)

# === СЕКЦИЯ ПРОЕКТОВ ===
func _build_projects_section():
	var section = _create_section_label("📋 Проекты")
	_content_vbox.add_child(section)

	var has_analytics = PMData.can_see_project_analytics()
	var finished_today = GameState.projects_finished_today.duplicate()
	var failed_today = GameState.projects_failed_today.duplicate()

	if finished_today.size() > 0:
		var sub_label = _create_subsection_label("✅ Завершены сегодня:")
		_content_vbox.add_child(sub_label)
		for entry in finished_today:
			var proj: ProjectData = entry["project"]
			var payout: int = entry["payout"]
			var text: String
			if has_analytics:
				text = "[%s] %s — Выплата: $%d" % [proj.category.to_upper(), proj.title, payout]
				if payout < proj.budget:
					var penalty = proj.budget - payout
					text += " (⚠ штраф -$%d, просрочка софт)" % penalty
			else:
				text = "[%s] %s — завершён" % [proj.category.to_upper(), proj.title]
			var lbl = Label.new()
			lbl.text = text
			lbl.add_theme_color_override("font_color", COLOR_GREEN)
			lbl.add_theme_font_size_override("font_size", 13)
			_content_vbox.add_child(lbl)

	if failed_today.size() > 0:
		var sub_label = _create_subsection_label("❌ Пров��лены сегодня:")
		_content_vbox.add_child(sub_label)
		for proj in failed_today:
			var text: String
			if has_analytics:
				text = "[%s] %s — Хард-дедлайн истёк, выплата: $0" % [proj.category.to_upper(), proj.title]
			else:
				text = "[%s] %s — провален" % [proj.category.to_upper(), proj.title]
			var lbl = Label.new()
			lbl.text = text
			lbl.add_theme_color_override("font_color", COLOR_RED)
			lbl.add_theme_font_size_override("font_size", 13)
			_content_vbox.add_child(lbl)

	var in_progress = []
	var drafting = []
	for proj in ProjectManager.active_projects:
		if proj.state == ProjectData.State.IN_PROGRESS:
			in_progress.append(proj)
		elif proj.state == ProjectData.State.DRAFTING:
			drafting.append(proj)

	if in_progress.size() > 0:
		var sub_label = _create_subsection_label("🔧 В работе:")
		_content_vbox.add_child(sub_label)
		for proj in in_progress:
			var text: String
			if has_analytics:
				var stage_info = _get_current_stage_info(proj)
				var soft_days = proj.soft_deadline_day - GameTime.day
				var hard_days = proj.deadline_day - GameTime.day
				text = "[%s] %s — %s | софт: %d дн. | хард: %d дн." % [
					proj.category.to_upper(), proj.title, stage_info, soft_days, hard_days
				]
			else:
				text = "[%s] %s — в работе" % [proj.category.to_upper(), proj.title]

			var lbl = Label.new()
			lbl.text = text
			lbl.add_theme_font_size_override("font_size", 13)

			if has_analytics:
				var hard_days = proj.deadline_day - GameTime.day
				if hard_days <= 0:
					lbl.add_theme_color_override("font_color", COLOR_RED)
				elif hard_days <= 3:
					lbl.add_theme_color_override("font_color", COLOR_ORANGE)
				else:
					lbl.add_theme_color_override("font_color", COLOR_BLUE)
			else:
				lbl.add_theme_color_override("font_color", COLOR_BLUE)

			_content_vbox.add_child(lbl)

	if drafting.size() > 0:
		var sub_label = _create_subsection_label("📝 Ожидают старта:")
		_content_vbox.add_child(sub_label)
		for proj in drafting:
			var text = "[%s] %s — не начат, назначьте людей" % [proj.category.to_upper(), proj.title]
			var lbl = Label.new()
			lbl.text = text
			lbl.add_theme_color_override("font_color", COLOR_GRAY)
			lbl.add_theme_font_size_override("font_size", 13)
			_content_vbox.add_child(lbl)

	if not has_analytics and (in_progress.size() > 0 or finished_today.size() > 0):
		_add_locked_hint("Аналитика проектов")

	if finished_today.size() == 0 and failed_today.size() == 0 and in_progress.size() == 0 and drafting.size() == 0:
		var lbl = Label.new()
		lbl.text = "Нет активных проектов"
		lbl.add_theme_color_override("font_color", COLOR_GRAY)
		lbl.add_theme_font_size_override("font_size", 13)
		_content_vbox.add_child(lbl)

# === СЕКЦИЯ СОТРУДНИКОВ ===
func _build_employees_section():
	var section = _create_section_label("👥 Сотрудники")
	_content_vbox.add_child(section)

	var has_productivity = PMData.can_see_productivity()
	var npcs = get_tree().get_nodes_in_group("npc")

	if npcs.is_empty():
		var lbl = Label.new()
		lbl.text = "Нет сотрудников"
		lbl.add_theme_color_override("font_color", COLOR_GRAY)
		lbl.add_theme_font_size_override("font_size", 13)
		_content_vbox.add_child(lbl)
		return

	var total_count = npcs.size()

	if not has_productivity:
		var summary_lbl = Label.new()
		summary_lbl.text = "👥 Всего сотрудников: %d" % total_count
		summary_lbl.add_theme_color_override("font_color", COLOR_DARK)
		summary_lbl.add_theme_font_size_override("font_size", 14)
		_content_vbox.add_child(summary_lbl)
		_add_locked_hint("Оценка продуктивности")
		return

	var worked_list = []
	var idle_list = []

	for npc in npcs:
		if not npc.data:
			continue
		var work_minutes = npc.data.get_meta("daily_work_minutes", 0.0) if npc.data.has_meta("daily_work_minutes") else 0.0
		var progress = npc.data.get_meta("daily_progress", 0.0) if npc.data.has_meta("daily_progress") else 0.0
		if work_minutes > 0.1:
			worked_list.append({"data": npc.data, "minutes": work_minutes, "progress": progress})
		else:
			idle_list.append(npc.data)

	var summary_lbl = Label.new()
	summary_lbl.text = "👥 Всего: %d  |  🔧 Работали: %d  |  💤 Простаивали: %d" % [total_count, worked_list.size(), idle_list.size()]
	summary_lbl.add_theme_color_override("font_color", COLOR_DARK)
	summary_lbl.add_theme_font_size_override("font_size", 14)
	_content_vbox.add_child(summary_lbl)

	if worked_list.size() > 0:
		var sub = _create_subsection_label("🔧 Работали сегодня:")
		_content_vbox.add_child(sub)
		worked_list.sort_custom(func(a, b): return a["progress"] > b["progress"])
		for entry in worked_list:
			var emp: EmployeeData = entry["data"]
			var minutes: float = entry["minutes"]
			var progress: float = entry["progress"]
			var hours_str = _format_work_time(minutes)
			var progress_str = _format_progress(progress)
			var card = _create_employee_card(emp, hours_str, progress_str)
			_content_vbox.add_child(card)

	if idle_list.size() > 0:
		var sub = _create_subsection_label("💤 Простаивали (не назначены на проект):")
		_content_vbox.add_child(sub)
		for emp in idle_list:
			var card = _create_employee_card_idle(emp)
			_content_vbox.add_child(card)

	var low_energy = []
	for npc in npcs:
		if npc.data and npc.data.current_energy < 30:
			low_energy.append(npc.data)
	if low_energy.size() > 0:
		var warn_lbl = Label.new()
		var names = []
		for emp in low_energy:
			names.append(emp.employee_name)
		warn_lbl.text = "⚠ Низкая энергия: " + ", ".join(names)
		warn_lbl.add_theme_color_override("font_color", COLOR_ORANGE)
		warn_lbl.add_theme_font_size_override("font_size", 13)
		_content_vbox.add_child(warn_lbl)

# === КАРТОЧКА РАБОТАВШЕГО СОТРУДНИКА ===
func _create_employee_card(emp: EmployeeData, hours_str: String, progress_str: String) -> PanelContainer:
	var card = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.96, 0.98, 1.0, 1)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = COLOR_BORDER
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	card.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	margin.add_child(hbox)

	var name_lbl = Label.new()
	name_lbl.text = emp.employee_name + "  —  " + emp.job_title
	name_lbl.add_theme_color_override("font_color", COLOR_BLUE)
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_lbl)

	var hours_lbl = Label.new()
	hours_lbl.text = "⏱ " + hours_str
	hours_lbl.add_theme_color_override("font_color", COLOR_DARK)
	hours_lbl.add_theme_font_size_override("font_size", 13)
	hours_lbl.custom_minimum_size = Vector2(140, 0)
	hbox.add_child(hours_lbl)

	var prog_lbl = Label.new()
	prog_lbl.text = "📊 " + progress_str
	prog_lbl.add_theme_color_override("font_color", COLOR_GREEN)
	prog_lbl.add_theme_font_size_override("font_size", 13)
	prog_lbl.custom_minimum_size = Vector2(160, 0)
	hbox.add_child(prog_lbl)

	return card

# === КАРТОЧКА ПРОСТАИВАЮЩЕГО СОТРУДНИКА ===
func _create_employee_card_idle(emp: EmployeeData) -> PanelContainer:
	var card = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.97, 0.95, 1)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.9, 0.85, 0.8, 1)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	card.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	margin.add_child(hbox)

	var name_lbl = Label.new()
	name_lbl.text = emp.employee_name + "  —  " + emp.job_title
	name_lbl.add_theme_color_override("font_color", COLOR_GRAY)
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_lbl)

	var idle_lbl = Label.new()
	idle_lbl.text = "💤 Не работал"
	idle_lbl.add_theme_color_override("font_color", COLOR_ORANGE)
	idle_lbl.add_theme_font_size_override("font_size", 13)
	hbox.add_child(idle_lbl)

	return card

# === ХЕЛПЕРЫ ===
func _create_section_label(text: String) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", COLOR_BLUE)
	lbl.add_theme_font_size_override("font_size", 16)
	return lbl

func _create_subsection_label(text: String) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", COLOR_DARK)
	lbl.add_theme_font_size_override("font_size", 14)
	return lbl

func _get_current_stage_info(proj: ProjectData) -> String:
	for i in range(proj.stages.size()):
		var stage = proj.stages[i]
		if stage.get("is_completed", false):
			continue
		var prev_ok = true
		if i > 0:
			prev_ok = proj.stages[i - 1].get("is_completed", false)
		if prev_ok:
			var pct = 0.0
			if stage.amount > 0:
				pct = (stage.progress / float(stage.amount)) * 100.0
			var type_name = ""
			match stage.type:
				"BA": type_name = "Бизнес-анализ"
				"DEV": type_name = "Разработка"
				"QA": type_name = "Тестирование"
				_: type_name = stage.type
			return "этап %s (%d%%)" % [type_name, int(pct)]
	return "завершён"

func _format_work_time(minutes: float) -> String:
	var h = int(minutes) / 60
	var m = int(minutes) % 60
	if h > 0:
		return "%d ч %d мин" % [h, m]
	return "%d мин" % m

func _format_progress(progress: float) -> String:
	if progress >= 1000:
		return "%dk очков" % int(progress / 1000.0)
	return "%d очков" % int(progress)
