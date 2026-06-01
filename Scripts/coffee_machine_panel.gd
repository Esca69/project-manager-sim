extends Control

const COLOR_BLUE = Color(0.17254902, 0.30980393, 0.5686275, 1)
const COLOR_RED  = Color(0.8980392, 0.22352941, 0.20784314, 1)
const COLOR_WHITE = Color(1, 1, 1, 1)
const COLOR_GREEN = Color(0.29803923, 0.6862745, 0.3137255, 1)
const COLOR_WINDOW_BORDER = Color(0, 0, 0, 1)

var _current_machine = null
var _was_paused: bool = false
var _overlay: ColorRect
var _window: PanelContainer
var _content_vbox: VBoxContainer

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 92
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func open_for_machine(machine):
	_was_paused = GameTime.is_game_paused
	GameTime.set_paused(true)
	_current_machine = machine
	_refresh()
	mouse_filter = Control.MOUSE_FILTER_STOP
	if UITheme:
		UITheme.fade_in(self, 0.2)
	else:
		visible = true

func _close():
	_current_machine = null
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameTime.set_paused(_was_paused)
	if UITheme:
		UITheme.fade_out(self, 0.15)
	else:
		visible = false

func _build_ui():
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.4)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.gui_input.connect(_on_overlay_input)
	add_child(_overlay)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_window = PanelContainer.new()
	_window.custom_minimum_size = Vector2(420, 0)
	var win_style = StyleBoxFlat.new()
	win_style.bg_color = COLOR_WHITE
	win_style.border_width_left = 2
	win_style.border_width_top = 2
	win_style.border_width_right = 2
	win_style.border_width_bottom = 2
	win_style.border_color = COLOR_WINDOW_BORDER
	win_style.corner_radius_top_left = 18
	win_style.corner_radius_top_right = 18
	win_style.corner_radius_bottom_right = 16
	win_style.corner_radius_bottom_left = 16
	if UITheme:
		UITheme.apply_shadow(win_style, false)
	_window.add_theme_stylebox_override("panel", win_style)
	center.add_child(_window)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 0)
	_window.add_child(main_vbox)

	var header = Panel.new()
	header.custom_minimum_size = Vector2(0, 40)
	var header_style = StyleBoxFlat.new()
	header_style.bg_color = COLOR_BLUE
	header_style.corner_radius_top_left = 16
	header_style.corner_radius_top_right = 16
	header.add_theme_stylebox_override("panel", header_style)
	main_vbox.add_child(header)

	var title = Label.new()
	title.text = tr("COFFEE_MACHINE_PANEL_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title.grow_vertical = Control.GROW_DIRECTION_BOTH
	title.add_theme_color_override("font_color", COLOR_WHITE)
	title.add_theme_font_size_override("font_size", 15)
	if UITheme:
		UITheme.apply_font(title, "bold")
	header.add_child(title)

	var content_margin = MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 20)
	content_margin.add_theme_constant_override("margin_top", 16)
	content_margin.add_theme_constant_override("margin_right", 20)
	content_margin.add_theme_constant_override("margin_bottom", 16)
	main_vbox.add_child(content_margin)

	_content_vbox = VBoxContainer.new()
	_content_vbox.add_theme_constant_override("separation", 12)
	content_margin.add_child(_content_vbox)

	var footer_margin = MarginContainer.new()
	footer_margin.add_theme_constant_override("margin_bottom", 12)
	footer_margin.add_theme_constant_override("margin_left", 16)
	footer_margin.add_theme_constant_override("margin_right", 16)
	main_vbox.add_child(footer_margin)

	var close_center = CenterContainer.new()
	footer_margin.add_child(close_center)

	var close_btn = Button.new()
	close_btn.text = tr("PANEL_CLOSE")
	close_btn.custom_minimum_size = Vector2(160, 36)
	close_btn.focus_mode = Control.FOCUS_NONE
	var close_style = StyleBoxFlat.new()
	close_style.bg_color = COLOR_WHITE
	close_style.border_width_left = 2
	close_style.border_width_top = 2
	close_style.border_width_right = 2
	close_style.border_width_bottom = 2
	close_style.border_color = COLOR_BLUE
	close_style.corner_radius_top_left = 18
	close_style.corner_radius_top_right = 18
	close_style.corner_radius_bottom_right = 18
	close_style.corner_radius_bottom_left = 18
	close_btn.add_theme_stylebox_override("normal", close_style)
	var close_hover = close_style.duplicate()
	close_hover.bg_color = COLOR_BLUE
	close_btn.add_theme_stylebox_override("hover", close_hover)
	close_btn.add_theme_stylebox_override("pressed", close_hover)
	close_btn.add_theme_color_override("font_color", COLOR_BLUE)
	close_btn.add_theme_color_override("font_hover_color", COLOR_WHITE)
	close_btn.add_theme_color_override("font_pressed_color", COLOR_WHITE)
	if UITheme:
		UITheme.apply_font(close_btn, "semibold")
	close_btn.pressed.connect(_close)
	close_center.add_child(close_btn)

func _refresh():
	for child in _content_vbox.get_children():
		child.queue_free()

	if not _current_machine or not _current_machine.is_broken:
		_close()
		return

	var banner = Label.new()
	banner.text = tr("COFFEE_MACHINE_BROKEN_BANNER")
	banner.add_theme_color_override("font_color", COLOR_RED)
	banner.add_theme_font_size_override("font_size", 14)
	banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if UITheme:
		UITheme.apply_font(banner, "semibold")
	_content_vbox.add_child(banner)

	var repair_btn = Button.new()
	repair_btn.text = tr("COFFEE_MACHINE_REPAIR_BTN") + " ($%d)" % _current_machine.COFFEE_MACHINE_REPAIR_COST
	repair_btn.custom_minimum_size = Vector2(220, 40)
	repair_btn.focus_mode = Control.FOCUS_NONE
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = COLOR_GREEN
	btn_style.corner_radius_top_left = 20
	btn_style.corner_radius_top_right = 20
	btn_style.corner_radius_bottom_right = 20
	btn_style.corner_radius_bottom_left = 20
	repair_btn.add_theme_stylebox_override("normal", btn_style)
	repair_btn.add_theme_stylebox_override("hover", btn_style)
	repair_btn.add_theme_stylebox_override("pressed", btn_style)
	repair_btn.add_theme_color_override("font_color", COLOR_WHITE)
	repair_btn.add_theme_font_size_override("font_size", 14)
	if UITheme:
		UITheme.apply_font(repair_btn, "semibold")
	repair_btn.pressed.connect(_on_repair_pressed)

	var btn_center = CenterContainer.new()
	btn_center.add_child(repair_btn)
	_content_vbox.add_child(btn_center)

func _on_repair_pressed():
	if not _current_machine:
		return
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.company_balance < _current_machine.COFFEE_MACHINE_REPAIR_COST:
		var el = get_node_or_null("/root/EventLog")
		if el:
			el.add(tr("TXT_NOT_ENOUGH_MONEY"), el.LogType.ALERT)
		return
	var ok = _current_machine.repair_machine()
	if ok:
		_close()

func _on_overlay_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		_close()
