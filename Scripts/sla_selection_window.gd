extends Control

signal contract_signed(project)

const COLOR_BLUE = Color(0.17254902, 0.30980393, 0.5686275, 1)
const COLOR_WHITE = Color(1, 1, 1, 1)
const COLOR_BORDER = Color(0.8784314, 0.8784314, 0.8784314, 1)
const COLOR_GRAY = Color(0.5, 0.5, 0.5, 1)
const COLOR_GREEN = Color(0.29803923, 0.6862745, 0.3137255, 1)
const COLOR_CARD_BG = Color(0.98, 0.98, 0.98, 1)

var _overlay: ColorRect
var _window: PanelContainer
var _list_vbox: VBoxContainer
var _duration_hbox: HBoxContainer
var _preview_vbox: VBoxContainer
var _confirm_btn: Button

var _project: SupportProjectData = null
var _selected_sla: String = ""
var _selected_duration_days: int = 0
var _selected_duration_bonus_percent: int = 0
var _was_paused: bool = false

func _tr_format_safe(key: String, args, fallback: String) -> String:
	var text = tr(key)
	if text.find("%") >= 0:
		return text % args
	return fallback

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 98
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func open_for_project(proj: SupportProjectData):
	if proj == null:
		return
	_project = proj
	_selected_sla = ""
	_selected_duration_days = 0
	_selected_duration_bonus_percent = 0
	_was_paused = GameTime.is_game_paused
	GameTime.set_paused(true)
	_rebuild_cards()
	mouse_filter = Control.MOUSE_FILTER_STOP
	if UITheme:
		UITheme.fade_in(self, 0.2)
	else:
		visible = true

