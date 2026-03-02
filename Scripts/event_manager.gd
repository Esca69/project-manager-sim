extends Node

# =============================================
# EventManager — синглтон для системы ивентов
# =============================================

signal event_triggered(event_data: Dictionary)
signal effect_applied(effect: Dictionary)
signal effect_expired(effect: Dictionary)

# === ГЛОБАЛЬНЫЕ НАСТРОЙКИ ===
const MIN_DAYS_BETWEEN_EVENTS: int = 2      # Минимум 2 дня между любыми ивентами
const BASE_EVENT_CHANCE: float = 0.25       # 25% шанс болезни утром (если все кулдауны прошли)
const FIRST_SAFE_DAYS: int = 7              # Первая неделя — без болезней
const MIN_EMPLOYEES_FOR_EVENTS: int = 1     # Минимум сотрудников для ивентов

# === КУЛДАУНЫ ПО ТИПАМ ИВЕНТОВ ===
const SICK_PERSONAL_COOLDOWN: int = 20      # Сотрудник не болеет чаще чем раз в 20 дней
const SICK_GLOBAL_COOLDOWN: int = 7         # Между любыми болезнями — 7 дней
const DAYOFF_PERSONAL_COOLDOWN: int = 15    # Отгул не чаще чем раз в 15 дней на сотрудника
const DAYOFF_GLOBAL_COOLDOWN: int = 5       # Между любыми отгулами — 5 дней

# === ПЕРВАЯ НЕДЕЛЯ: гарантированный отгул ===
const FIRST_WEEK_DAYOFF_DAY_MIN: int = 3    # Самый ранний день для первого отгула
const FIRST_WEEK_DAYOFF_DAY_MAX: int = 5    # Самый поздний день для первого отгула
var _first_week_dayoff_target_day: int = -1  # Рандомный день для гарантированного отгула
var _first_week_dayoff_done: bool = false    # Уже сработал?

# === ВЕСА ИВЕНТОВ ===
const EVENT_WEIGHTS = {
	"sick_leave": 40,
	"day_off": 60,
}

# === СТОИМОСТЬ ЭКСПРЕСС-ЛЕЧЕНИЯ ===
const EXPRESS_CURE_MIN: int = 300
const EXPRESS_CURE_MAX: int = 500

# === MOOD-ЭФФЕКТЫ ОТГУЛА ===
const DAYOFF_ALLOW_MOOD_VALUE: float = 6.0
const DAYOFF_ALLOW_MOOD_DURATION: float = 2880.0   # 2 суток в минутах (48ч × 60)
const DAYOFF_DENY_MOOD_VALUE: float = -10.0
const DAYOFF_DENY_MOOD_DURATION: float = 2880.0    # 2 суток в минутах (48ч × 60)

# === ПРОЕКТНЫЕ ИВЕНТЫ: НАСТРОЙКИ ===
const SCOPE_EXPANSION_CHANCE: float = 0.12       # 12% в день
const CLIENT_REVIEW_CHANCE: float = 0.25         # 25% в день
const CLIENT_REVIEW_MAX_DAYS: int = 2            # Максимум 2 дня на ожидание отзыва
const CONTRACT_CANCEL_CHANCE: float = 0.05       # 5% в день
const CONTRACT_CANCEL_MAX_PROGRESS: float = 0.4  # Прогресс < 40%
const CONTRACT_CANCEL_PAYOUT_PERCENT: float = 0.3  # 30% неустойка
const JUNIOR_MISTAKE_CHANCE: float = 0.10        # 10% в день
const JUNIOR_MAX_LEVEL: int = 2                  # Грейд Junior = уровни 0-2

# === ДАННЫЕ ===
var last_event_day: int = 0
var last_sick_day: int = -100
var last_dayoff_day: int = -100

# Персональные кулдауны: {"Имя": {"last_sick_day": N, "last_dayoff_day": N}}
var employee_cooldowns: Dictionary = {}

# Активные эффекты (баффы/дебаффы)
# [{"type": "efficiency_buff", "employee_name": "...", "value": 0.10, "days_left": 1, "emoji": "💚"}]
var active_effects: Array = []

# Ссылка на попап (устанавливается из HUD)
var _popup: Control = null

# === ФЛАГ: отгул уже сработал сегодня ===
var _dayoff_triggered_today: bool = false

# === ПРОЕКТНЫЕ ИВЕНТЫ: ДАННЫЕ ===
# Отзывы: [{client_id, client_name, project_title, budget, finished_day}]
var _pending_reviews: Array = []
# Флаги "скоуп уже расширяли" — массив title проектов
var _scope_expanded_projects: Array = []
# Флаги "ошибка джуниора уже была" — массив ключей "title::stage_index"
var _junior_mistake_stages: Array = []
# Флаг: проектный ивент уже сработал сегодня (чтобы не спамить)
var _project_event_triggered_today: bool = false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Выбираем рандомный день для гарантированного отгула на первой неделе
	_first_week_dayoff_target_day = randi_range(FIRST_WEEK_DAYOFF_DAY_MIN, FIRST_WEEK_DAYOFF_DAY_MAX)
	call_deferred("_connect_signals")

