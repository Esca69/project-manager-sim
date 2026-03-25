extends Node

# === PEOPLE HISTORY SINGLETON ===
# Stores the entire game's daily employee data for reporting

var daily_records: Array = []
# Each element is a Dictionary:
# {
#   day: int,
#   team_size: int,
#   avg_mood: float,
#   avg_energy: float,
#   avg_burnout: float,
#   employees: [
#     {
#       name: String,
#       job_title: String,
#       employment_type: String,
#       monthly_salary: int,
#       daily_salary: float,
#       mood: float,
#       energy: float,
#       burnout: float,
#       work_minutes: float,
#       progress: float,
#       days_in_company: int,
#       grade: int,
#     }
#   ]
# }

func record_day():
	var npcs = get_tree().get_nodes_in_group("npc")
	if npcs.is_empty():
		return

	var employees_data = []
	var total_mood = 0.0
	var total_energy = 0.0
	var total_burnout = 0.0
	var count = 0

	for npc in npcs:
		if not npc.data:
			continue
		var d = npc.data
		var emp = {
			"name": d.get_display_name() if d.has_method("get_display_name") else str(d.employee_name),
			"job_title": str(d.job_title),
			"employment_type": str(d.employment_type),
			"monthly_salary": int(d.monthly_salary),
			"daily_salary": float(d.monthly_salary) / 22.0,
			"mood": float(d.mood),
			"energy": float(d.current_energy),
			"burnout": float(d.burnout_level),
			"work_minutes": float(d.get_meta("daily_work_minutes", 0.0)),
			"progress": float(d.get_meta("daily_progress", 0.0)),
			"days_in_company": int(d.days_in_company),
			"grade": int(d.employee_level),
		}
		employees_data.append(emp)
		total_mood    += emp["mood"]
		total_energy  += emp["energy"]
		total_burnout += emp["burnout"]
		count += 1

	var record = {
		"day": GameTime.day,
		"team_size": count,
		"avg_mood":    total_mood    / max(count, 1),
		"avg_energy":  total_energy  / max(count, 1),
		"avg_burnout": total_burnout / max(count, 1),
		"employees": employees_data,
	}
	daily_records.append(record)

func reset():
	daily_records.clear()
