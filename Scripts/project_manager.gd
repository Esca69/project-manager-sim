extends Node

# --- МАССИВ ВСЕХ АКТИВНЫХ ПРОЕКТОВ ---
var active_projects: Array = []

# Максимум одновременных проектов (можно менять для баланса)
const MAX_PROJECTS = 5

# Сигнал — проект завершён (для UI-уведомлений в будущем)
signal project_finished(proj: ProjectData)

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

# --- ДОБАВИТЬ ПРОЕКТ ---
func add_project(proj: ProjectData):
	if active_projects.size() >= MAX_PROJECTS:
		print("⚠ Максимум проектов достигнут! (", MAX_PROJECTS, ")")
		return false
	active_projects.append(proj)
	print("📋 Проект добавлен: ", proj.title, " (всего: ", active_projects.size(), ")")
	return true

# --- ПРОВЕРКА ЛИМИТА ---
func can_take_more() -> bool:
	return active_projects.size() < MAX_PROJECTS

# --- ХЕЛПЕР: Получаем точное время (копия из project_window) ---
func get_current_global_time() -> float:
	var day_part = float(GameTime.hour) / 24.0
	var min_part = float(GameTime.minute) / (24.0 * 60.0)
	return float(GameTime.day) + day_part + min_part

# --- ТИКАНИЕ ВСЕХ ПРОЕКТОВ ---
func _physics_process(delta):
	for project in active_projects:
		if project.state != ProjectData.State.IN_PROGRESS:
			continue
		
		var now = get_current_global_time()
		
		if project.start_global_time < 0.01:
			project.start_global_time = now
		
		project.elapsed_days = now - project.start_global_time
		
		var is_working_hours = GameTime.hour >= GameTime.START_HOUR and GameTime.hour < GameTime.END_HOUR
		
		# Ищем активный этап
		var active_stage = null
		for i in range(project.stages.size()):
			var stage = project.stages[i]
			if stage.get("is_completed", false):
				continue
			
			var prev_ok = true
			if i > 0:
				prev_ok = project.stages[i - 1].get("is_completed", false)
			
			if prev_ok:
				active_stage = stage
				break
		
		if active_stage:
			if active_stage["actual_start"] == -1.0:
				active_stage["actual_start"] = project.elapsed_days
			
			if is_working_hours and active_stage.workers.size() > 0:
				for worker_data in active_stage.workers:
					var worker_node = _get_employee_node(worker_data)
					
					if worker_node and worker_node.current_state == worker_node.State.WORKING:
						var skill = _get_skill_for_stage(active_stage.type, worker_data)
						var efficiency = worker_data.get_efficiency_multiplier()
						
						var speed_per_second = (float(skill) * efficiency) / 60.0
						active_stage.progress += speed_per_second * delta
			
			if active_stage.progress >= active_stage.amount:
				active_stage.progress = active_stage.amount
				active_stage["is_completed"] = true
				active_stage["actual_end"] = project.elapsed_days
		
		else:
			# Все этапы завершены
			_finish_project(project)

func _finish_project(project: ProjectData):
	if project.state == ProjectData.State.FINISHED:
		return
	
	print("🎉 ПРОЕКТ ПОЛНОСТЬЮ ЗАВЕРШЕН: ", project.title)
	project.state = ProjectData.State.FINISHED
	GameState.change_balance(project.budget)
	emit_signal("project_finished", project)

# --- ВСПОМОГАТЕЛЬНЫЕ ---
func _get_employee_node(data):
	if not data:
		return null
	for npc in get_tree().get_nodes_in_group("npc"):
		if npc.data == data:
			return npc
	return null

func _get_skill_for_stage(type, worker):
	match type:
		"BA": return worker.skill_business_analysis
		"DEV": return worker.skill_backend
		"QA": return worker.skill_qa
	return 10

# --- ПРОВЕРКА: назначен ли сотрудник на активный этап ЛЮБОГО проекта ---
func is_employee_on_active_stage(emp_data: EmployeeData) -> bool:
	for project in active_projects:
		if project.state != ProjectData.State.IN_PROGRESS:
			continue
		
		# Ищем текущий активный этап
		var active_stage = null
		for i in range(project.stages.size()):
			var stage = project.stages[i]
			if stage.get("is_completed", false):
				continue
			var prev_ok = true
			if i > 0:
				prev_ok = project.stages[i - 1].get("is_completed", false)
			if prev_ok:
				active_stage = stage
				break
		
		if active_stage:
			for worker_data in active_stage.workers:
				if worker_data == emp_data:
					return true
	
	return false
