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
var soft_deadline_line: ColorRect
var hard_deadline_line: ColorRect

func setup(data: ProjectData, selector_node):
	project = data
	selector_ref = selector_node
	
	title_label.text = project.title
	budget_label.text = "Бюджет: $%d" % project.budget
	
	# [ИЗМЕНЕНИЕ] Дедлайн теперь показывает дату
	var deadline_date = GameTime.get_date_short(project.deadline_day)
	var days_left = project.deadline_day - GameTime.day
	deadline_label.text = "Дедлайн: %s (ост. %d дн.)" % [deadline_date, days_left]
	
	# Очистка
	for child in tracks_container.get_children():
		tracks_container.remove_child(child)
		child.queue_free() 
	
	for i in range(project.stages.size()):
		var stage = project.stages[i]
		
		_migrate_stage(stage)
		
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
		new_track.worker_removed.connect(_on_worker_removed)
	
	if not selector_ref.employee_selected.is_connected(_on_employee_chosen):
		selector_ref.employee_selected.connect(_on_employee_chosen)

	update_buttons_visibility()
	create_time_line_if_needed()

	call_deferred("recalculate_schedule_preview")

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	cancel_btn.pressed.connect(_on_cancel_pressed)
	start_btn.pressed.connect(_on_start_pressed)
	close_window_btn.pressed.connect(func(): visible = false)

func _migrate_stage(stage: Dictionary):
	if stage.has("worker"):
		if not stage.has("workers"):
			stage["workers"] = []
		if stage["worker"] != null and stage["worker"] not in stage["workers"]:
			stage["workers"].append(stage["worker"])
		stage.erase("worker")
	if not stage.has("workers"):
		stage["workers"] = []

func update_buttons_visibility():
	if project.state == ProjectData.State.IN_PROGRESS or project.state == ProjectData.State.FINISHED:
		start_btn.visible = false
		cancel_btn.visible = false
	else:
		start_btn.visible = true
		cancel_btn.visible = true

func get_current_global_time() -> float:
	var day_part = float(GameTime.hour) / 24.0
	var min_part = float(GameTime.minute) / (24.0 * 60.0)
	return float(GameTime.day) + day_part + min_part

func _on_start_pressed():
	freeze_plan()
	
	var now = get_current_global_time()
	project.start_global_time = now
	
	project.state = project.State.IN_PROGRESS
	print("КНОПКА СТАРТ: Записано время старта: ", project.start_global_time)
	
	update_buttons_visibility()

func _on_cancel_pressed():
	visible = false

# --- ВИЗУАЛИЗАЦИЯ ---
func _process(delta):
	if not project: return
	if not visible: return
	
	var origin_day = project.created_at_day
	
	if project.state == ProjectData.State.DRAFTING:
		var horizon_from_origin = float(project.deadline_day - origin_day) * 1.1
		if horizon_from_origin < 5.0:
			horizon_from_origin = 5.0
		var pixels_per_day = GANTT_VIEW_WIDTH / horizon_from_origin
		
		if current_time_line:
			current_time_line.visible = false
		
		var line_height = max(tracks_container.size.y + 50, 500)
		
		if soft_deadline_line and project.soft_deadline_day > 0:
			var soft_offset = float(project.soft_deadline_day - origin_day)
			soft_deadline_line.position.x = soft_offset * pixels_per_day
			soft_deadline_line.size.y = line_height
			soft_deadline_line.visible = true
		
		if hard_deadline_line and project.deadline_day > 0:
			var hard_offset = float(project.deadline_day - origin_day)
			hard_deadline_line.position.x = hard_offset * pixels_per_day
			hard_deadline_line.size.y = line_height
			hard_deadline_line.visible = true
		
		draw_dynamic_header(pixels_per_day, horizon_from_origin, origin_day)
		return
	
	# --- Проект IN_PROGRESS или FINISHED ---
	var now = get_current_global_time()
	if project.start_global_time > 0.01:
		project.elapsed_days = now - project.start_global_time

	var horizon_from_origin = max(float(project.deadline_day - origin_day) * 1.1, project.elapsed_days + 2.0)
	var pixels_per_day = GANTT_VIEW_WIDTH / horizon_from_origin
	
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
	
	var line_height = max(tracks_container.size.y + 50, 500)
	
	if current_time_line:
		current_time_line.position.x = project.elapsed_days * pixels_per_day
		current_time_line.size.y = line_height
		current_time_line.visible = true
	
	if soft_deadline_line and project.soft_deadline_day > 0:
		var soft_offset = float(project.soft_deadline_day - origin_day)
		soft_deadline_line.position.x = soft_offset * pixels_per_day
		soft_deadline_line.size.y = line_height
		soft_deadline_line.visible = true
	
	if hard_deadline_line and project.deadline_day > 0:
		var hard_offset = float(project.deadline_day - origin_day)
		hard_deadline_line.position.x = hard_offset * pixels_per_day
		hard_deadline_line.size.y = line_height
		hard_deadline_line.visible = true
		
	draw_dynamic_header(pixels_per_day, horizon_from_origin, origin_day)

