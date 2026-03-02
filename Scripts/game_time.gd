extends Node

signal time_tick(hour, minute)
signal day_started(day_number)
signal day_ended

signal work_started
signal work_ended

signal night_skip_started
signal night_skip_finished

const MINUTES_PER_REAL_SECOND = 1.0 

const START_HOUR = 9  
const END_HOUR = 18  
const NIGHT_SKIP_END_HOUR = 8
const NIGHT_SKIP_DURATION_SECONDS = 3.0

# --- КАЛЕНДАРЬ ---
const DAYS_IN_MONTH = 30
const DAYS_IN_WEEK = 7

# Заменили хардкодные массивы на ключи из CSV
const WEEKDAY_KEYS_SHORT = [
	"WEEKDAY_SHORT_MON", "WEEKDAY_SHORT_TUE", "WEEKDAY_SHORT_WED", 
	"WEEKDAY_SHORT_THU", "WEEKDAY_SHORT_FRI", "WEEKDAY_SHORT_SAT", "WEEKDAY_SHORT_SUN"
]

const WEEKDAY_KEYS_FULL = [
	"WEEKDAY_FULL_MON", "WEEKDAY_FULL_TUE", "WEEKDAY_FULL_WED", 
	"WEEKDAY_FULL_THU", "WEEKDAY_FULL_FRI", "WEEKDAY_FULL_SAT", "WEEKDAY_FULL_SUN"
]

var day = 1
var hour = 8 
var minute = 0

var time_accumulator = 0.0 

var current_speed_scale: float = 1.0
var is_game_paused: bool = false

var is_night_skip: bool = false
var skip_target_day: int = 0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	Engine.time_scale = 1.0
	current_speed_scale = 1.0
	is_game_paused = false
	is_night_skip = false

func _process(delta):
	# Прерываем выполнение логики времени, если игра на паузе
	if is_game_paused:
		return

	time_accumulator += delta * MINUTES_PER_REAL_SECOND
	
	while time_accumulator >= 1.0:
		minute += 1
		time_accumulator -= 1.0
		
		if minute >= 60:
			minute = 0
			hour += 1
			
			if hour == START_HOUR:
				if not is_weekend():
					# --- Сброс дневной статистики при начале рабочего дня ---
					GameState.reset_daily_stats()
					_reset_employee_daily_stats()
					
					emit_signal("work_started")
					print("🔔 09:00: СТАРТ РАБОТЫ (", get_weekday_name(), ")")
				else:
					print("🔔 09:00: ВЫХОДНОЙ (", get_weekday_name(), ") — никто не работает")
				
			elif hour == END_HOUR:
				if not is_weekend():
					emit_signal("work_ended")
					print("🔔 18:00: КОНЕЦ РАБОТЫ")
			
			if hour >= 24:
				hour = 0
				day += 1
				emit_signal("day_started", day)
				# Зарплаты теперь платятся при нажатии "Завершить день" (в hud.gd)
			
			# --- ПРОВЕРКА ОКОНЧАНИЯ ПРОМОТКИ ---
			if is_night_skip:
				if day >= skip_target_day and hour >= NIGHT_SKIP_END_HOUR:
					if is_weekend():
						pass
					else:
						finish_night_skip()
		
		emit_signal("time_tick", hour, minute)

		# === 09:05: счётчик дней и проверка ухода фрилансеров ===
		if hour == 9 and minute == 5 and not is_weekend():
			_increment_days_in_company()
			if FreelancerManager:
				FreelancerManager.check_freelancer_departures()

# === СБРОС ДНЕВНОЙ СТАТИСТИКИ СОТРУДНИКОВ ===
func _reset_employee_daily_stats():
	var npcs = get_tree().get_nodes_in_group("npc")
	for npc in npcs:
		if npc.data:
			npc.data.set_meta("daily_work_minutes", 0.0)
			npc.data.set_meta("daily_progress", 0.0)

# === ИНКРЕМЕНТ ДНЕЙ В КОМПАНИИ (09:05) ===
func _increment_days_in_company():
	for npc in get_tree().get_nodes_in_group("npc"):
		if npc.data:
			npc.data.days_in_company += 1

