extends Node

var active_support_projects: Array = []
var completed_support_projects: Array = []

var _planned_ticket_minutes: Dictionary = {}
var _planned_ticket_day: Dictionary = {}

func _tr_format_safe(key: String, args, fallback: String) -> String:
	var text = tr(key)
	if text.find("%") >= 0:
		return text % args
	return fallback

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	if GameTime and not GameTime.work_started.is_connected(_on_work_started):
		GameTime.work_started.connect(_on_work_started)
	if GameTime and not GameTime.time_tick.is_connected(_on_time_tick):
		GameTime.time_tick.connect(_on_time_tick)
	if GameTime and not GameTime.day_started.is_connected(_on_day_started):
		GameTime.day_started.connect(_on_day_started)

func add_support_project(proj: SupportProjectData) -> bool:
	if proj == null:
		return false
	if has_active_support_for_client(proj.client_id):
		return false
	if proj.week_start_day <= 0:
		proj.week_start_day = proj.created_at_day
	if proj.contract_duration_days <= 0:
		proj.contract_duration_days = 10
	if proj.end_day <= 0:
		proj.end_day = _add_working_days(proj.created_at_day, proj.contract_duration_days)
	active_support_projects.append(proj)
	return true

func has_active_support_for_client(client_id: String) -> bool:
	for proj in active_support_projects:
		if proj.is_active and proj.client_id == client_id:
			return true
	return false

func is_employee_on_support(emp_data: EmployeeData) -> bool:
	if emp_data == null:
		return false
	for proj in active_support_projects:
		if proj.assigned_support_employee == emp_data:
			return true
	return false

func is_employee_on_ticket(emp_data: EmployeeData) -> bool:
	if emp_data == null:
		return false
	for proj in active_support_projects:
		for ticket in proj.tickets:
			if ticket is SupportTicketData and not ticket.is_completed and ticket.assigned_worker == emp_data:
				return true
	return false

func get_effective_daily_rate(proj: SupportProjectData) -> int:
	if proj == null:
		return 0
	var effective_rate = float(proj.daily_rate)
	match proj.sla_level:
		"strict":
			effective_rate *= 1.2
		"easy":
			effective_rate *= 0.8
		effective_rate *= (1.0 + float(proj.duration_bonus_percent) / 100.0)
	return int(effective_rate)

func get_sla_deadline_days(sla_level: String) -> int:
	match sla_level:
		"strict":
			return 2
		"easy":
			return 4
	return 3

func get_overdue_termination_limit(sla_level: String) -> int:
	match sla_level:
		"strict":
			return 3
		"easy":
			return 9
	return 5

func _on_work_started():
	for proj in active_support_projects:
		proj.daily_labor_cost = 0.0
		if not proj.is_active:
			_planned_ticket_minutes.erase(proj.project_id)
			_planned_ticket_day.erase(proj.project_id)
			continue
		if proj.assigned_support_employee == null:
			_planned_ticket_minutes[proj.project_id] = []
			_planned_ticket_day.erase(proj.project_id)
			continue
		if GameTime.is_weekend():
			_planned_ticket_minutes[proj.project_id] = []
			_planned_ticket_day.erase(proj.project_id)
			continue
		var tickets_today = randi_range(0, 3)
		var minutes: Array = []
		for i in range(tickets_today):
			minutes.append(randi_range(GameTime.START_HOUR * 60, (GameTime.END_HOUR - 1) * 60 + 50))
		minutes.sort()
		_planned_ticket_minutes[proj.project_id] = minutes
		_planned_ticket_day[proj.project_id] = GameTime.day

