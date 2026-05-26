extends Control

# === ГЛАВНОЕ МЕНЮ ===
# Стильное меню с анимациями, в стиле всей игры (Inter, закруглённые кнопки, тени)

const SETTINGS_PATH = "user://settings.json"

# Цвета в стил игры
const COLOR_PRIMARY = Color(0.17254902, 0.30980393, 0.5686275, 1)  # Синий как в bottom_bar
const COLOR_PRIMARY_LIGHT = Color(0.25, 0.42, 0.72, 1)
const COLOR_ACCENT = Color(0.29803923, 0.6862745, 0.3137255, 1)    # Зелёный как end_day_button
const COLOR_ACCENT_HOVER = Color(0.35, 0.78, 0.38, 1)
const COLOR_DANGER = Color(0.85, 0.25, 0.25, 1)
const COLOR_DANGER_HOVER = Color(0.95, 0.35, 0.35, 1)
const COLOR_TEXT_DARK = Color(0.15, 0.15, 0.2, 1)
const COLOR_TEXT_MUTED = Color(0.45, 0.45, 0.55, 1)
const COLOR_BG = Color(0.94, 0.95, 0.97, 1)
const COLOR_CARD_BG = Color(1, 1, 1, 1)
const COLOR_CARD_BORDER = Color(0.878, 0.878, 0.878, 1)

const FEEDBACK_URL = "https://docs.google.com/forms/d/e/1FAIpQLScJEYPwfORRPnHlUCbXGVaSmexOCftMgsQkWQtM8NW6lCPpJw/viewform?usp=dialog"

# Ноды
var _bg: ColorRect
var _particles_container: Control
var _center_card: PanelContainer
var _title_label: Label
var _subtitle_label: Label
var _btn_continue: Button
var _btn_new_game: Button
var _btn_load_game: Button
var _btn_settings: Button
var _btn_feedback: Button
var _btn_quit: Button
var _version_label: Label

var _feedback_tween: Tween

# Настройки
var _settings_panel: PanelContainer
var _settings_visible: bool = false
var _lang_option: OptionButton
var _window_option: OptionButton
var _music_slider: HSlider
var _sfx_slider: HSlider

# Флаг загрузки
var _loading_save: bool = false

# === ПАНЕЛЬ ВЫБОРА СЛОТА ===
var _slot_panel_dim: ColorRect
var _slot_panel: PanelContainer
var _slot_mode: String = ""  # "new_game" или "load_game"
var _slot_cards: Array = []  # массив PanelContainer для каждого слота

# === ДИАЛОГ ПОДТВЕРЖДЕНИЯ ===
var _confirm_dim: ColorRect
var _confirm_panel: PanelContainer
var _confirm_slot: int = 0
var _confirm_mode: String = ""  # "overwrite" или "delete"

# === ПОПАП ОШИБКИ СОХРАНЕНИЯ ===
var _error_dim: ColorRect
var _error_panel: PanelContainer

# Анимационные иконки (плавающие эмодзи офиса)
var _floating_icons: Array = []
const FLOATING_EMOJIS = ["💼", "📊", "🏢", "📋", "💻", "☕", "📁", "🖥️", "📈", "🤝", "⏰", "📝"]

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Останавливаем игровое время
	GameTime.is_game_paused = true
	Engine.time_scale = 1.0

	SaveManager.save_incompatible.connect(_on_save_incompatible)

	_load_settings()
	_build_ui()
	_animate_entrance()

