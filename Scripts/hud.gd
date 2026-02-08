extends CanvasLayer

# --- ССЫЛКИ НА НОВЫЙ ИНТЕРФЕЙС (ВЕРХНЯЯ ПАНЕЛЬ) ---
# Пути могут отличаться, если вы назвали узлы иначе. Проверьте в редакторе!
@onready var time_label = $TopBar/MarginContainer/HBoxContainer/TimeLabel
@onready var balance_label = $TopBar/MarginContainer/HBoxContainer/BalanceLabel

# Кнопки скорости
@onready var btn_pause = $TopBar/MarginContainer/HBoxContainer/SpeedControls/PauseBtn
@onready var btn_1x = $TopBar/MarginContainer/HBoxContainer/SpeedControls/Speed1Btn
@onready var btn_2x = $TopBar/MarginContainer/HBoxContainer/SpeedControls/Speed2Btn
@onready var btn_5x = $TopBar/MarginContainer/HBoxContainer/SpeedControls/Speed5Btn

# --- ССЫЛКИ НА ОКНА (Оставляем как было) ---
@onready var info_panel = $Panel 
@onready var name_label = $Panel/VBoxContainer/NameLabel
@onready var role_label = $Panel/VBoxContainer/RoleLabel
@onready var salary_label = $Panel/VBoxContainer/SalaryLabel

@onready var selection_ui = $ProjectSelectionUI
@onready var project_window = $ProjectWindow
@onready var employee_selector = $EmployeeSelector
@onready var end_day_button = $EndDayButton

# --- СОСТОЯНИЕ ---
var active_project: ProjectData = null

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Скрываем окна при старте
	info_panel.visible = false
	selection_ui.visible = false
	project_window.visible = false
	employee_selector.visible = false
	end_day_button.visible = false
	
	# --- ПОДКЛЮЧЕНИЕ СИГНАЛОВ ---
	GameTime.time_tick.connect(update_time_label)
	GameTime.work_ended.connect(_on_work_ended_show_end_day)
	GameTime.work_started.connect(_on_work_started_hide_end_day)
	GameTime.night_skip_started.connect(_on_night_skip_started)
	GameTime.night_skip_finished.connect(_on_night_skip_finished)
	GameState.balance_changed.connect(update_balance_ui)
	
	end_day_button.pressed.connect(_on_end_day_pressed)
	
	if not selection_ui.project_selected.is_connected(_on_project_taken):
		selection_ui.project_selected.connect(_on_project_taken)
	
	# --- [НОВОЕ] ПОДКЛЮЧЕНИЕ КНОПОК СКОРОСТИ ---
	# Мы используем функции из GameTime
	btn_pause.pressed.connect(func(): GameTime.speed_pause())
	btn_1x.pressed.connect(func(): GameTime.speed_1x())
	btn_2x.pressed.connect(func(): GameTime.speed_2x())
	btn_5x.pressed.connect(func(): GameTime.speed_5x())
	
	# Инициализация UI
	update_balance_ui(GameState.company_balance)
	# Можно вызвать один раз, чтобы часы не были пустыми до первой минуты
	update_time_label(GameTime.hour, GameTime.minute)

# --- ОБНОВЛЕНИЕ ИНТЕРФЕЙСА ---

func update_time_label(hour, minute):
	# Формат: "День 5, 08:30"
	var time_str = "%02d:%02d" % [hour, minute]
	time_label.text = "День " + str(GameTime.day) + ", " + time_str

func update_balance_ui(amount):
	# Формат: "$ 10500"
	balance_label.text = "$ " + str(amount)
	
	# Опционально: Красить в красный, если минус
	if amount < 0:
		balance_label.modulate = Color.RED
	else:
		balance_label.modulate = Color.GREEN # Или Color.WHITE

# --- ОСТАЛЬНАЯ ЛОГИКА (БЕЗ ИЗМЕНЕНИЙ) ---

func show_employee_card(data: EmployeeData):
	name_label.text = "Имя: " + data.employee_name
	role_label.text = "Должность: " + data.job_title
	salary_label.text = "Ставка: " + str(data.monthly_salary) + "$/месяц"
	info_panel.visible = true

func _on_close_button_pressed():
	info_panel.visible = false

func open_boss_menu():
	if active_project and active_project.state != ProjectData.State.FINISHED and active_project.state != ProjectData.State.FAILED:
		print("Босс: Сначала закончи текущий проект!")
		return
	selection_ui.open_selection()

func open_work_menu():
	if active_project:
		project_window.setup(active_project, employee_selector)
		project_window.visible = true
	else:
		print("Компьютер: Нет активных проектов.")

func _on_project_taken(proj_data):
	active_project = proj_data
	selection_ui.visible = false

func _on_end_day_pressed():
	if GameTime.is_night_skip: return
	end_day_button.visible = false
	GameTime.start_night_skip()

func _on_work_ended_show_end_day():
	end_day_button.visible = true

func _on_work_started_hide_end_day():
	end_day_button.visible = false

func _on_night_skip_started():
	end_day_button.visible = false

func _on_night_skip_finished():
	end_day_button.visible = false
