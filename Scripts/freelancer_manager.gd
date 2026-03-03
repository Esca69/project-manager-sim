extends Node

# Предупреждённые фрилансеры (имя → через сколько дней уйдёт)
var _warned_freelancers: Dictionary = {}  # {employee_name: days_until_leave}

func check_freelancer_departures():
	# Вызывается из game_time.gd в 09:05
	var npcs = get_tree().get_nodes_in_group("npc")

	for npc in npcs:
		if not npc.data:
			continue
		if npc.data.employment_type != "freelancer":
			continue

		var days = npc.data.days_in_company
		var emp_name = npc.data.employee_name

		# Проверяем предупреждённых
		if _warned_freelancers.has(emp_name):
			_warned_freelancers[emp_name] -= 1
			if _warned_freelancers[emp_name] <= 0:
				_warned_freelancers.erase(emp_name)
				_show_departure_popup(npc, "guaranteed")
				break
			continue

		# Шансы ухода
		var leave_chance = 0.0
		var hard_leave_chance = 0.0  # Шанс уйти БЕЗ предупреждения

		if days >= 10:
			# Гарантированный уход
			_show_departure_popup(npc, "guaranteed")
			break
		elif days >= 8:
			leave_chance = 0.20
			hard_leave_chance = 0.30  # 30% hard leave
		elif days >= 5:
			leave_chance = 0.10
			hard_leave_chance = 0.0  # Только soft leave
		else:
			continue

		if randf() < leave_chance:
			if randf() < hard_leave_chance:
				# HARD LEAVE — уходит сразу
				_show_departure_popup(npc, "hard")
				break
			else:
				# SOFT LEAVE — предупреждение за 1-2 дня
				var warning_days = randi_range(1, 2)
				_show_soft_leave_popup(npc, warning_days)
				break

func _get_random_reason() -> String:
	var reasons = [
		"FREELANCER_REASON_1",
		"FREELANCER_REASON_2",
		"FREELANCER_REASON_3",
		"FREELANCER_REASON_4",
		"FREELANCER_REASON_5",
	]
	return tr(reasons.pick_random())

func _show_soft_leave_popup(npc_node: Node, warning_days: int):
	var emp_name = npc_node.data.employee_name
	var emp_role = tr(npc_node.data.job_title)
	var reason = _get_random_reason()
	var desc = tr("EVENT_FREELANCER_SOFT_DESC") % [emp_name, emp_role, reason, warning_days]
	var event_data = {
		"id": "freelancer_leave",
		"leave_type": "soft",
		"npc_node": npc_node,
		"employee_name": emp_name,
		"warning_days": warning_days,
		"description_text": desc,
		"choices": [
			{
				"id": "ok",
				"label": tr("EVENT_FREELANCER_LEAVE_OK"),
				"description": tr("EVENT_FREELANCER_LEAVE_OK_DESC"),
				"emoji": "👍",
			},
		],
	}
	if EventLog:
		EventLog.add(tr("LOG_FREELANCER_WARN_LEAVE") % [emp_name, warning_days])
	EventManager._show_event_popup(event_data)

func _show_departure_popup(npc_node: Node, leave_type: String):
	var emp_name = npc_node.data.employee_name
	var emp_role = tr(npc_node.data.job_title)
	var reason = _get_random_reason()
	var desc = tr("EVENT_FREELANCER_HARD_DESC") % [emp_name, emp_role, reason]
	var event_data = {
		"id": "freelancer_leave",
		"leave_type": leave_type,
		"npc_node": npc_node,
		"employee_name": emp_name,
		"description_text": desc,
		"choices": [
			{
				"id": "ok",
				"label": tr("EVENT_FREELANCER_LEAVE_OK"),
				"description": tr("EVENT_FREELANCER_LEAVE_OK_DESC"),
				"emoji": "👍",
			},
		],
	}
	if EventLog:
		EventLog.add(tr("LOG_FREELANCER_SUDDEN_LEAVE") % emp_name)
	EventManager._show_event_popup(event_data)

func register_warned_freelancer(emp_name: String, warning_days: int):
	_warned_freelancers[emp_name] = warning_days

func _execute_departure(npc_node):
	var emp_data = npc_node.data
	var emp_name = emp_data.employee_name

	# 1. Снять со всех проектов (НЕ сбрасывая прогресс этапа!)
	for project in ProjectManager.active_projects:
		for stage in project.stages:
			var idx = -1
			for i in range(stage.workers.size()):
				if stage.workers[i] == emp_data:
					idx = i
					break
			if idx != -1:
				stage.workers.remove_at(idx)

	# 2. Освободить стол
	for desk in get_tree().get_nodes_in_group("desk"):
		if not desk.has_method("unassign_employee"):
			continue
		if not ("assigned_employee" in desk):
			continue
		if desk.assigned_employee == emp_data:
			desk.unassign_employee()
			break

	# 3. Удалить NPC
	if npc_node and is_instance_valid(npc_node):
		npc_node.release_from_desk()
		npc_node.remove_from_group("npc")
		npc_node.queue_free()

	# 4. Лог
	if EventLog:
		EventLog.add(tr("LOG_FREELANCER_DEPARTED") % [emp_name, emp_data.days_in_company])

	print("🚪 Фрилансер %s покинул компанию" % emp_name)
