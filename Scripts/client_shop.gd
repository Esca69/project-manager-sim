extends Control

# === ЦВЕТА ===
const COLOR_BLUE = Color(0.17254902, 0.30980393, 0.5686275, 1)
const COLOR_GREEN = Color(0.29803923, 0.6862745, 0.3137255, 1)
const COLOR_GRAY = Color(0.5, 0.5, 0.5, 1)
const COLOR_DARK = Color(0.2, 0.2, 0.2, 1)
const COLOR_WHITE = Color(1, 1, 1, 1)
const COLOR_BORDER = Color(0.8784314, 0.8784314, 0.8784314, 1)
const COLOR_WINDOW_BORDER = Color(0, 0, 0, 1)
const COLOR_GOLD = Color(0.85, 0.65, 0.13, 1)

var client_id: String = ""
var panel_ref: Control = null  # ссылка на client_panel для обновления после возврата

var _overlay: ColorRect
var _window: PanelContainer
var _content_root: VBoxContainer

var _btn_style: StyleBoxFlat
var _btn_style_hover: StyleBoxFlat
var _btn_style_disabled: StyleBoxFlat

const ROMAN_NUMERALS = ["I", "II", "III", "IV", "V", "VI"]

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 95
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_force_fullscreen_size()
	_init_button_styles()
	_build_ui()

func _force_fullscreen_size():
	var vp_size = get_viewport().get_visible_rect().size
	position = Vector2.ZERO
	size = vp_size

func _init_button_styles():
	_btn_style = StyleBoxFlat.new()
	_btn_style.bg_color = COLOR_WHITE
	_btn_style.border_width_left = 2
	_btn_style.border_width_top = 2
	_btn_style.border_width_right = 2
	_btn_style.border_width_bottom = 2
	_btn_style.border_color = COLOR_BLUE
	_btn_style.corner_radius_top_left = 20
	_btn_style.corner_radius_top_right = 20
	_btn_style.corner_radius_bottom_right = 20
	_btn_style.corner_radius_bottom_left = 20

	_btn_style_hover = StyleBoxFlat.new()
	_btn_style_hover.bg_color = COLOR_BLUE
	_btn_style_hover.border_width_left = 2
	_btn_style_hover.border_width_top = 2
	_btn_style_hover.border_width_right = 2
	_btn_style_hover.border_width_bottom = 2
	_btn_style_hover.border_color = COLOR_BLUE
	_btn_style_hover.corner_radius_top_left = 20
	_btn_style_hover.corner_radius_top_right = 20
	_btn_style_hover.corner_radius_bottom_right = 20
	_btn_style_hover.corner_radius_bottom_left = 20

	_btn_style_disabled = StyleBoxFlat.new()
	_btn_style_disabled.bg_color = Color(0.9, 0.9, 0.92, 1)
	_btn_style_disabled.border_width_left = 2
	_btn_style_disabled.border_width_top = 2
	_btn_style_disabled.border_width_right = 2
	_btn_style_disabled.border_width_bottom = 2
	_btn_style_disabled.border_color = Color(0.75, 0.75, 0.78, 1)
	_btn_style_disabled.corner_radius_top_left = 20
	_btn_style_disabled.corner_radius_top_right = 20
	_btn_style_disabled.corner_radius_bottom_right = 20
	_btn_style_disabled.corner_radius_bottom_left = 20

func _build_ui():
	# Overlay
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.55)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	# Окно 1500×900
	_window = PanelContainer.new()
	_window.custom_minimum_size = Vector2(1500, 900)
	_window.set_anchors_preset(Control.PRESET_CENTER)
	_window.offset_left = -750
	_window.offset_top = -450
	_window.offset_right = 750
	_window.offset_bottom = 450
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
	add_child(_window)

	_content_root = VBoxContainer.new()
	_content_root.add_theme_constant_override("separation", 0)
	_window.add_child(_content_root)

	_rebuild()

