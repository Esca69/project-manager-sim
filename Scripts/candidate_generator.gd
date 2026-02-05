extends Node

var first_names = ["Олег", "Мария", "Алексей", "Дарья", "Иван", "Елена", "Макс", "Сергей", "Анна"]
var last_names = ["Петров(а)", "Смирнов(а)", "Кузнецов(а)", "Попов(а)", "Васильев(а)", "Соколов(а)", "Михайлов(а)"]
var roles = ["Business Analyst", "Backend Developer", "QA Engineer"]

func generate_random_candidate() -> EmployeeData:
	var new_emp = EmployeeData.new()
	
	# 1. Имя и Роль
	new_emp.employee_name = first_names.pick_random() + " " + last_names.pick_random()
	var role = roles.pick_random()
	new_emp.job_title = role
	
	# 2. Навыки (Сначала обнуляем всё)
	new_emp.skill_business_analysis = 0.0
	new_emp.skill_backend = 0.0
	new_emp.skill_qa = 0.0
	
	# 3. Выдаем навык (Диапазон 100 - 200)
	var primary_skill_value = randi_range(100, 200) 
	
	match role:
		"Business Analyst":
			new_emp.skill_business_analysis = primary_skill_value
		"Backend Developer":
			new_emp.skill_backend = primary_skill_value
		"QA Engineer":
			new_emp.skill_qa = primary_skill_value
	
	# 4. Считаем Зарплату (FIX)
	# Формула: База 1000 + (Скилл * 10)
	# Скилл 100 -> 1000 + 1000 = 2000
	# Скилл 200 -> 1000 + 2000 = 3000
	var raw_salary = 1000 + (primary_skill_value * 10)
	
	# Добавляем немного рандома (+/- 200 баксов)
	raw_salary += randi_range(-200, 200)
	
	# Округляем до красивых 50 (например 2450)
	new_emp.monthly_salary = round(raw_salary / 50.0) * 50
	
	# При создании даем полную энергию
	new_emp.current_energy = 100.0
	
	return new_emp
