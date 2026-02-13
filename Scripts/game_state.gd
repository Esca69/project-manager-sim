extends Node

# Стартовый капитал
var company_balance: int = 10000

# Сигнал изменения денег
signal balance_changed(new_amount)

# === ДНЕВНАЯ СТАТИСТИКА ===
var balance_at_day_start: int = 10000
var daily_income: int = 0
var daily_expenses: int = 0
var daily_salary_details: Array = []  # [{name: String, amount: int}]
var projects_finished_today: Array = []  # [{project: ProjectData, payout: int}]
var projects_failed_today: Array = []    # [ProjectData]

func reset_daily_stats():
	balance_at_day_start = company_balance
	daily_income = 0
	daily_expenses = 0
	daily_salary_details.clear()
	projects_finished_today.clear()
	projects_failed_today.clear()

# Функция изменения баланса
func change_balance(amount: int):
	company_balance += amount
	emit_signal("balance_changed", company_balance)
	print("Баланс изменен: ", amount, ". Текущий: ", company_balance)
	
	if company_balance < 0:
		print("!!! КАССОВЫЙ РАЗРЫВ !!!")

# Начисление дохода (от завершённых проектов)
func add_income(amount: int):
	daily_income += amount
	change_balance(amount)

# Списание расхода (зарплаты и т.д.)
func add_expense(amount: int):
	daily_expenses += amount
	change_balance(-amount)

# --- ФУНКЦИЯ ВЫПЛАТЫ ЗАРПЛАТ ---
func pay_daily_salaries():
	print("\n--- КОНЕЦ ДНЯ. ВЫПЛАТА ЗАРПЛАТ ---")
	var total_daily_cost = 0
	
	# 1. Ищем всех, кто находится в группе "npc"
	var employees = get_tree().get_nodes_in_group("npc")
	
	# 2. Считаем, сколько кому платить
	for worker in employees:
		if "data" in worker and worker.data is EmployeeData:
			var salary = worker.data.daily_salary
			total_daily_cost += salary
			# Запоминаем детализацию
			daily_salary_details.append({
				"name": worker.data.employee_name,
				"amount": salary
			})
			print("Сотрудник ", worker.data.employee_name, " получил: ", salary, "$")
	
	# 3. Вычитаем общую сумму через add_expense (для дневной статистики)
	if total_daily_cost > 0:
		add_expense(total_daily_cost)
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
