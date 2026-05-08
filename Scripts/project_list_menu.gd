extends Control

signal project_opened(proj)
const CardHelpers = preload("res://Scripts/project_card_helpers.gd")

@onready var cards_container = $Window/MainVBox/CardsMargin/ScrollContainer/CardsContainer
@onready var close_btn = find_child("CloseButton", true, false)
@onready var empty_label = $Window/MainVBox/CardsMargin/ScrollContainer/CardsContainer/EmptyLabel
@onready var title_label = $Window/MainVBox/HeaderPanel/TitleLabel

var _current_tab: String = "active"
var _tab_container: HBoxContainer
var _btn_tab_active: Button
var _btn_tab_completed: Button

var btn_style: StyleBoxFlat
var btn_style_hover: StyleBoxFlat

# --- СТИЛИ ДЛЯ НОВОГО ДИЗАЙНА ПЕРЕКЛЮЧАТЕЛЯ ---
var tab_bg_style: StyleBoxFlat
var tab_active_style: StyleBoxFlat
var tab_inactive_style: StyleBoxFlat

const COLOR_BLUE = Color(0.17254902, 0.30980393, 0.5686275, 1)
const COLOR_GRAY = Color(0.5, 0.5, 0.5, 1)
const COLOR_BUDGET_GREEN = Color(0.29803923, 0.6862745, 0.3137255, 1)
const COLOR_SOFT_DEADLINE = Color(1.0, 0.55, 0.0, 1)
const COLOR_HARD_DEADLINE = Color(0.8980392, 0.22352941, 0.20784314, 1)
const COLOR_WARNING = Color(0.9, 0.5, 0.1, 1)

# === ДОБАВЛЕНО ДЛЯ ФОНА ===
var _overlay: ColorRect

func _tr_format_safe(key: String, args, fallback: String) -> String:
	var text = tr(key)
	if text.find("%") >= 0:
		return text % args
	return fallback

func _ready():
	visible = false
	z_index = 90
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_force_fullscreen_size()
	
	if title_label:
		title_label.text = tr("TITLE_MY_PROJECTS")
		
	# === ДОБАВЛЯЕМ ЗАТЕМНЕНИЕ ФОНА (OVERLAY) ===
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.45)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)
	move_child(_overlay, 0) # Помещаем на самый задний план
	
	if close_btn:
		close_btn.pressed.connect(_on_close_pressed)
		if UITheme: UITheme.apply_font(close_btn, "semibold")

	var scroll = cards_container.get_parent()
	if scroll and scroll is ScrollContainer:
		scroll.clip_contents = true

	# --- СТИЛИ КНОПОК ПРОЕКТОВ ---
	btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(1, 1, 1, 1)
	btn_style.border_width_left = 2
	btn_style.border_width_top = 2
	btn_style.border_width_right = 2
	btn_style.border_width_bottom = 2
	btn_style.border_color = COLOR_BLUE
	btn_style.corner_radius_top_left = 20
	btn_style.corner_radius_top_right = 20
	btn_style.corner_radius_bottom_right = 20
	btn_style.corner_radius_bottom_left = 20

	btn_style_hover = StyleBoxFlat.new()
	btn_style_hover.bg_color = COLOR_BLUE
	btn_style_hover.border_width_left = 2
	btn_style_hover.border_width_top = 2
	btn_style_hover.border_width_right = 2
	btn_style_hover.border_width_bottom = 2
	btn_style_hover.border_color = COLOR_BLUE
	btn_style_hover.corner_radius_top_left = 20
	btn_style_hover.corner_radius_top_right = 20
	btn_style_hover.corner_radius_bottom_right = 20
	btn_style_hover.corner_radius_bottom_left = 20
	
	# --- СТИЛИ КРАСИВЫХ ТАБОВ (PILL-ДИЗАЙН) ---
	tab_bg_style = StyleBoxFlat.new()
	tab_bg_style.bg_color = Color(0.92, 0.94, 0.96, 1) # Мягкий серо-голубой фон
	tab_bg_style.corner_radius_top_left = 24
	tab_bg_style.corner_radius_top_right = 24
	tab_bg_style.corner_radius_bottom_right = 24
	tab_bg_style.corner_radius_bottom_left = 24
	
	tab_active_style = StyleBoxFlat.new()
	tab_active_style.bg_color = Color(1, 1, 1, 1) # Белая плашка активного таба
	tab_active_style.corner_radius_top_left = 20
	tab_active_style.corner_radius_top_right = 20
	tab_active_style.corner_radius_bottom_right = 20
	tab_active_style.corner_radius_bottom_left = 20
	tab_active_style.shadow_color = Color(0, 0, 0, 0.08) # Легкая тень
	tab_active_style.shadow_size = 4
	tab_active_style.shadow_offset = Vector2(0, 2)
	
	tab_inactive_style = StyleBoxFlat.new()
	tab_inactive_style.bg_color = Color(1, 1, 1, 0) # Полностью прозрачный фон
	
	_create_tabs()

