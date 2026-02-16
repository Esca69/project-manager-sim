extends Control

# === ЦВЕТА (как в client_panel.gd) ===
const COLOR_BLUE = Color(0.17254902, 0.30980393, 0.5686275, 1)
const COLOR_GREEN = Color(0.29803923, 0.6862745, 0.3137255, 1)
const COLOR_RED = Color(0.8980392, 0.22352941, 0.20784314, 1)
const COLOR_ORANGE = Color(1.0, 0.55, 0.0, 1)
const COLOR_GRAY = Color(0.5, 0.5, 0.5, 1)
const COLOR_DARK = Color(0.2, 0.2, 0.2, 1)
const COLOR_WHITE = Color(1, 1, 1, 1)
const COLOR_BORDER = Color(0.8784314, 0.8784314, 0.8784314, 1)
const COLOR_WINDOW_BORDER = Color(0, 0, 0, 1)
const COLOR_GOLD = Color(0.85, 0.65, 0.13, 1)
const COLOR_TRUST = Color(0.85, 0.55, 0.0, 1)

var _overlay: ColorRect
var _window: PanelContainer
var _scroll: ScrollContainer
var _content_vbox: VBoxContainer
var _close_btn: Button

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	z_index = 90
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_force_fullscreen_size()
	_build_ui()

func _force_fullscreen_size():
	var vp_size = get_viewport().get_visible_rect().size
	position = Vector2.ZERO
	size = vp_size

func open():
	_force_fullscreen_size()
	_populate()
	if UITheme:
		UITheme.fade_in(self, 0.2)
	else:
		visible = true

func close():
	if UITheme:
		UITheme.fade_out(self, 0.15)
	else:
		visible = false

# === ПОСТРОЕНИЕ КАРКАСА (идентично client_panel) ===
func _build_ui():
	# Затемнение фона
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.45)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	# === ОКНО: 1500×900 по центру ===
	_window = PanelContainer.new()
	_window.custom_minimum_size = Vector2(1500, 900)
	_window.set_anchors_preset(Control.PRESET_CENTER)
	_window.offset_left = -750
	_window.offset_top = -450
	_window.offset_right = 750
	_window.offset_bottom = 450
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
	if UITheme:
		UITheme.apply_shadow(window_style, false)
	_window.add_theme_stylebox_override("panel", window_style)
	add_child(_window)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 0)
	_window.add_child(main_vbox)

	# === ЗАГОЛОВОК — синий хедер ===
	var header_panel = Panel.new()
	header_panel.custom_minimum_size = Vector2(0, 40)
	var header_style = StyleBoxFlat.new()
	header_style.bg_color = COLOR_BLUE
	header_style.border_color = COLOR_WINDOW_BORDER
	header_style.corner_radius_top_left = 20
	header_style.corner_radius_top_right = 20
	header_panel.add_theme_stylebox_override("panel", header_style)
	main_vbox.add_child(header_panel)

	# TitleLabel — по центру
	var title_label = Label.new()
	title_label.text = "🏢 Босс"
	title_label.set_anchors_preset(Control.PRESET_CENTER)
	title_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	title_label.offset_left = -88
	title_label.offset_top = -11.5
	title_label.offset_right = 88
	title_label.offset_bottom = 11.5
	title_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", COLOR_WHITE)
	title_label.add_theme_font_size_override("font_size", 16)
	if UITheme: UITheme.apply_font(title_label, "bold")
	header_panel.add_child(title_label)

	# CloseButton — правый край, белый фон, синий "X"
	_close_btn = Button.new()
	_close_btn.text = "X"
	_close_btn.focus_mode = Control.FOCUS_NONE
	_close_btn.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_close_btn.offset_left = -51
	_close_btn.offset_top = -15
	_close_btn.offset_right = -24
	_close_btn.offset_bottom = 16
	_close_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_close_btn.grow_vertical = Control.GROW_DIRECTION_BOTH
	_close_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	_close_btn.size_flags_vertical = Control.SIZE_SHRINK_END

	_close_btn.add_theme_color_override("font_color", COLOR_BLUE)
	var close_style = StyleBoxFlat.new()
	close_style.bg_color = COLOR_WHITE
	close_style.corner_radius_top_left = 10
	close_style.corner_radius_top_right = 10
	close_style.corner_radius_bottom_right = 10
	close_style.corner_radius_bottom_left = 10
	_close_btn.add_theme_stylebox_override("normal", close_style)
	if UITheme: UITheme.apply_font(_close_btn, "semibold")
	_close_btn.pressed.connect(close)
	header_panel.add_child(_close_btn)

	# === КОНТЕНТ ===
	var content_margin = MarginContainer.new()
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_left", 24)
	content_margin.add_theme_constant_override("margin_top", 18)
	content_margin.add_theme_constant_override("margin_right", 24)
	content_margin.add_theme_constant_override("margin_bottom", 18)
	main_vbox.add_child(content_margin)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_margin.add_child(_scroll)

	_content_vbox = VBoxContainer.new()
	_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_vbox.add_theme_constant_override("separation", 6)
	_scroll.add_child(_content_vbox)