func _close_window():
	if not _was_paused:
		GameTime.set_paused(false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if UITheme:
		UITheme.fade_out(self, 0.15)
	else:
		visible = false

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
	_window.custom_minimum_size = Vector2(700, 0)
	var win_style = StyleBoxFlat.new()
	win_style.bg_color = COLOR_WHITE
	win_style.border_width_left = 3
	win_style.border_width_top = 3
	win_style.border_width_right = 3
	win_style.border_width_bottom = 3
	win_style.border_color = Color(0, 0, 0, 1)
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
	header.custom_minimum_size = Vector2(0, 44)
	var hdr_style = StyleBoxFlat.new()
	hdr_style.bg_color = COLOR_BLUE
	hdr_style.corner_radius_top_left = 16
	hdr_style.corner_radius_top_right = 16
	header.add_theme_stylebox_override("panel", hdr_style)
	main_vbox.add_child(header)

	var title_lbl = Label.new()
	title_lbl.text = tr("SLA_SELECTION_TITLE")
	title_lbl.add_theme_color_override("font_color", COLOR_WHITE)
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.set_anchors_preset(Control.PRESET_CENTER)
	title_lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title_lbl.grow_vertical = Control.GROW_DIRECTION_BOTH
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme:
		UITheme.apply_font(title_lbl, "bold")
	header.add_child(title_lbl)

	var content_margin = MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 20)
	content_margin.add_theme_constant_override("margin_top", 16)
	content_margin.add_theme_constant_override("margin_right", 20)
	content_margin.add_theme_constant_override("margin_bottom", 16)
	main_vbox.add_child(content_margin)

	var content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 14)
	content_margin.add_child(content_vbox)

	var sla_title = Label.new()
	sla_title.text = tr("SLA_SELECTION_TITLE")
	sla_title.add_theme_color_override("font_color", COLOR_BLUE)
	sla_title.add_theme_font_size_override("font_size", 13)
	if UITheme:
		UITheme.apply_font(sla_title, "semibold")
	content_vbox.add_child(sla_title)

	var cards_scroll = ScrollContainer.new()
	cards_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cards_scroll.custom_minimum_size = Vector2(0, 260)
	cards_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_vbox.add_child(cards_scroll)

	_list_vbox = VBoxContainer.new()
	_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_vbox.add_theme_constant_override("separation", 8)
	cards_scroll.add_child(_list_vbox)

	var duration_title = Label.new()
	duration_title.text = tr("SLA_DURATION_TITLE")
	duration_title.add_theme_color_override("font_color", COLOR_BLUE)
	duration_title.add_theme_font_size_override("font_size", 13)
	if UITheme:
		UITheme.apply_font(duration_title, "semibold")
	content_vbox.add_child(duration_title)

	_duration_hbox = HBoxContainer.new()
	_duration_hbox.add_theme_constant_override("separation", 8)
	content_vbox.add_child(_duration_hbox)

	var preview_panel = PanelContainer.new()
	var preview_style = StyleBoxFlat.new()
	preview_style.bg_color = Color(0.97, 0.98, 1.0, 1)
	preview_style.border_width_left = 1
	preview_style.border_width_top = 1
	preview_style.border_width_right = 1
	preview_style.border_width_bottom = 1
	preview_style.border_color = COLOR_BORDER
	preview_style.corner_radius_top_left = 8
	preview_style.corner_radius_top_right = 8
	preview_style.corner_radius_bottom_right = 8
	preview_style.corner_radius_bottom_left = 8
	preview_panel.add_theme_stylebox_override("panel", preview_style)
	content_vbox.add_child(preview_panel)

	var preview_margin = MarginContainer.new()
	preview_margin.add_theme_constant_override("margin_left", 12)
	preview_margin.add_theme_constant_override("margin_top", 10)
	preview_margin.add_theme_constant_override("margin_right", 12)
	preview_margin.add_theme_constant_override("margin_bottom", 10)
	preview_panel.add_child(preview_margin)

	_preview_vbox = VBoxContainer.new()
	_preview_vbox.add_theme_constant_override("separation", 4)
	preview_margin.add_child(_preview_vbox)

	var actions = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 8)
	content_vbox.add_child(actions)

	var cancel_btn = Button.new()
	cancel_btn.text = tr("UI_CANCEL")
	cancel_btn.custom_minimum_size = Vector2(140, 34)
	_style_secondary_button(cancel_btn)
	cancel_btn.pressed.connect(_close_window)
	actions.add_child(cancel_btn)

	_confirm_btn = Button.new()
	_confirm_btn.text = tr("SLA_CONFIRM")
	_confirm_btn.custom_minimum_size = Vector2(200, 34)
	_style_primary_button(_confirm_btn)
	_confirm_btn.disabled = true
	_confirm_btn.pressed.connect(_confirm_and_close)
	actions.add_child(_confirm_btn)

func _rebuild_cards():
	for c in _list_vbox.get_children():
		c.queue_free()
	for c in _duration_hbox.get_children():
		c.queue_free()

	var definitions = [
		{"id": "strict", "icon": "🔴", "name_key": "SLA_STRICT", "desc_key": "SLA_STRICT_DESC", "hint_key": "SLA_STRICT_TERMINATION_HINT"},
		{"id": "medium", "icon": "🟡", "name_key": "SLA_MEDIUM", "desc_key": "SLA_MEDIUM_DESC", "hint_key": "SLA_MEDIUM_TERMINATION_HINT"},
		{"id": "easy", "icon": "🟢", "name_key": "SLA_EASY", "desc_key": "SLA_EASY_DESC", "hint_key": "SLA_EASY_TERMINATION_HINT"},
	]
	for d in definitions:
		_list_vbox.add_child(_make_sla_card(d))

	var duration_defs = [
		{"days": 5, "bonus": -10, "label_key": "DURATION_5_DAYS"},
		{"days": 10, "bonus": 0, "label_key": "DURATION_10_DAYS"},
		{"days": 15, "bonus": 5, "label_key": "DURATION_15_DAYS"},
		{"days": 20, "bonus": 10, "label_key": "DURATION_20_DAYS"},
	]
	for d in duration_defs:
		_duration_hbox.add_child(_make_duration_button(d))

	_rebuild_preview()

