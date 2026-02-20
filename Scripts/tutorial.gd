extends Control

# === ТУТОРИАЛ ===
# Модальное окно обучения от лица босса.
# Показывается при первом запуске новой игры.

# === ЦВЕТА (как в проекте) ===
const COLOR_BLUE = Color(0.17254902, 0.30980393, 0.5686275, 1)
const COLOR_GREEN = Color(0.29803923, 0.6862745, 0.3137255, 1)
const COLOR_WHITE = Color(1, 1, 1, 1)
const COLOR_GRAY = Color(0.5, 0.5, 0.5, 1)
const COLOR_DARK = Color(0.2, 0.2, 0.2, 1)
const COLOR_BORDER = Color(0.8784314, 0.8784314, 0.8784314, 1)
const COLOR_WINDOW_BORDER = Color(0, 0, 0, 1)

# Шаги туториала — ключи локализации
const STEPS = [
	"TUTORIAL_STEP_1",
	"TUTORIAL_STEP_2",
	"TUTORIAL_STEP_3",
	"TUTORIAL_STEP_4",
	"TUTORIAL_STEP_5",
	"TUTORIAL_STEP_6",
	"TUTORIAL_STEP_7",
]

var _overlay: ColorRect
var _window: PanelContainer
var _emoji_label: Label
var _text_label: RichTextLabel
var _next_btn: Button
var _counter_label: Label

var _current_step: int = 0

signal tutorial_finished

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_force_fullscreen_size()
	_build_ui()

func _force_fullscreen_size():
	var vp_size = get_viewport().get_visible_rect().size
	position = Vector2.ZERO
	size = vp_size

func open():
	_force_fullscreen_size()
	_current_step = 0
	_update_step()
	GameTime.is_game_paused = true
	if UITheme:
		UITheme.fade_in(self, 0.3)
	else:
		visible = true

func close():
	GameTime.is_game_paused = false
	if UITheme:
		UITheme.fade_out(self, 0.2)
	else:
		visible = false
	emit_signal("tutorial_finished")