# --- ВСПОМОГАТЕЛЬНЫЕ ---

func create_time_line_if_needed():
	if not current_time_line:
		current_time_line = ColorRect.new()
		current_time_line.color = Color(0, 0.4, 1, 0.8)
		current_time_line.size = Vector2(2, 500)
		current_time_line.z_index = 100
		current_time_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		timeline_header.add_child(current_time_line)
	
	if not soft_deadline_line:
		soft_deadline_line = ColorRect.new()
		soft_deadline_line.color = Color(1, 0.65, 0, 0.8)
		soft_deadline_line.size = Vector2(2, 500)
		soft_deadline_line.z_index = 99
		soft_deadline_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		soft_deadline_line.visible = false
		timeline_header.add_child(soft_deadline_line)
	
	if not hard_deadline_line:
		hard_deadline_line = ColorRect.new()
		hard_deadline_line.color = Color(1, 0, 0, 0.8)
		hard_deadline_line.size = Vector2(2, 500)
		hard_deadline_line.z_index = 99
		hard_deadline_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hard_deadline_line.visible = false
		timeline_header.add_child(hard_deadline_line)

func freeze_plan():
	var current_time_offset_days = 0.0
	for stage in project.stages:
		stage["plan_start"] = current_time_offset_days
		
		var duration_days = 1.0
		var total_skill = get_total_skill_for_stage(stage)
		if total_skill > 0:
			var total_work_hours = float(stage.amount) / float(total_skill)
			duration_days = total_work_hours / 9.0 
		
		stage["plan_duration"] = duration_days
		current_time_offset_days += duration_days

# --- [ИЗМЕНЕНИЕ] Двухуровневый хедер: месяцы сверху, дни снизу, выходные затенены ---
func draw_dynamic_header(px_per_day, horizon_days, origin_day: int = 0):
	for child in timeline_header.get_children():
		if child == current_time_line: continue
		if child == soft_deadline_line: continue
		if child == hard_deadline_line: continue
		child.queue_free()
	
	var line_height = max(tracks_container.size.y + 80, 500)
	var prev_month = -1
	
	for i in range(0, int(horizon_days) + 1):
		var abs_day = origin_day + i
		var day_in_month = GameTime.get_day_in_month(abs_day)
		var month_num = GameTime.get_month(abs_day)
		var weekday = GameTime.get_weekday_name(abs_day)
		var is_wknd = GameTime.is_weekend(abs_day)
		
		var x_pos = float(i) * px_per_day
		
		# --- Подсветка выходных (серый фон на всю высоту) ---
		if is_wknd:
			var wknd_bg = ColorRect.new()
			wknd_bg.color = Color(0.0, 0.0, 0.0, 0.06)
			wknd_bg.size = Vector2(px_per_day, line_height)
			wknd_bg.position = Vector2(x_pos, 0)
			wknd_bg.z_index = -2
			wknd_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			timeline_header.add_child(wknd_bg)
		
		# --- Верхний уровень: полоска месяца (рисуем при смене месяца) ---
		if month_num != prev_month:
			var month_lbl = Label.new()
			month_lbl.text = "Мес. " + str(month_num)
			month_lbl.add_theme_font_size_override("font_size", 11)
			month_lbl.modulate = Color(0.17, 0.31, 0.57, 0.8)
			month_lbl.position = Vector2(x_pos + 2, -2)
			timeline_header.add_child(month_lbl)
			
			# Жирная линия границы месяца
			if prev_month != -1:
				var month_line = ColorRect.new()
				month_line.color = Color(0.17, 0.31, 0.57, 0.4)
				month_line.size = Vector2(2, line_height)
				month_line.position = Vector2(x_pos, 0)
				month_line.z_index = -1
				month_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
				timeline_header.add_child(month_line)
			
			prev_month = month_num
		
		# --- Нижний уровень: номер дня + день недели ---
		var day_lbl = Label.new()
		day_lbl.text = str(day_in_month)
		day_lbl.add_theme_font_size_override("font_size", 11)
		
		if is_wknd:
			day_lbl.modulate = Color(0.8, 0.3, 0.3, 0.7)
		else:
			day_lbl.modulate = Color(0, 0, 0, 0.5)
		
		day_lbl.position = Vector2(x_pos + 2, 12)
		timeline_header.add_child(day_lbl)
		
		# День недели (только если хватает места — px_per_day > 25)
		if px_per_day > 25:
			var wd_lbl = Label.new()
			wd_lbl.text = weekday
			wd_lbl.add_theme_font_size_override("font_size", 9)
			wd_lbl.modulate = Color(0, 0, 0, 0.35)
			wd_lbl.position = Vector2(x_pos + 2, 24)
			timeline_header.add_child(wd_lbl)
		
		# Тонкая вертикальная линия дня
		var line = ColorRect.new()
		line.color = Color(0.0, 0.0, 0.0, 0.08)
		line.size = Vector2(1, line_height)
		line.position = Vector2(x_pos, 35)
		line.z_index = -1
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		timeline_header.add_child(line)

