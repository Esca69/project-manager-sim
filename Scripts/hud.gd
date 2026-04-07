extends CanvasLayer

@onready var time_label = $TopBar/MarginContainer/HBoxContainer/TimeLabel
@onready var balance_label = $TopBar/MarginContainer/HBoxContainer/BalanceLabel

@onready var btn_pause = $TopBar/MarginContainer/HBoxContainer/SpeedControls/PauseBtn
@onready var btn_1x = $TopBar/MarginContainer/HBoxContainer/SpeedControls/Speed1Btn
@onready var btn_2x = $TopBar/MarginContainer/HBoxContainer/SpeedControls/Speed2Btn
@onready var btn_5x = $TopBar/MarginContainer/HBoxContainer/SpeedControls/Speed5Btn
@onready var btn_10x = $TopBar/MarginContainer/HBoxContainer/SpeedControls/Speed10Btn

@onready var info_panel = $Panel
@onready var name_label = $Panel/VBoxContainer/NameLabel
@onready var role_label = $Panel/VBoxContainer/RoleLabel
@onready var salary_label = $Panel/VBoxContainer/SalaryLabel

@onready var selection_ui = $ProjectSelectionUI
@onready var project_window = $ProjectWindow
@onready var employee_selector = $EmployeeSelector
@onready var end_day_button = $EndDayButton
@onready var project_list_menu = $ProjectListMenu

@onready var bottom_bar = $BottomBar
@onready var employee_roster = $EmployeeRoster
@onready var pm_skill_tree = $PMSkillTree
@onready var client_panel = $ClientPanel

# --- PM Level UI ---
var _pm_level_label: Label
var _pm_xp_bar: ProgressBar
var _pm_xp_label: Label
var _xp_tween: Tween = null

# --- Boss Trust UI ---
var _boss_trust_label: Label

# --- Day Summary ---
var _day_summary: Control

# --- Boss UI ---
var _boss_panel: Control
var _boss_quest_screen: Control
var _boss_report_screen: Control

# === ПОИСК КАНДИДАТОВ (HR) ===
var _is_searching: bool = false
var _search_role: String = ""
var _search_minutes_remaining: float = 0.0
var _search_total_minutes: float = 0.0
const HR_SEARCH_HOURS: int = 2
const HR_CUTOFF_HOUR: int = 16

# === ФОНОВЫЙ ПОИСК HR (когда нанят HR-специалист) ===
var _is_hr_searching: bool = false
var _hr_search_role: String = ""
var _hr_search_minutes_remaining: float = 0.0
var _hr_search_total_minutes: float = 0.0
var _hr_search_results_ready: bool = false

# === АВТО-ЗАВЕРШЕНИЕ ДНЯ ===
const AUTO_END_DAY_HOUR: int = 21

# === ЭКРАН ВЫБОРА РОЛИ (HR) ===
var _hr_role_screen: Control

# >>> ДОБАВЛЕНО: Пауз-меню (Escape)
var _pause_menu: CanvasLayer

# <<< TUTORIAL: переменная для туториала-оверлея
var _tutorial_overlay: Control

# === GAME OVER ===
var _game_over_screen: Control

# === PLAYTEST CAP ===
const PLAYTEST_LAST_DAY = 90  # last playable day (end of month 3)
var _playtest_label: Label
var _playtest_label_tween: Tween
var _playtest_end_screen: Control

# === EVENT SYSTEM: Попап ивентов ===
var _event_popup: Control

# === EVENT LOG: Журнал событий ===
var _event_log_panel: Control

# === BOSS EVENT SYSTEM ===
var _boss_event_popup: Control
var _boss_event_tracker: Control

# === META: MY LIFE PANEL ===
var _my_life_panel: Control
var _personal_balance_label: Label

# === REPORTS PANEL ===
var _reports_panel: Control

# === ENCYCLOPEDIA PANEL ===
var _encyclopedia_panel: Control

# >>> ДОБАВЛЕНО: Переменная для FPS
var _fps_label: Label

# === SCREEN JUICE: предыдущие значения баланса для определения направления ===
var _prev_balance: int = 0
var _prev_personal_balance: int = 0

# === ИНДИКАТОР СВОБОДНОЙ КАМЕРЫ ===
var _free_camera_hint: PanelContainer = null

