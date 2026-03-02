extends Control

const PANEL_WIDTH = 350
const PANEL_HEIGHT = 250
const BOTTOM_BAR_HEIGHT = 50
const SIDE_MARGIN = 10
const BOTTOM_MARGIN = 10
const ICON_SIZE = 36
const SCROLL_TOLERANCE = 1

var _panel: PanelContainer
var _scroll: ScrollContainer
var _messages_vbox: VBoxContainer
var _title_label: Label
var _collapse_btn: Button
var _icon_btn: Button
var _is_collapsed: bool = false
var _pulse_tween: Tween = null

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	EventLog.log_added.connect(_on_log_added)
	EventLog.alert_added.connect(_on_alert_added)
	for entry in EventLog.entries:
		_add_message_label(entry)
	call_deferred("_scroll_to_bottom")

func _build_ui():
	# === FULL PANEL ===
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	_panel.anchor_left = 1.0
	_panel.anchor_top = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -(PANEL_WIDTH + SIDE_MARGIN)
	_panel.offset_right = -SIDE_MARGIN
	_panel.offset_top = -(PANEL_HEIGHT + BOTTOM_BAR_HEIGHT + BOTTOM_MARGIN)
	_panel.offset_bottom = -(BOTTOM_BAR_HEIGHT + BOTTOM_MARGIN)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.12, 0.75)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.corner_radius_bottom_left = 12
	if UITheme:
		UITheme.apply_shadow(panel_style)
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	_panel.add_child(vbox)

	# === HEADER ===
	var header_margin = MarginContainer.new()
	header_margin.add_theme_constant_override("margin_left", 10)
	header_margin.add_theme_constant_override("margin_top", 6)
	header_margin.add_theme_constant_override("margin_right", 6)
	header_margin.add_theme_constant_override("margin_bottom", 4)
	vbox.add_child(header_margin)

	var header_hbox = HBoxContainer.new()
	header_margin.add_child(header_hbox)

	_title_label = Label.new()
	_title_label.text = tr("LOG_PANEL_TITLE")
	_title_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
	_title_label.add_theme_font_size_override("font_size", 13)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if UITheme:
		UITheme.apply_font(_title_label, "semibold")
	header_hbox.add_child(_title_label)

	_collapse_btn = Button.new()
	_collapse_btn.text = "−"
	_collapse_btn.flat = true
	_collapse_btn.custom_minimum_size = Vector2(24, 24)
	_collapse_btn.focus_mode = Control.FOCUS_NONE
	_collapse_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	_collapse_btn.add_theme_font_size_override("font_size", 18)
	_collapse_btn.pressed.connect(_collapse)
	header_hbox.add_child(_collapse_btn)

	# Separator
	var sep = HSeparator.new()
	vbox.add_child(sep)

	# === SCROLL CONTAINER ===
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.clip_contents = true
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_scroll)

	var scroll_margin = MarginContainer.new()
	scroll_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_margin.add_theme_constant_override("margin_left", 8)
	scroll_margin.add_theme_constant_override("margin_top", 4)
	scroll_margin.add_theme_constant_override("margin_right", 8)
	scroll_margin.add_theme_constant_override("margin_bottom", 4)
	_scroll.add_child(scroll_margin)

	_messages_vbox = VBoxContainer.new()
	_messages_vbox.add_theme_constant_override("separation", 2)
	_messages_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_margin.add_child(_messages_vbox)

	# === COLLAPSED ICON BUTTON ===
	_icon_btn = Button.new()
	_icon_btn.text = "📋"
	_icon_btn.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	_icon_btn.anchor_left = 1.0
	_icon_btn.anchor_top = 1.0
	_icon_btn.anchor_right = 1.0
	_icon_btn.anchor_bottom = 1.0
	_icon_btn.offset_left = -(ICON_SIZE + SIDE_MARGIN)
	_icon_btn.offset_right = -SIDE_MARGIN
	_icon_btn.offset_top = -(ICON_SIZE + BOTTOM_BAR_HEIGHT + BOTTOM_MARGIN)
	_icon_btn.offset_bottom = -(BOTTOM_BAR_HEIGHT + BOTTOM_MARGIN)
	_icon_btn.focus_mode = Control.FOCUS_NONE
	_icon_btn.add_theme_font_size_override("font_size", 18)
	_icon_btn.pressed.connect(_expand)
	_icon_btn.visible = false
	add_child(_icon_btn)

func _add_message_label(entry: Dictionary):
	var lbl = Label.new()
	lbl.text = entry["text"]
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", _get_color_for_type(entry["type"]))
	if UITheme:
		UITheme.apply_font(lbl, "regular")
	_messages_vbox.add_child(lbl)
	while _messages_vbox.get_child_count() > EventLog.MAX_ENTRIES:
		_messages_vbox.get_child(0).queue_free()

func _get_color_for_type(type: int) -> Color:
	match type:
		EventLog.LogType.PROGRESS:
			return Color(0.4, 0.8, 0.5)
		EventLog.LogType.ALERT:
			return Color(1.0, 0.4, 0.3)
	return Color(0.75, 0.75, 0.75)

func _on_log_added(entry: Dictionary):
	_add_message_label(entry)
	var scrollbar = _scroll.get_v_scroll_bar()
	var at_bottom = scrollbar.value >= scrollbar.max_value - scrollbar.page - SCROLL_TOLERANCE
	if at_bottom or scrollbar.max_value <= scrollbar.page:
		call_deferred("_scroll_to_bottom")

func _scroll_to_bottom():
	if _scroll:
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)

func _on_alert_added():
	if _is_collapsed:
		_start_pulse()

func _collapse():
	_is_collapsed = true
	_panel.visible = false
	_icon_btn.visible = true

func _expand():
	_is_collapsed = false
	_panel.visible = true
	_icon_btn.visible = false
	_stop_pulse()
	call_deferred("_scroll_to_bottom")

func _start_pulse():
	if _pulse_tween and _pulse_tween.is_running():
		return
	_pulse_tween = create_tween()
	_pulse_tween.set_loops()
	_pulse_tween.tween_property(_icon_btn, "modulate", Color(1.0, 0.3, 0.2, 1), 0.5)
	_pulse_tween.tween_property(_icon_btn, "modulate", Color.WHITE, 0.5)

func _stop_pulse():
	if _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null
	_icon_btn.modulate = Color.WHITE
