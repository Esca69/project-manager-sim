extends Control

# === ЦВЕТА (из проекта) ===
const COLOR_BLUE   = Color(0.17254902, 0.30980393, 0.5686275, 1)
const COLOR_GREEN  = Color(0.29803923, 0.6862745, 0.3137255, 1)
const COLOR_RED    = Color(0.8980392, 0.22352941, 0.20784314, 1)
const COLOR_DARK   = Color(0.2, 0.2, 0.2, 1)
const COLOR_GRAY   = Color(0.5, 0.5, 0.5, 1)
const COLOR_WHITE  = Color(1, 1, 1, 1)
const COLOR_BORDER = Color(0.8784314, 0.8784314, 0.8784314, 1)

# === СИМВОЛЫ РАДИО-КНОПОК ===
const SYMBOL_RADIO_ON  = "●"
const SYMBOL_RADIO_OFF = "○"

# Текущий стол
var _current_desk = null
var _was_paused: bool = false

# Ноды UI
var _overlay: ColorRect
var _window: PanelContainer
var _employee_label: Label
var _assign_btn: Button
var _upgrades_vbox: VBoxContainer

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 92
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	name = "DeskPanel"
	_build_ui()

func _build_ui():
	# === ЗАТЕМНЕНИЕ ФОНА ===
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.45)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# === ОКНО ===
	_window = PanelContainer.new()
	_window.custom_minimum_size = Vector2(500, 0)
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

	# === ЗАГОЛОВОК ===
	var header = Panel.new()
	header.custom_minimum_size = Vector2(0, 44)
	var hdr_style = StyleBoxFlat.new()
	hdr_style.bg_color = COLOR_BLUE
	hdr_style.corner_radius_top_left = 16
	hdr_style.corner_radius_top_right = 16
	header.add_theme_stylebox_override("panel", hdr_style)
	main_vbox.add_child(header)

	var title_lbl = Label.new()
	title_lbl.text = tr("DESK_PANEL_TITLE")
	title_lbl.add_theme_color_override("font_color", COLOR_WHITE)
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.set_anchors_preset(Control.PRESET_CENTER)
	title_lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title_lbl.grow_vertical = Control.GROW_DIRECTION_BOTH
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme:
		UITheme.apply_font(title_lbl, "bold")
	header.add_child(title_lbl)

	# === КОНТЕНТ ===
	var content_margin = MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 20)
	content_margin.add_theme_constant_override("margin_top", 16)
	content_margin.add_theme_constant_override("margin_right", 20)
	content_margin.add_theme_constant_override("margin_bottom", 16)
	main_vbox.add_child(content_margin)

	var content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 14)
	content_margin.add_child(content_vbox)

	# === БЛОК СОТРУДНИКА ===
	var emp_panel = PanelContainer.new()
	var ep_style = StyleBoxFlat.new()
	ep_style.bg_color = Color(0.96, 0.97, 1.0, 1)
	ep_style.border_width_left = 1
	ep_style.border_width_top = 1
	ep_style.border_width_right = 1
	ep_style.border_width_bottom = 1
	ep_style.border_color = COLOR_BORDER
	ep_style.corner_radius_top_left = 10
	ep_style.corner_radius_top_right = 10
	ep_style.corner_radius_bottom_right = 10
	ep_style.corner_radius_bottom_left = 10
	emp_panel.add_theme_stylebox_override("panel", ep_style)
	content_vbox.add_child(emp_panel)

	var emp_margin = MarginContainer.new()
	emp_margin.add_theme_constant_override("margin_left", 14)
	emp_margin.add_theme_constant_override("margin_top", 10)
	emp_margin.add_theme_constant_override("margin_right", 14)
	emp_margin.add_theme_constant_override("margin_bottom", 10)
	emp_panel.add_child(emp_margin)

	var emp_vbox = VBoxContainer.new()
	emp_vbox.add_theme_constant_override("separation", 6)
	emp_margin.add_child(emp_vbox)

	var emp_header_lbl = Label.new()
	emp_header_lbl.text = tr("DESK_PANEL_OCCUPIED_BY")
	emp_header_lbl.add_theme_color_override("font_color", COLOR_GRAY)
	emp_header_lbl.add_theme_font_size_override("font_size", 12)
	if UITheme:
		UITheme.apply_font(emp_header_lbl, "regular")
	emp_vbox.add_child(emp_header_lbl)

	_employee_label = Label.new()
	_employee_label.add_theme_color_override("font_color", COLOR_DARK)
	_employee_label.add_theme_font_size_override("font_size", 14)
	if UITheme:
		UITheme.apply_font(_employee_label, "semibold")
	emp_vbox.add_child(_employee_label)

	_assign_btn = Button.new()
	_assign_btn.custom_minimum_size = Vector2(200, 34)
	_assign_btn.add_theme_font_size_override("font_size", 13)
	if UITheme:
		UITheme.apply_font(_assign_btn, "semibold")
	var abtn_normal = StyleBoxFlat.new()
	abtn_normal.bg_color = COLOR_WHITE
	abtn_normal.border_width_left = 2
	abtn_normal.border_width_top = 2
	abtn_normal.border_width_right = 2
	abtn_normal.border_width_bottom = 2
	abtn_normal.border_color = COLOR_BLUE
	abtn_normal.corner_radius_top_left = 16
	abtn_normal.corner_radius_top_right = 16
	abtn_normal.corner_radius_bottom_right = 16
	abtn_normal.corner_radius_bottom_left = 16
	var abtn_hover = StyleBoxFlat.new()
	abtn_hover.bg_color = COLOR_BLUE
	abtn_hover.border_width_left = 2
	abtn_hover.border_width_top = 2
	abtn_hover.border_width_right = 2
	abtn_hover.border_width_bottom = 2
	abtn_hover.border_color = COLOR_BLUE
	abtn_hover.corner_radius_top_left = 16
	abtn_hover.corner_radius_top_right = 16
	abtn_hover.corner_radius_bottom_right = 16
	abtn_hover.corner_radius_bottom_left = 16
	_assign_btn.add_theme_stylebox_override("normal", abtn_normal)
	_assign_btn.add_theme_stylebox_override("hover", abtn_hover)
	_assign_btn.add_theme_stylebox_override("pressed", abtn_hover)
	_assign_btn.add_theme_color_override("font_color", COLOR_BLUE)
	_assign_btn.add_theme_color_override("font_hover_color", COLOR_WHITE)
	_assign_btn.add_theme_color_override("font_pressed_color", COLOR_WHITE)
	_assign_btn.focus_mode = Control.FOCUS_NONE
	_assign_btn.pressed.connect(_on_assign_pressed)
	emp_vbox.add_child(_assign_btn)

	# === РАЗДЕЛИТЕЛЬ ===
	var sep = HSeparator.new()
	content_vbox.add_child(sep)

	# === ЗАГОЛОВОК УЛУЧШЕНИЙ ===
	var upg_title = Label.new()
	upg_title.text = tr("DESK_PANEL_UPGRADES_TITLE")
	upg_title.add_theme_color_override("font_color", COLOR_BLUE)
	upg_title.add_theme_font_size_override("font_size", 14)
	if UITheme:
		UITheme.apply_font(upg_title, "bold")
	content_vbox.add_child(upg_title)

	# === SCROLL ДЛЯ УЛУЧШЕНИЙ ===
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 280)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_vbox.add_child(scroll)

	_upgrades_vbox = VBoxContainer.new()
	_upgrades_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_upgrades_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(_upgrades_vbox)

	# === КНОПКА ЗАКРЫТЬ ===
	var footer_margin = MarginContainer.new()
	footer_margin.add_theme_constant_override("margin_top", 4)
	content_vbox.add_child(footer_margin)

	var close_center = CenterContainer.new()
	footer_margin.add_child(close_center)

	var close_btn = Button.new()
	close_btn.text = tr("UI_CLOSE")
	close_btn.custom_minimum_size = Vector2(160, 36)
	close_btn.add_theme_font_size_override("font_size", 14)
	close_btn.focus_mode = Control.FOCUS_NONE
	if UITheme:
		UITheme.apply_font(close_btn, "semibold")
	var cbtn_style = StyleBoxFlat.new()
	cbtn_style.bg_color = COLOR_WHITE
	cbtn_style.border_width_left = 2
	cbtn_style.border_width_top = 2
	cbtn_style.border_width_right = 2
	cbtn_style.border_width_bottom = 2
	cbtn_style.border_color = COLOR_GRAY
	cbtn_style.corner_radius_top_left = 16
	cbtn_style.corner_radius_top_right = 16
	cbtn_style.corner_radius_bottom_right = 16
	cbtn_style.corner_radius_bottom_left = 16
	var cbtn_hover = StyleBoxFlat.new()
	cbtn_hover.bg_color = COLOR_GRAY
	cbtn_hover.border_width_left = 2
	cbtn_hover.border_width_top = 2
	cbtn_hover.border_width_right = 2
	cbtn_hover.border_width_bottom = 2
	cbtn_hover.border_color = COLOR_GRAY
	cbtn_hover.corner_radius_top_left = 16
	cbtn_hover.corner_radius_top_right = 16
	cbtn_hover.corner_radius_bottom_right = 16
	cbtn_hover.corner_radius_bottom_left = 16
	close_btn.add_theme_stylebox_override("normal", cbtn_style)
	close_btn.add_theme_stylebox_override("hover", cbtn_hover)
	close_btn.add_theme_stylebox_override("pressed", cbtn_hover)
	close_btn.add_theme_color_override("font_color", COLOR_GRAY)
	close_btn.add_theme_color_override("font_hover_color", COLOR_WHITE)
	close_btn.pressed.connect(_on_close_pressed)
	close_center.add_child(close_btn)

