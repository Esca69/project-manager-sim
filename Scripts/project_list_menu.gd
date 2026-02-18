extends Control

signal project_opened(proj: ProjectData)

@onready var cards_container = $Window/MainVBox/CardsMargin/ScrollContainer/CardsContainer
@onready var close_btn = find_child("CloseButton", true, false)
@onready var empty_label = $Window/MainVBox/CardsMargin/ScrollContainer/CardsContainer/EmptyLabel

var btn_style: StyleBoxFlat
var btn_style_hover: StyleBoxFlat

func _ready():
	visible = false
	if close_btn:
		close_btn.pressed.connect(_on_close_pressed)
		if UITheme: UITheme.apply_font(close_btn, "semibold")

	var scroll = cards_container.get_parent()
	if scroll and scroll is ScrollContainer:
		# === ИСПРАВЛЕНИЕ БАГА СО СКРОЛЛОМ ===
		# Теперь карточки не будут вылезать за рамки
		scroll.clip_contents = true

	btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(1, 1, 1, 1)
	btn_style.border_width_left = 2
	btn_style.border_width_top = 2
	btn_style.border_width_right = 2
	btn_style.border_width_bottom = 2
	btn_style.border_color = Color(0.17254902, 0.30980393, 0.5686275, 1)
	btn_style.corner_radius_top_left = 20
	btn_style.corner_radius_top_right = 20
	btn_style.corner_radius_bottom_right = 20
	btn_style.corner_radius_bottom_left = 20

	btn_style_hover = StyleBoxFlat.new()
	btn_style_hover.bg_color = Color(0.17254902, 0.30980393, 0.5686275, 1)
	btn_style_hover.border_width_left = 2
	btn_style_hover.border_width_top = 2
	btn_style_hover.border_width_right = 2
	btn_style_hover.border_width_bottom = 2
	btn_style_hover.border_color = Color(0.17254902, 0.30980393, 0.5686275, 1)
	btn_style_hover.corner_radius_top_left = 20
	btn_style_hover.corner_radius_top_right = 20
	btn_style_hover.corner_radius_bottom_right = 20
	btn_style_hover.corner_radius_bottom_left = 20

func open_menu():
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

func _rebuild_cards():
	for child in cards_container.get_children():
		if child == empty_label:
			continue
		cards_container.remove_child(child)
		child.queue_free()

	if ProjectManager.active_projects.is_empty():
		# === ИСПРАВЛЕНИЕ: Красивое сообщение при отсутствии проектов ===
		empty_label.text = "Нет активных проектов.\nВозьмите проект у босса."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# Серый цвет, как принято для empty-state
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
		if UITheme: UITheme.apply_font(empty_label, "semibold")
		
		empty_label.visible = true
		return

	empty_label.visible = false

	var sorted_indices = []
	for i in range(ProjectManager.active_projects.size()):
		sorted_indices.append(i)

	sorted_indices.sort_custom(func(a, b):
		var sa = ProjectManager.active_projects[a].state
		var sb = ProjectManager.active_projects[b].state
		var a_done = (sa == ProjectData.State.FINISHED or sa == ProjectData.State.FAILED)
		var b_done = (sb == ProjectData.State.FINISHED or sb == ProjectData.State.FAILED)
		if a_done != b_done:
			return not a_done
		return a < b
	)

	for idx in sorted_indices:
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

	# === ИЗМЕНЕНИЕ: используем get_category_label() вместо хардкода ===
	var cat_label = proj.get_category_label()
	var client_prefix = ""
	if proj.client_id != "":
		var client = proj.get_client()
		if client:
			client_prefix = client.emoji + " " + client.client_name + "  —  "
	var title_text = client_prefix + cat_label + " " + proj.title
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
			status_lbl.text = "📝 Черновик — назначьте людей и нажмите Старт"
			status_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
		ProjectData.State.IN_PROGRESS:
			var stage_name = _get_current_stage_name(proj)
			status_lbl.text = "🔧 В работе — этап: " + stage_name
			status_lbl.add_theme_color_override("font_color", Color(0.17254902, 0.30980393, 0.5686275, 1))
		ProjectData.State.FINISHED:
			status_lbl.text = "✅ Завершён"
			status_lbl.add_theme_color_override("font_color", Color(0.29803923, 0.6862745, 0.3137255, 1))
		ProjectData.State.FAILED:
			status_lbl.text = "❌ Провален — хард-дедлайн истёк"
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
	
	# === ИСПРАВЛЕНИЕ: Динамический расчет бюджета (штрафы за софт-дедлайн) ===
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

	# Применение цветов в зависимости от статуса (Красный, Желтый, Зеленый)
	if is_failed:
		budget_lbl.text = "Бюджет: $0 (Провал)"
		budget_lbl.add_theme_color_override("font_color", Color(0.85, 0.21, 0.21)) 
	elif is_penalty:
		budget_lbl.text = "Бюджет: $" + str(current_payout)
		budget_lbl.add_theme_color_override("font_color", Color(0.9, 0.72, 0.04)) 
	else:
		budget_lbl.text = "Бюджет: $" + str(proj.budget)
		budget_lbl.add_theme_color_override("font_color", Color(0.29803923, 0.6862745, 0.3137255, 1))

	budget_lbl.add_theme_font_size_override("font_size", 20)
	budget_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if UITheme: UITheme.apply_font(budget_lbl, "bold")
	right_info.add_child(budget_lbl)

	var open_btn = Button.new()
	open_btn.text = "Открыть"
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
	soft_lbl.text = "Софт: %s (ост. %d дн.) | штраф -%d%%" % [soft_date, soft_days, proj.soft_deadline_penalty_percent]
	soft_lbl.add_theme_color_override("font_color", Color(1.0, 0.55, 0.0, 1))
	if UITheme: UITheme.apply_font(soft_lbl, "regular")
	deadlines_hbox.add_child(soft_lbl)

	var hard_lbl = Label.new()
	hard_lbl.text = "Хард: %s (ост. %d дн.)" % [hard_date, hard_days]
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
	visible = false

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
				"BA": return "Бизнес-анализ"
				"DEV": return "Разработка"
				"QA": return "Тестирование"
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
			return "Прогресс: %d%%" % int(pct)
	return ""
