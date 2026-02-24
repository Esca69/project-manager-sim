extends Resource
class_name EmployeeData

@export var employee_name: String = "Новичок"
@export var job_title: String = "Junior Developer"
@export var monthly_salary: int = 3000

var current_energy: float = 100.0

# === БОНУС МОТИВАЦИИ ОТ PM ===
var motivation_bonus: float = 0.0

# === MOOD SYSTEM v1 ===
var mood: float = 75.0  # 0..100, старт = 75 (верхняя граница "Нормально")

# Зоны настроения → множитель эффективности
const MOOD_ZONES = [
	{"name": "MOOD_ZONE_MISERABLE", "min": 0.0,  "max": 20.0,  "multiplier": 0.4},
	{"name": "MOOD_ZONE_SAD",       "min": 20.0, "max": 40.0,  "multiplier": 0.65},
	{"name": "MOOD_ZONE_NORMAL",    "min": 40.0, "max": 60.0,  "multiplier": 0.85},
	{"name": "MOOD_ZONE_GOOD",      "min": 60.0, "max": 80.0,  "multiplier": 1.0},
	{"name": "MOOD_ZONE_HAPPY",     "min": 80.0, "max": 100.0, "multiplier": 1.15},
]

# Дрейф настроения: скорость за игровую минуту
const MOOD_DRIFT_SPEED: float = 0.03  # ~1.8 за час, ~16 за рабочий день
const MOOD_BASE_TARGET: float = 50.0  # Базовая нейтральная точка

# === ПОСТОЯННЫЕ ��ОДИФИКАТОРЫ MOOD (влияют на natural target) ===
# Трейты → бонус/штраф к natural target
const MOOD_TRAIT_TARGET_MODIFIERS = {
	"energizer":     5.0,
	"fast_learner":  3.0,
	"early_bird":    2.0,
	"coffee_lover": -3.0,
	"toilet_lover": -3.0,
	"slowpoke":     -5.0,
	"cheap_hire":    0.0,
	"expensive":     0.0,
}

# Ситуационные модификаторы mood target (ключ → значение)
const MOOD_HAS_DESK_BONUS: float = 10.0       # Назначен на проект, есть рабочее место
const MOOD_NO_DESK_PENALTY: float = -5.0       # Бродит без дела

# Постоянные модификаторы эффективности от трейтов (множитель)
const MOOD_TRAIT_EFFICIENCY_MODIFIERS = {
	"energizer":     0.05,
	"coffee_lover": -0.03,
	"toilet_lover": -0.03,
	"slowpoke":     -0.05,
	"fast_learner":  0.03,
	"early_bird":    0.02,
	"cheap_hire":    0.0,
	"expensive":     0.0,
}

# Флаг: назначен ли сотрудник на активный этап (обновляется извне)
var has_active_desk: bool = false

func get_mood_zone() -> Dictionary:
	for zone in MOOD_ZONES:
		if mood >= zone.min and mood < zone.max:
			return zone
	# Если mood == 100, попадает в последнюю зону
	return MOOD_ZONES[MOOD_ZONES.size() - 1]

func get_mood_zone_name() -> String:
	return tr(get_mood_zone().name)

func get_mood_multiplier() -> float:
	return get_mood_zone().multiplier

# === NATURAL TARGET: куда дрейфует mood ===
func get_mood_natural_target() -> float:
	var target = MOOD_BASE_TARGET

	# Трейты
	for t in traits:
		if MOOD_TRAIT_TARGET_MODIFIERS.has(t):
			target += MOOD_TRAIT_TARGET_MODIFIERS[t]

	# Ситуация: есть стол / нет стола
	if has_active_desk:
		target += MOOD_HAS_DESK_BONUS
	else:
		target += MOOD_NO_DESK_PENALTY

	return clampf(target, 0.0, 100.0)

# === BREAKDOWN НАСТРОЕНИЯ (для тултипа) ===
func get_mood_breakdown() -> Dictionary:
	var modifiers: Array = []  # [{name, value}]
	var target = MOOD_BASE_TARGET

	# Трейты
	for t in traits:
		if MOOD_TRAIT_TARGET_MODIFIERS.has(t) and MOOD_TRAIT_TARGET_MODIFIERS[t] != 0.0:
			var val = MOOD_TRAIT_TARGET_MODIFIERS[t]
			var trait_name_key = EmployeeData.TRAIT_NAMES.get(t, t)
			modifiers.append({"name": tr(trait_name_key), "value": val})
			target += val

	# Стол / нет стола
	if has_active_desk:
		modifiers.append({"name": tr("MOOD_MOD_HAS_DESK"), "value": MOOD_HAS_DESK_BONUS})
		target += MOOD_HAS_DESK_BONUS
	else:
		modifiers.append({"name": tr("MOOD_MOD_NO_DESK"), "value": MOOD_NO_DESK_PENALTY})
		target += MOOD_NO_DESK_PENALTY

	target = clampf(target, 0.0, 100.0)

	return {
		"base": MOOD_BASE_TARGET,
		"modifiers": modifiers,
		"natural_target": target,
		"current_mood": mood,
	}

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

# Прибавка навыка при левел-апе [min, max]
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
	if employee_level >= MAX_LEVEL:
		return [0, 0]
	return [employee_xp, XP_PER_LEVEL[employee_level]]

