extends Node

# === ОПЫТ ===
var xp: int = 0
var skill_points: int = 0

signal xp_changed(new_xp: int, new_skill_points: int)
signal skill_unlocked(skill_id: String)

# === ПОРОГИ XP ДЛЯ ПОЛУЧЕНИЯ ОЧКОВ ===
const XP_THRESHOLDS = [
	50, 120, 200, 300, 420, 560, 720, 900, 1100, 1320,
	1560, 1820, 2100, 2400, 2720, 3060, 3420, 3800, 4200, 4620,
]

var _last_threshold_index: int = -1

# === ОПРЕДЕЛЕНИЕ НАВЫКОВ ===
# Теперь используем ключи локализации вместо прямого текста
const SKILL_TREE = {
	# ===========================
	# === КАТЕГОРИЯ: ПРОЕКТЫ ===
	# ===========================

	"estimate_work_1": {
		"name": "SKILL_ESTIMATE_WORK_1_NAME",
		"description": "SKILL_ESTIMATE_WORK_1_DESC",
		"cost": 1,
		"prerequisite": "",
		"category": "projects",
		"branch": "estimate_work",
		"branch_order": 0,
	},
	"estimate_work_2": {
		"name": "SKILL_ESTIMATE_WORK_2_NAME",
		"description": "SKILL_ESTIMATE_WORK_2_DESC",
		"cost": 2,
		"prerequisite": "estimate_work_1",
		"category": "projects",
		"branch": "estimate_work",
		"branch_order": 1,
	},

	"estimate_budget_1": {
		"name": "SKILL_ESTIMATE_BUDGET_1_NAME",
		"description": "SKILL_ESTIMATE_BUDGET_1_DESC",
		"cost": 1,
		"prerequisite": "",
		"category": "projects",
		"branch": "estimate_budget",
		"branch_order": 0,
	},
	"estimate_budget_2": {
		"name": "SKILL_ESTIMATE_BUDGET_2_NAME",
		"description": "SKILL_ESTIMATE_BUDGET_2_DESC",
		"cost": 2,
		"prerequisite": "estimate_budget_1",
		"category": "projects",
		"branch": "estimate_budget",
		"branch_order": 1,
	},

	"project_limit_1": {
		"name": "SKILL_PROJECT_LIMIT_1_NAME",
		"description": "SKILL_PROJECT_LIMIT_1_DESC",
		"cost": 1,
		"prerequisite": "",
		"category": "projects",
		"branch": "project_limit",
		"branch_order": 0,
	},
	"project_limit_2": {
		"name": "SKILL_PROJECT_LIMIT_2_NAME",
		"description": "SKILL_PROJECT_LIMIT_2_DESC",
		"cost": 2,
		"prerequisite": "project_limit_1",
		"category": "projects",
		"branch": "project_limit",
		"branch_order": 1,
	},

	"boss_meeting_speed_1": {
		"name": "SKILL_BOSS_MEETING_SPEED_1_NAME",
		"description": "SKILL_BOSS_MEETING_SPEED_1_DESC",
		"cost": 1,
		"prerequisite": "",
		"category": "projects",
		"branch": "boss_meeting_speed",
		"branch_order": 0,
	},
	"boss_meeting_speed_2": {
		"name": "SKILL_BOSS_MEETING_SPEED_2_NAME",
		"description": "SKILL_BOSS_MEETING_SPEED_2_DESC",
		"cost": 2,
		"prerequisite": "boss_meeting_speed_1",
		"category": "projects",
		"branch": "boss_meeting_speed",
		"branch_order": 1,
	},

	# ========================
	# === КАТЕГОРИЯ: ЛЮДИ ===
	# ========================

	"read_traits_1": {
		"name": "SKILL_READ_TRAITS_1_NAME",
		"description": "SKILL_READ_TRAITS_1_DESC",
		"cost": 1,
		"prerequisite": "",
		"category": "people",
		"branch": "read_traits",
		"branch_order": 0,
	},
	"read_traits_2": {
		"name": "SKILL_READ_TRAITS_2_NAME",
		"description": "SKILL_READ_TRAITS_2_DESC",
		"cost": 1,
		"prerequisite": "read_traits_1",
		"category": "people",
		"branch": "read_traits",
		"branch_order": 1,
	},
	"read_traits_3": {
		"name": "SKILL_READ_TRAITS_3_NAME",
		"description": "SKILL_READ_TRAITS_3_DESC",
		"cost": 2,
		"prerequisite": "read_traits_2",
		"category": "people",
		"branch": "read_traits",
		"branch_order": 2,
	},

	"read_skills_1": {
		"name": "SKILL_READ_SKILLS_1_NAME",
		"description": "SKILL_READ_SKILLS_1_DESC",
		"cost": 1,
		"prerequisite": "",
		"category": "people",
		"branch": "read_skills",
		"branch_order": 0,
	},
	"read_skills_2": {
		"name": "SKILL_READ_SKILLS_2_NAME",
		"description": "SKILL_READ_SKILLS_2_DESC",
		"cost": 1,
		"prerequisite": "read_skills_1",
		"category": "people",
		"branch": "read_skills",
		"branch_order": 1,
	},
	"read_skills_3": {
		"name": "SKILL_READ_SKILLS_3_NAME",
		"description": "SKILL_READ_SKILLS_3_DESC",
		"cost": 2,
		"prerequisite": "read_skills_2",
		"category": "people",
		"branch": "read_skills",
		"branch_order": 2,
	},

	"candidate_count_1": {
		"name": "SKILL_CANDIDATE_COUNT_1_NAME",
		"description": "SKILL_CANDIDATE_COUNT_1_DESC",
		"cost": 1,
		"prerequisite": "",
		"category": "people",
		"branch": "candidate_count",
		"branch_order": 0,
	},
	"candidate_count_2": {
		"name": "SKILL_CANDIDATE_COUNT_2_NAME",
		"description": "SKILL_CANDIDATE_COUNT_2_DESC",
		"cost": 2,
		"prerequisite": "candidate_count_1",
		"category": "people",
		"branch": "candidate_count",
		"branch_order": 1,
	},

	"hr_search_speed_1": {
		"name": "SKILL_HR_SEARCH_SPEED_1_NAME",
		"description": "SKILL_HR_SEARCH_SPEED_1_DESC",
		"cost": 1,
		"prerequisite": "",
		"category": "people",
		"branch": "hr_search_speed",
		"branch_order": 0,
	},
	"hr_search_speed_2": {
		"name": "SKILL_HR_SEARCH_SPEED_2_NAME",
		"description": "SKILL_HR_SEARCH_SPEED_2_DESC",
		"cost": 2,
		"prerequisite": "hr_search_speed_1",
		"category": "people",
		"branch": "hr_search_speed",
		"branch_order": 1,
	},

	# =============================
	# === КАТЕГОРИЯ: АНАЛИТИКА ===
	# =============================
	"report_expenses": {
		"name": "SKILL_REPORT_EXPENSES_NAME",
		"description": "SKILL_REPORT_EXPENSES_DESC",
		"cost": 1,
		"prerequisite": "",
		"category": "analytics",
		"branch": "report_expenses",
		"branch_order": 0,
	},
	"report_projects": {
		"name": "SKILL_REPORT_PROJECTS_NAME",
		"description": "SKILL_REPORT_PROJECTS_DESC",
		"cost": 1,
		"prerequisite": "",
		"category": "analytics",
		"branch": "report_projects",
		"branch_order": 0,
	},
	"report_productivity": {
		"name": "SKILL_REPORT_PRODUCTIVITY_NAME",
		"description": "SKILL_REPORT_PRODUCTIVITY_DESC",
		"cost": 1,
		"prerequisite": "",
		"category": "analytics",
		"branch": "report_productivity",
		"branch_order": 0,
	},

	# ===============================
	# === КАТЕГОРИЯ: АКТИВНЫЕ ===
	# ===============================

	"motivate": {
		"name": "SKILL_MOTIVATE_NAME",
		"description": "SKILL_MOTIVATE_DESC",
		"cost": 1,
		"prerequisite": "",
		"category": "active",
		"branch": "motivate",
		"branch_order": 0,
	},

	"no_toilet": {
		"name": "SKILL_NO_TOILET_NAME",
		"description": "SKILL_NO_TOILET_DESC",
		"cost": 1,
		"prerequisite": "",
		"category": "active",
		"branch": "no_toilet",
		"branch_order": 0,
	},
}

