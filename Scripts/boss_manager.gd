extends Node

# === СИСТЕМА КВЕСТОВ БОССА ===
# BossManager — autoload-синглтон, управляет доверием босса и месячными заданиями

signal trust_changed(new_trust: int)
signal quest_started(quest_data: Dictionary)
signal quest_completed(quest_data: Dictionary, success: bool)

# === ДОВЕРИЕ БОССА ===
var boss_trust: int = 0
const MAX_TRUST: int = 100

# === ТЕКУЩИЙ КВЕСТ ===
var current_quest: Dictionary = {}  # Пустой = нет активного квеста
var quest_active: bool = false

# === МЕСЯЧНАЯ СТАТИСТИКА (сбрасывается каждый месяц) ===
var monthly_income: int = 0
var monthly_expenses: int = 0
var monthly_projects_finished: int = 0
var monthly_projects_failed: int = 0
var monthly_hires: int = 0
var monthly_employee_levelups: int = 0

# === ИСТОРИЯ КВЕСТОВ ===
var quest_history: Array = []  # [{month, objectives, completed, trust_gained}]

# === ТРЕКИНГ ТЕКУЩЕГО МЕСЯЦА ===
var _current_month: int = 1
var _quest_shown_this_month: bool = false
var _report_shown_this_month: bool = false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_connect_signals")

func _connect_signals():
	GameTime.day_started.connect(_on_day_started)
	GameState.balance_changed.connect(_on_balance_changed)
	ProjectManager.project_finished.connect(_on_project_finished)
	ProjectManager.project_failed.connect(_on_project_failed)

# === ОТСЛЕЖИВАНИЕ ДНЕЙ ===
func _on_day_started(_day_number):
	var new_month = GameTime.get_month()
	if new_month != _current_month:
		_on_month_changed(new_month)

func _on_month_changed(new_month: int):
	# Сначала проверяем результаты предыдущего квеста
	if quest_active:
		_evaluate_quest()

	_current_month = new_month
	_quest_shown_this_month = false
	_report_shown_this_month = false

	# Сброс месячной статистики
	_reset_monthly_stats()

	print("📅 Новый месяц: %d. Доверие босса: %d" % [_current_month, boss_trust])

func _reset_monthly_stats():
	monthly_income = 0
	monthly_expenses = 0
	monthly_projects_finished = 0
	monthly_projects_failed = 0
	monthly_hires = 0
	monthly_employee_levelups = 0

# === ТРЕКИНГ СОБЫТИЙ ===
func _on_balance_changed(_new_amount):
	# Пересчитываем income/expenses из GameState
	pass

func _on_project_finished(_proj: ProjectData):
	monthly_projects_finished += 1

func _on_project_failed(_proj: ProjectData):
	monthly_projects_failed += 1

func track_hire():
	monthly_hires += 1

func track_income(amount: int):
	monthly_income += amount

func track_expense(amount: int):
	monthly_expenses += amount

func track_employee_levelup():
	monthly_employee_levelups += 1

# === ГЕНЕРАЦИЯ КВЕСТА НА МЕСЯЦ ===
func generate_quest_for_month(month: int) -> Dictionary:
	var quest = {
		"month": month,
		"objectives": [],
		"is_impossible": false,
	}

	var objectives = []

	# === ОБЯЗАТЕЛЬНОЕ: ПРИБЫЛЬ ===
	# Мес.1: 1000, Мес.2: 3000, Мес.3+: 5000 + (month-3)*2000
	var profit_target: int
	var profit_trust: int
	if month == 1:
		profit_target = 1000
		profit_trust = 3
	elif month == 2:
		profit_target = 3000
		profit_trust = 3
	else:
		profit_target = 5000 + (month - 3) * 2000
		profit_trust = 4

	objectives.append({
		"id": "profit",
		"type": "profit",
		"label": tr("QUEST_PROFIT") % profit_target,
		"target": profit_target,
		"trust_reward": profit_trust,
	})

	# === ОБЯЗАТЕЛЬНОЕ: ПРОЕКТЫ ===
	# Мес.1: 10, Мес.2: 14, Мес.3+: 14 + (month-2)*2
	var projects_target: int
	var projects_trust: int
	if month == 1:
		projects_target = 10
		projects_trust = 3
	elif month == 2:
		projects_target = 14
		projects_trust = 3
	else:
		projects_target = 14 + (month - 2) * 2
		projects_trust = 3

	objectives.append({
		"id": "projects",
		"type": "projects_completed",
		"label": tr("QUEST_PROJECTS") % projects_target,
		"target": projects_target,
		"trust_reward": projects_trust,
	})

	# === СЛУЧАЙНЫЕ ЗАДАНИЯ (2 штуки) ===
	var random_pool = _get_random_objectives_pool(month)
	random_pool.shuffle()

	var picked = 0
	var used_types = []
	for obj in random_pool:
		if obj["type"] not in used_types:
			objectives.append(obj)
			used_types.append(obj["type"])
			picked += 1
			if picked >= 2:
				break

	# === 20% шанс на "невозможное" задание ===
	if randf() < 0.20:
		quest["is_impossible"] = true
		for obj in objectives:
			obj["target"] = int(obj["target"] * randf_range(1.5, 2.0))
			obj["label"] = _rebuild_label(obj)
			obj["trust_reward"] = int(obj["trust_reward"] * 1.5)

	quest["objectives"] = objectives
	return quest