func _build_ui():
	set_anchors_preset(PRESET_FULL_RECT)

	# === ФОН: градиент через два ColorRect ===
	_bg = ColorRect.new()
	_bg.set_anchors_preset(PRESET_FULL_RECT)
	_bg.color = COLOR_BG
	add_child(_bg)

	# Декоративный градиент сверху (тёмно-синяя полоса)
	var top_gradient = ColorRect.new()
	top_gradient.set_anchors_preset(PRESET_TOP_WIDE)
	top_gradient.custom_minimum_size = Vector2(0, 340)
	top_gradient.color = COLOR_PRIMARY
	add_child(top_gradient)

	# Закруглённый край градиента (имитация через Panel)
	var gradient_bottom = PanelContainer.new()
	gradient_bottom.set_anchors_preset(PRESET_TOP_WIDE)
	gradient_bottom.offset_top = 300
	gradient_bottom.custom_minimum_size = Vector2(0, 80)
	var gb_style = StyleBoxFlat.new()
	gb_style.bg_color = COLOR_PRIMARY
	gb_style.corner_radius_bottom_left = 60
	gb_style.corner_radius_bottom_right = 60
	gradient_bottom.add_theme_stylebox_override("panel", gb_style)
	add_child(gradient_bottom)

	# === ПЛАВАЮЩИЕ ИКОНКИ ===
	_particles_container = Control.new()
	_particles_container.set_anchors_preset(PRESET_FULL_RECT)
	_particles_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_particles_container)
	_spawn_floating_icons()

	# === ЦЕНТРАЛЬНАЯ КАРТОЧКА ===
	_center_card = PanelContainer.new()
	_center_card.set_anchors_preset(PRESET_CENTER)
	_center_card.custom_minimum_size = Vector2(460, 0)
	_center_card.offset_left = -230
	_center_card.offset_right = 230
	_center_card.offset_top = -240
	_center_card.offset_bottom = 280

	var card_style = StyleBoxFlat.new()
	card_style.bg_color = COLOR_CARD_BG
	card_style.border_width_left = 1
	card_style.border_width_top = 1
	card_style.border_width_right = 1
	card_style.border_width_bottom = 1
	card_style.border_color = COLOR_CARD_BORDER
	card_style.corner_radius_top_left = 24
	card_style.corner_radius_top_right = 24
	card_style.corner_radius_bottom_right = 24
	card_style.corner_radius_bottom_left = 24
	card_style.shadow_color = Color(0, 0, 0, 0.15)
	card_style.shadow_size = 20
	card_style.shadow_offset = Vector2(0, 8)
	card_style.content_margin_left = 40
	card_style.content_margin_right = 40
	card_style.content_margin_top = 40
	card_style.content_margin_bottom = 40
	_center_card.add_theme_stylebox_override("panel", card_style)
	add_child(_center_card)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_center_card.add_child(vbox)

	# === ЭМОДЗИ-ИКОНКА ===
	var icon_label = Label.new()
	icon_label.text = "🏢"
	icon_label.add_theme_font_size_override("font_size", 52)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(icon_label)

	# === ЗАГОЛОВОК ===
	_title_label = Label.new()
	_title_label.text = "Project Manager SIM"
	_title_label.add_theme_font_size_override("font_size", 34)
	_title_label.add_theme_color_override("font_color", COLOR_PRIMARY)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme:
		UITheme.apply_font(_title_label, "bold")
	vbox.add_child(_title_label)

	# === ПОДЗАГОЛОВОК ===
	_subtitle_label = Label.new()
	_subtitle_label.text = tr("MENU_SUBTITLE")
	_subtitle_label.add_theme_font_size_override("font_size", 15)
	_subtitle_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme:
		UITheme.apply_font(_subtitle_label, "regular")
	vbox.add_child(_subtitle_label)

	# Разделитель
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer1)

	# === КНОПКА "ПРОДОЛЖИТЬ" ===
	_btn_continue = _create_menu_button(tr("MENU_CONTINUE"), COLOR_ACCENT, COLOR_ACCENT_HOVER, Color.WHITE, "▶  ")
	_btn_continue.pressed.connect(_on_continue_pressed)
	vbox.add_child(_btn_continue)

	# Показываем только если есть сохранение
	_btn_continue.visible = SaveManager.has_any_save()

	# === КНОПКА "НОВАЯ ИГРА" ===
	_btn_new_game = _create_menu_button(tr("MENU_NEW_GAME"), COLOR_PRIMARY, COLOR_PRIMARY_LIGHT, Color.WHITE, "🆕  ")
	_btn_new_game.pressed.connect(_on_new_game_pressed)
	vbox.add_child(_btn_new_game)

	# === КНОПКА "ЗАГРУЗИТЬ ИГРУ" ===
	_btn_load_game = _create_menu_button(tr("MENU_LOAD_GAME"), COLOR_PRIMARY, COLOR_PRIMARY_LIGHT, Color.WHITE, "📂  ")
	_btn_load_game.pressed.connect(_on_load_game_pressed)
	vbox.add_child(_btn_load_game)
	_btn_load_game.visible = SaveManager.has_any_save()

	# === КНОПКА "НАСТРОЙКИ" ===
	_btn_settings = _create_menu_button_outline(tr("MENU_SETTINGS"), COLOR_PRIMARY, "⚙  ")
	_btn_settings.pressed.connect(_on_settings_pressed)
	vbox.add_child(_btn_settings)

	# === КНОПКА "ФИДБЕК" ===
	_btn_feedback = _create_menu_button_outline(tr("MENU_FEEDBACK"), COLOR_PRIMARY, "📝  ")
	_btn_feedback.pressed.connect(func(): OS.shell_open(FEEDBACK_URL))
	vbox.add_child(_btn_feedback)
	_start_feedback_pulse()

	# === КНОПКА "ВЫХОД" ===
	_btn_quit = _create_menu_button_outline(tr("MENU_QUIT"), COLOR_DANGER, "✕  ")
	_btn_quit.pressed.connect(_on_quit_pressed)
	vbox.add_child(_btn_quit)

	# === ВЕРСИЯ ===
	_version_label = Label.new()
	_version_label.text = "v0.44 alpha"
	_version_label.add_theme_font_size_override("font_size", 12)
	_version_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 0.7))
	_version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme:
		UITheme.apply_font(_version_label, "regular")
	vbox.add_child(_version_label)

	# === ПАНЕЛЬ НАСТРОЕК (оверлей) ===
	_build_settings_panel()

	# === ПАНЕЛЬ ВЫБОРА СЛОТА (оверлей) ===
	_build_slot_panel()

	# === ДИАЛОГ ПОДТВЕРЖДЕНИЯ ===
	_build_confirm_dialog()

	# === ПОПАП ОШИБКИ СОХРАНЕНИЯ ===
	_build_error_popup()

# === СОЗДАНИЕ КНОПОК ===

