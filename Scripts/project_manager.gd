extends Node

var active_projects: Array = []

const MAX_PROJECTS = 5

signal project_finished(proj: ProjectData)
signal project_failed(proj: ProjectData)

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func add_project(proj: ProjectData):
	if count_active_projects() >= MAX_PROJECTS:
		print("⚠ Максимум активных проектов достигнут! (", MAX_PROJECTS, ")")
		return false
	active_projects.append(proj)
	print("📋 Проект добавлен: ", proj.title, " (всего: ", active_projects.size(), ")")
	return true

func can_take_more() -> bool:
	return count_active_projects() < MAX_PROJECTS

# Считаем только DRAFTING и IN_PROGRESS — завершённые и проваленные не в счёт
func count_active_projects() -> int:
	var count = 0
	for proj in active_projects:
		if proj.state == ProjectData.State.DRAFTING or proj.state == ProjectData.State.IN_PROGRESS:
			count += 1
	return count

func get_current_global_time() -> float:
	var day_part = float(GameTime.hour) / 24.0
	var min_part = float(GameTime.minute) / (24.0 * 60.0)
	return float(GameTime.day) + day_part + min_part

func _physics_process(delta):
	for project in active_projects:
		if project.state != ProjectData.State.IN_PROGRESS:
			continue

		var now = get_current_global_time()

		if project.start_global_time < 0.01:
			project.start_global_time = now

		project.elapsed_days = now - project.start_global_time

		# Хард-дедлайн: наступает когда day >= deadline_day (а не >)
		if GameTime.day >= project.deadline_day:
			_fail_project(project)
			continue

		var is_working_hours = GameTime.hour >= GameTime.START_HOUR and GameTime.hour < GameTime.END_HOUR

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
						var speed_mult = worker_data.get_work_speed_multiplier()
						var speed_per_second = (float(skill) * efficiency * speed_mult) / 60.0
						var progress_this_tick = speed_per_second * delta
						active_stage.progress += progress_this_tick

						var minutes_this_tick = GameTime.MINUTES_PER_REAL_SECOND * delta
						var old_work = worker_data.get_meta("daily_work_minutes", 0.0) if worker_data.has_meta("daily_work_minutes") else 0.0
						worker_data.set_meta("daily_work_minutes", old_work + minutes_this_tick)
						var old_prog = worker_data.get_meta("daily_progress", 0.0) if worker_data.has_meta("daily_progress") else 0.0
						worker_data.set_meta("daily_progress", old_prog + progress_this_tick)

			if active_stage.progress >= active_stage.amount:
				active_stage.progress = active_stage.amount
				active_stage["is_completed"] = true
				active_stage["actual_end"] = project.elapsed_days
				# Фиксируем имена исполнителей на завершённом этапе
				_freeze_stage_workers(active_stage)
		else:
			_finish_project(project)

func _freeze_stage_workers(stage: Dictionary):
	# Сохраняем имена исполнителей ��ля отображения, затем очищаем workers чтобы высвободить
	var names = []
	for w in stage.workers:
		names.append(w.employee_name)
	stage["completed_worker_names"] = names
	stage["workers"] = []

func _fail_project(project: ProjectData):
	if project.state == ProjectData.State.FAILED:
		return
	print("❌ ПРОЕКТ ПРОВАЛЕН (хард-дедлайн): ", project.title)
	project.state = ProjectData.State.FAILED
	# Фиксируем и высвобождаем всех работников на всех этапах
	for stage in project.stages:
		_freeze_stage_workers(stage)
	GameState.projects_failed_today.append(project)
	emit_signal("project_failed", project)

func _finish_project(project: ProjectData):
	if project.state == ProjectData.State.FINISHED:
		return
	var payout = project.get_final_payout(GameTime.day)
	if payout < project.budget:
		var penalty = project.budget - payout
		print("⚠️ ПРОЕКТ ЗАВЕРШЁН С ПРОСРОЧКОЙ: ", project.title, " | Штраф: -$", penalty, " | Выплата: $", payout)
	else:
		print("🎉 ПРОЕКТ ЗАВЕРШЁН ВОВРЕМЯ: ", project.title, " | Выплата: $", payout)
	project.state = ProjectData.State.FINISHED
	# Последний этап уже зафиксирован при is_completed, но на всякий случай
	for stage in project.stages:
		if stage.get("is_completed", false) and not stage.has("completed_worker_names"):
			_freeze_stage_workers(stage)
	GameState.add_income(payout)
	GameState.projects_finished_today.append({"project": project, "payout": payout})
	emit_signal("project_finished", project)

func _get_employee_node(data):
	if not data: return null
	for npc in get_tree().get_nodes_in_group("npc"):
		if npc.data == data: return npc
	return null

func _get_skill_for_stage(type, worker):
	match type:
		"BA": return worker.skill_business_analysis
		"DEV": return worker.skill_backend
		"QA": return worker.skill_qa
	return 10

func is_employee_on_active_stage(emp_data: EmployeeData) -> bool:
	for project in active_projects:
		if project.state != ProjectData.State.IN_PROGRESS:
			continue
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
