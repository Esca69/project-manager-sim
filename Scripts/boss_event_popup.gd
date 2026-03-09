extends Control

# === UI попап для ивентов босса ===
# Два режима:
#   open(event_data)      — выбор: принять / отклонить
#   open_info(event_data) — read-only: понятно

const COLOR_BLUE = Color(0.17254902, 0.30980393, 0.5686275, 1)
const COLOR_WHITE = Color(1, 1, 1, 1)
const COLOR_DARK = Color(0.2, 0.2, 0.2, 1)
const COLOR_GREEN = Color(0.29803923, 0.6862745, 0.3137255, 1)
const COLOR_RED = Color(0.8980392, 0.22352941, 0.20784314, 1)
const COLOR_GRAY = Color(0.55, 0.55, 0.55, 1)
const COLOR_WINDOW_BORDER = Color(0, 0, 0, 1)

const WINDOW_WIDTH = 550
const WINDOW_HEIGHT = 400

var _overlay: ColorRect
var _window: PanelContainer
var _header_label: Label
var _content_vbox: VBoxContainer
var _buttons_hbox: HBoxContainer

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 200
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func _build_ui():
	# === OVERLAY ===
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.5)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	# === ОКНО ===
	_window = PanelContainer.new()
	_window.custom_minimum_size = Vector2(WINDOW_WIDTH, 0)
	_window.set_anchors_preset(Control.PRESET_CENTER)
	_window.offset_left = -WINDOW_WIDTH / 2.0
	_window.offset_right = WINDOW_WIDTH / 2.0
	_window.offset_top = -WINDOW_HEIGHT / 2.0
	_window.offset_bottom = WINDOW_HEIGHT / 2.0
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

	# === СИНИЙ ХЕДЕР ===
	var header_panel = Panel.new()
	header_panel.custom_minimum_size = Vector2(0, 48)
	var header_style = StyleBoxFlat.new()
	header_style.bg_color = COLOR_BLUE
	header_style.corner_radius_top_left = 20
	header_style.corner_radius_top_right = 20
	header_panel.add_theme_stylebox_override("panel", header_style)
	main_vbox.add_child(header_panel)

	_header_label = Label.new()
	_header_label.set_anchors_preset(Control.PRESET_CENTER)
	_header_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_header_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_header_label.offset_left = -200
	_header_label.offset_top = -12
	_header_label.offset_right = 200
	_header_label.offset_bottom = 12
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_label.add_theme_color_override("font_color", COLOR_WHITE)
	_header_label.add_theme_font_size_override("font_size", 17)
	if UITheme:
		UITheme.apply_font(_header_label, "bold")
	header_panel.add_child(_header_label)

	# === КОНТЕНТ ===
	var content_margin = MarginContainer.new()
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_left", 28)
	content_margin.add_theme_constant_override("margin_top", 18)
	content_margin.add_theme_constant_override("margin_right", 28)
	content_margin.add_theme_constant_override("margin_bottom", 12)
	main_vbox.add_child(content_margin)

	_content_vbox = VBoxContainer.new()
	_content_vbox.add_theme_constant_override("separation", 12)
	content_margin.add_child(_content_vbox)

	# === КНОПКИ ===
	var buttons_margin = MarginContainer.new()
	buttons_margin.add_theme_constant_override("margin_left", 28)
	buttons_margin.add_theme_constant_override("margin_right", 28)
	buttons_margin.add_theme_constant_override("margin_bottom", 20)
	main_vbox.add_child(buttons_margin)

	_buttons_hbox = HBoxContainer.new()
	_buttons_hbox.add_theme_constant_override("separation", 14)
	_buttons_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons_margin.add_child(_buttons_hbox)

# ============================================================
#                   РЕЖИМ ВЫБОРА
# ============================================================

func open(event_data: Dictionary):
	_clear_dynamic_content()
	_header_label.text = tr("BOSS_EVENT_POPUP_TITLE")
	_populate_content(event_data, false)
	_populate_buttons_choice()
	if UITheme:
		UITheme.fade_in(self, 0.25)
	else:
		visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP

# ============================================================
#                   РЕЖИМ READ-ONLY
# ============================================================

func open_info(event_data: Dictionary):
	_clear_dynamic_content()
	_header_label.text = tr("BOSS_EVENT_POPUP_ACTIVE_TITLE")
	_populate_content(event_data, true)
	_populate_buttons_info()
	if UITheme:
		UITheme.fade_in(self, 0.25)
	else:
		visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP

# ============================================================
#                   ПОСТРОЕНИЕ КОНТЕНТА
# ============================================================

