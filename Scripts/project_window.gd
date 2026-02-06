extends Control

# --- ССЫЛКИ НА UI ---
@onready var title_label = $MainLayout/HeaderPanel/TitleLabel
@onready var close_window_btn = $MainLayout/HeaderPanel/CloseButton
@onready var deadline_label = $MainLayout/ContentWrapper/Body/InfoRow/DeadlineLabel
@onready var budget_label = $MainLayout/ContentWrapper/Body/InfoRow/BudgetLabel
@onready var timeline_header = $MainLayout/ContentWrapper/Body/TableHeader/TimelineHeader
@onready var tracks_container = $MainLayout/ContentWrapper/Body/TracksContainer
@onready var start_btn = $MainLayout/ContentWrapper/Body/Footer/StartButton
@onready var cancel_btn = $MainLayout/ContentWrapper/Body/Footer/CancelButton

@export var track_scene: PackedScene 

# --- ДАННЫЕ ---
var project: ProjectData
var selector_ref
var current_selecting_track_index: int = -1

# [НАСТРОЙКИ ВИЗУАЛА]
const GANTT_VIEW_WIDTH = 900.0 
var current_time_line: ColorRect

func setup(data: ProjectData, selector_node):
	project = data
	selector_ref = selector_node
	
	title_label.text = project.title
	budget_label.text = "Бюджет: $%d" % project.budget
	deadline_label.text = "Дедлайн: %d дн." % project.deadline_day
	
	# Очистка
	for child in tracks_container.get_children():
		tracks_container.remove_child(child)
		child.queue_free() 
	
	for i in range(project.stages.size()):
		var stage = project.stages[i]
		if not stage.has("plan_start"):
			stage["plan_start"] = 0.0
			stage["plan_duration"] = 0.0
			stage["actual_start"] = -1.0
			stage["actual_end"] = -1.0
			stage["is_completed"] = false
			
		var new_track = track_scene.instantiate()
		tracks_container.add_child(new_track)
		new_track.setup(i, stage)
		new_track.assignment_requested.connect(_on_track_assignment_requested)
	
	if not selector_ref.employee_selected.is_connected(_on_employee_chosen):
		selector_ref.employee_selected.connect(_on_employee_chosen)

	update_buttons_visibility()
	create_time_line_if_needed()

	# Превью графика
	call_deferred("recalculate_schedule_preview")

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	cancel_btn.pressed.connect(_on_cancel_pressed)
	start_btn.pressed.connect(_on_start_pressed)
	close_window_btn.pressed.connect(func(): visible = false)

func update_buttons_visibility():
	if project.state == ProjectData.State.IN_PROGRESS:
		start_btn.visible = false
		cancel_btn.visible = false
	else:
		start_btn.visible = true
		cancel_btn.visible = true

# --- ХЕЛПЕР: Получаем точное время ---
func get_current_global_time() -> float:
	var day_part = float(GameTime.hour) / 24.0
	var min_part = float(GameTime.minute) / (24.0 * 60.0)
	return float(GameTime.day) + day_part + min_part

func _on_start_pressed():
	freeze_plan()
	
	# Записываем старт
	var now = get_current_global_time()
	project.start_global_time = now
	
	project.state = project.State.IN_PROGRESS
	print("КНОПКА СТАРТ: Записано время старта: ", project.start_global_time)
	
	update_buttons_visibility()

func _on_cancel_pressed():
	visible = false

# --- 1. ЛОГИКА РАБОТЫ ---
func _physics_process(delta):
	if not project or project.state != ProjectData.State.IN_PROGRESS:
		return
	
	var now = get_current_global_time()
	
	# САМОКОРРЕКЦИЯ (на всякий случай)
	if project.start_global_time < 0.01:
		project.start_global_time = now
		print("!!! САМОКОРРЕКЦИЯ ВРЕМЕНИ !!!")
	
	project.elapsed_days = now - project.start_global_time
	
	var is_working_hours = GameTime.hour >= GameTime.START_HOUR and GameTime.hour < GameTime.END_HOUR
	
	var active_stage = null
	for i in range(project.stages.size()):
		var stage = project.stages[i]
		if stage.get("is_completed", false): continue
		
		var prev_ok = true
		if i > 0: prev_ok = project.stages[i-1].get("is_completed", false)
		
		if prev_ok:
			active_stage = stage
			break 
	
	if active_stage:
		if active_stage["actual_start"] == -1.0:
			active_stage["actual_start"] = project.elapsed_days
		
		if is_working_hours and active_stage.worker:
			var worker_node = get_employee_node(active_stage.worker)
			
			# --- ИСПРАВЛЕНИЕ: ПРОГРЕСС ИДЕТ ТОЛЬКО ЕСЛИ СОТРУДНИК СИДИТ ЗА СТОЛОМ ---
			if worker_node and worker_node.current_state == worker_node.State.WORKING:
				var skill = get_skill_for_stage(active_stage.type, active_stage.worker)
				var efficiency = active_stage.worker.get_efficiency_multiplier()
				
				var speed_per_second = (float(skill) * efficiency) / 60.0
				active_stage.progress += speed_per_second * delta
			
		if active_stage.progress >= active_stage.amount:
			active_stage.progress = active_stage.amount
			active_stage["is_completed"] = true
			active_stage["actual_end"] = project.elapsed_days

	else:
		finish_project()