func _on_time_tick(hour: int, minute: int):
	if GameTime.day <= 0:
		return

	if not GameTime.is_weekend():
		var minute_of_day = hour * 60 + minute
		for proj in active_support_projects:
			if not proj.is_active:
				_planned_ticket_minutes.erase(proj.project_id)
				_planned_ticket_day.erase(proj.project_id)
				continue
			if proj.assigned_support_employee == null:
				_planned_ticket_minutes[proj.project_id] = []
				_planned_ticket_day.erase(proj.project_id)
				continue
			var project_id = proj.project_id
			if int(_planned_ticket_day.get(project_id, -1)) != GameTime.day:
				var tickets_today = randi_range(0, 3)
				var minutes: Array = []
				for i in range(tickets_today):
					var min_time = max(minute_of_day + 1, GameTime.START_HOUR * 60)
					var max_time = (GameTime.END_HOUR - 1) * 60 + 50
					if min_time <= max_time:
						minutes.append(randi_range(min_time, max_time))
				minutes.sort()
				_planned_ticket_minutes[project_id] = minutes
				_planned_ticket_day[project_id] = GameTime.day
			var planned: Array = _planned_ticket_minutes.get(project_id, [])
				while planned.size() > 0 and int(planned[0]) <= minute_of_day:
					planned.pop_front()
					_generate_ticket(proj)
				_planned_ticket_minutes[project_id] = planned

	if hour == 18 and minute == 0 and GameTime.get_weekday_index() == 4:
		flush_weekly_payout_if_pending()

func flush_weekly_payout_if_pending():
	if GameTime.day <= 0:
		return
	if GameTime.get_weekday_index() != 4:
		return
	if GameTime.hour < GameTime.END_HOUR:
		return
	if not _has_pending_weekly_payouts():
		return
	_process_weekly_payouts()

func _has_pending_weekly_payouts() -> bool:
	for proj in active_support_projects:
		if not proj.is_active:
			continue
		var start_day = max(proj.week_start_day, proj.created_at_day)
		if start_day > GameTime.day:
			continue
		if _count_workdays_between(start_day, GameTime.day) > 0:
			return true
	return false

func _physics_process(delta: float):
	if GameTime.is_game_paused:
		return

	var is_working_hours = GameTime.hour >= GameTime.START_HOUR and GameTime.hour < GameTime.END_HOUR and not GameTime.is_weekend()
	var minutes_this_tick = GameTime.MINUTES_PER_REAL_SECOND * delta

	for proj in active_support_projects:
		if not proj.is_active:
			continue
		for ticket in proj.tickets:
			if not (ticket is SupportTicketData):
				continue
			if ticket.is_completed:
				continue
			if ticket.assigned_worker == null:
				continue

			if is_working_hours:
				var worker_data: EmployeeData = ticket.assigned_worker
				var cost_this_tick = minutes_this_tick * (float(worker_data.hourly_rate) / 60.0)
				proj.daily_labor_cost += cost_this_tick
				proj.total_labor_cost += cost_this_tick

			var worker_node = _get_employee_node(ticket.assigned_worker)
			if is_working_hours and worker_node and worker_node.current_state == worker_node.State.WORKING:
				var skill = _get_skill_for_role(ticket.required_role, ticket.assigned_worker)
				var efficiency = ticket.assigned_worker.get_efficiency_multiplier()
				var speed_per_second = (float(skill) * efficiency) / 60.0
				ticket.progress += speed_per_second * delta
				if ticket.progress >= float(ticket.work_amount):
					ticket.progress = float(ticket.work_amount)
					ticket.is_completed = true
					ticket.assigned_worker = null

func _on_day_started(_day_number: int):
	for proj in active_support_projects.duplicate():
		if not proj.is_active:
			continue
		for ticket in proj.tickets:
			if not (ticket is SupportTicketData):
				continue
			if not ticket.is_completed and not ticket.is_overdue and GameTime.day > ticket.deadline_day:
				ticket.is_overdue = true
				proj.weekly_overdue_count += 1
		if proj.is_active and proj.weekly_overdue_count >= get_overdue_termination_limit(proj.sla_level):
			_terminate_contract(proj)
			continue
		if proj.is_active and proj.end_day > 0 and GameTime.day > proj.end_day:
			_complete_contract(proj)