func open_for_desk(desk_node):
	_was_paused = GameTime.is_game_paused
	GameTime.set_paused(true)
	_current_desk = desk_node
	_refresh()
	mouse_filter = Control.MOUSE_FILTER_STOP
	if UITheme:
		UITheme.fade_in(self, 0.2)
	else:
		visible = true

func _refresh():
	if not _current_desk:
		return
	if _current_desk.is_broken:
		_refresh_broken_state()
	else:
		_refresh_employee_block()
		_refresh_upgrades()

func _refresh_employee_block():
	if not _current_desk:
		return
	if _current_desk.assigned_employee:
		var emp = _current_desk.assigned_employee
		_employee_label.text = emp.get_display_name() + " (" + tr(emp.job_title) + ")"
		_employee_label.add_theme_color_override("font_color", COLOR_DARK)
		_assign_btn.text = tr("DESK_PANEL_ASSIGN_BTN")
	else:
		_employee_label.text = tr("DESK_PANEL_EMPTY")
		_employee_label.add_theme_color_override("font_color", COLOR_GRAY)
		_assign_btn.text = tr("DESK_PANEL_ASSIGN_BTN")

func _refresh_upgrades():
	for child in _upgrades_vbox.get_children():
		child.queue_free()

	if not _current_desk:
		return

	# Section: One-time purchases
	_upgrades_vbox.add_child(_make_section_header("🛒 " + tr("DESK_UPG_SECTION_ONETIME")))
	for upgrade_id in ["second_monitor", "desk_plant"]:
		var config = _current_desk.DESK_UPGRADE_CONFIG.get(upgrade_id)
		if config:
			_upgrades_vbox.add_child(_build_upgrade_card(upgrade_id, config))

	var sep = HSeparator.new()
	_upgrades_vbox.add_child(sep)

	# Section: Subscriptions
	_upgrades_vbox.add_child(_make_section_header("📅 " + tr("DESK_UPG_SECTION_SUBS")))
	for upgrade_id in ["software_ba", "software_dev", "software_qa", "ai_subscription"]:
		var config = _current_desk.DESK_UPGRADE_CONFIG.get(upgrade_id)
		if config:
			_upgrades_vbox.add_child(_build_upgrade_card(upgrade_id, config))