func add_employee_xp(amount: int) -> Dictionary:
	var result = {"leveled_up": false, "new_level": employee_level, "skill_gain": 0, "new_trait": ""}

	if employee_level >= MAX_LEVEL:
		return result

	employee_xp += amount

	while employee_level < MAX_LEVEL and employee_xp >= XP_PER_LEVEL[employee_level]:
		employee_xp -= XP_PER_LEVEL[employee_level]
		employee_level += 1
		result["leveled_up"] = true
		result["new_level"] = employee_level

		var gain_range = SKILL_GAIN_PER_LEVEL[employee_level - 1]
		var gain = randi_range(gain_range[0], gain_range[1])
		result["skill_gain"] += gain
		_apply_skill_gain(gain)

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

const TRAIT_NAMES = {
	"fast_learner": "TRAIT_FAST_LEARNER",
	"energizer": "TRAIT_ENERGIZER",
	"early_bird": "TRAIT_EARLY_BIRD",
	"cheap_hire": "TRAIT_CHEAP_HIRE",
	"toilet_lover": "TRAIT_TOILET_LOVER",
	"coffee_lover": "TRAIT_COFFEE_LOVER",
	"slowpoke": "TRAIT_SLOWPOKE",
	"expensive": "TRAIT_EXPENSIVE",
}

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

const POSITIVE_TRAITS = ["fast_learner", "energizer", "early_bird", "cheap_hire"]
const NEGATIVE_TRAITS = ["toilet_lover", "coffee_lover", "slowpoke", "expensive"]

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

# --- ЭНЕРГИЯ: множитель от энергии (ступенчатый) ---
func _get_energy_factor() -> float:
	if current_energy >= 70.0:
		return 1.0
	elif current_energy >= 50.0:
		return 0.85
	elif current_energy >= 30.0:
		return 0.65
	else:
		return 0.4

# --- Модификатор скорости работы (МУЛЬТИПЛИКАТИВНЫЙ через mood) ---
func get_work_speed_multiplier() -> float:
	return get_efficiency_multiplier()

# --- Модификатор расхода энергии (учитывает energizer) ---
func get_energy_drain_multiplier() -> float:
	if has_trait("energizer"):
		return 0.7
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

# --- ЭФФЕКТИВНОСТЬ: МУЛЬТИПЛИКАТИВНАЯ ФОРМУЛА (Mood System v1) ---
func get_efficiency_multiplier() -> float:
	# 1. Множитель зоны настроения
	var mood_mult = get_mood_multiplier()

	# 2. Множитель энергии
	var energy_factor = _get_energy_factor()

	# 3. Сумма постоянных трейт-модификаторов эффективности
	var trait_sum: float = 0.0
	for t in traits:
		if MOOD_TRAIT_EFFICIENCY_MODIFIERS.has(t):
			trait_sum += MOOD_TRAIT_EFFICIENCY_MODIFIERS[t]

	# 4. Мотивация PM
	var motivation_mod = motivation_bonus

	# 5. Ивент-модификатор
	var event_mod: float = 0.0
	var em = _get_event_manager()
	if em:
		event_mod = em.get_employee_efficiency_modifier(employee_name)

	# Итоговая форму��а
	var result = mood_mult * energy_factor * (1.0 + trait_sum) * (1.0 + motivation_mod) * (1.0 + event_mod)
	return result

# --- РАЗБИВКА ЭФФЕКТИВНОСТИ (для тултипа в ростере) ---
func get_efficiency_breakdown() -> Dictionary:
	var mood_mult = get_mood_multiplier()
	var energy_factor = _get_energy_factor()

	var trait_sum: float = 0.0
	for t in traits:
		if MOOD_TRAIT_EFFICIENCY_MODIFIERS.has(t):
			trait_sum += MOOD_TRAIT_EFFICIENCY_MODIFIERS[t]

	var motivation_mod = motivation_bonus

	var event_mod: float = 0.0
	var em = _get_event_manager()
	if em:
		event_mod = em.get_employee_efficiency_modifier(employee_name)

	var total = mood_mult * energy_factor * (1.0 + trait_sum) * (1.0 + motivation_mod) * (1.0 + event_mod)

	return {
		"mood_zone_name": get_mood_zone_name(),
		"mood_value": mood,
		"mood_mult": mood_mult,
		"energy_value": current_energy,
		"energy_factor": energy_factor,
		"trait_sum": trait_sum,
		"motivation_mod": motivation_mod,
		"event_mod": event_mod,
		"total": total,
	}

# --- Д��ейф настроения к ДИНАМИЧЕСКОМУ natural target ---
func tick_mood_drift():
	var target = get_mood_natural_target()
	if absf(mood - target) < 0.01:
		mood = target
		return
	var direction = sign(target - mood)
	mood += direction * MOOD_DRIFT_SPEED
	# Не перепрыгиваем через цель
	if direction > 0 and mood > target:
		mood = target
	elif direction < 0 and mood < target:
		mood = target
	mood = clampf(mood, 0.0, 100.0)

# --- Изменение mood извне (кофе, ивенты, PM-действия и т.д.) ---
func change_mood(delta: float):
	mood = clampf(mood + delta, 0.0, 100.0)

# === EVENT SYSTEM: Безопасный доступ к EventManager из Resource ===
func _get_event_manager():
	if Engine.has_singleton("EventManager"):
		return Engine.get_singleton("EventManager")
	var main_loop = Engine.get_main_loop()
	if main_loop and main_loop is SceneTree:
		return main_loop.root.get_node_or_null("/root/EventManager")
	return null
