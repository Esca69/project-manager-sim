extends Control

# === EMPLOYEE INTERACTION PANEL ===
# UI панель взаимодействия PM с конкретным сотрудником
# Аналог DeskPanel, но для прямых управленческих действий

const COLOR_BLUE   = Color(0.17254902, 0.30980393, 0.5686275, 1)
const COLOR_GREEN  = Color(0.29803923, 0.6862745, 0.3137255, 1)
const COLOR_RED    = Color(0.85, 0.25, 0.2, 1)
const COLOR_DARK   = Color(0.15, 0.15, 0.15, 1)
const COLOR_GRAY   = Color(0.45, 0.45, 0.45, 1)
const COLOR_WHITE  = Color(1.0, 1.0, 1.0, 1.0)
const COLOR_BORDER = Color(0.0, 0.0, 0.0, 1.0)
const COLOR_LIGHT_GRAY = Color(0.94, 0.94, 0.94, 1)

# Текущий NPC
var _current_npc = null
var _was_paused: bool = false

# Ноды UI
var _overlay: ColorRect
var _window: PanelContainer
var _info_vbox: VBoxContainer
var _actions_vbox: VBoxContainer

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 92
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	name = "EmployeeInteractionPanel"
	_build_ui()

func _build_ui():
	# === ЗАТЕМНЕНИЕ ФОНА ===
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.45)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# === ОКНО ===
	_window = PanelContainer.new()
	_window.custom_minimum_size = Vector2(520, 0)
	var win_style = StyleBoxFlat.new()
	win_style.bg_color = COLOR_WHITE
	win_style.border_width_left = 3
	win_style.border_width_top = 3
	win_style.border_width_right = 3
	win_style.border_width_bottom = 3
	win_style.border_color = COLOR_BORDER
	win_style.corner_radius_top_left = 18
	win_style.corner_radius_top_right = 18
	win_style.corner_radius_bottom_right = 16
	win_style.corner_radius_bottom_left = 16
	if UITheme:
		UITheme.apply_shadow(win_style, false)
	_window.add_theme_stylebox_override("panel", win_style)
	center.add_child(_window)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 0)
	_window.add_child(main_vbox)

	# === ЗАГОЛОВОК ===
	var header = Panel.new()
	header.custom_minimum_size = Vector2(0, 44)
	var hdr_style = StyleBoxFlat.new()
	hdr_style.bg_color = COLOR_BLUE
	hdr_style.corner_radius_top_left = 16
	hdr_style.corner_radius_top_right = 16
	header.add_theme_stylebox_override("panel", hdr_style)
	main_vbox.add_child(header)

	var title_lbl = Label.new()
	title_lbl.text = tr("INTERACT_PANEL_TITLE")
	title_lbl.add_theme_color_override("font_color", COLOR_WHITE)
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.set_anchors_preset(Control.PRESET_CENTER)
	title_lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title_lbl.grow_vertical = Control.GROW_DIRECTION_BOTH
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme:
		UITheme.apply_font(title_lbl, "bold")
	header.add_child(title_lbl)

	# === КОНТЕНТ ===
	var content_margin = MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 16)
	content_margin.add_theme_constant_override("margin_right", 16)
	content_margin.add_theme_constant_override("margin_top", 14)
	content_margin.add_theme_constant_override("margin_bottom", 14)
	main_vbox.add_child(content_margin)

	var content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 10)
	content_margin.add_child(content_vbox)

	# === БЛОК ИНФОРМАЦИИ О СОТРУДНИКЕ ===
	_info_vbox = VBoxContainer.new()
	_info_vbox.add_theme_constant_override("separation", 4)
	content_vbox.add_child(_info_vbox)

	# === СЕПАРАТОР ===
	content_vbox.add_child(HSeparator.new())

	# === ЗАГОЛОВОК СЕКЦИИ ДЕЙСТВИЙ ===
	var actions_title = Label.new()
	actions_title.text = tr("INTERACT_SECTION_ACTIONS")
	actions_title.add_theme_font_size_override("font_size", 13)
	actions_title.add_theme_color_override("font_color", COLOR_GRAY)
	if UITheme:
		UITheme.apply_font(actions_title, "semibold")
	content_vbox.add_child(actions_title)

	# === БЛОК ДЕЙСТВИЙ ===
	_actions_vbox = VBoxContainer.new()
	_actions_vbox.add_theme_constant_override("separation", 6)
	content_vbox.add_child(_actions_vbox)

	# === КНОПКА ЗАКРЫТЬ ===
	var footer_margin = MarginContainer.new()
	footer_margin.add_theme_constant_override("margin_top", 4)
	content_vbox.add_child(footer_margin)

	var close_center = CenterContainer.new()
	footer_margin.add_child(close_center)

	var close_btn = Button.new()
	close_btn.text = tr("UI_CLOSE")
	close_btn.custom_minimum_size = Vector2(160, 36)
	close_btn.add_theme_font_size_override("font_size", 14)
	close_btn.focus_mode = Control.FOCUS_NONE
	if UITheme:
		UITheme.apply_font(close_btn, "semibold")
	var cbtn_style = StyleBoxFlat.new()
	cbtn_style.bg_color = COLOR_WHITE
	cbtn_style.border_width_left = 2
	cbtn_style.border_width_top = 2
	cbtn_style.border_width_right = 2
	cbtn_style.border_width_bottom = 2
	cbtn_style.border_color = COLOR_GRAY
	cbtn_style.corner_radius_top_left = 16
	cbtn_style.corner_radius_top_right = 16
	cbtn_style.corner_radius_bottom_right = 16
	cbtn_style.corner_radius_bottom_left = 16
	var cbtn_hover = StyleBoxFlat.new()
	cbtn_hover.bg_color = COLOR_GRAY
	cbtn_hover.border_width_left = 2
	cbtn_hover.border_width_top = 2
	cbtn_hover.border_width_right = 2
	cbtn_hover.border_width_bottom = 2
	cbtn_hover.border_color = COLOR_GRAY
	cbtn_hover.corner_radius_top_left = 16
	cbtn_hover.corner_radius_top_right = 16
	cbtn_hover.corner_radius_bottom_right = 16
	cbtn_hover.corner_radius_bottom_left = 16
	close_btn.add_theme_stylebox_override("normal", cbtn_style)
	close_btn.add_theme_stylebox_override("hover", cbtn_hover)
	close_btn.add_theme_stylebox_override("pressed", cbtn_hover)
	close_btn.add_theme_color_override("font_color", COLOR_GRAY)
	close_btn.add_theme_color_override("font_hover_color", COLOR_WHITE)
	close_btn.pressed.connect(_on_close_pressed)
	close_center.add_child(close_btn)