# === END DAY BUTTON: Пульсирующий tween ===
var _end_day_pulse_tween: Tween = null

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

	info_panel.visible = false
	selection_ui.visible = false
	project_window.visible = false
	employee_selector.visible = false
	end_day_button.visible = false
	project_list_menu.visible = false
	employee_roster.visible = false
	client_panel.visible = false

	# === Красивый дизайн для кнопки "Закончить день" ===
	var color_green = Color(0.29803923, 0.6862745, 0.3137255, 1)

	var btn_style_normal = StyleBoxFlat.new()
	btn_style_normal.bg_color = Color(1, 1, 1, 1)
	btn_style_normal.border_width_left = 2
	btn_style_normal.border_width_top = 2
	btn_style_normal.border_width_right = 2
	btn_style_normal.border_width_bottom = 2
	btn_style_normal.border_color = color_green
	btn_style_normal.corner_radius_top_left = 20
	btn_style_normal.corner_radius_top_right = 20
	btn_style_normal.corner_radius_bottom_right = 20
	btn_style_normal.corner_radius_bottom_left = 20

	var btn_style_hover = StyleBoxFlat.new()
	btn_style_hover.bg_color = color_green
	btn_style_hover.border_width_left = 2
	btn_style_hover.border_width_top = 2
	btn_style_hover.border_width_right = 2
	btn_style_hover.border_width_bottom = 2
	btn_style_hover.border_color = color_green
	btn_style_hover.corner_radius_top_left = 20
	btn_style_hover.corner_radius_top_right = 20
	btn_style_hover.corner_radius_bottom_right = 20
	btn_style_hover.corner_radius_bottom_left = 20

	end_day_button.add_theme_stylebox_override("normal", btn_style_normal)
	end_day_button.add_theme_stylebox_override("hover", btn_style_hover)
	end_day_button.add_theme_stylebox_override("pressed", btn_style_hover)

	end_day_button.add_theme_color_override("font_color", color_green)
	end_day_button.add_theme_color_override("font_hover_color", Color.WHITE)
	end_day_button.add_theme_color_override("font_pressed_color", Color.WHITE)

	end_day_button.custom_minimum_size = Vector2(280, 56)
	end_day_button.add_theme_font_size_override("font_size", 22)
	end_day_button.pivot_offset = end_day_button.custom_minimum_size / 2.0

	end_day_button.offset_bottom -= 70
	end_day_button.offset_top -= 70

	GameTime.time_tick.connect(update_time_label)
	GameTime.work_ended.connect(_on_work_ended_show_end_day)
	GameTime.work_started.connect(_on_work_started_hide_end_day)
	GameTime.night_skip_started.connect(_on_night_skip_started)
	GameTime.night_skip_finished.connect(_on_night_skip_finished)
	GameTime.day_started.connect(_on_new_day)
	GameState.balance_changed.connect(update_balance_ui)

	end_day_button.pressed.connect(_on_end_day_pressed)
	# Переводим кнопку конца дня
	end_day_button.text = tr("END_DAY_BTN")

	if not selection_ui.project_selected.is_connected(_on_project_taken):
		selection_ui.project_selected.connect(_on_project_taken)

	if not project_list_menu.project_opened.is_connected(_on_project_list_opened):
		project_list_menu.project_opened.connect(_on_project_list_opened)

	if not project_window.closed.is_connected(_on_project_window_closed):
		project_window.closed.connect(_on_project_window_closed)

	if bottom_bar and not bottom_bar.tab_pressed.is_connected(_on_bottom_tab_pressed):
		bottom_bar.tab_pressed.connect(_on_bottom_tab_pressed)

	btn_pause.pressed.connect(func(): GameTime.speed_pause())
	btn_1x.pressed.connect(func(): GameTime.speed_1x())
	btn_2x.pressed.connect(func(): GameTime.speed_2x())
	btn_5x.pressed.connect(func(): GameTime.speed_5x())
	btn_10x.pressed.connect(func(): GameTime.speed_10x())

	_prev_balance = GameState.company_balance
	update_balance_ui(GameState.company_balance)
	update_time_label(GameTime.hour, GameTime.minute)

	if ScreenJuice:
		ScreenJuice.register_balance_label(balance_label)

	pm_skill_tree.visible = false

	_build_pm_level_ui()
	_update_pm_level_ui()

	ProjectManager.project_finished.connect(_on_project_finished_xp)
	ProjectManager.project_failed.connect(_on_project_failed_xp)
	ProjectManager.employee_leveled_up.connect(_on_employee_leveled_up_toast)

	PMData.xp_changed.connect(_on_pm_xp_changed)
	PMData.level_up.connect(_on_pm_level_up)
	BossManager.trust_changed.connect(_on_boss_trust_changed)

	balance_label.tooltip_text = tr("TOOLTIP_COMPANY_BUDGET")

	call_deferred("_apply_fonts")

	# Тик времени для поиска кандидатов
	GameTime.time_tick.connect(_on_search_time_tick)

	# >>> ДОБАВЛЕНО: Создаём пауз-меню (Escape)
	var pause_script = load("res://Scripts/pause_menu.gd")
	_pause_menu = CanvasLayer.new()
	_pause_menu.set_script(pause_script)
	add_child(_pause_menu)

	# <<< TUTORIAL: Создаём туториал-оверлей и запускаем туториал если нужно
	_build_tutorial_overlay()
	if GameTime.day == 1 and not GameState.tutorial_completed:
		get_tree().create_timer(0.5).timeout.connect(func():
			if _tutorial_overlay and not GameState.tutorial_completed:
				_tutorial_overlay.open()
				TutorialManager.start_tutorial()
		)

	# Строим все панели синхронно — к этому моменту loading screen ещё виден
	_build_all_dynamic_ui()

# === СБОРКА ТЯЖЁЛЫХ UI-ПАНЕЛЕЙ (синхронно, выполняется пока виден loading screen) ===
func _build_all_dynamic_ui() -> void:
	_build_day_summary()

	_build_boss_ui()

	_build_hr_role_screen()

	# === EVENT SYSTEM: Создаём ивент-попап ===
	_build_event_popup()

	# === EVENT LOG: Создаём журнал событий ===
	_build_event_log()

	# === BOSS EVENT SYSTEM: Создаём попап и трекер ===
	_build_boss_event_ui()

	# === META: Создаём панель "Моя жизнь" ===
	_build_my_life_panel()

	_build_personal_balance_label()

	# >>> Создаем лейбл для FPS
	_build_fps_label()

	# === REPORTS: Создаём панель отчётов ===
	_build_reports_panel()

	# === ENCYCLOPEDIA: Создаём панель энциклопедии ===
	_build_encyclopedia_panel()

	# === PLAYTEST CAP: Счётчик дней и экран завершения ===
	_build_playtest_label()
	_build_playtest_end_screen()

	# Защита от загрузки сейва за пределами плейтеста
	if GameTime.day >= 91:
		call_deferred("_show_playtest_end")

	# Прогрев тяжёлых панелей — синхронно, пока виден loading screen
	_preheat_panels()

# === ПРОГРЕВ ТЯЖЁЛЫХ UI-ПАНЕЛЕЙ ===
# Строим UI при visible=false, чтобы ноды оказались в кеше.
func _preheat_panels() -> void:
	if pm_skill_tree and pm_skill_tree.has_method("_rebuild_tree"):
		pm_skill_tree.visible = false
		# Только если дерево уже инициализировано (_deferred_init успел отработать)
		if pm_skill_tree._initialized and pm_skill_tree._canvas:
			pm_skill_tree._rebuild_tree()
			pm_skill_tree._tree_is_dirty = false
		# Если не инициализировано — оставляем _tree_is_dirty = true,
		# чтобы при первом open() дерево нормально построилось

	if client_panel and client_panel.has_method("_populate"):
		var was_visible = client_panel.visible
		client_panel.visible = false
		client_panel._populate()
		client_panel.visible = was_visible

	if _boss_panel and _boss_panel.has_method("_populate"):
		var was_visible = _boss_panel.visible
		_boss_panel.visible = false
		_boss_panel._populate()
		_boss_panel.visible = was_visible

	if _reports_panel and _reports_panel.has_method("_refresh_content"):
		var was_visible = _reports_panel.visible
		_reports_panel.visible = false
		_reports_panel._refresh_content()
		_reports_panel.visible = was_visible

# >>> ДОБАВЛЕНО: Функция для обновления FPS каждый кадр
func _process(_delta):
	if _fps_label:
		_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

func _apply_fonts():
	if UITheme == null:
		return
	UITheme.apply_font(time_label, "semibold")
	UITheme.apply_font(balance_label, "bold")
	UITheme.apply_font(btn_pause, "semibold")
	UITheme.apply_font(btn_1x, "semibold")
	UITheme.apply_font(btn_2x, "semibold")
	UITheme.apply_font(btn_5x, "semibold")
	UITheme.apply_font(btn_10x, "semibold")
	if _pm_level_label:
		UITheme.apply_font(_pm_level_label, "semibold")
	if _pm_xp_label:
		UITheme.apply_font(_pm_xp_label, "regular")
	UITheme.apply_font(name_label, "semibold")
	UITheme.apply_font(role_label, "regular")
	UITheme.apply_font(salary_label, "regular")
	UITheme.apply_font(end_day_button, "semibold")

