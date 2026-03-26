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

var _overlay: ColorRect
var _window: PanelContainer
var _title_label: Label
var _close_btn: Button
var _content_area: Control
var _finance_tab_btn: Button
var _people_tab_btn: Button
var _finance_content: Control
var _people_content: Control
var _lock_label: Label

var _tab_bg_style: StyleBoxFlat
var _tab_active_style: StyleBoxFlat
var _tab_inactive_style: StyleBoxFlat

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
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.45)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

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
	header_panel.custom_minimum_size = Vector2(0, 40)
	var header_style = StyleBoxFlat.new()
	header_style.bg_color = COLOR_BLUE
	header_style.border_color = COLOR_WINDOW_BORDER
	header_style.corner_radius_top_left = 20
	header_style.corner_radius_top_right = 20
	header_panel.add_theme_stylebox_override("panel", header_style)
	main_vbox.add_child(header_panel)

	_title_label = Label.new()
	_title_label.text = tr("REPORTS_TITLE")
	_title_label.set_anchors_preset(Control.PRESET_CENTER)
	_title_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_title_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_title_label.offset_left = -120
	_title_label.offset_top = -11.5
	_title_label.offset_right = 120
	_title_label.offset_bottom = 11.5
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_color_override("font_color", COLOR_WHITE)
	_title_label.add_theme_font_size_override("font_size", 16)
	if UITheme: UITheme.apply_font(_title_label, "bold")
	header_panel.add_child(_title_label)

	# Close button
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

	# === PILL TABS ===
	_tab_bg_style = StyleBoxFlat.new()
	_tab_bg_style.bg_color = Color(0.92, 0.94, 0.96, 1)
	_tab_bg_style.corner_radius_top_left = 24
	_tab_bg_style.corner_radius_top_right = 24
	_tab_bg_style.corner_radius_bottom_right = 24
	_tab_bg_style.corner_radius_bottom_left = 24

	_tab_active_style = StyleBoxFlat.new()
	_tab_active_style.bg_color = Color(1, 1, 1, 1)
	_tab_active_style.corner_radius_top_left = 20
	_tab_active_style.corner_radius_top_right = 20
	_tab_active_style.corner_radius_bottom_right = 20
	_tab_active_style.corner_radius_bottom_left = 20

	_tab_inactive_style = StyleBoxFlat.new()
	_tab_inactive_style.bg_color = Color(0, 0, 0, 0)
	_tab_inactive_style.corner_radius_top_left = 20
	_tab_inactive_style.corner_radius_top_right = 20
	_tab_inactive_style.corner_radius_bottom_right = 20
	_tab_inactive_style.corner_radius_bottom_left = 20

	var tab_outer_margin = MarginContainer.new()
	tab_outer_margin.add_theme_constant_override("margin_top", 10)
	tab_outer_margin.add_theme_constant_override("margin_left", 16)
	tab_outer_margin.add_theme_constant_override("margin_right", 16)
	tab_outer_margin.add_theme_constant_override("margin_bottom", 0)
	main_vbox.add_child(tab_outer_margin)

	var tab_panel = PanelContainer.new()
	tab_panel.add_theme_stylebox_override("panel", _tab_bg_style)
	tab_panel.custom_minimum_size = Vector2(660, 50)
	tab_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tab_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	tab_outer_margin.add_child(tab_panel)

	var tab_margin = MarginContainer.new()
	tab_margin.add_theme_constant_override("margin_left", 6)
	tab_margin.add_theme_constant_override("margin_top", 6)
	tab_margin.add_theme_constant_override("margin_right", 6)
	tab_margin.add_theme_constant_override("margin_bottom", 6)
	tab_panel.add_child(tab_margin)

	var tab_hbox = HBoxContainer.new()
	tab_hbox.add_theme_constant_override("separation", 8)
	tab_margin.add_child(tab_hbox)

	_finance_tab_btn = Button.new()
	_finance_tab_btn.text = tr("REPORTS_TAB_FINANCE")
	_finance_tab_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_finance_tab_btn.focus_mode = Control.FOCUS_NONE
	if UITheme: UITheme.apply_font(_finance_tab_btn, "bold")
	_finance_tab_btn.pressed.connect(_on_finance_tab)
	tab_hbox.add_child(_finance_tab_btn)

	_people_tab_btn = Button.new()
	_people_tab_btn.text = tr("REPORTS_TAB_PEOPLE")
	_people_tab_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_people_tab_btn.focus_mode = Control.FOCUS_NONE
	if UITheme: UITheme.apply_font(_people_tab_btn, "bold")
	_people_tab_btn.pressed.connect(_on_people_tab)
	tab_hbox.add_child(_people_tab_btn)

	_apply_tab_styles(true)

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

	# People tab content
	var people_script = load("res://Scripts/people_reports_tab.gd")
	_people_content = Control.new()
	_people_content.set_script(people_script)
	_people_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_people_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_people_content.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_people_content.visible = false
	_content_area.add_child(_people_content)

	# Lock placeholder label
	_lock_label = Label.new()
	_lock_label.set_anchors_preset(Control.PRESET_CENTER)
	_lock_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_lock_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_lock_label.offset_left = -300
	_lock_label.offset_top = -30
	_lock_label.offset_right = 300
	_lock_label.offset_bottom = 30
	_lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lock_label.add_theme_color_override("font_color", COLOR_GRAY)
	_lock_label.add_theme_font_size_override("font_size", 18)
	if UITheme: UITheme.apply_font(_lock_label, "semibold")
	_lock_label.visible = false
	_content_area.add_child(_lock_label)