func _start_feedback_pulse():
	if _feedback_tween:
		_feedback_tween.kill()
	_feedback_tween = create_tween()
	_feedback_tween.set_loops()
	_feedback_tween.tween_property(_btn_feedback, "modulate:a", 0.6, 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_feedback_tween.tween_property(_btn_feedback, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _create_menu_button(text: String, bg_color: Color, hover_color: Color, text_color: Color, prefix: String = "") -> Button:
	var btn = Button.new()
	btn.text = prefix + text
	btn.custom_minimum_size = Vector2(380, 52)
	btn.focus_mode = Control.FOCUS_NONE

	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = bg_color
	style_normal.corner_radius_top_left = 14
	style_normal.corner_radius_top_right = 14
	style_normal.corner_radius_bottom_right = 14
	style_normal.corner_radius_bottom_left = 14
	style_normal.shadow_color = Color(bg_color.r, bg_color.g, bg_color.b, 0.3)
	style_normal.shadow_size = 6
	style_normal.shadow_offset = Vector2(0, 3)

	var style_hover = style_normal.duplicate()
	style_hover.bg_color = hover_color
	style_hover.shadow_size = 10
	style_hover.shadow_offset = Vector2(0, 5)

	var style_pressed = style_normal.duplicate()
	style_pressed.bg_color = bg_color.darkened(0.15)
	style_pressed.shadow_size = 2
	style_pressed.shadow_offset = Vector2(0, 1)

	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	btn.add_theme_color_override("font_color", text_color)
	btn.add_theme_color_override("font_hover_color", text_color)
	btn.add_theme_color_override("font_pressed_color", text_color)
	btn.add_theme_font_size_override("font_size", 17)
	if UITheme:
		UITheme.apply_font(btn, "semibold")

	return btn

func _create_menu_button_outline(text: String, accent_color: Color, prefix: String = "") -> Button:
	var btn = Button.new()
	btn.text = prefix + text
	btn.custom_minimum_size = Vector2(380, 48)
	btn.focus_mode = Control.FOCUS_NONE

	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color.WHITE
	style_normal.border_width_left = 2
	style_normal.border_width_top = 2
	style_normal.border_width_right = 2
	style_normal.border_width_bottom = 2
	style_normal.border_color = accent_color.lightened(0.3)
	style_normal.corner_radius_top_left = 14
	style_normal.corner_radius_top_right = 14
	style_normal.corner_radius_bottom_right = 14
	style_normal.corner_radius_bottom_left = 14

	var style_hover = style_normal.duplicate()
	style_hover.bg_color = accent_color
	style_hover.border_color = accent_color

	var style_pressed = style_normal.duplicate()
	style_pressed.bg_color = accent_color.darkened(0.1)
	style_pressed.border_color = accent_color.darkened(0.1)

	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	btn.add_theme_color_override("font_color", accent_color)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 16)
	if UITheme:
		UITheme.apply_font(btn, "semibold")

	return btn

# === ПЛАВАЮЩИЕ ИКОНКИ (декоративный фон) ===

func _spawn_floating_icons():
	for i in range(14):
		var lbl = Label.new()
		lbl.text = FLOATING_EMOJIS[i % FLOATING_EMOJIS.size()]
		lbl.add_theme_font_size_override("font_size", randi_range(20, 38))
		lbl.modulate.a = randf_range(0.06, 0.15)
		lbl.position = Vector2(randf_range(50, 1870), randf_range(50, 1030))
		lbl.rotation = randf_range(-0.3, 0.3)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_particles_container.add_child(lbl)
		_floating_icons.append({"node": lbl, "speed": randf_range(8, 25), "drift": randf_range(-10, 10)})

func _process(delta):
	# Лёгкое плавание иконок вверх
	for icon_data in _floating_icons:
		var node = icon_data["node"] as Label
		node.position.y -= icon_data["speed"] * delta
		node.position.x += icon_data["drift"] * delta
		# Если улетела за верхний край — возвращаем вниз
		if node.position.y < -50:
			node.position.y = 1100
			node.position.x = randf_range(50, 1870)

# === АНИМАЦИЯ ВХОДА ===

func _animate_entrance():
	# Карточка влетает снизу + fade
	_center_card.modulate.a = 0.0
	_center_card.offset_top += 60
	_center_card.offset_bottom += 60

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(_center_card, "modulate:a", 1.0, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_center_card, "offset_top", _center_card.offset_top - 60, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_center_card, "offset_bottom", _center_card.offset_bottom - 60, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

# === ПАНЕЛЬ НАСТРОЕК ===

func _build_settings_panel():
	# Затемнение фона
	var dim = ColorRect.new()
	dim.name = "SettingsDim"
	dim.set_anchors_preset(PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.4)
	dim.visible = false
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_settings_panel = PanelContainer.new()
	_settings_panel.name = "SettingsPanel"
	_settings_panel.set_anchors_preset(PRESET_CENTER)
	_settings_panel.custom_minimum_size = Vector2(420, 0)
	_settings_panel.offset_left = -210
	_settings_panel.offset_right = 210
	_settings_panel.offset_top = -180
	_settings_panel.offset_bottom = 180

	var s_style = StyleBoxFlat.new()
	s_style.bg_color = Color.WHITE
	s_style.corner_radius_top_left = 20
	s_style.corner_radius_top_right = 20
	s_style.corner_radius_bottom_right = 20
	s_style.corner_radius_bottom_left = 20
	s_style.shadow_color = Color(0, 0, 0, 0.2)
	s_style.shadow_size = 16
	s_style.shadow_offset = Vector2(0, 6)
	s_style.content_margin_left = 32
	s_style.content_margin_right = 32
	s_style.content_margin_top = 28
	s_style.content_margin_bottom = 28
	_settings_panel.add_theme_stylebox_override("panel", s_style)
	_settings_panel.visible = false
	add_child(_settings_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	_settings_panel.add_child(vbox)

	# Заголовок
	var title = Label.new()
	title.text = "⚙  " + tr("MENU_SETTINGS")
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", COLOR_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme:
		UITheme.apply_font(title, "bold")
	vbox.add_child(title)

	# --- Язык ---
	var lang_hbox = HBoxContainer.new()
	lang_hbox.add_theme_constant_override("separation", 12)

	var lang_label = Label.new()
	lang_label.text = tr("MENU_LANGUAGE")
	lang_label.add_theme_font_size_override("font_size", 15)
	lang_label.add_theme_color_override("font_color", COLOR_TEXT_DARK)
	lang_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if UITheme:
		UITheme.apply_font(lang_label, "semibold")
	lang_hbox.add_child(lang_label)

	_lang_option = OptionButton.new()
	_lang_option.add_item("Русский", 0)
	_lang_option.add_item("English", 1)
	_lang_option.custom_minimum_size = Vector2(160, 36)
	_lang_option.add_theme_font_size_override("font_size", 14)
	if UITheme:
		UITheme.apply_font(_lang_option, "regular")

	# Выбираем текущий язык
	var current_locale = TranslationServer.get_locale()
	if current_locale.begins_with("en"):
		_lang_option.select(1)
	else:
		_lang_option.select(0)

	_lang_option.item_selected.connect(_on_language_changed)
	lang_hbox.add_child(_lang_option)
	vbox.add_child(lang_hbox)

	# --- Режим окна ---
	var win_hbox = HBoxContainer.new()
	win_hbox.add_theme_constant_override("separation", 12)

	var win_label = Label.new()
	win_label.text = tr("MENU_WINDOW_MODE")
	win_label.add_theme_font_size_override("font_size", 15)
	win_label.add_theme_color_override("font_color", COLOR_TEXT_DARK)
	win_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if UITheme:
		UITheme.apply_font(win_label, "semibold")
	win_hbox.add_child(win_label)

	_window_option = OptionButton.new()
	_window_option.add_item(tr("WINDOW_MODE_WINDOWED"), 0)
	_window_option.add_item(tr("WINDOW_MODE_FULLSCREEN"), 1)
	_window_option.custom_minimum_size = Vector2(160, 36)
	_window_option.add_theme_font_size_override("font_size", 14)
	if UITheme:
		UITheme.apply_font(_window_option, "regular")
	_window_option.item_selected.connect(_on_window_mode_changed)

	# Выбираем текущий режим окна
	var current_mode = DisplayServer.window_get_mode()
	if current_mode == DisplayServer.WINDOW_MODE_WINDOWED:
		_window_option.select(0)
	else:
		_window_option.select(1)

	win_hbox.add_child(_window_option)
	vbox.add_child(win_hbox)

	# --- Громкость музыки ---
	vbox.add_child(_create_slider_row(tr("MENU_MUSIC_VOLUME"), AudioManager.music_volume, func(val): _on_music_volume_changed(val)))

	# --- Громкость эффектов ---
	vbox.add_child(_create_slider_row(tr("MENU_SFX_VOLUME"), AudioManager.sfx_volume, func(val): _on_sfx_volume_changed(val)))

	# Разделитель
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(spacer)

	# Кнопка "Назад"
	var btn_back = _create_menu_button_outline(tr("MENU_BACK"), COLOR_PRIMARY, "←  ")
	btn_back.custom_minimum_size.x = 0
	btn_back.pressed.connect(_on_settings_back)
	vbox.add_child(btn_back)

func _create_slider_row(label_text: String, initial_value: float, callback: Callable) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)

	var label = Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", COLOR_TEXT_DARK)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if UITheme:
		UITheme.apply_font(label, "semibold")
	hbox.add_child(label)

	var slider = HSlider.new()
	slider.custom_minimum_size = Vector2(160, 24)
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = initial_value
	slider.value_changed.connect(callback)
	hbox.add_child(slider)

	var val_label = Label.new()
	val_label.text = "%d%%" % int(initial_value * 100)
	val_label.add_theme_font_size_override("font_size", 13)
	val_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	val_label.custom_minimum_size = Vector2(45, 0)
	if UITheme:
		UITheme.apply_font(val_label, "regular")
	hbox.add_child(val_label)

	# Обновлять % при изменении
	slider.value_changed.connect(func(val): val_label.text = "%d%%" % int(val * 100))

	return hbox

# === ОБРАБОТЧИКИ КНОПОК ===

func _on_continue_pressed():
	if _loading_save:
		return
	_loading_save = true

	_btn_continue.text = "⏳  " + tr("MENU_LOADING")
	_btn_continue.disabled = true

	var last_slot = SaveManager.get_last_slot()
	# If meta is missing but saves exist, find first available slot
	if last_slot == 0:
		for i in range(1, 4):
			if SaveManager.has_save_in_slot(i):
				last_slot = i
				break
	if last_slot == 0:
		# No valid save found
		_btn_continue.text = "▶  " + tr("MENU_CONTINUE")
		_btn_continue.disabled = false
		_loading_save = false
		return
	LoadingScreen.pending_save_slot = last_slot
	get_tree().change_scene_to_file("res://Scenes/loading_screen.tscn")

func _on_new_game_pressed():
	_slot_mode = "new_game"
	_open_slot_panel()

func _on_load_game_pressed():
	_slot_mode = "load_game"
	_open_slot_panel()

func _on_settings_pressed():
	var dim = get_node_or_null("SettingsDim")
	if dim:
		dim.visible = true
	_settings_panel.visible = true
	_settings_panel.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(_settings_panel, "modulate:a", 1.0, 0.25).set_ease(Tween.EASE_OUT)
	_settings_visible = true

func _on_settings_back():
	_save_settings()
	var tween = create_tween()
	tween.tween_property(_settings_panel, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		_settings_panel.visible = false
		var dim = get_node_or_null("SettingsDim")
		if dim:
			dim.visible = false
	)
	_settings_visible = false

func _on_quit_pressed():
	get_tree().quit()

# === НАСТРОЙКИ: ЯЗЫК ===

func _on_language_changed(index: int):
	match index:
		0: TranslationServer.set_locale("ru")
		1: TranslationServer.set_locale("en")

	# Перестраиваем UI с новым языком
	_save_settings()
	# Перезагружаем сцену чтобы обновить все tr()
	get_tree().reload_current_scene()

# === НАСТРОЙКИ: РЕЖИМ ОКНА ===

func _on_window_mode_changed(index: int):
	_apply_window_mode(index)
	_save_settings()

func _apply_window_mode(index: int):
	match index:
		0:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(Vector2i(1280, 720))
			var screen_size = DisplayServer.screen_get_size()
			var win_size = DisplayServer.window_get_size()
			DisplayServer.window_set_position(Vector2i((screen_size.x - win_size.x) / 2, (screen_size.y - win_size.y) / 2))
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

# === НАСТРОЙКИ: ЗВУК ===

func _on_music_volume_changed(val: float):
	AudioManager.set_music_volume(val)

func _on_sfx_volume_changed(val: float):
	AudioManager.set_sfx_volume(val)

# === СБРОС СИНГЛТОНОВ ===

func _reset_all_singletons():
	# GameTime
	GameTime.day = 1
	GameTime.hour = 9
	GameTime.minute = 0
	GameTime.time_accumulator = 0.0
	GameTime.current_speed_scale = 1.0
	GameTime.is_game_paused = false
	GameTime.is_night_skip = false

	# GameState
	GameState.company_balance = 10000
	GameState.appearance_configured = false
	GameState.balance_at_day_start = 10000
	GameState.daily_income = 0
	GameState.daily_expenses = 0
	GameState.daily_salary_details.clear()
	GameState.daily_service_details.clear()
	GameState.daily_income_details.clear()
	GameState.daily_event_expenses.clear()
	GameState._last_reset_day = 0
	GameState.projects_finished_today.clear()
	GameState.projects_failed_today.clear()
	GameState.levelups_today.clear()
	GameState.reputation_changes_today.clear()
	GameState.office_upgrades = {
		"coffee_machine": false,
		"kitchen": false,
		"desk_count": 3,
		# Passive services
		"legal_consultant": false,
		"project_management_soft": false,
		"dev_tools": false,
		"corporate_psychologist": false,
		"corporate_dms": false,
		"hr_specialist": false,
		# One-time purchases
		"ergonomic_furniture": false,
		"corporate_library": false,
	}

	# PMData
	PMData.xp = 0
	PMData.skill_points = 0
	PMData._last_threshold_index = -1
	PMData.unlocked_skills.clear()
	PMData.personal_balance = 0
	PMData.monthly_salary = 1000
	PMData.partner_tier = 0
	PMData.appearance_gender = "male"
	PMData.appearance_body_type = "default"
	PMData.appearance_skin_color = Color("#FFE0BD")
	PMData.appearance_hair_type = 0
	PMData.appearance_hair_color = Color("#C8A882")
	PMData.appearance_clothing_color = Color("#A0C4FF")
	PMData.pm_traits.clear()

	# BossManager
	BossManager.boss_trust = 0
	BossManager.quest_active = false
	BossManager.current_quest = {}
	BossManager.quest_history.clear()
	BossManager.monthly_income = 0
	BossManager.monthly_expenses = 0
	BossManager.monthly_projects_finished = 0
	BossManager.monthly_projects_failed = 0
	BossManager.monthly_hires = 0
	BossManager.monthly_employee_levelups = 0
	BossManager._current_month = 1
	BossManager._quest_shown_this_month = false
	BossManager._report_shown_this_month = false

	# ClientManager — переинициализация клиентов
	ClientManager._init_clients()
	ClientManager.reputation_points = 0
	ClientManager.global_reputation = 0

	# ProjectManager
	ProjectManager.active_projects.clear()
	ProjectManager.completed_projects.clear()
	
	# Tutorial
	GameState.tutorial_completed = false
	TutorialManager.current_step = TutorialManager.Step.NONE
	TutorialManager._tutorial_project = null
	TutorialManager._tutorial_candidate = null
	TutorialManager.shown_hints.clear()

	# === EVENT SYSTEM: Сброс ивент-системы ===
	var em = get_node_or_null("/root/EventManager")
	if em:
		em.active_effects.clear()
		em.employee_cooldowns.clear()
		em.last_event_day = 0
		em.last_sick_day = -100
		em.last_dayoff_day = -100

	# FinancialHistory
	var fh = get_node_or_null("/root/FinancialHistory")
	if fh:
		fh.daily_records.clear()

	# PeopleHistory
	var ph = get_node_or_null("/root/PeopleHistory")
	if ph:
		ph.daily_records.clear()

# === СОХРАНЕНИЕ / ЗАГРУЗКА НАСТРОЕК ===

func _save_settings():
	var data = {
		"locale": TranslationServer.get_locale(),
		"music_volume": AudioManager.music_volume,
		"sfx_volume": AudioManager.sfx_volume,
		"master_volume": AudioManager.master_volume,
		"window_mode": _window_option.selected if _window_option else 1,
	}
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

func _load_settings():
	if not FileAccess.file_exists(SETTINGS_PATH):
		# --- АВТООПРЕДЕЛЕНИЕ ЯЗЫКА ПРИ ПЕРВОМ ЗАПУСКЕ ---
		var os_lang = OS.get_locale_language()
		if os_lang == "ru":
			TranslationServer.set_locale("ru")
		else:
			TranslationServer.set_locale("en")
		return
		
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if not file:
		return
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	var data = json.data
	if not data is Dictionary:
		return

	# Язык
	var locale = data.get("locale", "ru")
	TranslationServer.set_locale(locale)

	# Звук
	AudioManager.set_music_volume(float(data.get("music_volume", 0.2)))
	AudioManager.set_sfx_volume(float(data.get("sfx_volume", 0.8)))
	AudioManager.set_master_volume(float(data.get("master_volume", 1.0)))

	# Режим окна
	var win_mode = int(data.get("window_mode", 1))
	if win_mode > 1:
		win_mode = 1  # Migrate any legacy/invalid window mode value to fullscreen
	_apply_window_mode(win_mode)

# ============================================================
# === ПАНЕЛЬ ВЫБОРА СЛОТА ===
# ============================================================

func _build_slot_panel():
	# Затемнение
	_slot_panel_dim = ColorRect.new()
	_slot_panel_dim.name = "SlotPanelDim"
	_slot_panel_dim.set_anchors_preset(PRESET_FULL_RECT)
	_slot_panel_dim.color = Color(0, 0, 0, 0.5)
	_slot_panel_dim.visible = false
	_slot_panel_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_slot_panel_dim)

	# Белая карточка
	_slot_panel = PanelContainer.new()
	_slot_panel.name = "SlotPanel"
	_slot_panel.set_anchors_preset(PRESET_CENTER)
	_slot_panel.custom_minimum_size = Vector2(480, 0)
	_slot_panel.offset_left = -240
	_slot_panel.offset_right = 240
	_slot_panel.offset_top = -300
	_slot_panel.offset_bottom = 300

	var s_style = StyleBoxFlat.new()
	s_style.bg_color = Color.WHITE
	s_style.corner_radius_top_left = 20
	s_style.corner_radius_top_right = 20
	s_style.corner_radius_bottom_right = 20
	s_style.corner_radius_bottom_left = 20
	s_style.shadow_color = Color(0, 0, 0, 0.2)
	s_style.shadow_size = 20
	s_style.shadow_offset = Vector2(0, 8)
	s_style.content_margin_left = 32
	s_style.content_margin_right = 32
	s_style.content_margin_top = 28
	s_style.content_margin_bottom = 28
	_slot_panel.add_theme_stylebox_override("panel", s_style)
	_slot_panel.visible = false
	add_child(_slot_panel)

	var vbox = VBoxContainer.new()
	vbox.name = "SlotVBox"
	vbox.add_theme_constant_override("separation", 14)
	_slot_panel.add_child(vbox)

	# Заголовок
	var title = Label.new()
	title.name = "SlotTitle"
	title.text = tr("SLOT_SELECT_TITLE")
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", COLOR_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme:
		UITheme.apply_font(title, "bold")
	vbox.add_child(title)

	# 3 карточки слотов
	_slot_cards = []
	for i in range(1, 4):
		var card = _build_slot_card(i)
		vbox.add_child(card)
		_slot_cards.append(card)

	# Кнопка "Назад"
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(spacer)

	var btn_back = _create_menu_button_outline(tr("MENU_BACK"), COLOR_PRIMARY, "←  ")
	btn_back.custom_minimum_size.x = 0
	btn_back.pressed.connect(_close_slot_panel)
	vbox.add_child(btn_back)

func _build_slot_card(slot: int) -> PanelContainer:
	var card = PanelContainer.new()
	card.name = "SlotCard%d" % slot

	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.96, 0.97, 0.99, 1)
	card_style.border_width_left = 2
	card_style.border_width_top = 2
	card_style.border_width_right = 2
	card_style.border_width_bottom = 2
	card_style.border_color = COLOR_CARD_BORDER
	card_style.corner_radius_top_left = 14
	card_style.corner_radius_top_right = 14
	card_style.corner_radius_bottom_right = 14
	card_style.corner_radius_bottom_left = 14
	card_style.content_margin_left = 16
	card_style.content_margin_right = 16
	card_style.content_margin_top = 12
	card_style.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", card_style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	card.add_child(hbox)

	# Левая колонка: инфо
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(info_vbox)

	# Правая колонка: кнопки
	var btn_vbox = VBoxContainer.new()
	btn_vbox.add_theme_constant_override("separation", 6)
	btn_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(btn_vbox)

	_refresh_slot_card_info(slot, info_vbox, btn_vbox)

	return card