# --- DAY SUMMARY ---
func _build_day_summary():
	var day_summary_script = load("res://Scripts/day_summary.gd")
	_day_summary = Control.new()
	_day_summary.set_script(day_summary_script)
	_day_summary.set_anchors_preset(Control.PRESET_FULL_RECT)
	_day_summary.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_day_summary)

# --- BOSS UI ---
func _build_boss_ui():
	# Панель "Босс" (вкладка)
	var boss_panel_script = load("res://Scripts/boss_panel.gd")
	_boss_panel = Control.new()
	_boss_panel.set_script(boss_panel_script)
	_boss_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_boss_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_boss_panel)

	# Экран выдачи квеста
	var quest_screen_script = load("res://Scripts/boss_quest_screen.gd")
	_boss_quest_screen = Control.new()
	_boss_quest_screen.set_script(quest_screen_script)
	_boss_quest_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_boss_quest_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_boss_quest_screen)

	# Экран отчёта
	var report_screen_script = load("res://Scripts/boss_report_screen.gd")
	_boss_report_screen = Control.new()
	_boss_report_screen.set_script(report_screen_script)
	_boss_report_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_boss_report_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_boss_report_screen)

# === ОТКРЫТЬ ЭКРАН КВЕСТА БОССА ===
func open_boss_quest(quest: Dictionary):
	if _boss_quest_screen:
		_boss_quest_screen.open(quest)

# === ОТКРЫТЬ ЭКРАН ОТЧЁТА БОССА ===
func open_boss_report(report: Dictionary):
	if _boss_report_screen:
		_boss_report_screen.open(report)

# === ПОСТРОЕНИЕ ЭКРАНА ВЫБОРА РОЛИ (HR) ===
func _build_hr_role_screen():
	var script = load("res://Scripts/hr_role_screen.gd")
	_hr_role_screen = Control.new()
	_hr_role_screen.set_script(script)
	_hr_role_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hr_role_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_hr_role_screen)

	if not _hr_role_screen.search_started.is_connected(_on_hr_search_started):
		_hr_role_screen.search_started.connect(_on_hr_search_started)

# === ОТКРЫТЬ HR (вызывается из hr_desk.gd) ===
func open_hr_search():
	if _is_searching:
		print("HR: PM уже ищет кандидатов.")
		return
	if _is_hr_searching:
		print("HR: Фоновый поиск уже идёт.")
		return
	if _hr_role_screen:
		_hr_role_screen.open()

# === ПУБЛИЧНЫЕ МЕТОДЫ ДЛЯ hr_desk.gd ===
func is_hr_results_ready() -> bool:
	return _hr_search_results_ready

func is_hr_searching() -> bool:
	return _is_hr_searching

func show_hr_results():
	_hr_search_results_ready = false
	var hiring_menu = get_node_or_null("HiringMenu")
	if hiring_menu:
		hiring_menu.open_hiring_menu_for_role(_hr_search_role)
	_hr_search_role = ""

# === HR: ПОИСК НАЧАТ (сигнал из hr_role_screen) ===
func _on_hr_search_started(role: String):
	# Если HR-специалист нанят — фоновый режим
	if GameState.office_upgrades.get("hr_specialist", false):
		_is_hr_searching = true
		_hr_search_role = role
		_hr_search_total_minutes = float(PMData.get_hr_search_minutes())
		_hr_search_minutes_remaining = _hr_search_total_minutes
		var hr_desk = get_tree().get_first_node_in_group("hr_desk")
		if hr_desk and hr_desk.has_method("show_search_progress"):
			hr_desk.show_search_progress(_hr_search_total_minutes)
		EventLog.add(tr("LOG_HR_SEARCH_STARTED_BG") % tr(role), EventLog.LogType.ROUTINE)
		print("🔍 HR фоновый поиск начат: %s (%d мин.)" % [role, int(_hr_search_total_minutes)])
		return

	# Старая механика (PM стоит и ждёт)
	_is_searching = true
	_search_role = role
	_search_total_minutes = float(PMData.get_hr_search_minutes())
	_search_minutes_remaining = _search_total_minutes

	var player = _get_player()
	if player and player.has_method("show_discuss_bar"):
		player.show_discuss_bar(_search_total_minutes)
	# Меняем текст на плашке (используем существующий ключ)
	if player and player._discuss_label:
		player._discuss_label.text = tr("HR_SEARCH_LABEL")
	if player and player._discuss_timer_label:
		var hours = int(_search_total_minutes) / 60
		var mins = int(_search_total_minutes) % 60
		player._discuss_timer_label.text = "🔍 %d:%02d" % [hours, mins]

	print("🔍 Поиск кандидатов начат: %s (%d мин.)" % [role, int(_search_total_minutes)])

	# === ТУТОРИАЛ: автоускорение до 10x на время поиска ===
	if TutorialManager.is_active():
		GameTime.speed_10x()

func _on_search_time_tick(_h, _m):
	# === Фоновый поиск HR-специалиста ===
	if _is_hr_searching:
		_hr_search_minutes_remaining -= 1.0
		var elapsed_bg = _hr_search_total_minutes - _hr_search_minutes_remaining
		var hr_desk = get_tree().get_first_node_in_group("hr_desk")
		if hr_desk and hr_desk.has_method("update_search_progress"):
			hr_desk.update_search_progress(elapsed_bg, _hr_search_minutes_remaining)
		if _hr_search_minutes_remaining <= 0:
			_finish_hr_background_search()

	# === Обычный поиск (PM ждёт) ===
	if not _is_searching:
		return

	_search_minutes_remaining -= 1.0
	var elapsed = _search_total_minutes - _search_minutes_remaining

	var player = _get_player()
	if player and player.has_method("update_discuss_bar"):
		player._discuss_progress_bar.value = elapsed
		var hours_left = int(_search_minutes_remaining) / 60
		var mins_left = int(_search_minutes_remaining) % 60
		player._discuss_timer_label.text = "🔍 %d:%02d" % [hours_left, mins_left]

	if _search_minutes_remaining <= 0:
		_finish_search()

func _finish_hr_background_search():
	_is_hr_searching = false
	_hr_search_results_ready = true
	var hr_desk = get_tree().get_first_node_in_group("hr_desk")
	if hr_desk and hr_desk.has_method("hide_search_progress"):
		hr_desk.hide_search_progress()
	EventLog.add(tr("LOG_HR_SEARCH_DONE") % tr(_hr_search_role), EventLog.LogType.PROGRESS)
	print("✅ HR фоновый поиск завершён! Роль: ", _hr_search_role)

