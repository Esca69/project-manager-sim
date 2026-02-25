extends Control

# =============================================
# EventPopup — UI окно для отображения ивентов
# Стиль: как client_panel.gd / boss_quest_screen.gd
# =============================================

const COLOR_BLUE = Color(0.17254902, 0.30980393, 0.5686275, 1)
const COLOR_DARK = Color(0.2, 0.2, 0.2, 1)
const COLOR_GREEN = Color(0.29803923, 0.6862745, 0.3137255, 1)
const COLOR_RED = Color(0.8980392, 0.22352941, 0.20784314, 1)
const COLOR_GRAY = Color(0.55, 0.55, 0.55, 1)
const COLOR_WHITE = Color(1, 1, 1, 1)
const COLOR_ORANGE = Color(0.9, 0.5, 0.1, 1)

const WINDOW_WIDTH = 520
const WINDOW_HEIGHT_MIN = 280

# Заголовки и эмодзи по типу ивента
# Заголовки и эмодзи по типу ивента
const EVENT_HEADERS = {
	"sick_leave": {"emoji": "🤒", "title_key": "EVENT_SICK_TITLE"},
	"day_off": {"emoji": "🙏", "title_key": "EVENT_DAYOFF_TITLE"},
	"scope_expansion": {"emoji": "📦", "title_key": "EVENT_SCOPE_TITLE"},
	"client_review": {"emoji": "⭐", "title_key": "EVENT_REVIEW_TITLE"},
	"contract_cancel": {"emoji": "💔", "title_key": "EVENT_CANCEL_TITLE"},
	"junior_mistake": {"emoji": "🤦", "title_key": "EVENT_JUNIOR_TITLE"},
}

var _overlay: ColorRect
var _window: PanelContainer
var _content_vbox: VBoxContainer
var _buttons_vbox: VBoxContainer

var _current_event: Dictionary = {}
var _was_paused: bool = false

signal choice_made(event_data: Dictionary, choice_id: String)

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	z_index = 200
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)
	_build_ui()
	EventManager.register_popup(self)

# =============================================
# ПОСТРОЕНИЕ UI
# =============================================
func _build_ui():
	# === ЗАТЕМНЕНИЕ ФОНА ===
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(PRESET_FULL_RECT)
	_overlay.color = Color(0, 0, 0, 0.5)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	# === ОКНО ===
	_window = PanelContainer.new()
	_window.set_anchors_preset(PRESET_CENTER)
	_window.custom_minimum_size = Vector2(WINDOW_WIDTH, WINDOW_HEIGHT_MIN)
	_window.offset_left = -WINDOW_WIDTH / 2.0
	_window.offset_right = WINDOW_WIDTH / 2.0
	_window.offset_top = -200
	_window.offset_bottom = 200

	var window_style = StyleBoxFlat.new()
	window_style.bg_color = COLOR_WHITE
	window_style.border_width_left = 3
	window_style.border_width_top = 3
	window_style.border_width_right = 3
	window_style.border_width_bottom = 3
	window_style.border_color = Color(0, 0, 0, 1)
	window_style.corner_radius_top_left = 22
	window_style.corner_radius_top_right = 22
	window_style.corner_radius_bottom_right = 20
	window_style.corner_radius_bottom_left = 20
	if UITheme:
		UITheme.apply_shadow(window_style)
	_window.add_theme_stylebox_override("panel", window_style)
	add_child(_window)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 0)
	_window.add_child(main_vbox)

	# === ЗАГОЛОВОК ===
	var header_panel = Panel.new()
	header_panel.custom_minimum_size = Vector2(0, 50)
	var header_style = StyleBoxFlat.new()
	header_style.bg_color = COLOR_BLUE
	header_style.corner_radius_top_left = 20
	header_style.corner_radius_top_right = 20
	header_panel.add_theme_stylebox_override("panel", header_style)
	main_vbox.add_child(header_panel)

	var header_label = Label.new()
	header_label.name = "HeaderLabel"
	header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_label.set_anchors_preset(PRESET_FULL_RECT)
	header_label.add_theme_color_override("font_color", COLOR_WHITE)
	header_label.add_theme_font_size_override("font_size", 18)
	if UITheme:
		UITheme.apply_font(header_label, "bold")
	header_panel.add_child(header_label)

	# === КОНТЕНТ ===
	var content_margin = MarginContainer.new()
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_left", 24)
	content_margin.add_theme_constant_override("margin_top", 18)
	content_margin.add_theme_constant_override("margin_right", 24)
	content_margin.add_theme_constant_override("margin_bottom", 10)
	main_vbox.add_child(content_margin)

	_content_vbox = VBoxContainer.new()
	_content_vbox.add_theme_constant_override("separation", 12)
	content_margin.add_child(_content_vbox)

	# === КНОПКИ ===
	var buttons_margin = MarginContainer.new()
	buttons_margin.add_theme_constant_override("margin_left", 24)
	buttons_margin.add_theme_constant_override("margin_right", 24)
	buttons_margin.add_theme_constant_override("margin_bottom", 20)
	main_vbox.add_child(buttons_margin)

	_buttons_vbox = VBoxContainer.new()
	_buttons_vbox.add_theme_constant_override("separation", 10)
	buttons_margin.add_child(_buttons_vbox)

