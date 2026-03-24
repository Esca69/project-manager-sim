extends Control

# === REPORTS PANEL ===
# Overlay 1500×900 with Finance / People tabs

const COLOR_BLUE   = Color(0.17254902, 0.30980393, 0.5686275, 1)
const COLOR_GREEN  = Color(0.29803923, 0.6862745, 0.3137255, 1)
const COLOR_WHITE  = Color(1, 1, 1, 1)
const COLOR_DARK   = Color(0.2, 0.2, 0.2, 1)
const COLOR_GRAY   = Color(0.5, 0.5, 0.5, 1)
const COLOR_WINDOW_BORDER = Color(0, 0, 0, 1)
const COLOR_BORDER = Color(0.8784314, 0.8784314, 0.8784314, 1)

var _window: PanelContainer
var _content_area: Control
var _finance_tab_btn: Button
var _people_tab_btn: Button
var _finance_content: Control
var _people_placeholder: Control

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	z_index = 90
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_force_fullscreen_size()
	_build_ui()

func _force_fullscreen_size():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0; offset_top = 0; offset_right = 0; offset_bottom = 0

func open():
	_force_fullscreen_size()
	_refresh_content()
	if UITheme:
		UITheme.fade_in(self, 0.2)
	else:
		visible = true

func close():
	if UITheme:
		UITheme.fade_out(self)
	else:
		visible = false

func _build_ui():
	# === OVERLAY ===
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.45)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# === WINDOW ===
	_window = PanelContainer.new()
	_window.custom_minimum_size = Vector2(1500, 900)
	_window.set_anchors_preset(Control.PRESET_CENTER)
	_window.offset_left = -750
	_window.offset_top = -450
	_window.offset_right = 750
	_window.offset_bottom = 450

	var window_style = StyleBoxFlat.new()
	window_style.bg_color = Color(0.96, 0.97, 0.99, 1)
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

	# === HEADER ===
	var header_panel = Panel.new()
	header_panel.custom_minimum_size = Vector2(0, 48)
	var header_style = StyleBoxFlat.new()
	header_style.bg_color = COLOR_BLUE
	header_style.corner_radius_top_left = 20
	header_style.corner_radius_top_right = 20
	header_panel.add_theme_stylebox_override("panel", header_style)
	main_vbox.add_child(header_panel)

	var title_lbl = Label.new()
	title_lbl.text = tr("REPORTS_TITLE")
	title_lbl.set_anchors_preset(Control.PRESET_CENTER)
	title_lbl.add_theme_color_override("font_color", COLOR_WHITE)
	title_lbl.add_theme_font_size_override("font_size", 16)
	if UITheme: UITheme.apply_font(title_lbl, "bold")
	header_panel.add_child(title_lbl)

	# Close button
	var close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	close_btn.offset_left = -48
	close_btn.offset_top = -14
	close_btn.offset_right = -8
	close_btn.offset_bottom = 14
	close_btn.focus_mode = Control.FOCUS_NONE
	var close_style = StyleBoxFlat.new()
	close_style.bg_color = COLOR_WHITE
	close_style.corner_radius_top_left = 6
	close_style.corner_radius_top_right = 6
	close_style.corner_radius_bottom_right = 6
	close_style.corner_radius_bottom_left = 6
	close_btn.add_theme_stylebox_override("normal", close_style)
	close_btn.add_theme_stylebox_override("hover", close_style)
	close_btn.add_theme_stylebox_override("pressed", close_style)
	close_btn.add_theme_color_override("font_color", COLOR_BLUE)
	close_btn.add_theme_color_override("font_hover_color", COLOR_BLUE)
	close_btn.add_theme_font_size_override("font_size", 14)
	if UITheme: UITheme.apply_font(close_btn, "bold")
	close_btn.pressed.connect(close)
	header_panel.add_child(close_btn)

	# === TAB BAR ===
	var tab_bar = HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 0)
	tab_bar.custom_minimum_size = Vector2(0, 42)
	var tab_bar_style = StyleBoxFlat.new()
	tab_bar_style.bg_color = Color(0.93, 0.95, 0.98, 1)
	var tab_bar_panel = PanelContainer.new()
	tab_bar_panel.add_theme_stylebox_override("panel", tab_bar_style)
	main_vbox.add_child(tab_bar_panel)
	tab_bar_panel.add_child(tab_bar)

	_finance_tab_btn = _make_tab_btn(tr("REPORTS_TAB_FINANCE"), true)
	_finance_tab_btn.pressed.connect(_on_finance_tab)
	tab_bar.add_child(_finance_tab_btn)

	_people_tab_btn = _make_tab_btn(tr("REPORTS_TAB_PEOPLE"), false)
	_people_tab_btn.pressed.connect(_on_people_tab)
	tab_bar.add_child(_people_tab_btn)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_bar.add_child(spacer)

	# === CONTENT AREA ===
	var content_margin = MarginContainer.new()
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_left", 16)
	content_margin.add_theme_constant_override("margin_top", 12)
	content_margin.add_theme_constant_override("margin_right", 16)
	content_margin.add_theme_constant_override("margin_bottom", 12)
	main_vbox.add_child(content_margin)

	_content_area = Control.new()
	_content_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_area.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_content_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_margin.add_child(_content_area)

	# Finance tab content
	var finance_script = load("res://Scripts/financial_reports_tab.gd")
	_finance_content = Control.new()
	_finance_content.set_script(finance_script)
	_finance_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_finance_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_finance_content.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_content_area.add_child(_finance_content)

	# People placeholder
	_people_placeholder = Control.new()
	_people_placeholder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_people_placeholder.visible = false
	var coming_soon_lbl = Label.new()
	coming_soon_lbl.text = tr("REPORTS_COMING_SOON")
	coming_soon_lbl.set_anchors_preset(Control.PRESET_CENTER)
	coming_soon_lbl.add_theme_color_override("font_color", COLOR_GRAY)
	coming_soon_lbl.add_theme_font_size_override("font_size", 24)
	if UITheme: UITheme.apply_font(coming_soon_lbl, "semibold")
	_people_placeholder.add_child(coming_soon_lbl)
	_content_area.add_child(_people_placeholder)