func _connect_signals():
	GameTime.day_started.connect(_on_day_started)
	GameTime.day_ended.connect(_on_day_ended)
	GameTime.time_tick.connect(_on_time_tick)
	GameTime.work_started.connect(_on_work_started)

# =============================================
# ОБРАБОТКА НОВОГО ДНЯ
# =============================================
func _on_day_started(_day_number):
	_update_sick_employees()
	# Эффекты тикаем только в рабочие дни (чтобы бафф с пятницы дожил до понедельника)
	if not GameTime.is_weekend():
		_tick_daily_effects()
	_dayoff_triggered_today = false  # Сброс флага на новый день
	_project_event_triggered_today = false  # Сброс флага проектных ивентов
	# Удаляем протухшие отзывы (старше CLIENT_REVIEW_MAX_DAYS)
	_cleanup_expired_reviews()

# =============================================
# ОБРАБОТКА КОНЦА ДНЯ
# =============================================
func _on_day_ended():
	_remove_intraday_effects()

func _on_work_started():
	# Болезнь проверяем утром (отложенно, чтобы сотрудники успели сменить стейт)
	call_deferred("_try_trigger_morning_event")
	# Проектные ивенты проверяем утром
	call_deferred("_try_trigger_project_events")

# =============================================
# ОБРАБОТКА ТИКА ВРЕМЕНИ (каждую минуту)
# =============================================
func _on_time_tick(_hour, _minute):
	if GameTime.is_game_paused or GameTime.is_night_skip:
		return
	# Отгул проверяем каждую минуту в рабочее время (10:00 — 16:00)
	if _hour >= 10 and _hour <= 16:
		_try_trigger_dayoff_event()

# =============================================
# УТРЕННИЙ ИВЕНТ (болезнь)
# =============================================
func _try_trigger_morning_event():
	# Первая неделя — без болезней (но отгул разрешён)
	if GameTime.day <= FIRST_SAFE_DAYS:
		return

	if not _can_trigger_event():
		return

	if not _can_trigger_sick():
		return

	# Бросаем кубик
	if randf() > BASE_EVENT_CHANCE:
		return

	var candidate = _pick_sick_candidate()
	if candidate == null:
		return

	_trigger_sick_event(candidate)

# =============================================
# ИВЕНТ ОТГУЛА (в течение дня)
# =============================================
func _try_trigger_dayoff_event():
	# Только 1 отгул в день
	if _dayoff_triggered_today:
		return

	# === ПЕРВАЯ НЕДЕЛЯ: гарантированный отгул в назначенный день ===
	if not _first_week_dayoff_done and GameTime.day == _first_week_dayoff_target_day:
		var candidate = _pick_dayoff_candidate()
		if candidate != null:
			_first_week_dayoff_done = true
			_dayoff_triggered_today = true
			_trigger_dayoff_event(candidate)
			return

	# === ОБЫЧНАЯ ЛОГИКА (после первой недели) ===
	if GameTime.day <= FIRST_SAFE_DAYS:
		return

	if not _can_trigger_event():
		return

	if not _can_trigger_dayoff():
		return

	# Шанс каждую минуту: ~360 минут (10:00-16:00)
	# P(хотя бы 1 за день) = 1 - (1 - 0.003)^360 ≈ 66%
	var per_minute_chance = 0.003
	if randf() > per_minute_chance:
		return

	var candidate = _pick_dayoff_candidate()
	if candidate == null:
		return

	_dayoff_triggered_today = true
	_trigger_dayoff_event(candidate)

# =============================================
# ПРОЕКТНЫЕ ИВЕНТЫ (утром)
# =============================================
func _try_trigger_project_events():
	if GameTime.day <= FIRST_SAFE_DAYS:
		return
	if GameTime.is_weekend():
		return
	if _project_event_triggered_today:
		return

	# Порядок проверки: review → scope → cancel → junior
	# Каждый день максимум 1 проектный ивент
	if _try_client_review():
		return
	if _try_scope_expansion():
		return
	if _try_contract_cancel():
		return
	if _try_junior_mistake():
		return

# =============================================
# ИВЕНТ 1: РАСШИРЕНИЕ СКОУПА
# =============================================
func _try_scope_expansion() -> bool:
	if randf() > SCOPE_EXPANSION_CHANCE:
		return false

	# Ищем подходящий проект: IN_PROGRESS, есть активный этап, ещё не расширяли
	var candidates = []
	for project in ProjectManager.active_projects:
		if project.state != ProjectData.State.IN_PROGRESS:
			continue
		if project.title in _scope_expanded_projects:
			continue
		# Проверяем наличие активного этапа
		var active_stage = _get_active_stage(project)
		if active_stage == null:
			continue
		candidates.append({"project": project, "stage": active_stage})

	if candidates.is_empty():
		return false

	var pick = candidates.pick_random()
	_trigger_scope_expansion(pick["project"], pick["stage"])
	return true

