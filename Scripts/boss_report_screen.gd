extends Control

# === UI экран: Отчёт по результатам прошлого месяца ===

var _content_vbox: VBoxContainer

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func _build_ui():
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(700, 0)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 1)
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_right = 20
	style.corner_radius_bottom_left = 20
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.17, 0.31, 0.57, 1)
	if UITheme: UITheme.apply_shadow(style)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 25)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 25)
	panel.add_child(margin)

	_content_vbox = VBoxContainer.new()
	_content_vbox.add_theme_constant_override("separation", 14)
	margin.add_child(_content_vbox)

func open(report: Dictionary):
	for child in _content_vbox.get_children():
		child.queue_free()

	var month = report.get("month", 0)
	var results = report.get("results", [])
	var total_trust = report.get("total_trust", 0)
	var was_impossible = report.get("was_impossible", false)

	# Заголовок
	var title = Label.new()
	title.text = "📊 Итоги месяца %d" % month
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.17, 0.31, 0.57, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme: UITheme.apply_font(title, "bold")
	_content_vbox.add_child(title)

	if was_impossible:
		var warn = Label.new()
		warn.text = "(Это был месяц с повышенными требованиями)"
		warn.add_theme_font_size_override("font_size", 12)
		warn.add_theme_color_override("font_color", Color(0.85, 0.55, 0.0, 1))
		warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if UITheme: UITheme.apply_font(warn, "regular")
		_content_vbox.add_child(warn)

	var sep = HSeparator.new()
	_content_vbox.add_child(sep)

	# Результаты по каждой цели
	for r in results:
		var obj = r["objective"]
		var achieved = r["achieved"]
		var trust = r["trust_gained"]

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		var icon = Label.new()
		icon.text = "✅" if achieved else "❌"
		icon.add_theme_font_size_override("font_size", 16)
		row.add_child(icon)

		var lbl = Label.new()
		lbl.text = obj["label"]
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if achieved:
			lbl.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2, 1))
		else:
			lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
		if UITheme: UITheme.apply_font(lbl, "regular")
		row.add_child(lbl)

		var reward = Label.new()
		if achieved:
			reward.text = "+%d 🤝" % trust
			reward.add_theme_color_override("font_color", Color(0.3, 0.7, 0.3, 1))
		else:
			reward.text = "+0 🤝"
			reward.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
		reward.add_theme_font_size_override("font_size", 14)
		if UITheme: UITheme.apply_font(reward, "semibold")
		row.add_child(reward)

		_content_vbox.add_child(row)

	var sep2 = HSeparator.new()
	_content_vbox.add_child(sep2)

	# Итого доверие
	var total_row = HBoxContainer.new()
	total_row.add_theme_constant_override("separation", 10)

	var total_lbl = Label.new()
	total_lbl.text = "Изменение доверия:"
	total_lbl.add_theme_font_size_override("font_size", 16)
	total_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if UITheme: UITheme.apply_font(total_lbl, "bold")
	total_row.add_child(total_lbl)

	var total_val = Label.new()
	total_val.text = "%+d 🤝" % total_trust
	total_val.add_theme_font_size_override("font_size", 18)
	if total_trust > 0:
		total_val.add_theme_color_override("font_color", Color(0.3, 0.7, 0.3, 1))
	elif total_trust < 0:
		total_val.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2, 1))
	else:
		total_val.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
	if UITheme: UITheme.apply_font(total_val, "bold")
	total_row.add_child(total_val)

	_content_vbox.add_child(total_row)

	# Текущее доверие
	var current_trust = Label.new()
	current_trust.text = "Текущее доверие: %d  %s" % [BossManager.boss_trust, BossManager.get_trust_label()]
	current_trust.add_theme_font_size_override("font_size", 14)
	current_trust.add_theme_color_override("font_color", BossManager.get_trust_color())
	current_trust.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme: UITheme.apply_font(current_trust, "semibold")
	_content_vbox.add_child(current_trust)

	# Реакция босса
	var reaction = Label.new()
	reaction.text = _get_boss_reaction(total_trust, was_impossible)
	reaction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reaction.add_theme_font_size_override("font_size", 13)
	reaction.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 1))
	reaction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme: UITheme.apply_font(reaction, "regular")
	_content_vbox.add_child(reaction)

	# Кнопка закрыть
	var close_btn = Button.new()
	close_btn.text = "Понятно"
	close_btn.custom_minimum_size = Vector2(200, 40)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.17, 0.31, 0.57, 1)
	btn_style.corner_radius_top_left = 12
	btn_style.corner_radius_top_right = 12
	btn_style.corner_radius_bottom_right = 12
	btn_style.corner_radius_bottom_left = 12
	close_btn.add_theme_stylebox_override("normal", btn_style)
	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = Color(0.22, 0.38, 0.65, 1)
	close_btn.add_theme_stylebox_override("hover", btn_hover)
	close_btn.add_theme_stylebox_override("pressed", btn_hover)
	close_btn.add_theme_color_override("font_color", Color.WHITE)
	close_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	close_btn.add_theme_font_size_override("font_size", 15)
	if UITheme: UITheme.apply_font(close_btn, "bold")

	close_btn.pressed.connect(_on_close)
	_content_vbox.add_child(close_btn)

	BossManager.mark_report_shown()

	if UITheme:
		UITheme.fade_in(self, 0.25)
	else:
		visible = true

func _on_close():
	if UITheme:
		UITheme.fade_out(self, 0.2)
	else:
		visible = false

func _get_boss_reaction(trust: int, was_impossible: bool) -> String:
	if was_impossible and trust > 0:
		return "\"Невероятно! Я не ожидал что ты справишься с такими планами.\""
	if trust >= 8:
		return "\"Отличная работа! Так держать.\""
	elif trust >= 4:
		return "\"Неплохо. Есть над чем работать, но в целом доволен.\""
	elif trust > 0:
		return "\"Могло быть и лучше, но хоть что-то сделал.\""
	elif trust == 0:
		return "\"Ничего не выполнено... Я разочарован.\""
	else:
		return "\"Это провал. Мне придётся подумать о твоём будущем здесь.\""