func _rebuild():
	for child in _content_root.get_children():
		child.queue_free()

	var client = ClientManager.get_client_by_id(client_id)
	if client == null:
		return

	# === ЗАГОЛОВОК ===
	var header_panel = Panel.new()
	header_panel.custom_minimum_size = Vector2(0, 40)
	var header_style = StyleBoxFlat.new()
	header_style.bg_color = COLOR_BLUE
	header_style.corner_radius_top_left = 20
	header_style.corner_radius_top_right = 20
	header_panel.add_theme_stylebox_override("panel", header_style)
	_content_root.add_child(header_panel)

	var title_lbl = Label.new()
	title_lbl.text = tr("CLIENT_SHOP_TITLE") % client.get_display_name()
	title_lbl.set_anchors_preset(Control.PRESET_CENTER)
	title_lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title_lbl.grow_vertical = Control.GROW_DIRECTION_BOTH
	title_lbl.offset_left = -200
	title_lbl.offset_top = -11.5
	title_lbl.offset_right = 200
	title_lbl.offset_bottom = 11.5
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_color_override("font_color", COLOR_WHITE)
	title_lbl.add_theme_font_size_override("font_size", 16)
	if UITheme: UITheme.apply_font(title_lbl, "bold")
	header_panel.add_child(title_lbl)

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
	close_btn.add_theme_color_override("font_color", COLOR_BLUE)
	var close_style = StyleBoxFlat.new()
	close_style.bg_color = COLOR_WHITE
	close_style.corner_radius_top_left = 10
	close_style.corner_radius_top_right = 10
	close_style.corner_radius_bottom_right = 10
	close_style.corner_radius_bottom_left = 10
	close_btn.add_theme_stylebox_override("normal", close_style)
	if UITheme: UITheme.apply_font(close_btn, "semibold")
	close_btn.pressed.connect(_on_close)
	header_panel.add_child(close_btn)

	# === ПАНЕЛЬ СВОДКИ ===
	var summary_panel = PanelContainer.new()
	summary_panel.custom_minimum_size = Vector2(0, 60)
	summary_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var summary_style = StyleBoxFlat.new()
	summary_style.bg_color = Color(0.96, 0.97, 0.99, 1)
	summary_style.border_width_bottom = 2
	summary_style.border_color = COLOR_BORDER
	summary_panel.add_theme_stylebox_override("panel", summary_style)
	_content_root.add_child(summary_panel)

	var sum_hbox = HBoxContainer.new()
	sum_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	sum_hbox.add_theme_constant_override("separation", 40)
	summary_panel.add_child(sum_hbox)

	_add_summary_label(sum_hbox, tr("CLIENT_AVAILABLE_POINTS") % ClientManager.reputation_points, COLOR_GOLD)

	var sep1 = VSeparator.new()
	sum_hbox.add_child(sep1)

	_add_summary_label(sum_hbox, tr("CLIENT_PROJECTS_DONE") % client.get_total_projects(), COLOR_BLUE)

	var sep2 = VSeparator.new()
	sum_hbox.add_child(sep2)

	_add_summary_label(sum_hbox, tr("CLIENT_CURRENT_BONUS") % client.get_budget_bonus_percent(), COLOR_GREEN)

	var sep3 = VSeparator.new()
	sum_hbox.add_child(sep3)

	var types = client.get_unlocked_project_types()
	_add_summary_label(sum_hbox, tr("CLIENT_CURRENT_TYPES") % ", ".join(types), COLOR_DARK)

	# === КОНТЕНТ: скролл ===
	var content_margin = MarginContainer.new()
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_left", 24)
	content_margin.add_theme_constant_override("margin_top", 16)
	content_margin.add_theme_constant_override("margin_right", 24)
	content_margin.add_theme_constant_override("margin_bottom", 16)
	_content_root.add_child(content_margin)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_margin.add_child(scroll)

	var items_vbox = VBoxContainer.new()
	items_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items_vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(items_vbox)

	# === СЕКЦИЯ: ТИПЫ ПРОЕКТОВ ===
	items_vbox.add_child(_make_section_header(tr("CLIENT_SECTION_TYPES")))

	# Контракт на Simple
	if client.has_simple:
		items_vbox.add_child(_make_card_purchased(tr("CLIENT_SIMPLE_TITLE"), tr("CLIENT_SIMPLE_DESC"), "📄"))
	else:
		var can_afford = ClientManager.reputation_points >= ClientData.SIMPLE_UNLOCK_COST
		items_vbox.add_child(_make_card_buyable(
			tr("CLIENT_SIMPLE_TITLE"),
			tr("CLIENT_SIMPLE_DESC"),
			ClientData.SIMPLE_UNLOCK_COST,
			can_afford,
			func(): _buy_simple(),
			"📄"
		))

	# Контракт на Easy
	if not client.has_simple:
		items_vbox.add_child(_make_card_locked(tr("CLIENT_EASY_TITLE"), tr("CLIENT_EASY_DESC"), tr("CLIENT_EASY_LOCKED"), "📋"))
	elif client.has_easy:
		items_vbox.add_child(_make_card_purchased(tr("CLIENT_EASY_TITLE"), tr("CLIENT_EASY_DESC"), "📋"))
	else:
		var can_afford = ClientManager.reputation_points >= ClientData.EASY_UNLOCK_COST
		items_vbox.add_child(_make_card_buyable(
			tr("CLIENT_EASY_TITLE"),
			tr("CLIENT_EASY_DESC"),
			ClientData.EASY_UNLOCK_COST,
			can_afford,
			func(): _buy_easy(),
			"📋"
		))

	# Support-контракт (параллельная ветка)
	if client.has_support:
		items_vbox.add_child(_make_card_purchased(tr("CLIENT_SUPPORT_TITLE"), tr("CLIENT_SUPPORT_DESC"), "🛟"))
	else:
		var can_afford_support = ClientManager.reputation_points >= ClientData.SUPPORT_UNLOCK_COST
		items_vbox.add_child(_make_card_buyable(
			tr("CLIENT_SUPPORT_TITLE"),
			tr("CLIENT_SUPPORT_DESC"),
			ClientData.SUPPORT_UNLOCK_COST,
			can_afford_support,
			func(): _buy_support(),
			"🛟"
		))

	# === СЕКЦИЯ: БЮДЖЕТ ПРОЕКТОВ ===
	items_vbox.add_child(_make_section_header(tr("CLIENT_SECTION_BUDGET")))

	for i in range(ClientData.MAX_BUDGET_LEVEL):
		var level_num = i + 1  # 1–6
		var roman = ROMAN_NUMERALS[i]
		var title = tr("CLIENT_BUDGET_TITLE") % roman
		var desc = tr("CLIENT_BUDGET_DESC") % (level_num * 5)

		if i < client.budget_level:
			# Уже куплено
			items_vbox.add_child(_make_card_purchased(title, desc, "💰"))
		elif i == client.budget_level:
			# Доступно для покупки
			var can_afford = ClientManager.reputation_points >= ClientData.BUDGET_UPGRADE_COST
			items_vbox.add_child(_make_card_buyable(
				title, desc, ClientData.BUDGET_UPGRADE_COST, can_afford,
				func(): _buy_budget(),
				"💰"
			))
		else:
			# Заблокировано
			items_vbox.add_child(_make_card_locked(title, desc, tr("CLIENT_BUDGET_LOCKED"), "💰"))

