extends Control

# === UI экран: Отчёт по результатам прошлого месяца ===
# Переделан в стиль client_panel: синий хедер, overlay, Inter шрифт

const COLOR_BLUE = Color(0.17254902, 0.30980393, 0.5686275, 1)
const COLOR_WHITE = Color(1, 1, 1, 1)
const COLOR_DARK = Color(0.2, 0.2, 0.2, 1)
const COLOR_GRAY = Color(0.5, 0.5, 0.5, 1)
const COLOR_GREEN = Color(0.29803923, 0.6862745, 0.3137255, 1)
const COLOR_RED = Color(0.8980392, 0.22352941, 0.20784314, 1)
const COLOR_ORANGE = Color(0.85, 0.55, 0.0, 1)
const COLOR_TRUST = Color(0.85, 0.55, 0.0, 1)
const COLOR_WINDOW_BORDER = Color(0, 0, 0, 1)

var _overlay: ColorRect
var _window: PanelContainer
var _content_vbox: VBoxContainer

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 95
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func _build_ui():
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.5)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	_window = PanelContainer.new()
	_window.custom_minimum_size = Vector2(750, 0)
	_window.set_anchors_preset(Control.PRESET_CENTER)
	_window.offset_left = -375
	_window.offset_top = -300
	_window.offset_right = 375
	_window.offset_bottom = 300
	_window.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_window.grow_vertical = Control.GROW_DIRECTION_BOTH

	var window_style = StyleBoxFlat.new()
	window_style.bg_color = COLOR_WHITE
	window_style.border_width_left = 3
	window_style.border_width_top = 3
	window_style.border_width_right = 3
	window_style.border_width_bottom = 3
	window_style.border_color = COLOR_WINDOW_BORDER
	window_style.corner_radius_top_left = 22
	window_style.corner_radius_top_right = 22
	window_style.corner_radius_bottom_right = 20
	window_style.corner_radius_bottom_left = 20
	if UITheme: UITheme.apply_shadow(window_style, false)
	_window.add_theme_stylebox_override("panel", window_style)
	add_child(_window)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 0)
	_window.add_child(main_vbox)

	# === СИНИЙ ХЕДЕР ===
	var header_panel = Panel.new()
	header_panel.custom_minimum_size = Vector2(0, 40)
	var header_style = StyleBoxFlat.new()
	header_style.bg_color = COLOR_BLUE
	header_style.border_color = COLOR_WINDOW_BORDER
	header_style.corner_radius_top_left = 20
	header_style.corner_radius_top_right = 20
	header_panel.add_theme_stylebox_override("panel", header_style)
	main_vbox.add_child(header_panel)

	var title_label = Label.new()
	title_label.text = tr("BOSS_REPORT_TITLE")
	title_label.set_anchors_preset(Control.PRESET_CENTER)
	title_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	title_label.offset_left = -120
	title_label.offset_top = -11.5
	title_label.offset_right = 120
	title_label.offset_bottom = 11.5
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", COLOR_WHITE)
	title_label.add_theme_font_size_override("font_size", 16)
	if UITheme: UITheme.apply_font(title_label, "bold")
	header_panel.add_child(title_label)

	# === КОНТЕНТ ===
	var content_margin = MarginContainer.new()
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_left", 30)
	content_margin.add_theme_constant_override("margin_top", 20)
	content_margin.add_theme_constant_override("margin_right", 30)
	content_margin.add_theme_constant_override("margin_bottom", 25)
	main_vbox.add_child(content_margin)

	_content_vbox = VBoxContainer.new()
	_content_vbox.add_theme_constant_override("separation", 12)
	content_margin.add_child(_content_vbox)

