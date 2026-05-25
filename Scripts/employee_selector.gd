extends Panel

# Сигнал: "Я выбрал вот этого человека"
signal employee_selected(data: EmployeeData)

const ProjectCardHelpers = preload("res://Scripts/project_card_helpers.gd")

@onready var close_btn = find_child("CloseButton", true, false)

# Текущий фильтр по типу этапа ("BA", "DEV", "QA" или "" = все)
var _filter_stage_type: String = ""

const COLOR_BLUE = Color(0.17254902, 0.30980393, 0.5686275, 1)
const COLOR_WHITE = Color(1, 1, 1, 1)
const COLOR_GRAY = Color(0.6, 0.6, 0.6, 1)
const COLOR_DARK = Color(0.15, 0.15, 0.15, 1)
const ROW_HEIGHT = 48
const NAME_MIN_WIDTH = 170
const ROLE_MIN_WIDTH = 160
const BTN_MIN_WIDTH = 120

var _scroll: ScrollContainer
var _rows_container: VBoxContainer

# Стили кнопок
var _btn_style_normal: StyleBoxFlat
var _btn_style_hover: StyleBoxFlat
var _btn_style_disabled: StyleBoxFlat

func _ready():
	visible = false
	z_index = 100  # поверх project_window (z_index=90)

	# === УМНОЕ УДАЛЕНИЕ КНОПОК ===
	var all_buttons = find_children("*", "Button", true, false)
	for btn in all_buttons:
		if close_btn and btn != close_btn:
			btn.queue_free()

	if close_btn:
		if not close_btn.pressed.is_connected(_on_cancel_button_pressed):
			close_btn.pressed.connect(_on_cancel_button_pressed)

	# === НАСТРОЙКА ЗАГОЛОВКА ===
	if UITheme:
		var title_label = find_child("TitleLabel", true, false)
		if title_label:
			UITheme.apply_font(title_label, "bold")
			title_label.text = tr("EMP_SELECT_TITLE")

	# === УДАЛЯЕМ СТАРЫЙ ItemList И CancelButton ===
	var old_item_list = find_child("ItemList", true, false)
	if old_item_list:
		old_item_list.queue_free()
	var old_cancel = find_child("Button", true, false)
	if old_cancel and old_cancel != close_btn:
		old_cancel.queue_free()

	# === СОЗДАЁМ НОВЫЙ LAYOUT ===
	var content_vbox = find_child("VBoxContainer", true, false)
	if content_vbox == null:
		var content_margin = find_child("ContentMargin", true, false)
		if content_margin:
			content_vbox = VBoxContainer.new()
			content_vbox.add_theme_constant_override("separation", 0)
			content_margin.add_child(content_vbox)

	# Заголовки колонок
	var header_row = _create_header_row()
	content_vbox.add_child(header_row)

	# Разделитель
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	content_vbox.add_child(sep)

	# ScrollContainer для строк
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_vbox.add_child(_scroll)

	_rows_container = VBoxContainer.new()
	_rows_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_container.add_theme_constant_override("separation", 2)
	_scroll.add_child(_rows_container)

	# === СТИЛИ КНОПОК ===
	_btn_style_normal = StyleBoxFlat.new()
	_btn_style_normal.bg_color = COLOR_WHITE
	_btn_style_normal.border_width_left = 2
	_btn_style_normal.border_width_top = 2
	_btn_style_normal.border_width_right = 2
	_btn_style_normal.border_width_bottom = 2
	_btn_style_normal.border_color = COLOR_BLUE
	_btn_style_normal.corner_radius_top_left = 16
	_btn_style_normal.corner_radius_top_right = 16
	_btn_style_normal.corner_radius_bottom_right = 16
	_btn_style_normal.corner_radius_bottom_left = 16

	_btn_style_hover = StyleBoxFlat.new()
	_btn_style_hover.bg_color = COLOR_BLUE
	_btn_style_hover.border_width_left = 2
	_btn_style_hover.border_width_top = 2
	_btn_style_hover.border_width_right = 2
	_btn_style_hover.border_width_bottom = 2
	_btn_style_hover.border_color = COLOR_BLUE
	_btn_style_hover.corner_radius_top_left = 16
	_btn_style_hover.corner_radius_top_right = 16
	_btn_style_hover.corner_radius_bottom_right = 16
	_btn_style_hover.corner_radius_bottom_left = 16

	_btn_style_disabled = StyleBoxFlat.new()
	_btn_style_disabled.bg_color = Color(0.95, 0.95, 0.95, 1)
	_btn_style_disabled.border_width_left = 2
	_btn_style_disabled.border_width_top = 2
	_btn_style_disabled.border_width_right = 2
	_btn_style_disabled.border_width_bottom = 2
	_btn_style_disabled.border_color = Color(0.8, 0.8, 0.8, 1)
	_btn_style_disabled.corner_radius_top_left = 16
	_btn_style_disabled.corner_radius_top_right = 16
	_btn_style_disabled.corner_radius_bottom_right = 16
	_btn_style_disabled.corner_radius_bottom_left = 16

