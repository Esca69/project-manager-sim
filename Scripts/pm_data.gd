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
const SKILL_TREE = {
	# ===========================
	# === КАТЕГОРИЯ: ПРОЕКТЫ ===
	# ===========================

	# --- Оценка объёма (2 навыка) ---
	"estimate_work_1": {
		"name": "📐 Оценка объёма I",
		"description": "Объём работ по проекту показан как вилка ±20% вместо ±40%",
		"cost": 1,
		"prerequisite": "",
		"category": "projects",
		"branch": "estimate_work",
		"branch_order": 0,
	},
	"estimate_work_2": {
		"name": "📐 Оценка объёма II",
		"description": "Вы видите точный объём работ по каждому этапу",
		"cost": 2,
		"prerequisite": "estimate_work_1",
		"category": "projects",
		"branch": "estimate_work",
		"branch_order": 1,
	},

	# --- Оценка бюджета (2 навыка) ---
	"estimate_budget_1": {
		"name": "💰 Оценка бюджета I",
		"description": "Бюджет проекта показан как вилка ±15% вместо ±35%",
		"cost": 1,
		"prerequisite": "",
		"category": "projects",
		"branch": "estimate_budget",
		"branch_order": 0,
	},
	"estimate_budget_2": {
		"name": "💰 Оценка бюджета II",
		"description": "Вы видите точный бюджет проекта",
		"cost": 2,
		"prerequisite": "estimate_budget_1",
		"category": "projects",
		"branch": "estimate_budget",
		"branch_order": 1,
	},

	# --- Лимит проектов (2 навыка) ---
	"project_limit_1": {
		"name": "📁 Лимит проектов I",
		"description": "Максимум активных проектов увеличен до 3 (было 2)",
		"cost": 1,
		"prerequisite": "",
		"category": "projects",
		"branch": "project_limit",
		"branch_order": 0,
	},
	"project_limit_2": {
		"name": "📁 Лимит проектов II",
		"description": "Максимум активных проектов увеличен до 5",
		"cost": 2,
		"prerequisite": "project_limit_1",
		"category": "projects",
		"branch": "project_limit",
		"branch_order": 1,
	},

	# --- Скорость обсуждения (2 навыка) ---
	"boss_meeting_speed_1": {
		"name": "⏱ Скорость обсуждения I",
		"description": "Обсуждение проекта с боссом занимает 3 часа вместо 4",
		"cost": 1,
		"prerequisite": "",
		"category": "projects",
		"branch": "boss_meeting_speed",
		"branch_order": 0,
	},
	"boss_meeting_speed_2": {
		"name": "⏱ Скорость обсуждения II",
		"description": "Обсуждение проекта с боссом занимает 2 часа",
		"cost": 2,
		"prerequisite": "boss_meeting_speed_1",
		"category": "projects",
		"branch": "boss_meeting_speed",
		"branch_order": 1,
	},

	# ========================
	# === КАТЕГОРИЯ: ЛЮДИ ===
	# ========================

	# --- Чтение людей (3 навыка) ---
	"read_traits_1": {
		"name": "👁 Чтение людей I",
		"description": "При найме вы видите 1 трейт кандидата",
		"cost": 1,
		"prerequisite": "",
		"category": "people",
		"branch": "read_traits",
		"branch_order": 0,
	},
	"read_traits_2": {
		"name": "👁 Чтение людей II",
		"description": "При найме вы видите 2 трейта кандидата",
		"cost": 1,
		"prerequisite": "read_traits_1",
		"category": "people",
		"branch": "read_traits",
		"branch_order": 1,
	},
	"read_traits_3": {
		"name": "👁 Чтение людей III",
		"description": "Вы видите все трейты кандидата при найме",
		"cost": 2,
		"prerequisite": "read_traits_2",
		"category": "people",
		"branch": "read_traits",
		"branch_order": 2,
	},

	# --- Оценка кадров (3 навыка) ---
	"read_skills_1": {
		"name": "📊 Оценка кадров I",
		"description": "Навыки кандидата показаны как «Низкий / Средний / Высокий»\nвместо полного скрытия",
		"cost": 1,
		"prerequisite": "",
		"category": "people",
		"branch": "read_skills",
		"branch_order": 0,
	},
	"read_skills_2": {
		"name": "📊 Оценка кадров II",
		"description": "Навыки кандидата показаны как диапазон (100–150)",
		"cost": 1,
		"prerequisite": "read_skills_1",
		"category": "people",
		"branch": "read_skills",
		"branch_order": 1,
	},
	"read_skills_3": {
		"name": "📊 Оценка кадров III",
		"description": "Вы видите точные значения навыков кандидата",
		"cost": 2,
		"prerequisite": "read_skills_2",
		"category": "people",
		"branch": "read_skills",
		"branch_order": 2,
	},

	# --- Кандидаты на вакансию (2 навыка) ---
	"candidate_count_1": {
		"name": "👤 Кандидаты I",
		"description": "При поиске HR выдаёт 3 кандидата вместо 2",
		"cost": 1,
		"prerequisite": "",
		"category": "people",
		"branch": "candidate_count",
		"branch_order": 0,
	},
	"candidate_count_2": {
		"name": "👤 Кандидаты II",
		"description": "При поиске HR выдаёт 5 кандидатов",
		"cost": 2,
		"prerequisite": "candidate_count_1",
		"category": "people",
		"branch": "candidate_count",
		"branch_order": 1,
	},

	# --- Скорость поиска (2 навыка) ---
	"hr_search_speed_1": {
		"name": "🔍 Скорость поиска I",
		"description": "Поиск кандидатов занимает 1.5 часа вместо 2",
		"cost": 1,
		"prerequisite": "",
		"category": "people",
		"branch": "hr_search_speed",
		"branch_order": 0,
	},
	"hr_search_speed_2": {
		"name": "🔍 Скорость поиска II",
		"description": "Поиск кандидатов занимает 1 час",
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
		"name": "📋 Учёт расходов",
		"description": "В дневном отчёте видна детализация затрат:\nкому выплачена зарплата и сколько",
		"cost": 1,
		"prerequisite": "",
		"category": "analytics",
		"branch": "report_expenses",
		"branch_order": 0,
	},
	"report_projects": {
		"name": "📋 Аналитика проектов",
		"description": "В дневном отчёте видны этапы проектов,\nпроцент прогресса и дни до дедлайнов",
		"cost": 1,
		"prerequisite": "",
		"category": "analytics",
		"branch": "report_projects",
		"branch_order": 0,
	},
	"report_productivity": {
		"name": "📋 Оценка продуктивности",
		"description": "В дневном отчёте видно кто из сотрудников\nсколько часов работал и сколько очков принёс",
		"cost": 1,
		"prerequisite": "",
		"category": "analytics",
		"branch": "report_productivity",
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
			skill_points += 1
			print("🎯 PM получил очко навыка! (всего: ", skill_points, ")")
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
	print("🧠 PM изучил навык: ", skill["name"])
	emit_signal("skill_unlocked", skill_id)
	emit_signal("xp_changed", xp, skill_points)
	return true

func has_skill(skill_id: String) -> bool:
	return skill_id in unlocked_skills

# === ПОМОЩНИКИ ДЛЯ UI ===

# --- Оценка объёма (0=база, 1=лучше, 2=точно) ---
func get_work_estimate_level() -> int:
	if has_skill("estimate_work_2"): return 2
	if has_skill("estimate_work_1"): return 1
	return 0

# --- Оценка бюджета (0=база, 1=лучше, 2=точно) ---
func get_budget_estimate_level() -> int:
	if has_skill("estimate_budget_2"): return 2
	if has_skill("estimate_budget_1"): return 1
	return 0

# --- Трейты ---
func get_visible_traits_count() -> int:
	if has_skill("read_traits_3"): return 999
	if has_skill("read_traits_2"): return 2
	if has_skill("read_traits_1"): return 1
	return 0

# --- Навыки кандидатов ---
func get_skill_read_level() -> int:
	if has_skill("read_skills_3"): return 3
	if has_skill("read_skills_2"): return 2
	if has_skill("read_skills_1"): return 1
	return 0

# === НОВЫЕ ХЕЛПЕРЫ ===

# --- Максимум активных проектов (2 → 3 → 5) ---
func get_max_projects() -> int:
	if has_skill("project_limit_2"): return 5
	if has_skill("project_limit_1"): return 3
	return 2

# --- Количество кандидатов при поиске (2 → 3 → 5) ---
func get_candidate_count() -> int:
	if has_skill("candidate_count_2"): return 5
	if has_skill("candidate_count_1"): return 3
	return 2

# --- Время обсуждения с боссом в часах (4 → 3 → 2) ---
func get_boss_meeting_hours() -> int:
	if has_skill("boss_meeting_speed_2"): return 2
	if has_skill("boss_meeting_speed_1"): return 3
	return 4

# --- Время поиска HR в минутах (120 → 90 → 60) ---
func get_hr_search_minutes() -> int:
	if has_skill("hr_search_speed_2"): return 60
	if has_skill("hr_search_speed_1"): return 90
	return 120

# --- Cutoff hour для босса (18 - часы обсуждения) ---
func get_boss_cutoff_hour() -> int:
	return 18 - get_boss_meeting_hours()

# --- Cutoff hour для HR (18 - ceil(минуты / 60)) ---
func get_hr_cutoff_hour() -> int:
	return 18 - ceili(float(get_hr_search_minutes()) / 60.0)

# === АНАЛИТИКА (для дневного отчёта) ===
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
			if real_value < 80: return "Низкий"
			elif real_value < 140: return "Средний"
			else: return "Высокий"
		2:
			var spread = int(real_value * 0.20)
			var low = max(1, real_value - spread)
			var high = real_value + spread
			return "%d – %d" % [low, high]
		3: return str(real_value)
	return "???"