func _finish_search():
	_is_searching = false

	var player = _get_player()
	if player and player.has_method("hide_discuss_bar"):
		player.hide_discuss_bar()

	print("✅ Поиск завершён! Роль: ", _search_role)
	EventLog.add(tr("LOG_HR_SEARCH_DONE") % tr(_search_role), EventLog.LogType.PROGRESS)

	# === ТУТОРИАЛ: восстанавливаем 1x после поиска ===
	if TutorialManager.is_active():
		GameTime.speed_1x()

	# Открываем HiringMenu с результатами
	var hiring_menu = get_node_or_null("HiringMenu")
	if hiring_menu:
		hiring_menu.open_hiring_menu_for_role(_search_role)

	_search_role = ""

# --- PM LEVEL UI ---
func _build_pm_level_ui():
	var hbox_container = $TopBar/MarginContainer/HBoxContainer

	var level_vbox = VBoxContainer.new()
	level_vbox.add_theme_constant_override("separation", 2)
	level_vbox.custom_minimum_size = Vector2(140, 0)

	_pm_level_label = Label.new()
	_pm_level_label.text = tr("UI_PM_LEVEL") % 1 # Инициализируем переведенной строкой
	_pm_level_label.add_theme_font_size_override("font_size", 13)
	_pm_level_label.add_theme_color_override("font_color", Color(0.85, 0.85, 1.0, 1))
	_pm_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_vbox.add_child(_pm_level_label)

	_pm_xp_bar = ProgressBar.new()
	_pm_xp_bar.custom_minimum_size = Vector2(130, 12)
	_pm_xp_bar.max_value = 100
	_pm_xp_bar.value = 0
	_pm_xp_bar.show_percentage = false

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.2, 0.4, 0.8)
	bg_style.corner_radius_top_left = 6
	bg_style.corner_radius_top_right = 6
	bg_style.corner_radius_bottom_right = 6
	bg_style.corner_radius_bottom_left = 6
	_pm_xp_bar.add_theme_stylebox_override("background", bg_style)

	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.4, 0.75, 1.0, 1)
	fill_style.corner_radius_top_left = 6
	fill_style.corner_radius_top_right = 6
	fill_style.corner_radius_bottom_right = 6
	fill_style.corner_radius_bottom_left = 6
	_pm_xp_bar.add_theme_stylebox_override("fill", fill_style)

	level_vbox.add_child(_pm_xp_bar)

	_pm_xp_label = Label.new()
	_pm_xp_label.text = tr("UI_XP") % [0, 50]
	_pm_xp_label.add_theme_font_size_override("font_size", 11)
	_pm_xp_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9, 1))
	_pm_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_vbox.add_child(_pm_xp_label)

	var spacer_index = -1
	for i in range(hbox_container.get_child_count()):
		if hbox_container.get_child(i).name == "Spacer":
			spacer_index = i
			break

	_boss_trust_label = Label.new()
	_boss_trust_label.text = tr("UI_BOSS_TRUST") % BossManager.boss_trust
	_boss_trust_label.add_theme_font_size_override("font_size", 13)
	_boss_trust_label.add_theme_color_override("font_color", BossManager.get_trust_color())
	_boss_trust_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	if spacer_index >= 0:
		hbox_container.add_child(level_vbox)
		hbox_container.move_child(level_vbox, spacer_index)
		hbox_container.add_child(_boss_trust_label)
		hbox_container.move_child(_boss_trust_label, spacer_index + 1)
	else:
		hbox_container.add_child(level_vbox)
		hbox_container.add_child(_boss_trust_label)

	level_vbox.tooltip_text = tr("TOOLTIP_PM_LEVEL")
	_boss_trust_label.tooltip_text = tr("TOOLTIP_BOSS_TRUST")

