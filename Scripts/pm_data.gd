extends Node

# === ОПЫТ ===
var xp: int = 0
var skill_points: int = 0

signal xp_changed(new_xp: int, new_skill_points: int)
signal skill_unlocked(skill_id: String)
signal level_up(new_level: int)

# === ВНЕШНОСТЬ ИГРОКА ===
var appearance_gender: String = "male"       # "male" | "female"
var appearance_body_type: String = "default" # "default" | "man_fat" | "man_fit" | "man_skinny" | "woman_fat" | "woman_fit" | "woman_skinny"
var appearance_skin_color: Color = Color("#FFE0BD")
var appearance_hair_type: int = 0            # 0..N-1 по массиву MALE/FEMALE_HAIR_PATHS; -1 = без волос
var appearance_hair_color: Color = Color("#C8A882")
var appearance_clothing_color: Color = Color("#A0C4FF")  # Цвет одежды из CLOTHING_PALETTE

# === ТРЕЙТЫ ПЕРСОНАЖА ===
var pm_traits: Array[String] = []

const PM_TRAIT_STARTING_POINTS: int = 3

# Определения всех PM-трейтов
const PM_TRAIT_DEFINITIONS: Array = [
	# Положительные (cost > 0) — идут первыми
	{
		"id": "pm_sprinter",
		"name_key": "PM_TRAIT_SPRINTER_NAME",
		"desc_key": "PM_TRAIT_SPRINTER_DESC",
		"cost": 1,
		"positive": true,
		"conflict_group": "speed",
	},
	{
		"id": "pm_extrovert",
		"name_key": "PM_TRAIT_EXTROVERT_NAME",
		"desc_key": "PM_TRAIT_EXTROVERT_DESC",
		"cost": 1,
		"positive": true,
		"conflict_group": "social",
	},
	{
		"id": "pm_fast_learner",
		"name_key": "PM_TRAIT_FAST_LEARNER_NAME",
		"desc_key": "PM_TRAIT_FAST_LEARNER_DESC",
		"cost": 2,
		"positive": true,
		"conflict_group": "learning",
	},
	{
		"id": "pm_introvert",
		"name_key": "PM_TRAIT_INTROVERT_NAME",
		"desc_key": "PM_TRAIT_INTROVERT_DESC",
		"cost": -1,
		"positive": true,
		"conflict_group": "social",
	},
	{
		"id": "pm_trained",
		"name_key": "PM_TRAIT_TRAINED_NAME",
		"desc_key": "PM_TRAIT_TRAINED_DESC",
		"cost": 1,
		"positive": true,
		"conflict_group": "training",
	},
	{
		"id": "pm_well_trained",
		"name_key": "PM_TRAIT_WELL_TRAINED_NAME",
		"desc_key": "PM_TRAIT_WELL_TRAINED_DESC",
		"cost": 2,
		"positive": true,
		"conflict_group": "training",
	},
	# Отрицательные (cost < 0) — идут вторыми
	{
		"id": "pm_slowmover",
		"name_key": "PM_TRAIT_SLOWMOVER_NAME",
		"desc_key": "PM_TRAIT_SLOWMOVER_DESC",
		"cost": -1,
		"positive": false,
		"conflict_group": "speed",
	},
	{
		"id": "pm_slow_learner",
		"name_key": "PM_TRAIT_SLOW_LEARNER_NAME",
		"desc_key": "PM_TRAIT_SLOW_LEARNER_DESC",
		"cost": -2,
		"positive": false,
		"conflict_group": "learning",
	},
]

# === META PROGRESSION ===
var personal_balance: int = 0
var monthly_salary: int = 1000
var partner_tier: int = 0  # 0=нет, 1=Младший(1%), 2=Партнер(5%), 3=Старший(10%)

const WIN_TARGET: int = 300000

const PARTNER_TIERS = {
	0: {"name_key": "PARTNER_NONE", "percent": 0.0},
	1: {"name_key": "PARTNER_JUNIOR", "percent": 0.01},
	2: {"name_key": "PARTNER_MID", "percent": 0.05},
	3: {"name_key": "PARTNER_SENIOR", "percent": 0.10},
}

signal personal_balance_changed(new_amount: int)

func change_personal_balance(amount: int):
	personal_balance += amount
	emit_signal("personal_balance_changed", personal_balance)