func open_for_employee(npc_node):
	_was_paused = GameTime.is_game_paused
	GameTime.set_paused(true)
	_current_npc = npc_node
	_refresh()
	mouse_filter = Control.MOUSE_FILTER_STOP
	if UITheme:
		UITheme.fade_in(self, 0.2)
	else:
		visible = true

func _refresh():
	if not _current_npc or not is_instance_valid(_current_npc):
		return
	_refresh_info_block()
	_refresh_actions_block()

func _refresh_info_block():
	for child in _info_vbox.get_children():
		child.queue_free()

	var emp = _current_npc.data
	if not emp:
		return

	# Имя + роль
	var name_lbl = Label.new()
	name_lbl.text = emp.get_display_name() + " — " + tr(emp.job_title)
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", COLOR_DARK)
	if UITheme:
		UITheme.apply_font(name_lbl, "bold")
	_info_vbox.add_child(name_lbl)

	# Грейд + уровень
	var grade_lbl = Label.new()
	grade_lbl.text = emp.get_grade_name() + " Lv." + str(emp.employee_level)
	grade_lbl.add_theme_font_size_override("font_size", 13)
	grade_lbl.add_theme_color_override("font_color", COLOR_GRAY)
	_info_vbox.add_child(grade_lbl)

	# Настроение
	var mood_lbl = Label.new()
	var mood_val = int(emp.mood)
	var zone_name = emp.get_mood_zone_name()
	mood_lbl.text = tr("ROSTER_MOOD") % [mood_val, zone_name]
	mood_lbl.add_theme_font_size_override("font_size", 13)
	mood_lbl.add_theme_color_override("font_color", COLOR_GRAY)
	_info_vbox.add_child(mood_lbl)

	var loyalty_lbl = Label.new()
	var loyalty_level = emp.get_pm_loyalty_level()
	loyalty_lbl.text = tr("INTERACT_LOYALTY") % [int(emp.pm_loyalty), tr(loyalty_level.name)]
	loyalty_lbl.add_theme_font_size_override("font_size", 13)
	if emp.pm_loyalty >= 65.0:
		loyalty_lbl.add_theme_color_override("font_color", COLOR_GREEN)
	elif emp.pm_loyalty >= 36.0:
		loyalty_lbl.add_theme_color_override("font_color", COLOR_GRAY)
	else:
		loyalty_lbl.add_theme_color_override("font_color", COLOR_RED)
	_info_vbox.add_child(loyalty_lbl)