func _make_section_header(text: String) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", COLOR_DARK)
	lbl.add_theme_font_size_override("font_size", 13)
	if UITheme:
		UITheme.apply_font(lbl, "semibold")
	return lbl

func _refresh_broken_state():
	# Скрываем обычные блоки — перезаполняем upgrades_vbox
	_employee_label.text = ""
	_assign_btn.visible = false
	for child in _upgrades_vbox.get_children():
		child.queue_free()

	# Баннер
	var banner_lbl = Label.new()
	banner_lbl.text = tr("DESK_BROKEN_BANNER")
	banner_lbl.add_theme_color_override("font_color", COLOR_RED)
	banner_lbl.add_theme_font_size_override("font_size", 14)
	banner_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if UITheme:
		UITheme.apply_font(banner_lbl, "semibold")
	_upgrades_vbox.add_child(banner_lbl)

	# Кнопка починки
	var repair_btn = Button.new()
	repair_btn.text = tr("DESK_REPAIR_BTN") + " ($%d)" % _current_desk.MONITOR_REPAIR_COST
	repair_btn.custom_minimum_size = Vector2(200, 40)
	repair_btn.add_theme_font_size_override("font_size", 14)
	repair_btn.focus_mode = Control.FOCUS_NONE
	if UITheme:
		UITheme.apply_font(repair_btn, "semibold")
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = COLOR_GREEN
	btn_style.corner_radius_top_left = 16
	btn_style.corner_radius_top_right = 16
	btn_style.corner_radius_bottom_right = 16
	btn_style.corner_radius_bottom_left = 16
	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = Color(0.2, 0.6, 0.25, 1)
	repair_btn.add_theme_stylebox_override("normal", btn_style)
	repair_btn.add_theme_stylebox_override("hover", btn_hover)
	repair_btn.add_theme_stylebox_override("pressed", btn_hover)
	repair_btn.add_theme_color_override("font_color", COLOR_WHITE)
	repair_btn.add_theme_color_override("font_hover_color", COLOR_WHITE)
	repair_btn.pressed.connect(_on_repair_pressed)
	_upgrades_vbox.add_child(repair_btn)

