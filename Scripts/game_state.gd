extends Node

# Стартовый капитал
var company_balance: int = 10000

# Сигнал изменения денег
signal balance_changed(new_amount)

# Функция изменения баланса
func change_balance(amount: int):
	company_balance += amount
	emit_signal("balance_changed", company_balance)
	print("Баланс изменен: ", amount, ". Текущий: ", company_balance)
	
	if company_balance < 0:
		print("!!! КАССОВЫЙ РАЗРЫВ !!!")

# --- НОВОЕ: ФУНКЦИЯ ВЫПЛАТЫ ЗАРПЛАТ ---
func pay_daily_salaries():
	print("\n--- КОНЕЦ ДНЯ. ВЫПЛАТА ЗАРПЛАТ ---")
	var total_daily_cost = 0
	
	# 1. Ищем всех, кто находится в группе "npc"
	var employees = get_tree().get_nodes_in_group("npc")
	
	# 2. Считаем, сколько кому платить
	for worker in employees:
		# Проверяем, есть ли у этого объекта данные сотрудника
		if "data" in worker and worker.data is EmployeeData:
			var salary = worker.data.daily_salary
			total_daily_cost += salary
			print("Сотрудник ", worker.data.employee_name, " получил: ", salary, "$")
	
	# 3. Вычитаем общую сумму
	if total_daily_cost > 0:
		change_balance(-total_daily_cost)
		print("Всего выплачено за день: ", total_daily_cost, "$")
	else:
		print("Некому платить зарплату. Бюджет цел.")
func _ready():
	# --- ВРЕМЕННЫЙ ТЕСТ ГЕНЕРАТОРА ---
	var generator = load("res://Scripts/candidate_generator.gd").new()
	var test_human = generator.generate_random_candidate()
	
	print("--- ТЕСТ ГЕНЕРАТОРА ---")
	print("Имя: ", test_human.employee_name)
	print("Роль: ", test_human.job_title)
	print("Зарплата: ", test_human.monthly_salary)
	print("-----------------------")