func _trigger_scope_expansion(project: ProjectData, stage: Dictionary):
	var client = project.get_client()
	var client_name = ""
	var display_title = tr(project.title)
	
	if client:
		client_name = client.get_display_name()
		display_title = client.emoji + " " + client.client_name + " — " + display_title
	else:
		client_name = tr("EVENT_UNKNOWN_CLIENT")

	# Рандом объёма: 10%, 20% или 30%
	var percent_options = [10, 20, 30]
	var extra_percent = percent_options.pick_random()

	var event_data = {
		"id": "scope_expansion",
		"project": project,
		"stage": stage,
		"client_name": client_name,
		"project_title": display_title,
		"extra_percent": extra_percent,
		"choices": [
			{
				"id": "accept",
				"label": tr("EVENT_SCOPE_CHOICE_ACCEPT"),
				"description": tr("EVENT_SCOPE_ACCEPT_DESC") % [extra_percent, extra_percent],
				"emoji": "✅",
			},
			{
				"id": "decline",
				"label": tr("EVENT_SCOPE_CHOICE_DECLINE"),
				"description": tr("EVENT_SCOPE_DECLINE_DESC"),
				"emoji": "❌",
			},
		],
	}

	_scope_expanded_projects.append(project.title)
	_project_event_triggered_today = true
	_show_event_popup(event_data)

# =============================================
# ИВЕНТ 2: ОТЗЫВ КЛИЕНТА
# =============================================
func register_finished_project(project: ProjectData):
	# Вызывается из project_manager.gd при завершении вовремя
	if not project.is_finished_on_time(GameTime.day):
		return
	var client = project.get_client()
	if client == null:
		return
	_pending_reviews.append({
		"client_id": client.client_id,
		"client_name": client.get_display_name(),
		"project_title": project.title,
		"budget": project.budget,
		"finished_day": GameTime.day,
	})
	print("⭐ Проект '%s' добавлен в очередь на отзыв" % tr(project.title))

func _cleanup_expired_reviews():
	var remaining = []
	for review in _pending_reviews:
		var days_since = GameTime.day - review["finished_day"]
		if days_since <= CLIENT_REVIEW_MAX_DAYS:
			remaining.append(review)
		else:
			print("⭐ Отзыв по '%s' протух (прошло %d дней)" % [tr(review["project_title"]), days_since])
	_pending_reviews = remaining

func _try_client_review() -> bool:
	if _pending_reviews.is_empty():
		return false

	# Не в день завершения — минимум на следующий день
	var eligible = []
	for review in _pending_reviews:
		if GameTime.day > review["finished_day"]:
			eligible.append(review)

	if eligible.is_empty():
		return false

	if randf() > CLIENT_REVIEW_CHANCE:
		return false

	var review = eligible.pick_random()
	_trigger_client_review(review)
	return true

func _trigger_client_review(review: Dictionary):
	var bonus_amount = int(review["budget"] * 0.10)
	
	# Формируем красивое название с эмодзи клиента
	var display_title = tr(review["project_title"])
	var client = ClientManager.get_client_by_id(review["client_id"])
	if client:
		display_title = client.emoji + " " + client.client_name + " — " + display_title
		
	# Делаем копию, чтобы не ломать оригинал в массиве (хотя он удаляется ниже)
	var review_for_event = review.duplicate()
	review_for_event["project_title"] = display_title

	var event_data = {
		"id": "client_review",
		"review": review_for_event,
		"bonus_amount": bonus_amount,
		"choices": [
			{
				"id": "ask_review",
				"label": tr("EVENT_REVIEW_CHOICE_REVIEW"),
				"description": tr("EVENT_REVIEW_REVIEW_DESC"),
				"emoji": "⭐",
			},
			{
				"id": "ask_bonus",
				"label": tr("EVENT_REVIEW_CHOICE_BONUS"),
				"description": tr("EVENT_REVIEW_BONUS_DESC") % bonus_amount,
				"emoji": "💰",
			},
		],
	}

	# Удаляем этот отзыв из очереди
	_pending_reviews.erase(review)
	_project_event_triggered_today = true
	_show_event_popup(event_data)

# =============================================
# ИВЕНТ 3: РАЗРЫВ КОНТРАКТА
# =============================================
func _try_contract_cancel() -> bool:
	if randf() > CONTRACT_CANCEL_CHANCE:
		return false

	var candidates = []
	for project in ProjectManager.active_projects:
		if project.state != ProjectData.State.IN_PROGRESS:
			continue
		# Не первый день проекта
		if project.start_global_time < 0.01:
			continue
		var days_active = ProjectManager.get_current_global_time() - project.start_global_time
		if days_active < 1.0:
			continue
		# Общий прогресс < 40%
		var total_progress = _get_project_total_progress(project)
		if total_progress >= CONTRACT_CANCEL_MAX_PROGRESS:
			continue
		candidates.append(project)

	if candidates.is_empty():
		return false

	var project = candidates.pick_random()
	_trigger_contract_cancel(project)
	return true

