extends Resource
class_name EmployeeData

@export var employee_name: String = "Новичок"
@export var job_title: String = "Junior Developer"
@export var monthly_salary: int = 3000

# === ТИП ЗАНЯТОСТИ ===
@export var employment_type: String = "contractor"  # "contractor" или "freelancer"
@export var gender: String = "male"  # "male" или "female"
var days_in_company: int = 0  # Инкрементируется каждый рабочий день

# === АДАПТАЦИЯ (ОНБОРДИНГ И ПРОЕКТЫ) ===
var onboarding_hours_left: float = 120.0
var project_adapt_hours_left: float = 0.0
var known_project_ids: Array = []

const SEVERANCE_MIN_MULTIPLIER: float = 0.5
const SEVERANCE_MAX_MULTIPLIER: float = 1.5

func get_severance_pay() -> int:
	if employment_type != "contractor":
		return 0
	var mult = randf_range(SEVERANCE_MIN_MULTIPLIER, SEVERANCE_MAX_MULTIPLIER)
	return int(monthly_salary * mult)

func get_gender_icon() -> String:
	if gender == "female":
		return "♀"
	return "♂"

var current_energy: float = 100.0

# === БОНУС МОТИВАЦИИ ОТ PM ===
var motivation_bonus: float = 0.0

# === БОНУС АУРЫ PM (I'm Watching You) ===
var aura_bonus: float = 0.0

# === RELATIONSHIP SYSTEM: Бонус/штраф от соседей по столу ===
var neighbor_mod: float = 0.0

# === СИСТЕМА ПОВЫШЕНИЯ ЗП (RAISES) ===
var is_requesting_raise: bool = false       # Активен ли запрос на повышение ЗП
var raise_requested_salary: int = 0         # Желаемая ЗП (фиксируется при триггере)
var raise_ignored_days: int = 0             # Сколько рабочих дней проигнорировали запрос
var last_raise_grade: int = -1              # Грейд, на котором последний раз был запрос (cooldown)

# === СИСТЕМА ХАНТИНГА (HUNTING) ===
var is_quitting: bool = false         # Сотрудник отрабатывает перед уходом
var quit_days_left: int = 0           # Дней до увольнения

# === СИСТЕМА ОТПУСКОВ (VACATIONS) ===
var vacation_days_until_request: int = -1   # Обратный отсчёт до запроса (-1 = не инициализирован)
var vacation_approved: bool = false          # Отпуск одобрен, ждём начала
var vacation_delay_days: int = 0            # Дней до начала отпуска (после одобрения)
var vacation_days_remaining: int = 0        # Дней отпуска осталось (3 рабочих дня)

func init_vacation_timer():
	if employment_type != "contractor":
		return
	vacation_days_until_request = randi_range(20, 25)

# === MOOD SYSTEM v2 ===
# mood вычисляется как: BASE + постоянные + временные, clamp(0..100)
# Никакого дрейфа. Полная прозрачность для игрока.
var mood: float = 55.0  # Будет пересчитан при первом recalculate_mood()

const MOOD_BASE: float = 50.0  # Базовое значение настроения

# Зоны настроения → множитель эффективности
const MOOD_ZONES = [
	{"name": "MOOD_ZONE_MISERABLE", "min": 0.0,  "max": 20.0,  "multiplier": 0.4},
	{"name": "MOOD_ZONE_SAD",       "min": 20.0, "max": 40.0,  "multiplier": 0.65},
	{"name": "MOOD_ZONE_NORMAL",    "min": 40.0, "max": 60.0,  "multiplier": 0.85},
	{"name": "MOOD_ZONE_GOOD",      "min": 60.0, "max": 80.0,  "multiplier": 1.0},
	{"name": "MOOD_ZONE_HAPPY",     "min": 80.0, "max": 100.0, "multiplier": 1.15},
]

# === ПОСТОЯННЫЕ МОДИФИКАТОРЫ MOOD ===
# Трейт → бонус к mood
const MOOD_TRAIT_MODIFIERS = {
	"energizer": 5.0,
	"optimist": 8.0,
	"pessimist": -8.0,
	# athletic и sleepyhead зависят от времени — обрабатываются отдельно в recalculate_mood()
}

