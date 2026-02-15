extends Control

# === ЦВЕТА (как в проекте) ===
const COLOR_BLUE = Color(0.17254902, 0.30980393, 0.5686275, 1)
const COLOR_GREEN = Color(0.29803923, 0.6862745, 0.3137255, 1)
const COLOR_RED = Color(0.8980392, 0.22352941, 0.20784314, 1)
const COLOR_ORANGE = Color(1.0, 0.55, 0.0, 1)
const COLOR_GRAY = Color(0.5, 0.5, 0.5, 1)
const COLOR_DARK = Color(0.2, 0.2, 0.2, 1)
const COLOR_WHITE = Color(1, 1, 1, 1)
const COLOR_BORDER = Color(0.8784314, 0.8784314, 0.8784314, 1)
const COLOR_WINDOW_BORDER = Color(0, 0, 0, 1)
const COLOR_LOYALTY = Color(0.85, 0.2, 0.45, 1)

var _overlay: ColorRect
var _window: PanelContainer
var _scroll: ScrollContainer
var _cards_vbox: VBoxContainer
var _close_btn: Button

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	z_index = 90
	_build_ui()

func open():
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

# === ПОСТРОЕНИЕ КАРКАСА ===
func _build_ui():
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.45)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_window = PanelContainer.new()
	_window.custom_minimum_size = Vector2(750, 600)
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
	center.add_child(_window)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 0)
	_window.add_child(main_vbox)

	# === ЗАГОЛОВОК ===
	var header_panel = Panel.new()
	header_panel.custom_minimum_size = Vector2(0, 48)
	var header_style = StyleBoxFlat.new()
	header_style.bg_color = COLOR_BLUE
	header_style.border_color = COLOR_WINDOW_BORDER
	header_style.corner_radius_top_left = 20
	header_style.corner_radius_top_right = 20
	header_panel.add_theme_stylebox_override("panel", header_style)
	main_vbox.add_child(header_panel)

	var header_margin = MarginContainer.new()
	header_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	header_margin.add_theme_constant_override("margin_left", 20)
	header_margin.add_theme_constant_override("margin_right", 10)
	header_panel.add_child(header_margin)

	var header_hbox = HBoxContainer.new()
	header_margin.add_child(header_hbox)

	var title_label = Label.new()
	title_label.text = "🤝 Заказчики"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", COLOR_WHITE)
	title_label.add_theme_font_size_override("font_size", 17)
	if UITheme: UITheme.apply_font(title_label, "bold")
	header_hbox.add_child(title_label)

	_close_btn = Button.new()
	_close_btn.text = "✕"
	_close_btn.custom_minimum_size = Vector2(40, 36)
	_close_btn.focus_mode = Control.FOCUS_NONE
	var close_style = StyleBoxFlat.new()
	close_style.bg_color = Color(1, 1, 1, 0.15)
	close_style.corner_radius_top_left = 10
	close_style.corner_radius_top_right = 10
	close_style.corner_radius_bottom_right = 10
	close_style.corner_radius_bottom_left = 10
	_close_btn.add_theme_stylebox_override("normal", close_style)
	var close_hover = close_style.duplicate()
	close_hover.bg_color = Color(1, 1, 1, 0.3)
	_close_btn.add_theme_stylebox_override("hover", close_hover)
	_close_btn.add_theme_stylebox_override("pressed", close_hover)
	_close_btn.add_theme_color_override("font_color", COLOR_WHITE)
	_close_btn.add_theme_color_override("font_hover_color", COLOR_WHITE)
	_close_btn.add_theme_font_size_override("font_size", 16)
	if UITheme: UITheme.apply_font(_close_btn, "bold")
	_close_btn.pressed.connect(close)
	header_hbox.add_child(_close_btn)

	# === КОНТЕНТ ===
	var content_margin = MarginContainer.new()
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_left", 20)
	content_margin.add_theme_constant_override("margin_top", 15)
	content_margin.add_theme_constant_override("margin_right", 20)
	content_margin.add_theme_constant_override("margin_bottom", 15)
	main_vbox.add_child(content_margin)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_margin.add_child(_scroll)

	_cards_vbox = VBoxContainer.new()
	_cards_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards_vbox.add_theme_constant_override("separation", 12)
	_scroll.add_child(_cards_vbox)

# === НАПОЛНЕНИЕ ДАННЫМИ ===
func _populate():
	for child in _cards_vbox.get_children():
		child.queue_free()

	for client in ClientManager.clients:
		var card = _create_client_card(client)
		_cards_vbox.add_child(card)