func _make_sla_card(definition: Dictionary) -> PanelContainer:
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var selected = _selected_sla == str(definition["id"])
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = COLOR_CARD_BG
	card_style.border_width_left = 2 if selected else 1
	card_style.border_width_top = 2 if selected else 1
	card_style.border_width_right = 2 if selected else 1
	card_style.border_width_bottom = 2 if selected else 1
	card_style.border_color = COLOR_BLUE if selected else COLOR_BORDER
	card_style.corner_radius_top_left = 8
	card_style.corner_radius_top_right = 8
	card_style.corner_radius_bottom_right = 8
	card_style.corner_radius_bottom_left = 8
	card.add_theme_stylebox_override("panel", card_style)

	var m = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 14)
	m.add_theme_constant_override("margin_top", 10)
	m.add_theme_constant_override("margin_right", 14)
	m.add_theme_constant_override("margin_bottom", 10)
	card.add_child(m)

	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	m.add_child(h)

	var left = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 4)
	h.add_child(left)

	var title = Label.new()
	title.text = "%s %s" % [definition["icon"], tr(definition["name_key"])]
	title.add_theme_font_size_override("font_size", 14)
	if UITheme:
		UITheme.apply_font(title, "semibold")
	left.add_child(title)

	var desc = Label.new()
	desc.text = tr(definition["desc_key"])
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", COLOR_GRAY)
	if UITheme:
		UITheme.apply_font(desc, "regular")
	left.add_child(desc)

	var hint = Label.new()
	hint.text = tr(definition["hint_key"])
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.8, 0.35, 0.15, 1))
	if UITheme:
		UITheme.apply_font(hint, "regular")
	left.add_child(hint)

	var right = VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(right)

	var pick_btn = Button.new()
	pick_btn.text = tr("PROJ_SEL_BTN_SELECT")
	pick_btn.custom_minimum_size = Vector2(140, 34)
	_style_secondary_button(pick_btn)
	if selected:
		pick_btn.disabled = true
	pick_btn.pressed.connect(func():
		_selected_sla = str(definition["id"])
		_rebuild_cards()
	)
	right.add_child(pick_btn)

	return card

func _make_duration_button(definition: Dictionary) -> Button:
	var btn = Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 36)
	btn.text = tr(definition["label_key"])
	var days = int(definition["days"])
	var selected = _selected_duration_days == days
	_style_secondary_button(btn)
	if selected:
		_style_primary_button(btn)
	btn.pressed.connect(func():
		_selected_duration_days = days
		_selected_duration_bonus_percent = int(definition["bonus"])
		_rebuild_cards()
	)
	return btn

func _rebuild_preview():
	for c in _preview_vbox.get_children():
		c.queue_free()

	if _project == null or _selected_sla == "" or _selected_duration_days <= 0:
		var pick_lbl = Label.new()
		pick_lbl.text = tr("SLA_PREVIEW_PICK_BOTH")
		pick_lbl.add_theme_color_override("font_color", COLOR_GRAY)
		if UITheme:
			UITheme.apply_font(pick_lbl, "regular")
		_preview_vbox.add_child(pick_lbl)
		_confirm_btn.disabled = true
		return

	var rate = _calc_preview_rate()
	var weeks = int(ceil(float(_selected_duration_days) / 5.0))
	var total = rate * _selected_duration_days

	_preview_vbox.add_child(_preview_line(_tr_format_safe("SLA_PREVIEW_RATE", rate, "Rate: $%d/day" % rate), COLOR_GREEN))
	_preview_vbox.add_child(_preview_line(_tr_format_safe("SLA_PREVIEW_DURATION", [_selected_duration_days, weeks], "Duration: %d work days (≈%d weeks)" % [_selected_duration_days, weeks]), COLOR_BLUE))
	_preview_vbox.add_child(_preview_line(_tr_format_safe("SLA_PREVIEW_TOTAL", total, "Estimated total: ≈$%d" % total), COLOR_GREEN))

	_confirm_btn.disabled = false

func _preview_line(text: String, color: Color) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	if UITheme:
		UITheme.apply_font(lbl, "regular")
	return lbl