func _get_random_objectives_pool(month: int) -> Array:
	var pool = []

	# Нанять сотрудников
	# Мес.1: 3, Мес.2: 5, Мес.3+: 5 + (month-2)*2
	var hire_target: int
	if month == 1:
		hire_target = 3
	elif month == 2:
		hire_target = 5
	else:
		hire_target = 5 + (month - 2) * 2
	pool.append({
		"id": "hires",
		"type": "hires",
		"label": tr("QUEST_HIRES") % hire_target,
		"target": hire_target,
		"trust_reward": 2,
	})

	# Лояльность клиентов (без изменений)
	var loyalty_target: int
	if month == 1:
		loyalty_target = 20
	elif month == 2:
		loyalty_target = 40
	else:
		loyalty_target = 50 + (month - 3) * 10
	pool.append({
		"id": "loyalty",
		"type": "total_loyalty",
		"label": tr("QUEST_LOYALTY") % loyalty_target,
		"target": loyalty_target,
		"trust_reward": 2,
	})

	# Без провалов (без изменений)
	pool.append({
		"id": "no_fails",
		"type": "no_fails",
		"label": tr("QUEST_NO_FAILS"),
		"target": 0,
		"trust_reward": 4,
	})

	# Минимум расходов
	# Мес.1: 8000, Мес.2: 10000, Мес.3+: 10000 + (month-2)*3000
	var expense_target: int
	if month == 1:
		expense_target = 8000
	elif month == 2:
		expense_target = 10000
	else:
		expense_target = 10000 + (month - 2) * 3000
	pool.append({
		"id": "low_expenses",
		"type": "max_expenses",
		"label": tr("QUEST_MAX_EXPENSES") % expense_target,
		"target": expense_target,
		"trust_reward": 2,
	})

	# PM уровень
	# Мес.1: 5, Мес.2: 8, Мес.3+: 8 + (month-2)*3
	var pm_level_target: int
	if month == 1:
		pm_level_target = 5
	elif month == 2:
		pm_level_target = 8
	else:
		pm_level_target = 8 + (month - 2) * 3
	pool.append({
		"id": "pm_level",
		"type": "pm_level",
		"label": tr("QUEST_PM_LEVEL") % pm_level_target,
		"target": pm_level_target,
		"trust_reward": 2,
	})

	# Левел-апы сотрудников
	# Мес.1: 2, Мес.2: 5, Мес.3+: 5 + (month-2)*3
	var levelup_target: int
	if month == 1:
		levelup_target = 2
	elif month == 2:
		levelup_target = 5
	else:
		levelup_target = 5 + (month - 2) * 3
	pool.append({
		"id": "employee_levelups",
		"type": "employee_levelups",
		"label": tr("QUEST_EMPLOYEE_LEVELUPS") % levelup_target,
		"target": levelup_target,
		"trust_reward": 2,
	})

	return pool

func _rebuild_label(obj: Dictionary) -> String:
	match obj["type"]:
		"profit":
			return tr("QUEST_PROFIT") % obj["target"]
		"projects_completed":
			return tr("QUEST_PROJECTS") % obj["target"]
		"hires":
			return tr("QUEST_HIRES") % obj["target"]
		"total_loyalty":
			return tr("QUEST_LOYALTY") % obj["target"]
		"no_fails":
			return tr("QUEST_NO_FAILS")
		"max_expenses":
			return tr("QUEST_MAX_EXPENSES") % obj["target"]
		"pm_level":
			return tr("QUEST_PM_LEVEL") % obj["target"]
		"employee_levelups":
			return tr("QUEST_EMPLOYEE_LEVELUPS") % obj["target"]
	return obj.get("label", "???")

# === ЗАПУСК КВЕСТА ===
func start_quest(quest: Dictionary):
	current_quest = quest
	quest_active = true
	_quest_shown_this_month = true
	emit_signal("quest_started", quest)
	if ScreenJuice:
		ScreenJuice.show_toast("📋", tr("TOAST_BOSS_QUEST_STARTED"))
	print("📋 Квест месяца %d запущен! Целей: %d" % [quest["month"], quest["objectives"].size()])