func _force_fullscreen_size():
	var vp_size = get_viewport().get_visible_rect().size
	position = Vector2.ZERO
	size = vp_size

func _create_tabs():
	var main_vbox = $Window/MainVBox
	var cards_margin = $Window/MainVBox/CardsMargin
	
	# Главный контейнер-пилюля
	var tab_panel = PanelContainer.new()
	tab_panel.add_theme_stylebox_override("panel", tab_bg_style)
	tab_panel.custom_minimum_size = Vector2(460, 50)
	tab_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tab_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Отступ внутри пилюли
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	tab_panel.add_child(margin)
	
	_tab_container = HBoxContainer.new()
	_tab_container.add_theme_constant_override("separation", 8)
	margin.add_child(_tab_container)
	
	# Отступы снаружи всего блока табов
	var container_margin = MarginContainer.new()
	container_margin.add_theme_constant_override("margin_top", 10)
	container_margin.add_theme_constant_override("margin_bottom", 15)
	container_margin.add_child(tab_panel)
	
	main_vbox.add_child(container_margin)
	main_vbox.move_child(container_margin, cards_margin.get_index()) # Ставим перед скроллом
	
	# Кнопки
	_btn_tab_active = Button.new()
	_btn_tab_active.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_tab_active.focus_mode = Control.FOCUS_NONE
	if UITheme: UITheme.apply_font(_btn_tab_active, "bold")
	_btn_tab_active.pressed.connect(_on_tab_pressed.bind("active"))
	_tab_container.add_child(_btn_tab_active)
	
	_btn_tab_completed = Button.new()
	_btn_tab_completed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_tab_completed.focus_mode = Control.FOCUS_NONE
	if UITheme: UITheme.apply_font(_btn_tab_completed, "bold")
	_btn_tab_completed.pressed.connect(_on_tab_pressed.bind("completed"))
	_tab_container.add_child(_btn_tab_completed)

# НОВАЯ ФУНКЦИЯ: Жесткое применение стилей, чтобы перебить темы Godot
func _apply_button_style(btn: Button, box_style: StyleBox, font_color: Color):
	btn.add_theme_stylebox_override("normal", box_style)
	btn.add_theme_stylebox_override("hover", box_style)
	btn.add_theme_stylebox_override("pressed", box_style)
	btn.add_theme_stylebox_override("focus", box_style)
	
	btn.add_theme_color_override("font_color", font_color)
	btn.add_theme_color_override("font_hover_color", font_color)
	btn.add_theme_color_override("font_pressed_color", font_color)
	btn.add_theme_color_override("font_focus_color", font_color)

func _update_tab_styles():
	# Надежно присваиваем переводы
	_btn_tab_active.text = tr("TAB_ACTIVE_PROJECTS")
	_btn_tab_completed.text = tr("TAB_COMPLETED_PROJECTS")

	if _current_tab == "active":
		_apply_button_style(_btn_tab_active, tab_active_style, COLOR_BLUE)
		_apply_button_style(_btn_tab_completed, tab_inactive_style, COLOR_GRAY)
	else:
		_apply_button_style(_btn_tab_completed, tab_active_style, COLOR_BLUE)
		_apply_button_style(_btn_tab_active, tab_inactive_style, COLOR_GRAY)

