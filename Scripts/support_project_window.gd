extends Control

signal closed

const COLOR_BLUE = Color(0.17254902, 0.30980393, 0.5686275, 1)
const COLOR_WHITE = Color(1, 1, 1, 1)
const TICKET_COLUMN_WIDTH = 340
const TICKET_COLUMNS_SEPARATION = 12

var _overlay: ColorRect
var _window: PanelContainer
var _top_vbox: VBoxContainer
var _ticket_column_lists: Dictionary = {}
var _ticket_column_headers: Dictionary = {}

var _project: SupportProjectData = null
var _was_paused: bool = false
var _last_refresh_key: int = -1

var _assignment_overlay: ColorRect
var _assignment_scroll: ScrollContainer
var _assignment_rows_container: VBoxContainer
var _assignment_callback: Callable
var _ticket_progress_labels: Array = []

# Стили кнопок для попапа назначения
var _assign_btn_style_normal: StyleBoxFlat
var _assign_btn_style_hover: StyleBoxFlat
var _assign_btn_style_disabled: StyleBoxFlat

func _tr_format_safe(key: String, args, fallback: String) -> String:
	var text = tr(key)
	if text.find("%") >= 0:
		return text % args
	return fallback

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	z_index = 97
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func open_for_project(proj: SupportProjectData):
	if proj == null:
		return
	_project = proj
	_was_paused = GameTime.is_game_paused
	GameTime.set_paused(true)
	_rebuild()
	if UITheme:
		UITheme.fade_in(self, 0.2)
	else:
		visible = true

func _close_window():
	if not _was_paused:
		GameTime.set_paused(false)
	if UITheme:
		UITheme.fade_out(self, 0.15)
	else:
		visible = false
	emit_signal("closed")

func _build_ui():
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.55)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	_window = PanelContainer.new()
	_window.custom_minimum_size = Vector2(1500, 900)
	_window.set_anchors_preset(Control.PRESET_CENTER)
	_window.offset_left = -750
	_window.offset_top = -450
	_window.offset_right = 750
	_window.offset_bottom = 450
	_window.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_window.grow_vertical = Control.GROW_DIRECTION_BOTH
	var ws = StyleBoxFlat.new()
	ws.bg_color = COLOR_WHITE
	ws.border_width_left = 3
	ws.border_width_top = 3
	ws.border_width_right = 3
	ws.border_width_bottom = 3
	ws.border_color = Color(0, 0, 0, 1)
	ws.corner_radius_top_left = 22
	ws.corner_radius_top_right = 22
	ws.corner_radius_bottom_left = 20
	ws.corner_radius_bottom_right = 20
	if UITheme:
		UITheme.apply_shadow(ws, false)
	_window.add_theme_stylebox_override("panel", ws)
	add_child(_window)

	var root = VBoxContainer.new()
	root.add_theme_constant_override("separation", 0)
	_window.add_child(root)

	var header = Panel.new()
	header.custom_minimum_size = Vector2(0, 40)
	var hs = StyleBoxFlat.new()
	hs.bg_color = COLOR_BLUE
	hs.corner_radius_top_left = 20
	hs.corner_radius_top_right = 20
	header.add_theme_stylebox_override("panel", hs)
	root.add_child(header)

	var title_lbl = Label.new()
	title_lbl.name = "TitleLabel"
	title_lbl.add_theme_color_override("font_color", COLOR_WHITE)
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.set_anchors_preset(Control.PRESET_CENTER)
	title_lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title_lbl.grow_vertical = Control.GROW_DIRECTION_BOTH
	title_lbl.offset_left = -88
	title_lbl.offset_top = -11.5
	title_lbl.offset_right = 88
	title_lbl.offset_bottom = 11.5
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme:
		UITheme.apply_font(title_lbl, "bold")
	header.add_child(title_lbl)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	close_btn.offset_left = -51
	close_btn.offset_top = -15
	close_btn.offset_right = -24
	close_btn.offset_bottom = 16
	close_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	close_btn.grow_vertical = Control.GROW_DIRECTION_BOTH
	close_btn.add_theme_color_override("font_color", COLOR_BLUE)
	var close_style = StyleBoxFlat.new()
	close_style.bg_color = COLOR_WHITE
	close_style.corner_radius_top_left = 10
	close_style.corner_radius_top_right = 10
	close_style.corner_radius_bottom_right = 10
	close_style.corner_radius_bottom_left = 10
	close_btn.add_theme_stylebox_override("normal", close_style)
	if UITheme:
		UITheme.apply_font(close_btn, "semibold")
	close_btn.pressed.connect(_close_window)
	header.add_child(close_btn)

	var margin = MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 16)
	root.add_child(margin)

	var body = VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	margin.add_child(body)

	_top_vbox = VBoxContainer.new()
	_top_vbox.add_theme_constant_override("separation", 8)
	body.add_child(_top_vbox)
	body.add_child(HSeparator.new())

	var columns_row = HBoxContainer.new()
	columns_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	columns_row.add_theme_constant_override("separation", TICKET_COLUMNS_SEPARATION)
	body.add_child(columns_row)

	_create_ticket_column(columns_row, "todo", "SUPPORT_COLUMN_TODO")
	_create_ticket_column(columns_row, "in_progress", "SUPPORT_COLUMN_IN_PROGRESS")
	_create_ticket_column(columns_row, "done", "SUPPORT_COLUMN_DONE")
	_create_ticket_column(columns_row, "overdue", "SUPPORT_COLUMN_OVERDUE")

	_build_assignment_popup()