func _update_pm_level_ui():
	if PMData == null:
		return
	var level = PMData.get_level()
	_pm_level_label.text = tr("UI_PM_LEVEL") % level

	var progress = PMData.get_level_progress()
	var current_in_level = progress[0]
	var needed_for_level = progress[1]

	_pm_xp_bar.max_value = needed_for_level
	# Убиваем предыдущий tween, чтобы не накапливались
	if _xp_tween and _xp_tween.is_valid():
		_xp_tween.kill()
	_xp_tween = create_tween()
	_xp_tween.tween_property(_pm_xp_bar, "value", current_in_level, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	_pm_xp_label.text = tr("UI_XP") % [current_in_level, needed_for_level]

func _on_pm_xp_changed(_new_xp, _new_sp):
	_update_pm_level_ui()

func _on_pm_level_up(new_level: int):
	if ScreenJuice:
		ScreenJuice.show_toast("⬆️", tr("TOAST_PM_LEVEL_UP") % new_level)
	var player = _get_player()
	if player and is_instance_valid(player):
		var bubble = Node2D.new()
		player.add_child(bubble)
		bubble.position = Vector2(0, -210)
		bubble.z_index = 100

		var panel = Panel.new()
		bubble.add_child(panel)
		panel.custom_minimum_size = Vector2(72, 72)
		panel.size = Vector2(72, 72)
		panel.position = Vector2(-36, -36)

		var style = StyleBoxFlat.new()
		style.bg_color = Color(1.0, 1.0, 1.0, 1.0)
		style.border_width_bottom = 2
		style.border_width_top = 2
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_color = Color(0.2, 0.2, 0.2, 1.0)
		style.corner_radius_bottom_left = 20
		style.corner_radius_bottom_right = 20
		style.corner_radius_top_left = 20
		style.corner_radius_top_right = 20
		style.shadow_color = Color(0, 0, 0, 0.1)
		style.shadow_size = 4
		panel.add_theme_stylebox_override("panel", style)

		var label = Label.new()
		panel.add_child(label)
		label.custom_minimum_size = Vector2(72, 72)
		label.size = Vector2(72, 72)
		label.position = Vector2.ZERO
		label.text = "⬆️"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var label_settings = LabelSettings.new()
		label_settings.font_size = 42
		label.label_settings = label_settings

		bubble.scale = Vector2.ZERO
		var tween = create_tween()
		tween.tween_property(bubble, "scale", Vector2(1.3, 1.3), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(bubble, "scale", Vector2.ONE, 0.2)
		tween.tween_interval(2.0)
		tween.tween_property(bubble, "modulate:a", 0.0, 0.5)
		tween.parallel().tween_property(bubble, "position:y", bubble.position.y - 30, 0.5)
		tween.tween_callback(bubble.queue_free)

# === ПОЛУЧИТЬ PLAYER ===
func _get_player():
	return get_tree().get_first_node_in_group("player")

# =========================================================
# === ВЗЯТИЕ ПРОЕКТА (МГНОВЕННОЕ) =========================
# =========================================================

# === ХЕЛПЕР: прибавить N рабочих дней (пропуская выходные) ===
func _add_working_days(from_day: int, work_days: int) -> int:
	var result = from_day
	var added = 0
	while added < work_days:
		result += 1
		if not GameTime.is_weekend(result):
			added += 1
	return result

# === ПРОВЕРКА: PM ЗАНЯТ ===
func is_pm_busy() -> bool:
	return _is_searching

# === ПРОВЕРКА: АКТИВЕН ЛИ ДЛИТЕЛЬНЫЙ ПРОЦЕСС (для свободной камеры) ===
func is_long_action_active() -> bool:
	return _is_searching

# --- ПРОВЕРКА: ОТКРЫТО ЛИ КАКОЕ-ТО МЕНЮ ---
func is_any_menu_open() -> bool:
	if info_panel.visible: return true
	if selection_ui.visible: return true
	if project_window.visible: return true
	if employee_selector.visible: return true
	if project_list_menu.visible: return true
	if employee_roster.visible: return true
	if pm_skill_tree.visible: return true
	if client_panel.visible: return true

	if _day_summary and _day_summary.visible: return true
	if _boss_panel and _boss_panel.visible: return true
	if _boss_quest_screen and _boss_quest_screen.visible: return true
	if _boss_report_screen and _boss_report_screen.visible: return true
	if _hr_role_screen and _hr_role_screen.visible: return true
	if _my_life_panel and _my_life_panel.visible: return true

	var hiring_menu = get_node_or_null("HiringMenu")
	if hiring_menu and hiring_menu.visible: return true

	var assignment_menu = get_node_or_null("AssignmentMenu")
	if assignment_menu and assignment_menu.visible: return true

	# >>> ДОБАВЛЕНО: Проверка пауз-меню
	if _pause_menu and _pause_menu.is_open():
		return true

	# <<< TUTORIAL: Проверка туториала-оверлея
	if _tutorial_overlay and _tutorial_overlay._card_visible: return true

	# === EVENT SYSTEM: Проверка ивент-попапа ===
	if _event_popup and _event_popup.visible: return true

	if _reports_panel and _reports_panel.visible: return true

	if _encyclopedia_panel and _encyclopedia_panel.visible: return true

	return false

func _on_project_finished_xp(proj):
	PMData.add_xp(30)
	print("🎯 PM +30 XP за завершённый проект")
	if ScreenJuice:
		var payout = proj.get_final_payout(GameTime.day) if proj else 0
		ScreenJuice.show_toast("✅", tr("TOAST_PROJECT_FINISHED") % [tr(proj.title), payout])
		ScreenJuice.show_confetti()
		AudioManager.play_projectdone_sfx()
	if proj and proj.is_finished_on_time(GameTime.day):
		BossManager.change_trust(1)
		if ScreenJuice:
			ScreenJuice.show_toast("🤝", tr("TOAST_TRUST_PROJECT_SUCCESS"))

func _on_project_failed_xp(proj):
	PMData.add_xp(10)
	print("🎯 PM +10 XP за проваленный проект (опыт всё равно)")
	BossManager.change_trust(-2)
	if ScreenJuice and proj:
		ScreenJuice.show_toast("❌", tr("TOAST_PROJECT_FAILED") % tr(proj.title))
		ScreenJuice.show_toast("🤝", tr("TOAST_TRUST_PROJECT_FAILED"))

func _on_boss_trust_changed(new_trust: int):
	if _boss_trust_label:
		_boss_trust_label.text = tr("UI_BOSS_TRUST") % new_trust
		_boss_trust_label.add_theme_color_override("font_color", BossManager.get_trust_color())

func _on_employee_leveled_up_toast(emp: EmployeeData, new_level: int, _skill_gain: int, _new_trait: String):
	if ScreenJuice and emp:
		ScreenJuice.show_toast("⬆️", tr("TOAST_EMPLOYEE_LEVELED_UP") % [emp.get_display_name(), new_level, emp.get_grade_name()])

# --- ОБНОВЛЕНИЕ ИНТЕРФЕЙСА ---

func update_time_label(_hour, _minute):
	var time_str = "%02d:%02d" % [GameTime.hour, GameTime.minute]
	var date_str = GameTime.get_date_string()

	time_label.text = date_str + " — " + time_str

	if GameTime.is_weekend():
		time_label.modulate = Color(1.0, 0.6, 0.6, 1.0)
	else:
		time_label.modulate = Color.WHITE

	# === АВТО-ЗАВЕРШЕНИЕ ДНЯ В 21:00 ===
	if GameTime.hour == AUTO_END_DAY_HOUR and GameTime.minute == 0:
		if end_day_button.visible and not GameTime.is_night_skip:
			print("⏰ 21:00 — автоматическое завершение дня!")
			_on_end_day_pressed()

	# === CRUNCH TIME: Показываем кнопку «Завершить день» в 20:00 ===
	if GameTime.hour == 20 and GameTime.minute == 0 and not GameTime.is_weekend() and not GameTime.is_night_skip:
		if not end_day_button.visible:
			_start_end_day_pulse()

	# === ТУТОРИАЛ: показываем кнопку «Завершить день» когда дошли до шага 10 и время >= 18:00 ===
	if TutorialManager.is_active() and TutorialManager.current_step == TutorialManager.Step.STEP_10_END_DAY:
		if GameTime.hour >= 18 and not end_day_button.visible:
			_start_end_day_pulse()

	# === PLAYTEST CAP: Обновляем счётчик оставшихся дней ===
	_update_playtest_label()

func update_balance_ui(amount):
	balance_label.text = tr("HUD_BALANCE") % amount

	var label_color = Color.RED if amount < 0 else Color.GREEN
	balance_label.modulate = label_color

	if ScreenJuice:
		ScreenJuice.bounce_node(balance_label, amount >= _prev_balance, label_color)
	_prev_balance = amount

# --- ОСТАЛЬНАЯ ЛОГИКА ---

func show_employee_card(data: EmployeeData):
	name_label.text = tr("HUD_INFO_NAME") % data.employee_name
	role_label.text = tr("HUD_INFO_ROLE") % tr(data.job_title)
	salary_label.text = tr("HUD_INFO_SALARY") % data.monthly_salary
	if UITheme:
		UITheme.fade_in(info_panel)
	else:
		info_panel.visible = true

func _on_close_button_pressed():
	if UITheme:
		UITheme.fade_out(info_panel)
	else:
		info_panel.visible = false

func open_boss_menu():
	if _is_searching:
		print("Босс: PM занят поиском кандидатов.")
		return
	# ИСПРАВЛЕНИЕ: Блокирующая проверка can_take_more() убрана,
	# чтобы меню открывалось, а плашка с предупреждением показывалась внутри UI
	selection_ui.open_selection()

func open_work_menu():
	if _is_searching:
		print("Компьютер: PM занят поиском кандидатов.")
		return
	# ИСПРАВЛЕНИЕ: Блокировка при отсутствии проектов убрана.
	# Меню откроется, но покажет EmptyLabel (как в EmployeeRoster)
	project_list_menu.open_menu()

func _on_project_taken(proj_data: ProjectData):
	# Мгновенное взятие проекта (meeting больше не нужен)
	var today = GameTime.day
	proj_data.created_at_day = today
	proj_data.soft_deadline_day = _add_working_days(today, proj_data.soft_days_budget)
	proj_data.deadline_day = _add_working_days(today, proj_data.hard_days_budget)

	print("📅 Дедлайны: софт = день %d, хард = день %d" % [proj_data.soft_deadline_day, proj_data.deadline_day])

	ProjectManager.add_project(proj_data)

	PMData.add_xp(5)
	print("🎯 PM +5 XP за взятие проекта")

	EventLog.add(tr("LOG_DISCUSSION_FINISHED") % tr(proj_data.title), EventLog.LogType.PROGRESS)
	AudioManager.play_sfx("bossmeeting")

	# === ТУТОРИАЛ ===
	if TutorialManager.is_active():
		TutorialManager.notify_discussion_finished()

func _on_project_list_opened(proj_data: ProjectData):
	project_window.setup(proj_data, employee_selector)
	if UITheme:
		UITheme.fade_in(project_window)
	else:
		project_window.visible = true

func _on_project_window_closed():
	project_list_menu.open_menu()
	TutorialManager.notify_project_screen_closed()

func _on_bottom_tab_pressed(tab_name: String):
	match tab_name:
		"employees":
			if employee_roster.visible:
				if UITheme:
					UITheme.fade_out(employee_roster)
				else:
					employee_roster.visible = false
			else:
				pm_skill_tree.visible = false
				client_panel.visible = false
				if _boss_panel: _boss_panel.visible = false
				if _my_life_panel: _my_life_panel.visible = false
				if _reports_panel: _reports_panel.visible = false
				employee_roster.open()
				if UITheme and employee_roster.modulate.a < 1.0:
					employee_roster.modulate.a = 1.0
		"pm_skills":
			if pm_skill_tree.visible:
				if UITheme:
					UITheme.fade_out(pm_skill_tree)
				else:
					pm_skill_tree.visible = false
			else:
				employee_roster.visible = false
				client_panel.visible = false
				if _boss_panel: _boss_panel.visible = false
				if _my_life_panel: _my_life_panel.visible = false
				if _reports_panel: _reports_panel.visible = false
				pm_skill_tree.open()
				if UITheme and pm_skill_tree.modulate.a < 1.0:
					pm_skill_tree.modulate.a = 1.0
		"clients":
			if client_panel.visible:
				if UITheme:
					UITheme.fade_out(client_panel)
				else:
					client_panel.visible = false
			else:
				employee_roster.visible = false
				pm_skill_tree.visible = false
				if _boss_panel: _boss_panel.visible = false
				if _my_life_panel: _my_life_panel.visible = false
				if _reports_panel: _reports_panel.visible = false
				client_panel.open()
		"boss":
			if _boss_panel and _boss_panel.visible:
				if UITheme:
					UITheme.fade_out(_boss_panel)
				else:
					_boss_panel.visible = false
			elif _boss_panel:
				employee_roster.visible = false
				pm_skill_tree.visible = false
				client_panel.visible = false
				if _my_life_panel: _my_life_panel.visible = false
				if _reports_panel: _reports_panel.visible = false
				_boss_panel.open()
		"my_life":
			if _my_life_panel and _my_life_panel.visible:
				if UITheme:
					UITheme.fade_out(_my_life_panel)
				else:
					_my_life_panel.visible = false
			elif _my_life_panel:
				employee_roster.visible = false
				pm_skill_tree.visible = false
				client_panel.visible = false
				if _boss_panel: _boss_panel.visible = false
				if _reports_panel: _reports_panel.visible = false
				_my_life_panel.open()
		"reports":
			if _reports_panel and _reports_panel.visible:
				if UITheme:
					UITheme.fade_out(_reports_panel)
				else:
					_reports_panel.visible = false
			elif _reports_panel:
				employee_roster.visible = false
				pm_skill_tree.visible = false
				client_panel.visible = false
				if _boss_panel: _boss_panel.visible = false
				if _my_life_panel: _my_life_panel.visible = false
				_reports_panel.open()
		"projects_menu":
			if project_list_menu.visible:
				if UITheme:
					UITheme.fade_out(project_list_menu)
				else:
					project_list_menu.visible = false
			else:
				employee_roster.visible = false
				pm_skill_tree.visible = false
				client_panel.visible = false
				if _boss_panel: _boss_panel.visible = false
				if _my_life_panel: _my_life_panel.visible = false
				if _reports_panel: _reports_panel.visible = false
				project_list_menu.open_menu()
		"encyclopedia":
			if _encyclopedia_panel and _encyclopedia_panel.visible:
				if UITheme:
					UITheme.fade_out(_encyclopedia_panel)
				else:
					_encyclopedia_panel.visible = false
				GameTime.set_paused(false)
			elif _encyclopedia_panel:
				employee_roster.visible = false
				pm_skill_tree.visible = false
				client_panel.visible = false
				if _boss_panel: _boss_panel.visible = false
				if _my_life_panel: _my_life_panel.visible = false
				if _reports_panel: _reports_panel.visible = false
				project_list_menu.visible = false
				_encyclopedia_panel.open()
				GameTime.set_paused(true)

# === ПРИНУДИТЕЛЬНАЯ ОТПРАВКА ВСЕХ СОТРУДНИКОВ ДОМОЙ ===
func _dismiss_all_employees():
	var npcs = get_tree().get_nodes_in_group("npc")
	for npc in npcs:
		if npc.current_state == npc.State.HOME or npc.current_state == npc.State.SICK_LEAVE or npc.current_state == npc.State.DAY_OFF:
			continue
		npc._go_to_sleep_instant()
	print("🏠 Все сотрудники отправлены домой принудительно")

func _on_end_day_pressed():
	if GameTime.is_night_skip: return
	if _is_searching:
		print("Нельзя закончить день: PM ищет кандидатов!")
		return

	# === ТУТОРИАЛ: обработка завершения дня 0 ===
	if TutorialManager.is_active():
		# Complete tutorial (step 9B card already told the player to end the day)
		TutorialManager.notify_end_day()
		# After tutorial completes (day 1), night skip advances to day 2
		end_day_button.visible = false
		_dismiss_all_employees()
		# Don't pay salaries on day 1 (tutorial day — no real work done)
		# Reset camera before night skip to prevent camera flying off (mirrors day_summary._close)
		var player = get_tree().get_first_node_in_group("player")
		if player:
			player.velocity = Vector2.ZERO
			if player.has_method("force_reset_camera"):
				player.force_reset_camera()
		# Skip day summary, go directly to night skip
		GameTime.start_night_skip()
		return

	_stop_end_day_pulse()

	# === ПРИНУДИТЕЛЬНО УБИРАЕМ ВСЕХ СОТРУДНИКОВ ИЗ ОФИСА ===
	_dismiss_all_employees()

	GameState.pay_daily_salaries()
	GameState.pay_daily_services()

	# === ФИНАНСОВАЯ ИСТОРИЯ: Записать снимок дня ===
	if FinancialHistory:
		FinancialHistory.record_day()

	# === ИСТОРИЯ СОТРУДНИКОВ: Записать снимок дня ===
	if PeopleHistory:
		PeopleHistory.record_day()

	# === GAME OVER: Банкротство ===
	if GameState.company_balance < 0 and GameState.tutorial_completed:
		show_game_over("GAMEOVER_REASON_BANKRUPT")
		return

	if _day_summary:
		_day_summary.open()
	else:
		GameTime.start_night_skip()

func _on_work_ended_show_end_day():
	# === CRUNCH TIME: Если активен кранч — кнопка появляется только в 20:00 ===
	if ProjectManager.has_any_crunch_active():
		return
	_start_end_day_pulse()

func _start_end_day_pulse():
	end_day_button.visible = true
	end_day_button.pivot_offset = end_day_button.custom_minimum_size / 2.0
	if _end_day_pulse_tween and _end_day_pulse_tween.is_valid():
		_end_day_pulse_tween.kill()
	_end_day_pulse_tween = create_tween()
	_end_day_pulse_tween.set_loops()
	_end_day_pulse_tween.tween_property(end_day_button, "scale", Vector2(1.08, 1.08), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_end_day_pulse_tween.tween_property(end_day_button, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _stop_end_day_pulse():
	if _end_day_pulse_tween and _end_day_pulse_tween.is_valid():
		_end_day_pulse_tween.kill()
		_end_day_pulse_tween = null
	end_day_button.scale = Vector2.ONE
	end_day_button.visible = false

func _on_work_started_hide_end_day():
	_stop_end_day_pulse()

func _on_new_day(_day_number):
	# === PLAYTEST CAP: Завершаем на день 91 (Месяц 4, День 1) ===
	if _day_number >= 91:
		_show_playtest_end()
		return
	_stop_end_day_pulse()

func _on_night_skip_started():
	_stop_end_day_pulse()

func _on_night_skip_finished():
	_stop_end_day_pulse()
	# === АВТОСОХРАНЕНИЕ: начало нового рабочего дня ===
	SaveManager.save_game()
	if ScreenJuice:
		ScreenJuice.show_toast("💾", tr("TOAST_AUTOSAVE"))

# <<< TUTORIAL: Построение туториал-оверлея ===
func _build_tutorial_overlay():
	var script = load("res://Scripts/tutorial_overlay.gd")
	if script == null:
		push_warning("tutorial_overlay.gd не найден")
		return
	_tutorial_overlay = Control.new()
	_tutorial_overlay.set_script(script)
	_tutorial_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tutorial_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_tutorial_overlay)

# === GAME OVER: Показать экран увольнения ===
func show_game_over(reason_key: String):
	if _game_over_screen:
		return
	var script = load("res://Scripts/game_over_screen.gd")
	if script == null:
		push_warning("game_over_screen.gd не найден")
		return
	_game_over_screen = Control.new()
	_game_over_screen.set_script(script)
	_game_over_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_game_over_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_game_over_screen)
	_game_over_screen.setup(tr(reason_key))

# === EVENT SYSTEM: Построение попапа ивентов ===
func _build_event_popup():
	var script = load("res://Scripts/event_popup.gd")
	if script == null:
		push_warning("event_popup.gd не найден — ивент-попап не будет работать")
		return
	_event_popup = Control.new()
	_event_popup.set_script(script)
	_event_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	_event_popup.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_event_popup)

# === EVENT LOG: Построение журнала событий ===
func _build_event_log():
	var script = load("res://Scripts/event_log_panel.gd")
	if script == null:
		push_warning("event_log_panel.gd не найден — журнал событий не будет работать")
		return
	_event_log_panel = Control.new()
	_event_log_panel.set_script(script)
	_event_log_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_event_log_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_event_log_panel)