func _refresh_slot_card_info(slot: int, info_vbox: VBoxContainer, btn_vbox: VBoxContainer):
	# Очищаем
	for c in info_vbox.get_children():
		c.queue_free()
	for c in btn_vbox.get_children():
		c.queue_free()

	var has_save = SaveManager.has_save_in_slot(slot)
	var slot_meta = SaveManager.get_slot_meta(slot)

	# Заголовок слота
	var slot_title = Label.new()
	slot_title.text = tr("SLOT_NUMBER") % slot
	slot_title.add_theme_font_size_override("font_size", 15)
	slot_title.add_theme_color_override("font_color", COLOR_PRIMARY)
	if UITheme:
		UITheme.apply_font(slot_title, "bold")
	info_vbox.add_child(slot_title)

	if has_save and slot_meta.size() > 0:
		# Дата/месяц
		var day_label = Label.new()
		var month_val = int(slot_meta.get("month", 1))
		var day_val = int(slot_meta.get("day", 1))
		day_label.text = "📅 " + tr("SLOT_DAY_INFO") % [month_val, day_val]
		day_label.add_theme_font_size_override("font_size", 13)
		day_label.add_theme_color_override("font_color", COLOR_TEXT_DARK)
		if UITheme:
			UITheme.apply_font(day_label, "regular")
		info_vbox.add_child(day_label)

		# Баланс
		var balance_label = Label.new()
		balance_label.text = "💰 " + tr("SLOT_BALANCE") % int(slot_meta.get("company_balance", 0))
		balance_label.add_theme_font_size_override("font_size", 13)
		balance_label.add_theme_color_override("font_color", COLOR_TEXT_DARK)
		if UITheme:
			UITheme.apply_font(balance_label, "regular")
		info_vbox.add_child(balance_label)

		# Дата сохранения
		var ts = str(slot_meta.get("timestamp", ""))
		if ts != "":
			var save_label = Label.new()
			# Форматируем ISO timestamp в читаемый вид (YYYY-MM-DDTHH:MM:SS → DD.MM.YYYY HH:MM)
			var formatted = _format_timestamp(ts)
			save_label.text = "🕐 " + tr("SLOT_LAST_SAVE") % formatted
			save_label.add_theme_font_size_override("font_size", 12)
			save_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
			if UITheme:
				UITheme.apply_font(save_label, "regular")
			info_vbox.add_child(save_label)
	else:
		# Пустой слот
		var empty_label = Label.new()
		empty_label.text = "➕  " + tr("SLOT_EMPTY")
		empty_label.add_theme_font_size_override("font_size", 13)
		empty_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
		if UITheme:
			UITheme.apply_font(empty_label, "regular")
		info_vbox.add_child(empty_label)

	# Кнопка выбора
	var select_btn = Button.new()
	if _slot_mode == "new_game":
		select_btn.text = "▶"
	else:
		select_btn.text = "📂"
	select_btn.custom_minimum_size = Vector2(40, 36)
	select_btn.focus_mode = Control.FOCUS_NONE
	if _slot_mode == "load_game" and not has_save:
		select_btn.disabled = true
	var style_s = StyleBoxFlat.new()
	style_s.bg_color = COLOR_ACCENT if (_slot_mode == "new_game" or has_save) else Color(0.8, 0.8, 0.85)
	style_s.corner_radius_top_left = 10
	style_s.corner_radius_top_right = 10
	style_s.corner_radius_bottom_right = 10
	style_s.corner_radius_bottom_left = 10
	select_btn.add_theme_stylebox_override("normal", style_s)
	select_btn.add_theme_color_override("font_color", Color.WHITE)
	select_btn.add_theme_font_size_override("font_size", 14)
	select_btn.pressed.connect(func(): _on_slot_selected(slot))
	btn_vbox.add_child(select_btn)

	# Кнопка удаления (только если слот занят)
	if has_save:
		var del_btn = Button.new()
		del_btn.text = "🗑"
		del_btn.custom_minimum_size = Vector2(40, 32)
		del_btn.focus_mode = Control.FOCUS_NONE
		var style_d = StyleBoxFlat.new()
		style_d.bg_color = Color.WHITE
		style_d.border_width_left = 2
		style_d.border_width_top = 2
		style_d.border_width_right = 2
		style_d.border_width_bottom = 2
		style_d.border_color = COLOR_DANGER.lightened(0.3)
		style_d.corner_radius_top_left = 10
		style_d.corner_radius_top_right = 10
		style_d.corner_radius_bottom_right = 10
		style_d.corner_radius_bottom_left = 10
		var style_d_hover = style_d.duplicate()
		style_d_hover.bg_color = COLOR_DANGER
		style_d_hover.border_color = COLOR_DANGER
		var style_d_pressed = style_d.duplicate()
		style_d_pressed.bg_color = COLOR_DANGER.darkened(0.1)
		style_d_pressed.border_color = COLOR_DANGER.darkened(0.1)
		del_btn.add_theme_stylebox_override("normal", style_d)
		del_btn.add_theme_stylebox_override("hover", style_d_hover)
		del_btn.add_theme_stylebox_override("pressed", style_d_pressed)
		del_btn.add_theme_color_override("font_color", COLOR_DANGER)
		del_btn.add_theme_color_override("font_hover_color", Color.WHITE)
		del_btn.add_theme_color_override("font_pressed_color", Color.WHITE)
		del_btn.add_theme_font_size_override("font_size", 14)
		del_btn.pressed.connect(func(): _on_slot_delete_pressed(slot))
		btn_vbox.add_child(del_btn)