# Ситуационные постоянные
const MOOD_HAS_DESK_BONUS: float = 10.0
const MOOD_NO_DESK_PENALTY: float = -5.0
const MOOD_LOW_ENERGY_PENALTY: float = -5.0        # Энергия 30-50%
const MOOD_VERY_LOW_ENERGY_PENALTY: float = -10.0  # Энергия <30%
const MOOD_MOTIVATION_BONUS: float = 5.0           # Мотивация от PM активна

# === Время-зависимые трейты: настройки ===
const ATHLETIC_MOOD_BONUS: float = 3.0
const ATHLETIC_EFFICIENCY_BONUS: float = 0.05
const ATHLETIC_ACTIVE_BEFORE_HOUR: int = 13  # Работает до 13:00

const SLEEPYHEAD_MOOD_PENALTY: float = -3.0
const SLEEPYHEAD_EFFICIENCY_PENALTY: float = -0.05
const SLEEPYHEAD_ACTIVE_FROM_HOUR: int = 14  # Работает с 14:00

# === ВРЕМЕННЫЕ МОДИФИКАТОРЫ MOOD ===
# Массив словарей: {id, name_key, value, minutes_left}
var mood_temp_modifiers: Array = []

# Флаг: назначен ли сотрудник на активный этап (обновляется извне)
var has_active_desk: bool = false

# Постоянные модификаторы эффективности от трейтов
const MOOD_TRAIT_EFFICIENCY_MODIFIERS = {
	"energizer":     0.05,
	"coffee_lover": -0.03,
	"toilet_lover": -0.03,
	"slowpoke":     -0.05,
	"fast_learner":  0.03,
	"early_bird":    0.02,
	"cheap_hire":    0.0,
	"expensive":     0.0,
	# Время-зависимые — НЕ кладём сюда, обрабатываем отдельно
	"optimist":      0.0,
	"pessimist":     0.0,
	"athletic":      0.0,
	"sleepyhead":    0.0,
}

# === Хелпер: получить текущий игровой час из Resource ===
func _get_game_hour() -> int:
	var main_loop = Engine.get_main_loop()
	if main_loop and main_loop is SceneTree:
		var gt = main_loop.root.get_node_or_null("/root/GameTime")
		if gt and "hour" in gt:
			return gt.hour
	return 12  # Дефолт — середина дня (ни athletic, ни sleepyhead не активны)

# === MOOD: Пересчёт (вызывается каждую игровую минуту) ===
func recalculate_mood():
	var result = MOOD_BASE

	# Постоянные: трейты
	for t in traits:
		if MOOD_TRAIT_MODIFIERS.has(t):
			result += MOOD_TRAIT_MODIFIERS[t]

	# Время-зависимые трейты: mood
	var current_hour = _get_game_hour()
	if "athletic" in traits and current_hour < ATHLETIC_ACTIVE_BEFORE_HOUR:
		result += ATHLETIC_MOOD_BONUS
	if "sleepyhead" in traits and current_hour >= SLEEPYHEAD_ACTIVE_FROM_HOUR:
		result += SLEEPYHEAD_MOOD_PENALTY

	# Постоянные: рабочее задание
	if has_active_desk:
		result += MOOD_HAS_DESK_BONUS
	else:
		result += MOOD_NO_DESK_PENALTY

	# Постоянные: энергия
	if current_energy < 30.0:
		result += MOOD_VERY_LOW_ENERGY_PENALTY
	elif current_energy < 50.0:
		result += MOOD_LOW_ENERGY_PENALTY

	# Постоянные: мотивация от PM
	if motivation_bonus > 0.0:
		result += MOOD_MOTIVATION_BONUS

	# Временные модификаторы
	for mod in mood_temp_modifiers:
		result += mod.value

	mood = clampf(result, 0.0, 100.0)

# === MOOD: Тик временных модификаторов (каждую игровую минуту) ===
func tick_mood_modifiers():
	# Уменьшаем таймеры
	var expired: Array = []
	for mod in mood_temp_modifiers:
		mod.minutes_left -= 1.0
		if mod.minutes_left <= 0.0:
			expired.append(mod)

	# Удаляем истёкшие
	for mod in expired:
		mood_temp_modifiers.erase(mod)

	# Пересчитываем mood
	recalculate_mood()

