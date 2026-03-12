extends Control

# === ЭКРАН ИНТРО ===
# Показывается ТОЛЬКО при старте новой игры

const COLOR_PRIMARY = Color(0.17254902, 0.30980393, 0.5686275, 1)
const COLOR_ACCENT = Color(0.29803923, 0.6862745, 0.3137255, 1)
const COLOR_ACCENT_HOVER = Color(0.35, 0.78, 0.38, 1)

var _line_labels: Array = []
var _start_btn: Button
var _current_line: int = 0
var _tween: Tween

const INTRO_LINES = ["INTRO_LINE_1", "INTRO_LINE_2", "INTRO_LINE_3", "INTRO_LINE_4"]

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func _build_ui():
	# Белый фон
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(1, 1, 1, 1)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Центральный контейнер
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(760, 0)
	vbox.add_theme_constant_override("separation", 28)
	center.add_child(vbox)

	# Декоративный заголовок
	var emoji_lbl = Label.new()
	emoji_lbl.text = "🏎️"
	emoji_lbl.add_theme_font_size_override("font_size", 72)
	emoji_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(emoji_lbl)

	# Строки текста — изначально прозрачные
	for key in INTRO_LINES:
		var lbl = Label.new()
		lbl.text = tr(key)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_color_override("font_color", Color(0.15, 0.15, 0.2, 1))
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.modulate.a = 0.0
		if UITheme:
			UITheme.apply_font(lbl, "regular")
		vbox.add_child(lbl)
		_line_labels.append(lbl)

	# Разделитель
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	# Кнопка "Начать"
	_start_btn = Button.new()
	_start_btn.text = tr("INTRO_BTN_START")
	_start_btn.custom_minimum_size = Vector2(220, 52)
	_start_btn.focus_mode = Control.FOCUS_NONE
	_start_btn.modulate.a = 0.0
	_start_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = COLOR_ACCENT
	btn_style.corner_radius_top_left = 14
	btn_style.corner_radius_top_right = 14
	btn_style.corner_radius_bottom_right = 14
	btn_style.corner_radius_bottom_left = 14

	var btn_style_hover = StyleBoxFlat.new()
	btn_style_hover.bg_color = COLOR_ACCENT_HOVER
	btn_style_hover.corner_radius_top_left = 14
	btn_style_hover.corner_radius_top_right = 14
	btn_style_hover.corner_radius_bottom_right = 14
	btn_style_hover.corner_radius_bottom_left = 14

	_start_btn.add_theme_stylebox_override("normal", btn_style)
	_start_btn.add_theme_stylebox_override("hover", btn_style_hover)
	_start_btn.add_theme_stylebox_override("pressed", btn_style_hover)
	_start_btn.add_theme_color_override("font_color", Color.WHITE)
	_start_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	_start_btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	_start_btn.add_theme_font_size_override("font_size", 18)
	if UITheme:
		UITheme.apply_font(_start_btn, "bold")
	_start_btn.pressed.connect(_on_start_pressed)
	vbox.add_child(_start_btn)

	# Запускаем анимацию через небольшую задержку
	await get_tree().create_timer(0.8, true, false, true).timeout
	_animate_lines()

func _animate_lines():
	_current_line = 0
	_show_next_line()

func _show_next_line():
	if _current_line >= _line_labels.size():
		# Все строки показаны — показываем кнопку
		_tween = create_tween()
		_tween.tween_property(_start_btn, "modulate:a", 1.0, 0.5).set_ease(Tween.EASE_OUT)
		return

	var lbl = _line_labels[_current_line]
	_tween = create_tween()
	_tween.tween_property(lbl, "modulate:a", 1.0, 1.4).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(0.8)
	_tween.tween_callback(func():
		_current_line += 1
		_show_next_line()
	)

func _on_start_pressed():
	_start_btn.disabled = true
	# Прямой переход в офис — нет необходимости в fade-out, так как интро — самостоятельная сцена
	get_tree().change_scene_to_file("res://Scenes/office.tscn")