func get_daily_salary() -> int:
	return int(monthly_salary / 22.0)

func get_partner_percent() -> float:
	return PARTNER_TIERS.get(partner_tier, {}).get("percent", 0.0)

func get_partner_name() -> String:
	return tr(PARTNER_TIERS.get(partner_tier, {}).get("name_key", "PARTNER_NONE"))

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
	"daily_report": {
		"name": "SKILL_DAILY_REPORT_NAME",
		"description": "SKILL_DAILY_REPORT_DESC",
		"cost": 1,
		"prerequisite": "",
		"category": "analytics",
		"branch": "daily_report",
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

	"work_is_fun": {
		"name": "SKILL_WORK_FUN_NAME",
		"description": "SKILL_WORK_FUN_DESC",
		"cost": 1,
		"prerequisite": "",
		"category": "active",
		"branch": "work_is_fun",
		"branch_order": 0,
	},

	# ================================
	# === КАТЕГОРИЯ: ПАССИВНЫЕ ===
	# ================================

	"move_speed_1": {
		"name": "SKILL_MOVE_SPEED_1_NAME",
		"description": "SKILL_MOVE_SPEED_1_DESC",
		"cost": 1,
		"prerequisite": "",
		"category": "passive",
		"branch": "move_speed",
		"branch_order": 0,
	},
	"move_speed_2": {
		"name": "SKILL_MOVE_SPEED_2_NAME",
		"description": "SKILL_MOVE_SPEED_2_DESC",
		"cost": 2,
		"prerequisite": "move_speed_1",
		"category": "passive",
		"branch": "move_speed",
		"branch_order": 1,
	},

	# ==================================
	# === НОВЫЕ НАВЫКИ: ЛЮДИ ===
	# ==================================

	"read_mood": {
		"name": "SKILL_READ_MOOD_NAME",
		"description": "SKILL_READ_MOOD_DESC",
		"cost": 1,
		"prerequisite": "",
		"category": "people",
		"branch": "read_mood",
		"branch_order": 0,
	},

	"read_efficiency": {
		"name": "SKILL_READ_EFFICIENCY_NAME",
		"description": "SKILL_READ_EFFICIENCY_DESC",
		"cost": 1,
		"prerequisite": "",
		"category": "people",
		"branch": "read_efficiency",
		"branch_order": 0,
	},

	# ===================================
	# === НОВЫЕ НАВЫКИ: АНАЛИТИКА ===
	# ===================================

	"report_finance_tab": {
		"name": "SKILL_REPORT_FINANCE_TAB_NAME",
		"description": "SKILL_REPORT_FINANCE_TAB_DESC",
		"cost": 1,
		"prerequisite": "",
		"prerequisites": ["daily_report"],
		"category": "analytics",
		"branch": "report_finance_tab",
		"branch_order": 0,
	},

	"report_people_tab": {
		"name": "SKILL_REPORT_PEOPLE_TAB_NAME",
		"description": "SKILL_REPORT_PEOPLE_TAB_DESC",
		"cost": 1,
		"prerequisite": "",
		"prerequisites": ["daily_report"],
		"category": "analytics",
		"branch": "report_people_tab",
		"branch_order": 0,
	},

	# ===================================
	# === НОВЫЕ НАВЫКИ: ПРОЕКТЫ ===
	# ===================================

	"crisis_management": {
		"name": "SKILL_CRISIS_MANAGEMENT_NAME",
		"description": "SKILL_CRISIS_MANAGEMENT_DESC",
		"cost": 2,
		"prerequisite": "",
		"category": "projects",
		"branch": "crisis_management",
		"branch_order": 0,
	},

	# ====================================
	# === КАТЕГОРИЯ: УПРАВЛЕНИЕ ===
	# ====================================
	"desk_one_time_unlock": {
		"name": "SKILL_DESK_ONE_TIME_NAME",
		"description": "SKILL_DESK_ONE_TIME_DESC",
		"cost": 1,
		"prerequisite": "",
		"category": "management",
		"branch": "desk_one_time",
		"branch_order": 0,
	},
	"desk_subs_unlock": {
		"name": "SKILL_DESK_SUBS_NAME",
		"description": "SKILL_DESK_SUBS_DESC",
		"cost": 1,
		"prerequisite": "",
		"category": "management",
		"branch": "desk_subs",
		"branch_order": 0,
	},
	"interact_feedback_unlock": {
		"name": "SKILL_INTERACT_FEEDBACK_NAME",
		"description": "SKILL_INTERACT_FEEDBACK_DESC",
		"cost": 1,
		"prerequisite": "",
		"category": "management",
		"branch": "interact_feedback",
		"branch_order": 0,
	},
	"interact_hr_tools_unlock": {
		"name": "SKILL_INTERACT_HR_TOOLS_NAME",
		"description": "SKILL_INTERACT_HR_TOOLS_DESC",
		"cost": 1,
		"prerequisite": "",
		"category": "management",
		"branch": "interact_hr_tools",
		"branch_order": 0,
	},
}