# === MOOD: Добавить временный модификатор ===
func add_mood_modifier(id: String, name_key: String, value: float, duration_minutes: float):
	# Если модификатор с таким id уже есть — обновляем таймер (не дублируем)
	for mod in mood_temp_modifiers:
		if mod.id == id:
			mod.minutes_left = duration_minutes
			mod.value = value
			mod.name_key = name_key
			recalculate_mood()
			return

	mood_temp_modifiers.append({
		"id": id,
		"name_key": name_key,
		"value": value,
		"minutes_left": duration_minutes,
	})
	recalculate_mood()

# === MOOD: Убрать модификатор по id ===
func remove_mood_modifier(id: String):
	var to_remove = null
	for mod in mood_temp_modifiers:
		if mod.id == id:
			to_remove = mod
			break
	if to_remove:
		mood_temp_modifiers.erase(to_remove)
		recalculate_mood()

# === MOOD: Зоны ===
func get_mood_zone() -> Dictionary:
	for zone in MOOD_ZONES:
		if mood >= zone.min and mood < zone.max:
			return zone
	return MOOD_ZONES[MOOD_ZONES.size() - 1]

func get_mood_zone_name() -> String:
	return tr(get_mood_zone().name)

func get_mood_multiplier() -> float:
	return get_mood_zone().multiplier

# === MOOD: Breakdown для тултипа (полная прозрачность) ===
func get_mood_breakdown() -> Dictionary:
	var permanent_mods: Array = []  # [{name, value}]
	var temp_mods: Array = []       # [{name, value, minutes_left}]

	# Трейты (постоянные)
	for t in traits:
		if MOOD_TRAIT_MODIFIERS.has(t) and MOOD_TRAIT_MODIFIERS[t] != 0.0:
			var trait_name_key = EmployeeData.TRAIT_NAMES.get(t, t)
			permanent_mods.append({"name": tr(trait_name_key), "value": MOOD_TRAIT_MODIFIERS[t]})

	# Время-зависимые трейты
	var current_hour = _get_game_hour()
	if "athletic" in traits:
		if current_hour < ATHLETIC_ACTIVE_BEFORE_HOUR:
			permanent_mods.append({"name": tr("MOOD_MOD_ATHLETIC_ACTIVE"), "value": ATHLETIC_MOOD_BONUS})
		else:
			permanent_mods.append({"name": tr("MOOD_MOD_ATHLETIC_INACTIVE"), "value": 0.0})
	if "sleepyhead" in traits:
		if current_hour >= SLEEPYHEAD_ACTIVE_FROM_HOUR:
			permanent_mods.append({"name": tr("MOOD_MOD_SLEEPYHEAD_ACTIVE"), "value": SLEEPYHEAD_MOOD_PENALTY})
		else:
			permanent_mods.append({"name": tr("MOOD_MOD_SLEEPYHEAD_INACTIVE"), "value": 0.0})

	# Рабочее задание
	if has_active_desk:
		permanent_mods.append({"name": tr("MOOD_MOD_HAS_DESK"), "value": MOOD_HAS_DESK_BONUS})
	else:
		permanent_mods.append({"name": tr("MOOD_MOD_NO_DESK"), "value": MOOD_NO_DESK_PENALTY})

	# Энергия
	if current_energy < 30.0:
		permanent_mods.append({"name": tr("MOOD_MOD_VERY_LOW_ENERGY"), "value": MOOD_VERY_LOW_ENERGY_PENALTY})
	elif current_energy < 50.0:
		permanent_mods.append({"name": tr("MOOD_MOD_LOW_ENERGY"), "value": MOOD_LOW_ENERGY_PENALTY})

	# Мотивация
	if motivation_bonus > 0.0:
		permanent_mods.append({"name": tr("MOOD_MOD_MOTIVATED"), "value": MOOD_MOTIVATION_BONUS})

	# Временные
	for mod in mood_temp_modifiers:
		temp_mods.append({
			"name": tr(mod.name_key),
			"value": mod.value,
			"minutes_left": mod.minutes_left,
		})

	return {
		"base": MOOD_BASE,
		"permanent_mods": permanent_mods,
		"temp_mods": temp_mods,
		"current_mood": mood,
	}