# === BOSS EVENT SYSTEM: Построение попапа и трекера ===
func _build_boss_event_ui():
	# Попап
	var popup_script = load("res://Scripts/boss_event_popup.gd")
	if popup_script:
		_boss_event_popup = Control.new()
		_boss_event_popup.set_script(popup_script)
		_boss_event_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
		_boss_event_popup.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_boss_event_popup)

	# Трекер
	var tracker_script = load("res://Scripts/boss_event_tracker.gd")
	if tracker_script:
		_boss_event_tracker = Control.new()
		_boss_event_tracker.set_script(tracker_script)
		_boss_event_tracker.set_anchors_preset(Control.PRESET_FULL_RECT)
		_boss_event_tracker.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_boss_event_tracker)

func _build_my_life_panel():
	var my_life_script = load("res://Scripts/my_life_panel.gd")
	if my_life_script:
		_my_life_panel = Control.new()
		_my_life_panel.set_script(my_life_script)
		_my_life_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		_my_life_panel.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_my_life_panel)

func _build_personal_balance_label():
	# Добавляем лейбл личного баланса в TopBar HBox
	var hbox_container = get_node_or_null("TopBar/MarginContainer/HBoxContainer")
	if hbox_container == null:
		return
	_personal_balance_label = Label.new()
	_personal_balance_label.add_theme_color_override("font_color", Color(0.85, 0.65, 0.13, 1))
	_personal_balance_label.add_theme_font_size_override("font_size", 15)
	if UITheme: UITheme.apply_font(_personal_balance_label, "bold")
	_personal_balance_label.text = "💰 $%d" % PMData.personal_balance
	# Вставляем ПЕРЕД SpeedControls, чтобы лейбл был слева от кнопок скорости
	var speed_controls = hbox_container.get_node_or_null("SpeedControls")
	if speed_controls:
		var idx = speed_controls.get_index()
		hbox_container.add_child(_personal_balance_label)
		hbox_container.move_child(_personal_balance_label, idx)
	else:
		hbox_container.add_child(_personal_balance_label)
	PMData.personal_balance_changed.connect(_on_personal_balance_changed)
	_prev_personal_balance = PMData.personal_balance
	if ScreenJuice:
		ScreenJuice.register_personal_balance_label(_personal_balance_label)
	_personal_balance_label.tooltip_text = tr("TOOLTIP_PERSONAL_BALANCE")