# === НАПОЛНЕНИЕ ДАННЫМИ (как на скрине) ===
func _populate():
	for child in _content_vbox.get_children():
		child.queue_free()

	var bm = get_node_or_null("/root/BossManager")
	if bm == null:
		_add_label("⚠ BossManager не найден.", COLOR_RED, 15, "semibold")
		return

	# === СТРОКА: Доверие ===
	var trust = bm.boss_trust
	var trust_label_text = _get_trust_level_text(trust)
	var trust_lbl = Label.new()
	trust_lbl.text = "Доверие: %d 🤝  %s" % [trust, trust_label_text]
	trust_lbl.add_theme_color_override("font_color", COLOR_GRAY)
	trust_lbl.add_theme_font_size_override("font_size", 14)
	if UITheme: UITheme.apply_font(trust_lbl, "regular")
	_content_vbox.add_child(trust_lbl)

	# === РАЗДЕЛИТЕЛЬ ===
	var sep = HSeparator.new()
	_content_vbox.add_child(sep)

	# === КВЕСТ ===
	var quest = bm.current_quest
	if quest.is_empty():
		_add_label("Босс пока не дал задание.\nПодойдите к столу босса в начале месяца.", COLOR_GRAY, 14, "regular")
		return

	# Заголовок квеста
	var quest_title = Label.new()
	quest_title.text = "📋  Задание месяца %d:" % quest.get("month", 0)
	quest_title.add_theme_color_override("font_color", COLOR_BLUE)
	quest_title.add_theme_font_size_override("font_size", 15)
	if UITheme: UITheme.apply_font(quest_title, "bold")
	_content_vbox.add_child(quest_title)

	# === КАЖДАЯ ЦЕЛЬ — отдельная строка ===
	var goals = quest.get("goals", [])
	for goal in goals:
		_add_goal_row(goal, bm)

# === СТРОКА ЦЕЛИ (как на скрине) ===
func _add_goal_row(goal: Dictionary, bm):
	var target = goal.get("target", 0)
	var current = bm.get_goal_current(goal)
	var is_done = current >= target
	var trust_reward = goal.get("trust_reward", 0)

	# --- Фоновая подложка строки (светло-серая, как на скрине) ---
	var row_panel = PanelContainer.new()
	row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row_style = StyleBoxFlat.new()
	row_style.bg_color = Color(0.96, 0.96, 0.96, 1) if not is_done else Color(0.93, 0.98, 0.93, 1)
	row_style.corner_radius_top_left = 8
	row_style.corner_radius_top_right = 8
	row_style.corner_radius_bottom_right = 8
	row_style.corner_radius_bottom_left = 8
	row_panel.add_theme_stylebox_override("panel", row_style)
	_content_vbox.add_child(row_panel)

	var row_margin = MarginContainer.new()
	row_margin.add_theme_constant_override("margin_left", 14)
	row_margin.add_theme_constant_override("margin_top", 8)
	row_margin.add_theme_constant_override("margin_right", 14)
	row_margin.add_theme_constant_override("margin_bottom", 8)
	row_panel.add_child(row_margin)

	var row_vbox = VBoxContainer.new()
	row_vbox.add_theme_constant_override("separation", 4)
	row_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_margin.add_child(row_vbox)

	# --- Текст цели + награда справа ---
	var top_hbox = HBoxContainer.new()
	top_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_vbox.add_child(top_hbox)

	var goal_text = Label.new()
	goal_text.text = goal.get("label", "")
	goal_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	goal_text.add_theme_color_override("font_color", COLOR_DARK if not is_done else COLOR_GREEN)
	goal_text.add_theme_font_size_override("font_size", 14)
	if UITheme: UITheme.apply_font(goal_text, "regular")
	top_hbox.add_child(goal_text)

	if trust_reward > 0:
		var reward_lbl = Label.new()
		reward_lbl.text = "+%d 🤝" % trust_reward
		reward_lbl.add_theme_color_override("font_color", COLOR_TRUST)
		reward_lbl.add_theme_font_size_override("font_size", 14)
		if UITheme: UITheme.apply_font(reward_lbl, "semibold")
		top_hbox.add_child(reward_lbl)

	# --- Прогресс-бар на всю ширину ---
	var pbar = ProgressBar.new()
	pbar.min_value = 0
	pbar.max_value = target if target > 0 else 1
	pbar.value = min(current, target)
	pbar.show_percentage = false
	pbar.custom_minimum_size = Vector2(0, 16)
	pbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var bg_s = StyleBoxFlat.new()
	bg_s.bg_color = Color(0.88, 0.88, 0.88, 1)
	bg_s.corner_radius_top_left = 8
	bg_s.corner_radius_top_right = 8
	bg_s.corner_radius_bottom_right = 8
	bg_s.corner_radius_bottom_left = 8
	pbar.add_theme_stylebox_override("background", bg_s)

	var fill_s = StyleBoxFlat.new()
	if is_done:
		fill_s.bg_color = COLOR_GREEN
	else:
		fill_s.bg_color = COLOR_BLUE
	fill_s.corner_radius_top_left = 8
	fill_s.corner_radius_top_right = 8
	fill_s.corner_radius_bottom_right = 8
	fill_s.corner_radius_bottom_left = 8
	pbar.add_theme_stylebox_override("fill", fill_s)

	row_vbox.add_child(pbar)

	# --- Подпись прогресса: "0 / 5000" ---
	var progress_lbl = Label.new()
	progress_lbl.text = "%d / %d" % [current, target]
	progress_lbl.add_theme_color_override("font_color", COLOR_GRAY)
	progress_lbl.add_theme_font_size_override("font_size", 12)
	if UITheme: UITheme.apply_font(progress_lbl, "regular")
	row_vbox.add_child(progress_lbl)

# === ХЕЛПЕРЫ ===
func _add_label(text: String, color: Color, size: int, weight: String):
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if UITheme: UITheme.apply_font(lbl, weight)
	_content_vbox.add_child(lbl)

func _get_trust_level_text(trust: int) -> String:
	if trust < 0:
		return "😠 Недоволен"
	elif trust == 0:
		return "😐 Нейтрально"
	elif trust <= 5:
		return "🙂 Доволен"
	elif trust <= 12:
		return "😊 Доверяет"
	elif trust <= 20:
		return "🤩 Очень доверяет"
	else:
		return "🏆 Полное доверие"
