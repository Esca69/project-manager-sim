extends Control

# === Виджет-трекер ивентов босса ===
# Отображается над панелью лога событий.
# Два режима: PENDING (мигает ❗) и ACTIVE (показывает прогресс).
# Скрыт в IDLE.

const PANEL_WIDTH = 455
const BOTTOM_BAR_HEIGHT = 50
const SIDE_MARGIN = 10
const BOTTOM_MARGIN = 10
const ICON_SIZE = 36
const TRACKER_HEIGHT = 42
const GAP = 6

var _tracker: PanelContainer
var _icon_label: Label
var _text_label: Label
var _days_label: Label
var _pulse_tween: Tween = null

# Ссылки на соседей (лог)
var _log_panel: Control = null
var _log_icon: Control = null

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_connect_signals()
	_refresh()

func _build_ui():
	_tracker = PanelContainer.new()
	_tracker.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	_tracker.anchor_left = 1.0
	_tracker.anchor_top = 1.0
	_tracker.anchor_right = 1.0
	_tracker.anchor_bottom = 1.0
	_tracker.offset_left = -(PANEL_WIDTH + SIDE_MARGIN)
	_tracker.offset_right = -SIDE_MARGIN
	_tracker.offset_top = -200  # will be recalculated in _process
	_tracker.offset_bottom = -160
	_tracker.mouse_filter = Control.MOUSE_FILTER_STOP
	_tracker.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_tracker.visible = false

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.75)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	if UITheme:
		UITheme.apply_shadow(style)
	_tracker.add_theme_stylebox_override("panel", style)
	add_child(_tracker)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 6)
	_tracker.add_child(margin)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	margin.add_child(hbox)

	_icon_label = Label.new()
	_icon_label.add_theme_font_size_override("font_size", 18)
	_icon_label.add_theme_color_override("font_color", Color.WHITE)
	_icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(_icon_label)

	_text_label = Label.new()
	_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_label.add_theme_font_size_override("font_size", 13)
	_text_label.add_theme_color_override("font_color", Color.WHITE)
	_text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if UITheme:
		UITheme.apply_font(_text_label, "semibold")
	hbox.add_child(_text_label)

	_days_label = Label.new()
	_days_label.add_theme_font_size_override("font_size", 12)
	_days_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75, 1))
	_days_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if UITheme:
		UITheme.apply_font(_days_label, "regular")
	hbox.add_child(_days_label)

	# Клик-кнопка поверх всего
	var click_btn = Button.new()
	click_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	click_btn.flat = true
	click_btn.focus_mode = Control.FOCUS_NONE
	click_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	click_btn.pressed.connect(_on_tracker_clicked)
	_tracker.add_child(click_btn)

func _connect_signals():
	BossEventSystem.boss_event_generated.connect(_on_event_generated)
	BossEventSystem.boss_event_accepted.connect(_on_event_accepted)
	BossEventSystem.boss_event_rejected.connect(_on_event_hidden)
	BossEventSystem.boss_event_ended.connect(_on_event_hidden)
	BossEventSystem.boss_event_ignored.connect(_on_event_ignored)

# ============================================================
#                   ПОЗИЦИОНИРОВАНИЕ
# ============================================================

func _process(_delta):
	if not _tracker:
		return
	_update_position()

func _update_position():
	# Ищем лог если ещё не нашли
	if _log_panel == null or _log_icon == null:
		_find_log_nodes()

	var log_is_expanded = _log_panel != null and _log_panel.visible
	var icon_bottom_offset: float

	if log_is_expanded:
		# Верхний край развёрнутой панели лога
		# _log_panel.offset_top = -(PANEL_HEIGHT + BOTTOM_BAR_HEIGHT + BOTTOM_MARGIN)
		# Трекер должен быть на GAP выше этого верхнего края
		icon_bottom_offset = _log_panel.offset_top - GAP
	elif _log_icon != null and _log_icon.visible:
		# Верхний край иконки свёрнутого лога
		icon_bottom_offset = _log_icon.offset_top - GAP
	else:
		# Дефолтная позиция — выше bottom_bar с учётом иконки лога
		icon_bottom_offset = -(ICON_SIZE + BOTTOM_BAR_HEIGHT + BOTTOM_MARGIN + GAP)

	_tracker.offset_bottom = icon_bottom_offset
	_tracker.offset_top = icon_bottom_offset - max(_tracker.size.y, TRACKER_HEIGHT)

func _find_log_nodes():
	var hud = get_tree().get_first_node_in_group("ui")
	if hud == null:
		return
	for child in hud.get_children():
		if child.get_script() == null:
			continue
		var script_path = child.get_script().get_path()
		if script_path.ends_with("event_log_panel.gd"):
			# Ищем _panel и _icon_btn внутри
			for sub in child.get_children():
				if sub is PanelContainer:
					_log_panel = sub
				if sub is Button:
					_log_icon = sub
			break

# ============================================================
#                   ОБНОВЛЕНИЕ ВИДА
# ============================================================

func _refresh():
	if not _tracker:
		return
	match BossEventSystem.state:
		BossEventSystem.State.PENDING:
			_show_pending()
		BossEventSystem.State.ACTIVE:
			_show_active()
		_:
			_hide_tracker()

func _show_pending():
	_stop_pulse()
	_icon_label.text = "❗"
	_text_label.text = tr("BOSS_EVENT_TRACKER_PENDING")
	_days_label.text = ""
	_tracker.visible = true
	_start_pulse()

func _show_active():
	_stop_pulse()
	var event_data = BossEventSystem.get_active_event_data()
	_icon_label.text = event_data.get("emoji", "🏢")
	var title_key = event_data.get("title_key", "")
	_text_label.text = tr(title_key)
	_days_label.text = tr("BOSS_EVENT_TRACKER_DAYS_LEFT") % BossEventSystem.active_days_remaining
	_tracker.visible = true

func _hide_tracker():
	_stop_pulse()
	_tracker.visible = false

# ============================================================
#                   ПУЛЬСАЦИЯ
# ============================================================

func _start_pulse():
	if _pulse_tween and _pulse_tween.is_running():
		return
	_pulse_tween = create_tween()
	_pulse_tween.set_loops()
	_pulse_tween.tween_property(_icon_label, "modulate", Color(1.0, 0.3, 0.2, 1), 0.5)
	_pulse_tween.tween_property(_icon_label, "modulate", Color.WHITE, 0.5)

func _stop_pulse():
	if _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null
	if _icon_label:
		_icon_label.modulate = Color.WHITE

# ============================================================
#                   КЛИК
# ============================================================

func _on_tracker_clicked():
	var hud = get_tree().get_first_node_in_group("ui")
	if not hud:
		return
	match BossEventSystem.state:
		BossEventSystem.State.PENDING:
			if hud.has_method("open_boss_event"):
				hud.open_boss_event(BossEventSystem.get_pending_event_data())
		BossEventSystem.State.ACTIVE:
			if hud.has_method("open_boss_event_info"):
				hud.open_boss_event_info(BossEventSystem.get_active_event_data())

# ============================================================
#                   СИГНАЛЫ
# ============================================================

func _on_event_generated(_event_id: String):
	_show_pending()

func _on_event_accepted(_event_id: String):
	_show_active()

func _on_event_hidden(_event_id: String = ""):
	_hide_tracker()

func _on_event_ignored():
	_hide_tracker()