func _make_tab_btn(text: String, active: bool) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(160, 40)
	btn.focus_mode = Control.FOCUS_NONE
	_apply_tab_style(btn, active)
	if UITheme: UITheme.apply_font(btn, "semibold")
	return btn

func _apply_tab_style(btn: Button, active: bool):
	var s = StyleBoxFlat.new()
	s.bg_color = COLOR_BLUE if active else Color(0.93, 0.95, 0.98, 1)
	s.corner_radius_top_left = 0
	s.corner_radius_top_right = 0
	s.corner_radius_bottom_right = 0
	s.corner_radius_bottom_left = 0
	if active:
		s.border_width_bottom = 3
		s.border_color = COLOR_BLUE
	btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_stylebox_override("hover", s)
	btn.add_theme_stylebox_override("pressed", s)
	btn.add_theme_color_override("font_color", COLOR_WHITE if active else COLOR_DARK)
	btn.add_theme_color_override("font_hover_color", COLOR_WHITE if active else COLOR_DARK)
	btn.add_theme_color_override("font_pressed_color", COLOR_WHITE if active else COLOR_DARK)

func _on_finance_tab():
	_apply_tab_style(_finance_tab_btn, true)
	_apply_tab_style(_people_tab_btn, false)
	_finance_content.visible = true
	_people_placeholder.visible = false
	_refresh_finance()

func _on_people_tab():
	_apply_tab_style(_finance_tab_btn, false)
	_apply_tab_style(_people_tab_btn, true)
	_finance_content.visible = false
	_people_placeholder.visible = true

func _refresh_content():
	_refresh_finance()

func _refresh_finance():
	if _finance_content and _finance_content.has_method("refresh"):
		_finance_content.refresh()
