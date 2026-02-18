extends Node

var first_names = ["Олег", "Мария", "Алексей", "Дарья", "Иван", "Елена", "Макс", "Сергей", "Анна"]
var last_names = ["Петров(а)", "Смирнов(а)", "Кузнецов(а)", "Попов(а)", "Васильев(а)", "Соколов(а)", "Михайлов(а)"]
var roles = ["Business Analyst", "Backend Developer", "QA Engineer"]

var all_traits = ["fast_learner", "energizer", "early_bird", "cheap_hire", "toilet_lover", "coffee_lover", "slowpoke", "expensive"]

# === ЗАРПЛАТЫ ПО РОЛЯМ ===
# Формула: base + skill × multiplier ± rand
const SALARY_CONFIG = {
	"QA Engineer":        { "base": 800,  "mult": 8,  "rand": 200 },
	"Business Analyst":   { "base": 1000, "mult": 12, "rand": 200 },
	"Backend Developer":  { "base": 1200, "mult": 16, "rand": 200 },
}

# === РАСПРЕДЕЛЕНИЕ ГРЕЙДОВ ПО ДНЮ ИГРЫ ===
# Каждый элемент: [шанс, min_level, max_level]
const GRADE_DISTRIBUTION = {
	"early": [   # Дни 1–15
		[0.60, 0, 2],   # Junior
		[0.35, 3, 4],   # Middle
		[0.05, 5, 5],   # Senior
	],
	"mid": [     # Дни 16–45
		[0.30, 0, 2],   # Junior
		[0.45, 3, 4],   # Middle
		[0.20, 5, 6],   # Senior
		[0.05, 7, 7],   # Lead
	],
	"late": [    # Дни 46+
		[0.15, 1, 2],   # Junior
		[0.35, 3, 4],   # Middle
		[0.35, 5, 7],   # Senior
		[0.15, 7, 8],   # Lead
	],
}

func generate_random_candidate() -> EmployeeData:
	var role = roles.pick_random()
	return generate_candidate_for_role(role)

# === НОВЫЙ МЕТОД: генерация кандидата конкретной роли ===
func generate_candidate_for_role(role: String) -> EmployeeData:
	var new_emp = EmployeeData.new()

	# 1. Имя и Роль
	new_emp.employee_name = first_names.pick_random() + " " + last_names.pick_random()
	new_emp.job_title = role

	# 2. Определяем уровень на основе дня игры
	var level = _roll_level()
	new_emp.employee_level = level
	new_emp.employee_xp = 0

	# 3. Рассчитываем навык из уровня (с рандомом прибавок)
	new_emp.skill_business_analysis = 0
	new_emp.skill_backend = 0
	new_emp.skill_qa = 0

	var primary_skill_value = _calculate_skill_for_level(level)

	match role:
		"Business Analyst":
			new_emp.skill_business_analysis = primary_skill_value
		"Backend Developer":
			new_emp.skill_backend = primary_skill_value
		"QA Engineer":
			new_emp.skill_qa = primary_skill_value

	# 4. Зарплата ПО РОЛИ (разная для BA, DEV, QA)
	var cfg = SALARY_CONFIG[role]
	var raw_salary = cfg["base"] + (primary_skill_value * cfg["mult"]) + randi_range(-cfg["rand"], cfg["rand"])

	# 5. Генерация трейтов (0-3)
	new_emp.traits.clear()
	var trait_count = _pick_trait_count()

	if trait_count > 0:
		var available = all_traits.duplicate()
		available.shuffle()

		for i in range(trait_count):
			if available.is_empty():
				break
			var picked = available.pop_front()
			if _has_conflict(picked, new_emp.traits):
				continue
			new_emp.traits.append(picked)

	# 6. Модификация зарплаты трейтами
	if new_emp.has_trait("cheap_hire"):
		raw_salary = int(raw_salary * 0.85)
	if new_emp.has_trait("expensive"):
		raw_salary = int(raw_salary * 1.20)

	new_emp.monthly_salary = int(round(raw_salary / 50.0)) * 50

	new_emp.current_energy = 100.0
	new_emp.trait_text = new_emp.build_trait_text()

	return new_emp

func _roll_level() -> int:
	var current_day = 1
	if GameTime:
		current_day = GameTime.day

	var distribution_key = "early"
	if current_day >= 46:
		distribution_key = "late"
	elif current_day >= 16:
		distribution_key = "mid"

	var distribution = GRADE_DISTRIBUTION[distribution_key]
	var roll = randf()
	var cumulative = 0.0

	for entry in distribution:
		cumulative += entry[0]
		if roll <= cumulative:
			return randi_range(int(entry[1]), int(entry[2]))

	# Fallback
	var last = distribution[distribution.size() - 1]
	return randi_range(int(last[1]), int(last[2]))

func _calculate_skill_for_level(level: int) -> int:
	# Начинаем с базы 0-го уровня, затем добавляем рандомные прибавки за каждый уровень
	var skill = EmployeeData.SKILL_TABLE[0]  # 80

	for i in range(level):
		var gain_range = EmployeeData.SKILL_GAIN_PER_LEVEL[i]
		skill += randi_range(gain_range[0], gain_range[1])

	return skill

func _pick_trait_count() -> int:
	var roll = randf()
	if roll < 0.30:
		return 0
	elif roll < 0.70:
		return 1
	elif roll < 0.90:
		return 2
	else:
		return 3

func _has_conflict(new_trait: String, existing: Array[String]) -> bool:
	for pair in EmployeeData.CONFLICTING_PAIRS:
		if new_trait == pair[0] and pair[1] in existing:
			return true
		if new_trait == pair[1] and pair[0] in existing:
			return true
	return false