func _format_timestamp(ts: String) -> String:
	# ISO: "2024-01-15T14:30:00" → locale-aware date/time
	if ts.length() >= 16:
		var date_part = ts.substr(0, 10)
		var time_part = ts.substr(11, 5)
		var parts = date_part.split("-")
		if parts.size() == 3:
			var locale = TranslationServer.get_locale()
			if locale.begins_with("en"):
				return "%s/%s/%s %s" % [parts[1], parts[2], parts[0], time_part]
			else:
				return "%s.%s.%s %s" % [parts[2], parts[1], parts[0], time_part]
	return ts

func _open_slot_panel():
	_slot_panel_dim.visible = true
	_slot_panel.visible = true
	_refresh_all_slot_cards()
	_slot_panel.modulate.a = 0.0
	create_tween().tween_property(_slot_panel, "modulate:a", 1.0, 0.2).set_ease(Tween.EASE_OUT)

func _close_slot_panel():
	var tween = create_tween()
	tween.tween_property(_slot_panel, "modulate:a", 0.0, 0.15).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		_slot_panel.visible = false
		_slot_panel_dim.visible = false
	)

func _refresh_all_slot_cards():
	# Обновляем содержимое карточек после изменений
	var vbox = _slot_panel.get_node_or_null("SlotVBox")
	if not vbox:
		return
	for i in range(1, 4):
		var card = _slot_cards[i - 1]
		if not is_instance_valid(card):
			continue
		var hbox = card.get_child(0) as HBoxContainer
		if not hbox:
			continue
		var info_vbox = hbox.get_child(0) as VBoxContainer
		var btn_vbox = hbox.get_child(1) as VBoxContainer
		if info_vbox and btn_vbox:
			_refresh_slot_card_info(i, info_vbox, btn_vbox)