func _refresh_actions_block():
	for child in _actions_vbox.get_children():
		child.queue_free()

	if not _current_npc or not is_instance_valid(_current_npc):
		return

	var emp = _current_npc.data
	if not emp:
		return

	var bonus_amount = int(emp.monthly_salary * 0.25)

	# 👏 Похвала
	var praise_reason = ""
	if emp.pm_praise_cooldown > 0:
		var h = int(emp.pm_praise_cooldown) / 60
		var m = int(emp.pm_praise_cooldown) % 60
		praise_reason = tr("INTERACT_COOLDOWN") % [h, m]
	_add_action_row(
		tr("INTERACT_PRAISE_TITLE"),
		tr("INTERACT_PRAISE_DESC"),
		praise_reason,
		func(): _do_praise()
	)

	# ⚠️ Выговор
	var reprimand_reason = ""
	if emp.pm_reprimand_cooldown > 0:
		var h = int(emp.pm_reprimand_cooldown) / 60
		var m = int(emp.pm_reprimand_cooldown) % 60
		reprimand_reason = tr("INTERACT_COOLDOWN") % [h, m]
	_add_action_row(
		tr("INTERACT_REPRIMAND_TITLE"),
		tr("INTERACT_REPRIMAND_DESC"),
		reprimand_reason,
		func(): _do_reprimand()
	)

	# Сепаратор
	_actions_vbox.add_child(HSeparator.new())

	# 📚 Обучение
	var training_reason = ""
	if emp.employment_type != "contractor":
		training_reason = tr("INTERACT_TRAINING_FREELANCER")
	elif GameState.company_balance < 800:
		training_reason = tr("INTERACT_TRAINING_NO_MONEY")
	_add_action_row(
		tr("INTERACT_TRAINING_TITLE"),
		tr("INTERACT_TRAINING_DESC"),
		training_reason,
		func(): _do_training()
	)

	# 🏖️ Оплачиваемый отгул
	var dayoff_reason = ""
	if GameTime.hour >= 11:
		dayoff_reason = tr("INTERACT_DAYOFF_TOO_LATE")
	_add_action_row(
		tr("INTERACT_DAYOFF_TITLE"),
		tr("INTERACT_DAYOFF_DESC"),
		dayoff_reason,
		func(): _do_dayoff()
	)

	# 💰 Неоплачиваемый отпуск
	_add_action_row(
		tr("INTERACT_UNPAID_TITLE"),
		tr("INTERACT_UNPAID_DESC"),
		"",
		func(): _do_unpaid_leave()
	)

	# 💵 Премия
	var bonus_reason = ""
	if GameState.company_balance < bonus_amount:
		bonus_reason = tr("INTERACT_BONUS_NO_MONEY") % bonus_amount
	_add_action_row(
		tr("INTERACT_BONUS_TITLE"),
		tr("INTERACT_BONUS_DESC") % bonus_amount,
		bonus_reason,
		func(): _do_bonus()
	)