func _on_tab_pressed(tab_name: String):
	if _current_tab == tab_name:
		return
	_current_tab = tab_name
	_rebuild_cards()

func open_menu():
	_force_fullscreen_size()
	_current_tab = "active"
	_rebuild_cards()
	if UITheme:
		UITheme.fade_in(self, 0.2)
	else:
		visible = true

func _on_close_pressed():
	_kill_all_tooltips()
	if UITheme:
		UITheme.fade_out(self, 0.15)
	else:
		visible = false

func _kill_all_tooltips():
	for tp in get_tree().get_nodes_in_group("project_list_tooltip"):
		if is_instance_valid(tp):
			tp.queue_free()

func _get_project_finish_time(proj: ProjectData) -> float:
	var last_end = 0.0
	for s in proj.stages:
		if s.get("actual_end", -1.0) > last_end:
			last_end = s["actual_end"]
	return proj.start_global_time + last_end

func _rebuild_cards():
	_update_tab_styles()
	_kill_all_tooltips()
	
	for child in cards_container.get_children():
		if child == empty_label:
			continue
		cards_container.remove_child(child)
		child.queue_free()

	# Фильтрация: "active" — из active_projects, "completed" — из completed_projects
	var filtered_projects: Array = []
	if _current_tab == "active":
		for proj in ProjectManager.active_projects:
			var is_done = (proj.state == ProjectData.State.FINISHED or proj.state == ProjectData.State.FAILED)
			if not is_done:
				filtered_projects.append(proj)
		for support_proj in SupportProjectManager.active_support_projects:
			if support_proj.is_active:
				filtered_projects.append(support_proj)
	else:
		filtered_projects = ProjectManager.completed_projects.duplicate()

	if filtered_projects.is_empty():
		empty_label.text = tr("PROJ_LIST_EMPTY")
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
		if UITheme: UITheme.apply_font(empty_label, "semibold")
		
		empty_label.visible = true
		return

	empty_label.visible = false

	# Сортировка
	filtered_projects.sort_custom(func(proj_a, proj_b):
		if proj_a is SupportProjectData and proj_b is ProjectData:
			return true
		if proj_a is ProjectData and proj_b is SupportProjectData:
			return false
		if _current_tab == "completed":
			var time_a = _get_project_finish_time(proj_a)
			var time_b = _get_project_finish_time(proj_b)
			return time_a > time_b
		else:
			return proj_a.created_at_day < proj_b.created_at_day
	)

	for proj in filtered_projects:
		var card = _create_card(proj)
		cards_container.add_child(card)

func _make_card_style(proj: ProjectData) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_right = 20
	style.corner_radius_bottom_left = 20
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3

	match proj.state:
		ProjectData.State.FINISHED:
			style.bg_color = Color(0.9, 0.95, 0.9, 1)
			style.border_color = Color(0.29803923, 0.6862745, 0.3137255, 1)
		ProjectData.State.FAILED:
			style.bg_color = Color(0.98, 0.92, 0.92, 1)
			style.border_color = Color(0.8980392, 0.22352941, 0.20784314, 1)
		_:
			style.bg_color = Color(1, 1, 1, 1)
			style.border_color = Color(0.8784314, 0.8784314, 0.8784314, 1)

	if UITheme: UITheme.apply_shadow(style)
	return style

func _make_card_style_hover(proj: ProjectData) -> StyleBoxFlat:
	var style = _make_card_style(proj)
	match proj.state:
		ProjectData.State.FINISHED:
			style.border_color = Color(0.2, 0.55, 0.25, 1)
			style.bg_color = Color(0.87, 0.94, 0.87, 1)
		ProjectData.State.FAILED:
			style.border_color = Color(0.75, 0.18, 0.17, 1)
			style.bg_color = Color(0.96, 0.89, 0.89, 1)
		_:
			style.border_color = Color(0.17254902, 0.30980393, 0.5686275, 1)
			style.bg_color = Color(0.96, 0.97, 1.0, 1)
	return style

