extends Node

# === ОПЫТ ===
var xp: int = 0
var skill_points: int = 0  # Доступные очки для вложения

signal xp_changed(new_xp: int, new_skill_points: int)
signal skill_unlocked(skill_id: String)

# === ПОРОГИ XP ДЛЯ ПОЛУЧЕНИЯ ОЧКОВ ===
# Каждый порог = 1 очко навыка
# Первые очки легко, потом сложнее
const XP_THRESHOLDS = [
	50, 120, 200, 300, 420, 560, 720, 900, 1100, 1320,
	1560, 1820, 2100, 2400, 2720, 3060, 3420, 3800, 4200, 4620,
]

var _last_threshold_index: int = -1  # Сколько порогов мы уже прошли

# === ОПРЕДЕЛЕНИЕ НАВЫКОВ ===
const SKILL_TREE = {
	# === ВЛЕВО: ПРОЕКТЫ ===
	# --- Ветка 1: Оценка объёма ---
	"estimate_work_1": {
		"name": "Оценка объёма I",
		"description": "Объём работ по проекту показан как вилка ±25% вместо ±40%",
		"cost": 1,
		"prerequisite": "",
		"direction": "projects_left",
		"branch": "estimate_work",
		"branch_order": 0,
	},
	"estimate_work_2": {
		"name": "Оценка объёма II",
		"description": "Объём работ по проекту показан как вилка ±10%",
		"cost": 1,
		"prerequisite": "estimate_work_1",
		"direction": "projects_left",
		"branch": "estimate_work",
		"branch_order": 1,
	},
	"estimate_work_3": {
		"name": "Оценка объёма III",
		"description": "Вы видите точный объём работ по каждому этапу",
		"cost": 2,
		"prerequisite": "estimate_work_2",
		"direction": "projects_left",
		"branch": "estimate_work",
		"branch_order": 2,
	},
	
	# --- Ветка 2: Оценка бюджета ---
	"estimate_budget_1": {
		"name": "Оценка бюджета I",
		"description": "Бюджет проекта показан как вилка ±20% вместо ±35%",
		"cost": 1,
		"prerequisite": "",
		"direction": "projects_left",
		"branch": "estimate_budget",
		"branch_order": 0,
	},
	"estimate_budget_2": {
		"name": "Оценка бюджета II",
		"description": "Бюджет проекта показан как вилка ±8%",
		"cost": 1,
		"prerequisite": "estimate_budget_1",
		"direction": "projects_left",
		"branch": "estimate_budget",
		"branch_order": 1,
	},
	"estimate_budget_3": {
		"name": "Оценка бюджета III",
		"description": "Вы видите точный бюджет проекта",
		"cost": 2,
		"prerequisite": "estimate_budget_2",
		"direction": "projects_left",
		"branch": "estimate_budget",
		"branch_order": 2,
	},
	
	# === ВПРАВО: ЛЮДИ ===
	# --- Ветка 3: Чтение людей (трейты) ---
	"read_traits_1": {
		"name": "Чтение людей I",
		"description": "При найме вы видите 1 трейт кандидата",
		"cost": 1,
		"prerequisite": "",
		"direction": "people_right",
		"branch": "read_traits",
		"branch_order": 0,
	},
	"read_traits_2": {
		"name": "Чтение людей II",
		"description": "При найме вы видите 2 трейта кандидата",
		"cost": 1,
		"prerequisite": "read_traits_1",
		"direction": "people_right",
		"branch": "read_traits",
		"branch_order": 1,
	},
	"read_traits_3": {
		"name": "Чтение людей III",
		"description": "Вы видите все трейты кандидата при найме",
		"cost": 2,
		"prerequisite": "read_traits_2",
		"direction": "people_right",
		"branch": "read_traits",
		"branch_order": 2,
	},
	
	# --- Ветка 4: Оценка навыков ---
	"read_skills_1": {
		"name": "Оценка кадров I",
		"description": "Навыки кандидата показаны как «Низкий / Средний / Высокий»\nвместо полного скрытия",
		"cost": 1,
		"prerequisite": "",
		"direction": "people_right",
		"branch": "read_skills",
		"branch_order": 0,
	},
	"read_skills_2": {
		"name": "Оценка кадров II",
		"description": "Навыки кандидата показаны как диапазон (100–150)",
		"cost": 1,
		"prerequisite": "read_skills_1",
		"direction": "people_right",
		"branch": "read_skills",
		"branch_order": 1,
	},
	"read_skills_3": {
		"name": "Оценка кадров III",
		"description": "Вы видите точные значения навыков кандидата",
		"cost": 2,
		"prerequisite": "read_skills_2",
		"direction": "people_right",
		"branch": "read_skills",
		"branch_order": 2,
	},
}

# === ИЗУЧЕННЫЕ НАВЫКИ ===
var unlocked_skills: Array[String] = []

func _ready():
	pass

# === XP ===
func add_xp(amount: int):
	xp += amount
	
	# Проверяем, не пора ли дать очко навыка
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
# Уровень = сколько порогов пройдено + 1 (начинаем с 1)
func get_level() -> int:
	return _last_threshold_index + 2  # +2 потому что index -1 = уровень 1

# XP текущего уровня и XP нужного для следующего (для прогресс-бара)
# Возвращает [current_xp_in_level, xp_needed_for_next_level]
func get_level_progress() -> Array:
	var level_index = _last_threshold_index  # После��ний пройденный порог
	
	# XP предыдущего порога (начало текущего уровня)
	var prev_threshold = 0
	if level_index >= 0:
		prev_threshold = XP_THRESHOLDS[level_index]
	
	# XP следующего порога (конец текущего уровня)
	var next_index = level_index + 1
	if next_index >= XP_THRESHOLDS.size():
		# Максимальный уровень достигнут
		return [1, 1]  # Полная шкала
	
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

func get_work_estimate_level() -> int:
	if has_skill("estimate_work_3"): return 3
	if has_skill("estimate_work_2"): return 2
	if has_skill("estimate_work_1"): return 1
	return 0

func get_budget_estimate_level() -> int:
	if has_skill("estimate_budget_3"): return 3
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
		1: return blur_value(real_value, 0.25)
		2: return blur_value(real_value, 0.10)
		3: return str(real_value)
	return blur_value(real_value, 0.40)

func get_blurred_budget(real_value: int) -> String:
	match get_budget_estimate_level():
		0: return blur_value(real_value, 0.35)
		1: return blur_value(real_value, 0.20)
		2: return blur_value(real_value, 0.08)
		3: return "$" + str(real_value)
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
