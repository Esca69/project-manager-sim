extends Control

const COLOR_BLUE = Color(0.17254902, 0.30980393, 0.5686275, 1)
const COLOR_LIGHT_GRAY = Color(0.95, 0.95, 0.97, 1)
const COLOR_BTN_HOVER = Color(0.9, 0.93, 1.0, 1)
const COLOR_BTN_ACTIVE = Color(0.85, 0.9, 1.0, 1)
const BUTTON_CORNER_RADIUS = 8

var _topic_keys: Array = []
var _topic_buttons: Array = []
var _active_index: int = -1
var _content_title: Label
var _content_label: RichTextLabel
var _content_scroll: ScrollContainer
var _topics_vbox: VBoxContainer

var _categories_data: Array = [
	{"key": "ENCYCLOPEDIA_CAT_BASICS", "topics": [
		"ENCYCLOPEDIA_TOPIC_CONTROLS",
		"ENCYCLOPEDIA_TOPIC_TIME",
		"ENCYCLOPEDIA_TOPIC_UI",
	]},
	{"key": "ENCYCLOPEDIA_CAT_PROJECTS", "topics": [
		"ENCYCLOPEDIA_TOPIC_PROJECTS",
		"ENCYCLOPEDIA_TOPIC_CLASSIC_PROJECT",
		"ENCYCLOPEDIA_TOPIC_SUPPORT_PROJECT",
		"ENCYCLOPEDIA_TOPIC_PROGRESS_POINTS",
		"ENCYCLOPEDIA_TOPIC_DEADLINES",
		"ENCYCLOPEDIA_TOPIC_CRUNCH",
	]},
	{"key": "ENCYCLOPEDIA_CAT_EMPLOYEES", "topics": [
		"ENCYCLOPEDIA_TOPIC_EMPLOYEES",
		"ENCYCLOPEDIA_TOPIC_MOOD",
		"ENCYCLOPEDIA_TOPIC_EFFICIENCY",
		"ENCYCLOPEDIA_TOPIC_TRAITS",
		"ENCYCLOPEDIA_TOPIC_PERSONALITY",
		"ENCYCLOPEDIA_TOPIC_BURNOUT",
		"ENCYCLOPEDIA_TOPIC_RELATIONSHIPS",
		"ENCYCLOPEDIA_TOPIC_HIRING",
		"ENCYCLOPEDIA_TOPIC_RAISES",
		"ENCYCLOPEDIA_TOPIC_VACATIONS",
		"ENCYCLOPEDIA_TOPIC_EMPLOYEE_INTERACTIONS",
		"ENCYCLOPEDIA_TOPIC_PM_LOYALTY",
	]},
	{"key": "ENCYCLOPEDIA_CAT_CLIENTS", "topics": [
		"ENCYCLOPEDIA_TOPIC_CLIENTS",
		"ENCYCLOPEDIA_TOPIC_LOYALTY",
		"ENCYCLOPEDIA_TOPIC_GLOBAL_REPUTATION",
	]},
	{"key": "ENCYCLOPEDIA_CAT_BOSS", "topics": [
		"ENCYCLOPEDIA_TOPIC_BOSS_TRUST",
		"ENCYCLOPEDIA_TOPIC_BOSS_QUESTS",
		"ENCYCLOPEDIA_TOPIC_BOSS_EVENTS",
	]},
	{"key": "ENCYCLOPEDIA_CAT_FINANCE", "topics": [
		"ENCYCLOPEDIA_TOPIC_FINANCE",
		"ENCYCLOPEDIA_TOPIC_PM_LIFE",
		"ENCYCLOPEDIA_TOPIC_PARTNERSHIP",
	]},
	{"key": "ENCYCLOPEDIA_CAT_PM_SKILLS", "topics": [
		"ENCYCLOPEDIA_TOPIC_PM_SKILLS",
		"ENCYCLOPEDIA_TOPIC_PM_XP",
	]},
	{"key": "ENCYCLOPEDIA_CAT_OFFICE", "topics": [
		"ENCYCLOPEDIA_TOPIC_UPGRADES",
	]},
]

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	z_index = 90
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_force_fullscreen_size()
	_build_flat_topic_list()
	_build_ui()

func _force_fullscreen_size():
	var vp_size = get_viewport().get_visible_rect().size
	position = Vector2.ZERO
	size = vp_size

func _build_flat_topic_list():
	for cat in _categories_data:
		for topic_key in cat["topics"]:
			_topic_keys.append(topic_key)

func open():
	_force_fullscreen_size()
	if UITheme:
		UITheme.fade_in(self, 0.2)
	else:
		visible = true
	_select_topic(0)

func close():
	if UITheme:
		UITheme.fade_out(self, 0.15)
	else:
		visible = false
	GameTime.set_paused(false)

func _input(event: InputEvent):
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()

