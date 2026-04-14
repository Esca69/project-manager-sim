extends Control

# === ЦВЕТА ===
const COLOR_BLUE = Color(0.17254902, 0.30980393, 0.5686275, 1)
const COLOR_GREEN = Color(0.29803923, 0.6862745, 0.3137255, 1)
const COLOR_RED = Color(0.8980392, 0.22352941, 0.20784314, 1)
const COLOR_ORANGE = Color(1.0, 0.55, 0.0, 1)
const COLOR_GRAY = Color(0.5, 0.5, 0.5, 1)
const COLOR_DARK = Color(0.2, 0.2, 0.2, 1)
const COLOR_WHITE = Color(1, 1, 1, 1)
const COLOR_BORDER = Color(0.8784314, 0.8784314, 0.8784314, 1)
const COLOR_WINDOW_BORDER = Color(0, 0, 0, 1)
const COLOR_GOLD = Color(0.85, 0.65, 0.13, 1)
const COLOR_SUMMARY_BG = Color(0.96, 0.97, 0.99, 1)

var _overlay: ColorRect
var _window: PanelContainer
var _scroll: ScrollContainer
var _cards_vbox: VBoxContainer
var _close_btn: Button

var _summary_rp_lbl: Label
var _summary_gr_lbl: Label

# Кнопки стилей
var _btn_style: StyleBoxFlat
var _btn_style_hover: StyleBoxFlat

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	z_index = 90
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_force_fullscreen_size()
	_init_button_styles()
	_build_ui()

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

func _force_fullscreen_size():
	var vp_size = get_viewport().get_visible_rect().size
	position = Vector2.ZERO
	size = vp_size

func open():
	_force_fullscreen_size()
	_populate()
	if UITheme:
		UITheme.fade_in(self, 0.2)
	else:
		visible = true

func close():
	get_tree().call_group("client_tooltip", "queue_free")
	if UITheme:
		UITheme.fade_out(self, 0.15)
	else:
		visible = false

# === ПОСТРОЕНИЕ КАРКАСА ===
func _build_ui():
	# Затемнение фона
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.45)
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
	if UITheme:
		UITheme.apply_shadow(window_style, false)
	_window.add_theme_stylebox_override("panel", window_style)
	add_child(_window)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 0)
	_window.add_child(main_vbox)

	# === ЗАГОЛОВОК ===
	var header_panel = Panel.new()
	header_panel.custom_minimum_size = Vector2(0, 40)
	var header_style = StyleBoxFlat.new()
	header_style.bg_color = COLOR_BLUE
	header_style.border_color = COLOR_WINDOW_BORDER
	header_style.corner_radius_top_left = 20
	header_style.corner_radius_top_right = 20
	header_panel.add_theme_stylebox_override("panel", header_style)
	main_vbox.add_child(header_panel)

	var title_label = Label.new()
	title_label.text = tr("TAB_CLIENTS")
	title_label.set_anchors_preset(Control.PRESET_CENTER)
	title_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	title_label.offset_left = -88
	title_label.offset_top = -11.5
	title_label.offset_right = 88
	title_label.offset_bottom = 11.5
	title_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", COLOR_WHITE)
	title_label.add_theme_font_size_override("font_size", 16)
	if UITheme: UITheme.apply_font(title_label, "bold")
	header_panel.add_child(title_label)

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
	_close_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	_close_btn.size_flags_vertical = Control.SIZE_SHRINK_END
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

	# === ПАНЕЛЬ СВОДКИ ===
	var summary_panel = PanelContainer.new()
	summary_panel.custom_minimum_size = Vector2(0, 50)
	summary_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var summary_style = StyleBoxFlat.new()
	summary_style.bg_color = COLOR_SUMMARY_BG
	summary_style.border_width_bottom = 2
	summary_style.border_color = COLOR_BORDER
	summary_panel.add_theme_stylebox_override("panel", summary_style)
	main_vbox.add_child(summary_panel)

	var summary_hbox = HBoxContainer.new()
	summary_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	summary_hbox.add_theme_constant_override("separation", 60)
	summary_panel.add_child(summary_hbox)

	# --- RP group ---
	var rp_group = HBoxContainer.new()
	rp_group.add_theme_constant_override("separation", 8)
	summary_hbox.add_child(rp_group)

	_summary_rp_lbl = Label.new()
	_summary_rp_lbl.text = "..."
	_summary_rp_lbl.add_theme_color_override("font_color", COLOR_GOLD)
	_summary_rp_lbl.add_theme_font_size_override("font_size", 18)
	if UITheme: UITheme.apply_font(_summary_rp_lbl, "bold")
	rp_group.add_child(_summary_rp_lbl)

	var rp_help_btn = _create_help_button()
	_attach_help_tooltip(rp_help_btn, func(): return tr("TOOLTIP_REPUTATION_POINTS"))
	rp_group.add_child(rp_help_btn)

	var sep = VSeparator.new()
	summary_hbox.add_child(sep)

	# --- GR group ---
	var gr_group = HBoxContainer.new()
	gr_group.add_theme_constant_override("separation", 8)
	summary_hbox.add_child(gr_group)

	_summary_gr_lbl = Label.new()
	_summary_gr_lbl.text = "..."
	_summary_gr_lbl.add_theme_color_override("font_color", COLOR_BLUE)
	_summary_gr_lbl.add_theme_font_size_override("font_size", 18)
	if UITheme: UITheme.apply_font(_summary_gr_lbl, "bold")
	gr_group.add_child(_summary_gr_lbl)

	var gr_help_btn = _create_help_button()
	_attach_help_tooltip(gr_help_btn, func(): return tr("TOOLTIP_GLOBAL_REPUTATION") % ClientManager.get_weekly_project_count())
	gr_group.add_child(gr_help_btn)

	# === КОНТЕНТ ===
	var content_margin = MarginContainer.new()
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_left", 20)
	content_margin.add_theme_constant_override("margin_top", 20)
	content_margin.add_theme_constant_override("margin_right", 20)
	content_margin.add_theme_constant_override("margin_bottom", 20)
	main_vbox.add_child(content_margin)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_margin.add_child(_scroll)

	_cards_vbox = VBoxContainer.new()
	_cards_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cards_vbox.add_theme_constant_override("separation", 15)
	_scroll.add_child(_cards_vbox)