func _on_slot_selected(slot: int):
	if _slot_mode == "new_game":
		if SaveManager.has_save_in_slot(slot):
			# Предупреждение о перезаписи
			_open_confirm_dialog("overwrite", slot)
		else:
			# Пустой слот — сразу начинаем
			_start_new_game_in_slot(slot)
	elif _slot_mode == "load_game":
		if SaveManager.has_save_in_slot(slot):
			_load_from_slot(slot)

func _start_new_game_in_slot(slot: int):
	SaveManager.current_slot = slot
	SaveManager.delete_save(slot)
	_reset_all_singletons()
	get_tree().change_scene_to_file("res://Scenes/intro_screen.tscn")

func _load_from_slot(slot: int):
	if _loading_save:
		return
	_loading_save = true
	LoadingScreen.pending_save_slot = slot
	get_tree().change_scene_to_file("res://Scenes/loading_screen.tscn")

func _on_slot_delete_pressed(slot: int):
	_open_confirm_dialog("delete", slot)

# ============================================================
# === ДИАЛОГ ПОДТВЕРЖДЕНИЯ ===
# ============================================================

func _build_confirm_dialog():
	_confirm_dim = ColorRect.new()
	_confirm_dim.name = "ConfirmDim"
	_confirm_dim.set_anchors_preset(PRESET_FULL_RECT)
	_confirm_dim.color = Color(0, 0, 0, 0.6)
	_confirm_dim.visible = false
	_confirm_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_confirm_dim)

	_confirm_panel = PanelContainer.new()
	_confirm_panel.name = "ConfirmPanel"
	_confirm_panel.set_anchors_preset(PRESET_CENTER)
	_confirm_panel.custom_minimum_size = Vector2(380, 0)
	_confirm_panel.offset_left = -190
	_confirm_panel.offset_right = 190
	_confirm_panel.offset_top = -120
	_confirm_panel.offset_bottom = 120

	var c_style = StyleBoxFlat.new()
	c_style.bg_color = Color.WHITE
	c_style.corner_radius_top_left = 18
	c_style.corner_radius_top_right = 18
	c_style.corner_radius_bottom_right = 18
	c_style.corner_radius_bottom_left = 18
	c_style.shadow_color = Color(0, 0, 0, 0.25)
	c_style.shadow_size = 18
	c_style.shadow_offset = Vector2(0, 6)
	c_style.content_margin_left = 28
	c_style.content_margin_right = 28
	c_style.content_margin_top = 24
	c_style.content_margin_bottom = 24
	_confirm_panel.add_theme_stylebox_override("panel", c_style)
	_confirm_panel.visible = false
	add_child(_confirm_panel)