# === СИСТЕМА УРОВНЕЙ ===
@export var employee_level: int = 0
@export var employee_xp: int = 0
const MAX_LEVEL = 10
const MAX_TRAITS = 4
const TRAIT_ON_LEVELUP_CHANCE = 0.25

const GRADE_NAMES = {
	0: "GRADE_JUNIOR", 1: "GRADE_JUNIOR", 2: "GRADE_JUNIOR",
	3: "GRADE_MIDDLE", 4: "GRADE_MIDDLE",
	5: "GRADE_SENIOR", 6: "GRADE_SENIOR",
	7: "GRADE_LEAD", 8: "GRADE_LEAD", 9: "GRADE_LEAD", 10: "GRADE_LEAD",
}

const SKILL_TABLE = [80, 100, 120, 145, 170, 200, 225, 250, 270, 285, 300]

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

const XP_PER_LEVEL = [50, 80, 120, 170, 230, 300, 400, 520, 660, 820]

const STAGE_XP_REWARD = {
	"micro": [15, 25],
	"simple": [30, 50],
	"easy": [50, 80],
}

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

	# Фрилансеры не получают XP
	if employment_type == "freelancer":
		return result

	if employee_level >= MAX_LEVEL:
		return result

	employee_xp += amount

	while employee_level < MAX_LEVEL and employee_xp >= XP_PER_LEVEL[employee_level]:
		employee_xp -= XP_PER_LEVEL[employee_level]
		employee_level += 1
		result["leveled_up"] = true
		result["new_level"] = employee_level

		# === RAISES: Проверка смены грейда ===
		var old_grade = GRADE_NAMES.get(employee_level - 1, "")
		var new_grade = GRADE_NAMES.get(employee_level, "")
		if old_grade != "" and new_grade != "" and old_grade != new_grade and employment_type == "contractor":
			if last_raise_grade != employee_level:
				_trigger_raise_request()

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
@export var personality: Array[String] = []

const TRAIT_NAMES = {
	"fast_learner": "TRAIT_FAST_LEARNER",
	"energizer": "TRAIT_ENERGIZER",
	"early_bird": "TRAIT_EARLY_BIRD",
	"cheap_hire": "TRAIT_CHEAP_HIRE",
	"toilet_lover": "TRAIT_TOILET_LOVER",
	"coffee_lover": "TRAIT_COFFEE_LOVER",
	"slowpoke": "TRAIT_SLOWPOKE",
	"expensive": "TRAIT_EXPENSIVE",
	"optimist": "TRAIT_OPTIMIST",
	"pessimist": "TRAIT_PESSIMIST",
	"athletic": "TRAIT_ATHLETIC",
	"sleepyhead": "TRAIT_SLEEPYHEAD",
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
	"optimist": "TRAIT_DESC_OPTIMIST",
	"pessimist": "TRAIT_DESC_PESSIMIST",
	"athletic": "TRAIT_DESC_ATHLETIC",
	"sleepyhead": "TRAIT_DESC_SLEEPYHEAD",
}

const POSITIVE_TRAITS = ["fast_learner", "energizer", "early_bird", "cheap_hire", "optimist", "athletic"]
const NEGATIVE_TRAITS = ["toilet_lover", "coffee_lover", "slowpoke", "expensive", "pessimist", "sleepyhead"]

const CONFLICTING_PAIRS = [
	["fast_learner", "slowpoke"],
	["cheap_hire", "expensive"],
	["optimist", "pessimist"],
	["athletic", "sleepyhead"],
]

# === СИСТЕМА ХАРАКТЕРА (PERSONALITY) ===
# Категория A: Социальная батарейка (1 из списка, всегда)
const PERSONALITY_SOCIAL = ["extrovert", "introvert", "toxic"]

# Категория B: Интересы (0-2 из списка)
const PERSONALITY_INTERESTS = ["geek", "jock", "finance_bro", "parent", "informal", "furry"]

# Категория C: Раздражители (0-1 из списка)
const PERSONALITY_IRRITANTS = ["smelly", "sexist", "man_hater", "flirt"]