func _trigger_contract_cancel(project: ProjectData):
	var client = project.get_client()
	var client_name = ""
	var display_title = tr(project.title)
	
	if client:
		client_name = client.get_display_name()
		display_title = client.emoji + " " + client.client_name + " — " + display_title
	else:
		client_name = tr("EVENT_UNKNOWN_CLIENT")

	var payout = int(project.budget * CONTRACT_CANCEL_PAYOUT_PERCENT)

	var event_data = {
		"id": "contract_cancel",
		"project": project,
		"client_name": client_name,
		"project_title": display_title,
		"payout": payout,
		"choices": [
			{
				"id": "acknowledge",
				"label": tr("EVENT_CANCEL_CHOICE_OK"),
				"description": tr("EVENT_CANCEL_OK_DESC") % payout,
				"emoji": "📋",
			},
		],
	}

	_project_event_triggered_today = true
	_show_event_popup(event_data)

# =============================================
# ИВЕНТ 4: ОШИБКА ДЖУНИОРА
# =============================================
func _try_junior_mistake() -> bool:
	if randf() > JUNIOR_MISTAKE_CHANCE:
		return false

	var candidates = []
	for project in ProjectManager.active_projects:
		if project.state != ProjectData.State.IN_PROGRESS:
			continue
		var active_stage = _get_active_stage(project)
		if active_stage == null:
			continue
		var stage_index = _get_stage_index(project, active_stage)
		var stage_key = str(project.title) + "::" + str(stage_index)
		if stage_key in _junior_mistake_stages:
			continue
		# Ищем Junior на этом этапе
		for worker in active_stage.workers:
			if worker is EmployeeData and worker.employee_level <= JUNIOR_MAX_LEVEL:
				candidates.append({
					"project": project,
					"stage": active_stage,
					"stage_index": stage_index,
					"worker": worker,
				})
				break  # Один Junior на этап достаточно

	if candidates.is_empty():
		return false

	var pick = candidates.pick_random()
	_trigger_junior_mistake(pick)
	return true

func _trigger_junior_mistake(info: Dictionary):
	var project = info["project"]
	var stage = info["stage"]
	var stage_index = info["stage_index"]
	var worker = info["worker"]

	# Рандом доп. работы: 10-30%
	var extra_percent = randi_range(10, 30)

	var stage_type_name = tr("STAGE_" + stage.type)
	
	# Форматируем имя проекта с клиентом
	var client = project.get_client()
	var display_title = tr(project.title)
	if client:
		display_title = client.emoji + " " + client.client_name + " — " + display_title
		
	# Форматируем имя сотрудника с ролью
	var display_worker_name = worker.employee_name + " (" + tr(worker.job_title) + ")"

	var event_data = {
		"id": "junior_mistake",
		"project": project,
		"stage": stage,
		"stage_index": stage_index,
		"worker": worker,
		"worker_name": display_worker_name,
		"project_title": display_title,
		"stage_type_name": stage_type_name,
		"extra_percent": extra_percent,
		"choices": [
			{
				"id": "scold",
				"label": tr("EVENT_JUNIOR_CHOICE_SCOLD"),
				"description": tr("EVENT_JUNIOR_SCOLD_DESC") % (extra_percent / 2),
				"emoji": "😤",
			},
			{
				"id": "help",
				"label": tr("EVENT_JUNIOR_CHOICE_HELP"),
				"description": tr("EVENT_JUNIOR_HELP_DESC") % (extra_percent * 2), # Увеличиваем штраф в 2 раза для баланса
				"emoji": "🤝",
			},
		],
	}

	# Помечаем этап как "ошибка уже была"
	var stage_key = str(project.title) + "::" + str(stage_index)
	_junior_mistake_stages.append(stage_key)
	_project_event_triggered_today = true
	_show_event_popup(event_data)

# =============================================
# ПРОВЕРКИ ВОЗМОЖНОСТИ ТРИГГЕРА
# =============================================
func _can_trigger_event() -> bool:
	# Выходные — без ивентов
	if GameTime.is_weekend():
		return false

	# Кулдаун между любыми ивентами
	if GameTime.day - last_event_day < MIN_DAYS_BETWEEN_EVENTS:
		return false

	# Минимум сотрудников
	var employees = get_tree().get_nodes_in_group("npc")
	var active_count = 0
	for emp in employees:
		if emp.current_state != emp.State.HOME and emp.current_state != emp.State.SICK_LEAVE and emp.current_state != emp.State.DAY_OFF:
			active_count += 1
	if active_count < MIN_EMPLOYEES_FOR_EVENTS:
		return false

	return true

