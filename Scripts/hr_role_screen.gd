extends Control

signal search_started(role: String)

# === ЦВЕТА (как в проекте) ===
const COLOR_BLUE = Color(0.17254902, 0.30980393, 0.5686275, 1)
const COLOR_GREEN = Color(0.29803923, 0.6862745, 0.3137255, 1)
const COLOR_WHITE = Color(1, 1, 1, 1)
const COLOR_GRAY = Color(0.5, 0.5, 0.5, 1)
const COLOR_DARK = Color(0.2, 0.2, 0.2, 1)
const COLOR_BORDER = Color(0.8784314, 0.8784314, 0.8784314, 1)
const COLOR_WINDOW_BORDER = Color(0, 0, 0, 1)
const COLOR_RED = Color(0.8980392, 0.22352941, 0.20784314, 1)

var _overlay: ColorRect
var _window: PanelContainer
var _close_btn: Button
var _search_btn: Button
var _selected_role: String = ""
var _role_buttons: Array = []
var _time_warning_lbl: Label
var _time_info_lbl: Label

var _was_paused: bool = false

# Стили для кнопок ролей
var _role_style_normal: StyleBoxFlat
var _role_style_hover: StyleBoxFlat
var _role_style_selected: StyleBoxFlat
var _role_style_disabled: StyleBoxFlat

# Стили для кнопки поиска
var _search_style_normal: StyleBoxFlat
var _search_style_hover: StyleBoxFlat
var _search_style_disabled: StyleBoxFlat

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	z_index = 90
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_force_fullscreen_size()
	_build_styles()
	_build_ui()

func _force_fullscreen_size():
	var vp_size = get_viewport().get_visible_rect().size
	set_deferred("position", Vector2.ZERO)
	set_deferred("size", vp_size)

func open():
	_was_paused = GameTime.is_game_paused
	GameTime.set_paused(true)
	_force_fullscreen_size()
	_selected_role = ""
	_update_role_buttons_visual()
	_update_search_button()
	_update_time_warning()
	_update_time_info()

	# === ТУТОРИАЛ: только BA, скрыть кнопку закрытия ===
	if TutorialManager.is_active():
		_apply_tutorial_restrictions()
	else:
		_remove_tutorial_restrictions()

	if get_parent():
		get_parent().move_child(self, -1)

	if UITheme:
		UITheme.fade_in(self, 0.2)
	else:
		visible = true

func _apply_tutorial_restrictions():
	# Hide close button
	if _close_btn:
		_close_btn.visible = false
	# Disable non-BA role buttons with proper disabled style
	for rd in _role_buttons:
		var btn: Button = rd["button"]
		if rd["role"] != "Business Analyst":
			btn.add_theme_stylebox_override("normal", _role_style_disabled)
			btn.add_theme_stylebox_override("hover", _role_style_disabled)
			btn.add_theme_stylebox_override("pressed", _role_style_disabled)
			btn.add_theme_stylebox_override("disabled", _role_style_disabled)
			btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
			btn.add_theme_color_override("font_hover_color", Color(0.6, 0.6, 0.6, 1))
			btn.add_theme_color_override("font_pressed_color", Color(0.6, 0.6, 0.6, 1))
			btn.add_theme_color_override("font_disabled_color", Color(0.6, 0.6, 0.6, 1))
			btn.disabled = true

func _remove_tutorial_restrictions():
	# Show close button
	if _close_btn:
		_close_btn.visible = true
	# Re-enable all role buttons and restore normal styles
	for rd in _role_buttons:
		var btn: Button = rd["button"]
		btn.add_theme_stylebox_override("normal", _role_style_normal)
		btn.add_theme_stylebox_override("hover", _role_style_hover)
		btn.add_theme_stylebox_override("pressed", _role_style_selected)
		btn.remove_theme_stylebox_override("disabled")
		btn.add_theme_color_override("font_color", COLOR_BLUE)
		btn.add_theme_color_override("font_hover_color", COLOR_BLUE)
		btn.add_theme_color_override("font_pressed_color", COLOR_WHITE)
		btn.remove_theme_color_override("font_disabled_color")
		btn.disabled = false

func close():
	if TutorialManager.is_active():
		return  # Can't close HR screen during tutorial
	if not _was_paused:
		GameTime.set_paused(false)
	if UITheme:
		UITheme.fade_out(self, 0.15)
	else:
		visible = false