func _set_children_pass_filter(node: Node):
	for child in node.get_children():
		if child is Button:
			child.mouse_filter = Control.MOUSE_FILTER_PASS
		elif child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_PASS
		_set_children_pass_filter(child)

func _create_card(proj) -> PanelContainer:
	if proj is SupportProjectData:
		return _create_support_card(proj)

	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style_normal = _make_card_style(proj)
	var style_hover = _make_card_style_hover(proj)
	card.add_theme_stylebox_override("panel", style_normal)

	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_entered.connect(func():
		card.add_theme_stylebox_override("panel", style_hover)
	)
	card.mouse_exited.connect(func():
		card.add_theme_stylebox_override("panel", style_normal)
	)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	card.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	margin.add_child(vbox)

	var top_hbox = HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(top_hbox)

	var left_info = VBoxContainer.new()
	left_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_info.add_theme_constant_override("separation", 6)
	top_hbox.add_child(left_info)

	left_info.add_child(_create_card_header(proj))

	var status_lbl = Label.new()
	match proj.state:
		ProjectData.State.DRAFTING:
			status_lbl.text = tr("PROJ_LIST_STATUS_DRAFT")
			status_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
		ProjectData.State.IN_PROGRESS:
			var stage_name = _get_current_stage_name(proj)
			status_lbl.text = tr("PROJ_LIST_STATUS_IN_PROGRESS") % stage_name
			status_lbl.add_theme_color_override("font_color", Color(0.17254902, 0.30980393, 0.5686275, 1))
		ProjectData.State.FINISHED:
			status_lbl.text = "✅ " + tr("PROJECT_STATE_FINISHED")
			status_lbl.add_theme_color_override("font_color", Color(0.29803923, 0.6862745, 0.3137255, 1))
		ProjectData.State.FAILED:
			status_lbl.text = tr("PROJ_LIST_FAILED_DEADLINE")
			status_lbl.add_theme_color_override("font_color", Color(0.8980392, 0.22352941, 0.20784314, 1))
	if UITheme: UITheme.apply_font(status_lbl, "regular")
	left_info.add_child(status_lbl)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(spacer)

	var right_info = VBoxContainer.new()
	right_info.add_theme_constant_override("separation", 6)
	right_info.alignment = BoxContainer.ALIGNMENT_END
	top_hbox.add_child(right_info)
	right_info.add_child(_create_budget_section(proj))

	var is_active_layout = proj.state == ProjectData.State.DRAFTING or proj.state == ProjectData.State.IN_PROGRESS
	if is_active_layout:
		if proj.state == ProjectData.State.DRAFTING:
			vbox.add_child(_create_draft_warning_bar())
		vbox.add_child(_create_stages_section(proj, card))
		vbox.add_child(_create_deadlines_section(proj))

	call_deferred("_set_children_pass_filter", card)

	return card

func _create_card_header(proj) -> Control:
	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 8)

	var client_prefix = ""
	if proj.client_id != "":
		var client = proj.get_client()
		if client:
			client_prefix = client.get_display_name() + "  —  "

	var status_prefix = ""
	if proj.state == ProjectData.State.FINISHED:
		status_prefix = "✅ "
	elif proj.state == ProjectData.State.FAILED:
		status_prefix = "❌ "

	var name_lbl = Label.new()
	name_lbl.text = status_prefix + client_prefix + proj.get_display_title()
	name_lbl.add_theme_color_override("font_color", COLOR_BLUE)
	name_lbl.add_theme_font_size_override("font_size", 20)
	if UITheme: UITheme.apply_font(name_lbl, "bold")
	header_hbox.add_child(name_lbl)

	var category_badge = CardHelpers.create_category_badge(proj.category, self)
	header_hbox.add_child(category_badge)

	return header_hbox