# === ОЦЕНКА КВЕСТА (конец месяца) ===
func _evaluate_quest():
	if current_quest.is_empty():
		return

	var total_trust = 0
	var results = []

	for obj in current_quest["objectives"]:
		var achieved = _check_objective(obj)
		var trust = obj["trust_reward"] if achieved else 0
		total_trust += trust
		results.append({
			"objective": obj,
			"achieved": achieved,
			"trust_gained": trust,
		})

	# Штраф если ни одна цель не выполнена
	if total_trust == 0:
		total_trust = -3

	change_trust(total_trust)

	quest_history.append({
		"month": current_quest["month"],
		"results": results,
		"total_trust": total_trust,
		"was_impossible": current_quest.get("is_impossible", false),
	})

	var old_quest = current_quest
	current_quest = {}
	quest_active = false
	_report_shown_this_month = false

	emit_signal("quest_completed", old_quest, total_trust > 0)

	print("📊 Квест месяца завершён. Доверие: %+d (итого: %d)" % [total_trust, boss_trust])

func _check_objective(obj: Dictionary) -> bool:
	match obj["type"]:
		"profit":
			var net = monthly_income - monthly_expenses
			return net >= obj["target"]
		"projects_completed":
			return monthly_projects_finished >= obj["target"]
		"hires":
			return monthly_hires >= obj["target"]
		"total_loyalty":
			return ClientManager.get_total_loyalty() >= obj["target"]
		"no_fails":
			return monthly_projects_failed == 0
		"max_expenses":
			return monthly_expenses <= obj["target"]
		"pm_level":
			return PMData.get_level() >= obj["target"]
		"employee_levelups":
			return monthly_employee_levelups >= obj["target"]
	return false

# === ТЕКУЩИЙ ПРОГРЕСС ПО ЦЕЛЯМ ===
func get_objective_progress(obj: Dictionary) -> Dictionary:
	var current = 0
	var target = obj["target"]
	var is_inverse = false  # true = "меньше лучше"

	match obj["type"]:
		"profit":
			current = monthly_income - monthly_expenses
		"projects_completed":
			current = monthly_projects_finished
		"hires":
			current = monthly_hires
		"total_loyalty":
			current = ClientManager.get_total_loyalty()
		"no_fails":
			current = monthly_projects_failed
			is_inverse = true
		"max_expenses":
			current = monthly_expenses
			is_inverse = true
		"pm_level":
			current = PMData.get_level()
		"employee_levelups":
			current = monthly_employee_levelups

	var achieved = _check_objective(obj)

	return {
		"current": current,
		"target": target,
		"achieved": achieved,
		"is_inverse": is_inverse,
	}

# === УПРАВЛЕНИЕ ДОВЕРИЕМ ===
func change_trust(amount: int):
	var old = boss_trust
	boss_trust = clampi(boss_trust + amount, -20, MAX_TRUST)
	emit_signal("trust_changed", boss_trust)
	if boss_trust != old:
		print("🤝 Доверие босса: %d → %d (%+d)" % [old, boss_trust, amount])

# === НУЖНО ЛИ ПОКАЗАТЬ КВЕСТ / ОТЧЁТ ===
func should_show_quest() -> bool:
	# Показываем квест в начале каждого месяца (день 1 месяца)
	if _quest_shown_this_month:
		return false
	return GameTime.get_day_in_month() <= 3  # Первые 3 дня месяца

func should_show_report() -> bool:
	# Показываем отчёт когда есть завершённый квест в истории для прошлого месяца
	if _report_shown_this_month:
		return false
	if quest_history.is_empty():
		return false
	var last = quest_history[quest_history.size() - 1]
	return last["month"] == _current_month - 1

func mark_quest_shown():
	_quest_shown_this_month = true

func mark_report_shown():
	_report_shown_this_month = true
	if ScreenJuice:
		ScreenJuice.show_toast("📊", tr("TOAST_BOSS_REPORT"))

# === ПОЛУЧИТЬ ТЕКСТОВОЕ ОПИСАНИЕ ДОВЕРИЯ ===
func get_trust_label() -> String:
	if boss_trust < 0:
		return tr("BOSS_TRUST_STATE_ANGRY")
	elif boss_trust < 10:
		return tr("BOSS_TRUST_STATE_NEUTRAL")
	elif boss_trust < 25:
		return tr("BOSS_TRUST_STATE_FINE")
	elif boss_trust < 50:
		return tr("BOSS_TRUST_STATE_PLEASED")
	elif boss_trust < 75:
		return tr("BOSS_TRUST_STATE_VERY_PLEASED")
	else:
		return tr("BOSS_TRUST_STATE_AMAZED")

func get_trust_color() -> Color:
	if boss_trust < 0:
		return Color(0.9, 0.2, 0.2, 1)
	elif boss_trust < 10:
		return Color(0.6, 0.6, 0.6, 1)
	elif boss_trust < 25:
		return Color(0.4, 0.7, 0.4, 1)
	elif boss_trust < 50:
		return Color(0.3, 0.7, 0.3, 1)
	else:
		return Color(0.2, 0.8, 0.2, 1)
