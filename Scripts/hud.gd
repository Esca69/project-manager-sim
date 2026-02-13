extends CanvasLayer

@onready var time_label = $TopBar/MarginContainer/HBoxContainer/TimeLabel
@onready var balance_label = $TopBar/MarginContainer/HBoxContainer/BalanceLabel

@onready var btn_pause = $TopBar/MarginContainer/HBoxContainer/SpeedControls/PauseBtn
@onready var btn_1x = $TopBar/MarginContainer/HBoxContainer/SpeedControls/Speed1Btn
@onready var btn_2x = $TopBar/MarginContainer/HBoxContainer/SpeedControls/Speed2Btn
@onready var btn_5x = $TopBar/MarginContainer/HBoxContainer/SpeedControls/Speed5Btn

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

# --- PM Level UI (создаются в коде) ---
var _pm_level_label: Label
var _pm_xp_bar: ProgressBar
var _pm_xp_label: Label

# --- Day Summary (создаётся в коде) ---
var _day_summary: Control

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	info_panel.visible = false
	selection_ui.visible = false
	project_window.visible = false
	employee_selector.visible = false
	end_day_button.visible = false
	project_list_menu.visible = false
	employee_roster.visible = false
	
	GameTime.time_tick.connect(update_time_label)
	GameTime.work_ended.connect(_on_work_ended_show_end_day)
	GameTime.work_started.connect(_on_work_started_hide_end_day)
	GameTime.night_skip_started.connect(_on_night_skip_started)
	GameTime.night_skip_finished.connect(_on_night_skip_finished)
	GameTime.day_started.connect(_on_new_day)
	GameState.balance_changed.connect(update_balance_ui)
	
	end_day_button.pressed.connect(_on_end_day_pressed)
	
	if not selection_ui.project_selected.is_connected(_on_project_taken):
		selection_ui.project_selected.connect(_on_project_taken)
	
	if not project_list_menu.project_opened.is_connected(_on_project_list_opened):
		project_list_menu.project_opened.connect(_on_project_list_opened)
	
	if bottom_bar and not bottom_bar.tab_pressed.is_connected(_on_bottom_tab_pressed):
		bottom_bar.tab_pressed.connect(_on_bottom_tab_pressed)
	
	btn_pause.pressed.connect(func(): GameTime.speed_pause())
	btn_1x.pressed.connect(func(): GameTime.speed_1x())
	btn_2x.pressed.connect(func(): GameTime.speed_2x())
	btn_5x.pressed.connect(func(): GameTime.speed_5x())
	
	update_balance_ui(GameState.company_balance)
	update_time_label(GameTime.hour, GameTime.minute)
	
	pm_skill_tree.visible = false
	
	# --- Создаём UI уровня PM в TopBar ---
	_build_pm_level_ui()
	_update_pm_level_ui()
	
	# XP за проекты
	ProjectManager.project_finished.connect(_on_project_finished_xp)
	ProjectManager.project_failed.connect(_on_project_failed_xp)
	
	# XP обновление UI
	PMData.xp_changed.connect(_on_pm_xp_changed)
	
	# --- Создаём DaySummary ---
	_build_day_summary()

# --- DAY SUMMARY ---
func _build_day_summary():
	var day_summary_script = load("res://Scripts/day_summary.gd")
	_day_summary = Control.new()
	_day_summary.set_script(day_summary_script)
	_day_summary.set_anchors_preset(Control.PRESET_FULL_RECT)
	_day_summary.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_day_summary)

# --- PM LEVEL UI ---
func _build_pm_level_ui():
	var hbox_container = $TopBar/MarginContainer/HBoxContainer
	
	# Контейнер для уровня
	var level_vbox = VBoxContainer.new()
	level_vbox.add_theme_constant_override("separation", 2)
	level_vbox.custom_minimum_size = Vector2(140, 0)
	
	# Лейбл "Ур. 1"
	_pm_level_label = Label.new()
	_pm_level_label.text = "PM Ур. 1"
	_pm_level_label.add_theme_font_size_override("font_size", 13)
	_pm_level_label.add_theme_color_override("font_color", Color(0.85, 0.85, 1.0, 1))
	_pm_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_vbox.add_child(_pm_level_label)
	
	# Прогресс-бар
	_pm_xp_bar = ProgressBar.new()
	_pm_xp_bar.custom_minimum_size = Vector2(130, 12)
	_pm_xp_bar.max_value = 100
	_pm_xp_bar.value = 0
	_pm_xp_bar.show_percentage = false
	
	# Стиль фона прогресс-бара
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.2, 0.4, 0.8)
	bg_style.corner_radius_top_left = 6
	bg_style.corner_radius_top_right = 6
	bg_style.corner_radius_bottom_right = 6
	bg_style.corner_radius_bottom_left = 6
	_pm_xp_bar.add_theme_stylebox_override("background", bg_style)
	
	# Стиль заполнения прогресс-бара
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.4, 0.75, 1.0, 1)
	fill_style.corner_radius_top_left = 6
	fill_style.corner_radius_top_right = 6
	fill_style.corner_radius_bottom_right = 6
	fill_style.corner_radius_bottom_left = 6
	_pm_xp_bar.add_theme_stylebox_override("fill", fill_style)
	
	level_vbox.add_child(_pm_xp_bar)
	
	# Лейбл "0 / 50 XP"
	_pm_xp_label = Label.new()
	_pm_xp_label.text = "0 / 50 XP"
	_pm_xp_label.add_theme_font_size_override("font_size", 11)
	_pm_xp_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9, 1))
	_pm_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_vbox.add_child(_pm_xp_label)
	
	# Вставляем после BalanceLabel (перед Spacer)
	var spacer_index = -1
	for i in range(hbox_container.get_child_count()):
		if hbox_container.get_child(i).name == "Spacer":
			spacer_index = i
			break
	
	if spacer_index >= 0:
		hbox_container.add_child(level_vbox)
		hbox_container.move_child(level_vbox, spacer_index)
	else:
		hbox_container.add_child(level_vbox)