func _create_draft_warning_bar() -> PanelContainer:
	var bar = PanelContainer.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style = StyleBoxFlat.new()
	style.bg_color = Color(COLOR_WARNING.r, COLOR_WARNING.g, COLOR_WARNING.b, 0.12)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = COLOR_WARNING
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	bar.add_theme_stylebox_override("panel", style)

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
	title_lbl.text = tr("PROJ_LIST_DRAFT_WARN_TITLE")
	title_lbl.add_theme_color_override("font_color", COLOR_WARNING)
	if UITheme: UITheme.apply_font(title_lbl, "bold")
	vbox.add_child(title_lbl)

	var hint_lbl = Label.new()
	hint_lbl.text = tr("PROJ_LIST_DRAFT_WARN_HINT")
	hint_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
	hint_lbl.add_theme_font_size_override("font_size", 13)
	if UITheme: UITheme.apply_font(hint_lbl, "regular")
	vbox.add_child(hint_lbl)

	return bar

func _create_stages_section(proj: ProjectData, card: PanelContainer) -> Control:
	var stages_vbox = VBoxContainer.new()
	stages_vbox.add_theme_constant_override("separation", 4)
	stages_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var stage_rows: Array = []
	for i in range(proj.stages.size()):
		var stage_data = _create_stage_row(proj.stages[i], i, proj)
		stages_vbox.add_child(stage_data["row"])
		stage_rows.append({
			"row": stage_data["row"],
			"scope_label": stage_data["scope_label"],
			"status_label": stage_data["status_label"],
			"stage_index": i
		})

	card.set_meta("stage_rows", stage_rows)
	card.set_meta("project_ref", proj)
	return stages_vbox

func _create_stage_row(stage, stage_index: int, proj: ProjectData) -> Dictionary:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var specialist_lbl = Label.new()
	specialist_lbl.text = tr("PROJ_SPECIALIST_LABEL")
	specialist_lbl.add_theme_color_override("font_color", COLOR_BLUE)
	specialist_lbl.add_theme_font_size_override("font_size", 14)
	if UITheme: UITheme.apply_font(specialist_lbl, "semibold")
	row.add_child(specialist_lbl)

	var role_lbl = Label.new()
	var role_key = "ROLE_SHORT_" + str(stage.type)
	var role_text = tr(role_key)
	if role_text == role_key:
		role_text = str(stage.type).to_upper()
	role_lbl.text = role_text
	role_lbl.add_theme_color_override("font_color", CardHelpers.get_role_color(stage.type))
	role_lbl.add_theme_font_size_override("font_size", 14)
	if UITheme: UITheme.apply_font(role_lbl, "semibold")
	row.add_child(role_lbl)

	var assignee_lbl = Label.new()
	var assignee_data = _format_stage_assignees(stage)
	assignee_lbl.text = " (%s)" % assignee_data["text"]
	assignee_lbl.add_theme_color_override("font_color", COLOR_GRAY if assignee_data["is_unassigned"] else COLOR_BLUE)
	assignee_lbl.add_theme_font_size_override("font_size", 13)
	if UITheme: UITheme.apply_font(assignee_lbl, "regular")
	row.add_child(assignee_lbl)

	if proj.state == ProjectData.State.DRAFTING and assignee_data["is_unassigned"]:
		var warn_lbl = Label.new()
		warn_lbl.text = "⚠"
		warn_lbl.add_theme_color_override("font_color", COLOR_WARNING)
		if UITheme: UITheme.apply_font(warn_lbl, "bold")
		row.add_child(warn_lbl)
		CardHelpers.attach_tooltip(warn_lbl, self, tr("PROJ_LIST_DRAFT_STAGE_HINT"), COLOR_WARNING, "project_list_tooltip")

	var scope_lbl = Label.new()
	scope_lbl.add_theme_color_override("font_color", COLOR_BLUE)
	scope_lbl.add_theme_font_size_override("font_size", 14)
	if UITheme: UITheme.apply_font(scope_lbl, "regular")
	row.add_child(scope_lbl)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var status_lbl = Label.new()
	status_lbl.add_theme_font_size_override("font_size", 13)
	if UITheme: UITheme.apply_font(status_lbl, "semibold")
	row.add_child(status_lbl)

	_update_stage_row_labels(scope_lbl, status_lbl, proj, stage_index)

	return {
		"row": row,
		"scope_label": scope_lbl,
		"status_label": status_lbl,
	}

