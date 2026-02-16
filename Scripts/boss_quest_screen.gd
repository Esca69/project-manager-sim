extends Control

# === UI экран: Босс даёт задание на месяц ===

var _panel: PanelContainer
var _content_vbox: VBoxContainer
var _accept_btn: Button

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func _build_ui():
	# Затемнение фона
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# Центральная панель
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(700, 0)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(1, 1, 1, 1)
	panel_style.corner_radius_top_left = 20
	panel_style.corner_radius_top_right = 20
	panel_style.corner_radius_bottom_right = 20
	panel_style.corner_radius_bottom_left = 20
	panel_style.border_width_left = 3
	panel_style.border_width_top = 3
	panel_style.border_width_right = 3
	panel_style.border_width_bottom = 3
	panel_style.border_color = Color(0.17, 0.31, 0.57, 1)
	if UITheme: UITheme.apply_shadow(panel_style)
	_panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(_panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 25)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 25)
	_panel.add_child(margin)

	_content_vbox = VBoxContainer.new()
	_content_vbox.add_theme_constant_override("separation", 16)
	margin.add_child(_content_vbox)

func open(quest: Dictionary):
	# Очищаем контент
	for child in _content_vbox.get_children():
		child.queue_free()

	# Заголовок
	var title_lbl = Label.new()
	title_lbl.text = "🏢 Задание на месяц %d" % quest["month"]
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", Color(0.17, 0.31, 0.57, 1))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme: UITheme.apply_font(title_lbl, "bold")
	_content_vbox.add_child(title_lbl)

	# Доверие
	var trust_lbl = Label.new()
	trust_lbl.text = "Доверие босса: %d 🤝  (%s)" % [BossManager.boss_trust, BossManager.get_trust_label()]
	trust_lbl.add_theme_font_size_override("font_size", 14)
	trust_lbl.add_theme_color_override("font_color", BossManager.get_trust_color())
	trust_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme: UITheme.apply_font(trust_lbl, "semibold")
	_content_vbox.add_child(trust_lbl)

	# Предупреждение о невозможном задании
	if quest.get("is_impossible", false):
		var warn_lbl = Label.new()
		warn_lbl.text = "⚠️ Босс в этом месяце особенно требователен..."
		warn_lbl.add_theme_font_size_override("font_size", 13)
		warn_lbl.add_theme_color_override("font_color", Color(0.85, 0.55, 0.0, 1))
		warn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if UITheme: UITheme.apply_font(warn_lbl, "semibold")
		_content_vbox.add_child(warn_lbl)

	# Разделитель
	var sep = HSeparator.new()
	_content_vbox.add_child(sep)

	# Речь босса
	var speech_lbl = Label.new()
	speech_lbl.text = _get_boss_speech(quest)
	speech_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	speech_lbl.add_theme_font_size_override("font_size", 14)
	speech_lbl.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3, 1))
	if UITheme: UITheme.apply_font(speech_lbl, "regular")
	_content_vbox.add_child(speech_lbl)

	# Цели
	var goals_title = Label.new()
	goals_title.text = "📋 Цели на этот месяц:"
	goals_title.add_theme_font_size_override("font_size", 16)
	goals_title.add_theme_color_override("font_color", Color(0.17, 0.31, 0.57, 1))
	if UITheme: UITheme.apply_font(goals_title, "bold")
	_content_vbox.add_child(goals_title)

	for obj in quest["objectives"]:
		var obj_hbox = HBoxContainer.new()
		obj_hbox.add_theme_constant_override("separation", 10)

		var bullet = Label.new()
		bullet.text = "▸"
		bullet.add_theme_font_size_override("font_size", 15)
		bullet.add_theme_color_override("font_color", Color(0.17, 0.31, 0.57, 1))
		obj_hbox.add_child(bullet)

		var obj_lbl = Label.new()
		obj_lbl.text = obj["label"]
		obj_lbl.add_theme_font_size_override("font_size", 15)
		obj_lbl.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2, 1))
		if UITheme: UITheme.apply_font(obj_lbl, "regular")
		obj_hbox.add_child(obj_lbl)

		var reward_lbl = Label.new()
		reward_lbl.text = "+%d 🤝" % obj["trust_reward"]
		reward_lbl.add_theme_font_size_override("font_size", 13)
		reward_lbl.add_theme_color_override("font_color", Color(0.3, 0.7, 0.3, 1))
		reward_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		reward_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if UITheme: UITheme.apply_font(reward_lbl, "semibold")
		obj_hbox.add_child(reward_lbl)

		_content_vbox.add_child(obj_hbox)

	# Разделитель
	var sep2 = HSeparator.new()
	_content_vbox.add_child(sep2)

	# Кнопка "Принять"
	_accept_btn = Button.new()
	_accept_btn.text = "✅ Понял, босс!"
	_accept_btn.custom_minimum_size = Vector2(250, 44)
	_accept_btn.focus_mode = Control.FOCUS_NONE
	_accept_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.17, 0.31, 0.57, 1)
	btn_style.corner_radius_top_left = 14
	btn_style.corner_radius_top_right = 14
	btn_style.corner_radius_bottom_right = 14
	btn_style.corner_radius_bottom_left = 14
	_accept_btn.add_theme_stylebox_override("normal", btn_style)

	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = Color(0.22, 0.38, 0.65, 1)
	_accept_btn.add_theme_stylebox_override("hover", btn_hover)
	_accept_btn.add_theme_stylebox_override("pressed", btn_hover)

	_accept_btn.add_theme_color_override("font_color", Color.WHITE)
	_accept_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	_accept_btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	_accept_btn.add_theme_font_size_override("font_size", 16)
	if UITheme: UITheme.apply_font(_accept_btn, "bold")

	_accept_btn.pressed.connect(_on_accept.bind(quest))
	_content_vbox.add_child(_accept_btn)

	if UITheme:
		UITheme.fade_in(self, 0.25)
	else:
		visible = true

func _on_accept(quest: Dictionary):
	BossManager.start_quest(quest)
	if UITheme:
		UITheme.fade_out(self, 0.2)
	else:
		visible = false

func _get_boss_speech(quest: Dictionary) -> String:
	var speeches_normal = [
		"Значит так, у нас планы на этот месяц. Покажи что ты можешь.",
		"Руководство ждёт результатов. Давай не подведём.",
		"Новый месяц — новые цели. Я рассчитываю на тебя.",
		"Ладно, слушай внимательно. Вот что нужно сделать.",
	]
	var speeches_impossible = [
		"Этот месяц будет непростым. Руководство поставило амбициозные цели...",
		"Не буду врать, задача серьёзная. Но я верю в тебя.",
		"Сверху при��ли... интересные ожидания. Сделай что сможешь.",
	]

	if quest.get("is_impossible", false):
		return speeches_impossible.pick_random()
	return speeches_normal.pick_random()