func _update_pm_level_ui():
	var level = PMData.get_level()
	_pm_level_label.text = "PM Ур. %d" % level
	
	var progress = PMData.get_level_progress()
	var current_in_level = progress[0]
	var needed_for_level = progress[1]
	
	_pm_xp_bar.max_value = needed_for_level
	_pm_xp_bar.value = current_in_level
	
	_pm_xp_label.text = "%d / %d XP" % [current_in_level, needed_for_level]

func _on_pm_xp_changed(_new_xp, _new_sp):
	_update_pm_level_ui()

# --- ПРОВЕРКА: ОТКРЫТО ЛИ КАКОЕ-ТО МЕНЮ ---
func is_any_menu_open() -> bool:
	if info_panel.visible: return true
	if selection_ui.visible: return true
	if project_window.visible: return true
	if employee_selector.visible: return true
	if project_list_menu.visible: return true
	if employee_roster.visible: return true
	if pm_skill_tree.visible: return true
	
	if _day_summary and _day_summary.visible: return true
	
	var hiring_menu = get_node_or_null("HiringMenu")
	if hiring_menu and hiring_menu.visible: return true
	
	var assignment_menu = get_node_or_null("AssignmentMenu")
	if assignment_menu and assignment_menu.visible: return true
	
	return false

func _on_project_finished_xp(_proj):
	PMData.add_xp(30)
	print("🎯 PM +30 XP за завершённый проект")

func _on_project_failed_xp(_proj):
	PMData.add_xp(10)
	print("🎯 PM +10 XP за проваленный проект (опыт всё равно)")

# --- ОБНОВЛЕНИЕ ИНТЕРФЕЙСА ---

func update_time_label(_hour, _minute):
	var time_str = "%02d:%02d" % [GameTime.hour, GameTime.minute]
	var date_str = GameTime.get_date_string()
	
	time_label.text = date_str + " — " + time_str
	
	if GameTime.is_weekend():
		time_label.modulate = Color(1.0, 0.6, 0.6, 1.0)
	else:
		time_label.modulate = Color.WHITE

func update_balance_ui(amount):
	balance_label.text = "$ " + str(amount)
	
	if amount < 0:
		balance_label.modulate = Color.RED
	else:
		balance_label.modulate = Color.GREEN

# --- ОСТАЛЬНАЯ ЛОГИКА ---

func show_employee_card(data: EmployeeData):
	name_label.text = "Имя: " + data.employee_name
	role_label.text = "Должность: " + data.job_title
	salary_label.text = "Ставка: " + str(data.monthly_salary) + "$/месяц"
	info_panel.visible = true

func _on_close_button_pressed():
	info_panel.visible = false

func open_boss_menu():
	if not ProjectManager.can_take_more():
		print("Босс: Слишком много активных проектов! (макс: ", ProjectManager.MAX_PROJECTS, ")")
		return
	selection_ui.open_selection()

func open_work_menu():
	if ProjectManager.active_projects.is_empty():
		print("Компьютер: Нет активных проектов.")
		return
	project_list_menu.open_menu()

func _on_project_taken(proj_data):
	var today = GameTime.day
	var old_created = proj_data.created_at_day
	
	if today != old_created:
		var shift = today - old_created
		proj_data.created_at_day = today
		proj_data.deadline_day += shift
		proj_data.soft_deadline_day += shift
	
	ProjectManager.add_project(proj_data)
	
	# XP за взятие проекта
	PMData.add_xp(5)
	print("🎯 PM +5 XP за взятие проекта")

func _on_project_list_opened(proj_data: ProjectData):
	project_window.setup(proj_data, employee_selector)
	project_window.visible = true

func _on_bottom_tab_pressed(tab_name: String):
	match tab_name:
		"employees":
			if employee_roster.visible:
				employee_roster.visible = false
			else:
				pm_skill_tree.visible = false
				employee_roster.open()
		"pm_skills":
			if pm_skill_tree.visible:
				pm_skill_tree.visible = false
			else:
				employee_roster.visible = false
				pm_skill_tree.open()

func _on_end_day_pressed():
	if GameTime.is_night_skip: return
	end_day_button.visible = false
	
	# --- Платим зарплаты ПЕРЕД показом отчёта ---
	GameState.pay_daily_salaries()
	
	# --- Открываем итоги дня (ставит паузу внутри) ---
	if _day_summary:
		_day_summary.open()
	else:
		GameTime.start_night_skip()

func _on_work_ended_show_end_day():
	end_day_button.visible = true

func _on_work_started_hide_end_day():
	end_day_button.visible = false

func _on_new_day(_day_number):
	end_day_button.visible = false

func _on_night_skip_started():
	end_day_button.visible = false

func _on_night_skip_finished():
	end_day_button.visible = false
