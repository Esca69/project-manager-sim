extends Control

# === ЭКРАН ДИВИДЕНДОВ ПАРТНЁРА ===

const COLOR_BLUE = Color(0.17254902, 0.30980393, 0.5686275, 1)
const COLOR_GREEN = Color(0.29803923, 0.6862745, 0.3137255, 1)
const COLOR_GOLD = Color(0.85, 0.65, 0.13, 1)
const COLOR_WHITE = Color(1, 1, 1, 1)
const COLOR_DARK = Color(0.2, 0.2, 0.2, 1)
const COLOR_GRAY = Color(0.5, 0.5, 0.5, 1)
const COLOR_RED = Color(0.8980392, 0.22352941, 0.20784314, 1)
const COLOR_WINDOW_BORDER = Color(0, 0, 0, 1)

var _overlay: ColorRect
var _window: PanelContainer
var _content_vbox: VBoxContainer

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 96
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func _build_ui():
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.5)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	_window = PanelContainer.new()
	_window.custom_minimum_size = Vector2(520, 0)
	_window.set_anchors_preset(Control.PRESET_CENTER)
	_window.offset_left = -260
	_window.offset_top = -200
	_window.offset_right = 260
	_window.offset_bottom = 200
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
	_window.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_window)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 0)
	_window.add_child(main_vbox)

	# Заголовок (placeholder — меняется в open())
	var header_panel = Panel.new()
	header_panel.custom_minimum_size = Vector2(0, 46)
	var header_style = StyleBoxFlat.new()
	header_style.bg_color = COLOR_GOLD
	header_style.corner_radius_top_left = 20
	header_style.corner_radius_top_right = 20
	header_panel.add_theme_stylebox_override("panel", header_style)
	main_vbox.add_child(header_panel)

	var title_lbl = Label.new()
	title_lbl.name = "TitleLabel"
	title_lbl.set_anchors_preset(Control.PRESET_CENTER)
	title_lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title_lbl.grow_vertical = Control.GROW_DIRECTION_BOTH
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_color_override("font_color", COLOR_WHITE)
	title_lbl.add_theme_font_size_override("font_size", 17)
	if UITheme: UITheme.apply_font(title_lbl, "bold")
	header_panel.add_child(title_lbl)

	var content_margin = MarginContainer.new()
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_left", 32)
	content_margin.add_theme_constant_override("margin_top", 24)
	content_margin.add_theme_constant_override("margin_right", 32)
	content_margin.add_theme_constant_override("margin_bottom", 24)
	main_vbox.add_child(content_margin)

	_content_vbox = VBoxContainer.new()
	_content_vbox.add_theme_constant_override("separation", 14)
	content_margin.add_child(_content_vbox)

func open(net_profit: int):
	if _content_vbox == null:
		return

	# Очищаем контент
	for child in _content_vbox.get_children():
		child.queue_free()

	# Находим лейбл заголовка
	var header_title = find_child("TitleLabel", true, false)

	if net_profit > 0 and PMData.partner_tier > 0:
		var dividend = int(net_profit * PMData.get_partner_percent())
		var pct_str = "%.0f%%" % (PMData.get_partner_percent() * 100.0)

		if header_title:
			header_title.text = tr("DIVIDEND_TITLE")

		# Эмодзи большой
		var emoji_lbl = Label.new()
		emoji_lbl.text = "💰"
		emoji_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		emoji_lbl.add_theme_font_size_override("font_size", 52)
		_content_vbox.add_child(emoji_lbl)

		# Сумма
		var amount_lbl = Label.new()
		amount_lbl.text = tr("DIVIDEND_AMOUNT") % dividend
		amount_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		amount_lbl.add_theme_color_override("font_color", COLOR_GOLD)
		amount_lbl.add_theme_font_size_override("font_size", 26)
		if UITheme: UITheme.apply_font(amount_lbl, "bold")
		_content_vbox.add_child(amount_lbl)

		# Расчёт
		var calc_lbl = Label.new()
		calc_lbl.text = tr("DIVIDEND_CALC") % [pct_str, net_profit]
		calc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		calc_lbl.add_theme_color_override("font_color", COLOR_GRAY)
		calc_lbl.add_theme_font_size_override("font_size", 14)
		if UITheme: UITheme.apply_font(calc_lbl, "regular")
		_content_vbox.add_child(calc_lbl)

		# Начисляем дивиденды
		GameState.add_expense(dividend)
		PMData.change_personal_balance(dividend)
		EventLog.add(tr("LOG_PM_DIVIDEND") % dividend)
	else:
		# Убыток
		if header_title:
			header_title.text = tr("DIVIDEND_NONE_TITLE")
			# Меняем цвет заголовка на красный
			var header = header_title.get_parent()
			if header:
				var s = StyleBoxFlat.new()
				s.bg_color = COLOR_RED
				s.corner_radius_top_left = 20
				s.corner_radius_top_right = 20
				header.add_theme_stylebox_override("panel", s)

		var emoji_lbl = Label.new()
		emoji_lbl.text = "📉"
		emoji_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		emoji_lbl.add_theme_font_size_override("font_size", 52)
		_content_vbox.add_child(emoji_lbl)

		var desc_lbl = Label.new()
		desc_lbl.text = tr("DIVIDEND_NONE_DESC")
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_color_override("font_color", COLOR_DARK)
		desc_lbl.add_theme_font_size_override("font_size", 15)
		if UITheme: UITheme.apply_font(desc_lbl, "regular")
		_content_vbox.add_child(desc_lbl)

	# Кнопка "Понятно"
	var btn_center = CenterContainer.new()
	_content_vbox.add_child(btn_center)

	var ok_btn = Button.new()
	ok_btn.text = tr("DIVIDEND_BTN_OK")
	ok_btn.custom_minimum_size = Vector2(180, 44)
	ok_btn.focus_mode = Control.FOCUS_NONE

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = COLOR_BLUE
	btn_style.corner_radius_top_left = 12
	btn_style.corner_radius_top_right = 12
	btn_style.corner_radius_bottom_right = 12
	btn_style.corner_radius_bottom_left = 12

	ok_btn.add_theme_stylebox_override("normal", btn_style)
	ok_btn.add_theme_stylebox_override("hover", btn_style)
	ok_btn.add_theme_color_override("font_color", Color.WHITE)
	ok_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	ok_btn.add_theme_font_size_override("font_size", 15)
	if UITheme: UITheme.apply_font(ok_btn, "bold")
	ok_btn.pressed.connect(_on_ok)
	btn_center.add_child(ok_btn)

	if UITheme:
		UITheme.fade_in(self, 0.25)
	else:
		visible = true

func _on_ok():
	if UITheme:
		UITheme.fade_out(self, 0.2)
	else:
		visible = false
