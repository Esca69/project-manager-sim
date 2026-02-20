extends CanvasLayer

# === ПАУЗ-МЕНЮ (Escape) ===
# Добавляется как дочерний узел в hud.gd

const COLOR_PRIMARY = Color(0.17254902, 0.30980393, 0.5686275, 1)
const COLOR_PRIMARY_LIGHT = Color(0.25, 0.42, 0.72, 1)
const COLOR_ACCENT = Color(0.29803923, 0.6862745, 0.3137255, 1)
const COLOR_ACCENT_HOVER = Color(0.35, 0.78, 0.38, 1)
const COLOR_DANGER = Color(0.85, 0.25, 0.25, 1)
const COLOR_DANGER_HOVER = Color(0.95, 0.35, 0.35, 1)
const COLOR_TEXT_DARK = Color(0.15, 0.15, 0.2, 1)
const COLOR_TEXT_MUTED = Color(0.45, 0.45, 0.55, 1)

var _is_open: bool = false
var _dim: ColorRect
var _panel: PanelContainer
var _btn_resume: Button
var _btn_save: Button
var _btn_settings: Button
var _btn_main_menu: Button

# Настройки (вложенная панель)
var _settings_panel: PanelContainer
var _settings_open: bool = false
var _lang_option: OptionButton

const SETTINGS_PATH = "user://settings.json"

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100  # Поверх всего

	_build_ui()
	visible = false

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		if _settings_open:
			_close_settings()
		elif _is_open:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()

# === ПОСТРОЕНИЕ UI ===

func _build_ui():
	# Затемне��ие
	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0, 0, 0, 0.5)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	# Центральная панель
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(400, 0)
	_panel.offset_left = -200
	_panel.offset_right = 200
	_panel.offset_top = -200
	_panel.offset_bottom = 200

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color.WHITE
	panel_style.corner_radius_top_left = 20
	panel_style.corner_radius_top_right = 20
	panel_style.corner_radius_bottom_right = 20
	panel_style.corner_radius_bottom_left = 20
	panel_style.shadow_color = Color(0, 0, 0, 0.2)
	panel_style.shadow_size = 16
	panel_style.shadow_offset = Vector2(0, 6)
	panel_style.content_margin_left = 36
	panel_style.content_margin_right = 36
	panel_style.content_margin_top = 32
	panel_style.content_margin_bottom = 32
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(vbox)

	# Заголовок
	var title = Label.new()
	title.text = "⏸  " + tr("PAUSE_TITLE")
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", COLOR_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme:
		UITheme.apply_font(title, "bold")
	vbox.add_child(title)

	# Разделитель
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(spacer)

	# --- Кнопка "Продолжить" ---
	_btn_resume = _make_button_filled(tr("PAUSE_RESUME"), COLOR_ACCENT, COLOR_ACCENT_HOVER, "▶  ")
	_btn_resume.pressed.connect(close)
	vbox.add_child(_btn_resume)

	# --- Кнопка "Сохранить" ---
	_btn_save = _make_button_filled(tr("PAUSE_SAVE"), COLOR_PRIMARY, COLOR_PRIMARY_LIGHT, "💾  ")
	_btn_save.pressed.connect(_on_save_pressed)
	vbox.add_child(_btn_save)

	# --- Кнопка "Настройки" ---
	_btn_settings = _make_button_outline(tr("MENU_SETTINGS"), COLOR_PRIMARY, "⚙  ")
	_btn_settings.pressed.connect(_open_settings)
	vbox.add_child(_btn_settings)

	# --- Кнопка "В главное меню" ---
	_btn_main_menu = _make_button_outline(tr("PAUSE_MAIN_MENU"), COLOR_DANGER, "🏠  ")
	_btn_main_menu.pressed.connect(_on_main_menu_pressed)
	vbox.add_child(_btn_main_menu)

	# === Панель настроек ===
	_build_settings_panel()

# === КНОПКИ ===