func _apply_tab_styles(finance_active: bool):
	_apply_button_style(_finance_tab_btn, _tab_active_style if finance_active else _tab_inactive_style, COLOR_BLUE if finance_active else COLOR_GRAY)
	_apply_button_style(_people_tab_btn, _tab_inactive_style if finance_active else _tab_active_style, COLOR_GRAY if finance_active else COLOR_BLUE)

func _apply_button_style(btn: Button, box_style: StyleBox, font_color: Color):
	btn.add_theme_stylebox_override("normal", box_style)
	btn.add_theme_stylebox_override("hover", box_style)
	btn.add_theme_stylebox_override("pressed", box_style)
	btn.add_theme_stylebox_override("focus", box_style)
	btn.add_theme_color_override("font_color", font_color)
	btn.add_theme_color_override("font_hover_color", font_color)
	btn.add_theme_color_override("font_pressed_color", font_color)
	btn.add_theme_color_override("font_focus_color", font_color)

func _on_finance_tab():
	_apply_tab_styles(true)
	if not PMData.has_skill("report_finance_tab"):
		_finance_content.visible = false
		_people_content.visible = false
		_lock_label.text = tr("REPORTS_LOCK_FINANCE")
		_lock_label.visible = true
		return
	_lock_label.visible = false
	_finance_content.visible = true
	_people_content.visible = false
	_refresh_finance()

func _on_people_tab():
	_apply_tab_styles(false)
	if not PMData.has_skill("report_people_tab"):
		_finance_content.visible = false
		_people_content.visible = false
		_lock_label.text = tr("REPORTS_LOCK_PEOPLE")
		_lock_label.visible = true
		return
	_lock_label.visible = false
	_finance_content.visible = false
	_people_content.visible = true
	_refresh_people()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and visible:
		close()
		get_viewport().set_input_as_handled()

func _refresh_content():
	if _people_content and _people_content.visible:
		if not PMData.has_skill("report_people_tab"):
			_people_content.visible = false
			_lock_label.text = tr("REPORTS_LOCK_PEOPLE")
			_lock_label.visible = true
			return
		_lock_label.visible = false
		_refresh_people()
	else:
		if not PMData.has_skill("report_finance_tab"):
			_finance_content.visible = false
			_lock_label.text = tr("REPORTS_LOCK_FINANCE")
			_lock_label.visible = true
			return
		_lock_label.visible = false
		_refresh_finance()

func _refresh_finance():
	if _finance_content and _finance_content.has_method("refresh"):
		_finance_content.refresh()

func _refresh_people():
	if _people_content and _people_content.has_method("refresh"):
		_people_content.refresh()