func _add_summary_label(parent: HBoxContainer, text: String, color: Color):
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 15)
	if UITheme: UITheme.apply_font(lbl, "semibold")
	parent.add_child(lbl)

func _make_section_header(text: String) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", COLOR_BLUE)
	lbl.add_theme_font_size_override("font_size", 14)
	if UITheme: UITheme.apply_font(lbl, "bold")
	return lbl

func _create_emoji_label(emoji: String) -> Label:
	var icon_lbl = Label.new()
	icon_lbl.text = emoji
	icon_lbl.add_theme_font_size_override("font_size", 36)
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_lbl.custom_minimum_size = Vector2(52, 0)
	return icon_lbl

func _make_card_purchased(title: String, desc: String, emoji: String = "") -> PanelContainer:
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.93, 0.98, 0.93, 1)
	card_style.border_width_left = 2
	card_style.border_width_top = 2
	card_style.border_width_right = 2
	card_style.border_width_bottom = 2
	card_style.border_color = Color(0.29803923, 0.6862745, 0.3137255, 0.5)
	card_style.corner_radius_top_left = 14
	card_style.corner_radius_top_right = 14
	card_style.corner_radius_bottom_right = 14
	card_style.corner_radius_bottom_left = 14
	card.add_theme_stylebox_override("panel", card_style)

	var m = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 16)
	m.add_theme_constant_override("margin_top", 10)
	m.add_theme_constant_override("margin_right", 16)
	m.add_theme_constant_override("margin_bottom", 10)
	card.add_child(m)

	var hbox = HBoxContainer.new()
	m.add_child(hbox)

	if emoji != "":
		hbox.add_child(_create_emoji_label(emoji))

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 3)
	hbox.add_child(vbox)

	var t_lbl = Label.new()
	t_lbl.text = title
	t_lbl.add_theme_color_override("font_color", Color(0.2, 0.6, 0.2, 1))
	t_lbl.add_theme_font_size_override("font_size", 14)
	if UITheme: UITheme.apply_font(t_lbl, "bold")
	vbox.add_child(t_lbl)

	var d_lbl = Label.new()
	d_lbl.text = desc
	d_lbl.add_theme_color_override("font_color", Color(0.4, 0.5, 0.4, 1))
	d_lbl.add_theme_font_size_override("font_size", 12)
	if UITheme: UITheme.apply_font(d_lbl, "regular")
	vbox.add_child(d_lbl)

	var status_lbl = Label.new()
	status_lbl.text = tr("CLIENT_PURCHASED")
	status_lbl.add_theme_color_override("font_color", Color(0.2, 0.7, 0.2, 1))
	status_lbl.add_theme_font_size_override("font_size", 13)
	if UITheme: UITheme.apply_font(status_lbl, "semibold")
	hbox.add_child(status_lbl)

	return card