func _calc_preview_rate() -> int:
	if _project == null:
		return 0
	var effective_rate = float(_project.daily_rate)
	match _selected_sla:
		"strict":
			effective_rate *= 1.2
		"easy":
			effective_rate *= 0.8
	effective_rate *= (1.0 + float(_selected_duration_bonus_percent) / 100.0)
	return int(effective_rate)

func _confirm_and_close():
	if _project == null or _selected_sla == "" or _selected_duration_days <= 0:
		return
	_project.sla_level = _selected_sla
	_project.contract_duration_days = _selected_duration_days
	_project.duration_bonus_percent = _selected_duration_bonus_percent
	_project.end_day = SupportProjectManager._add_working_days(_project.created_at_day, _project.contract_duration_days)
	if _project.week_start_day <= 0:
		_project.week_start_day = GameTime.day
	if not SupportProjectManager.add_support_project(_project):
		return

	var client = _project.get_client()
	var client_name = client.get_display_name() if client else _project.client_id
	var sla_name = tr("SLA_" + _selected_sla.to_upper())
	EventLog.add(_tr_format_safe("LOG_SUPPORT_CONTRACT_SIGNED", [client_name, sla_name], "Support contract with %s signed (SLA: %s)" % [client_name, sla_name]), EventLog.LogType.PROGRESS)
	if ScreenJuice:
		ScreenJuice.show_toast("🔧", tr("TOAST_SUPPORT_SIGNED"))

	emit_signal("contract_signed", _project)
	_close_window()

func _style_primary_button(btn: Button):
	btn.add_theme_font_size_override("font_size", 13)
	btn.focus_mode = Control.FOCUS_NONE
	if UITheme:
		UITheme.apply_font(btn, "semibold")
	var btn_n = StyleBoxFlat.new()
	btn_n.bg_color = COLOR_BLUE
	btn_n.border_width_left = 2
	btn_n.border_width_top = 2
	btn_n.border_width_right = 2
	btn_n.border_width_bottom = 2
	btn_n.border_color = COLOR_BLUE
	btn_n.corner_radius_top_left = 16
	btn_n.corner_radius_top_right = 16
	btn_n.corner_radius_bottom_right = 16
	btn_n.corner_radius_bottom_left = 16
	var btn_h = btn_n.duplicate()
	btn_h.bg_color = Color(0.13, 0.26, 0.5, 1)
	btn.add_theme_stylebox_override("normal", btn_n)
	btn.add_theme_stylebox_override("hover", btn_h)
	btn.add_theme_stylebox_override("pressed", btn_h)
	btn.add_theme_stylebox_override("disabled", btn_n)
	btn.add_theme_color_override("font_color", COLOR_WHITE)
	btn.add_theme_color_override("font_hover_color", COLOR_WHITE)
	btn.add_theme_color_override("font_pressed_color", COLOR_WHITE)

func _style_secondary_button(btn: Button):
	btn.add_theme_font_size_override("font_size", 13)
	btn.focus_mode = Control.FOCUS_NONE
	if UITheme:
		UITheme.apply_font(btn, "semibold")
	var btn_n = StyleBoxFlat.new()
	btn_n.bg_color = COLOR_WHITE
	btn_n.border_width_left = 2
	btn_n.border_width_top = 2
	btn_n.border_width_right = 2
	btn_n.border_width_bottom = 2
	btn_n.border_color = COLOR_BLUE
	btn_n.corner_radius_top_left = 16
	btn_n.corner_radius_top_right = 16
	btn_n.corner_radius_bottom_right = 16
	btn_n.corner_radius_bottom_left = 16
	var btn_h = btn_n.duplicate()
	btn_h.bg_color = COLOR_BLUE
	btn.add_theme_stylebox_override("normal", btn_n)
	btn.add_theme_stylebox_override("hover", btn_h)
	btn.add_theme_stylebox_override("pressed", btn_h)
	btn.add_theme_color_override("font_color", COLOR_BLUE)
	btn.add_theme_color_override("font_hover_color", COLOR_WHITE)
	btn.add_theme_color_override("font_pressed_color", COLOR_WHITE)

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_close_window()
		get_viewport().set_input_as_handled()