func get_employee_node(data):
	if not data: return null
	for npc in get_tree().get_nodes_in_group("npc"):
		if npc.data == data: return npc
	return null

func recalculate_schedule_preview():
	if project.state == ProjectData.State.IN_PROGRESS: return
	
	var origin_day = project.created_at_day
	var horizon_from_origin = float(project.deadline_day - origin_day) * 1.1
	if horizon_from_origin < 5.0:
		horizon_from_origin = 5.0
	var preview_px_per_day = GANTT_VIEW_WIDTH / horizon_from_origin
	
	var current_offset = 0.0 
	var all_assigned = true
	
	for i in range(project.stages.size()):
		var stage = project.stages[i]
		var track_node = tracks_container.get_child(i)
		
		if stage.workers.size() > 0:
			var total_skill = get_total_skill_for_stage(stage)
			if total_skill < 1: total_skill = 1
			var duration_days = (float(stage.amount) / float(total_skill)) / 9.0
			
			var color = get_color_for_stage(stage.type)
			track_node.update_bar_preview(current_offset * preview_px_per_day, duration_days * preview_px_per_day, color)
			current_offset += duration_days
		else:
			all_assigned = false
			track_node.update_bar_preview(0, 0, Color.WHITE)
			
	start_btn.disabled = not all_assigned

func get_total_skill_for_stage(stage: Dictionary) -> int:
	var total = 0
	for w in stage.workers:
		total += get_skill_for_stage(stage.type, w)
	return total

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
	current_selecting_track_index = index
	var stage_type = project.stages[index].type
	selector_ref.open_list(stage_type)

func _on_employee_chosen(emp_data):
	if current_selecting_track_index == -1: return
	
	var stage = project.stages[current_selecting_track_index]
	
	for existing_worker in stage.workers:
		if existing_worker == emp_data:
			print("⚠️ Этот сотрудник уже назначен на этот этап!")
			return
	
	stage.workers.append(emp_data)
	print("✅ Назначен: ", emp_data.employee_name, " на этап ", stage.type, " (всего: ", stage.workers.size(), ")")
	
	var track_node = tracks_container.get_child(current_selecting_track_index)
	track_node.update_button_visuals()
	recalculate_schedule_preview()

func _on_worker_removed(stage_index: int, worker_index: int):
	var stage = project.stages[stage_index]
	
	if worker_index < 0 or worker_index >= stage.workers.size():
		return
	
	var removed = stage.workers[worker_index]
	stage.workers.remove_at(worker_index)
	print("❌ Снят: ", removed.employee_name, " с этапа ", stage.type, " (осталось: ", stage.workers.size(), ")")
	
	var track_node = tracks_container.get_child(stage_index)
	track_node.update_button_visuals()
	recalculate_schedule_preview()
