extends Resource
class_name EmployeeData

@export var employee_name: String = "Новичок"
@export var job_title: String = "Junior Developer"
@export var monthly_salary: int = 3000

var current_energy: float = 100.0

# === БОНУС МОТИВАЦИИ ОТ PM ===
var motivation_bonus: float = 0.0

# === СИСТЕМА УРОВНЕЙ ===
@export var employee_level: int = 0
@export var employee_xp: int = 0
const MAX_LEVEL = 10
const MAX_TRAITS = 4
const TRAIT_ON_LEVELUP_CHANCE = 0.25

# Названия грейдов (используем ключи для локализации)
const GRADE_NAMES = {
	0: "GRADE_JUNIOR", 1: "GRADE_JUNIOR", 2: "GRADE_JUNIOR",
	3: "GRADE_MIDDLE", 4: "GRADE_MIDDLE",
	5: "GRADE_SENIOR", 6: "GRADE_SENIOR",
	7: "GRADE_LEAD", 8: "GRADE_LEAD", 9: "GRADE_LEAD", 10: "GRADE_LEAD",
}

# Базовые навыки по уровням (без рандома)
const SKILL_TABLE = [80, 100, 120, 145, 170, 200, 225, 250, 270, 285, 300]

# Прибавка навыка при левел-��пе [min, max]
const SKILL_GAIN_PER_LEVEL = [
	[17, 23],  # 0 → 1
	[17, 23],  # 1 → 2
	[21, 29],  # 2 → 3
	[21, 29],  # 3 → 4
	[25, 35],  # 4 → 5
	[21, 29],  # 5 → 6
	[21, 29],  # 6 → 7
	[17, 23],  # 7 → 8
	[12, 18],  # 8 → 9
	[12, 18],  # 9 → 10
]

# XP для перехода на следующий уровень
const XP_PER_LEVEL = [50, 80, 120, 170, 230, 300, 400, 520, 660, 820]

# XP за завершение этапа по категории проекта [min, max]
const STAGE_XP_REWARD = {
	"micro": [15, 25],
	"simple": [30, 50],
	"easy": [50, 80],
}

# Бонус XP за проект без просрочки софт-дедлайна
const ON_TIME_XP_BONUS = 0.30

signal level_up(emp: EmployeeData, new_level: int, skill_gain: int, new_trait: String)

func get_grade_name() -> String:
	return tr(GRADE_NAMES.get(employee_level, "GRADE_JUNIOR"))

func get_xp_for_next_level() -> int:
	if employee_level >= MAX_LEVEL:
		return 0
	return XP_PER_LEVEL[employee_level]

func get_xp_progress() -> Array:
	# Возвращает [current_xp_in_level, xp_needed_for_level]
	if employee_level >= MAX_LEVEL:
		return [0, 0]
	return [employee_xp, XP_PER_LEVEL[employee_level]]

func add_employee_xp(amount: int) -> Dictionary:
	# Возвращает {"leveled_up": bool, "new_level": int, "skill_gain": int, "new_trait": String}
	var result = {"leveled_up": false, "new_level": employee_level, "skill_gain": 0, "new_trait": ""}

	if employee_level >= MAX_LEVEL:
		return result

	employee_xp += amount

	while employee_level < MAX_LEVEL and employee_xp >= XP_PER_LEVEL[employee_level]:
		employee_xp -= XP_PER_LEVEL[employee_level]
		employee_level += 1
		result["leveled_up"] = true
		result["new_level"] = employee_level

		# Прибавка навыка
		var gain_range = SKILL_GAIN_PER_LEVEL[employee_level - 1]
		var gain = randi_range(gain_range[0], gain_range[1])
		result["skill_gain"] += gain
		_apply_skill_gain(gain)

		# Шанс получить трейт
		if traits.size() < MAX_TRAITS and randf() < TRAIT_ON_LEVELUP_CHANCE:
			var new_trait = _roll_random_trait()
			if new_trait != "":
				traits.append(new_trait)
				trait_text = build_trait_text()
				result["new_trait"] = new_trait

		print("⬆️ %s повысился до ур. %d (%s)! +%d навыка" % [employee_name, employee_level, get_grade_name(), gain])

	if result["leveled_up"]:
		emit_signal("level_up", self, result["new_level"], result["skill_gain"], result["new_trait"])

	return result

func _apply_skill_gain(amount: int):
	match job_title:
		"Business Analyst":
			skill_business_analysis += amount
		"Backend Developer":
			skill_backend += amount
		"QA Engineer":
			skill_qa += amount

func _roll_random_trait() -> String:
	# 50/50 положительный или отрицательный
	var pool: Array
	if randf() < 0.5:
		pool = POSITIVE_TRAITS.duplicate()
	else:
		pool = NEGATIVE_TRAITS.duplicate()

	pool.shuffle()
	for candidate_trait in pool:
		if candidate_trait in traits:
			continue
		var has_conflict = false
		for pair in CONFLICTING_PAIRS:
			if candidate_trait == pair[0] and pair[1] in traits:
				has_conflict = true
				break
			if candidate_trait == pair[1] and pair[0] in traits:
				has_conflict = true
				break
		if not has_conflict:
			return candidate_trait

	# Попробовать другой пул если первый не дал результат
	if randf() < 0.5:
		pool = NEGATIVE_TRAITS.duplicate()
	else:
		pool = POSITIVE_TRAITS.duplicate()

	pool.shuffle()
	for candidate_trait in pool:
		if candidate_trait in traits:
			continue
		var has_conflict = false
		for pair in CONFLICTING_PAIRS:
			if candidate_trait == pair[0] and pair[1] in traits:
				has_conflict = true
				break
			if candidate_trait == pair[1] and pair[0] in traits:
				has_conflict = true
				break
		if not has_conflict:
			return candidate_trait

	return ""