func _on_repair_pressed():
	if not _current_desk:
		return
	if _current_desk.repair_monitor():
		_assign_btn.visible = true
		_refresh()

func _build_upgrade_card(upgrade_id: String, config: Dictionary) -> Control:
	var card = PanelContainer.new()
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.98, 0.98, 0.98, 1)
	card_style.border_width_left = 1
	card_style.border_width_top = 1
	card_style.border_width_right = 1
	card_style.border_width_bottom = 1
	card_style.border_color = COLOR_BORDER
	card_style.corner_radius_top_left = 8
	card_style.corner_radius_top_right = 8
	card_style.corner_radius_bottom_right = 8
	card_style.corner_radius_bottom_left = 8
	card.add_theme_stylebox_override("panel", card_style)

	var card_margin = MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left", 12)
	card_margin.add_theme_constant_override("margin_top", 8)
	card_margin.add_theme_constant_override("margin_right", 12)
	card_margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(card_margin)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card_margin.add_child(row)

	# Emoji + название + описание (left side)
	var left_vbox = VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.add_theme_constant_override("separation", 2)
	row.add_child(left_vbox)

	var name_row = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 4)
	left_vbox.add_child(name_row)

	var emoji_lbl = Label.new()
	emoji_lbl.text = config.emoji
	emoji_lbl.add_theme_font_size_override("font_size", 14)
	name_row.add_child(emoji_lbl)

	var name_lbl = Label.new()
	name_lbl.text = tr(config.name_key)
	name_lbl.add_theme_color_override("font_color", COLOR_DARK)
	name_lbl.add_theme_font_size_override("font_size", 13)
	if UITheme:
		UITheme.apply_font(name_lbl, "semibold")
	name_row.add_child(name_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = tr(config.desc_key)
	desc_lbl.add_theme_color_override("font_color", COLOR_GRAY)
	desc_lbl.add_theme_font_size_override("font_size", 11)
	if UITheme:
		UITheme.apply_font(desc_lbl, "regular")
	left_vbox.add_child(desc_lbl)

	# Price label (left side, under description)
	var is_bought = _current_desk.desk_upgrades.get(upgrade_id, false)

	if config.type == "one_time":
		if is_bought:
			var bought_lbl = Label.new()
			bought_lbl.text = "✅ " + tr("DESK_UPG_BOUGHT")
			bought_lbl.add_theme_color_override("font_color", COLOR_GREEN)
			bought_lbl.add_theme_font_size_override("font_size", 12)
			if UITheme:
				UITheme.apply_font(bought_lbl, "semibold")
			left_vbox.add_child(bought_lbl)
		else:
			var price_lbl = Label.new()
			price_lbl.text = "💰 $%d" % config.cost
			price_lbl.add_theme_color_override("font_color", COLOR_GREEN)
			price_lbl.add_theme_font_size_override("font_size", 12)
			if UITheme:
				UITheme.apply_font(price_lbl, "semibold")
			left_vbox.add_child(price_lbl)
	elif config.type == "subscription":
		var price_lbl = Label.new()
		price_lbl.text = "💰 $%d%s" % [config.daily_cost, tr("DESK_UPG_PER_DAY")]
		price_lbl.add_theme_color_override("font_color", COLOR_GREEN)
		price_lbl.add_theme_font_size_override("font_size", 12)
		if UITheme:
			UITheme.apply_font(price_lbl, "semibold")
		left_vbox.add_child(price_lbl)

	# Action (right side)
	var action_box = HBoxContainer.new()
	action_box.add_theme_constant_override("separation", 6)
	action_box.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(action_box)

	if config.type == "one_time":
		if not is_bought:
			if not PMData.has_skill("desk_one_time_unlock"):
				action_box.add_child(_create_lock_control("DESK_LOCK_ONE_TIME_TOOLTIP"))
			else:
				var buy_btn = Button.new()
				buy_btn.text = tr("DESK_UPG_BUY")
				buy_btn.custom_minimum_size = Vector2(120, 34)
				buy_btn.add_theme_font_size_override("font_size", 12)
				buy_btn.focus_mode = Control.FOCUS_NONE
				if UITheme:
					UITheme.apply_font(buy_btn, "semibold")
				_style_buy_button(buy_btn)
				buy_btn.pressed.connect(_on_buy_pressed.bind(upgrade_id))
				action_box.add_child(buy_btn)
	elif config.type == "subscription":
		if not PMData.has_skill("desk_subs_unlock"):
			action_box.add_child(_create_lock_control("DESK_LOCK_SUBS_TOOLTIP"))
		else:
			var is_active = _current_desk.desk_upgrades.get(upgrade_id + "_active", false)

			# Off radio pair
			var off_pair = HBoxContainer.new()
			off_pair.add_theme_constant_override("separation", 4)
			off_pair.alignment = BoxContainer.ALIGNMENT_CENTER
			action_box.add_child(off_pair)

			var off_btn = Button.new()
			off_btn.text = SYMBOL_RADIO_ON if not is_active else SYMBOL_RADIO_OFF
			off_btn.custom_minimum_size = Vector2(28, 28)
			off_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			off_btn.add_theme_font_size_override("font_size", 10)
			off_btn.focus_mode = Control.FOCUS_NONE
			_style_sub_off_button(off_btn, not is_active)
			off_btn.pressed.connect(_on_sub_off_pressed.bind(upgrade_id))
			off_pair.add_child(off_btn)

			var off_lbl = Label.new()
			off_lbl.text = tr("DESK_UPG_TOGGLE_OFF")
			off_lbl.add_theme_font_size_override("font_size", 11)
			off_lbl.add_theme_color_override("font_color", COLOR_DARK)
			if UITheme:
				UITheme.apply_font(off_lbl, "regular")
			off_pair.add_child(off_lbl)

			var spacer = Control.new()
			spacer.custom_minimum_size = Vector2(8, 0)
			action_box.add_child(spacer)

			# On radio pair
			var on_pair = HBoxContainer.new()
			on_pair.add_theme_constant_override("separation", 4)
			on_pair.alignment = BoxContainer.ALIGNMENT_CENTER
			action_box.add_child(on_pair)

			var on_btn = Button.new()
			on_btn.text = SYMBOL_RADIO_ON if is_active else SYMBOL_RADIO_OFF
			on_btn.custom_minimum_size = Vector2(28, 28)
			on_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			on_btn.add_theme_font_size_override("font_size", 10)
			on_btn.focus_mode = Control.FOCUS_NONE
			_style_sub_on_button(on_btn, is_active)
			on_btn.pressed.connect(_on_sub_on_pressed.bind(upgrade_id))
			on_pair.add_child(on_btn)

			var on_lbl = Label.new()
			on_lbl.text = tr("DESK_UPG_TOGGLE_ON")
			on_lbl.add_theme_font_size_override("font_size", 11)
			on_lbl.add_theme_color_override("font_color", COLOR_DARK)
			if UITheme:
				UITheme.apply_font(on_lbl, "regular")
			on_pair.add_child(on_lbl)

	return card

func _create_lock_control(tooltip_key: String) -> Control:
	var lock_lbl = Label.new()
	lock_lbl.text = "🔒"
	lock_lbl.add_theme_font_size_override("font_size", 18)
	lock_lbl.custom_minimum_size = Vector2(40, 34)
	lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lock_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	lock_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var tooltip_ref: Array = [null]
	var parent_ref = self
	lock_lbl.mouse_entered.connect(func():
		if tooltip_ref[0] != null and is_instance_valid(tooltip_ref[0]):
			tooltip_ref[0].queue_free()
		var tp = TraitUIHelper.create_tooltip(tr(tooltip_key), Color(0.5, 0.5, 0.5, 1))
		parent_ref.add_child(tp)
		await parent_ref.get_tree().process_frame
		if not is_instance_valid(tp):
			return
		var lbl_global = lock_lbl.global_position
		tp.global_position = Vector2(lbl_global.x + 28, lbl_global.y - 10)
		var vp_size = parent_ref.get_viewport().get_visible_rect().size
		tp.global_position.x = min(tp.global_position.x, vp_size.x - tp.size.x - 10)
		tp.global_position.y = max(tp.global_position.y, 10)
		tooltip_ref[0] = tp
	)
	lock_lbl.mouse_exited.connect(func():
		if tooltip_ref[0] != null and is_instance_valid(tooltip_ref[0]):
			tooltip_ref[0].queue_free()
		tooltip_ref[0] = null
	)
	return lock_lbl

func _style_buy_button(btn: Button):
	var n = StyleBoxFlat.new()
	n.bg_color = COLOR_WHITE
	n.border_width_left = 2
	n.border_width_top = 2
	n.border_width_right = 2
	n.border_width_bottom = 2
	n.border_color = COLOR_BLUE
	n.corner_radius_top_left = 16
	n.corner_radius_top_right = 16
	n.corner_radius_bottom_right = 16
	n.corner_radius_bottom_left = 16
	var h = StyleBoxFlat.new()
	h.bg_color = COLOR_BLUE
	h.border_width_left = 2
	h.border_width_top = 2
	h.border_width_right = 2
	h.border_width_bottom = 2
	h.border_color = COLOR_BLUE
	h.corner_radius_top_left = 16
	h.corner_radius_top_right = 16
	h.corner_radius_bottom_right = 16
	h.corner_radius_bottom_left = 16
	btn.add_theme_stylebox_override("normal", n)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("pressed", h)
	btn.add_theme_color_override("font_color", COLOR_BLUE)
	btn.add_theme_color_override("font_hover_color", COLOR_WHITE)
	btn.add_theme_color_override("font_pressed_color", COLOR_WHITE)

func _style_sub_off_button(btn: Button, is_selected: bool):
	var n = StyleBoxFlat.new()
	n.corner_radius_top_left = 14
	n.corner_radius_top_right = 14
	n.corner_radius_bottom_right = 14
	n.corner_radius_bottom_left = 14
	n.border_width_left = 2
	n.border_width_top = 2
	n.border_width_right = 2
	n.border_width_bottom = 2
	if is_selected:
		n.bg_color = COLOR_RED
		n.border_color = COLOR_RED
		btn.add_theme_color_override("font_color", COLOR_WHITE)
	else:
		n.bg_color = COLOR_WHITE
		n.border_color = COLOR_RED
		btn.add_theme_color_override("font_color", COLOR_RED)
	var h = StyleBoxFlat.new()
	h.corner_radius_top_left = 14
	h.corner_radius_top_right = 14
	h.corner_radius_bottom_right = 14
	h.corner_radius_bottom_left = 14
	h.border_width_left = 2
	h.border_width_top = 2
	h.border_width_right = 2
	h.border_width_bottom = 2
	h.bg_color = COLOR_RED
	h.border_color = COLOR_RED
	btn.add_theme_stylebox_override("normal", n)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("pressed", h)
	btn.add_theme_color_override("font_hover_color", COLOR_WHITE)
	btn.add_theme_color_override("font_pressed_color", COLOR_WHITE)

func _style_sub_on_button(btn: Button, is_selected: bool):
	var n = StyleBoxFlat.new()
	n.corner_radius_top_left = 14
	n.corner_radius_top_right = 14
	n.corner_radius_bottom_right = 14
	n.corner_radius_bottom_left = 14
	n.border_width_left = 2
	n.border_width_top = 2
	n.border_width_right = 2
	n.border_width_bottom = 2
	if is_selected:
		n.bg_color = COLOR_GREEN
		n.border_color = COLOR_GREEN
		btn.add_theme_color_override("font_color", COLOR_WHITE)
	else:
		n.bg_color = COLOR_WHITE
		n.border_color = COLOR_GREEN
		btn.add_theme_color_override("font_color", COLOR_GREEN)
	var h = StyleBoxFlat.new()
	h.corner_radius_top_left = 14
	h.corner_radius_top_right = 14
	h.corner_radius_bottom_right = 14
	h.corner_radius_bottom_left = 14
	h.border_width_left = 2
	h.border_width_top = 2
	h.border_width_right = 2
	h.border_width_bottom = 2
	h.bg_color = COLOR_GREEN
	h.border_color = COLOR_GREEN
	btn.add_theme_stylebox_override("normal", n)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("pressed", h)
	btn.add_theme_color_override("font_hover_color", COLOR_WHITE)
	btn.add_theme_color_override("font_pressed_color", COLOR_WHITE)

func _on_assign_pressed():
	var hud = get_tree().get_first_node_in_group("ui")
	if not hud:
		return
	var menu = hud.get_node_or_null("AssignmentMenu")
	if not menu:
		return
	# Disconnect first to avoid duplicate connections
	if menu.employee_assigned.is_connected(_on_employee_assigned_from_menu):
		menu.employee_assigned.disconnect(_on_employee_assigned_from_menu)
	menu.employee_assigned.connect(_on_employee_assigned_from_menu)
	if menu.menu_closed.is_connected(_on_assignment_menu_closed):
		menu.menu_closed.disconnect(_on_assignment_menu_closed)
	menu.menu_closed.connect(_on_assignment_menu_closed)
	# Hide DeskPanel so its overlay doesn't block AssignmentMenu clicks
	visible = false
	menu.open_assignment_list(_current_desk)

func _on_assignment_menu_closed():
	visible = true
	_refresh()

func _on_employee_assigned_from_menu():
	var hud = get_tree().get_first_node_in_group("ui")
	if hud:
		var menu = hud.get_node_or_null("AssignmentMenu")
		if menu and menu.menu_closed.is_connected(_on_assignment_menu_closed):
			menu.menu_closed.disconnect(_on_assignment_menu_closed)
	_on_close_pressed()

func _on_buy_pressed(upgrade_id: String):
	if not _current_desk:
		return
	var gs = get_node_or_null("/root/GameState")
	if gs == null:
		return
	var config = _current_desk.DESK_UPGRADE_CONFIG.get(upgrade_id, {})
	var cost = config.get("cost", config.get("daily_cost", 0))
	if gs.company_balance < cost:
		var el = get_node_or_null("/root/EventLog")
		if el:
			el.add(tr("TXT_NOT_ENOUGH_MONEY"), el.LogType.ALERT)
		return
	_current_desk.buy_upgrade(upgrade_id)
	_refresh_upgrades()

func _on_sub_on_pressed(upgrade_id: String):
	if not _current_desk:
		return
	_current_desk.activate_subscription(upgrade_id)
	_refresh_upgrades()

func _on_sub_off_pressed(upgrade_id: String):
	if not _current_desk:
		return
	_current_desk.deactivate_subscription(upgrade_id)
	_refresh_upgrades()

func _on_close_pressed():
	if not _was_paused:
		GameTime.set_paused(false)
	_current_desk = null
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if UITheme:
		UITheme.fade_out(self, 0.15)
	else:
		visible = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and visible:
		_on_close_pressed()
		get_viewport().set_input_as_handled()