func _build_assignment_popup():
	_assignment_overlay = ColorRect.new()
	_assignment_overlay.color = Color(0, 0, 0, 0.45)
	_assignment_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_assignment_overlay.visible = false
	_assignment_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_assignment_overlay)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 440)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -280
	panel.offset_top = -220
	panel.offset_right = 280
	panel.offset_bottom = 220
	var ps = StyleBoxFlat.new()
	ps.bg_color = COLOR_WHITE
	ps.border_width_left = 3
	ps.border_width_top = 3
	ps.border_width_right = 3
	ps.border_width_bottom = 3
	ps.border_color = Color(0, 0, 0, 1)
	ps.corner_radius_top_left = 22
	ps.corner_radius_top_right = 22
	ps.corner_radius_bottom_left = 20
	ps.corner_radius_bottom_right = 20
	if UITheme:
		UITheme.apply_shadow(ps, false)
	panel.add_theme_stylebox_override("panel", ps)
	_assignment_overlay.add_child(panel)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 0)
	panel.add_child(main_vbox)

	var header = Panel.new()
	header.custom_minimum_size = Vector2(0, 40)
	var hs = StyleBoxFlat.new()
	hs.bg_color = COLOR_BLUE
	hs.corner_radius_top_left = 20
	hs.corner_radius_top_right = 20
	header.add_theme_stylebox_override("panel", hs)
	main_vbox.add_child(header)

	var title = Label.new()
	title.text = tr("EMP_SELECT_TITLE")
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title.grow_vertical = Control.GROW_DIRECTION_BOTH
	title.offset_left = -100
	title.offset_top = -11.5
	title.offset_right = 100
	title.offset_bottom = 11.5
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_WHITE)
	title.add_theme_font_size_override("font_size", 16)
	if UITheme:
		UITheme.apply_font(title, "bold")
	header.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	close_btn.offset_left = -51
	close_btn.offset_top = -15
	close_btn.offset_right = -24
	close_btn.offset_bottom = 16
	close_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	close_btn.grow_vertical = Control.GROW_DIRECTION_BOTH
	close_btn.add_theme_color_override("font_color", COLOR_BLUE)
	var close_style = StyleBoxFlat.new()
	close_style.bg_color = COLOR_WHITE
	close_style.corner_radius_top_left = 10
	close_style.corner_radius_top_right = 10
	close_style.corner_radius_bottom_right = 10
	close_style.corner_radius_bottom_left = 10
	close_btn.add_theme_stylebox_override("normal", close_style)
	if UITheme:
		UITheme.apply_font(close_btn, "semibold")
	close_btn.pressed.connect(func(): _assignment_overlay.visible = false)
	header.add_child(close_btn)

	var content_margin = MarginContainer.new()
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_left", 15)
	content_margin.add_theme_constant_override("margin_top", 15)
	content_margin.add_theme_constant_override("margin_right", 15)
	content_margin.add_theme_constant_override("margin_bottom", 15)
	main_vbox.add_child(content_margin)

	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	content_margin.add_child(v)

	# Заголовки колонок
	var header_row = _create_assign_header_row()
	v.add_child(header_row)

	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	v.add_child(sep)

	# ScrollContainer для строк
	_assignment_scroll = ScrollContainer.new()
	_assignment_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_assignment_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(_assignment_scroll)

	_assignment_rows_container = VBoxContainer.new()
	_assignment_rows_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_assignment_rows_container.add_theme_constant_override("separation", 2)
	_assignment_scroll.add_child(_assignment_rows_container)

	# === СТИЛИ КНОПОК ===
	_assign_btn_style_normal = StyleBoxFlat.new()
	_assign_btn_style_normal.bg_color = COLOR_WHITE
	_assign_btn_style_normal.border_width_left = 2
	_assign_btn_style_normal.border_width_top = 2
	_assign_btn_style_normal.border_width_right = 2
	_assign_btn_style_normal.border_width_bottom = 2
	_assign_btn_style_normal.border_color = COLOR_BLUE
	_assign_btn_style_normal.corner_radius_top_left = 16
	_assign_btn_style_normal.corner_radius_top_right = 16
	_assign_btn_style_normal.corner_radius_bottom_right = 16
	_assign_btn_style_normal.corner_radius_bottom_left = 16

	_assign_btn_style_hover = StyleBoxFlat.new()
	_assign_btn_style_hover.bg_color = COLOR_BLUE
	_assign_btn_style_hover.border_width_left = 2
	_assign_btn_style_hover.border_width_top = 2
	_assign_btn_style_hover.border_width_right = 2
	_assign_btn_style_hover.border_width_bottom = 2
	_assign_btn_style_hover.border_color = COLOR_BLUE
	_assign_btn_style_hover.corner_radius_top_left = 16
	_assign_btn_style_hover.corner_radius_top_right = 16
	_assign_btn_style_hover.corner_radius_bottom_right = 16
	_assign_btn_style_hover.corner_radius_bottom_left = 16

	_assign_btn_style_disabled = StyleBoxFlat.new()
	_assign_btn_style_disabled.bg_color = Color(0.95, 0.95, 0.95, 1)
	_assign_btn_style_disabled.border_width_left = 2
	_assign_btn_style_disabled.border_width_top = 2
	_assign_btn_style_disabled.border_width_right = 2
	_assign_btn_style_disabled.border_width_bottom = 2
	_assign_btn_style_disabled.border_color = Color(0.8, 0.8, 0.8, 1)
	_assign_btn_style_disabled.corner_radius_top_left = 16
	_assign_btn_style_disabled.corner_radius_top_right = 16
	_assign_btn_style_disabled.corner_radius_bottom_right = 16
	_assign_btn_style_disabled.corner_radius_bottom_left = 16

