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

	_scroll_ready = true

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
			client_text = client.emoji + " " + client.client_name + "  —  "

	var name_lbl = Label.new()
	name_lbl.text = client_text + cat_label + " " + tr(data.title)
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

	print("⏱ Начинаем обсуждение проекта: ", tr(selected.title))

	current_options[index] = null
	_on_close_pressed()

	emit_signal("project_selected", selected)

# === ОБРАБОТКА ВВОДА (ESC) ===
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and visible:
		_on_close_pressed()
		get_viewport().set_input_as_handled()