func _generate_ticket(proj: SupportProjectData):
	var ticket = SupportTicketData.new()
	ticket.ticket_id = "ticket_%s_%d_%d" % [proj.project_id, GameTime.day, proj.tickets.size() + 1]
	ticket.required_role = ["BA", "DEV", "QA"][randi_range(0, 2)]
	ticket.work_amount = randi_range(80, 200)
	ticket.progress = 0.0
	ticket.created_at_day = GameTime.day
	ticket.deadline_day = _add_working_days(ticket.created_at_day, get_sla_deadline_days(proj.sla_level))
	proj.tickets.append(ticket)

	var role_name = tr("ROLE_SHORT_" + ticket.required_role)
	EventLog.add(_tr_format_safe("LOG_SUPPORT_TICKET_NEW", [role_name, proj.get_display_title()], "New ticket (%s) for project %s" % [role_name, proj.get_display_title()]), EventLog.LogType.PROGRESS)
	if ScreenJuice:
		ScreenJuice.show_toast("📋", _tr_format_safe("TOAST_SUPPORT_TICKET", role_name, "New ticket: %s" % role_name))

func _process_weekly_payouts():
	for proj in active_support_projects:
		if not proj.is_active:
			continue

		var start_day = max(proj.week_start_day, proj.created_at_day)
		var worked_days = _count_workdays_between(start_day, GameTime.day)
		var overdue_count = 0
		for ticket in proj.tickets:
			if ticket is SupportTicketData and ticket.is_overdue and not ticket.is_completed:
				overdue_count += 1

		var effective_rate = get_effective_daily_rate(proj)
		var base_payout = worked_days * effective_rate
		var penalty_percent = min(overdue_count * 10, 100)
		var final_payout = int(base_payout * (1.0 - float(penalty_percent) / 100.0))

		if final_payout > 0:
			GameState.add_income(final_payout)
			GameState.daily_income_details.append({"reason": tr("PROJ_CAT_SUPPORT"), "amount": final_payout, "category": "support"})
			proj.total_earned += final_payout

		var client = proj.get_client()
		var client_name = client.get_display_name() if client else proj.client_id
		if penalty_percent > 0:
			EventLog.add(_tr_format_safe("LOG_SUPPORT_PENALTY", [client_name, penalty_percent, overdue_count], "Support %s: -%d%% penalty for %d overdue tickets" % [client_name, penalty_percent, overdue_count]), EventLog.LogType.ALERT)
		EventLog.add(_tr_format_safe("LOG_SUPPORT_WEEKLY_PAYOUT", [client_name, final_payout], "Support %s: received $%d for the week" % [client_name, final_payout]), EventLog.LogType.PROGRESS)
		if ScreenJuice:
			ScreenJuice.show_toast("💰", _tr_format_safe("TOAST_SUPPORT_PAYOUT", final_payout, "Support: +$%d" % final_payout))

		proj.weekly_overdue_count = 0
		proj.week_start_day = _get_next_monday(GameTime.day)

func _terminate_contract(proj: SupportProjectData):
	if proj == null or not proj.is_active:
		return
	proj.is_active = false
	proj.termination_reason = "terminated_overdue"

	var client = proj.get_client()
	if ClientManager:
		if ClientManager.has_method("penalize_reputation_points"):
			ClientManager.penalize_reputation_points(10)
		else:
			ClientManager.spend_reputation_points(10)

	var client_name = client.get_display_name() if client else proj.client_id
	EventLog.add(_tr_format_safe("LOG_SUPPORT_TERMINATED", client_name, "⛔ Support contract with %s terminated due to overdue" % client_name), EventLog.LogType.ALERT)
	if ScreenJuice:
		ScreenJuice.show_toast("⛔", _tr_format_safe("TOAST_SUPPORT_TERMINATED", client_name, "⛔ Contract terminated: %s" % client_name))

	_release_and_archive(proj)

func _complete_contract(proj: SupportProjectData):
	if proj == null or not proj.is_active:
		return

	_process_final_payout(proj)
	proj.is_active = false
	proj.termination_reason = "completed"

	var client = proj.get_client()
	var client_name = client.get_display_name() if client else proj.client_id
	EventLog.add(_tr_format_safe("LOG_SUPPORT_COMPLETED", [client_name, proj.total_earned], "✅ Support contract with %s completed. Earned: $%d" % [client_name, proj.total_earned]), EventLog.LogType.PROGRESS)
	if ScreenJuice:
		ScreenJuice.show_toast("✅", _tr_format_safe("TOAST_SUPPORT_COMPLETED", client_name, "✅ Contract completed: %s" % client_name))

	_release_and_archive(proj)