func _create_deadlines_section(proj: ProjectData) -> Control:
	var deadlines_vbox = VBoxContainer.new()
	deadlines_vbox.add_theme_constant_override("separation", 3)

	var soft_row = HBoxContainer.new()
	soft_row.add_theme_constant_override("separation", 6)
	deadlines_vbox.add_child(soft_row)

	var soft_days_left = maxi(0, proj.soft_deadline_day - GameTime.day)
	var soft_lbl = Label.new()
	soft_lbl.text = tr("PROJ_LIST_SOFT_INFO_V2") % [GameTime.get_date_short(proj.soft_deadline_day), soft_days_left, proj.soft_deadline_penalty_percent]
	soft_lbl.add_theme_color_override("font_color", COLOR_SOFT_DEADLINE)
	if UITheme: UITheme.apply_font(soft_lbl, "regular")
	soft_row.add_child(soft_lbl)

	var soft_help = CardHelpers.create_help_button()
	CardHelpers.attach_tooltip(soft_help, self, tr("PROJ_SOFT_DEADLINE_TOOLTIP") % proj.soft_deadline_penalty_percent, COLOR_SOFT_DEADLINE, "project_list_tooltip")
	soft_row.add_child(soft_help)

	var hard_row = HBoxContainer.new()
	hard_row.add_theme_constant_override("separation", 6)
	deadlines_vbox.add_child(hard_row)

	var hard_days_left = maxi(0, proj.deadline_day - GameTime.day)
	var hard_lbl = Label.new()
	hard_lbl.text = tr("PROJ_LIST_HARD_INFO_V2") % [GameTime.get_date_short(proj.deadline_day), hard_days_left]
	hard_lbl.add_theme_color_override("font_color", COLOR_HARD_DEADLINE)
	if UITheme: UITheme.apply_font(hard_lbl, "semibold")
	hard_row.add_child(hard_lbl)

	var hard_help = CardHelpers.create_help_button()
	CardHelpers.attach_tooltip(hard_help, self, tr("PROJ_HARD_DEADLINE_TOOLTIP"), COLOR_HARD_DEADLINE, "project_list_tooltip")
	hard_row.add_child(hard_help)

	return deadlines_vbox

func _create_budget_section(proj: ProjectData) -> Control:
	var budget_vbox = VBoxContainer.new()
	budget_vbox.add_theme_constant_override("separation", 6)
	budget_vbox.alignment = BoxContainer.ALIGNMENT_END

	var budget_lbl = Label.new()
	var current_payout = proj.budget
	var is_penalty = false
	var is_failed = false

	if proj.state == ProjectData.State.FAILED:
		current_payout = 0
		is_failed = true
	elif proj.state == ProjectData.State.FINISHED:
		var finish_day = proj.created_at_day
		if proj.start_global_time > 0:
			var last_end = 0.0
			for s in proj.stages:
				if s.get("actual_end", -1.0) > last_end:
					last_end = s["actual_end"]
			finish_day = int(proj.start_global_time + last_end)
		current_payout = proj.get_final_payout(finish_day)
		if current_payout < proj.budget:
			is_penalty = true
	else:
		current_payout = proj.get_final_payout(GameTime.day)
		if current_payout < proj.budget:
			is_penalty = true

	if is_failed:
		budget_lbl.text = tr("PROJ_LIST_BUDGET_FAILED")
		budget_lbl.add_theme_color_override("font_color", Color(0.85, 0.21, 0.21))
	elif is_penalty:
		budget_lbl.text = tr("PROJECT_BUDGET") % current_payout
		budget_lbl.add_theme_color_override("font_color", Color(0.9, 0.72, 0.04))
	else:
		budget_lbl.text = tr("PROJECT_BUDGET") % proj.budget
		budget_lbl.add_theme_color_override("font_color", COLOR_BUDGET_GREEN)

	budget_lbl.add_theme_font_size_override("font_size", 20)
	budget_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if UITheme: UITheme.apply_font(budget_lbl, "bold")
	budget_vbox.add_child(budget_lbl)

	var open_btn = Button.new()
	open_btn.text = tr("UI_OPEN")
	open_btn.custom_minimum_size = Vector2(180, 40)
	open_btn.add_theme_color_override("font_color", COLOR_BLUE)
	open_btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	open_btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	open_btn.add_theme_stylebox_override("normal", btn_style)
	open_btn.add_theme_stylebox_override("hover", btn_style_hover)
	open_btn.add_theme_stylebox_override("pressed", btn_style_hover)
	if UITheme: UITheme.apply_font(open_btn, "semibold")
	open_btn.pressed.connect(_on_open_pressed.bind(proj))
	budget_vbox.add_child(open_btn)

	return budget_vbox

