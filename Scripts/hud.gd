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
@onready var client_panel = $ClientPanel

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
	client_panel.visible = false

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

func _on_bottom_tab_pressed(tab_name: String):
	match tab_name:
		"employees":
			employee_roster.open()
		"pm_skills":
			pm_skill_tree.visible = !pm_skill_tree.visible
		"clients":
			client_panel.open()

func update_time_label(h, m):
	var day_str = GameTime.get_date_string()
	time_label.text = day_str + " | %02d:%02d" % [h, m]

func update_balance_ui(amount):
	balance_label.text = "$%d" % amount

func _on_project_taken(data: ProjectData):
	print("📥 Получен проект: ", data.title)
	ProjectManager.add_project(data)
	project_window.setup(data, employee_selector)
	if UITheme:
		UITheme.fade_in(project_window, 0.2)
	else:
		project_window.visible = true

func _on_project_list_opened(proj: ProjectData):
	project_window.setup(proj, employee_selector)
	if UITheme:
		UITheme.fade_in(project_window, 0.2)
	else:
		project_window.visible = true

func _on_work_ended_show_end_day():
	end_day_button.visible = true

func _on_work_started_hide_end_day():
	end_day_button.visible = false

func _on_end_day_pressed():
	GameState.pay_daily_salaries()
	end_day_button.visible = false
	if _day_summary:
		_day_summary.open()
	else:
		GameTime.start_night_skip()

func _on_night_skip_started():
	end_day_button.visible = false

func _on_night_skip_finished():
	end_day_button.visible = false

func _on_new_day(day_number):
	pass

# === PM LEVEL UI ===
func _build_pm_level_ui():
	var topbar_hbox = $TopBar/MarginContainer/HBoxContainer

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topbar_hbox.add_child(spacer)

	var pm_hbox = HBoxContainer.new()
	pm_hbox.add_theme_constant_override("separation", 8)
	topbar_hbox.add_child(pm_hbox)

	_pm_level_label = Label.new()
	_pm_level_label.text = "PM Lv.1"
	_pm_level_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_pm_level_label.add_theme_font_size_override("font_size", 13)
	if UITheme: UITheme.apply_font(_pm_level_label, "bold")
	pm_hbox.add_child(_pm_level_label)

	_pm_xp_bar = ProgressBar.new()
	_pm_xp_bar.min_value = 0
	_pm_xp_bar.max_value = 100
	_pm_xp_bar.value = 0
	_pm_xp_bar.show_percentage = false
	_pm_xp_bar.custom_minimum_size = Vector2(100, 14)

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(1, 1, 1, 0.2)
	bg_style.corner_radius_top_left = 7
	bg_style.corner_radius_top_right = 7
	bg_style.corner_radius_bottom_right = 7
	bg_style.corner_radius_bottom_left = 7
	_pm_xp_bar.add_theme_stylebox_override("background", bg_style)

	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.95, 0.85, 0.2, 1)
	fill_style.corner_radius_top_left = 7
	fill_style.corner_radius_top_right = 7
	fill_style.corner_radius_bottom_right = 7
	fill_style.corner_radius_bottom_left = 7
	_pm_xp_bar.add_theme_stylebox_override("fill", fill_style)

	pm_hbox.add_child(_pm_xp_bar)

	_pm_xp_label = Label.new()
	_pm_xp_label.text = "0 / 50"
	_pm_xp_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	_pm_xp_label.add_theme_font_size_override("font_size", 11)
	if UITheme: UITheme.apply_font(_pm_xp_label, "regular")
	pm_hbox.add_child(_pm_xp_label)

	PMData.xp_changed.connect(_on_pm_xp_changed)

func _update_pm_level_ui():
	var level = PMData.get_level()
	_pm_level_label.text = "PM Lv.%d" % level

	var progress = PMData.get_level_progress()
	var current_in_level = progress[0]
	var needed_for_level = progress[1]

	_pm_xp_bar.max_value = max(needed_for_level, 1)
	_pm_xp_bar.value = current_in_level
	_pm_xp_label.text = "%d / %d" % [current_in_level, needed_for_level]

	if PMData.skill_points > 0:
		_pm_xp_label.text += "  (🔵 %d)" % PMData.skill_points

func _on_pm_xp_changed(new_xp, new_skill_points):
	_update_pm_level_ui()

func _on_project_finished_xp(proj: ProjectData):
	var base_xp = 15 if proj.category == "micro" else 30
	PMData.add_xp(base_xp)
	print("🎯 PM получил %d XP за завершение проекта '%s'" % [base_xp, proj.title])