func _create_header_row() -> HBoxContainer:
	var row = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 30)

	var name_lbl = Label.new()
	name_lbl.text = tr("ASSIGN_COL_NAME")
	name_lbl.custom_minimum_size = Vector2(NAME_MIN_WIDTH, 0)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_color_override("font_color", COLOR_DARK)
	name_lbl.add_theme_font_size_override("font_size", 14)
	if UITheme:
		UITheme.apply_font(name_lbl, "bold")
	row.add_child(name_lbl)

	var role_lbl = Label.new()
	role_lbl.text = tr("ASSIGN_COL_ROLE")
	role_lbl.custom_minimum_size = Vector2(ROLE_MIN_WIDTH, 0)
	role_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	role_lbl.add_theme_color_override("font_color", COLOR_DARK)
	role_lbl.add_theme_font_size_override("font_size", 14)
	if UITheme:
		UITheme.apply_font(role_lbl, "bold")
	row.add_child(role_lbl)

	# Пустое место под кнопку
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(BTN_MIN_WIDTH, 0)
	row.add_child(spacer)

	return row

func open_list(stage_type: String = ""):
	_filter_stage_type = stage_type
	_refresh_list()
	visible = true

func _refresh_list():
	for child in _rows_container.get_children():
		child.queue_free()

	var npcs = get_tree().get_nodes_in_group("npc")
	var found_any = false

	for npc in npcs:
		if npc.data:
			if _filter_stage_type != "" and not _matches_stage_type(npc.data, _filter_stage_type):
				continue

			var is_disabled = false
			var disable_reason = ""

			# Блокируем сотрудников в отпуске
			if npc.current_state == npc.State.ON_VACATION:
				is_disabled = true
				disable_reason = "✈️ " + tr("EMP_SELECT_ON_VACATION")
			# Блокируем сотрудников на обучении или в неоплачиваемом отпуске
			elif npc.current_state == npc.State.ON_TRAINING or npc.current_state == npc.State.UNPAID_LEAVE:
				is_disabled = true
				disable_reason = "🚫 " + tr("EMP_SELECT_ABSENT")
			# Блокируем занятых на проекте
			elif _is_employee_assigned_to_any_project(npc.data):
				is_disabled = true
				disable_reason = tr("EMP_SELECT_BUSY")

			var row = _create_employee_row(npc, is_disabled, disable_reason)
			_rows_container.add_child(row)
			found_any = true

	if not found_any:
		var empty_lbl = Label.new()
		var role_name = _get_role_name(_filter_stage_type)
		empty_lbl.text = tr("EMP_SELECT_NO_ROLE") % role_name
		empty_lbl.add_theme_color_override("font_color", COLOR_GRAY)
		empty_lbl.add_theme_font_size_override("font_size", 14)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if UITheme:
			UITheme.apply_font(empty_lbl, "regular")
		_rows_container.add_child(empty_lbl)