func _on_personal_balance_changed(new_amount: int):
	if _personal_balance_label:
		_personal_balance_label.text = "💰 $%d" % new_amount
		if ScreenJuice:
			var is_income = new_amount >= _prev_personal_balance
			ScreenJuice.bounce_node(_personal_balance_label, is_income, Color(0.85, 0.65, 0.13, 1))
			var diff = abs(new_amount - _prev_personal_balance)
			if diff > 0:
				if is_income:
					ScreenJuice.show_personal_income_float(diff)
				else:
					ScreenJuice.show_personal_expense_float(diff)
		_prev_personal_balance = new_amount

# >>> ДОБАВЛЕНО: Функция сборки FPS лейбла 
func _build_fps_label():
	var hbox_container = get_node_or_null("TopBar/MarginContainer/HBoxContainer")
	if hbox_container == null:
		return
		
	_fps_label = Label.new()
	_fps_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2, 1)) 
	_fps_label.add_theme_font_size_override("font_size", 14)
	if UITheme: 
		UITheme.apply_font(_fps_label, "bold")
	
	hbox_container.add_child(_fps_label)
	hbox_container.move_child(_fps_label, 0)

func _build_reports_panel():
	var script = load("res://Scripts/reports_panel.gd")
	_reports_panel = Control.new()
	_reports_panel.set_script(script)
	_reports_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_reports_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_reports_panel)

