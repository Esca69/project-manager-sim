extends Control

# === ПАНЕЛЬ "МОЯ ЖИЗНЬ" ===

const COLOR_BLUE = Color(0.17254902, 0.30980393, 0.5686275, 1)
const COLOR_GREEN = Color(0.29803923, 0.6862745, 0.3137255, 1)
const COLOR_GOLD = Color(0.85, 0.65, 0.13, 1)
const COLOR_WHITE = Color(1, 1, 1, 1)
const COLOR_DARK = Color(0.2, 0.2, 0.2, 1)
const COLOR_GRAY = Color(0.5, 0.5, 0.5, 1)
const COLOR_BORDER = Color(0.8784314, 0.8784314, 0.8784314, 1)
const COLOR_WINDOW_BORDER = Color(0, 0, 0, 1)
const COLOR_BG = Color(0.94, 0.95, 0.97, 1)

var _window: PanelContainer
var _content_vbox: VBoxContainer
var _progress_bar: ProgressBar
var _progress_label: Label
var _salary_label: Label
var _daily_label: Label
var _partner_label: Label
var _balance_label: Label
var _win_btn: Button

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	z_index = 80
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	PMData.personal_balance_changed.connect(_on_balance_changed)

func open():
	_refresh()
	if UITheme:
		UITheme.fade_in(self, 0.2)
	else:
		visible = true

func _build_ui():
	# Полупрозрачный оверлей
	var overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.35)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.pressed = null
	add_child(overlay)
	overlay.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_close()
	)

	# Окно — позиционируем как остальные панели (внизу справа)
	_window = PanelContainer.new()
	_window.custom_minimum_size = Vector2(650, 560)
	_window.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_window.offset_left = -680
	_window.offset_top = -640
	_window.offset_right = -20
	_window.offset_bottom = -80
	_window.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_window.grow_vertical = Control.GROW_DIRECTION_BEGIN

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

	# Заголовок
	var header_panel = Panel.new()
	header_panel.custom_minimum_size = Vector2(0, 50)
	var header_style = StyleBoxFlat.new()
	header_style.bg_color = COLOR_BLUE
	header_style.corner_radius_top_left = 20
	header_style.corner_radius_top_right = 20
	header_panel.add_theme_stylebox_override("panel", header_style)
	main_vbox.add_child(header_panel)

	var title_lbl = Label.new()
	title_lbl.text = tr("MY_LIFE_TITLE")
	title_lbl.set_anchors_preset(Control.PRESET_CENTER)
	title_lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title_lbl.grow_vertical = Control.GROW_DIRECTION_BOTH
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_color_override("font_color", COLOR_WHITE)
	title_lbl.add_theme_font_size_override("font_size", 18)
	if UITheme: UITheme.apply_font(title_lbl, "bold")
	header_panel.add_child(title_lbl)

	# Контент
	var content_margin = MarginContainer.new()
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_left", 25)
	content_margin.add_theme_constant_override("margin_top", 20)
	content_margin.add_theme_constant_override("margin_right", 25)
	content_margin.add_theme_constant_override("margin_bottom", 20)
	main_vbox.add_child(content_margin)

	_content_vbox = VBoxContainer.new()
	_content_vbox.add_theme_constant_override("separation", 16)
	content_margin.add_child(_content_vbox)

	# === Большой эмодзи машины ===
	var car_lbl = Label.new()
	car_lbl.text = "🏎️"
	car_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	car_lbl.add_theme_font_size_override("font_size", 56)
	_content_vbox.add_child(car_lbl)

	# === Баланс ===
	_balance_label = Label.new()
	_balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_balance_label.add_theme_color_override("font_color", COLOR_GOLD)
	_balance_label.add_theme_font_size_override("font_size", 28)
	if UITheme: UITheme.apply_font(_balance_label, "bold")
	_content_vbox.add_child(_balance_label)

	# === Прогресс-бар накоплений ===
	var progress_card = _make_card()
	_content_vbox.add_child(progress_card)
	var progress_inner = _get_card_inner(progress_card)

	var prog_lbl_header = Label.new()
	prog_lbl_header.text = "🚀 " + tr("INTRO_LINE_1").substr(0, 30) + "..."
	prog_lbl_header.add_theme_color_override("font_color", COLOR_GRAY)
	prog_lbl_header.add_theme_font_size_override("font_size", 11)
	if UITheme: UITheme.apply_font(prog_lbl_header, "regular")
	progress_inner.add_child(prog_lbl_header)

	_progress_label = Label.new()
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_label.add_theme_color_override("font_color", COLOR_DARK)
	_progress_label.add_theme_font_size_override("font_size", 15)
	if UITheme: UITheme.apply_font(_progress_label, "semibold")
	progress_inner.add_child(_progress_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(0, 22)
	_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress_bar.min_value = 0
	_progress_bar.max_value = PMData.WIN_TARGET
	_progress_bar.show_percentage = false
	progress_inner.add_child(_progress_bar)

	# === Статистика ЗП ===
	var salary_card = _make_card()
	_content_vbox.add_child(salary_card)
	var salary_inner = _get_card_inner(salary_card)

	_salary_label = Label.new()
	_salary_label.add_theme_color_override("font_color", COLOR_DARK)
	_salary_label.add_theme_font_size_override("font_size", 15)
	if UITheme: UITheme.apply_font(_salary_label, "semibold")
	salary_inner.add_child(_salary_label)

	_daily_label = Label.new()
	_daily_label.add_theme_color_override("font_color", COLOR_GRAY)
	_daily_label.add_theme_font_size_override("font_size", 13)
	if UITheme: UITheme.apply_font(_daily_label, "regular")
	salary_inner.add_child(_daily_label)

	# === Партнёрство ===
	var partner_card = _make_card()
	_content_vbox.add_child(partner_card)
	var partner_inner = _get_card_inner(partner_card)

	_partner_label = Label.new()
	_partner_label.add_theme_color_override("font_color", COLOR_BLUE)
	_partner_label.add_theme_font_size_override("font_size", 14)
	if UITheme: UITheme.apply_font(_partner_label, "semibold")
	partner_inner.add_child(_partner_label)

	# === Кнопка победы (скрыта до накопления цели) ===
	_win_btn = Button.new()
	_win_btn.text = tr("MY_LIFE_WIN_BTN")
	_win_btn.custom_minimum_size = Vector2(0, 48)
	_win_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_win_btn.visible = false
	_win_btn.focus_mode = Control.FOCUS_NONE

	var win_style = StyleBoxFlat.new()
	win_style.bg_color = COLOR_GOLD
	win_style.corner_radius_top_left = 14
	win_style.corner_radius_top_right = 14
	win_style.corner_radius_bottom_right = 14
	win_style.corner_radius_bottom_left = 14

	_win_btn.add_theme_stylebox_override("normal", win_style)
	_win_btn.add_theme_stylebox_override("hover", win_style)
	_win_btn.add_theme_color_override("font_color", Color.WHITE)
	_win_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	_win_btn.add_theme_font_size_override("font_size", 16)
	if UITheme: UITheme.apply_font(_win_btn, "bold")
	_win_btn.pressed.connect(func(): print("🏆 Победа! Бамборгини куплена!"))
	_content_vbox.add_child(_win_btn)

func _make_card() -> PanelContainer:
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_BG
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = COLOR_BORDER
	card.add_theme_stylebox_override("panel", style)
	return card

const COLOR_BG = Color(0.96, 0.97, 1.0, 1)

func _get_card_inner(card: PanelContainer) -> VBoxContainer:
	var m = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 16)
	m.add_theme_constant_override("margin_top", 12)
	m.add_theme_constant_override("margin_right", 16)
	m.add_theme_constant_override("margin_bottom", 12)
	card.add_child(m)
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	m.add_child(vb)
	return vb