func _create_employee_row(npc_node, is_disabled: bool, disable_reason: String) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	row.add_theme_constant_override("separation", 8)

	# Имя
	var name_lbl = Label.new()
	name_lbl.text = npc_node.data.get_display_name()
	name_lbl.custom_minimum_size = Vector2(NAME_MIN_WIDTH, 0)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 14)
	if is_disabled:
		name_lbl.add_theme_color_override("font_color", COLOR_GRAY)
	else:
		name_lbl.add_theme_color_override("font_color", COLOR_DARK)
	if UITheme:
		UITheme.apply_font(name_lbl, "regular")
	row.add_child(name_lbl)

	# Роль
	var role_lbl = Label.new()
	var role_text = tr(npc_node.data.job_title)
	if is_disabled and disable_reason != "":
		role_text += " " + disable_reason
	role_lbl.text = role_text
	role_lbl.custom_minimum_size = Vector2(ROLE_MIN_WIDTH, 0)
	role_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	role_lbl.clip_text = true
	role_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	role_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	role_lbl.add_theme_font_size_override("font_size", 14)
	var role_color = _get_role_color(npc_node.data.job_title)
	role_lbl.add_theme_color_override("font_color", role_color if not is_disabled else COLOR_GRAY)
	if UITheme:
		UITheme.apply_font(role_lbl, "semibold")
	row.add_child(role_lbl)

	# Кнопка
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(BTN_MIN_WIDTH, 34)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 13)
	if UITheme:
		UITheme.apply_font(btn, "semibold")

	if is_disabled:
		btn.text = tr("ASSIGN_BTN")
		btn.disabled = true
		btn.add_theme_stylebox_override("normal", _btn_style_disabled)
		btn.add_theme_stylebox_override("disabled", _btn_style_disabled)
		btn.add_theme_color_override("font_color", COLOR_GRAY)
		btn.add_theme_color_override("font_disabled_color", COLOR_GRAY)
	else:
		btn.text = tr("ASSIGN_BTN")
		btn.add_theme_stylebox_override("normal", _btn_style_normal)
		btn.add_theme_stylebox_override("hover", _btn_style_hover)
		btn.add_theme_stylebox_override("pressed", _btn_style_hover)
		btn.add_theme_color_override("font_color", COLOR_BLUE)
		btn.add_theme_color_override("font_hover_color", COLOR_WHITE)
		btn.add_theme_color_override("font_pressed_color", COLOR_WHITE)
		btn.pressed.connect(_on_assign_pressed.bind(npc_node.data))

	row.add_child(btn)
	return row

func _get_role_color(job_title: String) -> Color:
	match job_title:
		"Business Analyst":
			return ProjectCardHelpers.get_role_color("ba")
		"Backend Developer":
			return ProjectCardHelpers.get_role_color("dev")
		"QA Engineer":
			return ProjectCardHelpers.get_role_color("qa")
		"Customer Support":
			return ProjectCardHelpers.get_role_color("support")
	return COLOR_BLUE

func _on_assign_pressed(emp_data: EmployeeData):
	emit_signal("employee_selected", emp_data)
	visible = false

func _is_employee_assigned_to_any_project(emp_data: EmployeeData) -> bool:
	if SupportProjectManager and SupportProjectManager.is_employee_on_support(emp_data):
		return true
	if SupportProjectManager and SupportProjectManager.is_employee_on_ticket(emp_data):
		return true

	for project in ProjectManager.active_projects:
		if project.state == ProjectData.State.FINISHED:
			continue
		if project.state == ProjectData.State.FAILED:
			continue

		for stage in project.stages:
			for worker in stage.workers:
				if worker == emp_data:
					return true

	return false

func _matches_stage_type(data: EmployeeData, stage_type: String) -> bool:
	match stage_type:
		"BA":
			return data.job_title == "Business Analyst"
		"DEV":
			return data.job_title == "Backend Developer"
		"QA":
			return data.job_title == "QA Engineer"
		"SUPPORT":
			return data.job_title == "Customer Support"
	return true

func _get_role_name(stage_type: String) -> String:
	match stage_type:
		"BA": return tr("HR_ROLE_BA")
		"DEV": return tr("HR_ROLE_DEV")
		"QA": return tr("HR_ROLE_QA")
		"SUPPORT": return tr("HR_ROLE_SUPPORT")
	return stage_type

func _on_cancel_button_pressed():
	visible = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and visible:
		_on_cancel_button_pressed()
		get_viewport().set_input_as_handled()