func _format_stage_assignees(stage) -> Dictionary:
	var workers: Array = stage.get("workers", [])
	var names: Array[String] = []
	for worker in workers:
		if worker is EmployeeData:
			names.append(worker.get_display_name())

	if names.is_empty():
		return {"text": tr("PROJ_LIST_NOT_ASSIGNED"), "is_unassigned": true}
	if names.size() <= 3:
		return {"text": ", ".join(names), "is_unassigned": false}
	return {"text": "%s, %s%s" % [names[0], names[1], tr("PROJ_LIST_ASSIGNEE_MORE") % (names.size() - 2)], "is_unassigned": false}

func _get_current_stage_name(proj: ProjectData) -> String:
	for i in range(proj.stages.size()):
		var stage = proj.stages[i]
		if stage.get("is_completed", false):
			continue
		if i > 0 and not proj.stages[i - 1].get("is_completed", false):
			continue
		match stage.type:
			"BA":
				return tr("STAGE_BA")
			"DEV":
				return tr("STAGE_DEV")
			"QA":
				return tr("STAGE_QA")
		return str(stage.type)
	return "—"

func _is_stage_active(proj: ProjectData, stage_index: int) -> bool:
	if proj.state != ProjectData.State.IN_PROGRESS:
		return false
	var stage = proj.stages[stage_index]
	if stage.get("is_completed", false):
		return false
	if stage_index == 0:
		return true
	return proj.stages[stage_index - 1].get("is_completed", false)

func _get_stage_status_data(proj: ProjectData, stage_index: int) -> Dictionary:
	var stage = proj.stages[stage_index]
	if stage.get("is_completed", false):
		return {"text": tr("PROJ_LIST_STAGE_COMPLETED"), "color": COLOR_BUDGET_GREEN}
	if _is_stage_active(proj, stage_index):
		var pct = 0
		if stage.amount > 0:
			pct = int((float(stage.progress) / float(stage.amount)) * 100.0)
		pct = clampi(pct, 0, 100)
		return {"text": tr("PROJ_LIST_STAGE_IN_PROGRESS") % pct, "color": COLOR_BLUE}
	return {"text": tr("PROJ_LIST_STAGE_NOT_STARTED"), "color": COLOR_GRAY}

func _update_stage_row_labels(scope_label: Label, status_label: Label, proj: ProjectData, stage_index: int):
	if stage_index < 0 or stage_index >= proj.stages.size():
		return
	var stage = proj.stages[stage_index]
	scope_label.text = "%s %d / %d" % [tr("PROJ_SCOPE_LABEL"), int(stage.progress), int(stage.amount)]
	var status_data = _get_stage_status_data(proj, stage_index)
	status_label.text = status_data["text"]
	status_label.add_theme_color_override("font_color", status_data["color"])