# === НАПОЛНЕНИЕ ДАННЫМИ ===
func _populate():
	if _summary_rp_lbl:
		_summary_rp_lbl.text = tr("CLIENT_REPUTATION_POINTS") % ClientManager.reputation_points
	if _summary_gr_lbl:
		_summary_gr_lbl.text = tr("CLIENT_GLOBAL_REPUTATION") % ClientManager.global_reputation

	for child in _cards_vbox.get_children():
		child.queue_free()

	# 3 карточки в первом ряду, 2 во втором по центру
	var clients = ClientManager.clients
	var row1 = HBoxContainer.new()
	row1.add_theme_constant_override("separation", 14)
	row1.alignment = BoxContainer.ALIGNMENT_CENTER
	row1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards_vbox.add_child(row1)

	var row2 = HBoxContainer.new()
	row2.add_theme_constant_override("separation", 14)
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	row2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards_vbox.add_child(row2)

	for i in range(clients.size()):
		var client = clients[i]
		var card = _create_client_card(client)
		if i < 3:
			row1.add_child(card)
		else:
			row2.add_child(card)

func _create_client_card(client: ClientData) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(440, 0)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_WHITE
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = COLOR_BORDER
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_right = 16
	style.corner_radius_bottom_left = 16
	if UITheme: UITheme.apply_shadow(style)
	card.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	card.add_child(margin)

	var card_vbox = VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(card_vbox)

	# Emoji крупно
	var emoji_lbl = Label.new()
	emoji_lbl.text = client.emoji
	emoji_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji_lbl.add_theme_font_size_override("font_size", 36)
	card_vbox.add_child(emoji_lbl)

	# Имя клиента
	var name_lbl = Label.new()
	name_lbl.text = tr(client.client_name)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_color_override("font_color", COLOR_BLUE)
	name_lbl.add_theme_font_size_override("font_size", 16)
	if UITheme: UITheme.apply_font(name_lbl, "bold")
	card_vbox.add_child(name_lbl)

	# Проектов сдано
	var done_lbl = Label.new()
	done_lbl.text = tr("CLIENT_PROJECTS_DONE") % client.get_total_projects()
	done_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	done_lbl.add_theme_color_override("font_color", COLOR_GRAY)
	done_lbl.add_theme_font_size_override("font_size", 13)
	if UITheme: UITheme.apply_font(done_lbl, "regular")
	card_vbox.add_child(done_lbl)

	# Купленные бонусы
	var bonus_parts = []
	var budget_pct = client.get_budget_bonus_percent()
	if budget_pct > 0:
		bonus_parts.append(tr("CLIENT_CURRENT_BONUS") % budget_pct)
	var type_parts = []
	if client.has_simple: type_parts.append("Simple")
	if client.has_easy: type_parts.append("Easy")
	if type_parts.size() > 0:
		bonus_parts.append(" · ".join(type_parts))

	var bonus_lbl = Label.new()
	if bonus_parts.size() > 0:
		bonus_lbl.text = " | ".join(bonus_parts)
		bonus_lbl.add_theme_color_override("font_color", COLOR_GREEN)
	else:
		bonus_lbl.text = tr("CLIENT_MICRO_ONLY")
		bonus_lbl.add_theme_color_override("font_color", COLOR_GRAY)
	bonus_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bonus_lbl.add_theme_font_size_override("font_size", 13)
	if UITheme: UITheme.apply_font(bonus_lbl, "semibold")
	card_vbox.add_child(bonus_lbl)

	# Кнопка "Развить"
	var dev_btn = Button.new()
	dev_btn.text = tr("CLIENT_BTN_DEVELOP")
	dev_btn.custom_minimum_size = Vector2(180, 40)
	dev_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dev_btn.focus_mode = Control.FOCUS_NONE
	dev_btn.add_theme_stylebox_override("normal", _btn_style)
	dev_btn.add_theme_stylebox_override("hover", _btn_style_hover)
	dev_btn.add_theme_stylebox_override("pressed", _btn_style_hover)
	dev_btn.add_theme_color_override("font_color", COLOR_BLUE)
	dev_btn.add_theme_color_override("font_hover_color", COLOR_WHITE)
	dev_btn.add_theme_color_override("font_pressed_color", COLOR_WHITE)
	dev_btn.add_theme_font_size_override("font_size", 14)
	if UITheme: UITheme.apply_font(dev_btn, "semibold")
	var cid = client.client_id
	dev_btn.pressed.connect(_open_shop.bind(cid))
	card_vbox.add_child(dev_btn)

	return card