func _can_trigger_sick() -> bool:
	return GameTime.day - last_sick_day >= SICK_GLOBAL_COOLDOWN

func _can_trigger_dayoff() -> bool:
	return GameTime.day - last_dayoff_day >= DAYOFF_GLOBAL_COOLDOWN

# =============================================
# ВЫБОР КАНДИДАТА
# =============================================
func _pick_sick_candidate():
	var employees = get_tree().get_nodes_in_group("npc")
	var candidates = []

	for emp in employees:
		if not emp.data or not emp.data is EmployeeData:
			continue
		# Не болеет и не в отгуле
		if emp.current_state == emp.State.SICK_LEAVE or emp.current_state == emp.State.DAY_OFF:
			continue
		# Не ушёл домой
		if emp.current_state == emp.State.HOME or emp.current_state == emp.State.GOING_HOME:
			continue
		# Персональный кулдаун
		var name_key = emp.data.employee_name
		if employee_cooldowns.has(name_key):
			var cd = employee_cooldowns[name_key]
			if GameTime.day - cd.get("last_sick_day", -100) < SICK_PERSONAL_COOLDOWN:
				continue
		candidates.append(emp)

	if candidates.is_empty():
		return null
	return candidates.pick_random()

func _pick_dayoff_candidate():
	var employees = get_tree().get_nodes_in_group("npc")
	var candidates = []

	for emp in employees:
		if not emp.data or not emp.data is EmployeeData:
			continue
		# Только работающие / бездельничающие в офисе
		if emp.current_state != emp.State.WORKING and emp.current_state != emp.State.IDLE and emp.current_state != emp.State.WANDERING and emp.current_state != emp.State.WANDER_PAUSE:
			continue
		# Персональный кулдаун (пропускаем на первой неделе для гарантированного ивента)
		if _first_week_dayoff_done or GameTime.day != _first_week_dayoff_target_day:
			var name_key = emp.data.employee_name
			if employee_cooldowns.has(name_key):
				var cd = employee_cooldowns[name_key]
				if GameTime.day - cd.get("last_dayoff_day", -100) < DAYOFF_PERSONAL_COOLDOWN:
					continue
		candidates.append(emp)

	if candidates.is_empty():
		return null
	return candidates.pick_random()

# =============================================
# ТРИГГЕР ИВЕНТОВ (болезнь / отгул)
# =============================================
func _trigger_sick_event(employee_node):
	var emp_name_raw = employee_node.data.employee_name
	var display_name = emp_name_raw + " (" + tr(employee_node.data.job_title) + ")"
	var cure_cost = randi_range(EXPRESS_CURE_MIN, EXPRESS_CURE_MAX)
	# Округляем до 50
	cure_cost = int(round(float(cure_cost) / 50.0)) * 50
	var sick_days = randi_range(2, 3)

	var event_data = {
		"id": "sick_leave",
		"employee_node": employee_node,
		"employee_name": display_name,
		"cure_cost": cure_cost,
		"sick_days": sick_days,
		"choices": [
			{
				"id": "express_cure",
				"label": tr("EVENT_SICK_CHOICE_CURE") % cure_cost,
				"description": tr("EVENT_SICK_CURE_DESC"),
				"emoji": "💊",
			},
			{
				"id": "sick_leave",
				"label": tr("EVENT_SICK_CHOICE_LEAVE"),
				"description": tr("EVENT_SICK_LEAVE_DESC") % sick_days,
				"emoji": "🏠",
			},
		],
	}

	last_event_day = GameTime.day
	last_sick_day = GameTime.day
	_record_cooldown(emp_name_raw, "last_sick_day")

	_show_event_popup(event_data)

func _trigger_dayoff_event(employee_node):
	var emp_name_raw = employee_node.data.employee_name
	var display_name = emp_name_raw + " (" + tr(employee_node.data.job_title) + ")"

	var event_data = {
		"id": "day_off",
		"employee_node": employee_node,
		"employee_name": display_name,
		"choices": [
			{
				"id": "allow",
				"label": tr("EVENT_DAYOFF_CHOICE_ALLOW"),
				"description": tr("EVENT_DAYOFF_ALLOW_DESC"),
				"emoji": "✅",
			},
			{
				"id": "deny",
				"label": tr("EVENT_DAYOFF_CHOICE_DENY"),
				"description": tr("EVENT_DAYOFF_DENY_DESC"),
				"emoji": "❌",
			},
		],
	}

	last_event_day = GameTime.day
	last_dayoff_day = GameTime.day
	_record_cooldown(emp_name_raw, "last_dayoff_day")

	_show_event_popup(event_data)