func _add_action_row(title: String, desc: String, reason: String, callback: Callable):
	var row = PanelContainer.new()
	var row_style = StyleBoxFlat.new()
	row_style.bg_color = COLOR_LIGHT_GRAY
	row_style.corner_radius_top_left = 8
	row_style.corner_radius_top_right = 8
	row_style.corner_radius_bottom_right = 8
	row_style.corner_radius_bottom_left = 8
	row.add_theme_stylebox_override("panel", row_style)
	_actions_vbox.add_child(row)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	row.add_child(margin)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	margin.add_child(hbox)

	# Левая часть: название + описание
	var left_vbox = VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(left_vbox)

	var title_lbl = Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.add_theme_color_override("font_color", COLOR_DARK)
	if UITheme:
		UITheme.apply_font(title_lbl, "semibold")
	left_vbox.add_child(title_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = desc
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", COLOR_GRAY)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left_vbox.add_child(desc_lbl)

	if reason != "":
		var reason_lbl = Label.new()
		reason_lbl.text = reason
		reason_lbl.add_theme_font_size_override("font_size", 11)
		reason_lbl.add_theme_color_override("font_color", COLOR_RED)
		left_vbox.add_child(reason_lbl)

	# Правая часть: кнопка
	var btn = Button.new()
	btn.text = tr("INTERACT_BTN_EXECUTE")
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(100, 32)
	btn.add_theme_font_size_override("font_size", 12)
	if UITheme:
		UITheme.apply_font(btn, "semibold")

	var is_disabled = reason != ""
	btn.disabled = is_disabled
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	if not is_disabled:
		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = COLOR_BLUE
		btn_style.corner_radius_top_left = 16
		btn_style.corner_radius_top_right = 16
		btn_style.corner_radius_bottom_right = 16
		btn_style.corner_radius_bottom_left = 16
		var btn_hover = StyleBoxFlat.new()
		btn_hover.bg_color = COLOR_BLUE.darkened(0.2)
		btn_hover.corner_radius_top_left = 16
		btn_hover.corner_radius_top_right = 16
		btn_hover.corner_radius_bottom_right = 16
		btn_hover.corner_radius_bottom_left = 16
		btn.add_theme_stylebox_override("normal", btn_style)
		btn.add_theme_stylebox_override("hover", btn_hover)
		btn.add_theme_stylebox_override("pressed", btn_hover)
		btn.add_theme_color_override("font_color", COLOR_WHITE)
		btn.add_theme_color_override("font_hover_color", COLOR_WHITE)
		btn.pressed.connect(callback)
	else:
		var disabled_style = StyleBoxFlat.new()
		disabled_style.bg_color = Color(0.7, 0.7, 0.7, 1)
		disabled_style.corner_radius_top_left = 16
		disabled_style.corner_radius_top_right = 16
		disabled_style.corner_radius_bottom_right = 16
		disabled_style.corner_radius_bottom_left = 16
		btn.add_theme_stylebox_override("disabled", disabled_style)
		btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.5, 1))

	hbox.add_child(btn)

# ==========================================
# === ДЕЙСТВИЯ PM ===
# ==========================================

func _do_praise():
	if not _current_npc or not is_instance_valid(_current_npc):
		return
	var emp = _current_npc.data
	if not emp:
		return
	if emp.pm_praise_cooldown > 0:
		return

	# Применить mood
	emp.add_mood_modifier("pm_praise", "MOOD_MOD_PM_PRAISE", 5.0, 1440.0)
	emp.change_pm_loyalty(2.0, "praise")
	# Установить кулдаун
	emp.pm_praise_cooldown = 4320.0

	_current_npc.show_thought_bubble("👏", 3.0)

	if EventLog:
		EventLog.add(tr("LOG_PM_PRAISE") % emp.get_display_name(), EventLog.LogType.PROGRESS)

	AudioManager.play_sfx("interact")
	_close()

