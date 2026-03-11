extends Node

# === НАСТРОЙКИ ПСЕВДОРАНДОМА ===
# Шаг изменения вероятности при выпадении одного и того же пола подряд (по умолчанию 0.02 = 2%)
@export_range(0.0, 0.5) var gender_chance_step: float = 0.05

# Текущий шанс того, что следующим выпадет мужчина
var _current_male_chance: float = 0.5

# === БАЗЫ ИМЁН (РУССКИЕ - МУЖЧИНЫ) ===
var first_names_ru_m = [
	"Александр", "Дмитрий", "Максим", "Сергей", "Андрей", "Алексей", "Артём", "Илья", "Кирилл", "Михаил", 
	"Никита", "Матвей", "Роман", "Егор", "Арсений", "Иван", "Денис", "Евгений", "Даниил", "Тимофей", 
	"Владислав", "Игорь", "Владимир", "Павел", "Руслан", "Марк", "Константин", "Тимур", "Олег", "Вадим",
	"Антон", "Виктор", "Григорий", "Леонид", "Станислав"
]
var last_names_ru_m = [
	"Смирнов", "Иванов", "Кузнецов", "Соколов", "Попов", "Лебедев", "Козлов", "Новиков", "Морозов", "Петров", 
	"Волков", "Соловьёв", "Васильев", "Зайцев", "Павлов", "Семёнов", "Голубев", "Виноградов", "Богданов", "Воробьёв", 
	"Фёдоров", "Михайлов", "Беляев", "Тарасов", "Белов", "Комаров", "Орлов", "Киселёв", "Макаров", "Андреев",
	"Ильин", "Гусев", "Титов", "Кузьмин", "Николаев"
]

# === БАЗЫ ИМЁН (РУССКИЕ - ЖЕНЩИНЫ) ===
var first_names_ru_f = [
	"Анастасия", "Мария", "Дарья", "Анна", "Виктория", "Полина", "Елизавета", "Екатерина", "Ксения", "Валерия", 
	"Варвара", "Александра", "Вероника", "Арина", "Алиса", "Алина", "Милана", "Маргарита", "Диана", "Ульяна", 
	"София", "Елена", "Татьяна", "Наталья", "Ольга", "Светлана", "Надежда", "Марина", "Ирина", "Людмила",
	"Юлия", "Евгения", "Алёна", "Кристина", "Ангелина"
]
var last_names_ru_f = [
	"Смирнова", "Иванова", "Кузнецова", "Соколова", "Попова", "Лебедева", "Козлова", "Новикова", "Морозова", "Петрова", 
	"Волкова", "Соловьёва", "Васильева", "Зайцева", "Павлова", "Семёнова", "Голубева", "Виноградова", "Богданова", "Воробьёва", 
	"Фёдорова", "Михайлова", "Беляева", "Тарасова", "Белова", "Комарова", "Орлова", "Киселёва", "Макарова", "Андреева",
	"Ильина", "Гусева", "Титова", "Кузьмина", "Николаева"
]

# === БАЗЫ ИМЁН (АНГЛИЙСКИЕ - МУЖЧИНЫ) ===
var first_names_en_m = [
	"John", "Michael", "David", "Alex", "James", "Robert",
	"William", "Richard", "Joseph", "Thomas", "Charles",
	"Christopher", "Daniel", "Matthew", "Anthony",
	"Mark", "Steven", "Paul", "Andrew"
]
# === БАЗЫ ИМЁН (АНГЛИЙСКИЕ - ЖЕНЩИНЫ) ===
var first_names_en_f = [
	"Emma", "Sarah", "Laura", "Emily", "Patricia",
	"Jennifer", "Linda", "Elizabeth", "Barbara", "Susan",
	"Jessica", "Karen", "Nancy", "Lisa", "Betty",
	"Margaret", "Sandra", "Ashley", "Kimberly", "Donna"
]
var last_names_en = [
	"Smith", "Johnson", "Williams", "Brown", "Jones", "Miller", "Davis", "Garcia", "Rodriguez", "Wilson",
	"Martinez", "Anderson", "Taylor", "Thomas", "Hernandez", "Moore", "Martin", "Jackson", "Thompson", "White",
	"Lopez", "Lee", "Gonzalez", "Harris", "Clark", "Lewis", "Robinson", "Walker", "Perez", "Hall",
	"Young", "Allen", "Sanchez", "Wright", "King", "Scott", "Green", "Baker", "Adams"
]