func _build_encyclopedia_panel():
	var script = load("res://Scripts/encyclopedia_panel.gd")
	_encyclopedia_panel = Control.new()
	_encyclopedia_panel.set_script(script)
	_encyclopedia_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_encyclopedia_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_encyclopedia_panel)

func open_boss_event(event_data: Dictionary):
	if _boss_event_popup and _boss_event_popup.has_method("open"):
		_boss_event_popup.open(event_data)

func open_boss_event_info(event_data: Dictionary):
	if _boss_event_popup and _boss_event_popup.has_method("open_info"):
		_boss_event_popup.open_info(event_data)

# === EVENT SYSTEM: Открыть попап ивента (вызывается из EventManager) ===
func show_event_popup(event_data: Dictionary):
	if _event_popup and _event_popup.has_method("open"):
		_event_popup.open(event_data)

# === СВОБОДНАЯ КАМЕРА: ПОКАЗАТЬ ИНДИКАТОР ===
func show_free_camera_hint():
	if _free_camera_hint and is_instance_valid(_free_camera_hint):
		_free_camera_hint.visible = true
		if UITheme:
			_free_camera_hint.modulate.a = 0.0
			UITheme.fade_in(_free_camera_hint, 0.3)
		return

	_free_camera_hint = PanelContainer.new()
	_free_camera_hint.set_anchors_preset(Control.PRESET_TOP_LEFT) # Меняем якорь на верх-влево
	_free_camera_hint.position = Vector2(20, 120) # Отступ 20 вправо, 120 вниз от верха

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.17254902, 0.30980393, 0.5686275, 0.85)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_free_camera_hint.add_theme_stylebox_override("panel", style)

	var label = Label.new()
	label.text = "📷  " + tr("FREE_CAMERA_HINT")
	label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	label.add_theme_font_size_override("font_size", 14)
	if UITheme: UITheme.apply_font(label, "semibold")
	_free_camera_hint.add_child(label)

	add_child(_free_camera_hint)

	if UITheme:
		_free_camera_hint.modulate.a = 0.0
		UITheme.fade_in(_free_camera_hint, 0.3)

# === СВОБОДНАЯ КАМЕРА: СКРЫТЬ ИНДИКАТОР ===
func hide_free_camera_hint():
	if _free_camera_hint and is_instance_valid(_free_camera_hint):
		if UITheme:
			UITheme.fade_out(_free_camera_hint, 0.3)
		else:
			_free_camera_hint.visible = false

# === PLAYTEST CAP: Счётчик оставшихся дней ===

func _build_playtest_label():
	var hbox_container = get_node_or_null("TopBar/MarginContainer/HBoxContainer")
	if hbox_container == null:
		return
	_playtest_label = Label.new()
	_playtest_label.add_theme_color_override("font_color", Color.WHITE)
	_playtest_label.add_theme_font_size_override("font_size", 12)
	if UITheme:
		UITheme.apply_font(_playtest_label, "semibold")
	_playtest_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_playtest_label.visible = false

	var speed_controls = hbox_container.get_node_or_null("SpeedControls")
	if speed_controls:
		var idx = speed_controls.get_index()
		hbox_container.add_child(_playtest_label)
		hbox_container.move_child(_playtest_label, idx)
	else:
		hbox_container.add_child(_playtest_label)
	_playtest_label.tooltip_text = tr("TOOLTIP_PLAYTEST_DAYS")

func _update_playtest_label():
	if _playtest_label == null:
		return
	if GameTime.day == 0 or GameTime.day > PLAYTEST_LAST_DAY:
		_playtest_label.visible = false
		return
	_playtest_label.visible = true
	var days_left = max(0, PLAYTEST_LAST_DAY - GameTime.day)
	_playtest_label.text = tr("PLAYTEST_DAYS_LEFT") % days_left

	if days_left <= 3:
		_playtest_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		if _playtest_label_tween == null or not _playtest_label_tween.is_running():
			_start_playtest_pulse()
	elif days_left <= 7:
		_playtest_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
		if _playtest_label_tween == null or not _playtest_label_tween.is_running():
			_start_playtest_pulse()
	else:
		_playtest_label.add_theme_color_override("font_color", Color.WHITE)
		if _playtest_label_tween:
			_playtest_label_tween.kill()
			_playtest_label_tween = null
		_playtest_label.modulate.a = 1.0

func _start_playtest_pulse():
	if _playtest_label_tween:
		_playtest_label_tween.kill()
	_playtest_label_tween = create_tween()
	_playtest_label_tween.set_loops()
	_playtest_label_tween.tween_property(_playtest_label, "modulate:a", 0.55, 0.7).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_playtest_label_tween.tween_property(_playtest_label, "modulate:a", 1.0, 0.7).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _build_playtest_end_screen():
	var script = load("res://Scripts/playtest_end_screen.gd")
	_playtest_end_screen = Control.new()
	_playtest_end_screen.set_script(script)
	_playtest_end_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_playtest_end_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	_playtest_end_screen.visible = false
	add_child(_playtest_end_screen)

func _show_playtest_end():
	if _playtest_end_screen:
		_playtest_end_screen.visible = true