func _close_forced():
	if not _was_paused:
		GameTime.set_paused(false)
	if UITheme:
		UITheme.fade_out(self, 0.15)
	else:
		visible = false

func _is_too_late() -> bool:
	return GameTime.hour >= PMData.get_hr_cutoff_hour()

# === СТИЛИ ===
func _build_styles():
	# Кнопка роли — обычная
	_role_style_normal = StyleBoxFlat.new()
	_role_style_normal.bg_color = COLOR_WHITE
	_role_style_normal.border_width_left = 2
	_role_style_normal.border_width_top = 2
	_role_style_normal.border_width_right = 2
	_role_style_normal.border_width_bottom = 2
	_role_style_normal.border_color = COLOR_BORDER
	_role_style_normal.corner_radius_top_left = 16
	_role_style_normal.corner_radius_top_right = 16
	_role_style_normal.corner_radius_bottom_right = 16
	_role_style_normal.corner_radius_bottom_left = 16

	# Кнопка роли — hover
	_role_style_hover = StyleBoxFlat.new()
	_role_style_hover.bg_color = Color(0.96, 0.97, 1.0, 1)
	_role_style_hover.border_width_left = 2
	_role_style_hover.border_width_top = 2
	_role_style_hover.border_width_right = 2
	_role_style_hover.border_width_bottom = 2
	_role_style_hover.border_color = COLOR_BLUE
	_role_style_hover.corner_radius_top_left = 16
	_role_style_hover.corner_radius_top_right = 16
	_role_style_hover.corner_radius_bottom_right = 16
	_role_style_hover.corner_radius_bottom_left = 16

	# Кнопка роли — выбрана
	_role_style_selected = StyleBoxFlat.new()
	_role_style_selected.bg_color = Color(0.93, 0.93, 1.0, 1)
	_role_style_selected.border_width_left = 3
	_role_style_selected.border_width_top = 3
	_role_style_selected.border_width_right = 3
	_role_style_selected.border_width_bottom = 3
	_role_style_selected.border_color = COLOR_BLUE
	_role_style_selected.corner_radius_top_left = 16
	_role_style_selected.corner_radius_top_right = 16
	_role_style_selected.corner_radius_bottom_right = 16
	_role_style_selected.corner_radius_bottom_left = 16

	# Кнопка роли — disabled (туториал)
	_role_style_disabled = StyleBoxFlat.new()
	_role_style_disabled.bg_color = Color(0.95, 0.95, 0.95, 1)
	_role_style_disabled.border_width_left = 2
	_role_style_disabled.border_width_top = 2
	_role_style_disabled.border_width_right = 2
	_role_style_disabled.border_width_bottom = 2
	_role_style_disabled.border_color = Color(0.8, 0.8, 0.8, 1)
	_role_style_disabled.corner_radius_top_left = 16
	_role_style_disabled.corner_radius_top_right = 16
	_role_style_disabled.corner_radius_bottom_right = 16
	_role_style_disabled.corner_radius_bottom_left = 16

	# Кнопка поиска — обычная
	_search_style_normal = StyleBoxFlat.new()
	_search_style_normal.bg_color = COLOR_WHITE
	_search_style_normal.border_width_left = 2
	_search_style_normal.border_width_top = 2
	_search_style_normal.border_width_right = 2
	_search_style_normal.border_width_bottom = 2
	_search_style_normal.border_color = COLOR_BLUE
	_search_style_normal.corner_radius_top_left = 20
	_search_style_normal.corner_radius_top_right = 20
	_search_style_normal.corner_radius_bottom_right = 20
	_search_style_normal.corner_radius_bottom_left = 20

	# Кнопка поиска — hover
	_search_style_hover = StyleBoxFlat.new()
	_search_style_hover.bg_color = COLOR_BLUE
	_search_style_hover.border_width_left = 2
	_search_style_hover.border_width_top = 2
	_search_style_hover.border_width_right = 2
	_search_style_hover.border_width_bottom = 2
	_search_style_hover.border_color = COLOR_BLUE
	_search_style_hover.corner_radius_top_left = 20
	_search_style_hover.corner_radius_top_right = 20
	_search_style_hover.corner_radius_bottom_right = 20
	_search_style_hover.corner_radius_bottom_left = 20

	# Кнопка поиска — disabled
	_search_style_disabled = StyleBoxFlat.new()
	_search_style_disabled.bg_color = Color(0.95, 0.95, 0.95, 1)
	_search_style_disabled.border_width_left = 2
	_search_style_disabled.border_width_top = 2
	_search_style_disabled.border_width_right = 2
	_search_style_disabled.border_width_bottom = 2
	_search_style_disabled.border_color = Color(0.8, 0.8, 0.8, 1)
	_search_style_disabled.corner_radius_top_left = 20
	_search_style_disabled.corner_radius_top_right = 20
	_search_style_disabled.corner_radius_bottom_right = 20
	_search_style_disabled.corner_radius_bottom_left = 20