func _refresh():
	var balance = PMData.personal_balance
	var target = PMData.WIN_TARGET

	_balance_label.text = "$%d" % balance

	_progress_label.text = tr("MY_LIFE_PROGRESS") % [balance, target]
	_progress_bar.value = balance

	# Цвет прогресс-бара
	var pct = float(balance) / float(target)
	var bar_color: Color
	if pct < 0.33:
		bar_color = Color(0.9, 0.25, 0.25, 1)
	elif pct < 0.66:
		bar_color = Color(1.0, 0.7, 0.0, 1)
	else:
		bar_color = COLOR_GREEN
	_progress_bar.add_theme_color_override("font_color", bar_color)
	# Красим fill через StyleBoxFlat
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = bar_color
	fill_style.corner_radius_top_left = 6
	fill_style.corner_radius_top_right = 6
	fill_style.corner_radius_bottom_right = 6
	fill_style.corner_radius_bottom_left = 6
	_progress_bar.add_theme_stylebox_override("fill", fill_style)

	_salary_label.text = tr("MY_LIFE_MONTHLY_SALARY") % PMData.monthly_salary
	_daily_label.text = tr("MY_LIFE_DAILY_RATE") % PMData.get_daily_salary()
	_partner_label.text = tr("MY_LIFE_PARTNERSHIP") % PMData.get_partner_name()

	_win_btn.visible = balance >= target

func _on_balance_changed(_new_amount: int):
	if visible:
		_refresh()

func _close():
	if UITheme:
		UITheme.fade_out(self, 0.15)
	else:
		visible = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and visible:
		_close()
		get_viewport().set_input_as_handled()