func _process_final_payout(proj: SupportProjectData):
	if proj == null:
		return
	var start_day = max(proj.week_start_day, proj.created_at_day)
	var last_paid_day = min(proj.end_day, GameTime.day - 1)
	if last_paid_day < start_day:
		return

	var worked_days = _count_workdays_between(start_day, last_paid_day)
	if worked_days <= 0:
		return

	var overdue_count = 0
	for ticket in proj.tickets:
		if ticket is SupportTicketData and ticket.is_overdue and not ticket.is_completed:
			overdue_count += 1

	var effective_rate = get_effective_daily_rate(proj)
	var base_payout = worked_days * effective_rate
	var penalty_percent = min(overdue_count * 10, 100)
	var final_payout = int(base_payout * (1.0 - float(penalty_percent) / 100.0))

	if final_payout > 0:
		GameState.add_income(final_payout)
		GameState.daily_income_details.append({"reason": tr("PROJ_CAT_SUPPORT"), "amount": final_payout, "category": "support"})
		proj.total_earned += final_payout

	var client = proj.get_client()
	var client_name = client.get_display_name() if client else proj.client_id
	EventLog.add(_tr_format_safe("LOG_SUPPORT_FINAL_PAYOUT", [client_name, final_payout], "💰 Support %s: final payout $%d" % [client_name, final_payout]), EventLog.LogType.PROGRESS)
	if ScreenJuice:
		ScreenJuice.show_toast("💰", _tr_format_safe("TOAST_SUPPORT_PAYOUT", final_payout, "Support: +$%d" % final_payout))

func _release_and_archive(proj: SupportProjectData):
	if proj == null:
		return
	proj.assigned_support_employee = null
	for ticket in proj.tickets:
		if not (ticket is SupportTicketData):
			continue
			ticket.assigned_worker = null
			if not ticket.is_completed:
				ticket.progress = 0.0
				ticket.is_overdue = false

	_planned_ticket_minutes.erase(proj.project_id)
	_planned_ticket_day.erase(proj.project_id)

	active_support_projects.erase(proj)
	if not completed_support_projects.has(proj):
		completed_support_projects.append(proj)

func _count_workdays_between(start_day: int, end_day: int) -> int:
	if end_day < start_day:
		return 0
	var count = 0
	for d in range(start_day, end_day + 1):
		if not GameTime.is_weekend(d):
			count += 1
	return count

func _add_working_days(start_day: int, work_days: int) -> int:
	var target = start_day
	var left = work_days
	while left > 0:
		target += 1
		if not GameTime.is_weekend(target):
			left -= 1
	return target

func _get_next_monday(day_value: int) -> int:
	var d = day_value + 1
	while GameTime.get_weekday_index(d) != 0:
		d += 1
	return d

func _get_employee_node(data: EmployeeData):
	if not data:
		return null
	for npc in get_tree().get_nodes_in_group("npc"):
		if npc.data == data:
			return npc
	return null

func _get_skill_for_role(role: String, worker: EmployeeData) -> int:
	match role:
		"BA":
			return worker.skill_business_analysis
		"DEV":
			return worker.skill_backend
		"QA":
			return worker.skill_qa
	return 10

func serialize() -> Dictionary:
	return {
		"active": _serialize_projects_array(active_support_projects),
		"completed": _serialize_projects_array(completed_support_projects),
	}

func deserialize(d: Dictionary):
	active_support_projects.clear()
	completed_support_projects.clear()
	_planned_ticket_minutes.clear()
	_planned_ticket_day.clear()

	for pd in d.get("active", []):
		var proj = _deserialize_project_dict(pd)
		if proj:
			active_support_projects.append(proj)
	for pd in d.get("completed", []):
		var proj = _deserialize_project_dict(pd)
		if proj:
			completed_support_projects.append(proj)

