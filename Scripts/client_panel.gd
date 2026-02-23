extends Control

# === ЦВЕТА (как в проекте) ===
const COLOR_BLUE = Color(0.17254902, 0.30980393, 0.5686275, 1)
const COLOR_GREEN = Color(0.29803923, 0.6862745, 0.3137255, 1)
const COLOR_RED = Color(0.8980392, 0.22352941, 0.20784314, 1)
const COLOR_ORANGE = Color(1.0, 0.55, 0.0, 1)
const COLOR_GRAY = Color(0.5, 0.5, 0.5, 1)
const COLOR_DARK = Color(0.2, 0.2, 0.2, 1)
const COLOR_WHITE = Color(1, 1, 1, 1)
const COLOR_BORDER = Color(0.8784314, 0.8784314, 0.8784314, 1)
const COLOR_WINDOW_BORDER = Color(0, 0, 0, 1)
const COLOR_LOYALTY = Color(0.85, 0.2, 0.45, 1)
const COLOR_GOLD = Color(0.85, 0.65, 0.13, 1)
const COLOR_UNLOCK = Color(0.2, 0.5, 0.85, 1)
# Новый цвет для фона сводки (очень светло-серый/голубой)
const COLOR_SUMMARY_BG = Color(0.96, 0.97, 0.99, 1)

var _overlay: ColorRect
var _window: PanelContainer
var _scroll: ScrollContainer
var _cards_vbox: VBoxContainer
var _close_btn: Button

# Новые переменные для лейблов сводки
var _summary_loyalty_lbl: Label
var _summary_projects_lbl: Label

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	z_index = 90
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Принудительно растягиваем на весь экран (CanvasLayer не поддерживает anchors)
	_force_fullscreen_size()
	_build_ui()

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

	# === ОКНО: 1500×900 по центру (как EmployeeRoster/ProjectSelectionUI) ===
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

	# === ЗАГОЛОВОК — точно как в EmployeeRoster.tscn ===
	var header_panel = Panel.new()
	header_panel.custom_minimum_size = Vector2(0, 40)
	var header_style = StyleBoxFlat.new()
	header_style.bg_color = COLOR_BLUE
	header_style.border_color = COLOR_WINDOW_BORDER
	header_style.corner_radius_top_left = 20
	header_style.corner_radius_top_right = 20
	header_panel.add_theme_stylebox_override("panel", header_style)
	main_vbox.add_child(header_panel)

	# TitleLabel — по центру
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

	# CloseButton — правый край, белый фон, синий "X"
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

	# ===============================================
	# === НОВОЕ: ПАНЕЛЬ СВОДНОЙ СТАТИСТИКИ ===
	# ===============================================
	var summary_panel = PanelContainer.new()
	summary_panel.custom_minimum_size = Vector2(0, 50)
	summary_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var summary_style = StyleBoxFlat.new()
	summary_style.bg_color = COLOR_SUMMARY_BG
	summary_style.border_width_bottom = 2
	summary_style.border_color = COLOR_BORDER
	# Убираем скругление сверху, так как стыкуется с хедером, но оставляем снизу 0 (прямой стык со списком)
	summary_panel.add_theme_stylebox_override("panel", summary_style)
	main_vbox.add_child(summary_panel)

	var summary_hbox = HBoxContainer.new()
	summary_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	summary_hbox.add_theme_constant_override("separation", 60) # Расстояние между статами
	summary_panel.add_child(summary_hbox)
	
	# Лейбл 1: Общая лояльность
	_summary_loyalty_lbl = Label.new()
	_summary_loyalty_lbl.text = "..." # Заполнится в _populate()
	_summary_loyalty_lbl.add_theme_color_override("font_color", COLOR_LOYALTY)
	_summary_loyalty_lbl.add_theme_font_size_override("font_size", 18)
	if UITheme: UITheme.apply_font(_summary_loyalty_lbl, "bold")
	summary_hbox.add_child(_summary_loyalty_lbl)
	
	# Разделитель (визуальный)
	var sep = VSeparator.new()
	summary_hbox.add_child(sep)
	
	# Лейбл 2: Проектов в неделю
	_summary_projects_lbl = Label.new()
	_summary_projects_lbl.text = "..." # Заполнится в _populate()
	_summary_projects_lbl.add_theme_color_override("font_color", COLOR_BLUE)
	_summary_projects_lbl.add_theme_font_size_override("font_size", 18)
	if UITheme: UITheme.apply_font(_summary_projects_lbl, "bold")
	summary_hbox.add_child(_summary_projects_lbl)
	# ===============================================

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
	# --- ОБНОВЛЕНИЕ СВОДКИ ---
	var total_loyalty = ClientManager.get_total_loyalty()
	var weekly_projects = ClientManager.get_weekly_project_count()
	
	if _summary_loyalty_lbl:
		_summary_loyalty_lbl.text = tr("CLIENT_TOTAL_LOYALTY") % total_loyalty
		
	if _summary_projects_lbl:
		_summary_projects_lbl.text = tr("CLIENT_WEEKLY_PROJECTS") % weekly_projects
	# -------------------------

	for child in _cards_vbox.get_children():
		child.queue_free()

	for client in ClientManager.clients:
		var card = _create_client_card(client)
		_cards_vbox.add_child(card)

