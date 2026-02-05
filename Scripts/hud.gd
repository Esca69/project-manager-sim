extends CanvasLayer

# --- ССЫЛКИ НА СТАРУЮ КАРТОЧКУ СОТРУДНИКА ---
# (Убедись, что в сцене HUD у тебя есть Panel c этими Label внутри)
@onready var info_panel = $Panel 
@onready var name_label = $Panel/VBoxContainer/NameLabel
@onready var role_label = $Panel/VBoxContainer/RoleLabel
@onready var salary_label = $Panel/VBoxContainer/SalaryLabel

# --- ССЫЛКИ НА НОВЫЕ ОКНА ---
@onready var time_label = $TimeLabel
@onready var selection_ui = $ProjectSelectionUI
@onready var project_window = $ProjectWindow
@onready var employee_selector = $EmployeeSelector
@onready var balance_label = $BalanceLabel

# --- СОСТОЯНИЕ ---
var active_project: ProjectData = null

func _ready():
	# 1. САМОЕ ВАЖНОЕ: Скрываем вообще все окна при старте
	info_panel.visible = false
	selection_ui.visible = false
	project_window.visible = false
	employee_selector.visible = false
	
	# 2. Подключаем сигналы
	GameTime.time_tick.connect(update_time_label)
	
	# Если мы что-то выбрали в меню босса -> запоминаем это
	if not selection_ui.project_selected.is_connected(_on_project_taken):
		selection_ui.project_selected.connect(_on_project_taken)
	
	
	# Показываем баланс сразу при старте
	update_balance_ui(GameState.company_balance)
	
	# Подписываемся на изменения баланса
	GameState.balance_changed.connect(update_balance_ui)

# --- ЧАСЫ ---
func update_time_label(hour, minute):
	var time_str = "%02d:%02d" % [hour, minute]
	time_label.text = "День " + str(GameTime.day) + ", " + time_str

# --- ЛОГИКА 1: ПОКАЗАТЬ КАРТОЧКУ СОТРУДНИКА (Старая функция) ---
# Ее вызывает Player, когда тычет в NPC
func show_employee_card(data: EmployeeData):
	name_label.text = "Имя: " + data.employee_name
	role_label.text = "Должность: " + data.job_title
	salary_label.text = "Ставка: " + str(data.monthly_salary) + "$/месяц"
	
	info_panel.visible = true

# Кнопка закрытия внутри панели (если есть)
func _on_close_button_pressed():
	info_panel.visible = false

# --- ЛОГИКА 2: СТОЛ БОССА ---
func open_boss_menu():
	# Проверяем: если проект есть И он не завершен и не провален
	if active_project and active_project.state != ProjectData.State.FINISHED and active_project.state != ProjectData.State.FAILED:
		print("Босс: Сначала закончи (или сдай) текущий проект!")
		return
	
	selection_ui.open_selection()

# --- ЛОГИКА 3: ТВОЙ СТОЛ ---
func open_work_menu():
	if active_project:
		# Передаем проект и селектор в окно управления
		project_window.setup(active_project, employee_selector)
		project_window.visible = true
	else:
		print("Компьютер: Нет активных проектов. Сходи к Боссу.")

# --- ОБРАБОТЧИК: КОГДА ВЗЯЛИ ПРОЕКТ У БОССА ---
func _on_project_taken(proj_data):
	active_project = proj_data
	print("Новый проект: " + proj_data.title)
	# Меню выбора закроется само (внутри своего скрипта), но можно продублировать:
	selection_ui.visible = false

# Функция отрисовки денег
func update_balance_ui(amount):
	balance_label.text = str(amount) + " $"
