extends Node

# === СИСТЕМА СОХРАНЕНИЯ И ЗАГРУЗКИ ===
# SaveManager — autoload-синглтон

const SAVE_PATH = "user://savegame.json"
const SAVE_VERSION = 1

# >>> Флаг — синглтоны загружены, нужно восстановить сотрудников после загрузки сцены
var pending_restore: bool = false

signal game_saved
signal game_loaded

# === ПРОВЕРКА НАЛИЧИЯ СОХРАНЕНИЯ ===
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

# === УДАЛЕНИЕ СОХРАНЕНИЯ ===
func delete_save():
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)
		print("🗑️ Сохранение удалено")

# ============================================================
#                        СОХРАНЕНИЕ
# ============================================================

func save_game():
	var data = {
		"save_version": SAVE_VERSION,
		"timestamp": Time.get_datetime_string_from_system(),

		# --- GameTime ---
		"game_time": _serialize_game_time(),

		# --- GameState ---
		"game_state": _serialize_game_state(),

		# --- PMData ---
		"pm_data": _serialize_pm_data(),

		# --- BossManager ---
		"boss_manager": _serialize_boss_manager(),

		# --- ClientManager ---
		"clients": _serialize_clients(),

		# --- Сотрудники ---
		"employees": _serialize_employees(),

		# --- Проекты ---
		"projects": _serialize_projects(),
		
		# --- Привязка столов ---
		"desk_assignments": _serialize_desk_assignments(),

		# === EVENT SYSTEM: Сохраняем состояние EventManager ===
		"event_manager": _serialize_event_manager(),
	}

	var json_string = JSON.stringify(data, "\t")
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		print("💾 Игра сохранена: ", SAVE_PATH)
		emit_signal("game_saved")
	else:
		push_error("Не удалось открыть файл для сохранения: " + SAVE_PATH)

# --- GameTime ---
func _serialize_game_time() -> Dictionary:
	return {
		"day": GameTime.day,
		"hour": GameTime.hour,
		"minute": GameTime.minute,
	}

# --- GameState ---
func _serialize_game_state() -> Dictionary:
	return {
		"company_balance": GameState.company_balance,
		"tutorial_completed": GameState.tutorial_completed,
	}

# --- PMData ---
func _serialize_pm_data() -> Dictionary:
	return {
		"xp": PMData.xp,
		"skill_points": PMData.skill_points,
		"unlocked_skills": PMData.unlocked_skills.duplicate(),
		"_last_threshold_index": PMData._last_threshold_index,
	}

# --- BossManager ---
func _serialize_boss_manager() -> Dictionary:
	return {
		"boss_trust": BossManager.boss_trust,
		"quest_active": BossManager.quest_active,
		"current_quest": _deep_copy_dict(BossManager.current_quest),
		"quest_history": _deep_copy_array(BossManager.quest_history),
		"monthly_income": BossManager.monthly_income,
		"monthly_expenses": BossManager.monthly_expenses,
		"monthly_projects_finished": BossManager.monthly_projects_finished,
		"monthly_projects_failed": BossManager.monthly_projects_failed,
		"monthly_hires": BossManager.monthly_hires,
		"monthly_employee_levelups": BossManager.monthly_employee_levelups,
		"_current_month": BossManager._current_month,
		"_quest_shown_this_month": BossManager._quest_shown_this_month,
		"_report_shown_this_month": BossManager._report_shown_this_month,
	}

# --- Клиенты ---
func _serialize_clients() -> Array:
	var result = []
	for c in ClientManager.clients:
		result.append({
			"client_id": c.client_id,
			"loyalty": c.loyalty,
			"projects_completed_on_time": c.projects_completed_on_time,
			"projects_completed_late": c.projects_completed_late,
			"projects_failed": c.projects_failed,
		})
	return result