func _make_card_locked(title: String, desc: String, lock_reason: String, emoji: String = "") -> PanelContainer:
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.96, 0.96, 0.96, 1)
	card_style.border_width_left = 2
	card_style.border_width_top = 2
	card_style.border_width_right = 2
	card_style.border_width_bottom = 2
	card_style.border_color = Color(0.8, 0.8, 0.8, 1)
	card_style.corner_radius_top_left = 14
	card_style.corner_radius_top_right = 14
	card_style.corner_radius_bottom_right = 14
	card_style.corner_radius_bottom_left = 14
	card.add_theme_stylebox_override("panel", card_style)

	var m = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 16)
	m.add_theme_constant_override("margin_top", 10)
	m.add_theme_constant_override("margin_right", 16)
	m.add_theme_constant_override("margin_bottom", 10)
	card.add_child(m)

	var hbox = HBoxContainer.new()
	m.add_child(hbox)

	if emoji != "":
		hbox.add_child(_create_emoji_label(emoji))

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 3)
	hbox.add_child(vbox)

	var t_lbl = Label.new()
	t_lbl.text = title
	t_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
	t_lbl.add_theme_font_size_override("font_size", 14)
	if UITheme: UITheme.apply_font(t_lbl, "bold")
	vbox.add_child(t_lbl)

	var d_lbl = Label.new()
	d_lbl.text = desc
	d_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	d_lbl.add_theme_font_size_override("font_size", 12)
	if UITheme: UITheme.apply_font(d_lbl, "regular")
	vbox.add_child(d_lbl)

	var locked_lbl = Label.new()
	locked_lbl.text = "🔒 " + lock_reason
	locked_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
	locked_lbl.add_theme_font_size_override("font_size", 12)
	if UITheme: UITheme.apply_font(locked_lbl, "regular")
	hbox.add_child(locked_lbl)

	return card