# === ФУНКЦИИ КАЛЕНДАРЯ ===

func get_month(d: int = -1) -> int:
	if d == -1: d = day
	return ((d - 1) / DAYS_IN_MONTH) + 1

func get_day_in_month(d: int = -1) -> int:
	if d == -1: d = day
	return ((d - 1) % DAYS_IN_MONTH) + 1

func get_weekday_index(d: int = -1) -> int:
	if d == -1: d = day
	return (d - 1) % DAYS_IN_WEEK

# Возвращает переведенный короткий день недели (Пн, Вт...)
func get_weekday_name(d: int = -1) -> String:
	var idx = get_weekday_index(d)
	return tr(WEEKDAY_KEYS_SHORT[idx])

# Возвращает переведенный полный день недели (Понедельник...)
func get_weekday_name_full(d: int = -1) -> String:
	var idx = get_weekday_index(d)
	return tr(WEEKDAY_KEYS_FULL[idx])

func is_weekend(d: int = -1) -> bool:
	var idx = get_weekday_index(d)
	return idx == 5 or idx == 6

func get_date_string(d: int = -1) -> String:
	if d == -1: d = day
	var m = get_month(d)
	var dm = get_day_in_month(d)
	var wd = get_weekday_name(d)
	return tr("DATE_FORMAT") % [m, dm, wd]

func get_date_short(d: int) -> String:
	var m = get_month(d)
	var dm = get_day_in_month(d)
	return tr("DATE_FORMAT_SHORT") % [m, dm]

# === НОЧНАЯ ПРОМОТКА ===

func start_night_skip():
	if is_night_skip:
		return
	
	is_night_skip = true
	
	var target: int
	if hour < NIGHT_SKIP_END_HOUR:
		target = day
	else:
		target = day + 1
	
	while is_weekend(target):
		target += 1
	
	skip_target_day = target
	
	var minutes_until_target: int
	if target == day:
		minutes_until_target = (NIGHT_SKIP_END_HOUR - hour) * 60 - minute
	else:
		var minutes_remaining_today = ((24 - hour) * 60) - minute
		var full_days_between = target - day - 1
		var minutes_full_days = full_days_between * 24 * 60
		var minutes_target_morning = NIGHT_SKIP_END_HOUR * 60
		minutes_until_target = minutes_remaining_today + minutes_full_days + minutes_target_morning
	
	if minutes_until_target <= 0:
		minutes_until_target = 1
	
	var skip_speed = max(1.0, float(minutes_until_target) / NIGHT_SKIP_DURATION_SECONDS)
	current_speed_scale = skip_speed
	Engine.time_scale = current_speed_scale
	
	get_tree().paused = true
	
	print("🌙 Промотка до дня ", skip_target_day, " (", get_weekday_name(skip_target_day), ") 08:00")
	
	emit_signal("night_skip_started")

func finish_night_skip():
	if not is_night_skip:
		return
	
	is_night_skip = false
	current_speed_scale = 1.0
	Engine.time_scale = current_speed_scale
	
	get_tree().paused = false
	
	emit_signal("night_skip_finished")

# === УПРАВЛЕНИЕ СКОРОСТЬЮ ===

func set_speed(new_scale: float):
	if is_night_skip:
		return
	
	if new_scale == 0:
		set_paused(true)
		return
	
	set_paused(false)
	
	current_speed_scale = new_scale
	Engine.time_scale = current_speed_scale
	print("⏩ Скорость игры: x", current_speed_scale)

func set_paused(state: bool):
	if is_night_skip:
		return
	
	is_game_paused = state
	get_tree().paused = is_game_paused
	
	if is_game_paused:
		print("⏸ ИГРА НА ПАУЗЕ")

func speed_pause(): set_speed(0.0)
func speed_1x(): set_speed(1.0)
func speed_2x(): set_speed(2.0)
func speed_5x(): set_speed(5.0)
func speed_10x(): set_speed(10.0)
