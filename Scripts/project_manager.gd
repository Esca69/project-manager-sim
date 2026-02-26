extends Node

var active_projects: Array = []

signal project_finished(proj: ProjectData)
signal project_failed(proj: ProjectData)
signal employee_leveled_up(emp: EmployeeData, new_level: int, skill_gain: int, new_trait: String)

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Подписываемся на начало рабочего дня для сброса daily_labor_cost
	GameTime.work_started.connect(_on_work_started)

func _on_work_started():
	for project in active_projects:
		project.daily_labor_cost = 0.0

func add_project(proj: ProjectData):
	if count_active_projects() >= PMData.get_max_projects():
		print(tr("LOG_MAX_PROJECTS") % PMData.get_max_projects())
		return false
	active_projects.append(proj)
	print(tr("LOG_PROJECT_ADDED") % [tr(proj.title), active_projects.size()])
	return true

func can_take_more() -> bool:
	return count_active_projects() < PMData.get_max_projects()

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
	if GameTime.is_game_paused:
		return
		
	for project in active_projects:
		if project.state != ProjectData.State.IN_PROGRESS:
			continue

		var now = get_current_global_time()

		if project.start_global_time < 0.01:
			project.start_global_time = now

		project.elapsed_days = now - project.start_global_time

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
						var speed_per_second = (float(skill) * efficiency) / 60.0
						var progress_this_tick = speed_per_second * delta
						active_stage.progress += progress_this_tick

						var minutes_this_tick = GameTime.MINUTES_PER_REAL_SECOND * delta
						var old_work = worker_data.get_meta("daily_work_minutes", 0.0) if worker_data.has_meta("daily_work_minutes") else 0.0
						worker_data.set_meta("daily_work_minutes", old_work + minutes_this_tick)
						var old_prog = worker_data.get_meta("daily_progress", 0.0) if worker_data.has_meta("daily_progress") else 0.0
						worker_data.set_meta("daily_progress", old_prog + progress_this_tick)

						# === АНАЛИТИКА: Считаем затраты на рабочую силу ===
						var cost_this_tick = minutes_this_tick * (float(worker_data.hourly_rate) / 60.0)
						project.daily_labor_cost += cost_this_tick
						project.total_labor_cost += cost_this_tick

			if active_stage.progress >= active_stage.amount:
				active_stage.progress = active_stage.amount
				active_stage["is_completed"] = true
				active_stage["actual_end"] = project.elapsed_days

				# === НАЧИСЛЕНИЕ XP СОТРУДНИКАМ ===
				_award_stage_xp(active_stage, project)
				_freeze_stage_workers(active_stage)
		else:
			_finish_project(project)

# === НАЧИСЛЕНИЕ XP ЗА ЭТАП ===
func _award_stage_xp(stage: Dictionary, project: ProjectData):
	var category = project.category
	var xp_range = EmployeeData.STAGE_XP_REWARD.get(category, [20, 35])
	var base_xp = randi_range(xp_range[0], xp_range[1])

	# === ПРОЕКТНЫЙ ИВЕНТ: XP бонус за junior_mistake (помощь) ===
	var xp_multiplier = stage.get("xp_bonus_multiplier", 1.0)
	var xp_bonus_employee = stage.get("xp_bonus_employee", "")

	for worker_data in stage.workers:
		if worker_data is EmployeeData:
			var final_xp = base_xp
			# Применяем бонусный множитель только к конкретному сотруднику
			if xp_multiplier != 1.0 and worker_data.employee_name == xp_bonus_employee:
				final_xp = int(base_xp * xp_multiplier)
				print("🤝 %s получает ×%.1f XP за этап (помощь с ошибкой)" % [worker_data.employee_name, xp_multiplier])

			var result = worker_data.add_employee_xp(final_xp)
			print(tr("LOG_XP_GAIN") % [worker_data.employee_name, final_xp, tr("STAGE_" + stage.type)])

			# === MOOD SYSTEM v2: Завершил этап → +5 на 8 часов (480 мин) ===
			worker_data.add_mood_modifier("stage_complete", "MOOD_MOD_STAGE_COMPLETE", 5.0, 1440.0)

			if result["leveled_up"]:
				emit_signal("employee_leveled_up", worker_data, result["new_level"], result["skill_gain"], result["new_trait"])
				# === MOOD SYSTEM v2: Левел-ап → +7 на 24 часа (1440 мин) ===
				worker_data.add_mood_modifier("level_up", "MOOD_MOD_LEVEL_UP", 7.0, 2880.0)