func _create_client_card(client: ClientData) -> PanelContainer:
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 1)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = COLOR_BORDER
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_right = 16
	style.corner_radius_bottom_left = 16
	if UITheme: UITheme.apply_shadow(style)
	card.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	card.add_child(margin)

	var card_vbox = VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(card_vbox)

	# === СТРОКА 1: Название + лояльность ===
	var top_hbox = HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 10)
	card_vbox.add_child(top_hbox)

	var name_lbl = Label.new()
	name_lbl.text = client.emoji + "  " + client.client_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_color_override("font_color", COLOR_BLUE)
	name_lbl.add_theme_font_size_override("font_size", 17)
	if UITheme: UITheme.apply_font(name_lbl, "bold")
	top_hbox.add_child(name_lbl)

	var loyalty_lbl = Label.new()
	loyalty_lbl.text = "❤ %d очков" % client.loyalty
	loyalty_lbl.add_theme_color_override("font_color", COLOR_LOYALTY)
	loyalty_lbl.add_theme_font_size_override("font_size", 16)
	if UITheme: UITheme.apply_font(loyalty_lbl, "bold")
	top_hbox.add_child(loyalty_lbl)

	# === СТРОКА 2: Описание ===
	var desc_lbl = Label.new()
	desc_lbl.text = client.description
	desc_lbl.add_theme_color_override("font_color", COLOR_GRAY)
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if UITheme: UITheme.apply_font(desc_lbl, "regular")
	card_vbox.add_child(desc_lbl)

	# === СТРОКА 3: Статистика ===
	var stats_hbox = HBoxContainer.new()
	stats_hbox.add_theme_constant_override("separation", 25)
	card_vbox.add_child(stats_hbox)

	_add_stat_label(stats_hbox, "✅ Успешно: %d" % client.projects_completed_on_time, COLOR_GREEN)
	_add_stat_label(stats_hbox, "⚠ Просрочка софт: %d" % client.projects_completed_late, COLOR_ORANGE)
	_add_stat_label(stats_hbox, "❌ Провал: %d" % client.projects_failed, COLOR_RED)

	# === СТРОКА 4: Бонус + прогресс-бар ===
	var bonus_percent = client.get_budget_bonus_percent()
	var next_info = client.get_next_bonus_threshold()
	var next_threshold = next_info[0]
	var next_bonus = next_info[1]

	var bonus_hbox = HBoxContainer.new()
	bonus_hbox.add_theme_constant_override("separation", 12)
	card_vbox.add_child(bonus_hbox)

	var bonus_lbl = Label.new()
	bonus_lbl.text = "💰 Бонус к бюджету: +%d%%" % bonus_percent
	bonus_lbl.add_theme_color_override("font_color", COLOR_GREEN if bonus_percent > 0 else COLOR_DARK)
	bonus_lbl.add_theme_font_size_override("font_size", 14)
	if UITheme: UITheme.apply_font(bonus_lbl, "semibold")
	bonus_hbox.add_child(bonus_lbl)

	# === СТРОКА 5: Прогресс до следующего порога ===
	if next_threshold > 0:
		var progress_hbox = HBoxContainer.new()
		progress_hbox.add_theme_constant_override("separation", 8)
		card_vbox.add_child(progress_hbox)

		var pbar = ProgressBar.new()
		pbar.min_value = 0
		pbar.max_value = next_threshold
		pbar.value = client.loyalty
		pbar.show_percentage = false
		pbar.custom_minimum_size = Vector2(300, 18)
		pbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# Стиль фона
		var bg_style = StyleBoxFlat.new()
		bg_style.bg_color = Color(0.92, 0.92, 0.92, 1)
		bg_style.corner_radius_top_left = 9
		bg_style.corner_radius_top_right = 9
		bg_style.corner_radius_bottom_right = 9
		bg_style.corner_radius_bottom_left = 9
		pbar.add_theme_stylebox_override("background", bg_style)

		# Стиль заполнения
		var fill_style = StyleBoxFlat.new()
		fill_style.bg_color = COLOR_LOYALTY
		fill_style.corner_radius_top_left = 9
		fill_style.corner_radius_top_right = 9
		fill_style.corner_radius_bottom_right = 9
		fill_style.corner_radius_bottom_left = 9
		pbar.add_theme_stylebox_override("fill", fill_style)

		progress_hbox.add_child(pbar)

		var progress_text = Label.new()
		progress_text.text = "%d / %d  до +%d%%" % [client.loyalty, next_threshold, next_bonus]
		progress_text.add_theme_color_override("font_color", COLOR_GRAY)
		progress_text.add_theme_font_size_override("font_size", 12)
		if UITheme: UITheme.apply_font(progress_text, "regular")
		progress_hbox.add_child(progress_text)
	else:
		var max_lbl = Label.new()
		max_lbl.text = "🏆 Максимальный уровень бонуса!"
		max_lbl.add_theme_color_override("font_color", COLOR_GREEN)
		max_lbl.add_theme_font_size_override("font_size", 13)
		if UITheme: UITheme.apply_font(max_lbl, "semibold")
		card_vbox.add_child(max_lbl)

	return card

func _add_stat_label(parent: HBoxContainer, text: String, color: Color):
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 13)
	if UITheme: UITheme.apply_font(lbl, "semibold")
	parent.add_child(lbl)
