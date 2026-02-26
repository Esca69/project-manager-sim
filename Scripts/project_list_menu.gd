extends Control

signal project_opened(proj: ProjectData)

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

# === ДОБАВЛЕНО ДЛЯ ФОНА ===
var _overlay: ColorRect

func _ready():
	visible = false
	z_index = 90
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_force_fullscreen_size()
	
	if title_label:
		title_label.text = tr("TITLE_MY_PROJECTS")
		
	# ... остальной код _ready()
	
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
	if UITheme:
		UITheme.fade_out(self, 0.15)
	else:
		visible = false

func _get_project_finish_time(proj: ProjectData) -> float:
	var last_end = 0.0
	for s in proj.stages:
		if s.get("actual_end", -1.0) > last_end:
			last_end = s["actual_end"]
	return proj.start_global_time + last_end

func _rebuild_cards():
	_update_tab_styles()
	
	for child in cards_container.get_children():
		if child == empty_label:
			continue
		cards_container.remove_child(child)
		child.queue_free()

	# Фильтрация
	var filtered_indices = []
	for i in range(ProjectManager.active_projects.size()):
		var proj = ProjectManager.active_projects[i]
		var is_done = (proj.state == ProjectData.State.FINISHED or proj.state == ProjectData.State.FAILED)
		
		if _current_tab == "active" and not is_done:
			filtered_indices.append(i)
		elif _current_tab == "completed" and is_done:
			filtered_indices.append(i)

	if filtered_indices.is_empty():
		empty_label.text = tr("PROJ_LIST_EMPTY")
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
		if UITheme: UITheme.apply_font(empty_label, "semibold")
		
		empty_label.visible = true
		return

	empty_label.visible = false

	# Сортировка
	filtered_indices.sort_custom(func(a, b):
		var proj_a = ProjectManager.active_projects[a]
		var proj_b = ProjectManager.active_projects[b]
		
		if _current_tab == "completed":
			var time_a = _get_project_finish_time(proj_a)
			var time_b = _get_project_finish_time(proj_b)
			return time_a > time_b
		else:
			return a < b
	)

	for idx in filtered_indices:
		var proj = ProjectManager.active_projects[idx]
		var card = _create_card(proj, idx)
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

func _create_card(proj: ProjectData, index: int) -> PanelContainer:
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
	vbox.add_child(top_hbox)

	var left_info = VBoxContainer.new()
	top_hbox.add_child(left_info)

	var cat_label = proj.get_category_label()
	var client_prefix = ""
	if proj.client_id != "":
		var client = proj.get_client()
		if client:
			client_prefix = client.emoji + " " + client.client_name + "  —  "
	
	var title_text = client_prefix + cat_label + " " + tr(proj.title)
	if proj.state == ProjectData.State.FINISHED:
		title_text = "✅ " + title_text
	elif proj.state == ProjectData.State.FAILED:
		title_text = "❌ " + title_text

	var name_lbl = Label.new()
	name_lbl.text = title_text
	name_lbl.add_theme_color_override("font_color", Color(0.17254902, 0.30980393, 0.5686275, 1))
	if UITheme: UITheme.apply_font(name_lbl, "bold")
	left_info.add_child(name_lbl)

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

	if proj.state == ProjectData.State.IN_PROGRESS:
		var progress_text = _get_progress_text(proj)
		var progress_lbl = Label.new()
		progress_lbl.text = progress_text
		progress_lbl.add_theme_color_override("font_color", Color(0.17254902, 0.30980393, 0.5686275, 1))
		if UITheme: UITheme.apply_font(progress_lbl, "semibold")
		left_info.add_child(progress_lbl)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(spacer)

	var right_info = VBoxContainer.new()
	top_hbox.add_child(right_info)

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
		budget_lbl.add_theme_color_override("font_color", Color(0.29803923, 0.6862745, 0.3137255, 1))

	budget_lbl.add_theme_font_size_override("font_size", 20)
	budget_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if UITheme: UITheme.apply_font(budget_lbl, "bold")
	right_info.add_child(budget_lbl)

	var open_btn = Button.new()
	open_btn.text = tr("UI_OPEN")
	open_btn.custom_minimum_size = Vector2(180, 40)
	open_btn.add_theme_color_override("font_color", Color(0.17254902, 0.30980393, 0.5686275, 1))
	open_btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	open_btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	open_btn.add_theme_stylebox_override("normal", btn_style)
	open_btn.add_theme_stylebox_override("hover", btn_style_hover)
	open_btn.add_theme_stylebox_override("pressed", btn_style_hover)
	if UITheme: UITheme.apply_font(open_btn, "semibold")
	open_btn.pressed.connect(_on_open_pressed.bind(index))
	right_info.add_child(open_btn)

	var deadlines_hbox = HBoxContainer.new()
	deadlines_hbox.add_theme_constant_override("separation", 40)
	vbox.add_child(deadlines_hbox)

	var soft_days = proj.soft_deadline_day - GameTime.day
	var hard_days = proj.deadline_day - GameTime.day
	var soft_date = GameTime.get_date_short(proj.soft_deadline_day)
	var hard_date = GameTime.get_date_short(proj.deadline_day)

	var soft_lbl = Label.new()
	soft_lbl.text = tr("PROJ_LIST_SOFT_INFO") % [soft_date, soft_days, proj.soft_deadline_penalty_percent]
	soft_lbl.add_theme_color_override("font_color", Color(1.0, 0.55, 0.0, 1))
	if UITheme: UITheme.apply_font(soft_lbl, "regular")
	deadlines_hbox.add_child(soft_lbl)

	var hard_lbl = Label.new()
	hard_lbl.text = tr("PROJ_LIST_HARD_INFO") % [hard_date, hard_days]
	hard_lbl.add_theme_color_override("font_color", Color(0.8980392, 0.22352941, 0.20784314, 1))
	if UITheme: UITheme.apply_font(hard_lbl, "semibold")
	deadlines_hbox.add_child(hard_lbl)

	call_deferred("_set_children_pass_filter", card)

	return card

func _on_open_pressed(index: int):
	if index < 0 or index >= ProjectManager.active_projects.size():
		return
	var proj = ProjectManager.active_projects[index]
	emit_signal("project_opened", proj)
	_on_close_pressed()

func _get_current_stage_name(proj: ProjectData) -> String:
	for i in range(proj.stages.size()):
		var stage = proj.stages[i]
		if stage.get("is_completed", false):
			continue
		var prev_ok = true
		if i > 0:
			prev_ok = proj.stages[i - 1].get("is_completed", false)
		if prev_ok:
			match stage.type:
				"BA": return tr("STAGE_BA")
				"DEV": return tr("STAGE_DEV")
				"QA": return tr("STAGE_QA")
			return stage.type
	return "—"

func _get_progress_text(proj: ProjectData) -> String:
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
				pct = (float(stage.progress) / float(stage.amount)) * 100.0
			return tr("PROJ_LIST_PROGRESS") % int(pct)
	return ""

# === ОБРАБОТКА ВВОДА (ESC) ===
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and visible:
		_on_close_pressed()
		get_viewport().set_input_as_handled()