func open(report: Dictionary):
	for child in _content_vbox.get_children():
		child.queue_free()

	var month = report.get("month", 0)
	var results = report.get("results", [])
	var total_trust = report.get("total_trust", 0)
	var was_impossible = report.get("was_impossible", false)

	if was_impossible:
		var warn = Label.new()
		warn.text = tr("BOSS_REPORT_IMPOSSIBLE")
		warn.add_theme_font_size_override("font_size", 12)
		warn.add_theme_color_override("font_color", COLOR_ORANGE)
		warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if UITheme: UITheme.apply_font(warn, "regular")
		_content_vbox.add_child(warn)

	var sep = HSeparator.new()
	_content_vbox.add_child(sep)

	# Результаты по каждой цели — строки как в boss_panel
	for r in results:
		var obj = r["objective"]
		var achieved = r["achieved"]
		var trust = r["trust_gained"]

		var row_panel = PanelContainer.new()
		row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row_style = StyleBoxFlat.new()
		row_style.bg_color = Color(0.93, 0.98, 0.93, 1) if achieved else Color(0.98, 0.93, 0.93, 1)
		row_style.corner_radius_top_left = 8
		row_style.corner_radius_top_right = 8
		row_style.corner_radius_bottom_right = 8
		row_style.corner_radius_bottom_left = 8
		row_panel.add_theme_stylebox_override("panel", row_style)
		_content_vbox.add_child(row_panel)

		var row_margin = MarginContainer.new()
		row_margin.add_theme_constant_override("margin_left", 12)
		row_margin.add_theme_constant_override("margin_top", 6)
		row_margin.add_theme_constant_override("margin_right", 12)
		row_margin.add_theme_constant_override("margin_bottom", 6)
		row_panel.add_child(row_margin)

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row_margin.add_child(row)

		var icon = Label.new()
		icon.text = "✅" if achieved else "❌"
		icon.add_theme_font_size_override("font_size", 16)
		row.add_child(icon)

		var lbl = Label.new()
		lbl.text = obj["label"]
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_color_override("font_color", COLOR_DARK if achieved else COLOR_GRAY)
		if UITheme: UITheme.apply_font(lbl, "regular")
		row.add_child(lbl)

		var reward = Label.new()
		if achieved:
			reward.text = "+%d 🤝" % trust
			reward.add_theme_color_override("font_color", COLOR_GREEN)
		else:
			reward.text = "+0 🤝"
			reward.add_theme_color_override("font_color", COLOR_GRAY)
		reward.add_theme_font_size_override("font_size", 14)
		if UITheme: UITheme.apply_font(reward, "semibold")
		row.add_child(reward)

	var sep2 = HSeparator.new()
	_content_vbox.add_child(sep2)

	# Итого доверие
	var total_row = HBoxContainer.new()
	total_row.add_theme_constant_override("separation", 10)

	var total_lbl = Label.new()
	total_lbl.text = tr("BOSS_REPORT_TRUST_CHANGE")
	total_lbl.add_theme_font_size_override("font_size", 16)
	total_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if UITheme: UITheme.apply_font(total_lbl, "bold")
	total_row.add_child(total_lbl)

	var total_val = Label.new()
	total_val.text = "%+d 🤝" % total_trust
	total_val.add_theme_font_size_override("font_size", 18)
	if total_trust > 0:
		total_val.add_theme_color_override("font_color", COLOR_GREEN)
	elif total_trust < 0:
		total_val.add_theme_color_override("font_color", COLOR_RED)
	else:
		total_val.add_theme_color_override("font_color", COLOR_GRAY)
	if UITheme: UITheme.apply_font(total_val, "bold")
	total_row.add_child(total_val)

	_content_vbox.add_child(total_row)

	# Текущее доверие
	var current_trust = Label.new()
	current_trust.text = tr("BOSS_REPORT_CURRENT_TRUST") % [BossManager.boss_trust, BossManager.get_trust_label()]
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

	# Кнопка — синяя
	var close_btn = Button.new()
	close_btn.text = tr("BOSS_REPORT_CLOSE")
	close_btn.custom_minimum_size = Vector2(200, 40)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = COLOR_BLUE
	btn_style.corner_radius_top_left = 14
	btn_style.corner_radius_top_right = 14
	btn_style.corner_radius_bottom_right = 14
	btn_style.corner_radius_bottom_left = 14
	close_btn.add_theme_stylebox_override("normal", btn_style)
	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = Color(0.22, 0.38, 0.65, 1)
	close_btn.add_theme_stylebox_override("hover", btn_hover)
	close_btn.add_theme_stylebox_override("pressed", btn_hover)
	close_btn.add_theme_color_override("font_color", Color.WHITE)
	close_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	close_btn.add_theme_color_override("font_pressed_color", Color.WHITE)
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
		return '"%s"' % tr("BOSS_REACTION_IMPOSSIBLE_WIN")
	if trust >= 8:
		return '"%s"' % tr("BOSS_REACTION_GREAT")
	elif trust >= 4:
		return '"%s"' % tr("BOSS_REACTION_OK")
	elif trust > 0:
		return '"%s"' % tr("BOSS_REACTION_MEH")
	elif trust == 0:
		return '"%s"' % tr("BOSS_REACTION_ZERO")
	else:
		return '"%s"' % tr("BOSS_REACTION_FAIL")
