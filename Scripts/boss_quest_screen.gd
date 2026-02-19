extends Control

# === UI экран: Босс даёт задание на месяц ===
# Переделан в стиль client_panel: синий хедер, overlay, Inter шрифт

const COLOR_BLUE = Color(0.17254902, 0.30980393, 0.5686275, 1)
const COLOR_WHITE = Color(1, 1, 1, 1)
const COLOR_DARK = Color(0.2, 0.2, 0.2, 1)
const COLOR_GRAY = Color(0.5, 0.5, 0.5, 1)
const COLOR_ORANGE = Color(0.85, 0.55, 0.0, 1)
const COLOR_GREEN = Color(0.29803923, 0.6862745, 0.3137255, 1)
const COLOR_TRUST = Color(0.85, 0.55, 0.0, 1)
const COLOR_WINDOW_BORDER = Color(0, 0, 0, 1)
const COLOR_BORDER = Color(0.8784314, 0.8784314, 0.8784314, 1)

var _overlay: ColorRect
var _window: PanelContainer
var _content_vbox: VBoxContainer
var _close_btn: Button

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
	title_label.text = tr("BOSS_QUEST_TITLE")
	title_label.set_anchors_preset(Control.PRESET_CENTER)
	title_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	title_label.offset_left = -150
	title_label.offset_top = -11.5
	title_label.offset_right = 150
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
	_content_vbox.add_theme_constant_override("separation", 14)
	content_margin.add_child(_content_vbox)

func open(quest: Dictionary):
	for child in _content_vbox.get_children():
		child.queue_free()

	# Доверие
	var trust_lbl = Label.new()
	trust_lbl.text = tr("BOSS_TRUST_LABEL") % [BossManager.boss_trust, BossManager.get_trust_label()]
	trust_lbl.add_theme_font_size_override("font_size", 14)
	trust_lbl.add_theme_color_override("font_color", BossManager.get_trust_color())
	trust_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme: UITheme.apply_font(trust_lbl, "semibold")
	_content_vbox.add_child(trust_lbl)

	# Предупреждение
	if quest.get("is_impossible", false):
		var warn_lbl = Label.new()
		warn_lbl.text = tr("BOSS_IMPOSSIBLE_WARN")
		warn_lbl.add_theme_font_size_override("font_size", 13)
		warn_lbl.add_theme_color_override("font_color", COLOR_ORANGE)
		warn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if UITheme: UITheme.apply_font(warn_lbl, "semibold")
		_content_vbox.add_child(warn_lbl)

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

	# Цели — заголовок
	var goals_title = Label.new()
	goals_title.text = tr("BOSS_GOALS_TITLE") % quest["month"]
	goals_title.add_theme_font_size_override("font_size", 16)
	goals_title.add_theme_color_override("font_color", COLOR_BLUE)
	if UITheme: UITheme.apply_font(goals_title, "bold")
	_content_vbox.add_child(goals_title)

	# Каждая цель — строка
	for obj in quest["objectives"]:
		var row_panel = PanelContainer.new()
		row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row_style = StyleBoxFlat.new()
		row_style.bg_color = Color(0.96, 0.96, 0.96, 1)
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

		var obj_hbox = HBoxContainer.new()
		obj_hbox.add_theme_constant_override("separation", 10)
		row_margin.add_child(obj_hbox)

		var bullet = Label.new()
		bullet.text = "▸"
		bullet.add_theme_font_size_override("font_size", 15)
		bullet.add_theme_color_override("font_color", COLOR_BLUE)
		obj_hbox.add_child(bullet)

		var obj_lbl = Label.new()
		# Label цели переводится в самом BossManager, здесь просто выводим как есть
		obj_lbl.text = obj["label"] 
		obj_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		obj_lbl.add_theme_font_size_override("font_size", 15)
		obj_lbl.add_theme_color_override("font_color", COLOR_DARK)
		if UITheme: UITheme.apply_font(obj_lbl, "regular")
		obj_hbox.add_child(obj_lbl)

		var reward_lbl = Label.new()
		reward_lbl.text = "+%d 🤝" % obj["trust_reward"]
		reward_lbl.add_theme_font_size_override("font_size", 13)
		reward_lbl.add_theme_color_override("font_color", COLOR_TRUST)
		if UITheme: UITheme.apply_font(reward_lbl, "semibold")
		obj_hbox.add_child(reward_lbl)

	var sep2 = HSeparator.new()
	_content_vbox.add_child(sep2)

	# Кнопка "Принять" — синяя, как везде
	var accept_btn = Button.new()
	accept_btn.text = tr("BOSS_ACCEPT_BTN")
	accept_btn.custom_minimum_size = Vector2(250, 44)
	accept_btn.focus_mode = Control.FOCUS_NONE
	accept_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = COLOR_BLUE
	btn_style.corner_radius_top_left = 14
	btn_style.corner_radius_top_right = 14
	btn_style.corner_radius_bottom_right = 14
	btn_style.corner_radius_bottom_left = 14
	accept_btn.add_theme_stylebox_override("normal", btn_style)

	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = Color(0.22, 0.38, 0.65, 1)
	accept_btn.add_theme_stylebox_override("hover", btn_hover)
	accept_btn.add_theme_stylebox_override("pressed", btn_hover)

	accept_btn.add_theme_color_override("font_color", Color.WHITE)
	accept_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	accept_btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	accept_btn.add_theme_font_size_override("font_size", 16)
	if UITheme: UITheme.apply_font(accept_btn, "bold")

	accept_btn.pressed.connect(_on_accept.bind(quest))
	_content_vbox.add_child(accept_btn)

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
		tr("BOSS_SPEECH_1"),
		tr("BOSS_SPEECH_2"),
		tr("BOSS_SPEECH_3"),
		tr("BOSS_SPEECH_4"),
	]
	var speeches_impossible = [
		tr("BOSS_SPEECH_IMPOSSIBLE_1"),
		tr("BOSS_SPEECH_IMPOSSIBLE_2"),
		tr("BOSS_SPEECH_IMPOSSIBLE_3"),
	]

	if quest.get("is_impossible", false):
		return speeches_impossible.pick_random()
	return speeches_normal.pick_random()