func _make_card_buyable(title: String, desc: String, cost: int, can_afford: bool, on_buy: Callable, emoji: String = "") -> PanelContainer:
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var card_style = StyleBoxFlat.new()
	card_style.bg_color = COLOR_WHITE
	card_style.border_width_left = 2
	card_style.border_width_top = 2
	card_style.border_width_right = 2
	card_style.border_width_bottom = 2
	card_style.border_color = COLOR_BORDER
	card_style.corner_radius_top_left = 14
	card_style.corner_radius_top_right = 14
	card_style.corner_radius_bottom_right = 14
	card_style.corner_radius_bottom_left = 14
	if UITheme: UITheme.apply_shadow(card_style)
	card.add_theme_stylebox_override("panel", card_style)

	var m = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 16)
	m.add_theme_constant_override("margin_top", 10)
	m.add_theme_constant_override("margin_right", 16)
	m.add_theme_constant_override("margin_bottom", 10)
	card.add_child(m)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	m.add_child(hbox)

	if emoji != "":
		hbox.add_child(_create_emoji_label(emoji))

	var left_vbox = VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(left_vbox)

	var t_lbl = Label.new()
	t_lbl.text = title
	t_lbl.add_theme_color_override("font_color", COLOR_BLUE)
	t_lbl.add_theme_font_size_override("font_size", 15)
	if UITheme: UITheme.apply_font(t_lbl, "bold")
	left_vbox.add_child(t_lbl)

	var d_lbl = Label.new()
	d_lbl.text = desc
	d_lbl.add_theme_color_override("font_color", COLOR_GRAY)
	d_lbl.add_theme_font_size_override("font_size", 13)
	if UITheme: UITheme.apply_font(d_lbl, "regular")
	left_vbox.add_child(d_lbl)

	var cost_lbl = Label.new()
	cost_lbl.text = tr("CLIENT_COST") % cost
	cost_lbl.add_theme_color_override("font_color", COLOR_GOLD)
	cost_lbl.add_theme_font_size_override("font_size", 13)
	if UITheme: UITheme.apply_font(cost_lbl, "semibold")
	left_vbox.add_child(cost_lbl)

	var right_vbox = VBoxContainer.new()
	right_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(right_vbox)

	var buy_btn = Button.new()
	buy_btn.custom_minimum_size = Vector2(160, 40)
	buy_btn.focus_mode = Control.FOCUS_NONE
	buy_btn.disabled = not can_afford

	if can_afford:
		buy_btn.text = tr("CLIENT_BTN_BUY")
		buy_btn.add_theme_stylebox_override("normal", _btn_style)
		buy_btn.add_theme_stylebox_override("hover", _btn_style_hover)
		buy_btn.add_theme_stylebox_override("pressed", _btn_style_hover)
		buy_btn.add_theme_color_override("font_color", COLOR_BLUE)
		buy_btn.add_theme_color_override("font_hover_color", COLOR_WHITE)
		buy_btn.add_theme_color_override("font_pressed_color", COLOR_WHITE)
		buy_btn.pressed.connect(on_buy)
	else:
		buy_btn.text = tr("CLIENT_NOT_ENOUGH")
		buy_btn.add_theme_stylebox_override("normal", _btn_style_disabled)
		buy_btn.add_theme_stylebox_override("hover", _btn_style_disabled)
		buy_btn.add_theme_stylebox_override("pressed", _btn_style_disabled)
		buy_btn.add_theme_stylebox_override("disabled", _btn_style_disabled)
		buy_btn.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6, 1))
		buy_btn.add_theme_color_override("font_hover_color", Color(0.55, 0.55, 0.6, 1))
		buy_btn.add_theme_color_override("font_disabled_color", Color(0.55, 0.55, 0.6, 1))

	buy_btn.add_theme_font_size_override("font_size", 14)
	if UITheme: UITheme.apply_font(buy_btn, "semibold")
	right_vbox.add_child(buy_btn)

	return card

func _buy_simple():
	var client = ClientManager.get_client_by_id(client_id)
	if client == null: return
	if ClientManager.buy_simple_unlock(client_id):
		EventLog.add(tr("LOG_CLIENT_UPGRADE") % client.get_display_name(), EventLog.LogType.PROGRESS)
		_rebuild()

func _buy_easy():
	var client = ClientManager.get_client_by_id(client_id)
	if client == null: return
	if ClientManager.buy_easy_unlock(client_id):
		EventLog.add(tr("LOG_CLIENT_UPGRADE") % client.get_display_name(), EventLog.LogType.PROGRESS)
		_rebuild()

func _buy_support():
	var client = ClientManager.get_client_by_id(client_id)
	if client == null: return
	if ClientManager.buy_support_unlock(client_id):
		EventLog.add(tr("LOG_CLIENT_UPGRADE") % client.get_display_name(), EventLog.LogType.PROGRESS)
		_rebuild()

func _buy_budget():
	var client = ClientManager.get_client_by_id(client_id)
	if client == null: return
	if ClientManager.buy_budget_upgrade(client_id):
		EventLog.add(tr("LOG_CLIENT_UPGRADE") % client.get_display_name(), EventLog.LogType.PROGRESS)
		_rebuild()

func _on_close():
	# Обновить карточки в client_panel при возврате
	if panel_ref and panel_ref.has_method("_populate"):
		panel_ref._populate()
	queue_free()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_close()
		get_viewport().set_input_as_handled()