# =============================================
# ПРИМЕНЕНИЕ ВЫБОРА
# =============================================
func apply_choice(event_data: Dictionary, choice_id: String):
	match event_data["id"]:
		"sick_leave":
			_apply_sick_choice(event_data, choice_id)
		"day_off":
			_apply_dayoff_choice(event_data, choice_id)
		"scope_expansion":
			_apply_scope_expansion(event_data, choice_id)
		"client_review":
			_apply_client_review(event_data, choice_id)
		"contract_cancel":
			_apply_contract_cancel(event_data, choice_id)
		"junior_mistake":
			_apply_junior_mistake(event_data, choice_id)

func _apply_sick_choice(event_data: Dictionary, choice_id: String):
	var emp_node = event_data["employee_node"]
	if not is_instance_valid(emp_node):
		return
		
	var emp_name_real = emp_node.data.employee_name

	match choice_id:
		"express_cure":
			# Списать деньги
			GameState.add_expense(event_data["cure_cost"])
			GameState.daily_event_expenses.append({"reason": tr("EXPENSE_CURE") % emp_name_real, "amount": event_data["cure_cost"]})
			# Болеет 1 день
			emp_node.start_sick_leave(1)
			print("🏥 %s: экспресс-лечение за $%d, вернётся завтра" % [emp_name_real, event_data["cure_cost"]])
			EventLog.add(tr("LOG_SICK_EXPRESS_CURE") % [emp_name_real, event_data["cure_cost"]], EventLog.LogType.ALERT)

		"sick_leave":
			# Болеет 2-3 дня
			emp_node.start_sick_leave(event_data["sick_days"])
			print("🤒 %s: больничный на %d дней" % [emp_name_real, event_data["sick_days"]])
			EventLog.add(tr("LOG_SICK_LEAVE") % [emp_name_real, event_data["sick_days"]], EventLog.LogType.ALERT)

func _apply_dayoff_choice(event_data: Dictionary, choice_id: String):
	var emp_node = event_data["employee_node"]
	if not is_instance_valid(emp_node):
		return
		
	var emp_name_real = emp_node.data.employee_name

	match choice_id:
		"allow":
			# Отпустить — уходит домой, завтра бафф efficiency
			emp_node.start_day_off()
			add_effect({
				"type": "efficiency_buff",
				"employee_name": emp_name_real, # Обязательно реальное имя для поиска эффекта
				"value": 0.10,
				"days_left": 2,  # Переживёт полночь, отработает полный следующий рабочий день
				"emoji": "💚",
			})
			# Mood: благодарен, +6 на 2 суток
			if emp_node.data:
				emp_node.data.add_mood_modifier(
					"dayoff_gratitude",
					"MOOD_MOD_DAYOFF_ALLOW",
					DAYOFF_ALLOW_MOOD_VALUE,
					DAYOFF_ALLOW_MOOD_DURATION
				)
			print("🏠 %s отпущен домой. Завтра +10%% эффективности, +%d mood на 2 суток" % [emp_name_real, int(DAYOFF_ALLOW_MOOD_VALUE)])
			EventLog.add(tr("LOG_DAYOFF_ALLOWED") % emp_name_real, EventLog.LogType.ROUTINE)

		"deny":
			# Не отпустить — дебафф efficiency до конца дня
			add_effect({
				"type": "efficiency_debuff",
				"employee_name": emp_name_real, # Обязательно реальное имя для поиска эффекта
				"value": -0.20,
				"days_left": 0,  # 0 = д конца текущего дня
				"emoji": "😤",
			})
			# Mood: обижен, -10 на 2 суток
			if emp_node.data:
				emp_node.data.add_mood_modifier(
					"dayoff_denied",
					"MOOD_MOD_DAYOFF_DENY",
					DAYOFF_DENY_MOOD_VALUE,
					DAYOFF_DENY_MOOD_DURATION
				)
			print("😤 %s не отпущен. -20%% эффективности сегодня, %d mood на 2 суток" % [emp_name_real, int(DAYOFF_DENY_MOOD_VALUE)])
			EventLog.add(tr("LOG_DAYOFF_DENIED") % emp_name_real, EventLog.LogType.ROUTINE)

# === ПРИМЕНЕНИЕ: РАСШИРЕНИЕ СКОУПА ===
func _apply_scope_expansion(event_data: Dictionary, choice_id: String):
	var project = event_data["project"]
	var stage = event_data["stage"]
	var extra_percent = event_data["extra_percent"]

	match choice_id:
		"accept":
			# Добавляем работу к текущему этапу
			var extra_work = stage.amount * (float(extra_percent) / 100.0)
			stage.amount += extra_work
			# Добавляем бюджет 1:1
			var extra_budget = int(project.budget * (float(extra_percent) / 100.0))
			project.budget += extra_budget
			print("📦 Скоуп расширен: +%d%% работы, +$%d бюджета для '%s'" % [extra_percent, extra_budget, tr(project.title)])
			EventLog.add(tr("LOG_SCOPE_EXPANDED") % [extra_percent, tr(project.title)], EventLog.LogType.PROGRESS)

		"decline":
			# -1 лояльность клиента
			var client = project.get_client()
			if client:
				client.add_loyalty(-1)
				print("📦 Скоуп отклонён, лояльность %s: %d (-1)" % [client.get_display_name(), client.loyalty])