func _make_button_filled(text: String, bg_color: Color, hover_color: Color, prefix: String = "") -> Button:
	var btn = Button.new()
	btn.text = prefix + text
	btn.custom_minimum_size = Vector2(320, 48)
	btn.focus_mode = Control.FOCUS_NONE

	var style_n = StyleBoxFlat.new()
	style_n.bg_color = bg_color
	style_n.corner_radius_top_left = 14
	style_n.corner_radius_top_right = 14
	style_n.corner_radius_bottom_right = 14
	style_n.corner_radius_bottom_left = 14
	style_n.shadow_color = Color(bg_color.r, bg_color.g, bg_color.b, 0.3)
	style_n.shadow_size = 5
	style_n.shadow_offset = Vector2(0, 3)

	var style_h = style_n.duplicate()
	style_h.bg_color = hover_color
	style_h.shadow_size = 8

	var style_p = style_n.duplicate()
	style_p.bg_color = bg_color.darkened(0.15)
	style_p.shadow_size = 2

	btn.add_theme_stylebox_override("normal", style_n)
	btn.add_theme_stylebox_override("hover", style_h)
	btn.add_theme_stylebox_override("pressed", style_p)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 16)
	if UITheme:
		UITheme.apply_font(btn, "semibold")
	return btn

func _make_button_outline(text: String, accent: Color, prefix: String = "") -> Button:
	var btn = Button.new()
	btn.text = prefix + text
	btn.custom_minimum_size = Vector2(320, 44)
	btn.focus_mode = Control.FOCUS_NONE

	var style_n = StyleBoxFlat.new()
	style_n.bg_color = Color.WHITE
	style_n.border_width_left = 2
	style_n.border_width_top = 2
	style_n.border_width_right = 2
	style_n.border_width_bottom = 2
	style_n.border_color = accent.lightened(0.3)
	style_n.corner_radius_top_left = 14
	style_n.corner_radius_top_right = 14
	style_n.corner_radius_bottom_right = 14
	style_n.corner_radius_bottom_left = 14

	var style_h = style_n.duplicate()
	style_h.bg_color = accent
	style_h.border_color = accent

	var style_p = style_n.duplicate()
	style_p.bg_color = accent.darkened(0.1)
	style_p.border_color = accent.darkened(0.1)

	btn.add_theme_stylebox_override("normal", style_n)
	btn.add_theme_stylebox_override("hover", style_h)
	btn.add_theme_stylebox_override("pressed", style_p)
	btn.add_theme_color_override("font_color", accent)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 15)
	if UITheme:
		UITheme.apply_font(btn, "semibold")
	return btn

# === НАСТРОЙКИ (вложенная панель) ===

func _build_settings_panel():
	_settings_panel = PanelContainer.new()
	_settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	_settings_panel.custom_minimum_size = Vector2(380, 0)
	_settings_panel.offset_left = -190
	_settings_panel.offset_right = 190
	_settings_panel.offset_top = -160
	_settings_panel.offset_bottom = 160

	var s_style = StyleBoxFlat.new()
	s_style.bg_color = Color.WHITE
	s_style.corner_radius_top_left = 20
	s_style.corner_radius_top_right = 20
	s_style.corner_radius_bottom_right = 20
	s_style.corner_radius_bottom_left = 20
	s_style.shadow_color = Color(0, 0, 0, 0.25)
	s_style.shadow_size = 20
	s_style.shadow_offset = Vector2(0, 8)
	s_style.content_margin_left = 28
	s_style.content_margin_right = 28
	s_style.content_margin_top = 24
	s_style.content_margin_bottom = 24
	_settings_panel.add_theme_stylebox_override("panel", s_style)
	_settings_panel.visible = false
	add_child(_settings_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	_settings_panel.add_child(vbox)

	# Заголовок
	var title = Label.new()
	title.text = "⚙  " + tr("MENU_SETTINGS")
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", COLOR_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme:
		UITheme.apply_font(title, "bold")
	vbox.add_child(title)

	# Язык
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
	_lang_option.custom_minimum_size = Vector2(150, 34)
	_lang_option.add_theme_font_size_override("font_size", 14)
	var current_locale = TranslationServer.get_locale()
	if current_locale.begins_with("en"):
		_lang_option.select(1)
	else:
		_lang_option.select(0)
	_lang_option.item_selected.connect(_on_language_changed)
	lang_hbox.add_child(_lang_option)
	vbox.add_child(lang_hbox)

	# Музыка
	vbox.add_child(_make_slider_row(tr("MENU_MUSIC_VOLUME"), AudioManager.music_volume, func(val): AudioManager.set_music_volume(val)))

	# SFX
	vbox.add_child(_make_slider_row(tr("MENU_SFX_VOLUME"), AudioManager.sfx_volume, func(val): AudioManager.set_sfx_volume(val)))

	# Кнопка "Назад"
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 2)
	vbox.add_child(spacer)

	var btn_back = _make_button_outline(tr("MENU_BACK"), COLOR_PRIMARY, "←  ")
	btn_back.custom_minimum_size.x = 0
	btn_back.pressed.connect(_close_settings)
	vbox.add_child(btn_back)