# === ПОСТРОЕНИЕ UI ===
func _build_ui():
	# Затемнение фона
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.5)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	# === ОКНО: 620×420 по центру ===
	_window = PanelContainer.new()
	_window.custom_minimum_size = Vector2(620, 420)
	_window.set_anchors_preset(Control.PRESET_CENTER)
	_window.offset_left = -310
	_window.offset_top = -210
	_window.offset_right = 310
	_window.offset_bottom = 210
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
	title_label.text = tr("TUTORIAL_TITLE")
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

	# === КОНТЕНТ ===
	var content_margin = MarginContainer.new()
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_left", 30)
	content_margin.add_theme_constant_override("margin_top", 20)
	content_margin.add_theme_constant_override("margin_right", 30)
	content_margin.add_theme_constant_override("margin_bottom", 10)
	main_vbox.add_child(content_margin)

	var content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 15)
	content_margin.add_child(content_vbox)

	# Эмодзи босса
	_emoji_label = Label.new()
	_emoji_label.text = "😤"
	_emoji_label.add_theme_font_size_override("font_size", 42)
	_emoji_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_vbox.add_child(_emoji_label)

	# Подзаголовок "Босс говорит..."
	var boss_hint = Label.new()
	boss_hint.text = tr("TUTORIAL_BOSS_SAYS")
	boss_hint.add_theme_color_override("font_color", COLOR_GRAY)
	boss_hint.add_theme_font_size_override("font_size", 13)
	boss_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme: UITheme.apply_font(boss_hint, "regular")
	content_vbox.add_child(boss_hint)

	# Текст шага
	_text_label = RichTextLabel.new()
	_text_label.bbcode_enabled = false
	_text_label.fit_content = true
	_text_label.scroll_active = false
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_label.add_theme_color_override("default_color", COLOR_DARK)
	_text_label.add_theme_font_size_override("normal_font_size", 15)
	if UITheme: UITheme.apply_font(_text_label, "regular")
	content_vbox.add_child(_text_label)

	# === НИЖНЯЯ ПАНЕЛЬ: счётчик + кнопка ===
	var bottom_margin = MarginContainer.new()
	bottom_margin.add_theme_constant_override("margin_left", 30)
	bottom_margin.add_theme_constant_override("margin_right", 30)
	bottom_margin.add_theme_constant_override("margin_bottom", 20)
	bottom_margin.add_theme_constant_override("margin_top", 5)
	main_vbox.add_child(bottom_margin)

	var bottom_hbox = HBoxContainer.new()
	bottom_hbox.add_theme_constant_override("separation", 10)
	bottom_margin.add_child(bottom_hbox)

	# Счётчик шагов (слева)
	_counter_label = Label.new()
	_counter_label.text = "1 / 7"
	_counter_label.add_theme_color_override("font_color", COLOR_GRAY)
	_counter_label.add_theme_font_size_override("font_size", 13)
	_counter_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_counter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if UITheme: UITheme.apply_font(_counter_label, "regular")
	bottom_hbox.add_child(_counter_label)

	# Кнопка "Далее" (справа)
	_next_btn = Button.new()
	_next_btn.text = tr("TUTORIAL_BTN_NEXT")
	_next_btn.custom_minimum_size = Vector2(200, 44)
	_next_btn.focus_mode = Control.FOCUS_NONE

	# Стили кнопки — как кнопка "Начать поиск" в hr_role_screen
	var btn_style_normal = StyleBoxFlat.new()
	btn_style_normal.bg_color = COLOR_WHITE
	btn_style_normal.border_width_left = 2
	btn_style_normal.border_width_top = 2
	btn_style_normal.border_width_right = 2
	btn_style_normal.border_width_bottom = 2
	btn_style_normal.border_color = COLOR_BLUE
	btn_style_normal.corner_radius_top_left = 20
	btn_style_normal.corner_radius_top_right = 20
	btn_style_normal.corner_radius_bottom_right = 20
	btn_style_normal.corner_radius_bottom_left = 20

	var btn_style_hover = StyleBoxFlat.new()
	btn_style_hover.bg_color = COLOR_BLUE
	btn_style_hover.border_width_left = 2
	btn_style_hover.border_width_top = 2
	btn_style_hover.border_width_right = 2
	btn_style_hover.border_width_bottom = 2
	btn_style_hover.border_color = COLOR_BLUE
	btn_style_hover.corner_radius_top_left = 20
	btn_style_hover.corner_radius_top_right = 20
	btn_style_hover.corner_radius_bottom_right = 20
	btn_style_hover.corner_radius_bottom_left = 20

	_next_btn.add_theme_stylebox_override("normal", btn_style_normal)
	_next_btn.add_theme_stylebox_override("hover", btn_style_hover)
	_next_btn.add_theme_stylebox_override("pressed", btn_style_hover)

	_next_btn.add_theme_color_override("font_color", COLOR_BLUE)
	_next_btn.add_theme_color_override("font_hover_color", COLOR_WHITE)
	_next_btn.add_theme_color_override("font_pressed_color", COLOR_WHITE)
	_next_btn.add_theme_font_size_override("font_size", 16)
	if UITheme: UITheme.apply_font(_next_btn, "bold")

	_next_btn.pressed.connect(_on_next_pressed)
	bottom_hbox.add_child(_next_btn)

# === ОБНОВЛЕНИЕ ШАГА ===
func _update_step():
	_text_label.text = tr(STEPS[_current_step])
	_counter_label.text = "%d / %d" % [_current_step + 1, STEPS.size()]

	if _current_step == STEPS.size() - 1:
		_next_btn.text = tr("TUTORIAL_BTN_FINISH")
	else:
		_next_btn.text = tr("TUTORIAL_BTN_NEXT")

func _on_next_pressed():
	_current_step += 1
	if _current_step >= STEPS.size():
		GameState.tutorial_completed = true
		close()
	else:
		_update_step()