# === БОНУС XP ЗА ПРОЕКТ ВОВРЕМЯ ===
func _award_on_time_bonus(project: ProjectData):
	var is_on_time = GameTime.day < project.soft_deadline_day
	if not is_on_time:
		return

	for stage in project.stages:
		var worker_names = stage.get("completed_worker_names", [])
		for npc in get_tree().get_nodes_in_group("npc"):
			if npc.data and npc.data.employee_name in worker_names:
				var bonus_xp = int(15 * EmployeeData.ON_TIME_XP_BONUS)
				var result = npc.data.add_employee_xp(bonus_xp)
				if result["leveled_up"]:
					emit_signal("employee_leveled_up", npc.data, result["new_level"], result["skill_gain"], result["new_trait"])

func _freeze_stage_workers(stage: Dictionary):
	var names = []
	for w in stage.workers:
		names.append(w.employee_name)
	stage["completed_worker_names"] = names
	stage["workers"] = []

func _fail_project(project: ProjectData):
	if project.state == ProjectData.State.FAILED:
		return
	print(tr("LOG_PROJECT_FAILED") % tr(project.title))
	project.state = ProjectData.State.FAILED

	# === MOOD SYSTEM v2: Провал → -10 на 24 часа всем участникам ===
	for stage in project.stages:
		for worker_data in stage.workers:
			if worker_data is EmployeeData:
				worker_data.add_mood_modifier("project_failed", "MOOD_MOD_PROJECT_FAILED", -10.0, 2880.0)
		var worker_names = stage.get("completed_worker_names", [])
		for npc in get_tree().get_nodes_in_group("npc"):
			if npc.data and npc.data.employee_name in worker_names:
				npc.data.add_mood_modifier("project_failed", "MOOD_MOD_PROJECT_FAILED", -10.0, 2880.0)

	for stage in project.stages:
		_freeze_stage_workers(stage)
	GameState.projects_failed_today.append(project)

	# === ЛОЯЛЬНОСТЬ: ПРОВАЛ ===
	var client = project.get_client()
	if client:
		client.record_project_failed()
		print("💔 %s: лояльность %d (провал проекта)" % [client.get_display_name(), client.loyalty])

	emit_signal("project_failed", project)

func _finish_project(project: ProjectData):
	if project.state == ProjectData.State.FINISHED:
		return
	var payout = project.get_final_payout(GameTime.day)
	if payout < project.budget:
		var penalty = project.budget - payout
		print(tr("LOG_PROJECT_FINISHED_LATE") % [tr(project.title), penalty, payout])
	else:
		print(tr("LOG_PROJECT_FINISHED_ON_TIME") % [tr(project.title), payout])
	
	project.state = ProjectData.State.FINISHED
	for stage in project.stages:
		if stage.get("is_completed", false) and not stage.has("completed_worker_names"):
			_freeze_stage_workers(stage)
	GameState.add_income(payout)
	GameState.daily_income_details.append({"reason": tr("INCOME_PROJECT") % tr(project.title), "amount": payout})
	GameState.projects_finished_today.append({"project": project, "payout": payout})

	# === MOOD SYSTEM v2: Проект завершён → +8 на 24 часа всем участникам ===
	for stage in project.stages:
		var worker_names = stage.get("completed_worker_names", [])
		for npc in get_tree().get_nodes_in_group("npc"):
			if npc.data and npc.data.employee_name in worker_names:
				npc.data.add_mood_modifier("project_success", "MOOD_MOD_PROJECT_SUCCESS", 8.0, 2880.0)

	# === ЛОЯЛЬНОСТЬ: УСПЕХ ===
	var client = project.get_client()
	if client:
		if project.is_finished_on_time(GameTime.day):
			client.record_project_on_time()
			print("💚 %s: лояльность %d (вовремя, +%d)" % [client.get_display_name(), client.loyalty, ClientData.LOYALTY_ON_TIME])
		else:
			client.record_project_late()
			print("💛 %s: лояльность %d (просрочка софт, +%d)" % [client.get_display_name(), client.loyalty, ClientData.LOYALTY_LATE])

		# Бонус XP за вовремя
	_award_on_time_bonus(project)
	# === ПРОЕКТНЫЙ ИВЕНТ: регистрация для отзыва ===
	var em = get_node_or_null("/root/EventManager")
	if em:
		em.register_finished_project(project)
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
