extends Node

# =============================================
# EventManager — синглтон для системы ивентов
# =============================================

signal event_triggered(event_data: Dictionary)
signal effect_applied(effect: Dictionary)
signal effect_expired(effect: Dictionary)

# === ГЛОБАЛЬНЫЕ НАСТРОЙКИ ===
const MIN_DAYS_BETWEEN_EVENTS: int = 0      # Минимум дней между любыми ивентами
const BASE_EVENT_CHANCE: float = 1.0        # 25% шанс ивента каждый подходящий день
const FIRST_SAFE_DAYS: int = 0  # TEST: ивенты с первого дня
const MIN_EMPLOYEES_FOR_EVENTS: int = 1     # Минимум сотрудников для ивентов

# === КУЛДАУНЫ ПО ТИПАМ ИВЕНТОВ ===
const SICK_PERSONAL_COOLDOWN: int = 20      # Сотрудник не болеет чаще чем раз в 20 дней
const SICK_GLOBAL_COOLDOWN: int = 0         # Между любыми болезнями — 7 дней
const DAYOFF_PERSONAL_COOLDOWN: int = 15    # Отгул не чаще чем раз в 15 дней
const DAYOFF_GLOBAL_COOLDOWN: int = 5       # Между любыми отгулами — 5 дней

# === ВЕСА ИВЕНТОВ ===
const EVENT_WEIGHTS = {
	"sick_leave": 40,
	"day_off": 60,
}

# === СТОИМОСТЬ ЭКСПРЕСС-ЛЕЧЕНИЯ ===
const EXPRESS_CURE_MIN: int = 300
const EXPRESS_CURE_MAX: int = 500

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

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	_tick_daily_effects()

# =============================================
# ОБРАБОТКА КОНЦА ДНЯ
# =============================================
func _on_day_ended():
	_remove_intraday_effects()

func _on_work_started():
	# Болезнь проверяем когда сотрудники уже пришли (09:00)
	_try_trigger_morning_event()
# =============================================
# ОБРАБОТКА ТИКА ВРЕМЕНИ (каждую минуту)
# =============================================
func _on_time_tick(_hour, _minute):
	if GameTime.is_game_paused or GameTime.is_night_skip:
		return
	# Отгул проверяем каждый час в рабочее время (10:00 — 16:00)
	if _minute == 0 and _hour >= 10 and _hour <= 16:
		pass  # TEST: отключён отгул, тестируем только болезнь
		#_try_trigger_dayoff_event()

# =============================================
# УТРЕННИЙ ИВЕНТ (болезнь)
# =============================================
func _try_trigger_morning_event():
	if not _can_trigger_event():
		return

	# Болезнь срабатывает только утром
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
	if not _can_trigger_event():
		return

	if not _can_trigger_dayoff():
		return

	# Шанс за каждый час = BASE_EVENT_CHANCE / 7 (7 часов проверки: 10-16)
	# Суммарно за день ~25%
	var hourly_chance = BASE_EVENT_CHANCE / 7.0
	if randf() > hourly_chance:
		return

	var candidate = _pick_dayoff_candidate()
	if candidate == null:
		return

	_trigger_dayoff_event(candidate)

# =============================================
# ПРОВЕРКИ ВОЗМОЖНОСТИ ТРИГГЕРА
# =============================================
func _can_trigger_event() -> bool:
	# Первые дни — без ивентов
	if GameTime.day <= FIRST_SAFE_DAYS:
		return false

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
		# Персональный кулдаун
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
# ТРИГГЕР ИВЕНТОВ
# =============================================
func _trigger_sick_event(employee_node):
	var emp_name = employee_node.data.employee_name
	var cure_cost = randi_range(EXPRESS_CURE_MIN, EXPRESS_CURE_MAX)
	# Округляем до 50
	cure_cost = int(round(float(cure_cost) / 50.0)) * 50
	var sick_days = randi_range(2, 3)

	var event_data = {
		"id": "sick_leave",
		"employee_node": employee_node,
		"employee_name": emp_name,
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
	_record_cooldown(emp_name, "last_sick_day")

	_show_event_popup(event_data)

func _trigger_dayoff_event(employee_node):
	var emp_name = employee_node.data.employee_name

	var event_data = {
		"id": "day_off",
		"employee_node": employee_node,
		"employee_name": emp_name,
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
	_record_cooldown(emp_name, "last_dayoff_day")

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

func _apply_sick_choice(event_data: Dictionary, choice_id: String):
	var emp_node = event_data["employee_node"]
	if not is_instance_valid(emp_node):
		return

	match choice_id:
		"express_cure":
			# Списать деньги
			GameState.add_expense(event_data["cure_cost"])
			# Болеет 1 день
			emp_node.start_sick_leave(1)
			print("🏥 %s: экспресс-лечение за $%d, вернётся завтра" % [event_data["employee_name"], event_data["cure_cost"]])

		"sick_leave":
			# Болеет 2-3 дня
			emp_node.start_sick_leave(event_data["sick_days"])
			print("🤒 %s: больничный на %d дней" % [event_data["employee_name"], event_data["sick_days"]])

func _apply_dayoff_choice(event_data: Dictionary, choice_id: String):
	var emp_node = event_data["employee_node"]
	if not is_instance_valid(emp_node):
		return

	match choice_id:
		"allow":
			# Отпустить — уходит домой, завтра бафф
			emp_node.start_day_off()
			add_effect({
				"type": "efficiency_buff",
				"employee_name": event_data["employee_name"],
				"value": 0.10,
				"days_left": 1,  # Действует 1 полный рабочий день (завтра)
				"emoji": "💚",
			})
			print("🏠 %s отпущен домой. Завтра +10%% эффективности" % event_data["employee_name"])

		"deny":
			# Не отпустить — дебафф до конца дня
			add_effect({
				"type": "efficiency_debuff",
				"employee_name": event_data["employee_name"],
				"value": -0.20,
				"days_left": 0,  # 0 = до конца текущего дня
				"emoji": "😤",
			})
			print("😤 %s не отпущен. -20%% эффективности до конца дня" % event_data["employee_name"])

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
