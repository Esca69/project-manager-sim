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

var _scroll: ScrollContainer
var _cards_container: VBoxContainer
var _scroll_ready: bool = false

func _ready():
	visible = false

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

	if close_btn:
		close_btn.pressed.connect(_on_close_pressed)
		if UITheme: UITheme.apply_font(close_btn, "semibold")

	_setup_scroll_container()

func _setup_scroll_container():
	if cards_margin == null:
		push_error("project_selection_ui: cards_margin is null!")
		return

	# КРИТИЧНО: MarginContainer ��олжен растягиваться на всю высоту
	cards_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Удаляем старый CardsContainer (с Card1/Card2/Card3)
	for child in cards_margin.get_children():
		child.queue_free()

	# Ждём один кадр чтобы queue_free завершился, потом создаём новые ноды
	await get_tree().process_frame

	# ScrollContainer (как в employee_roster)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.clip_contents = true
	cards_margin.add_child(_scroll)

	# VBoxContainer для карточек
	_cards_container = VBoxContainer.new()
	_cards_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cards_container.add_theme_constant_override("separation", 15)
	_scroll.add_child(_cards_container)

	_scroll_ready = true
	print("✅ ProjectSelectionUI: scroll готов")

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
	# Если scroll ещё не готов — ждём
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
	print("📋 Генерация %d проектов на неделю..." % count)
	for i in range(count):
		var proj = ProjectGenerator.generate_random_project(GameTime.day)
		current_options.append(proj)
		print("  → Проект %d: %s [%s]" % [i, proj.title, proj.category])
	print("📋 Итого: %d проектов в current_options" % current_options.size())

func _rebuild_cards():
	if _cards_container == null:
		push_error("project_selection_ui: _cards_container is null в _rebuild_cards!")
		return

	# Очищаем
	for child in _cards_container.get_children():
		_cards_container.remove_child(child)
		child.queue_free()

	var has_any = false
	for i in range(current_options.size()):
		if current_options[i] == null:
			continue
		has_any = true
		var card = _create_card(current_options[i], i)
		_cards_container.add_child(card)

	if not has_any:
		var empty_lbl = Label.new()
		empty_lbl.text = "Все проекты на этой неделе выбраны!"
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if UITheme: UITheme.apply_font(empty_lbl, "semibold")
		_cards_container.add_child(empty_lbl)

	print("🔄 _rebuild_cards: показано %d карточек" % _cards_container.get_child_count())

	if _scroll:
		_scroll.scroll_vertical = 0

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
	name_lbl.text = client_text + cat_label + " " + data.title
	name_lbl.add_theme_color_override("font_color", Color(0.17254902, 0.30980393, 0.5686275, 1))
	if UITheme: UITheme.apply_font(name_lbl, "bold")
	left_info.add_child(name_lbl)

	var work_lbl = Label.new()
	var parts = []
	for stage in data.stages:
		parts.append(stage.type + " " + PMData.get_blurred_work(stage.amount))
	work_lbl.text = "Работы:  " + "    ".join(parts)
	work_lbl.add_theme_color_override("font_color", Color(0.17254902, 0.30980393, 0.5686275, 1))
	if UITheme: UITheme.apply_font(work_lbl, "regular")
	left_info.add_child(work_lbl)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(spacer)

	var right_info = VBoxContainer.new()
	top_hbox.add_child(right_info)

	var budget_lbl = Label.new()
	var budget_text = "Бюджет " + PMData.get_blurred_budget(data.budget)
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

	var select_btn = Button.new()
	select_btn.text = "Выбрать"
	select_btn.custom_minimum_size = Vector2(180, 40)
	select_btn.add_theme_color_override("font_color", Color(0.17254902, 0.30980393, 0.5686275, 1))
	select_btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	select_btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	select_btn.add_theme_stylebox_override("normal", _btn_style)
	select_btn.add_theme_stylebox_override("hover", _btn_style_hover)
	select_btn.add_theme_stylebox_override("pressed", _btn_style_hover)
	if UITheme: UITheme.apply_font(select_btn, "semibold")
	select_btn.pressed.connect(_on_select_pressed.bind(index))
	right_info.add_child(select_btn)

	var deadlines_hbox = HBoxContainer.new()
	deadlines_hbox.add_theme_constant_override("separation", 40)
	card_vbox.add_child(deadlines_hbox)

	var soft_days = data.soft_deadline_day - GameTime.day
	var hard_days = data.deadline_day - GameTime.day

	var soft_lbl = Label.new()
	soft_lbl.text = "Софт: %d дн. (штраф -%d%%)" % [soft_days, data.soft_deadline_penalty_percent]
	soft_lbl.add_theme_color_override("font_color", Color(1.0, 0.55, 0.0, 1))
	if UITheme: UITheme.apply_font(soft_lbl, "regular")
	deadlines_hbox.add_child(soft_lbl)

	var hard_lbl = Label.new()
	hard_lbl.text = "Хард: %d дн. (провал = $0)" % hard_days
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

	print("Выбран проект: ", selected.title)
	emit_signal("project_selected", selected)

	current_options[index] = null

	_rebuild_cards()