func _select_topic(index: int):
	if index < 0 or index >= _topic_keys.size():
		return
	_active_index = index
	for i in _topic_buttons.size():
		_style_topic_button(_topic_buttons[i], i == index)
	var topic_key = _topic_keys[index]
	if _content_title:
		_content_title.text = tr(topic_key + "_TITLE")
	if _content_label:
		_content_label.text = tr(topic_key + "_BODY")
	if _content_scroll:
		_content_scroll.scroll_vertical = 0

func _style_topic_button(btn: Button, active: bool):
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = BUTTON_CORNER_RADIUS
	style.corner_radius_top_right = BUTTON_CORNER_RADIUS
	style.corner_radius_bottom_right = BUTTON_CORNER_RADIUS
	style.corner_radius_bottom_left = BUTTON_CORNER_RADIUS
	if active:
		style.bg_color = COLOR_BTN_ACTIVE
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = COLOR_BLUE
	else:
		style.bg_color = Color.WHITE
	btn.add_theme_stylebox_override("normal", style)

	var hover_style = StyleBoxFlat.new()
	hover_style.corner_radius_top_left = BUTTON_CORNER_RADIUS
	hover_style.corner_radius_top_right = BUTTON_CORNER_RADIUS
	hover_style.corner_radius_bottom_right = BUTTON_CORNER_RADIUS
	hover_style.corner_radius_bottom_left = BUTTON_CORNER_RADIUS
	hover_style.bg_color = COLOR_BTN_ACTIVE if active else COLOR_BTN_HOVER
	if active:
		hover_style.border_width_left = 2
		hover_style.border_width_top = 2
		hover_style.border_width_right = 2
		hover_style.border_width_bottom = 2
		hover_style.border_color = COLOR_BLUE
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", hover_style)

func _build_ui():
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.45)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var _window = PanelContainer.new()
	_window.custom_minimum_size = Vector2(1500, 900)
	_window.set_anchors_preset(Control.PRESET_CENTER)
	_window.offset_left = -750
	_window.offset_top = -450
	_window.offset_right = 750
	_window.offset_bottom = 450
	_window.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_window.grow_vertical = Control.GROW_DIRECTION_BOTH

	var window_style = StyleBoxFlat.new()
	window_style.bg_color = Color(1, 1, 1, 1)
	window_style.border_width_left = 3
	window_style.border_width_top = 3
	window_style.border_width_right = 3
	window_style.border_width_bottom = 3
	window_style.border_color = Color(0, 0, 0, 1)
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

	_build_header(main_vbox)

	var body_hbox = HBoxContainer.new()
	body_hbox.add_theme_constant_override("separation", 0)
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(body_hbox)

	_build_left_panel(body_hbox)
	_build_right_panel(body_hbox)

func _build_header(parent: Control):
	var header_panel = Panel.new()
	header_panel.custom_minimum_size = Vector2(0, 40)
	var header_style = StyleBoxFlat.new()
	header_style.bg_color = COLOR_BLUE
	header_style.border_color = Color(0, 0, 0, 1)
	header_style.corner_radius_top_left = 20
	header_style.corner_radius_top_right = 20
	header_panel.add_theme_stylebox_override("panel", header_style)
	parent.add_child(header_panel)

	var title_label = Label.new()
	title_label.text = tr("ENCYCLOPEDIA_TITLE")
	title_label.set_anchors_preset(Control.PRESET_CENTER)
	title_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	title_label.offset_left = -88
	title_label.offset_top = -11.5
	title_label.offset_right = 88
	title_label.offset_bottom = 11.5
	title_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	title_label.add_theme_font_size_override("font_size", 16)
	if UITheme: UITheme.apply_font(title_label, "bold")
	header_panel.add_child(title_label)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	close_btn.offset_left = -51
	close_btn.offset_top = -15
	close_btn.offset_right = -24
	close_btn.offset_bottom = 16
	close_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	close_btn.grow_vertical = Control.GROW_DIRECTION_BOTH
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	close_btn.size_flags_vertical = Control.SIZE_SHRINK_END

	close_btn.add_theme_color_override("font_color", COLOR_BLUE)
	var close_style = StyleBoxFlat.new()
	close_style.bg_color = Color(1, 1, 1, 1)
	close_style.corner_radius_top_left = 10
	close_style.corner_radius_top_right = 10
	close_style.corner_radius_bottom_right = 10
	close_style.corner_radius_bottom_left = 10
	close_btn.add_theme_stylebox_override("normal", close_style)
	if UITheme: UITheme.apply_font(close_btn, "semibold")
	close_btn.pressed.connect(close)
	header_panel.add_child(close_btn)