func finish_project():
	if project.state == ProjectData.State.FINISHED:
		return 
		
	print("ПРОЕКТ ПОЛНОСТЬЮ ЗАВЕРШЕН!")
	project.state = ProjectData.State.FINISHED
	GameState.change_balance(project.budget)
	
	var timer = get_tree().create_timer(1.0)
	await timer.timeout
	visible = false

# --- 2. ВИЗУАЛИЗАЦИЯ ---
func _process(delta):
	if not project: return
	if project.state == ProjectData.State.DRAFTING: return

	var horizon_days = max(project.deadline_day * 1.1, project.elapsed_days + 2.0)
	var pixels_per_day = GANTT_VIEW_WIDTH / horizon_days
	
	for i in range(project.stages.size()):
		if i < tracks_container.get_child_count():
			var stage = project.stages[i]
			var track_node = tracks_container.get_child(i)
			var stage_color = get_color_for_stage(stage.type)
			track_node.update_visuals_dynamic(pixels_per_day, project.elapsed_days, stage_color)
			
			var percent = 0.0
			if stage.amount > 0:
				percent = float(stage.progress) / float(stage.amount)
			track_node.update_progress(percent)
	
	# [ИСПРАВЛЕНИЕ 1] Позиция красной линии
	if current_time_line:
		# Мы УБРАЛИ offset_x, потому что TimelineHeader уже выровнен с графиком (судя по цифрам)
		# ЕслиElapsed = 0, то линия будет на 0 (начало графика).
		current_time_line.position.x = (project.elapsed_days * pixels_per_day)
		
		# Растягиваем
		current_time_line.size.y = max(tracks_container.size.y + 50, 500) 
		current_time_line.visible = true
		
	# Хедер
	draw_dynamic_header(pixels_per_day, horizon_days)

# --- ВСПОМОГАТЕЛЬНЫЕ ---

func create_time_line_if_needed():
	if not current_time_line:
		current_time_line = ColorRect.new()
		current_time_line.color = Color(1, 0, 0, 0.8)
		current_time_line.size = Vector2(2, 500) 
		current_time_line.z_index = 100
		current_time_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		timeline_header.add_child(current_time_line)

func freeze_plan():
	var current_time_offset_days = 0.0
	for stage in project.stages:
		stage["plan_start"] = current_time_offset_days
		
		var duration_days = 1.0
		if stage.worker:
			var skill = get_skill_for_stage(stage.type, stage.worker)
			if skill < 1: skill = 1
			
			var total_work_hours = float(stage.amount) / float(skill)
			duration_days = total_work_hours / 9.0 
		
		stage["plan_duration"] = duration_days
		current_time_offset_days += duration_days

func draw_dynamic_header(px_per_day, horizon_days):
	for child in timeline_header.get_children():
		if child == current_time_line: continue
		child.queue_free()
	
	var step = 1
	
	for i in range(0, int(horizon_days) + 1, step):
		var lbl = Label.new()
		
		# [ИСПРАВЛЕНИЕ 2] Визуально начинаем с 1-го дня (i + 1)
		# [ИСПРАВЛЕНИЕ 2] Визуально начинаем с 1-го дня (i + 1)
		# Компьютер считает от 0, но люди любят начинать с 1
		lbl.text = str(i + 1)
		
		lbl.modulate = Color(0, 0, 0, 0.5)
		lbl.position = Vector2(i * px_per_day + 2, 0)
		timeline_header.add_child(lbl)
		
		var line = ColorRect.new()
		line.color = Color(0.0, 0.0, 0.0, 0.1)
		line.size = Vector2(1, 1000)
		line.position = Vector2(i * px_per_day, 15)
		line.z_index = -1
		timeline_header.add_child(line)

func get_employee_node(data):
	if not data: return null
	for npc in get_tree().get_nodes_in_group("npc"):
		if npc.data == data: return npc
	return null

func recalculate_schedule_preview():
	if project.state == ProjectData.State.IN_PROGRESS: return
	var current_offset = 0.0 
	var preview_px_per_day = 50.0 
	var all_assigned = true
	
	for i in range(project.stages.size()):
		var stage = project.stages[i]
		var track_node = tracks_container.get_child(i)
		
		if stage.worker:
			var skill = get_skill_for_stage(stage.type, stage.worker)
			if skill < 1: skill = 1
			var duration_days = (float(stage.amount) / float(skill)) / 9.0
			
			var color = get_color_for_stage(stage.type)
			track_node.update_bar_preview(current_offset * preview_px_per_day, duration_days * preview_px_per_day, color)
			current_offset += duration_days
		else:
			all_assigned = false
			track_node.update_bar_preview(0, 0, Color.WHITE)
			
	start_btn.disabled = not all_assigned

func get_skill_for_stage(type, worker):
	match type:
		"BA": return worker.skill_business_analysis
		"DEV": return worker.skill_backend
		"QA": return worker.skill_qa
	return 10

func get_color_for_stage(type):
	match type:
		"BA": return Color("FFA500") 
		"DEV": return Color("6495ED") 
		"QA": return Color("98FB98") 
	return Color.GRAY
	
func _on_track_assignment_requested(index):
	if project.state == ProjectData.State.IN_PROGRESS: return
	current_selecting_track_index = index
	selector_ref.open_list()

func _on_employee_chosen(emp_data):
	if current_selecting_track_index != -1:
		project.stages[current_selecting_track_index].worker = emp_data
		var track_node = tracks_container.get_child(current_selecting_track_index)
		track_node.update_button_visuals()
		recalculate_schedule_preview()
