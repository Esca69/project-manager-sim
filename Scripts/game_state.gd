extends Node

# Стартовый капитал
var company_balance: int = 10000

# Флаг прохождения кастомизации внешности
var appearance_configured: bool = false

# Сигнал изменения денег
signal balance_changed(new_amount)

# === УЛУЧШЕНИЯ ОФИСА ===
signal office_upgrade_purchased(upgrade_id: String)

var office_upgrades: Dictionary = {
	"coffee_machine": false,
	"kitchen": false,
	"desk_count": 3,
	# Passive services
	"legal_consultant": false,
	"project_management_soft": false,
	"dev_tools": false,
	"corporate_psychologist": false,
	"corporate_dms": false,
	"hr_specialist": false,
	# One-time purchases
	"ergonomic_furniture": false,
	"corporate_library": false,
}

func is_upgrade_bought(upgrade_id: String) -> bool:
	return office_upgrades.get(upgrade_id, false)

func buy_upgrade(upgrade_id: String, cost_money: int, cost_trust: int) -> bool:
	var bm = get_node_or_null("/root/BossManager")
	if company_balance < cost_money:
		return false
	if bm and bm.boss_trust < cost_trust:
		return false
	add_expense(cost_money)
	if bm:
		bm.change_trust(-cost_trust)
	office_upgrades[upgrade_id] = true
	daily_event_expenses.append({"reason": "SUMMARY_OFFICE_UPGRADES", "amount": cost_money})
	emit_signal("office_upgrade_purchased", upgrade_id)
	return true

func buy_service(upgrade_id: String, cost_trust: int) -> bool:
	var bm = get_node_or_null("/root/BossManager")
	if bm and bm.boss_trust < cost_trust:
		return false
	if bm:
		bm.change_trust(-cost_trust)
	office_upgrades[upgrade_id] = true
	emit_signal("office_upgrade_purchased", upgrade_id)
	return true

func buy_desk() -> bool:
	if office_upgrades["desk_count"] >= 12:
		return false
	var bm = get_node_or_null("/root/BossManager")
	if company_balance < 500:
		return false
	if bm and bm.boss_trust < 2:
		return false
	add_expense(500)
	if bm:
		bm.change_trust(-2)
	office_upgrades["desk_count"] += 1
	daily_event_expenses.append({"reason": "SUMMARY_OFFICE_UPGRADES", "amount": 500})
	emit_signal("office_upgrade_purchased", "desk")
	return true

# === ДНЕВНАЯ СТАТИСТИКА ===
var balance_at_day_start: int = 10000
var daily_income: int = 0
var daily_expenses: int = 0
var daily_salary_details: Array = []  # [{name: String, amount: int}]
var daily_service_details: Array = [] # [{name: String, amount: int}]
var daily_income_details: Array = []  # [{reason: String, amount: int}]
var daily_event_expenses: Array = []  # [{reason: String, amount: int}]
var projects_finished_today: Array = []  # [{project: ProjectData, payout: int}]
var projects_failed_today: Array = []    # [ProjectData]
var tutorial_completed: bool = false

# День последнего сброса дневной статистики (защита от утечки при пропущенном reset)
var _last_reset_day: int = 0

# === ЛЕВЕЛ-АПЫ ЗА ДЕНЬ ===
var levelups_today: Array = []  # [{name, role, new_level, grade, skill_gain, new_trait}]

# === ИЗМЕНЕНИЯ РЕПУТАЦИИ ЗА ДЕНЬ ===
var reputation_changes_today: Array = []  # [{change, reason, new_total}]

func reset_daily_stats():
	_last_reset_day = GameTime.day if GameTime else 0
	balance_at_day_start = company_balance
	daily_income = 0
	daily_expenses = 0
	daily_salary_details.clear()
	daily_service_details.clear()
	projects_finished_today.clear()
	projects_failed_today.clear()
	levelups_today.clear()
	reputation_changes_today.clear()
	daily_income_details.clear()
	daily_event_expenses.clear()

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
	if ScreenJuice:
		ScreenJuice.show_income_float(amount)

# Списание расхода (зарплаты и т.д.)
func add_expense(amount: int):
	daily_expenses += amount
	change_balance(-amount)
	# === Трекинг для BossManager ===
	var bm = get_node_or_null("/root/BossManager")
	if bm:
		bm.track_expense(amount)
	if ScreenJuice:
		ScreenJuice.show_expense_float(amount)