# --- Сотрудники ---
func _serialize_employees() -> Array:
	var result = []
	var npcs = get_tree().get_nodes_in_group("npc")
	for npc in npcs:
		if not npc.data or not npc.data is EmployeeData:
			continue
		var d = npc.data
		
		# === MOOD SYSTEM v2: Сериализуем временные mood_modifiers ===
		var serialized_modifiers = []
		for mod in d.mood_modifiers:
			# Сохраняем только временные (у которых duration > 0)
			if mod.get("duration", 0.0) > 0.0:
				serialized_modifiers.append({
					"id": mod.get("id", ""),
					"display_name": mod.get("display_name", ""),
					"value": mod.get("value", 0.0),
					"duration": mod.get("duration", 0.0),
					"elapsed": mod.get("elapsed", 0.0),
				})
		
		result.append({
			"employee_name": d.employee_name,
			"job_title": d.job_title,
			"monthly_salary": d.monthly_salary,
			"employee_level": d.employee_level,
			"employee_xp": d.employee_xp,
			"skill_backend": d.skill_backend,
			"skill_qa": d.skill_qa,
			"skill_business_analysis": d.skill_business_analysis,
			"traits": d.traits.duplicate(),
			"current_energy": d.current_energy,
			"motivation_bonus": d.motivation_bonus,
			# === MOOD SYSTEM v2: Сохраняем mood + модификаторы ===
			"mood": d.mood,
			"mood_modifiers": serialized_modifiers,
			# Визуал
			"personal_color": npc.personal_color.to_html(),
			"skin_color": npc.skin_color.to_html(),
			# Позиция стола (для восстановления привязки)
			"desk_position_x": npc.my_desk_position.x,
			"desk_position_y": npc.my_desk_position.y,
			# === EVENT SYSTEM: Сохраняем состояние болезни/отгула ===
			"sick_days_left": npc.sick_days_left,
			"is_on_day_off": npc.is_on_day_off,
			"current_state": npc.current_state,
		})
	return result

# --- Привязка столов ---
func _serialize_desk_assignments() -> Array:
	var result = []
	var desks = get_tree().get_nodes_in_group("desk")
	for desk in desks:
		if not ("assigned_employee" in desk):
			continue
		if desk.assigned_employee == null:
			continue
		result.append({
			"desk_position_x": desk.global_position.x,
			"desk_position_y": desk.global_position.y,
			"employee_name": desk.assigned_employee.employee_name,
		})
	return result

# --- Проекты ---
func _serialize_projects() -> Array:
	var result = []
	for proj in ProjectManager.active_projects:
		var proj_dict = {
			"title": proj.title,
			"category": proj.category,
			"client_id": proj.client_id,
			"created_at_day": proj.created_at_day,
			"deadline_day": proj.deadline_day,
			"soft_deadline_day": proj.soft_deadline_day,
			"start_global_time": proj.start_global_time,
			"elapsed_days": proj.elapsed_days,
			"hard_days_budget": proj.hard_days_budget,
			"soft_days_budget": proj.soft_days_budget,
			"budget": proj.budget,
			"soft_deadline_penalty_percent": proj.soft_deadline_penalty_percent,
			"state": proj.state,
			"stages": [],
		}

		for stage in proj.stages:
			var stage_dict = {
				"type": stage.get("type", ""),
				"amount": stage.get("amount", 0),
				"progress": stage.get("progress", 0.0),
				"is_completed": stage.get("is_completed", false),
				"actual_start": stage.get("actual_start", -1.0),
				"actual_end": stage.get("actual_end", -1.0),
				"plan_start": stage.get("plan_start", 0.0),
				"plan_duration": stage.get("plan_duration", 0.0),
				"worker_names": [],
				"completed_worker_names": stage.get("completed_worker_names", []),
			}
			for w in stage.get("workers", []):
				if w is EmployeeData:
					stage_dict["worker_names"].append(w.employee_name)
			proj_dict["stages"].append(stage_dict)

		result.append(proj_dict)
	return result

# === EVENT SYSTEM: Сериализация EventManager ===
func _serialize_event_manager() -> Dictionary:
	var em = get_node_or_null("/root/EventManager")
	if em == null:
		return {}
	return em.serialize()

# ============================================================
#                        ЗАГРУЗКА
# ============================================================

func load_game() -> bool:
	if not has_save():
		print("⚠️ Нет сохранения для загрузки")
		return false

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_error("Не удалось открыть файл сохранения")
		return false

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		push_error("Ошибка парсинга JSON: " + json.get_error_message())
		return false

	var data = json.data
	if not data is Dictionary:
		push_error("Некорректный формат сохранения")
		return false

	var version = data.get("save_version", 0)
	if version != SAVE_VERSION:
		push_warning("Версия сохранения (%d) отличается от текущей (%d)" % [version, SAVE_VERSION])

	_load_game_time(data.get("game_time", {}))
	_load_game_state(data.get("game_state", {}))
	_load_pm_data(data.get("pm_data", {}))
	_load_boss_manager(data.get("boss_manager", {}))
	_load_clients(data.get("clients", []))

	# === EVENT SYSTEM: Восстанавливаем EventManager ===
	_load_event_manager(data.get("event_manager", {}))

	print("📂 Данные синглтонов восстановлены")
	pending_restore = true
	emit_signal("game_loaded")
	return true