const _ASSIGN_NAME_MIN_WIDTH = 170
const _ASSIGN_ROLE_MIN_WIDTH = 160
const _ASSIGN_BTN_MIN_WIDTH = 120
const _ASSIGN_ROW_HEIGHT = 48
const _ASSIGN_COLOR_GRAY = Color(0.6, 0.6, 0.6, 1)
const _ASSIGN_COLOR_DARK = Color(0.15, 0.15, 0.15, 1)

func _create_assign_header_row() -> HBoxContainer:
	var row = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 30)

	var name_lbl = Label.new()
	name_lbl.text = tr("ASSIGN_COL_NAME")
	name_lbl.custom_minimum_size = Vector2(_ASSIGN_NAME_MIN_WIDTH, 0)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_color_override("font_color", _ASSIGN_COLOR_DARK)
	name_lbl.add_theme_font_size_override("font_size", 14)
	if UITheme:
		UITheme.apply_font(name_lbl, "bold")
	row.add_child(name_lbl)

	var role_lbl = Label.new()
	role_lbl.text = tr("ASSIGN_COL_ROLE")
	role_lbl.custom_minimum_size = Vector2(_ASSIGN_ROLE_MIN_WIDTH, 0)
	role_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	role_lbl.add_theme_color_override("font_color", _ASSIGN_COLOR_DARK)
	role_lbl.add_theme_font_size_override("font_size", 14)
	if UITheme:
		UITheme.apply_font(role_lbl, "bold")
	row.add_child(role_lbl)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(_ASSIGN_BTN_MIN_WIDTH, 0)
	row.add_child(spacer)

	return row