# --- ФУНКЦИЯ ВЫПЛАТЫ ЗАРПЛАТ ---
func pay_daily_salaries():
	print("\n--- КОНЕЦ ДНЯ. ВЫПЛАТА ЗАРПЛАТ ---")
	var total_daily_cost = 0

	var employees = get_tree().get_nodes_in_group("npc")

	for worker in employees:
		if "data" in worker and worker.data is EmployeeData:
			# === UNPAID LEAVE: Не платить зарплату (ни в день отправки, ни в дни отсутствия) ===
			var is_on_unpaid_leave = worker.current_state == worker.State.UNPAID_LEAVE
			var is_pending_unpaid = ("_pending_unpaid_leave" in worker) and worker._pending_unpaid_leave
			var has_unpaid_days_left = ("unpaid_leave_days_left" in worker) and worker.unpaid_leave_days_left > 0
			if is_on_unpaid_leave or is_pending_unpaid or has_unpaid_days_left:
				continue
			var salary = worker.data.daily_salary
			total_daily_cost += salary
			# ИСПРАВЛЕНИЕ: Используем переведенное имя
			daily_salary_details.append({
				"name": worker.data.get_display_name(),
				"amount": salary
			})
			print("Сотрудник ", worker.data.get_display_name(), " получил: ", salary, "$")

	if total_daily_cost > 0:
		add_expense(total_daily_cost)
		print("Всего выплачено за день: ", total_daily_cost, "$")
	else:
		print("Некому платить зарплату. Бюджет цел.")

	# === PM SALARY ===
	var daily_pm_salary = PMData.get_daily_salary()
	add_expense(daily_pm_salary)
	PMData.change_personal_balance(daily_pm_salary)
	daily_salary_details.append({"name": tr("PM_SALARY_NAME"), "amount": daily_pm_salary})

# --- ФУНКЦИЯ ВЫПЛАТЫ ПАССИВНЫХ СЕРВИСОВ ---
func pay_daily_services():
	print("\n--- ВЫПЛАТА ПАССИВНЫХ СЕРВИСОВ ---")
	const SERVICE_COSTS = {
		"legal_consultant":        30,
		"project_management_soft": 20,
		"dev_tools":               50,
		"corporate_psychologist":  45,
		"corporate_dms":           30,
		"hr_specialist":           45,
	}
	const SERVICE_NAME_KEYS = {
		"legal_consultant":        "UPG_LEGAL_TITLE",
		"project_management_soft": "UPG_PM_SOFT_TITLE",
		"dev_tools":               "UPG_DEV_TOOLS_TITLE",
		"corporate_psychologist":  "UPG_PSYCHOLOGIST_TITLE",
		"corporate_dms":           "UPG_DMS_TITLE",
		"hr_specialist":           "UPG_HR_TITLE",
	}
	for service_id in SERVICE_COSTS:
		if office_upgrades.get(service_id, false):
			var cost = SERVICE_COSTS[service_id]
			var name_str = tr(SERVICE_NAME_KEYS[service_id])
			add_expense(cost)
			daily_service_details.append({"name": name_str, "amount": cost})
			print("Сервис ", name_str, " списал: ", cost, "$")

# --- ФУНКЦИЯ ЕЖЕДНЕВНОГО СПИСАНИЯ ПОДПИСОК РАБОЧИХ МЕСТ ---
func pay_daily_desk_subscriptions():
	var desks = get_tree().get_nodes_in_group("desk")
	var total_cost = 0
	for desk in desks:
		if desk.has_method("get_daily_subscription_cost"):
			var cost = desk.get_daily_subscription_cost()
			total_cost += cost
	if total_cost > 0:
		add_expense(total_cost)
		daily_service_details.append({"name": tr("SUMMARY_DESK_SUBSCRIPTIONS"), "amount": total_cost})
		print("Подписки столов списали: ", total_cost, "$")

# === ЗАПИСЬ ЛЕВЕЛ-АПА ===
func record_levelup(emp: EmployeeData, new_level: int, skill_gain: int, new_trait: String):
	# ИСПРАВЛЕНИЕ: Используем переведенное имя и должность
	levelups_today.append({
		"name": emp.get_display_name(),
		"role": tr(emp.job_title),
		"new_level": new_level,
		"grade": emp.get_grade_name(),
		"skill_gain": skill_gain,
		"new_trait": new_trait,
	})
	BossManager.track_employee_levelup()

# === ЗАПИСЬ ИЗМЕНЕНИЯ РЕПУТАЦИИ ===
func record_reputation_change(change: int, reason: String):
	var cm = get_node_or_null("/root/ClientManager")
	reputation_changes_today.append({
		"change": change,
		"reason": reason,
		"new_total": cm.reputation_points if cm else 0,
	})

func _ready():
	call_deferred("_connect_signals")

func _connect_signals():
	if GameTime and not GameTime.day_started.is_connected(_check_stale_data):
		GameTime.day_started.connect(_check_stale_data)
	if ProjectManager and not ProjectManager.employee_leveled_up.is_connected(record_levelup):
		ProjectManager.employee_leveled_up.connect(record_levelup)
	var cm = get_node_or_null("/root/ClientManager")
	if cm and not cm.reputation_points_changed.is_connected(_on_reputation_changed):
		cm.reputation_points_changed.connect(_on_reputation_changed)

# Аварийный сброс дневных данных, если reset_daily_stats не вызывался более 2 дней
func _check_stale_data(_day_number = 0):
	if GameTime and _last_reset_day > 0 and GameTime.day - _last_reset_day > 2:
		print("⚠️ GameState: Аварийный сброс дневных данных (пропущен reset)")
		reset_daily_stats()

func _on_reputation_changed(new_rp: int):
	pass  # Изменения репутации записываются напрямую через record_reputation_change