var roles = ["Business Analyst", "Backend Developer", "QA Engineer"]

var all_traits = ["fast_learner", "energizer", "early_bird", "cheap_hire", "toilet_lover", "coffee_lover", "slowpoke", "expensive"]

# === ЗАРПЛАТЫ ПО РОЛЯМ ===
const SALARY_CONFIG = {
	"QA Engineer":        { "base": 800,  "mult": 8,  "rand": 200 },
	"Business Analyst":   { "base": 1000, "mult": 12, "rand": 200 },
	"Backend Developer":  { "base": 1200, "mult": 16, "rand": 200 },
}

# === РАСПРЕДЕЛЕНИЕ ГРЕЙДОВ ПО МЕСЯЦУ ИГРЫ (1 мес = 30 дней) ===
const GRADE_DISTRIBUTION = {
	"month_1": [   
		[0.65, 0, 2],   # Junior (65%)
		[0.35, 3, 4],   # Middle (35%)
	],
	"month_2": [   
		[0.60, 0, 2],   # Junior (60%)
		[0.35, 3, 4],   # Middle (35%)
		[0.05, 5, 6],   # Senior (5%)
	],
	"month_3": [   
		[0.50, 0, 2],   # Junior (50%)
		[0.35, 3, 4],   # Middle (35%)
		[0.10, 5, 6],   # Senior (10%)
		[0.05, 7, 8],   # Lead (5%)
	],
}

# === ГЕНЕРАЦИЯ УНИКАЛЬНОГО ИМЕНИ ===
func _get_existing_employee_names() -> Array[String]:
	var names: Array[String] = []
	var tree = get_tree()
	if tree == null:
		return names
	for npc in tree.get_nodes_in_group("npc"):
		if npc.data and npc.data is EmployeeData:
			names.append(npc.data.employee_name)
	return names

# Функция умной генерации пола (с защитой от длинных серий)
func _roll_gender() -> String:
	var gender = "male"
	var roll = randf()
	
	if roll < _current_male_chance:
		# Выпал Мужчина
		gender = "male"
		if _current_male_chance > 0.5:
			# Если до этого была серия женщин, сбрасываем шанс к 50/50
			_current_male_chance = 0.5
		# Уменьшаем шанс выпадения следующего мужчины
		_current_male_chance -= gender_chance_step
	else:
		# Выпала Женщина
		gender = "female"
		if _current_male_chance < 0.5:
			# Если до этого была серия мужчин, сбрасываем шанс к 50/50
			_current_male_chance = 0.5
		# Увеличиваем шанс на мужчину (тем самым уменьшая шанс на женщину)
		_current_male_chance += gender_chance_step
		
	# Защита от выхода за пределы 0-1 (на случай если поставите шаг в 20%)
	_current_male_chance = clamp(_current_male_chance, 0.0, 1.0)
	
	return gender

# ИСПРАВЛЕНИЕ: Функция генерации сразу двух имен (RU и EN)
func _generate_random_names(gender: String) -> Dictionary:
	var f_name_ru = ""
	var l_name_ru = ""
	var f_name_en = ""
	var l_name_en = ""
	
	if gender == "male":
		f_name_ru = first_names_ru_m.pick_random()
		l_name_ru = last_names_ru_m.pick_random()
		f_name_en = first_names_en_m.pick_random()
		l_name_en = last_names_en.pick_random()
	else:
		f_name_ru = first_names_ru_f.pick_random()
		l_name_ru = last_names_ru_f.pick_random()
		f_name_en = first_names_en_f.pick_random()
		l_name_en = last_names_en.pick_random()
		
	return {
		"ru": f_name_ru + " " + l_name_ru,
		"en": f_name_en + " " + l_name_en
	}

