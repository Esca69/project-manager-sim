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

# --- ПРОВЕРКА: ОТКРЫТО ЛИ КАКОЕ-ТО МЕНЮ ---
# Вызывается из player.gd, чтобы блокировать движение/взаимодействие
func is_any_menu_open() -> bool:
	if info_panel.visible: return true
	if selection_ui.visible: return true
	if project_window.visible: return true
	if employee_selector.visible: return true
	if project_list_menu.visible: return true
	if employee_roster.visible: return true
	
	# Проверяем HiringMenu и AssignmentMenu
	var hiring_menu = get_node_or_null("HiringMenu")
	if hiring_menu and hiring_menu.visible: return true
	
	var assignment_menu = get_node_or_null("AssignmentMenu")
	if assignment_menu and assignment_menu.visible: return true
	
	return false

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

# [ИСПРАВЛЕНИЕ] При взятии проекта — сдвигаем created_at_day на текущий день
# Дедлайны сдвигаются на ту же разницу, чтобы у игрока осталось столько же дней
func _on_project_taken(proj_data):
	var today = GameTime.day
	var old_created = proj_data.created_at_day
	
	if today != old_created:
		var shift = today - old_created
		proj_data.created_at_day = today
		proj_data.deadline_day += shift
		proj_data.soft_deadline_day += shift
	
	ProjectManager.add_project(proj_data)

func _on_project_list_opened(proj_data: ProjectData):
	project_window.setup(proj_data, employee_selector)
	project_window.visible = true

func _on_bottom_tab_pressed(tab_name: String):
	match tab_name:
		"employees":
			if employee_roster.visible:
				employee_roster.visible = false
			else:
				employee_roster.open()

func _on_end_day_pressed():
	if GameTime.is_night_skip: return
	end_day_button.visible = false
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