func _open_shop(client_id: String):
	var shop_script = load("res://Scripts/client_shop.gd")
	if shop_script == null:
		return
	var shop = shop_script.new()
	shop.client_id = client_id
	shop.panel_ref = self
	add_child(shop)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and visible:
		close()
		get_viewport().set_input_as_handled()

func _create_help_button() -> Button:
	var btn = Button.new()
	btn.text = "?"
	btn.custom_minimum_size = Vector2(22, 22)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_color_override("font_color", COLOR_BLUE)

	var bstyle = StyleBoxFlat.new()
	bstyle.bg_color = Color(1, 1, 1, 1)
	bstyle.border_width_left = 2
	bstyle.border_width_top = 2
	bstyle.border_width_right = 2
	bstyle.border_width_bottom = 2
	bstyle.border_color = COLOR_BLUE
	bstyle.corner_radius_top_left = 11
	bstyle.corner_radius_top_right = 11
	bstyle.corner_radius_bottom_right = 11
	bstyle.corner_radius_bottom_left = 11
	btn.add_theme_stylebox_override("normal", bstyle)

	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.92, 0.94, 1.0, 1)
	hover_style.border_width_left = 2
	hover_style.border_width_top = 2
	hover_style.border_width_right = 2
	hover_style.border_width_bottom = 2
	hover_style.border_color = COLOR_BLUE
	hover_style.corner_radius_top_left = 11
	hover_style.corner_radius_top_right = 11
	hover_style.corner_radius_bottom_right = 11
	hover_style.corner_radius_bottom_left = 11
	btn.add_theme_stylebox_override("hover", hover_style)

	return btn

func _attach_help_tooltip(btn: Button, text_provider: Callable) -> void:
	var tooltip_ref: Array = [null]
	btn.mouse_entered.connect(func():
		if tooltip_ref[0] != null and is_instance_valid(tooltip_ref[0]):
			tooltip_ref[0].queue_free()
		var tp = TraitUIHelper.create_tooltip(text_provider.call(), COLOR_BLUE)
		add_child(tp)
		tp.add_to_group("client_tooltip")
		await get_tree().process_frame
		if not is_instance_valid(tp): return
		var btn_global = btn.global_position
		var viewport_height = get_viewport_rect().size.y
		var target_pos = Vector2(btn_global.x + 28, btn_global.y - 10)
		if target_pos.y + tp.size.y > viewport_height:
			target_pos.y = btn_global.y - tp.size.y + 20
		tp.global_position = target_pos
		tooltip_ref[0] = tp
	)
	btn.mouse_exited.connect(func():
		if tooltip_ref[0] != null and is_instance_valid(tooltip_ref[0]):
			tooltip_ref[0].queue_free()
		tooltip_ref[0] = null
	)
