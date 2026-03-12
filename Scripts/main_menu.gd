extends Control

# === ГЛАВНОЕ МЕНЮ ===
# Стильное меню с анимациями, в стиле всей игры (Inter, закруглённые кнопки, тени)

const SETTINGS_PATH = "user://settings.json"

# Цвета в стил�� игры
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

# Ноды
var _bg: ColorRect
var _particles_container: Control
var _center_card: PanelContainer
var _title_label: Label
var _subtitle_label: Label
var _btn_continue: Button
var _btn_new_game: Button
var _btn_settings: Button
var _btn_quit: Button
var _version_label: Label

# Настройки
var _settings_panel: PanelContainer
var _settings_visible: bool = false
var _lang_option: OptionButton
var _music_slider: HSlider
var _sfx_slider: HSlider

# Флаг загрузки
var _loading_save: bool = false

# Анимационные иконки (плавающие эмодзи офиса)
var _floating_icons: Array = []
const FLOATING_EMOJIS = ["💼", "📊", "🏢", "📋", "💻", "☕", "📁", "🖥️", "📈", "🤝", "⏰", "📝"]

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Останавливаем игровое время
	GameTime.is_game_paused = true
	Engine.time_scale = 1.0

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
	_title_label.text = "Project Manager"
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
	_btn_continue.visible = SaveManager.has_save()

	# === КНОПКА "НОВАЯ ИГРА" ===
	_btn_new_game = _create_menu_button(tr("MENU_NEW_GAME"), COLOR_PRIMARY, COLOR_PRIMARY_LIGHT, Color.WHITE, "🆕  ")
	_btn_new_game.pressed.connect(_on_new_game_pressed)
	vbox.add_child(_btn_new_game)

	# === КНОПКА "НАСТРОЙКИ" ===
	_btn_settings = _create_menu_button_outline(tr("MENU_SETTINGS"), COLOR_PRIMARY, "⚙  ")
	_btn_settings.pressed.connect(_on_settings_pressed)
	vbox.add_child(_btn_settings)

	# === КНОПКА "ВЫХОД" ===
	_btn_quit = _create_menu_button_outline(tr("MENU_QUIT"), COLOR_DANGER, "✕  ")
	_btn_quit.pressed.connect(_on_quit_pressed)
	vbox.add_child(_btn_quit)

	# === ВЕРСИЯ ===
	_version_label = Label.new()
	_version_label.text = "v0.3 alpha"
	_version_label.add_theme_font_size_override("font_size", 12)
	_version_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 0.7))
	_version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme:
		UITheme.apply_font(_version_label, "regular")
	vbox.add_child(_version_label)

	# === ПАНЕЛЬ НАСТРОЕК (оверлей) ===
	_build_settings_panel()

# === СОЗДАНИЕ КНОПОК ===

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

	var success = SaveManager.load_game()
	if success:
		get_tree().change_scene_to_file("res://Scenes/office.tscn")
	else:
		_btn_continue.text = "▶  " + tr("MENU_CONTINUE")
		_btn_continue.disabled = false
		_loading_save = false

func _on_new_game_pressed():
	# Удаляем сохранение
	SaveManager.delete_save()

	# Сбрасываем все синглтоны
	_reset_all_singletons()

	# Показываем интро-экран перед началом игры
	var intro = Control.new()
	intro.set_script(load("res://Scripts/intro_screen.gd"))
	intro.set_anchors_preset(Control.PRESET_FULL_RECT)
	intro.process_mode = Node.PROCESS_MODE_ALWAYS
	intro.z_index = 200
	add_child(intro)

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

# === НАСТРОЙКИ: ЗВУК ===

func _on_music_volume_changed(val: float):
	AudioManager.set_music_volume(val)

func _on_sfx_volume_changed(val: float):
	AudioManager.set_sfx_volume(val)

# === СБРОС СИНГЛТОНОВ ===

func _reset_all_singletons():
	# GameTime
	GameTime.day = 1
	GameTime.hour = 8
	GameTime.minute = 0
	GameTime.time_accumulator = 0.0
	GameTime.current_speed_scale = 1.0
	GameTime.is_game_paused = false
	GameTime.is_night_skip = false

	# GameState
	GameState.company_balance = 10000
	GameState.balance_at_day_start = 10000
	GameState.daily_income = 0
	GameState.daily_expenses = 0
	GameState.daily_salary_details.clear()
	GameState.projects_finished_today.clear()
	GameState.projects_failed_today.clear()
	GameState.levelups_today.clear()
	GameState.loyalty_changes_today.clear()

	# PMData
	PMData.xp = 0
	PMData.skill_points = 0
	PMData._last_threshold_index = -1
	PMData.unlocked_skills.clear()
	PMData.personal_balance = 0
	PMData.monthly_salary = 1000
	PMData.partner_tier = 0

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

	# ProjectManager
	ProjectManager.active_projects.clear()
	
	# Tutorial
	GameState.tutorial_completed = false

	# === EVENT SYSTEM: Сброс ивент-системы ===
	var em = get_node_or_null("/root/EventManager")
	if em:
		em.active_effects.clear()
		em.employee_cooldowns.clear()
		em.last_event_day = 0
		em.last_sick_day = -100
		em.last_dayoff_day = -100

# === СОХРАНЕНИЕ / ЗАГРУЗКА НАСТРОЕК ===

func _save_settings():
	var data = {
		"locale": TranslationServer.get_locale(),
		"music_volume": AudioManager.music_volume,
		"sfx_volume": AudioManager.sfx_volume,
		"master_volume": AudioManager.master_volume,
	}
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

func _load_settings():
	if not FileAccess.file_exists(SETTINGS_PATH):
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