# === ПОСТРОЕНИЕ UI ===
func _build_ui():
	# Затемнение фона
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.45)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	# Окно: 600×500 по центру
	_window = PanelContainer.new()
	_window.custom_minimum_size = Vector2(600, 500)
	_window.set_anchors_preset(Control.PRESET_CENTER)
	_window.offset_left = -300
	_window.offset_top = -250
	_window.offset_right = 300
	_window.offset_bottom = 250
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
	title_label.text = tr("HR_ROLE_TITLE")
	title_label.set_anchors_preset(Control.PRESET_CENTER)
	title_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	title_label.offset_left = -150
	title_label.offset_top = -11.5
	title_label.offset_right = 150
	title_label.offset_bottom = 11.5
	title_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", COLOR_WHITE)
	title_label.add_theme_font_size_override("font_size", 16)
	if UITheme: UITheme.apply_font(title_label, "bold")
	header_panel.add_child(title_label)

	# CloseButton
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

	# === КОНТЕНТ ===
	var content_margin = MarginContainer.new()
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_left", 30)
	content_margin.add_theme_constant_override("margin_top", 25)
	content_margin.add_theme_constant_override("margin_right", 30)
	content_margin.add_theme_constant_override("margin_bottom", 25)
	main_vbox.add_child(content_margin)

	var content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 20)
	content_margin.add_child(content_vbox)

	# Подсказка
	var hint_lbl = Label.new()
	hint_lbl.text = tr("HR_ROLE_HINT")
	hint_lbl.add_theme_color_override("font_color", COLOR_DARK)
	hint_lbl.add_theme_font_size_override("font_size", 15)
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme: UITheme.apply_font(hint_lbl, "regular")
	content_vbox.add_child(hint_lbl)

	# === КНОПКИ РОЛЕЙ ===
	var roles_vbox = VBoxContainer.new()
	roles_vbox.add_theme_constant_override("separation", 12)
	content_vbox.add_child(roles_vbox)

	# Используем ключи ролей из CSV
	var role_data = [
		{ "role": "Business Analyst", "icon": "📊", "label": "HR_ROLE_BA" },
		{ "role": "Backend Developer", "icon": "💻", "label": "HR_ROLE_DEV" },
		{ "role": "QA Engineer", "icon": "🧪", "label": "HR_ROLE_QA" },
	]

	for rd in role_data:
		var btn = Button.new()
		btn.text = "%s  %s" % [rd["icon"], tr(rd["label"])]
		btn.custom_minimum_size = Vector2(0, 50)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.focus_mode = Control.FOCUS_NONE

		btn.add_theme_color_override("font_color", COLOR_BLUE)
		btn.add_theme_color_override("font_hover_color", COLOR_BLUE)
		btn.add_theme_color_override("font_pressed_color", COLOR_WHITE)
		btn.add_theme_font_size_override("font_size", 16)

		btn.add_theme_stylebox_override("normal", _role_style_normal)
		btn.add_theme_stylebox_override("hover", _role_style_hover)
		btn.add_theme_stylebox_override("pressed", _role_style_selected)

		if UITheme: UITheme.apply_font(btn, "semibold")

		btn.pressed.connect(_on_role_selected.bind(rd["role"]))
		roles_vbox.add_child(btn)
		_role_buttons.append({ "button": btn, "role": rd["role"] })

	# Время поиска (динамическое)
	_time_info_lbl = Label.new()
	_time_info_lbl.text = ""
	_time_info_lbl.add_theme_color_override("font_color", COLOR_GRAY)
	_time_info_lbl.add_theme_font_size_override("font_size", 13)
	_time_info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme: UITheme.apply_font(_time_info_lbl, "regular")
	content_vbox.add_child(_time_info_lbl)

	# Предупреждение о времени
	_time_warning_lbl = Label.new()
	_time_warning_lbl.text = ""
	_time_warning_lbl.add_theme_color_override("font_color", COLOR_RED)
	_time_warning_lbl.add_theme_font_size_override("font_size", 13)
	_time_warning_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme: UITheme.apply_font(_time_warning_lbl, "semibold")
	_time_warning_lbl.visible = false
	content_vbox.add_child(_time_warning_lbl)

	# === КНОПКА ПОИСКА ===
	var btn_center = HBoxContainer.new()
	btn_center.alignment = BoxContainer.ALIGNMENT_CENTER
	content_vbox.add_child(btn_center)

	_search_btn = Button.new()
	_search_btn.text = tr("HR_ROLE_BTN_SEARCH")
	_search_btn.custom_minimum_size = Vector2(250, 48)
	_search_btn.focus_mode = Control.FOCUS_NONE
	_search_btn.disabled = true

	_search_btn.add_theme_color_override("font_color", COLOR_BLUE)
	_search_btn.add_theme_color_override("font_hover_color", COLOR_WHITE)
	_search_btn.add_theme_color_override("font_pressed_color", COLOR_WHITE)
	_search_btn.add_theme_color_override("font_disabled_color", Color(0.6, 0.6, 0.6, 1))
	_search_btn.add_theme_font_size_override("font_size", 16)

	_search_btn.add_theme_stylebox_override("normal", _search_style_normal)
	_search_btn.add_theme_stylebox_override("hover", _search_style_hover)
	_search_btn.add_theme_stylebox_override("pressed", _search_style_hover)
	_search_btn.add_theme_stylebox_override("disabled", _search_style_disabled)

	if UITheme: UITheme.apply_font(_search_btn, "bold")
	_search_btn.pressed.connect(_on_search_pressed)
	btn_center.add_child(_search_btn)