# Раздражители, ограниченные полом при генерации
const IRRITANT_GENDER_LOCK = {
	"sexist": "male",
	"man_hater": "female",
}

# Названия personality-тегов (ключи локализации)
const PERSONALITY_NAMES = {
	"extrovert": "PERSONALITY_EXTROVERT",
	"introvert": "PERSONALITY_INTROVERT",
	"toxic": "PERSONALITY_TOXIC",
	"geek": "PERSONALITY_GEEK",
	"jock": "PERSONALITY_JOCK",
	"finance_bro": "PERSONALITY_FINANCE_BRO",
	"parent": "PERSONALITY_PARENT",
	"informal": "PERSONALITY_INFORMAL",
	"furry": "PERSONALITY_FURRY",
	"smelly": "PERSONALITY_SMELLY",
	"sexist": "PERSONALITY_SEXIST",
	"man_hater": "PERSONALITY_MAN_HATER",
	"flirt": "PERSONALITY_FLIRT",
}

# Описания personality-тегов (ключи локализации)
const PERSONALITY_DESCRIPTIONS = {
	"extrovert": "PERSONALITY_DESC_EXTROVERT",
	"introvert": "PERSONALITY_DESC_INTROVERT",
	"toxic": "PERSONALITY_DESC_TOXIC",
	"geek": "PERSONALITY_DESC_GEEK",
	"jock": "PERSONALITY_DESC_JOCK",
	"finance_bro": "PERSONALITY_DESC_FINANCE_BRO",
	"parent": "PERSONALITY_DESC_PARENT",
	"informal": "PERSONALITY_DESC_INFORMAL",
	"furry": "PERSONALITY_DESC_FURRY",
	"smelly": "PERSONALITY_DESC_SMELLY",
	"sexist": "PERSONALITY_DESC_SEXIST",
	"man_hater": "PERSONALITY_DESC_MAN_HATER",
	"flirt": "PERSONALITY_DESC_FLIRT",
}

# Какие personality-теги считаются "негативными" (раздражители — красный цвет)
const PERSONALITY_NEGATIVE = ["toxic", "smelly", "sexist", "man_hater"]

# Какие personality-теги считаются "нейтральными" (социальная батарейка — синий цвет)
const PERSONALITY_NEUTRAL = ["extrovert", "introvert"]

# Всё остальное = позитивное (интересы — зелёный цвет)
# flirt — особый случай: оранжевый цвет

func get_personality_color(tag_id: String) -> Color:
	if tag_id in PERSONALITY_NEGATIVE:
		return Color(0.8980392, 0.22352941, 0.20784314, 1)  # Красный
	if tag_id in PERSONALITY_NEUTRAL:
		return Color(0.17254902, 0.30980393, 0.5686275, 1)  # Синий
	if tag_id == "flirt":
		return Color(0.9, 0.55, 0.2, 1)  # Оранжевый
	return Color(0.29803923, 0.6862745, 0.3137255, 1)  # Зелёный (интересы)

func get_personality_description(tag_id: String) -> String:
	if PERSONALITY_DESCRIPTIONS.has(tag_id):
		return tr(PERSONALITY_DESCRIPTIONS[tag_id])
	return ""

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

# --- Модификатор скорости работы (алиас) ---
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

# --- Хелпер: бонус эффективности от время-зависимых трейтов ---
func _get_time_based_efficiency_mod() -> float:
	var mod: float = 0.0
	var current_hour = _get_game_hour()
	if "athletic" in traits and current_hour < ATHLETIC_ACTIVE_BEFORE_HOUR:
		mod += ATHLETIC_EFFICIENCY_BONUS
	if "sleepyhead" in traits and current_hour >= SLEEPYHEAD_ACTIVE_FROM_HOUR:
		mod += SLEEPYHEAD_EFFICIENCY_PENALTY
	return mod