func _open_confirm_dialog(mode: String, slot: int):
	_confirm_mode = mode
	_confirm_slot = slot

	# Очищаем предыдущее содержимое
	for c in _confirm_panel.get_children():
		_confirm_panel.remove_child(c)
		c.queue_free()
	_confirm_panel.reset_size()

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_confirm_panel.add_child(vbox)

	# Заголовок
	var title = Label.new()
	if mode == "overwrite":
		title.text = tr("SLOT_OVERWRITE_TITLE")
	else:
		title.text = tr("SLOT_DELETE_TITLE")
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", COLOR_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme:
		UITheme.apply_font(title, "bold")
	vbox.add_child(title)

	# Текст
	var body = Label.new()
	if mode == "overwrite":
		body.text = tr("SLOT_OVERWRITE_TEXT") % slot
	else:
		body.text = tr("SLOT_DELETE_TEXT") % slot
	body.add_theme_font_size_override("font_size", 14)
	body.add_theme_color_override("font_color", COLOR_TEXT_DARK)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if UITheme:
		UITheme.apply_font(body, "regular")
	vbox.add_child(body)

	# Кнопки
	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 10)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_hbox)

	var btn_cancel = Button.new()
	if mode == "overwrite":
		btn_cancel.text = tr("SLOT_OVERWRITE_CANCEL")
	else:
		btn_cancel.text = tr("SLOT_DELETE_CANCEL")
	btn_cancel.custom_minimum_size = Vector2(130, 44)
	btn_cancel.focus_mode = Control.FOCUS_NONE
	var cancel_style = StyleBoxFlat.new()
	cancel_style.bg_color = Color.WHITE
	cancel_style.border_width_left = 2
	cancel_style.border_width_top = 2
	cancel_style.border_width_right = 2
	cancel_style.border_width_bottom = 2
	cancel_style.border_color = COLOR_TEXT_MUTED
	cancel_style.corner_radius_top_left = 12
	cancel_style.corner_radius_top_right = 12
	cancel_style.corner_radius_bottom_right = 12
	cancel_style.corner_radius_bottom_left = 12
	btn_cancel.add_theme_stylebox_override("normal", cancel_style)
	btn_cancel.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	btn_cancel.add_theme_font_size_override("font_size", 14)
	if UITheme:
		UITheme.apply_font(btn_cancel, "semibold")
	btn_cancel.pressed.connect(_close_confirm_dialog)
	btn_hbox.add_child(btn_cancel)

	var btn_confirm = Button.new()
	if mode == "overwrite":
		btn_confirm.text = tr("SLOT_OVERWRITE_CONFIRM")
	else:
		btn_confirm.text = tr("SLOT_DELETE_CONFIRM")
	btn_confirm.custom_minimum_size = Vector2(130, 44)
	btn_confirm.focus_mode = Control.FOCUS_NONE
	var confirm_style = StyleBoxFlat.new()
	confirm_style.bg_color = COLOR_DANGER
	confirm_style.corner_radius_top_left = 12
	confirm_style.corner_radius_top_right = 12
	confirm_style.corner_radius_bottom_right = 12
	confirm_style.corner_radius_bottom_left = 12
	confirm_style.shadow_color = Color(COLOR_DANGER.r, COLOR_DANGER.g, COLOR_DANGER.b, 0.3)
	confirm_style.shadow_size = 5
	confirm_style.shadow_offset = Vector2(0, 2)
	btn_confirm.add_theme_stylebox_override("normal", confirm_style)
	btn_confirm.add_theme_color_override("font_color", Color.WHITE)
	btn_confirm.add_theme_font_size_override("font_size", 14)
	if UITheme:
		UITheme.apply_font(btn_confirm, "semibold")
	btn_confirm.pressed.connect(_on_confirm_action)
	btn_hbox.add_child(btn_confirm)

	_confirm_dim.visible = true
	_confirm_panel.visible = true
	_confirm_panel.modulate.a = 0.0
	create_tween().tween_property(_confirm_panel, "modulate:a", 1.0, 0.2).set_ease(Tween.EASE_OUT)