# === ИЗУЧЕННЫЕ НАВЫКИ ===
var unlocked_skills: Array[String] = []

func _ready():
	pass

# === XP ===
func add_xp(amount: int):
	xp += amount
	while true:
		var next_index = _last_threshold_index + 1
		if next_index >= XP_THRESHOLDS.size():
			break
		if xp >= XP_THRESHOLDS[next_index]:
			_last_threshold_index = next_index
			skill_points += 2
			print("🎯 PM получил очки навыков! (всего: ", skill_points, ")")
		else:
			break
	emit_signal("xp_changed", xp, skill_points)

# === УРОВЕНЬ ===
func get_level() -> int:
	return _last_threshold_index + 2

func get_level_progress() -> Array:
	var level_index = _last_threshold_index
	var prev_threshold = 0
	if level_index >= 0:
		prev_threshold = XP_THRESHOLDS[level_index]
	var next_index = level_index + 1
	if next_index >= XP_THRESHOLDS.size():
		return [1, 1]
	var next_threshold = XP_THRESHOLDS[next_index]
	var current_in_level = xp - prev_threshold
	var needed_for_level = next_threshold - prev_threshold
	return [current_in_level, needed_for_level]

# === НАВЫКИ ===
func can_unlock(skill_id: String) -> bool:
	if skill_id not in SKILL_TREE:
		return false
	if skill_id in unlocked_skills:
		return false
	var skill = SKILL_TREE[skill_id]
	if skill_points < skill["cost"]:
		return false
	var prereq = skill["prerequisite"]
	if prereq != "" and prereq not in unlocked_skills:
		return false
	return true