# === ПРИМЕНЕНИЕ: ОТЗЫВ КЛИЕНТА ===
func _apply_client_review(event_data: Dictionary, choice_id: String):
	var review = event_data["review"]

	match choice_id:
		"ask_review":
			# +2 лояльности
			var client = ClientManager.get_client_by_id(review["client_id"])
			if client:
				client.add_loyalty(2)
				print("⭐ Отзыв от %s: лояльность %d (+2)" % [client.get_display_name(), client.loyalty])

		"ask_bonus":
			# +10% бюджета как доход
			var bonus = event_data["bonus_amount"]
			GameState.add_income(bonus)
			GameState.daily_income_details.append({"reason": tr("INCOME_CLIENT_BONUS") % review["client_name"], "amount": bonus})
			print("💰 Бонус от клиента: +$%d" % bonus)

# === ПРИМЕНЕНИЕ: РАЗРЫВ КОНТРАКТА ===
func _apply_contract_cancel(event_data: Dictionary, _choice_id: String):
	var project = event_data["project"]
	var payout = event_data["payout"]

	# Начисляем неустойку
	GameState.add_income(payout)
	GameState.daily_income_details.append({"reason": tr("INCOME_CONTRACT_CANCEL") % tr(project.title), "amount": payout})
	print("💔 Контракт расторгнут: '%s', неустойка +$%d" % [tr(project.title), payout])
	EventLog.add(tr("LOG_CONTRACT_CANCELLED") % tr(project.title), EventLog.LogType.ALERT)

	# Снимаем всех сотрудников с этапов
	for stage in project.stages:
		stage["workers"] = []
		# Не записываем в completed_worker_names — проект не завершён

	# Помечаем проект как FAILED (но не добавляем в статистику босса)
	project.state = ProjectData.State.FAILED
	# НЕ вызываем GameState.projects_failed_today.append() — не считаем как провал
	# НЕ меняем лояльность клиента

# === ПРИМЕЕНИЕ: ОШИБКА ДЖУНИОРА ===
func _apply_junior_mistake(event_data: Dictionary, choice_id: String):
	var stage = event_data["stage"]
	var worker = event_data["worker"]
	var extra_percent = event_data["extra_percent"]

	match choice_id:
		"scold":
			# Доп. работа уменьшается вдвое
			var actual_percent = extra_percent / 2
			var extra_work = stage.amount * (float(actual_percent) / 100.0)
			stage.amount += extra_work
			# -10 mood на 2 суток
			if worker is EmployeeData:
				worker.add_mood_modifier(
					"scolded",
					"MOOD_MOD_SCOLDED",
					-10.0,
					2880.0  # 2 суток
				)
			print("🤦 %s отчитан. +%d%% работы, -10 mood" % [worker.employee_name, actual_percent])

		"help":
			# Доп. работа увеличена в 2 раза из-за помощи
			var actual_percent = extra_percent * 2
			var extra_work = stage.amount * (float(actual_percent) / 100.0)
			stage.amount += extra_work
			# +5 mood на 24 часа
			if worker is EmployeeData:
				worker.add_mood_modifier(
					"helped",
					"MOOD_MOD_HELPED",
					5.0,
					1440.0  # 24 часа
				)
			# XP бонус ×1.5 за этот этап
			stage["xp_bonus_multiplier"] = 1.5
			stage["xp_bonus_employee"] = worker.employee_name
			print("🤦 %s получил помощь. +%d%% работы, +5 mood, ×1.5 XP" % [worker.employee_name, actual_percent])

# =============================================
# СИСТЕМА ЭФФЕКТОВ
# =============================================
func add_effect(effect: Dictionary):
	active_effects.append(effect)
	emit_signal("effect_applied", effect)

func get_employee_efficiency_modifier(employee_name: String) -> float:
	var modifier = 0.0
	for effect in active_effects:
		if effect["employee_name"] == employee_name:
			if effect["type"] == "efficiency_buff" or effect["type"] == "efficiency_debuff":
				modifier += effect["value"]
	return modifier

func get_employee_effect_emoji(employee_name: String) -> String:
	for effect in active_effects:
		if effect["employee_name"] == employee_name and effect.has("emoji"):
			return effect["emoji"]
	return ""

func _tick_daily_effects():
	# Вызывается утром: уменьшаем days_left, убираем истёкшие
	var remaining = []
	for effect in active_effects:
		if effect["days_left"] <= 0:
			# Интрадейные уже удалены в _on_day_ended
			continue
		effect["days_left"] -= 1
		if effect["days_left"] > 0:
			remaining.append(effect)
		else:
			# Эффект истёк
			emit_signal("effect_expired", effect)
			print("⏰ Эффект '%s' на %s истёк" % [effect["type"], effect["employee_name"]])
	active_effects = remaining