func _create_assign_employee_row(emp: EmployeeData, is_disabled: bool, disable_reason: String) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, _ASSIGN_ROW_HEIGHT)
	row.add_theme_constant_override("separation", 8)

	# Имя
	var name_lbl = Label.new()
	name_lbl.text = emp.get_display_name()
	name_lbl.custom_minimum_size = Vector2(_ASSIGN_NAME_MIN_WIDTH, 0)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 14)
	if is_disabled:
		name_lbl.add_theme_color_override("font_color", _ASSIGN_COLOR_GRAY)
	else:
		name_lbl.add_theme_color_override("font_color", _ASSIGN_COLOR_DARK)
	if UITheme:
		UITheme.apply_font(name_lbl, "regular")
	row.add_child(name_lbl)

	# Роль
	var role_lbl = Label.new()
	var role_text = tr(emp.job_title)
	if is_disabled and disable_reason != "":
		role_text += " " + disable_reason
	role_lbl.text = role_text
	role_lbl.custom_minimum_size = Vector2(_ASSIGN_ROLE_MIN_WIDTH, 0)
	role_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	role_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	role_lbl.add_theme_font_size_override("font_size", 14)
	var role_color = _get_assign_role_color(emp.job_title)
	role_lbl.add_theme_color_override("font_color", role_color if not is_disabled else _ASSIGN_COLOR_GRAY)
	if UITheme:
		UITheme.apply_font(role_lbl, "semibold")
	row.add_child(role_lbl)

	# Кнопка
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(_ASSIGN_BTN_MIN_WIDTH, 34)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 13)
	if UITheme:
		UITheme.apply_font(btn, "semibold")

	if is_disabled:
		btn.text = tr("ASSIGN_BTN")
		btn.disabled = true
		btn.add_theme_stylebox_override("normal", _assign_btn_style_disabled)
		btn.add_theme_stylebox_override("disabled", _assign_btn_style_disabled)
		btn.add_theme_color_override("font_color", _ASSIGN_COLOR_GRAY)
		btn.add_theme_color_override("font_disabled_color", _ASSIGN_COLOR_GRAY)
	else:
		btn.text = tr("ASSIGN_BTN")
		btn.add_theme_stylebox_override("normal", _assign_btn_style_normal)
		btn.add_theme_stylebox_override("hover", _assign_btn_style_hover)
		btn.add_theme_stylebox_override("pressed", _assign_btn_style_hover)
		btn.add_theme_color_override("font_color", COLOR_BLUE)
		btn.add_theme_color_override("font_hover_color", COLOR_WHITE)
		btn.add_theme_color_override("font_pressed_color", COLOR_WHITE)
		btn.pressed.connect(func():
			_assignment_overlay.visible = false
			if _assignment_callback.is_valid():
				_assignment_callback.call(emp)
		)

	row.add_child(btn)
	return row

func _get_assign_role_color(job_title: String) -> Color:
	const ProjectCardHelpers = preload("res://Scripts/project_card_helpers.gd")
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