func _generate_unique_name_and_gender() -> Dictionary:
	var existing = _get_existing_employee_names()
	var chosen_gender = _roll_gender()
	
	for attempt in range(50):
		var new_names = _generate_random_names(chosen_gender)
		if new_names.ru not in existing:
			return {"names": new_names, "gender": chosen_gender}
	
	var fallback_names = _generate_random_names(chosen_gender)
	var counter = 2
	while (fallback_names.ru + " " + str(counter)) in existing:
		counter += 1
	fallback_names.ru = fallback_names.ru + " " + str(counter)
	fallback_names.en = fallback_names.en + " " + str(counter)
	return {"names": fallback_names, "gender": chosen_gender}

func _generate_personality(gender: String) -> Array[String]:
	var result: Array[String] = []
	
	# Категория A: Социальная батарейка (ВСЕГДА 1)
	# toxic — 20%, extrovert и introvert — по 40%
	var social_roll = randf()
	if social_roll < 0.40:
		result.append("extrovert")
	elif social_roll < 0.80:
		result.append("introvert")
	else:
		result.append("toxic")
	
	# Категория B: Интересы (60% шанс первого, 30% шанс второго)
	var available_interests = EmployeeData.PERSONALITY_INTERESTS.duplicate()
	available_interests.shuffle()
	if randf() < 0.60 and available_interests.size() > 0:
		result.append(available_interests.pop_front())
		if randf() < 0.30 and available_interests.size() > 0:
			result.append(available_interests.pop_front())
	
	# Категория C: Раздражители (15-20% шанс)
	if randf() < 0.18:
		var available_irritants = EmployeeData.PERSONALITY_IRRITANTS.duplicate()
		available_irritants.shuffle()
		for irritant in available_irritants:
			# Проверяем гендерную привязку
			if EmployeeData.IRRITANT_GENDER_LOCK.has(irritant):
				if EmployeeData.IRRITANT_GENDER_LOCK[irritant] != gender:
					continue
			result.append(irritant)
			break  # Максимум 1 раздражитель
	
	return result

func generate_random_candidate() -> EmployeeData:
	var role = roles.pick_random()
	return generate_candidate_for_role(role)

func generate_candidate_for_role(role: String) -> EmployeeData:
	var new_emp = EmployeeData.new()

	# ИСПРАВЛЕНИЕ: Уникальное имя на двух языках и роль
	var name_data = _generate_unique_name_and_gender()
	new_emp.employee_name = name_data.names.ru
	new_emp.name_ru = name_data.names.ru
	new_emp.name_en = name_data.names.en
	new_emp.gender = name_data.gender
	new_emp.job_title = role

	# 2. Определяем уровень на основе дня игры
	var level = _roll_level()
	new_emp.employee_level = level
	new_emp.employee_xp = 0

	# 3. Рассчитываем навык из уровня
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

	# 4. Зарплата ПО РОЛИ
	var cfg = SALARY_CONFIG[role]
	var raw_salary = cfg["base"] + (primary_skill_value * cfg["mult"]) + randi_range(-cfg["rand"], cfg["rand"])

	# 5. Генерация трейтов
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

	# 7. Тип занятости (50/50)
	if randf() < 0.5:
		new_emp.employment_type = "freelancer"
	else:
		new_emp.employment_type = "contractor"

	# 8. Наценка фрилансера (10%-30% к зарплате)
	if new_emp.employment_type == "freelancer":
		var freelance_mult = randf_range(1.1, 1.3)
		raw_salary = int(raw_salary * freelance_mult)

	new_emp.monthly_salary = int(round(raw_salary / 50.0)) * 50

	new_emp.current_energy = 100.0
	new_emp.trait_text = new_emp.build_trait_text()

	# Генерация personality
	new_emp.personality = _generate_personality(new_emp.gender)

	return new_emp

func _roll_level() -> int:
	var current_day = 1
	if GameTime:
		current_day = GameTime.day

	var distribution_key = "month_1"
	if current_day >= 61:
		distribution_key = "month_3"
	elif current_day >= 31:
		distribution_key = "month_2"

	var distribution = GRADE_DISTRIBUTION[distribution_key]
	var roll = randf()
	var cumulative = 0.0

	for entry in distribution:
		cumulative += entry[0]
		if roll <= cumulative:
			return randi_range(int(entry[1]), int(entry[2]))

	var last = distribution[distribution.size() - 1]
	return randi_range(int(last[1]), int(last[2]))

func _calculate_skill_for_level(level: int) -> int:
	var skill = EmployeeData.SKILL_TABLE[0]

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