# === ИЗУЧЕННЫЕ НАВЫКИ ===
var unlocked_skills: Array[String] = []

func _ready():
	pass

# === XP ===
func add_xp(amount: int):
	var old_level = get_level()
	var multiplied_amount = int(amount * get_xp_multiplier_from_traits())
	xp += multiplied_amount
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
	if get_level() > old_level:
		emit_signal("level_up", get_level())

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
	# Одиночный пререквизит (старый формат)
	var prereq = skill.get("prerequisite", "")
	if prereq != "" and prereq not in unlocked_skills:
		return false
	# Множественные пререквизиты (новый формат)
	var prereqs = skill.get("prerequisites", [])
	for p in prereqs:
		if p not in unlocked_skills:
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

func get_hr_search_minutes() -> int:
	if has_skill("hr_search_speed_2"): return 60
	if has_skill("hr_search_speed_1"): return 90
	return 120

func get_hr_cutoff_hour() -> int:
	return 18 - ceili(float(get_hr_search_minutes()) / 60.0)

# === АНАЛИТИКА ===
func can_see_expense_details() -> bool:
	return has_skill("daily_report")

func can_see_project_analytics() -> bool:
	return has_skill("daily_report")

func can_see_productivity() -> bool:
	return has_skill("daily_report")

func can_see_finance_report() -> bool:
	return has_skill("report_finance_tab")

func can_see_people_report() -> bool:
	return has_skill("report_people_tab")

# === PM ТРЕЙТЫ: ХЕЛПЕРЫ ===

func has_pm_trait(trait_id: String) -> bool:
	return trait_id in pm_traits

func get_used_trait_points() -> int:
	var total: int = 0
	for t in pm_traits:
		for def in PM_TRAIT_DEFINITIONS:
			if def.id == t:
				total += def.cost
				break
	return total

func get_free_trait_points() -> int:
	return PM_TRAIT_STARTING_POINTS - get_used_trait_points()

func can_take_trait(trait_id: String) -> bool:
	if trait_id in pm_traits:
		return false
	var target_def: Dictionary = {}
	for def in PM_TRAIT_DEFINITIONS:
		if def.id == trait_id:
			target_def = def
			break
	if target_def.is_empty():
		return false
	for existing_id in pm_traits:
		for def in PM_TRAIT_DEFINITIONS:
			if def.id == existing_id and def.conflict_group == target_def.conflict_group:
				return false
	var new_free = get_free_trait_points() - target_def.cost
	if new_free < 0:
		return false
	return true

func toggle_pm_trait(trait_id: String) -> bool:
	if trait_id in pm_traits:
		pm_traits.erase(trait_id)
		return true
	if can_take_trait(trait_id):
		pm_traits.append(trait_id)
		return true
	return false

# === XP: с учётом трейта ===
func get_xp_multiplier_from_traits() -> float:
	if has_pm_trait("pm_fast_learner"): return 1.20
	if has_pm_trait("pm_slow_learner"): return 0.80
	return 1.0

# === ДВИЖЕНИЕ ===
func get_movement_bonus() -> float:
	var skill_bonus: float = 0.0
	if has_skill("move_speed_2"): skill_bonus = 0.40
	elif has_skill("move_speed_1"): skill_bonus = 0.20

	var trait_bonus: float = 0.0
	if has_pm_trait("pm_sprinter"): trait_bonus = 0.20
	elif has_pm_trait("pm_slowmover"): trait_bonus = -0.20

	return skill_bonus + trait_bonus

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