func _close_confirm_dialog():
	var tween = create_tween()
	tween.tween_property(_confirm_panel, "modulate:a", 0.0, 0.15).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		_confirm_panel.visible = false
		_confirm_dim.visible = false
	)

func _on_confirm_action():
	_close_confirm_dialog()
	if _confirm_mode == "overwrite":
		_start_new_game_in_slot(_confirm_slot)
	elif _confirm_mode == "delete":
		SaveManager.delete_save(_confirm_slot)
		_refresh_all_slot_cards()
		# Обновляем видимость кнопок главного меню
		_btn_continue.visible = SaveManager.has_any_save()
		_btn_load_game.visible = SaveManager.has_any_save()

# ============================================================
#              ПОПАП ОШИБКИ СОХРАНЕНИЯ
# ============================================================

func _build_error_popup():
	_error_dim = ColorRect.new()
	_error_dim.name = "ErrorDim"
	_error_dim.set_anchors_preset(PRESET_FULL_RECT)
	_error_dim.color = Color(0, 0, 0, 0.6)
	_error_dim.visible = false
	_error_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_error_dim)

	_error_panel = PanelContainer.new()
	_error_panel.name = "ErrorPanel"
	_error_panel.set_anchors_preset(PRESET_CENTER)
	_error_panel.custom_minimum_size = Vector2(400, 0)
	_error_panel.offset_left = -200
	_error_panel.offset_right = 200
	_error_panel.offset_top = -120
	_error_panel.offset_bottom = 120

	var e_style = StyleBoxFlat.new()
	e_style.bg_color = Color.WHITE
	e_style.corner_radius_top_left = 18
	e_style.corner_radius_top_right = 18
	e_style.corner_radius_bottom_right = 18
	e_style.corner_radius_bottom_left = 18
	e_style.shadow_color = Color(0, 0, 0, 0.25)
	e_style.shadow_size = 18
	e_style.shadow_offset = Vector2(0, 6)
	e_style.content_margin_left = 28
	e_style.content_margin_right = 28
	e_style.content_margin_top = 24
	e_style.content_margin_bottom = 24
	_error_panel.add_theme_stylebox_override("panel", e_style)
	_error_panel.visible = false
	add_child(_error_panel)

func _on_save_incompatible(slot: int, reason: String):
	# Очищаем предыдущее содержимое
	for c in _error_panel.get_children():
		_error_panel.remove_child(c)
		c.queue_free()
	_error_panel.reset_size()

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_error_panel.add_child(vbox)

	# Иконка
	var icon_label = Label.new()
	icon_label.text = "⚠️"
	icon_label.add_theme_font_size_override("font_size", 36)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(icon_label)

	# Заголовок
	var title = Label.new()
	title.text = "Слот %d — ошибка загрузки" % slot
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", COLOR_DANGER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme:
		UITheme.apply_font(title, "bold")
	vbox.add_child(title)

	# Текст причины
	var body = Label.new()
	body.text = reason
	body.add_theme_font_size_override("font_size", 14)
	body.add_theme_color_override("font_color", COLOR_TEXT_DARK)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if UITheme:
		UITheme.apply_font(body, "regular")
	vbox.add_child(body)

	# Кнопка ОК
	var btn_ok = Button.new()
	btn_ok.text = "ОК"
	btn_ok.custom_minimum_size = Vector2(130, 44)
	btn_ok.focus_mode = Control.FOCUS_NONE
	var ok_style = StyleBoxFlat.new()
	ok_style.bg_color = COLOR_PRIMARY
	ok_style.corner_radius_top_left = 12
	ok_style.corner_radius_top_right = 12
	ok_style.corner_radius_bottom_right = 12
	ok_style.corner_radius_bottom_left = 12
	ok_style.shadow_color = Color(COLOR_PRIMARY.r, COLOR_PRIMARY.g, COLOR_PRIMARY.b, 0.3)
	ok_style.shadow_size = 5
	ok_style.shadow_offset = Vector2(0, 2)
	btn_ok.add_theme_stylebox_override("normal", ok_style)
	btn_ok.add_theme_color_override("font_color", Color.WHITE)
	btn_ok.add_theme_font_size_override("font_size", 14)
	if UITheme:
		UITheme.apply_font(btn_ok, "semibold")
	btn_ok.pressed.connect(_close_error_popup)
	vbox.add_child(btn_ok)

	_error_dim.visible = true
	_error_panel.visible = true
	_error_panel.modulate.a = 0.0
	create_tween().tween_property(_error_panel, "modulate:a", 1.0, 0.2).set_ease(Tween.EASE_OUT)

func _close_error_popup():
	var tween = create_tween()
	tween.tween_property(_error_panel, "modulate:a", 0.0, 0.15).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		_error_panel.visible = false
		_error_dim.visible = false
	)
