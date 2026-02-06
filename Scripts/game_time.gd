extends Node

# Глобальные сигналы (на них подпишутся все: UI, сотрудники, календарь)
signal time_tick(hour, minute)
signal day_started(day_number)
signal day_ended # Можно использовать для сна игрока

# --- СИГНАЛЫ ДЛЯ AI ---
signal work_started # Сработает в 09:00
signal work_ended   # Сработает в 18:00

# --- СИГНАЛЫ ДЛЯ НОЧНОЙ ПРОМОТКИ ---
signal night_skip_started
signal night_skip_finished

# Настройки времени
# При Engine.time_scale = 1.0, одна игровая минута пройдет за 1 реальную секунду (если тут стоит 1.0)
const MINUTES_PER_REAL_SECOND = 1.0 

const START_HOUR = 9  
const END_HOUR = 18  
const NIGHT_SKIP_END_HOUR = 8
const NIGHT_SKIP_DURATION_SECONDS = 3.0

# Текущее состояние
var day = 1
var hour = 8 
var minute = 0

var time_accumulator = 0.0 

# --- [НОВОЕ] ПЕРЕМЕННЫЕ СКОРОСТИ ---
var current_speed_scale: float = 1.0
var is_game_paused: bool = false

# --- [НОВОЕ] НОЧНАЯ ПРОМОТКА ---
var is_night_skip: bool = false
var skip_target_day: int = 0

func _ready():
	# GameTime должен работать даже если все на паузе
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Всегда сбрасываем скорость на нормальную при старте игры
	Engine.time_scale = 1.0
	current_speed_scale = 1.0
	is_game_paused = false
	is_night_skip = false

func _process(delta):
	# При Engine.time_scale > 1, delta будет больше (или приходить чаще),
	# поэтому время в игре побежит быстрее само собой.
	
	time_accumulator += delta * MINUTES_PER_REAL_SECOND
	
	# Если набежала целая минута (или несколько)
	while time_accumulator >= 1.0:
		minute += 1
		time_accumulator -= 1.0
		
		# Логика перевода часов
		if minute >= 60:
			minute = 0
			hour += 1
			
			# --- ПРОВЕРКА РАСПИСАНИЯ ---
			if hour == START_HOUR:
				emit_signal("work_started")
				print("🔔 09:00: СТАРТ РАБОТЫ")
				
			elif hour == END_HOUR:
				emit_signal("work_ended")
				print("🔔 18:00: КОНЕЦ РАБОТЫ")
			
			# Новый день
			if hour >= 24:
				hour = 0
				day += 1
				emit_signal("day_started", day)
				GameState.pay_daily_salaries()
			
			# --- ПРОВЕРКА ОКОНЧАНИЯ ПРОМОТКИ ---
			if is_night_skip and day == skip_target_day and hour == NIGHT_SKIP_END_HOUR and minute == 0:
				finish_night_skip()
		
		# Сообщаем всем, сколько сейчас времени
		emit_signal("time_tick", hour, minute)

# --- НОЧНАЯ ПРОМОТКА ---

func start_night_skip():
	if is_night_skip:
		return
	
	is_night_skip = true
	skip_target_day = day + 1
	
	var minutes_remaining_today = ((24 - hour) * 60) - minute
	var minutes_until_target = minutes_remaining_today + (NIGHT_SKIP_END_HOUR * 60)
	
	var skip_speed = max(1.0, minutes_until_target / NIGHT_SKIP_DURATION_SECONDS)
	current_speed_scale = skip_speed
	Engine.time_scale = current_speed_scale
	
	# ВАЖНО: замораживаем весь мир, чтобы камера не уезжала
	get_tree().paused = true
	
	emit_signal("night_skip_started")

func finish_night_skip():
	if not is_night_skip:
		return
	
	is_night_skip = false
	current_speed_scale = 1.0
	Engine.time_scale = current_speed_scale
	
	# Возвращаем мир
	get_tree().paused = false
	
	emit_signal("night_skip_finished")

# --- [НОВОЕ] УПРАВЛЕНИЕ СКОРОСТЬЮ ---

# Основная функция смены скорости
func set_speed(new_scale: float):
	if is_night_skip:
		return
	
	if new_scale == 0:
		set_paused(true)
		return
	
	set_paused(false) # Снимаем с паузы, если была
	
	current_speed_scale = new_scale
	Engine.time_scale = current_speed_scale
	print("⏩ Скорость игры: x", current_speed_scale)

# Функция паузы
func set_paused(state: bool):
	if is_night_skip:
		return
	
	is_game_paused = state
	# get_tree().paused замораживает _process и _physics_process у всех узлов,
	# кроме тех, у кого Process Mode стоит "Always" или "When Paused".
	get_tree().paused = is_game_paused
	
	if is_game_paused:
		print("⏸ ИГРА НА ПАУЗЕ")

# Быстрые методы для кнопок UI
func speed_pause(): set_speed(0.0)
func speed_1x(): set_speed(1.0)
func speed_2x(): set_speed(2.0)
func speed_5x(): set_speed(5.0)