func _rebuild():
	if _project == null:
		return

	for c in _top_vbox.get_children():
		c.queue_free()
	for column_list in _ticket_column_lists.values():
		for c in column_list.get_children():
			c.queue_free()
	_ticket_progress_labels.clear()

	var title_lbl: Label = _window.find_child("TitleLabel", true, false)
	var client = _project.get_client()
	var client_name = client.get_display_name() if client else _project.client_id
	title_lbl.text = _tr_format_safe("SUPPORT_WINDOW_TITLE", client_name, "Support — %s" % client_name)

	var sla_text = tr("SLA_" + _project.sla_level.to_upper())
	var sla_days = SupportProjectManager.get_sla_deadline_days(_project.sla_level)
	_top_vbox.add_child(_info_label(_tr_format_safe("SUPPORT_SLA_BADGE", [sla_text, sla_days], "SLA: %s (%d days)" % [sla_text, sla_days]), Color(0.1, 0.55, 0.55, 1), true))

	var eff_rate = SupportProjectManager.get_effective_daily_rate(_project)
	_top_vbox.add_child(_info_label(_tr_format_safe("SUPPORT_DAILY_RATE_LABEL", eff_rate, "Rate: $%d/day" % eff_rate), Color(0.2, 0.6, 0.2, 1), true))
	var remaining_days = SupportProjectManager._count_workdays_between(GameTime.day, _project.end_day) if _project.end_day >= GameTime.day else 0
	_top_vbox.add_child(_info_label(_tr_format_safe("SUPPORT_DURATION_INFO", [_project.contract_duration_days, remaining_days], "Duration: %d work days | %d left" % [_project.contract_duration_days, remaining_days]), Color(0.25, 0.45, 0.8, 1), false))

	var support_row = HBoxContainer.new()
	support_row.add_theme_constant_override("separation", 8)
	_top_vbox.add_child(support_row)

	var specialist_lbl = Label.new()
	specialist_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _project.assigned_support_employee:
		specialist_lbl.text = "🎧 %s" % _project.assigned_support_employee.get_display_name()
	else:
		specialist_lbl.text = tr("TICKET_NOT_ASSIGNED")
	specialist_lbl.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2, 1))
	specialist_lbl.add_theme_font_size_override("font_size", 14)
	if UITheme:
		UITheme.apply_font(specialist_lbl, "semibold")
	support_row.add_child(specialist_lbl)

	if _project.assigned_support_employee:
		var remove_btn = Button.new()
		remove_btn.text = tr("SUPPORT_REMOVE_SPECIALIST")
		remove_btn.custom_minimum_size = Vector2(160, 34)
		_style_blue_button(remove_btn)
		remove_btn.pressed.connect(func():
			_project.assigned_support_employee = null
			_rebuild()
		)
		support_row.add_child(remove_btn)
	else:
		var assign_btn = Button.new()
		assign_btn.text = tr("SUPPORT_ASSIGN_SPECIALIST")
		assign_btn.custom_minimum_size = Vector2(260, 34)
		_style_blue_button(assign_btn)
		assign_btn.pressed.connect(func():
			_open_assignment_popup("Customer Support", func(emp):
				_project.assigned_support_employee = emp
				_rebuild()
			)
		)
		support_row.add_child(assign_btn)

	if _project.assigned_support_employee == null:
		_top_vbox.add_child(_info_label(tr("SUPPORT_NO_SPECIALIST"), Color(0.9, 0.25, 0.2, 1), false))

	var open_count = 0
	var overdue_count = 0
	for t in _project.tickets:
		if t is SupportTicketData and not t.is_completed:
			open_count += 1
			if t.is_overdue:
				overdue_count += 1
	_top_vbox.add_child(_info_label(_tr_format_safe("SUPPORT_STATUS_TICKETS", [open_count, overdue_count], "Tickets: %d open / %d overdue" % [open_count, overdue_count]), COLOR_BLUE, false))
	_top_vbox.add_child(_info_label(_tr_format_safe("SUPPORT_WEEKLY_RATE", eff_rate * 5, "~$%d/wk" % (eff_rate * 5)), Color(0.2, 0.6, 0.2, 1), true))

	var column_counts := {
		"todo": 0,
		"in_progress": 0,
		"done": 0,
		"overdue": 0,
	}
	var sorted_tickets = _project.tickets.duplicate()
	sorted_tickets.sort_custom(func(a, b): return _ticket_sort_key(a) < _ticket_sort_key(b))
	for ticket in sorted_tickets:
		if ticket is SupportTicketData:
			var column_id = _get_ticket_column_id(ticket)
			column_counts[column_id] += 1
			var column_list: VBoxContainer = _ticket_column_lists.get(column_id, null)
			if column_list != null:
				column_list.add_child(_create_ticket_card(ticket))
	_update_ticket_column_headers(column_counts)

func _create_ticket_column(parent: HBoxContainer, column_id: String, title_key: String):
	var column = VBoxContainer.new()
	column.custom_minimum_size = Vector2(TICKET_COLUMN_WIDTH, 0)
	column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	parent.add_child(column)

	var title_lbl = Label.new()
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_color_override("font_color", COLOR_BLUE)
	if UITheme:
		UITheme.apply_font(title_lbl, "bold")
	column.add_child(title_lbl)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	var tickets_vbox = VBoxContainer.new()
	tickets_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(tickets_vbox)

	_ticket_column_lists[column_id] = tickets_vbox
	_ticket_column_headers[column_id] = {"label": title_lbl, "title_key": title_key}

func _update_ticket_column_headers(column_counts: Dictionary):
	for column_id in _ticket_column_headers.keys():
		var header = _ticket_column_headers[column_id]
		var label: Label = header.get("label", null)
		if label == null:
			continue
		var title_key: String = header.get("title_key", "")
		var title_text = tr(title_key)
		var count: int = column_counts.get(column_id, 0)
		label.text = _tr_format_safe("SUPPORT_COLUMN_TITLE_COUNT", [title_text, count], "%s (%d)" % [title_text, count])