# Этот метод вызывается из office.gd ПОСЛЕ того как сцена полностью загружена
func restore_employees_and_projects(data_override: Dictionary = {}):
	var data: Dictionary
	if not data_override.is_empty():
		data = data_override
	else:
		if not has_save():
			return
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if not file:
			return
		var json_string = file.get_as_text()
		file.close()
		var json = JSON.new()
		if json.parse(json_string) != OK:
			return
		data = json.data

	var employee_dicts = data.get("employees", [])
	var project_dicts = data.get("projects", [])
	var desk_assignments = data.get("desk_assignments", [])

	var office = get_tree().get_first_node_in_group("office")
	if not office:
		push_error("Не найдена нода office для спавна сотрудников")
		return

	var world_layer = get_tree().get_first_node_in_group("world_layer")

	var existing_npcs = get_tree().get_nodes_in_group("npc")
	for npc in existing_npcs:
		npc.queue_free()

	await get_tree().process_frame
	await get_tree().process_frame

	var employee_map: Dictionary = {}
	var npc_map: Dictionary = {}

	for emp_dict in employee_dicts:
		var emp_data = EmployeeData.new()
		emp_data.employee_name = emp_dict.get("employee_name", "???")
		emp_data.job_title = emp_dict.get("job_title", "Junior Developer")
		emp_data.monthly_salary = int(emp_dict.get("monthly_salary", 3000))
		emp_data.employee_level = int(emp_dict.get("employee_level", 0))
		emp_data.employee_xp = int(emp_dict.get("employee_xp", 0))
		emp_data.skill_backend = int(emp_dict.get("skill_backend", 10))
		emp_data.skill_qa = int(emp_dict.get("skill_qa", 5))
		emp_data.skill_business_analysis = int(emp_dict.get("skill_business_analysis", 0))
		emp_data.current_energy = float(emp_dict.get("current_energy", 100.0))
		emp_data.motivation_bonus = float(emp_dict.get("motivation_bonus", 0.0))

		# Трейты
		var saved_traits = emp_dict.get("traits", [])
		emp_data.traits.clear()
		for t in saved_traits:
			emp_data.traits.append(str(t))
		emp_data.trait_text = emp_data.build_trait_text()

		var npc = _spawn_employee_in_office_proper(office, world_layer, emp_data)
		if npc:
			npc.personal_color = Color.from_string(emp_dict.get("personal_color", "#FFFFFF"), Color.WHITE)
			npc.skin_color = Color.from_string(emp_dict.get("skin_color", "#FFE0BD"), Color("#FFE0BD"))
			npc.update_visuals()

			npc.data.current_energy = float(emp_dict.get("current_energy", 100.0))
			npc.data.motivation_bonus = float(emp_dict.get("motivation_bonus", 0.0))
			# === MOOD SYSTEM v2: Восстанавливаем mood ===
			npc.data.mood = float(emp_dict.get("mood", 75.0))

			# === MOOD SYSTEM v2: Восстанавливаем временные модификаторы ===
			var saved_mods = emp_dict.get("mood_modifiers", [])
			for mod_dict in saved_mods:
				var mod = {
					"id": str(mod_dict.get("id", "")),
					"display_name": str(mod_dict.get("display_name", "")),
					"value": float(mod_dict.get("value", 0.0)),
					"duration": float(mod_dict.get("duration", 0.0)),
					"elapsed": float(mod_dict.get("elapsed", 0.0)),
				}
				npc.data.mood_modifiers.append(mod)

			var desk_x = float(emp_dict.get("desk_position_x", 0.0))
			var desk_y = float(emp_dict.get("desk_position_y", 0.0))
			if desk_x != 0.0 or desk_y != 0.0:
				npc.my_desk_position = Vector2(desk_x, desk_y)

			# === EVENT SYSTEM: Восстанавливаем состояние болезни/отгула ===
			npc.sick_days_left = int(emp_dict.get("sick_days_left", 0))
			npc.is_on_day_off = emp_dict.get("is_on_day_off", false)
			var saved_state = int(emp_dict.get("current_state", 0))
			if saved_state == 11:  # State.SICK_LEAVE
				npc.visible = false
				npc.get_node("CollisionShape2D").disabled = true
				npc.velocity = Vector2.ZERO
				npc.current_state = 11
			elif saved_state == 12:  # State.DAY_OFF
				npc.visible = false
				npc.get_node("CollisionShape2D").disabled = true
				npc.velocity = Vector2.ZERO
				npc.current_state = 12

			employee_map[emp_data.employee_name] = emp_data
			npc_map[emp_data.employee_name] = npc

	# === Восстанавливаем проекты ===
	ProjectManager.active_projects.clear()

	for proj_dict in project_dicts:
		var proj = ProjectData.new()
		proj.title = proj_dict.get("title", "PROJ_DEFAULT_TITLE")
		proj.category = proj_dict.get("category", "simple")
		proj.client_id = proj_dict.get("client_id", "")
		proj.created_at_day = int(proj_dict.get("created_at_day", 1))
		proj.deadline_day = int(proj_dict.get("deadline_day", 0))
		proj.soft_deadline_day = int(proj_dict.get("soft_deadline_day", 0))
		proj.start_global_time = float(proj_dict.get("start_global_time", 0.0))
		proj.elapsed_days = float(proj_dict.get("elapsed_days", 0.0))
		proj.hard_days_budget = int(proj_dict.get("hard_days_budget", 0))
		proj.soft_days_budget = int(proj_dict.get("soft_days_budget", 0))
		proj.budget = int(proj_dict.get("budget", 5000))
		proj.soft_deadline_penalty_percent = int(proj_dict.get("soft_deadline_penalty_percent", 10))
		proj.state = int(proj_dict.get("state", 0))

		proj.stages.clear()
		var saved_stages = proj_dict.get("stages", [])
		for stage_dict in saved_stages:
			var stage = {
				"type": stage_dict.get("type", ""),
				"amount": float(stage_dict.get("amount", 0)),
				"progress": float(stage_dict.get("progress", 0.0)),
				"is_completed": stage_dict.get("is_completed", false),
				"actual_start": float(stage_dict.get("actual_start", -1.0)),
				"actual_end": float(stage_dict.get("actual_end", -1.0)),
				"plan_start": float(stage_dict.get("plan_start", 0.0)),
				"plan_duration": float(stage_dict.get("plan_duration", 0.0)),
				"workers": [],
				"completed_worker_names": [],
			}

			var cwn = stage_dict.get("completed_worker_names", [])
			for cname in cwn:
				stage["completed_worker_names"].append(str(cname))

			var worker_names = stage_dict.get("worker_names", [])
			for wname in worker_names:
				var wname_str = str(wname)
				if employee_map.has(wname_str):
					stage["workers"].append(employee_map[wname_str])

			proj.stages.append(stage)

		ProjectManager.active_projects.append(proj)

	_restore_desk_assignments(desk_assignments, employee_map, npc_map)
	_rebind_employees_to_desks()

	GameTime.is_game_paused = false
	GameTime.is_night_skip = false
	GameTime.current_speed_scale = 1.0
	Engine.time_scale = 1.0
	get_tree().paused = false
	print("⏩ Скорость после загрузки: x1")

	print("✅ Сотрудники и проекты восстановлены из сохранения")

