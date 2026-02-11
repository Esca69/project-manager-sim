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

func generate_random_candidate() -> EmployeeData:
	var new_emp = EmployeeData.new()
	
	# 1. Имя и Роль
	new_emp.employee_name = first_names.pick_random() + " " + last_names.pick_random()
	var role = roles.pick_random()
	new_emp.job_title = role
	
	# 2. Навыки
	new_emp.skill_business_analysis = 0
	new_emp.skill_backend = 0
	new_emp.skill_qa = 0
	
	var primary_skill_value = randi_range(100, 200)
	
	match role:
		"Business Analyst":
			new_emp.skill_business_analysis = primary_skill_value
		"Backend Developer":
			new_emp.skill_backend = primary_skill_value
		"QA Engineer":
			new_emp.skill_qa = primary_skill_value
	
	# 3. Зарплата ПО РОЛИ (разная для BA, DEV, QA)
	var cfg = SALARY_CONFIG[role]
	var raw_salary = cfg["base"] + (primary_skill_value * cfg["mult"]) + randi_range(-cfg["rand"], cfg["rand"])
	
	# 4. Генерация трейтов (0-3)
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
	
	# 5. Модификация зарплаты трейтами
	if new_emp.has_trait("cheap_hire"):
		raw_salary = int(raw_salary * 0.85)
	if new_emp.has_trait("expensive"):
		raw_salary = int(raw_salary * 1.20)
	
	new_emp.monthly_salary = int(round(raw_salary / 50.0)) * 50
	
	new_emp.current_energy = 100.0
	new_emp.trait_text = new_emp.build_trait_text()
	
	return new_emp

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