# =============================================
# ПОКАЗ ИВЕНТА
# =============================================
func show_event(event_data: Dictionary):
	_current_event = event_data

	# Ставим на паузу
	_was_paused = GameTime.is_game_paused
	GameTime.set_paused(true)

	# Очищаем контент
	for child in _content_vbox.get_children():
		child.queue_free()
	for child in _buttons_vbox.get_children():
		child.queue_free()

	# === ЗАГОЛОВОК ===
	var header_info = EVENT_HEADERS.get(event_data["id"], {"emoji": "❓", "title_key": "EVENT_UNKNOWN"})
	var header_label = _window.find_child("HeaderLabel", true, false)
	if header_label:
		header_label.text = header_info["emoji"] + "  " + tr(header_info["title_key"])

	# === ОПИСАНИЕ ===
	var desc_text = _get_event_description(event_data)
	var desc_label = Label.new()
	desc_label.text = desc_text
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_color_override("font_color", COLOR_DARK)
	desc_label.add_theme_font_size_override("font_size", 15)
	if UITheme:
		UITheme.apply_font(desc_label, "regular")
	_content_vbox.add_child(desc_label)

	# === РАЗДЕЛИТЕЛЬ ===
	var sep = HSeparator.new()
	_content_vbox.add_child(sep)

	# === КНОПКИ ВЫБОРА ===
	for choice in event_data["choices"]:
		var btn_container = _create_choice_button(choice)
		_buttons_vbox.add_child(btn_container)

	# Показываем
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP

	if UITheme:
		UITheme.fade_in(self, 0.25)

# =============================================
# ОПИСАНИЕ ИВЕНТА
# =============================================
func _get_event_description(event_data: Dictionary) -> String:
	match event_data["id"]:
		"sick_leave":
			return tr("EVENT_SICK_DESC") % event_data["employee_name"]
		"day_off":
			return tr("EVENT_DAYOFF_DESC") % event_data["employee_name"]
		"scope_expansion":
			return tr("EVENT_SCOPE_DESC") % [event_data["client_name"], event_data["project_title"]]
		"client_review":
			var review = event_data["review"]
			return tr("EVENT_REVIEW_DESC") % [review["client_name"], tr(review["project_title"])]
		"contract_cancel":
			return tr("EVENT_CANCEL_DESC") % [event_data["client_name"], event_data["project_title"]]
		"junior_mistake":
			return tr("EVENT_JUNIOR_DESC") % [event_data["worker_name"], event_data["stage_type_name"], event_data["project_title"]]
	return ""

# =============================================
# СОЗДАНИЕ КНОПКИ ВЫБОРА
# =============================================
func _create_choice_button(choice: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 60)

	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.96, 0.96, 0.98, 1)
	style_normal.border_width_left = 2
	style_normal.border_width_top = 2
	style_normal.border_width_right = 2
	style_normal.border_width_bottom = 2
	style_normal.border_color = Color(0.85, 0.85, 0.9, 1)
	style_normal.corner_radius_top_left = 14
	style_normal.corner_radius_top_right = 14
	style_normal.corner_radius_bottom_right = 14
	style_normal.corner_radius_bottom_left = 14
	panel.add_theme_stylebox_override("panel", style_normal)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	# Заголовок кнопки
	var title_lbl = Label.new()
	title_lbl.text = choice.get("emoji", "") + "  " + choice["label"]
	title_lbl.add_theme_color_override("font_color", COLOR_BLUE)
	title_lbl.add_theme_font_size_override("font_size", 15)
	if UITheme:
		UITheme.apply_font(title_lbl, "semibold")
	vbox.add_child(title_lbl)

	# Описание
	if choice.has("description") and choice["description"] != "":
		var desc_lbl = Label.new()
		desc_lbl.text = choice["description"]
		desc_lbl.add_theme_color_override("font_color", COLOR_GRAY)
		desc_lbl.add_theme_font_size_override("font_size", 13)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if UITheme:
			UITheme.apply_font(desc_lbl, "regular")
		vbox.add_child(desc_lbl)

	# Кликабельность — через невидимую кнопку поверх
	var click_btn = Button.new()
	click_btn.set_anchors_preset(PRESET_FULL_RECT)
	click_btn.flat = true
	click_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	click_btn.focus_mode = Control.FOCUS_NONE

	# Ховер стиль
	var style_hover = style_normal.duplicate()
	style_hover.border_color = COLOR_BLUE
	style_hover.bg_color = Color(0.92, 0.94, 1.0, 1)

	click_btn.mouse_entered.connect(func():
		panel.add_theme_stylebox_override("panel", style_hover)
	)
	click_btn.mouse_exited.connect(func():
		panel.add_theme_stylebox_override("panel", style_normal)
	)
	click_btn.pressed.connect(_on_choice_pressed.bind(choice["id"]))
	panel.add_child(click_btn)

	return panel

# =============================================
# ОБРАБОТКА ВЫБОРА
# =============================================
func _on_choice_pressed(choice_id: String):
	if _current_event.is_empty():
		return

	EventManager.apply_choice(_current_event, choice_id)
	emit_signal("choice_made", _current_event, choice_id)

	_close()

func _close():
	_current_event = {}

	if not _was_paused:
		GameTime.set_paused(false)

	if UITheme:
		UITheme.fade_out(self, 0.2)
		await get_tree().create_timer(0.2).timeout
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

# =============================================
# ВВОД (ESC — нельзя закрыть, нужно выбрать)
# =============================================
func _unhandled_input(event):
	if not visible:
		return
	# Блокируем ESC — игрок обязан сделать выбор
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
