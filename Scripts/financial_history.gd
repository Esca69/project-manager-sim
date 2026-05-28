extends Node

# === FINANCIAL HISTORY SINGLETON ===
# Stores the entire game's daily financial data for reporting

var daily_records: Array = []
# Each element is a Dictionary:
# {
#   day: int,
#   income: int,
#   expenses: int,
#   balance: int,
#   salary_total: int,
#   pm_salary: int,
#   penalties: int,
#   office_costs: int,
#   training_costs: int,
#   bonus_costs: int,
#   service_costs: int,
#   projects_completed: int,
#   projects_failed: int,
#   project_income_details: [{title, payout, labor_cost, profit}],
# }

func record_day():
	var salary_total = 0
	for detail in GameState.daily_salary_details:
		salary_total += int(detail.get("amount", 0))

	# Use PMData directly for reliable PM salary identification
	var pm_salary = PMData.get_daily_salary()

	var penalties = 0
	var office_costs = 0
	var training_costs = 0
	var bonus_costs = 0
	for ev in GameState.daily_event_expenses:
		var amt = int(ev.get("amount", 0))
		var reason = str(ev.get("reason", ""))
		if reason == "SUMMARY_OFFICE_UPGRADES":
			office_costs += amt
		elif reason == "EXPENSE_MONITOR_REPAIR":
			office_costs += amt
		elif reason == "EXPENSE_TRAINING":
			training_costs += amt
		elif reason == "EXPENSE_BONUS":
			bonus_costs += amt
		else:
			penalties += amt

	var service_costs = 0
	for svc in GameState.daily_service_details:
		service_costs += int(svc.get("amount", 0))

	var support_income = 0
	for entry in GameState.daily_income_details:
		if str(entry.get("category", "")) == "support":
			support_income += int(entry.get("amount", 0))

	var project_details = []
	for entry in GameState.projects_finished_today:
		var proj = entry.get("project", null)
		var payout = int(entry.get("payout", 0))
		if proj == null:
			continue
		var labor_cost = int(proj.total_labor_cost) if "total_labor_cost" in proj else 0
		var profit = payout - labor_cost
		project_details.append({
			"title": proj.get_display_title() if proj.has_method("get_display_title") else str(proj.title),
			"payout": payout,
			"labor_cost": labor_cost,
			"profit": profit,
		})

	var record = {
		"day": GameTime.day,
		"income": GameState.daily_income,
		"support_income": support_income,
		"expenses": GameState.daily_expenses,
		"balance": GameState.company_balance,
		"salary_total": salary_total,
		"pm_salary": pm_salary,
		"penalties": penalties,
		"office_costs": office_costs,
		"training_costs": training_costs,
		"bonus_costs": bonus_costs,
		"service_costs": service_costs,
		"projects_completed": GameState.projects_finished_today.size(),
		"projects_failed": GameState.projects_failed_today.size(),
		"project_income_details": project_details,
	}
	daily_records.append(record)