func _spawn_employee_in_office_proper(office, world_layer, emp_data: EmployeeData):
	var employee_scene = load("res://Scenes/Employee.tscn")
	if not employee_scene:
		push_error("Не удалось загрузить Employee.tscn")
		return null

	var npc = employee_scene.instantiate()
	
	if npc.has_method("setup_employee"):
		npc.setup_employee(emp_data)
	else:
		npc.data = emp_data

	if world_layer:
		world_layer.add_child(npc)
	else:
		office.add_child(npc)
		print("ВНИМАНИЕ: Нет группы 'world_layer' при загрузке! Сортировка может сломаться.")

	var entrance = get_tree().get_first_node_in_group("entrance")
	if entrance:
		npc.global_position = entrance.global_position

	return npc

func _restore_desk_assignments(desk_assignments: Array, employee_map: Dictionary, npc_map: Dictionary):
	if desk_assignments.is_empty():
		return
	
	var desks = get_tree().get_nodes_in_group("desk")
	
	for assignment in desk_assignments:
		var desk_x = float(assignment.get("desk_position_x", 0.0))
		var desk_y = float(assignment.get("desk_position_y", 0.0))
		var emp_name = str(assignment.get("employee_name", ""))
		
		if emp_name.is_empty():
			continue
		if not employee_map.has(emp_name):
			continue
		
		var emp_data = employee_map[emp_name]
		var saved_desk_pos = Vector2(desk_x, desk_y)
		
		var best_desk = null
		var best_dist = 50.0
		
		for desk in desks:
			var dist = desk.global_position.distance_to(saved_desk_pos)
			if dist < best_dist:
				best_dist = dist
				best_desk = desk
		
		if best_desk and best_desk.has_method("assign_employee"):
			if "assigned_employee" in best_desk and best_desk.assigned_employee == null:
				
				var npc_node = null
				if npc_map.has(emp_name):
					npc_node = npc_map[emp_name]
				
				best_desk.assign_employee(emp_data, npc_node)
				print("🪑 Восстановлена привязка стола для: ", emp_name)
				
				if npc_node:
					if "seat_point" in best_desk and best_desk.seat_point:
						npc_node.my_desk_position = best_desk.seat_point.global_position
					else:
						npc_node.my_desk_position = best_desk.global_position

