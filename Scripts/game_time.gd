extends Node

# Глобальные сигналы (на них подпишутся все: UI, сотрудники, календарь)
signal time_tick(hour, minute)
signal day_started(day_number)
signal day_ended # Можно использовать для сна игрока

# --- СИГНАЛЫ ДЛЯ AI ---
signal work_started # Сработает в 09:00
signal work_ended   # Сработает в 18:00

# Настройки времени
# При Engine.time_scale = 1.0, одна игровая минута пройдет за 1 реальную секунду (если тут стоит 1.0)
const MINUTES_PER_REAL_SECOND = 1.0 

const START_HOUR = 9  
const END_HOUR = 18   

# Текущее состояние
var day = 1
var hour = 8 
var minute = 0

var time_accumulator = 0.0 

# --- [НОВОЕ] ПЕРЕМЕННЫЕ СКОРОСТИ ---
var current_speed_scale: float = 1.0
var is_game_paused: bool = false

func _ready():
	# Всегда сбрасываем скорость на нормальную при старте игры
	Engine.time_scale = 1.0
	current_speed_scale = 1.0
	is_game_paused = false

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
		
		# Сообщаем всем, сколько сейчас времени
		emit_signal("time_tick", hour, minute)

# --- [НОВОЕ] УПРАВЛЕНИЕ СКОРОСТЬЮ ---

# Основная функция смены скорости
func set_speed(new_scale: float):
	if new_scale == 0:
		set_paused(true)
		return
	
	set_paused(false) # Снимаем с паузы, если была
	
	current_speed_scale = new_scale
	Engine.time_scale = current_speed_scale
	print("⏩ Скорость игры: x", current_speed_scale)

# Функция паузы
func set_paused(state: bool):
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