func _get_ticket_column_id(ticket: SupportTicketData) -> String:
	if ticket.is_completed:
		return "done"
	if ticket.is_overdue:
		return "overdue"
	if ticket.assigned_worker == null:
		return "todo"
	return "in_progress"

func _info_label(text: String, color: Color, bold: bool) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	if UITheme:
		UITheme.apply_font(lbl, "bold" if bold else "regular")
	return lbl

func _ticket_sort_key(ticket: SupportTicketData) -> int:
	if ticket.is_overdue and not ticket.is_completed:
		return 0
	if not ticket.is_completed and ticket.assigned_worker == null:
		return 1
	if not ticket.is_completed and ticket.assigned_worker != null:
		return 2
	return 3

func _create_ticket_card(ticket: SupportTicketData) -> PanelContainer:
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var s = StyleBoxFlat.new()
	s.bg_color = Color(1, 1, 1, 1)
	s.border_width_left = 2
	s.border_width_top = 2
	s.border_width_right = 2
	s.border_width_bottom = 2
	s.corner_radius_top_left = 12
	s.corner_radius_top_right = 12
	s.corner_radius_bottom_left = 12
	s.corner_radius_bottom_right = 12

	var days_left = _count_workdays_left(GameTime.day, ticket.deadline_day)
	if ticket.is_completed:
		s.bg_color = Color(0.91, 0.98, 0.91, 1)
		s.border_color = Color(0.29803923, 0.6862745, 0.3137255, 1)
	elif ticket.is_overdue:
		s.bg_color = Color(0.99, 0.93, 0.93, 1)
		s.border_color = Color(0.8980392, 0.22352941, 0.20784314, 1)
	elif days_left == 1:
		s.bg_color = Color(1.0, 0.97, 0.9, 1)
		s.border_color = Color(0.95, 0.75, 0.15, 1)
	else:
		s.border_color = Color(0.85, 0.85, 0.85, 1)
	card.add_theme_stylebox_override("panel", s)

	var m = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 12)
	m.add_theme_constant_override("margin_top", 10)
	m.add_theme_constant_override("margin_right", 12)
	m.add_theme_constant_override("margin_bottom", 10)
	card.add_child(m)

	var root = VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	m.add_child(root)

	var role_icon = "📊"
	if ticket.required_role == "DEV":
		role_icon = "💻"
	elif ticket.required_role == "QA":
		role_icon = "🧪"
	var title_prefix = ""
	if ticket.was_unattended:
		title_prefix = "🔥 "
	root.add_child(_info_label("%s%s %s" % [title_prefix, role_icon, tr("ROLE_SHORT_" + ticket.required_role)], COLOR_BLUE, true))
	var progress_lbl = _info_label("%d / %d" % [int(ticket.progress), ticket.work_amount], COLOR_BLUE, false)
	root.add_child(progress_lbl)
	_ticket_progress_labels.append({"label": progress_lbl, "ticket": ticket})

	var date_txt = GameTime.get_date_short(ticket.deadline_day)
	root.add_child(_info_label(_tr_format_safe("TICKET_DEADLINE", [date_txt, max(days_left, 0)], "Deadline: %s (%d days left)" % [date_txt, max(days_left, 0)]), Color(0.4, 0.4, 0.4, 1), false))

	if ticket.was_unattended:
		root.add_child(_info_label(tr("TICKET_UNATTENDED"), Color(0.9, 0.3, 0.1, 1), false))

	if ticket.is_overdue and not ticket.is_completed:
		root.add_child(_info_label(tr("TICKET_OVERDUE"), Color(0.9, 0.2, 0.2, 1), true))
	if ticket.is_completed:
		root.add_child(_info_label(tr("TICKET_COMPLETED"), Color(0.2, 0.65, 0.25, 1), true))

	var worker_name = tr("TICKET_NOT_ASSIGNED")
	if ticket.assigned_worker:
		worker_name = "👤 " + ticket.assigned_worker.get_display_name()
	root.add_child(_info_label(worker_name, Color(0.3, 0.3, 0.3, 1), false))

	if not ticket.is_completed and not ticket.is_overdue:
		var btn = Button.new()
		btn.text = tr("TICKET_ASSIGN")
		btn.custom_minimum_size = Vector2(180, 34)
		_style_blue_button(btn)
		btn.pressed.connect(func():
			_open_assignment_popup(_role_to_job_title(ticket.required_role), func(emp):
				ticket.assigned_worker = emp
				_rebuild()
			)
		)
		root.add_child(btn)

	return card