func _build_left_panel(parent: Control):
	var left_container = Control.new()
	left_container.custom_minimum_size = Vector2(280, 0)
	left_container.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(left_container)

	var left_bg = ColorRect.new()
	left_bg.color = COLOR_LIGHT_GRAY
	left_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	left_container.add_child(left_bg)

	var right_border = ColorRect.new()
	right_border.color = Color(0.8, 0.82, 0.87, 1)
	right_border.custom_minimum_size = Vector2(1, 0)
	right_border.anchor_left = 1.0
	right_border.anchor_right = 1.0
	right_border.anchor_top = 0.0
	right_border.anchor_bottom = 1.0
	right_border.offset_left = -1
	right_border.offset_right = 0
	left_container.add_child(right_border)

	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_container.add_child(scroll)

	var outer_margin = MarginContainer.new()
	outer_margin.add_theme_constant_override("margin_left", 10)
	outer_margin.add_theme_constant_override("margin_right", 10)
	outer_margin.add_theme_constant_override("margin_top", 10)
	outer_margin.add_theme_constant_override("margin_bottom", 10)
	outer_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(outer_margin)

	_topics_vbox = VBoxContainer.new()
	_topics_vbox.add_theme_constant_override("separation", 3)
	_topics_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer_margin.add_child(_topics_vbox)

	_build_topic_buttons()

func _build_topic_buttons():
	var btn_index = 0
	for cat_data in _categories_data:
		var cat_margin = MarginContainer.new()
		cat_margin.add_theme_constant_override("margin_left", 4)
		cat_margin.add_theme_constant_override("margin_top", 10)
		cat_margin.add_theme_constant_override("margin_bottom", 2)
		cat_margin.add_theme_constant_override("margin_right", 0)
		_topics_vbox.add_child(cat_margin)

		var cat_lbl = Label.new()
		cat_lbl.text = tr(cat_data["key"])
		cat_lbl.add_theme_color_override("font_color", COLOR_BLUE)
		cat_lbl.add_theme_font_size_override("font_size", 13)
		if UITheme:
			UITheme.apply_font(cat_lbl, "semibold")
		cat_margin.add_child(cat_lbl)

		for topic_key in cat_data["topics"]:
			var btn = Button.new()
			btn.text = tr(topic_key + "_TITLE")
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.custom_minimum_size = Vector2(240, 30)
			btn.focus_mode = Control.FOCUS_NONE
			btn.add_theme_font_size_override("font_size", 14)
			btn.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2, 1))
			btn.add_theme_color_override("font_hover_color", COLOR_BLUE)
			btn.add_theme_color_override("font_pressed_color", COLOR_BLUE)
			if UITheme:
				UITheme.apply_font(btn, "regular")
			_style_topic_button(btn, false)
			var idx = btn_index
			btn.pressed.connect(_select_topic.bind(idx))
			_topic_buttons.append(btn)
			_topics_vbox.add_child(btn)
			btn_index += 1

func _build_right_panel(parent: Control):
	var right_container = Control.new()
	right_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(right_container)

	var right_bg = ColorRect.new()
	right_bg.color = Color.WHITE
	right_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	right_container.add_child(right_bg)

	var outer_vbox = VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 0)
	outer_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	right_container.add_child(outer_vbox)

	var title_margin = MarginContainer.new()
	title_margin.add_theme_constant_override("margin_left", 30)
	title_margin.add_theme_constant_override("margin_right", 30)
	title_margin.add_theme_constant_override("margin_top", 24)
	title_margin.add_theme_constant_override("margin_bottom", 8)
	outer_vbox.add_child(title_margin)

	_content_title = Label.new()
	_content_title.text = ""
	_content_title.add_theme_color_override("font_color", COLOR_BLUE)
	_content_title.add_theme_font_size_override("font_size", 20)
	if UITheme:
		UITheme.apply_font(_content_title, "semibold")
	title_margin.add_child(_content_title)

	var sep = ColorRect.new()
	sep.color = Color(0.85, 0.87, 0.92, 1)
	sep.custom_minimum_size = Vector2(0, 1)
	outer_vbox.add_child(sep)

	_content_scroll = ScrollContainer.new()
	_content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer_vbox.add_child(_content_scroll)

	var content_margin = MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 30)
	content_margin.add_theme_constant_override("margin_right", 30)
	content_margin.add_theme_constant_override("margin_top", 16)
	content_margin.add_theme_constant_override("margin_bottom", 30)
	content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_scroll.add_child(content_margin)

	_content_label = RichTextLabel.new()
	_content_label.bbcode_enabled = true
	_content_label.fit_content = true
	_content_label.scroll_active = false
	_content_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_label.add_theme_font_size_override("normal_font_size", 15)
	_content_label.add_theme_color_override("default_color", Color(0.15, 0.15, 0.15, 1))
	if UITheme:
		UITheme.apply_font(_content_label, "regular")
		# Make [b] tags render as semibold instead of full bold
		if UITheme.font_semibold:
			_content_label.add_theme_font_override("bold_font", UITheme.font_semibold)
	content_margin.add_child(_content_label)
