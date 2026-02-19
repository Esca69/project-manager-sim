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

# === ЛЕВЕЛ-АПЫ ЗА ДЕНЬ ===
var levelups_today: Array = []  # [{name, role, new_level, grade, skill_gain, new_trait}]

# === ИЗМЕНЕНИЯ ЛОЯЛЬНОСТИ ЗА ДЕНЬ ===
var loyalty_changes_today: Array = []  # [{client_name, emoji, change, new_loyalty, reason}]

func reset_daily_stats():
	balance_at_day_start = company_balance
	daily_income = 0
	daily_expenses = 0
	daily_salary_details.clear()
	projects_finished_today.clear()
	projects_failed_today.clear()
	levelups_today.clear()
	loyalty_changes_today.clear()

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
	# === Трекинг для BossManager ===
	var bm = get_node_or_null("/root/BossManager")
	if bm:
		bm.track_income(amount)

# Списание расхода (зарплаты и т.д.)
func add_expense(amount: int):
	daily_expenses += amount
	change_balance(-amount)
	# === Трекинг для BossManager ===
	var bm = get_node_or_null("/root/BossManager")
	if bm:
		bm.track_expense(amount)

# --- ФУНКЦИЯ ВЫПЛАТЫ ЗАРПЛАТ ---
func pay_daily_salaries():
	print("\n--- КОНЕЦ ДНЯ. ВЫПЛАТА ЗАРПЛАТ ---")
	var total_daily_cost = 0

	var employees = get_tree().get_nodes_in_group("npc")

	for worker in employees:
		if "data" in worker and worker.data is EmployeeData:
			var salary = worker.data.daily_salary
			total_daily_cost += salary
			daily_salary_details.append({
				"name": worker.data.employee_name,
				"amount": salary
			})
			print("Сотрудник ", worker.data.employee_name, " получил: ", salary, "$")

	if total_daily_cost > 0:
		add_expense(total_daily_cost)
		print("Всего выплачено за день: ", total_daily_cost, "$")
	else:
		print("Некому платить зарплату. Бюджет цел.")

# === ЗАПИСЬ ЛЕВЕЛ-АПА ===
func record_levelup(emp: EmployeeData, new_level: int, skill_gain: int, new_trait: String):
	levelups_today.append({
		"name": emp.employee_name,
		"role": emp.job_title,
		"new_level": new_level,
		"grade": emp.get_grade_name(),
		"skill_gain": skill_gain,
		"new_trait": new_trait,
	})
	BossManager.track_employee_levelup()

# === ЗАПИСЬ ИЗМЕНЕНИЯ ЛОЯЛЬНОСТИ ===
func record_loyalty_change(client, change: int, reason: String):
	loyalty_changes_today.append({
		"client_name": client.client_name,
		"emoji": client.emoji,
		"change": change,
		"new_loyalty": client.loyalty,
		"reason": reason,
	})

func _ready():
	call_deferred("_connect_signals")

func _connect_signals():
	if ProjectManager and not ProjectManager.employee_leveled_up.is_connected(record_levelup):
		ProjectManager.employee_leveled_up.connect(record_levelup)
	# ClientManager загружается ПОСЛЕ GameState в autoload,
	# поэтому обращаемся через get_node, а не напрямую по имени
	var cm = get_node_or_null("/root/ClientManager")
	if cm and not cm.client_loyalty_changed.is_connected(_on_loyalty_changed):
		cm.client_loyalty_changed.connect(_on_loyalty_changed)

func _on_loyalty_changed(client, old_value: int, new_value: int):
	var change = new_value - old_value
	var reason = ""
	if change > 0:
		if change >= 3:  # ClientData.LOYALTY_ON_TIME
			reason = tr("REASON_PROJECT_ON_TIME")
		else:
			reason = tr("REASON_PROJECT_LATE")
	elif change < 0:
		reason = tr("REASON_PROJECT_FAILED")
	record_loyalty_change(client, change, reason)