func _style_blue_button(btn: Button):
	btn.add_theme_font_size_override("font_size", 13)
	btn.focus_mode = Control.FOCUS_NONE
	if UITheme:
		UITheme.apply_font(btn, "semibold")
	var btn_n = StyleBoxFlat.new()
	btn_n.bg_color = COLOR_WHITE
	btn_n.border_width_left = 2
	btn_n.border_width_top = 2
	btn_n.border_width_right = 2
	btn_n.border_width_bottom = 2
	btn_n.border_color = COLOR_BLUE
	btn_n.corner_radius_top_left = 16
	btn_n.corner_radius_top_right = 16
	btn_n.corner_radius_bottom_right = 16
	btn_n.corner_radius_bottom_left = 16
	var btn_h = StyleBoxFlat.new()
	btn_h.bg_color = COLOR_BLUE
	btn_h.border_width_left = 2
	btn_h.border_width_top = 2
	btn_h.border_width_right = 2
	btn_h.border_width_bottom = 2
	btn_h.border_color = COLOR_BLUE
	btn_h.corner_radius_top_left = 16
	btn_h.corner_radius_top_right = 16
	btn_h.corner_radius_bottom_right = 16
	btn_h.corner_radius_bottom_left = 16
	btn.add_theme_stylebox_override("normal", btn_n)
	btn.add_theme_stylebox_override("hover", btn_h)
	btn.add_theme_stylebox_override("pressed", btn_h)
	btn.add_theme_color_override("font_color", COLOR_BLUE)
	btn.add_theme_color_override("font_hover_color", COLOR_WHITE)
	btn.add_theme_color_override("font_pressed_color", COLOR_WHITE)

func _count_workdays_left(from_day: int, to_day: int) -> int:
	var count = 0
	for d in range(from_day + 1, to_day + 1):
		if not GameTime.is_weekend(d):
			count += 1
	return count

func _role_to_job_title(role: String) -> String:
	match role:
		"BA":
			return "Business Analyst"
		"DEV":
			return "Backend Developer"
		"QA":
			return "QA Engineer"
	return ""

func _open_assignment_popup(required_job_title: String, callback: Callable):
	_assignment_callback = callback
	for child in _assignment_rows_container.get_children():
		child.queue_free()

	var found_any = false

	for npc in get_tree().get_nodes_in_group("npc"):
		if not npc.data:
			continue
		var emp: EmployeeData = npc.data

		if required_job_title != "" and emp.job_title != required_job_title:
			continue

		var is_busy = _is_employee_busy(emp)
		var disable_reason = tr("EMP_SELECT_BUSY") if is_busy else ""
		var row = _create_assign_employee_row(emp, is_busy, disable_reason)
		_assignment_rows_container.add_child(row)
		found_any = true

	if not found_any:
		var empty_lbl = Label.new()
		empty_lbl.text = tr("ASSIGN_MENU_NO_STAFF")
		empty_lbl.add_theme_color_override("font_color", _ASSIGN_COLOR_GRAY)
		empty_lbl.add_theme_font_size_override("font_size", 14)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if UITheme:
			UITheme.apply_font(empty_lbl, "regular")
		_assignment_rows_container.add_child(empty_lbl)

	_assignment_overlay.visible = true

func _is_employee_busy(emp: EmployeeData) -> bool:
	if SupportProjectManager.is_employee_on_support(emp):
		return true
	if SupportProjectManager.is_employee_on_ticket(emp):
		return true
	for project in ProjectManager.active_projects:
		if project.state == ProjectData.State.FINISHED or project.state == ProjectData.State.FAILED:
			continue
		for stage in project.stages:
			for worker in stage.workers:
				if worker == emp:
					return true
	return false

func _process(_delta):
	if not visible or _project == null:
		return
	for entry in _ticket_progress_labels:
		var ticket = entry.get("ticket")
		var label: Label = entry.get("label")
		if not is_instance_valid(label):
			continue
		if ticket == null:
			continue
		if ticket is SupportTicketData:
			label.text = "%d / %d" % [int(ticket.progress), ticket.work_amount]
	var key = GameTime.hour * 60 + GameTime.minute
	if key != _last_refresh_key:
		_last_refresh_key = key
		_rebuild()

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		if _assignment_overlay.visible:
			_assignment_overlay.visible = false
		else:
			_close_window()
		get_viewport().set_input_as_handled()