# --- ЭФФЕКТИВНОСТЬ: МУЛЬТИПЛИКАТИВНАЯ ФОРМУЛА ---
func get_efficiency_multiplier() -> float:
	var mood_mult = get_mood_multiplier()
	var energy_factor = _get_energy_factor()

	var trait_sum: float = 0.0
	for t in traits:
		if MOOD_TRAIT_EFFICIENCY_MODIFIERS.has(t):
			trait_sum += MOOD_TRAIT_EFFICIENCY_MODIFIERS[t]

	# Время-зависимые трейты
	trait_sum += _get_time_based_efficiency_mod()

	# === ШТРАФЫ АДАПТАЦИИ ===
	var adaptation_mod: float = 0.0
	if onboarding_hours_left > 0:
		adaptation_mod -= 0.10
	if project_adapt_hours_left > 0:
		adaptation_mod -= 0.20

	var motivation_mod = motivation_bonus

	var event_mod: float = 0.0
	var em = _get_event_manager()
	if em:
		event_mod = em.get_employee_efficiency_modifier(employee_name)

	var aura_mod = aura_bonus

	var result = mood_mult * energy_factor * (1.0 + trait_sum) * (1.0 + motivation_mod) * (1.0 + event_mod) * (1.0 + aura_mod) * (1.0 + neighbor_mod) * (1.0 + adaptation_mod)
	return result

# --- РАЗБИВКА ЭФФЕКТИВНОСТИ ---
func get_efficiency_breakdown() -> Dictionary:
	var mood_mult = get_mood_multiplier()
	var energy_factor = _get_energy_factor()

	var trait_sum: float = 0.0
	for t in traits:
		if MOOD_TRAIT_EFFICIENCY_MODIFIERS.has(t):
			trait_sum += MOOD_TRAIT_EFFICIENCY_MODIFIERS[t]

	# Время-зависимые трейты
	trait_sum += _get_time_based_efficiency_mod()

	var motivation_mod = motivation_bonus
	var aura_mod = aura_bonus

	var event_mod: float = 0.0
	var em = _get_event_manager()
	if em:
		event_mod = em.get_employee_efficiency_modifier(employee_name)

	var adaptation_mod: float = 0.0
	if onboarding_hours_left > 0:
		adaptation_mod -= 0.10
	if project_adapt_hours_left > 0:
		adaptation_mod -= 0.20

	var total = mood_mult * energy_factor * (1.0 + trait_sum) * (1.0 + motivation_mod) * (1.0 + event_mod) * (1.0 + aura_mod) * (1.0 + neighbor_mod) * (1.0 + adaptation_mod)

	return {
		"mood_zone_name": get_mood_zone_name(),
		"mood_value": mood,
		"mood_mult": mood_mult,
		"energy_value": current_energy,
		"energy_factor": energy_factor,
		"trait_sum": trait_sum,
		"motivation_mod": motivation_mod,
		"aura_mod": aura_mod,
		"event_mod": event_mod,
		"neighbor_mod": neighbor_mod,
		"onboarding_mod": -0.10 if onboarding_hours_left > 0 else 0.0,
		"project_adapt_mod": -0.20 if project_adapt_hours_left > 0 else 0.0,
		"total": total,
	}

# === EVENT SYSTEM: Безопасный доступ к EventManager из Resource ===
func _get_event_manager():
	if Engine.has_singleton("EventManager"):
		return Engine.get_singleton("EventManager")
	var main_loop = Engine.get_main_loop()
	if main_loop and main_loop is SceneTree:
		return main_loop.root.get_node_or_null("/root/EventManager")
	return null

# === RAISES: Генерация запроса на повышение ЗП ===
func _trigger_raise_request():
	if is_requesting_raise:
		return  # Уже есть активный запрос

	is_requesting_raise = true
	raise_ignored_days = 0
	last_raise_grade = employee_level

	# Случайный процент увеличения от 10% до 25%
	var percent = randf_range(0.10, 0.25)
	raise_requested_salary = int(monthly_salary * (1.0 + percent))

	# Лог — через EventLog (autoload)
	var main_loop = Engine.get_main_loop()
	if main_loop and main_loop is SceneTree:
		var el = main_loop.root.get_node_or_null("/root/EventLog")
		if el:
			el.add(el.tr("LOG_RAISE_REQUEST") % [employee_name, get_grade_name()], 2)  # 2 = LogType.ALERT

	print("💰 %s просит повышение ЗП: $%d → $%d (грейд: %s)" % [employee_name, monthly_salary, raise_requested_salary, get_grade_name()])