func _remove_intraday_effects():
	# Убираем эффекты с days_left == 0 (до конца дня)
	var remaining = []
	for effect in active_effects:
		if effect["days_left"] == 0:
			emit_signal("effect_expired", effect)
			print("⏰ Дневной эффект '%s' на %s снят" % [effect["type"], effect["employee_name"]])
		else:
			remaining.append(effect)
	active_effects = remaining

# =============================================
# ОБНОВЛЕНИЕ БОЛЬНЫХ СОТРУДНИКОВ
# =============================================
func _update_sick_employees():
	var employees = get_tree().get_nodes_in_group("npc")
	for emp in employees:
		if emp.current_state == emp.State.SICK_LEAVE:
			emp.tick_sick_day()
		elif emp.current_state == emp.State.DAY_OFF:
			# Отгул длится 1 день — возвращаем
			emp.end_day_off()

# =============================================
# КУЛДАУНЫ
# =============================================
func _record_cooldown(employee_name: String, field: String):
	if not employee_cooldowns.has(employee_name):
		employee_cooldowns[employee_name] = {}
	employee_cooldowns[employee_name][field] = GameTime.day

# =============================================
# УТИЛИТЫ ДЛЯ ПРОЕКТНЫХ ИВЕНТОВ
# =============================================
func _get_active_stage(project: ProjectData):
	for i in range(project.stages.size()):
		var stage = project.stages[i]
		if stage.get("is_completed", false):
			continue
		var prev_ok = true
		if i > 0:
			prev_ok = project.stages[i - 1].get("is_completed", false)
		if prev_ok:
			return stage
	return null

func _get_stage_index(project: ProjectData, target_stage: Dictionary) -> int:
	for i in range(project.stages.size()):
		if project.stages[i] == target_stage:
			return i
	return -1

func _get_project_total_progress(project: ProjectData) -> float:
	var total_amount = 0.0
	var total_progress = 0.0
	for stage in project.stages:
		total_amount += stage.amount
		total_progress += stage.progress
	if total_amount <= 0.0:
		return 0.0
	return total_progress / total_amount

# =============================================
# UI ПОПАП
# =============================================
func _show_event_popup(event_data: Dictionary):
	emit_signal("event_triggered", event_data)

	if _popup and _popup.has_method("show_event"):
		_popup.show_event(event_data)
	else:
		push_warning("EventManager: попап не найден, ивент пропущен")

func register_popup(popup_node: Control):
	_popup = popup_node

# =============================================
# СЕРИАЛИЗАЦИЯ (для SaveManager)
# =============================================
func serialize() -> Dictionary:
	# Очищаем employee_node из active_effects — нельзя сериализовать ноды
	var safe_effects = []
	for e in active_effects:
		var copy = e.duplicate()
		copy.erase("employee_node")
		safe_effects.append(copy)

	return {
		"last_event_day": last_event_day,
		"last_sick_day": last_sick_day,
		"last_dayoff_day": last_dayoff_day,
		"employee_cooldowns": employee_cooldowns.duplicate(true),
		"active_effects": safe_effects,
		"first_week_dayoff_done": _first_week_dayoff_done,
		"first_week_dayoff_target_day": _first_week_dayoff_target_day,
		# === ПРОЕКТНЫЕ ИВЕНТЫ ===
		"pending_reviews": _pending_reviews.duplicate(true),
		"scope_expanded_projects": _scope_expanded_projects.duplicate(),
		"junior_mistake_stages": _junior_mistake_stages.duplicate(),
	}

func deserialize(data: Dictionary):
	last_event_day = int(data.get("last_event_day", 0))
	last_sick_day = int(data.get("last_sick_day", -100))
	last_dayoff_day = int(data.get("last_dayoff_day", -100))

	employee_cooldowns.clear()
	var cd = data.get("employee_cooldowns", {})
	for key in cd:
		employee_cooldowns[str(key)] = cd[key]

	active_effects.clear()
	var effects = data.get("active_effects", [])
	for e in effects:
		active_effects.append(e)

	_first_week_dayoff_done = data.get("first_week_dayoff_done", false)
	_first_week_dayoff_target_day = int(data.get("first_week_dayoff_target_day", randi_range(FIRST_WEEK_DAYOFF_DAY_MIN, FIRST_WEEK_DAYOFF_DAY_MAX)))

	# === ПРОЕКТНЫЕ ИВЕНТЫ ===
	_pending_reviews.clear()
	var reviews = data.get("pending_reviews", [])
	for r in reviews:
		_pending_reviews.append(r)

	_scope_expanded_projects.clear()
	var scopes = data.get("scope_expanded_projects", [])
	for s in scopes:
		_scope_expanded_projects.append(str(s))

	_junior_mistake_stages.clear()
	var jm = data.get("junior_mistake_stages", [])
	for j in jm:
		_junior_mistake_stages.append(str(j))