func _create_support_card(proj: SupportProjectData) -> PanelContainer:
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_right = 20
	style.corner_radius_bottom_left = 20
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.bg_color = Color(0.95, 1.0, 1.0, 1)
	style.border_color = Color(0.0, 0.6, 0.6, 1)
	if UITheme: UITheme.apply_shadow(style)
	card.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	card.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	margin.add_child(vbox)

	var top_hbox = HBoxContainer.new()
	vbox.add_child(top_hbox)

	var left_info = VBoxContainer.new()
	top_hbox.add_child(left_info)

	var client = proj.get_client()
	var client_name = client.get_display_name() if client else proj.client_id
	var title_lbl = Label.new()
	title_lbl.text = _tr_format_safe("SUPPORT_WINDOW_TITLE", client_name, "Support — %s" % client_name)
	title_lbl.add_theme_color_override("font_color", Color(0.0, 0.55, 0.55, 1))
	if UITheme: UITheme.apply_font(title_lbl, "bold")
	left_info.add_child(title_lbl)

	var open_count = 0
	var overdue_count = 0
	for ticket in proj.tickets:
		if ticket is SupportTicketData and not ticket.is_completed:
			open_count += 1
			if ticket.is_overdue:
				overdue_count += 1
	var status_lbl = Label.new()
	status_lbl.text = _tr_format_safe("SUPPORT_STATUS_TICKETS", [open_count, overdue_count], "Tickets: %d open / %d overdue" % [open_count, overdue_count])
	status_lbl.add_theme_color_override("font_color", Color(0.0, 0.5, 0.5, 1))
	if UITheme: UITheme.apply_font(status_lbl, "regular")
	left_info.add_child(status_lbl)

	var remaining_days = SupportProjectManager._count_workdays_between(GameTime.day, proj.end_day) if proj.end_day >= GameTime.day else 0
	var duration_lbl = Label.new()
	duration_lbl.text = _tr_format_safe("SUPPORT_DURATION_INFO", [proj.contract_duration_days, remaining_days], "Duration: %d work days | %d left" % [proj.contract_duration_days, remaining_days])
	duration_lbl.add_theme_color_override("font_color", Color(0.0, 0.5, 0.5, 1))
	if UITheme: UITheme.apply_font(duration_lbl, "regular")
	left_info.add_child(duration_lbl)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(spacer)

	var right = VBoxContainer.new()
	top_hbox.add_child(right)

	var weekly_lbl = Label.new()
	var weekly_rate = SupportProjectManager.get_effective_daily_rate(proj) * 5
	weekly_lbl.text = _tr_format_safe("SUPPORT_WEEKLY_RATE", weekly_rate, "~$%d/wk" % weekly_rate)
	weekly_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weekly_lbl.add_theme_color_override("font_color", Color(0.2, 0.65, 0.3, 1))
	weekly_lbl.add_theme_font_size_override("font_size", 20)
	if UITheme: UITheme.apply_font(weekly_lbl, "bold")
	right.add_child(weekly_lbl)

	var open_btn = Button.new()
	open_btn.text = tr("UI_OPEN")
	open_btn.custom_minimum_size = Vector2(180, 40)
	open_btn.add_theme_color_override("font_color", COLOR_BLUE)
	open_btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	open_btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	open_btn.add_theme_stylebox_override("normal", btn_style)
	open_btn.add_theme_stylebox_override("hover", btn_style_hover)
	open_btn.add_theme_stylebox_override("pressed", btn_style_hover)
	if UITheme: UITheme.apply_font(open_btn, "semibold")
	open_btn.pressed.connect(_on_open_pressed.bind(proj))
	right.add_child(open_btn)

	call_deferred("_set_children_pass_filter", card)
	return card

func _on_open_pressed(proj):
	if proj == null:
		return
	emit_signal("project_opened", proj)
	_on_close_pressed()

# === ОБРАБОТКА ВВОДА (ESC) ===
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and visible:
		_on_close_pressed()
		get_viewport().set_input_as_handled()

func _process(_delta):
	if not visible:
		return
	for child in cards_container.get_children():
		if child == empty_label:
			continue
		if not child.has_meta("stage_rows") or not child.has_meta("project_ref"):
			continue
		var proj = child.get_meta("project_ref")
		var stage_rows = child.get_meta("stage_rows")
		if not (proj is ProjectData):
			continue
		if proj.state != ProjectData.State.IN_PROGRESS and proj.state != ProjectData.State.DRAFTING:
			continue
		for row_data in stage_rows:
			var stage_index = row_data.get("stage_index", -1)
			var scope_label = row_data.get("scope_label", null)
			var status_label = row_data.get("status_label", null)
			if stage_index < 0 or not is_instance_valid(scope_label) or not is_instance_valid(status_label):
				continue
			_update_stage_row_labels(scope_label, status_label, proj, stage_index)