func _rebind_employees_to_desks():
	var npcs = get_tree().get_nodes_in_group("npc")
	for npc in npcs:
		if npc.current_state == 11 or npc.current_state == 12:
			continue
		if npc.my_desk_position != Vector2.ZERO:
			if ProjectManager.is_employee_on_active_stage(npc.data):
				npc.move_to_desk(npc.my_desk_position)

func _load_game_time(d: Dictionary):
	if d.is_empty():
		return
	GameTime.day = int(d.get("day", 1))
	GameTime.hour = int(d.get("hour", 8))
	GameTime.minute = int(d.get("minute", 0))
	GameTime.time_accumulator = 0.0
	GameTime.current_speed_scale = 1.0
	GameTime.is_game_paused = false
	GameTime.is_night_skip = false

func _load_game_state(d: Dictionary):
	if d.is_empty():
		return
	GameState.company_balance = int(d.get("company_balance", 10000))
	GameState.balance_at_day_start = GameState.company_balance
	GameState.daily_income = 0
	GameState.daily_expenses = 0
	GameState.daily_salary_details.clear()
	GameState.projects_finished_today.clear()
	GameState.projects_failed_today.clear()
	GameState.levelups_today.clear()
	GameState.loyalty_changes_today.clear()
	GameState.tutorial_completed = d.get("tutorial_completed", false)

func _load_pm_data(d: Dictionary):
	if d.is_empty():
		return
	PMData.xp = int(d.get("xp", 0))
	PMData.skill_points = int(d.get("skill_points", 0))
	PMData._last_threshold_index = int(d.get("_last_threshold_index", -1))

	PMData.unlocked_skills.clear()
	var skills = d.get("unlocked_skills", [])
	for s in skills:
		PMData.unlocked_skills.append(str(s))

func _load_boss_manager(d: Dictionary):
	if d.is_empty():
		return
	BossManager.boss_trust = int(d.get("boss_trust", 0))
	BossManager.quest_active = d.get("quest_active", false)
	BossManager.current_quest = d.get("current_quest", {})
	BossManager.quest_history = d.get("quest_history", [])
	BossManager.monthly_income = int(d.get("monthly_income", 0))
	BossManager.monthly_expenses = int(d.get("monthly_expenses", 0))
	BossManager.monthly_projects_finished = int(d.get("monthly_projects_finished", 0))
	BossManager.monthly_projects_failed = int(d.get("monthly_projects_failed", 0))
	BossManager.monthly_hires = int(d.get("monthly_hires", 0))
	BossManager.monthly_employee_levelups = int(d.get("monthly_employee_levelups", 0))
	BossManager._current_month = int(d.get("_current_month", 1))
	BossManager._quest_shown_this_month = d.get("_quest_shown_this_month", false)
	BossManager._report_shown_this_month = d.get("_report_shown_this_month", false)

func _load_clients(arr: Array):
	if arr.is_empty():
		return
	for cd in arr:
		var cid = cd.get("client_id", "")
		var client = ClientManager.get_client_by_id(cid)
		if client:
			client.loyalty = int(cd.get("loyalty", 0))
			client.projects_completed_on_time = int(cd.get("projects_completed_on_time", 0))
			client.projects_completed_late = int(cd.get("projects_completed_late", 0))
			client.projects_failed = int(cd.get("projects_failed", 0))

func _load_event_manager(d: Dictionary):
	var em = get_node_or_null("/root/EventManager")
	if em == null:
		return
	if d.is_empty():
		return
	em.deserialize(d)

# ============================================================
#                        УТИЛИТЫ
# ============================================================

func _deep_copy_dict(d) -> Dictionary:
	if d == null or not d is Dictionary:
		return {}
	var result = {}
	for key in d:
		var val = d[key]
		if val is Dictionary:
			result[key] = _deep_copy_dict(val)
		elif val is Array:
			result[key] = _deep_copy_array(val)
		else:
			result[key] = val
	return result

func _deep_copy_array(a) -> Array:
	if a == null or not a is Array:
		return []
	var result = []
	for item in a:
		if item is Dictionary:
			result.append(_deep_copy_dict(item))
		elif item is Array:
			result.append(_deep_copy_array(item))
		else:
			result.append(item)
	return result