func _do_reprimand():
	if not _current_npc or not is_instance_valid(_current_npc):
		return
	var emp = _current_npc.data
	if not emp:
		return
	if emp.pm_reprimand_cooldown > 0:
		return

	# Применить mood-штраф
	emp.add_mood_modifier("pm_reprimand_mood", "MOOD_MOD_PM_REPRIMAND", -5.0, 1440.0)
	emp.change_pm_loyalty(-7.0, "reprimand")
	# Применить efficiency buff
	EventManager.add_effect({
		"type": "efficiency_buff",
		"employee_name": emp.employee_name,
		"value": 0.10,
		"days_left": 1,
		"emoji": "😤",
	})
	# Установить кулдаун
	emp.pm_reprimand_cooldown = 4320.0

	_current_npc.show_thought_bubble("😤", 3.0)

	if EventLog:
		EventLog.add(tr("LOG_PM_REPRIMAND") % emp.get_display_name(), EventLog.LogType.ALERT)

	AudioManager.play_sfx("interact")
	_close()

func _do_training():
	if not _current_npc or not is_instance_valid(_current_npc):
		return
	var emp = _current_npc.data
	if not emp:
		return
	if emp.employment_type != "contractor":
		return
	if GameState.company_balance < 800:
		return

	# Списать деньги
	GameState.add_expense(800)
	GameState.daily_event_expenses.append({"reason": "EXPENSE_TRAINING", "amount": 800, "employee": emp.get_display_name()})

	# Отправить на обучение
	_current_npc.start_training()
	emp.change_pm_loyalty(8.0, "training")

	if EventLog:
		EventLog.add(tr("LOG_PM_TRAINING_SENT") % emp.get_display_name(), EventLog.LogType.PROGRESS)

	AudioManager.play_sfx("interact")
	_close()

func _do_dayoff():
	if not _current_npc or not is_instance_valid(_current_npc):
		return
	var emp = _current_npc.data
	if not emp:
		return
	if GameTime.hour >= 11:
		return

	# Применить mood buff сразу
	emp.add_mood_modifier("pm_dayoff_mood", "MOOD_MOD_PM_DAYOFF", 8.0, 2880.0)
	# Снизить burnout
	emp.burnout_level = maxf(0.0, emp.burnout_level - 1.0)
	emp.change_pm_loyalty(5.0, "dayoff")

	# Отправить домой
	_current_npc.start_day_off()

	if EventLog:
		EventLog.add(tr("LOG_PM_DAYOFF_GIVEN") % emp.get_display_name(), EventLog.LogType.PROGRESS)

	AudioManager.play_sfx("interact")
	_close()

func _do_unpaid_leave():
	if not _current_npc or not is_instance_valid(_current_npc):
		return
	var emp = _current_npc.data
	if not emp:
		return

	_current_npc.start_unpaid_leave()
	emp.change_pm_loyalty(-15.0, "unpaid_leave")

	if EventLog:
		EventLog.add(tr("LOG_PM_UNPAID_LEAVE_SENT") % emp.get_display_name(), EventLog.LogType.PROGRESS)

	_close()

func _do_bonus():
	if not _current_npc or not is_instance_valid(_current_npc):
		return
	var emp = _current_npc.data
	if not emp:
		return
	var bonus_amount = int(emp.monthly_salary * 0.25)
	if GameState.company_balance < bonus_amount:
		return

	# Списать деньги
	GameState.add_expense(bonus_amount)
	GameState.daily_event_expenses.append({"reason": "EXPENSE_BONUS", "amount": bonus_amount, "employee": emp.get_display_name()})

	# Применить mood buff
	emp.add_mood_modifier("pm_bonus_mood", "MOOD_MOD_PM_BONUS", 15.0, 7200.0)
	emp.change_pm_loyalty(10.0, "bonus")

	_current_npc.show_thought_bubble("💵", 3.0)

	if EventLog:
		EventLog.add(tr("LOG_PM_BONUS_GIVEN") % [emp.get_display_name(), bonus_amount], EventLog.LogType.PROGRESS)

	AudioManager.play_sfx("interact")
	_close()

# ==========================================
# === УПРАВЛЕНИЕ ОКНОМ ===
# ==========================================

func _close():
	if not _was_paused:
		GameTime.set_paused(false)
	_current_npc = null
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if UITheme:
		UITheme.fade_out(self)
	else:
		visible = false

func _on_close_pressed():
	_close()

func _input(event):
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()