# === ОБНОВЛЕНИЕ ТЕКСТА ВРЕМЕНИ ПОИСКА ===
func _update_time_info():
	if _time_info_lbl:
		var search_minutes = int(PMData.get_hr_search_minutes())
		var hours = search_minutes / 60
		var mins = search_minutes % 60
		
		# Если есть и часы, и минуты (например, 1 ч 30 мин)
		if hours > 0 and mins > 0:
			# Используем массив для передачи двух параметров в локализацию
			_time_info_lbl.text = tr("HR_ROLE_TIME_H_M") % [hours, mins]
		elif hours > 0:
			_time_info_lbl.text = tr("HR_ROLE_TIME_H") % hours
		else:
			_time_info_lbl.text = tr("HR_ROLE_TIME_M") % mins

# === ВЫБОР РОЛИ ===
func _on_role_selected(role: String):
	_selected_role = role
	_update_role_buttons_visual()
	_update_search_button()

func _update_role_buttons_visual():
	for rd in _role_buttons:
		var btn: Button = rd["button"]
		if rd["role"] == _selected_role:
			btn.add_theme_stylebox_override("normal", _role_style_selected)
			btn.add_theme_stylebox_override("hover", _role_style_selected)
			btn.add_theme_color_override("font_color", COLOR_BLUE)
		else:
			btn.add_theme_stylebox_override("normal", _role_style_normal)
			btn.add_theme_stylebox_override("hover", _role_style_hover)
			btn.add_theme_color_override("font_color", COLOR_BLUE)

func _update_search_button():
	var is_late = _is_too_late()
	var no_role = _selected_role == ""

	_search_btn.disabled = no_role or is_late

	if is_late:
		_search_btn.text = tr("HR_ROLE_BTN_LATE")
	else:
		_search_btn.text = tr("HR_ROLE_BTN_SEARCH")

func _update_time_warning():
	if _is_too_late():
		var cutoff = PMData.get_hr_cutoff_hour()
		_time_warning_lbl.text = tr("HR_ROLE_WARN_LATE") % cutoff
		_time_warning_lbl.visible = true
	else:
		_time_warning_lbl.visible = false

# === НАЧАТЬ ПОИСК ===
func _on_search_pressed():
	if _selected_role == "":
		return
	if not TutorialManager.is_active() and _is_too_late():
		return

	print("🔍 HR: Начинаем поиск — %s" % _selected_role)

	_close_forced()
	emit_signal("search_started", _selected_role)