func _create_client_card(client: ClientData) -> PanelContainer:
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 1)
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
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	card.add_child(margin)

	var card_vbox = VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(card_vbox)

	# === СТРОКА 1: Название + лояльность ===
	var top_hbox = HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 10)
	card_vbox.add_child(top_hbox)

	var name_lbl = Label.new()
	name_lbl.text = client.emoji + "  " + client.client_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_color_override("font_color", COLOR_BLUE)
	name_lbl.add_theme_font_size_override("font_size", 17)
	if UITheme: UITheme.apply_font(name_lbl, "bold")
	top_hbox.add_child(name_lbl)

	var loyalty_level = client.get_loyalty_level()
	var loyalty_lbl = Label.new()
	loyalty_lbl.text = tr("CLIENT_LOYALTY_POINTS") % [client.loyalty, loyalty_level]
	loyalty_lbl.add_theme_color_override("font_color", COLOR_LOYALTY)
	loyalty_lbl.add_theme_font_size_override("font_size", 16)
	if UITheme: UITheme.apply_font(loyalty_lbl, "bold")
	top_hbox.add_child(loyalty_lbl)

	# === СТРОКА 2: Описание ===
	var desc_lbl = Label.new()
	desc_lbl.text = client.description
	desc_lbl.add_theme_color_override("font_color", COLOR_GRAY)
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if UITheme: UITheme.apply_font(desc_lbl, "regular")
	card_vbox.add_child(desc_lbl)

	# === СТРОКА 3: Статистика ===
	var stats_hbox = HBoxContainer.new()
	stats_hbox.add_theme_constant_override("separation", 25)
	card_vbox.add_child(stats_hbox)

	_add_stat_label(stats_hbox, tr("CLIENT_STAT_SUCCESS") % client.projects_completed_on_time, COLOR_GREEN)
	_add_stat_label(stats_hbox, tr("CLIENT_STAT_LATE") % client.projects_completed_late, COLOR_ORANGE)
	_add_stat_label(stats_hbox, tr("CLIENT_STAT_FAIL") % client.projects_failed, COLOR_RED)

	# === СТРОКА 4: Текущие бонусы ===
	var bonus_percent = client.get_budget_bonus_percent()
	var unlocked_types = client.get_unlocked_project_types()

	var bonus_hbox = HBoxContainer.new()
	bonus_hbox.add_theme_constant_override("separation", 20)
	card_vbox.add_child(bonus_hbox)

	var bonus_lbl = Label.new()
	bonus_lbl.text = tr("CLIENT_BONUS_BUDGET") % bonus_percent
	bonus_lbl.add_theme_color_override("font_color", COLOR_GREEN if bonus_percent > 0 else COLOR_DARK)
	bonus_lbl.add_theme_font_size_override("font_size", 14)
	if UITheme: UITheme.apply_font(bonus_lbl, "semibold")
	bonus_hbox.add_child(bonus_lbl)

	var types_lbl = Label.new()
	var types_text = tr("CLIENT_UNLOCKED_PROJECTS") % ", ".join(unlocked_types).to_upper()
	types_lbl.text = types_text
	types_lbl.add_theme_color_override("font_color", COLOR_UNLOCK)
	types_lbl.add_theme_font_size_override("font_size", 14)
	if UITheme: UITheme.apply_font(types_lbl, "semibold")
	bonus_hbox.add_child(types_lbl)

	# === СТРОКА 5: Прогресс-бар на ВСЮ шкалу с метками уровней ===
	var next_info = client.get_next_level_info()

	if not next_info.is_empty():
		# Есть следующий уровень — показываем полную шкалу
		var progress_vbox = VBoxContainer.new()
		progress_vbox.add_theme_constant_override("separation", 4)
		card_vbox.add_child(progress_vbox)

		# Прогресс-бар от 0 до MAX_LOYALTY
		var pbar = ProgressBar.new()
		pbar.min_value = 0
		pbar.max_value = ClientData.MAX_LOYALTY
		pbar.value = client.loyalty
		pbar.show_percentage = false
		pbar.custom_minimum_size = Vector2(300, 20)
		pbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var bg_style = StyleBoxFlat.new()
		bg_style.bg_color = Color(0.92, 0.92, 0.92, 1)
		bg_style.corner_radius_top_left = 10
		bg_style.corner_radius_top_right = 10
		bg_style.corner_radius_bottom_right = 10
		bg_style.corner_radius_bottom_left = 10
		pbar.add_theme_stylebox_override("background", bg_style)

		var fill_style = StyleBoxFlat.new()
		fill_style.bg_color = COLOR_LOYALTY
		fill_style.corner_radius_top_left = 10
		fill_style.corner_radius_top_right = 10
		fill_style.corner_radius_bottom_right = 10
		fill_style.corner_radius_bottom_left = 10
		pbar.add_theme_stylebox_override("fill", fill_style)

		progress_vbox.add_child(pbar)

		# Метки уровней под прогресс-баром
		var marks_hbox = HBoxContainer.new()
		marks_hbox.add_theme_constant_override("separation", 8)
		progress_vbox.add_child(marks_hbox)

		for i in range(ClientData.LOYALTY_LEVELS.size()):
			var level = ClientData.LOYALTY_LEVELS[i]
			var threshold = level["threshold"]
			if threshold == 0:
				continue  # Пропускаем нулевой уровень

			var mark_lbl = Label.new()
			var is_reached = client.loyalty >= threshold
			var icon = "✅" if is_reached else "⬜"
			# Здесь мы оборачиваем level["label"] в tr(), так как внутри хранятся ключи (например, LOYALTY_MICRO_PROJECTS)
			mark_lbl.text = "%s %d: %s" % [icon, threshold, tr(level["label"])]
			mark_lbl.add_theme_font_size_override("font_size", 11)

			if is_reached:
				mark_lbl.add_theme_color_override("font_color", COLOR_GREEN)
			else:
				mark_lbl.add_theme_color_override("font_color", COLOR_GRAY)

			if UITheme: UITheme.apply_font(mark_lbl, "regular")
			marks_hbox.add_child(mark_lbl)

		# Текст: сколько до следующего уровня
		var next_threshold = next_info["threshold"]
		var remaining = next_threshold - client.loyalty
		var next_text_lbl = Label.new()
		next_text_lbl.text = tr("CLIENT_NEXT_LEVEL_INFO") % [client.loyalty, next_threshold, next_info["label"]]
		next_text_lbl.add_theme_color_override("font_color", COLOR_DARK)
		next_text_lbl.add_theme_font_size_override("font_size", 12)
		if UITheme: UITheme.apply_font(next_text_lbl, "semibold")
		progress_vbox.add_child(next_text_lbl)

	else:
		# Максимальный уровень
		var max_lbl = Label.new()
		max_lbl.text = tr("CLIENT_MAX_LEVEL")
		max_lbl.add_theme_color_override("font_color", COLOR_GREEN)
		max_lbl.add_theme_font_size_override("font_size", 13)
		if UITheme: UITheme.apply_font(max_lbl, "semibold")
		card_vbox.add_child(max_lbl)

	return card

func _add_stat_label(parent: HBoxContainer, text: String, color: Color):
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 13)
	if UITheme: UITheme.apply_font(lbl, "semibold")
	parent.add_child(lbl)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and visible:
		close() 
		get_viewport().set_input_as_handled()