func _make_slider_row(label_text: String, initial: float, callback: Callable) -> HBoxContainer:
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
	slider.custom_minimum_size = Vector2(140, 22)
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = initial
	slider.value_changed.connect(callback)
	hbox.add_child(slider)

	var val_label = Label.new()
	val_label.text = "%d%%" % int(initial * 100)
	val_label.add_theme_font_size_override("font_size", 13)
	val_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	val_label.custom_minimum_size = Vector2(42, 0)
	if UITheme:
		UITheme.apply_font(val_label, "regular")
	hbox.add_child(val_label)

	slider.value_changed.connect(func(val): val_label.text = "%d%%" % int(val * 100))
	return hbox

# === ОТКРЫТЬ / ЗАКРЫТЬ ===

func open():
	if GameTime.is_night_skip:
		return
	_is_open = true
	visible = true
	GameTime.set_paused(true)

	# Анимация
	_panel.modulate.a = 0.0
	_panel.offset_top += 30
	_panel.offset_bottom += 30
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(_panel, "modulate:a", 1.0, 0.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(_panel, "offset_top", _panel.offset_top - 30, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_panel, "offset_bottom", _panel.offset_bottom - 30, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	_dim.modulate.a = 0.0
	create_tween().tween_property(_dim, "modulate:a", 1.0, 0.2)

func close():
	_is_open = false
	_settings_open = false
	_settings_panel.visible = false
	GameTime.set_paused(false)

	var tween = create_tween()
	tween.tween_property(_panel, "modulate:a", 0.0, 0.15).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): visible = false)

func is_open() -> bool:
	return _is_open

# === ОБРАБОТЧИКИ ===

func _on_save_pressed():
	SaveManager.save_game()
	# Мигаем текстом кнопки
	var original = _btn_save.text
	_btn_save.text = "✅  " + tr("PAUSE_SAVED")
	_btn_save.disabled = true
	await get_tree().create_timer(1.2).timeout
	_btn_save.text = original
	_btn_save.disabled = false

func _on_main_menu_pressed():
	# === FIX: НЕ сохраняем при выходе в меню ===
	# Раньше тут был SaveManager.save_game() — это приводило к тому,
	# что ��ри "Продолжить" загружалось состояние на момент выхода (9:05),
	# а не последнее автосохранение (08:00).
	# Теперь при выходе в меню НЕ перезаписываем сохранение.
	_save_settings()
	# Снимаем паузу и переходим
	GameTime.set_paused(false)
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")

func _open_settings():
	_settings_open = true
	_panel.visible = false
	_settings_panel.visible = true
	_settings_panel.modulate.a = 0.0
	create_tween().tween_property(_settings_panel, "modulate:a", 1.0, 0.2).set_ease(Tween.EASE_OUT)

func _close_settings():
	_settings_open = false
	_save_settings()
	_settings_panel.visible = false
	_panel.visible = true

func _on_language_changed(index: int):
	match index:
		0: TranslationServer.set_locale("ru")
		1: TranslationServer.set_locale("en")
	_save_settings()

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