func _serialize_projects_array(arr: Array) -> Array:
	var out: Array = []
	for proj in arr:
		if not (proj is SupportProjectData):
			continue
			var pd = {
				"project_id": proj.project_id,
				"client_id": proj.client_id,
				"title": proj.title,
				"created_at_day": proj.created_at_day,
				"sla_level": proj.sla_level,
				"daily_rate": proj.daily_rate,
				"is_active": proj.is_active,
				"contract_duration_days": proj.contract_duration_days,
				"duration_bonus_percent": proj.duration_bonus_percent,
				"end_day": proj.end_day,
				"weekly_overdue_count": proj.weekly_overdue_count,
				"termination_reason": proj.termination_reason,
				"week_start_day": proj.week_start_day,
				"total_earned": proj.total_earned,
				"total_labor_cost": proj.total_labor_cost,
				"assigned_support_employee": proj.assigned_support_employee.employee_name if proj.assigned_support_employee else "",
				"tickets": [],
			}
			for ticket in proj.tickets:
				if not (ticket is SupportTicketData):
					continue
					pd["tickets"].append({
						"ticket_id": ticket.ticket_id,
						"required_role": ticket.required_role,
						"work_amount": ticket.work_amount,
						"progress": ticket.progress,
						"created_at_day": ticket.created_at_day,
						"deadline_day": ticket.deadline_day,
						"is_completed": ticket.is_completed,
						"is_overdue": ticket.is_overdue,
						"assigned_worker": ticket.assigned_worker.employee_name if ticket.assigned_worker else "",
					})
			out.append(pd)
	return out

func _deserialize_project_dict(d: Dictionary) -> SupportProjectData:
	if d.is_empty():
		return null
	var proj = SupportProjectData.new()
	proj.project_id = str(d.get("project_id", ""))
	proj.client_id = str(d.get("client_id", ""))
	proj.title = str(d.get("title", ""))
	proj.created_at_day = int(d.get("created_at_day", 0))
	proj.sla_level = str(d.get("sla_level", "medium"))
	proj.daily_rate = int(d.get("daily_rate", 0))
	proj.is_active = bool(d.get("is_active", true))
	proj.contract_duration_days = int(d.get("contract_duration_days", 10))
	proj.duration_bonus_percent = int(d.get("duration_bonus_percent", 0))
	proj.end_day = int(d.get("end_day", 0))
	proj.weekly_overdue_count = int(d.get("weekly_overdue_count", 0))
	proj.termination_reason = str(d.get("termination_reason", ""))
	proj.week_start_day = int(d.get("week_start_day", proj.created_at_day))
	proj.total_earned = int(d.get("total_earned", 0))
	proj.total_labor_cost = float(d.get("total_labor_cost", 0.0))
	proj.assigned_support_employee = _find_employee_by_name(str(d.get("assigned_support_employee", "")))
	if proj.end_day == 0 and proj.is_active:
		proj.end_day = _add_working_days(GameTime.day, 10)

	for td in d.get("tickets", []):
		var ticket = SupportTicketData.new()
		ticket.ticket_id = str(td.get("ticket_id", ""))
		ticket.required_role = str(td.get("required_role", ""))
		ticket.work_amount = int(td.get("work_amount", 0))
		ticket.progress = float(td.get("progress", 0.0))
		ticket.created_at_day = int(td.get("created_at_day", 0))
		ticket.deadline_day = int(td.get("deadline_day", 0))
		ticket.is_completed = bool(td.get("is_completed", false))
		ticket.is_overdue = bool(td.get("is_overdue", false))
		ticket.assigned_worker = _find_employee_by_name(str(td.get("assigned_worker", "")))
		proj.tickets.append(ticket)
	return proj

func _find_employee_by_name(employee_name: String) -> EmployeeData:
	if employee_name == "":
		return null
	for npc in get_tree().get_nodes_in_group("npc"):
		if npc.data and npc.data.employee_name == employee_name:
			return npc.data
	return null