func _populate_content(event_data: Dictionary, is_active: bool):
	var emoji = event_data.get("emoji", "🏢")
	var title_key = event_data.get("title_key", "")
	var desc_key = event_data.get("desc_key", "")
	var min_days = event_data.get("min_days", 0)
	var max_days = event_data.get("max_days", 0)
	var trust_accept = event_data.get("trust_accept", 0)
	var trust_reject = event_data.get("trust_reject", 0)

	# Заголовок ивента
	var title_lbl = Label.new()
	title_lbl.text = emoji + "  " + tr(title_key)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_color_override("font_color", COLOR_BLUE)
	title_lbl.add_theme_font_size_override("font_size", 17)
	if UITheme:
		UITheme.apply_font(title_lbl, "bold")
	_content_vbox.add_child(title_lbl)

	# Описание
	var desc_lbl = Label.new()
	desc_lbl.text = tr(desc_key)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_color_override("font_color", COLOR_DARK)
	desc_lbl.add_theme_font_size_override("font_size", 14)
	if UITheme:
		UITheme.apply_font(desc_lbl, "regular")
	_content_vbox.add_child(desc_lbl)

	var sep = HSeparator.new()
	_content_vbox.add_child(sep)

	# Длительность
	var dur_lbl = Label.new()
	if max_days <= 0:
		dur_lbl.text = tr("BOSS_EVENT_POPUP_DURATION_INSTANT")
	else:
		dur_lbl.text = tr("BOSS_EVENT_POPUP_DURATION") % [min_days, max_days]
	dur_lbl.add_theme_color_override("font_color", COLOR_GRAY)
	dur_lbl.add_theme_font_size_override("font_size", 13)
	if UITheme:
		UITheme.apply_font(dur_lbl, "regular")
	_content_vbox.add_child(dur_lbl)

	if is_active:
		# Дней осталось
		var days_left = BossEventSystem.active_days_remaining
		var days_lbl = Label.new()
		days_lbl.text = tr("BOSS_EVENT_POPUP_DAYS_LEFT") % days_left
		days_lbl.add_theme_color_override("font_color", COLOR_BLUE)
		days_lbl.add_theme_font_size_override("font_size", 14)
		if UITheme:
			UITheme.apply_font(days_lbl, "semibold")
		_content_vbox.add_child(days_lbl)
	else:
		# Инфо о доверии
		var trust_accept_lbl = Label.new()
		trust_accept_lbl.text = tr("BOSS_EVENT_POPUP_TRUST_ACCEPT") % trust_accept
		trust_accept_lbl.add_theme_color_override("font_color", COLOR_GREEN)
		trust_accept_lbl.add_theme_font_size_override("font_size", 13)
		if UITheme:
			UITheme.apply_font(trust_accept_lbl, "semibold")
		_content_vbox.add_child(trust_accept_lbl)

		var trust_reject_lbl = Label.new()
		trust_reject_lbl.text = tr("BOSS_EVENT_POPUP_TRUST_REJECT") % trust_reject
		trust_reject_lbl.add_theme_color_override("font_color", COLOR_RED)
		trust_reject_lbl.add_theme_font_size_override("font_size", 13)
		if UITheme:
			UITheme.apply_font(trust_reject_lbl, "semibold")
		_content_vbox.add_child(trust_reject_lbl)

func _populate_buttons_choice():
	# Кнопка "Принять"
	var accept_btn = _make_button(tr("BOSS_EVENT_POPUP_ACCEPT"), COLOR_GREEN)
	accept_btn.pressed.connect(_on_accept_pressed)
	_buttons_hbox.add_child(accept_btn)

	# Кнопка "Отклонить"
	var reject_btn = _make_button(tr("BOSS_EVENT_POPUP_REJECT"), COLOR_RED)
	reject_btn.pressed.connect(_on_reject_pressed)
	_buttons_hbox.add_child(reject_btn)

func _populate_buttons_info():
	var ok_btn = _make_button(tr("BOSS_EVENT_POPUP_OK"), COLOR_BLUE)
	ok_btn.pressed.connect(_fade_out)
	_buttons_hbox.add_child(ok_btn)

func _make_button(text: String, color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(180, 44)
	btn.focus_mode = Control.FOCUS_NONE

	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_right = 14
	style.corner_radius_bottom_left = 14
	btn.add_theme_stylebox_override("normal", style)

	var style_hover = style.duplicate()
	style_hover.bg_color = color.lightened(0.1)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_hover)

	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 15)
	if UITheme:
		UITheme.apply_font(btn, "bold")
	return btn

# ============================================================
#                   ОБРАБОТКА КНОПОК
# ============================================================

func _on_accept_pressed():
	BossEventSystem.accept_event()
	_fade_out()

func _on_reject_pressed():
	BossEventSystem.reject_event()
	_fade_out()

func _fade_out():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if UITheme:
		UITheme.fade_out(self, 0.2)
	else:
		visible = false

# ============================================================
#                   ОЧИСТКА
# ============================================================

func _clear_dynamic_content():
	for child in _content_vbox.get_children():
		child.queue_free()
	for child in _buttons_hbox.get_children():
		child.queue_free()