func unlock_skill(skill_id: String) -> bool:
	if not can_unlock(skill_id):
		return false
	var skill = SKILL_TREE[skill_id]
	skill_points -= skill["cost"]
	unlocked_skills.append(skill_id)
	# Используем tr() для вывода в консоль переведенного названия
	print("🧠 PM изучил навык: ", tr(skill["name"]))
	emit_signal("skill_unlocked", skill_id)
	emit_signal("xp_changed", xp, skill_points)
	return true

func has_skill(skill_id: String) -> bool:
	return skill_id in unlocked_skills

# === ПОМОЩНИКИ ДЛЯ UI ===

func get_work_estimate_level() -> int:
	if has_skill("estimate_work_2"): return 2
	if has_skill("estimate_work_1"): return 1
	return 0

func get_budget_estimate_level() -> int:
	if has_skill("estimate_budget_2"): return 2
	if has_skill("estimate_budget_1"): return 1
	return 0

func get_visible_traits_count() -> int:
	if has_skill("read_traits_3"): return 999
	if has_skill("read_traits_2"): return 2
	if has_skill("read_traits_1"): return 1
	return 0

func get_skill_read_level() -> int:
	if has_skill("read_skills_3"): return 3
	if has_skill("read_skills_2"): return 2
	if has_skill("read_skills_1"): return 1
	return 0

# === НОВЫЕ ХЕЛПЕРЫ ===

func get_max_projects() -> int:
	if has_skill("project_limit_2"): return 7
	if has_skill("project_limit_1"): return 5
	return 3

func get_candidate_count() -> int:
	if has_skill("candidate_count_2"): return 5
	if has_skill("candidate_count_1"): return 3
	return 2

func get_boss_meeting_hours() -> int:
	if has_skill("boss_meeting_speed_2"): return 2
	if has_skill("boss_meeting_speed_1"): return 3
	return 4

func get_hr_search_minutes() -> int:
	if has_skill("hr_search_speed_2"): return 60
	if has_skill("hr_search_speed_1"): return 90
	return 120

func get_boss_cutoff_hour() -> int:
	return 18 - get_boss_meeting_hours()

func get_hr_cutoff_hour() -> int:
	return 18 - ceili(float(get_hr_search_minutes()) / 60.0)

# === АНАЛИТИКА ===
func can_see_expense_details() -> bool:
	return has_skill("report_expenses")

func can_see_project_analytics() -> bool:
	return has_skill("report_projects")

func can_see_productivity() -> bool:
	return has_skill("report_productivity")

# === РАЗМЫТИЕ ===
func blur_value(real_value: int, spread_percent: float) -> String:
	if spread_percent <= 0:
		return str(real_value)
	var spread = int(real_value * spread_percent)
	var low = max(1, real_value - spread)
	var high = real_value + spread
	return "%d – %d" % [low, high]

func get_blurred_work(real_value: int) -> String:
	match get_work_estimate_level():
		0: return blur_value(real_value, 0.40)
		1: return blur_value(real_value, 0.20)
		2: return str(real_value)
	return blur_value(real_value, 0.40)

func get_blurred_budget(real_value: int) -> String:
	match get_budget_estimate_level():
		0: return blur_value(real_value, 0.35)
		1: return blur_value(real_value, 0.15)
		2: return "$" + str(real_value)
	return blur_value(real_value, 0.35)

func get_blurred_skill(real_value: int) -> String:
	match get_skill_read_level():
		0: return "???"
		1:
			if real_value < 80: return tr("SKILL_VAL_LOW")
			elif real_value < 140: return tr("SKILL_VAL_MEDIUM")
			else: return tr("SKILL_VAL_HIGH")
		2:
			var spread = int(real_value * 0.20)
			var low = max(1, real_value - spread)
			var high = real_value + spread
			return "%d – %d" % [low, high]
		3: return str(real_value)
	return "???"