func get_primary_skill_value() -> int:
	match job_title:
		"Business Analyst": return skill_business_analysis
		"Backend Developer": return skill_backend
		"QA Engineer": return skill_qa
	return 0

# --- СИСТЕМА ТРЕЙТОВ ---
@export var traits: Array[String] = []
@export var trait_text: String = ""

# Полный словарь трейтов (заменили тексты на ключи из CSV)
const TRAIT_NAMES = {
	# Положительные
	"fast_learner": "TRAIT_FAST_LEARNER",
	"energizer": "TRAIT_ENERGIZER",
	"early_bird": "TRAIT_EARLY_BIRD",
	"cheap_hire": "TRAIT_CHEAP_HIRE",
	# Отрицательные
	"toilet_lover": "TRAIT_TOILET_LOVER",
	"coffee_lover": "TRAIT_COFFEE_LOVER",
	"slowpoke": "TRAIT_SLOWPOKE",
	"expensive": "TRAIT_EXPENSIVE",
}

# Описания для тултипов (заменили тексты на ключи из CSV)
const TRAIT_DESCRIPTIONS = {
	"fast_learner": "TRAIT_DESC_FAST_LEARNER",
	"energizer": "TRAIT_DESC_ENERGIZER",
	"early_bird": "TRAIT_DESC_EARLY_BIRD",
	"cheap_hire": "TRAIT_DESC_CHEAP_HIRE",
	"toilet_lover": "TRAIT_DESC_TOILET_LOVER",
	"coffee_lover": "TRAIT_DESC_COFFEE_LOVER",
	"slowpoke": "TRAIT_DESC_SLOWPOKE",
	"expensive": "TRAIT_DESC_EXPENSIVE",
}

# Какие трейты положительные
const POSITIVE_TRAITS = ["fast_learner", "energizer", "early_bird", "cheap_hire"]
const NEGATIVE_TRAITS = ["toilet_lover", "coffee_lover", "slowpoke", "expensive"]

# Пары-антагонисты (не могут быть вместе)
const CONFLICTING_PAIRS = [
	["fast_learner", "slowpoke"],
	["cheap_hire", "expensive"],
]

func is_positive_trait(trait_id: String) -> bool:
	return trait_id in POSITIVE_TRAITS

func is_negative_trait(trait_id: String) -> bool:
	return trait_id in NEGATIVE_TRAITS

func has_trait(trait_id: String) -> bool:
	return traits.has(trait_id)

func build_trait_text() -> String:
	if traits.is_empty():
		return ""
	var parts: Array[String] = []
	for t in traits:
		if TRAIT_NAMES.has(t):
			parts.append(tr(TRAIT_NAMES[t]))
		else:
			parts.append(t)
	return ", ".join(parts)

func get_trait_description(trait_id: String) -> String:
	if TRAIT_DESCRIPTIONS.has(trait_id):
		return tr(TRAIT_DESCRIPTIONS[trait_id])
	return ""

# --- Модификатор скорости работы (учитывает fast_learner, slowpoke, мотивацию И ивент-эффекты) ---
func get_work_speed_multiplier() -> float:
	var mult = 1.0
	if has_trait("fast_learner"):
		mult += 0.2
	if has_trait("slowpoke"):
		mult -= 0.2
	# === БОНУС МОТИВАЦИИ ===
	mult += motivation_bonus
	# === EVENT SYSTEM: Баффы/дебаффы от ивентов ===
	var em = Engine.get_singleton("EventManager") if Engine.has_singleton("EventManager") else null
	if em == null:
		em = _get_event_manager()
	if em:
		mult += em.get_employee_efficiency_modifier(employee_name)
	return mult

# --- Модификатор расхода энергии (учитывает energizer) ---
func get_energy_drain_multiplier() -> float:
	if has_trait("energizer"):
		return 0.7  # На 30% медленнее
	return 1.0

var daily_salary: int:
	get:
		return monthly_salary / 30

var hourly_rate: int:
	get:
		if monthly_salary <= 0: return 1
		return monthly_salary / 160

@export var skill_backend: int = 10
@export var skill_qa: int = 5
@export var skill_business_analysis: int = 0

@export var avatar: Texture2D

# --- Эффективность: энергия + мотивация + ивент-эффекты (для отображения в ростере) ---
func get_efficiency_multiplier() -> float:
	var base: float
	if current_energy >= 70.0:
		base = 1.0
	elif current_energy >= 50.0:
		base = 0.8
	elif current_energy >= 30.0:
		base = 0.5
	else:
		base = 0.2
	
	# Добавляем бонус мотивации
	base += motivation_bonus
	# === EVENT SYSTEM: Баффы/дебаффы от ивентов ===
	var em = _get_event_manager()
	if em:
		base += em.get_employee_efficiency_modifier(employee_name)
	return base

# === EVENT SYSTEM: Безопасный доступ к EventManager из Resource ===
func _get_event_manager():
	# Resource не имеет доступа к дереву сцены, поэтому ищем через autoload
	if Engine.has_singleton("EventManager"):
		return Engine.get_singleton("EventManager")
	# Fallback: получаем через MainLoop → root
	var main_loop = Engine.get_main_loop()
	if main_loop and main_loop is SceneTree:
		return main_loop.root.get_node_or_null("/root/EventManager")
	return null
