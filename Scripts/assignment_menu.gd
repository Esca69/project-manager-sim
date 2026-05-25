extends Control

signal employee_assigned
signal menu_closed

const ProjectCardHelpers = preload("res://Scripts/project_card_helpers.gd")

# Ссылка на стол, который сейчас ждёт назначения
var target_desk = null

@onready var close_btn = find_child("CloseButton", true, false)

const COLOR_BLUE = Color(0.17254902, 0.30980393, 0.5686275, 1)
const COLOR_WHITE = Color(1, 1, 1, 1)
const COLOR_GRAY = Color(0.6, 0.6, 0.6, 1)
const COLOR_DARK = Color(0.15, 0.15, 0.15, 1)
const ROW_HEIGHT = 48
const NAME_MIN_WIDTH = 170
const ROLE_MIN_WIDTH = 220
const BTN_MIN_WIDTH = 120

var _overlay: ColorRect
var _was_paused: bool = false
var _scroll: ScrollContainer
var _rows_container: VBoxContainer

# Стили кнопок
var _btn_style_normal: StyleBoxFlat
var _btn_style_hover: StyleBoxFlat
var _btn_style_disabled: StyleBoxFlat

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 90
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# === ЗАТЕМНЕНИЕ ФОНА ===
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.45)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)
	move_child(_overlay, 0)

	# === УМНОЕ УДАЛЕНИЕ КНОПОК (кроме CloseButton) ===
	var all_buttons = find_children("*", "Button", true, false)
	for btn in all_buttons:
		if close_btn and btn != close_btn:
			btn.queue_free()

	if close_btn:
		if not close_btn.pressed.is_connected(_on_close_pressed):
			close_btn.pressed.connect(_on_close_pressed)

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
	var old_cancel = find_child("CancelButton", true, false)
	if old_cancel:
		old_cancel.queue_free()

	# === СОЗДАЁМ НОВЫЙ LAYOUT: ScrollContainer + VBoxContainer ===
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
	name_lbl.add_theme_color_override("font_color", COLOR_BLUE)
	name_lbl.add_theme_font_size_override("font_size", 14)
	if UITheme:
		UITheme.apply_font(name_lbl, "bold")
	row.add_child(name_lbl)

	var role_lbl = Label.new()
	role_lbl.text = tr("ASSIGN_COL_ROLE")
	role_lbl.custom_minimum_size = Vector2(ROLE_MIN_WIDTH, 0)
	role_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	role_lbl.add_theme_color_override("font_color", COLOR_BLUE)
	role_lbl.add_theme_font_size_override("font_size", 14)
	if UITheme:
		UITheme.apply_font(role_lbl, "bold")
	row.add_child(role_lbl)

	# Пустое место под кнопку
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(BTN_MIN_WIDTH, 0)
	row.add_child(spacer)

	return row

# --- Вызывает Стол, когда хочет посадить/заменить сотрудника ---
func open_assignment_list(desk_node):
	z_index = 95
	_was_paused = GameTime.is_game_paused
	GameTime.set_paused(true)
	target_desk = desk_node
	_refresh_list()
	mouse_filter = Control.MOUSE_FILTER_STOP
	if UITheme:
		UITheme.fade_in(self, 0.2)
	else:
		visible = true

# --- Заполняем список сотрудниками ---
func _refresh_list():
	for child in _rows_container.get_children():
		child.queue_free()

	var all_npcs = get_tree().get_nodes_in_group("npc")
	var found_any = false

	var current_employee_data = target_desk.assigned_employee if target_desk else null

	for npc in all_npcs:
		if npc.data:
			var is_current = (current_employee_data and npc.data == current_employee_data)
			var row = _create_employee_row(npc, is_current)
			_rows_container.add_child(row)
			found_any = true

	if not found_any:
		var empty_lbl = Label.new()
		empty_lbl.text = tr("ASSIGN_MENU_NO_STAFF")
		empty_lbl.add_theme_color_override("font_color", COLOR_GRAY)
		empty_lbl.add_theme_font_size_override("font_size", 14)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if UITheme:
			UITheme.apply_font(empty_lbl, "regular")
		_rows_container.add_child(empty_lbl)

func _create_employee_row(npc_node, is_current: bool) -> HBoxContainer:
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
	if is_current:
		name_lbl.add_theme_color_override("font_color", COLOR_GRAY)
	else:
		name_lbl.add_theme_color_override("font_color", COLOR_BLUE)
	if UITheme:
		UITheme.apply_font(name_lbl, "regular")
	row.add_child(name_lbl)

	# Роль
	var role_lbl = Label.new()
	role_lbl.text = tr(npc_node.data.job_title)
	role_lbl.custom_minimum_size = Vector2(ROLE_MIN_WIDTH, 0)
	role_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	role_lbl.clip_text = true
	role_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	role_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	role_lbl.add_theme_font_size_override("font_size", 14)
	var role_color = _get_role_color(npc_node.data.job_title)
	role_lbl.add_theme_color_override("font_color", role_color if not is_current else COLOR_GRAY)
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

	if is_current:
		btn.text = tr("ASSIGN_BTN_ASSIGNED")
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
		btn.pressed.connect(_on_assign_pressed.bind(npc_node))

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

# --- Ищем стол, за которым уже сидит данный NPC ---
func _find_desk_with_npc(npc_node):
	var all_desks = get_tree().get_nodes_in_group("desk")
	for desk in all_desks:
		if "assigned_npc_node" in desk and desk.assigned_npc_node == npc_node:
			return desk
	return null

# --- Когда нажали кнопку "Назначить" ---
func _on_assign_pressed(npc_node):
	if npc_node == null:
		return

	if target_desk:
		if target_desk.assigned_npc_node == npc_node:
			print(tr("LOG_WARN_ALREADY_AT_DESK"))
			_on_close_pressed()
			return

		if target_desk.assigned_employee:
			var old_npc = target_desk.unassign_employee()
			if old_npc and old_npc.has_method("release_from_desk"):
				old_npc.release_from_desk()
				print(tr("LOG_EMP_RELEASED") % old_npc.data.get_display_name())

		var old_desk = _find_desk_with_npc(npc_node)
		if old_desk and old_desk != target_desk:
			old_desk.unassign_employee()
			print(tr("LOG_EMP_MOVED_DESK") % [npc_node.data.get_display_name(), old_desk.name])

		target_desk.assign_employee(npc_node.data, npc_node)
		# Проверяем, отсутствует ли сотрудник (болезнь, отпуск, обучение и т.д.)
		var absent_states = [
			npc_node.State.SICK_LEAVE, npc_node.State.DAY_OFF, npc_node.State.ON_VACATION,
			npc_node.State.ON_TRAINING, npc_node.State.UNPAID_LEAVE,
			npc_node.State.HOME, npc_node.State.GOING_HOME
		]
		if npc_node.current_state in absent_states:
			npc_node.my_desk_position = target_desk.seat_point.global_position
		else:
			npc_node.move_to_desk(target_desk.seat_point.global_position)
		print(tr("LOG_EMP_ORDER_DESK") % npc_node.data.get_display_name())

		# === ТУТОРИАЛ: уведомляем о назначении за стол ===
		TutorialManager.notify_worker_assigned()

	emit_signal("employee_assigned")
	_on_close_pressed()

func _on_close_pressed():
	z_index = 90
	if not _was_paused:
		GameTime.set_paused(false)
	target_desk = null
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	emit_signal("menu_closed")
	if UITheme:
		UITheme.fade_out(self, 0.15)
	else:
		visible = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and visible:
		_on_close_pressed()
		get_viewport().set_input_as_handled()
