extends CharacterBody2D

# --- СОСТОЯНИЯ ---
enum State {
	IDLE,
	MOVING,
	WORKING,
	GOING_HOME,
	HOME,
	GOING_COFFEE,
	COFFEE_BREAK,
	GOING_TOILET,
	TOILET_BREAK,
	WANDERING,     # Слоняется по офису
	WANDER_PAUSE   # Стоит на месте, "думает"
}

var current_state = State.IDLE
var movement_speed = 100.0 

# Настройка потери энергии (10 ед в игровой час)
const ENERGY_LOSS_PER_GAME_HOUR = 10.0

# Кофе-настройки (БАЗОВЫЕ значения)
const COFFEE_THRESHOLD = 70.0
const COFFEE_MIN_GAIN = 10.0
const COFFEE_MAX_GAIN = 15.0
const COFFEE_MIN_MINUTES = 10.0
const COFFEE_MAX_MINUTES = 15.0

# Кофе-множитель для трейта "coffee_lover"
const COFFEE_LOVER_DURATION_MULT = 2.0

# Туалет-настройки
const TOILET_VISITS_PER_DAY = 2
const TOILET_BREAK_MINUTES = 15.0

# Наклон при ходьбе
const LEAN_ANGLE = 0.12
const LEAN_SPEED = 10.0

# --- НАСТРОЙКИ СЛОНЯНИЯ ---
const WANDER_RADIUS = 1000.0          # Максимальный радиус от текущей позиции
const WANDER_PAUSE_MIN = 2.0         # Мин. время стоянки (реальные секунды)
const WANDER_PAUSE_MAX = 5.0         # Макс. время стоянки (реальные секунды)
const WANDER_SPEED_MULT = 0.5        # Скорость при слонянии (50% от нормальной)

var my_desk_position: Vector2 = Vector2.ZERO 
var coffee_machine_ref = null
var coffee_break_minutes_left := 0.0

var toilet_ref = null
var toilet_break_minutes_left := 0.0
var toilet_visit_times: Array[int] = []
var toilet_visits_done := 0

# --- ПЕРЕМЕННЫЕ СЛОНЯНИЯ ---
var _wander_pause_timer := 0.0       # Сколько ещё стоять на месте
var _wander_origin: Vector2 = Vector2.ZERO  # Точка спавна (центр слоняния)

@export var data: EmployeeData

@onready var body_sprite = $Visuals/Body
@onready var head_sprite = $Visuals/Body/Head
@onready var nav_agent = $NavigationAgent2D 
@onready var debug_label = $DebugLabel

# --- КРУЖКА ---
@onready var coffee_cup_holder = $CoffeeCupHolder

func _ready():
	add_to_group("npc")
	start_breathing_animation()
	
	nav_agent.path_desired_distance = 20.0
	nav_agent.target_desired_distance = 20.0
	
	if data:
		update_visuals()
		data.current_energy = 100.0

	coffee_cup_holder.visible = false

	GameTime.work_started.connect(_on_work_started)
	GameTime.work_ended.connect(_on_work_ended)
	
	if GameTime.hour < 9 or GameTime.hour >= 18:
		_go_to_sleep_instant()

func _physics_process(delta):
	update_debug_label()
	
	match current_state:
		State.IDLE:
			_apply_lean(Vector2.ZERO, delta)
			# Если рабочее время и нет стола — начинаем слоняться
			if my_desk_position == Vector2.ZERO and _is_work_time():
				_start_wandering()
		
		State.HOME:
			_apply_lean(Vector2.ZERO, delta)
			
		State.WORKING:
			var loss_speed = (ENERGY_LOSS_PER_GAME_HOUR / 60.0) * GameTime.MINUTES_PER_REAL_SECOND
			data.current_energy -= loss_speed * delta
			if data.current_energy < 0:
				data.current_energy = 0
			
			_try_start_toilet_break()
			_try_start_coffee_break()
			_apply_lean(Vector2.ZERO, delta)
			
		State.MOVING, State.GOING_COFFEE, State.GOING_TOILET:
			var dist = global_position.distance_to(nav_agent.target_position)
			if dist < 100.0:
				_on_navigation_finished()
				return
			_move_along_path(delta)

		State.GOING_HOME:
			var dist = global_position.distance_to(nav_agent.target_position)
			if dist < 50.0:
				_on_arrived_home()
				return
			_move_along_path(delta)

		State.COFFEE_BREAK:
			coffee_cup_holder.visible = true
			
			coffee_break_minutes_left -= GameTime.MINUTES_PER_REAL_SECOND * delta
			if coffee_break_minutes_left <= 0.0:
				_finish_coffee_break()
			_apply_lean(Vector2.ZERO, delta)

		State.TOILET_BREAK:
			toilet_break_minutes_left -= GameTime.MINUTES_PER_REAL_SECOND * delta
			if toilet_break_minutes_left <= 0.0:
				_finish_toilet_break()
			_apply_lean(Vector2.ZERO, delta)

		# --- СЛОНЯНИЕ: идёт к случайной точке ---
		State.WANDERING:
			var dist = global_position.distance_to(nav_agent.target_position)
			if dist < 100.0:
				_on_wander_arrived()
				return
			_move_along_path_slow(delta)

		# --- СЛОНЯНИЕ: стоит на месте, "думает" ---
		State.WANDER_PAUSE:
			_wander_pause_timer -= delta
			_apply_lean(Vector2.ZERO, delta)
			if _wander_pause_timer <= 0.0:
				_pick_next_wander_target()

func _move_along_path(delta):
	var next_path_position = nav_agent.get_next_path_position()
	var direction = global_position.direction_to(next_path_position)
	var new_velocity = direction * movement_speed
	velocity = new_velocity
	move_and_slide()
	_apply_lean(direction, delta)

# Медленная ходьба для слоняния
func _move_along_path_slow(delta):
	var next_path_position = nav_agent.get_next_path_position()
	var direction = global_position.direction_to(next_path_position)
	var new_velocity = direction * movement_speed * WANDER_SPEED_MULT
	velocity = new_velocity
	move_and_slide()
	_apply_lean(direction, delta)

func _apply_lean(direction: Vector2, delta: float) -> void:
	var target_lean = 0.0
	if direction.x > 0.1:
		target_lean = LEAN_ANGLE
	elif direction.x < -0.1:
		target_lean = -LEAN_ANGLE
	
	body_sprite.rotation = lerp(body_sprite.rotation, target_lean, LEAN_SPEED * delta)
	head_sprite.rotation = lerp(head_sprite.rotation, target_lean * 0.6, LEAN_SPEED * delta)

# --- СЛОНЯНИЕ ---
func _is_work_time() -> bool:
	return GameTime.hour >= GameTime.START_HOUR and GameTime.hour < GameTime.END_HOUR

func _start_wandering():
	# Запоминаем точку, вокруг которой будем слоняться
	_wander_origin = global_position
	_pick_next_wander_target()

func _pick_next_wander_target():
	if my_desk_position != Vector2.ZERO:
		move_to_desk(my_desk_position)
		return
	
	if not _is_work_time():
		_on_work_ended()
		return
	
	# Выбираем случайную точку в радиусе
	var random_angle = randf() * TAU
	var random_dist = randf_range(50.0, WANDER_RADIUS)
	var raw_target = _wander_origin + Vector2(cos(random_angle), sin(random_angle)) * random_dist
	
	# Привязываем к ближайшей ВАЛИДНОЙ точке на навигационной карте
	var nav_map = get_world_2d().navigation_map
	var safe_target = NavigationServer2D.map_get_closest_point(nav_map, raw_target)
	
	# Защита: если точка слишком близко — выбираем заново
	if global_position.distance_to(safe_target) < 30.0:
		_wander_pause_timer = 0.5  # Подождём полсекунды и попробуем снова
		current_state = State.WANDER_PAUSE
		return
	
	nav_agent.target_position = safe_target
	current_state = State.WANDERING
	z_index = 0

func _on_wander_arrived():
	# Пришёл к точке — останавливаемся, стоим какое-то время
	velocity = Vector2.ZERO
	current_state = State.WANDER_PAUSE
	_wander_pause_timer = randf_range(WANDER_PAUSE_MIN, WANDER_PAUSE_MAX)

# --- КОФЕ ---
func _try_start_coffee_break():
	if data.current_energy > COFFEE_THRESHOLD:
		return
	
	var machine = get_tree().get_first_node_in_group("coffee_machine")
	if machine and machine.try_reserve(self):
		coffee_machine_ref = machine
		current_state = State.GOING_COFFEE
		nav_agent.target_position = machine.get_spot_position()
		z_index = 0

func _start_coffee_break():
	current_state = State.COFFEE_BREAK
	velocity = Vector2.ZERO
	
	coffee_cup_holder.visible = true
	
	# --- ТРЕЙТ: ОБОЖАЕТ КОФЕ ---
	var min_minutes = COFFEE_MIN_MINUTES
	var max_minutes = COFFEE_MAX_MINUTES
	
	if data and data.has_trait("coffee_lover"):
		min_minutes *= COFFEE_LOVER_DURATION_MULT
		max_minutes *= COFFEE_LOVER_DURATION_MULT
		print("☕ ", data.employee_name, " ОБОЖАЕТ КОФЕ! Перерыв удлинён: ", min_minutes, "-", max_minutes, " мин.")
	
	coffee_break_minutes_left = randf_range(min_minutes, max_minutes)

func _finish_coffee_break():
	coffee_cup_holder.visible = false
	
	if coffee_machine_ref:
		coffee_machine_ref.release(self)
		coffee_machine_ref = null
	
	data.current_energy = min(100.0, data.current_energy + randf_range(COFFEE_MIN_GAIN, COFFEE_MAX_GAIN))
	
	if my_desk_position != Vector2.ZERO:
		move_to_desk(my_desk_position)

# --- ТУАЛЕТ ---
func _setup_toilet_schedule():
	toilet_visit_times.clear()
	toilet_visits_done = 0
	
	var work_minutes = (GameTime.END_HOUR - GameTime.START_HOUR) * 60
	for i in range(TOILET_VISITS_PER_DAY):
		var t = randi_range(30, work_minutes - int(TOILET_BREAK_MINUTES) - 30)
		toilet_visit_times.append(t)
	
	toilet_visit_times.sort()

func _try_start_toilet_break():
	if toilet_visits_done >= TOILET_VISITS_PER_DAY:
		return
	
	if GameTime.hour < GameTime.START_HOUR or GameTime.hour >= GameTime.END_HOUR:
		return
	
	if toilet_visit_times.is_empty():
		return
	
	var current_work_minutes = (GameTime.hour - GameTime.START_HOUR) * 60 + GameTime.minute
	if current_work_minutes < toilet_visit_times[toilet_visits_done]:
		return
	
	var toilet = get_tree().get_first_node_in_group("toilet")
	if toilet and toilet.try_reserve(self):
		toilet_ref = toilet
		current_state = State.GOING_TOILET
		nav_agent.target_position = toilet.get_spot_position()
		z_index = 0

func _start_toilet_break():
	current_state = State.TOILET_BREAK
	velocity = Vector2.ZERO
	
	toilet_break_minutes_left = TOILET_BREAK_MINUTES

func _finish_toilet_break():
	if toilet_ref:
		toilet_ref.release(self)
		toilet_ref = null
	
	toilet_visits_done += 1
	
	if my_desk_position != Vector2.ZERO:
		move_to_desk(my_desk_position)

# --- ФУНКЦИИ УПРАВЛЕНИЯ ---
func move_to_desk(target_point: Vector2):
	my_desk_position = target_point
	
	if GameTime.hour < GameTime.START_HOUR or GameTime.hour >= GameTime.END_HOUR:
		_go_to_sleep_instant()
		return
	
	current_state = State.MOVING
	z_index = 0 
	nav_agent.target_position = target_point
	visible = true
	$CollisionShape2D.disabled = false

# --- Сотрудник "встаёт" из-за стола ---
func release_from_desk():
	print("🚶 ", data.employee_name, " встаёт из-за стола")
	
	# Сбрасываем привязку к столу
	my_desk_position = Vector2.ZERO
	
	# Останавливаем кофе/туалет если был в процессе
	coffee_cup_holder.visible = false
	if coffee_machine_ref:
		coffee_machine_ref.release(self)
		coffee_machine_ref = null
	if toilet_ref:
		toilet_ref.release(self)
		toilet_ref = null
	
	# Начинаем слоняться, если рабочее время
	if _is_work_time():
		_start_wandering()
	else:
		current_state = State.IDLE
		velocity = Vector2.ZERO

func _on_navigation_finished():
	if current_state == State.GOING_COFFEE:
		_start_coffee_break()
		return
	if current_state == State.GOING_TOILET:
		_start_toilet_break()
		return
	
	global_position = nav_agent.target_position
	current_state = State.WORKING
	velocity = Vector2.ZERO

# --- ЛОГИКА ДЕНЬ/НОЧЬ ---
func _on_work_started():
	if data:
		data.current_energy = 100.0
		
	_setup_toilet_schedule()
	
	if my_desk_position == Vector2.ZERO:
		# Нет стола — начинаем слоняться
		visible = true
		$CollisionShape2D.disabled = false
		z_index = 0
		
		var entrance = get_tree().get_first_node_in_group("entrance")
		if entrance:
			global_position = entrance.global_position
		
		_start_wandering()
		return

	var entrance = get_tree().get_first_node_in_group("entrance")
	if entrance:
		global_position = entrance.global_position
	
	visible = true
	$CollisionShape2D.disabled = false
	z_index = 0 
	
	current_state = State.MOVING
	nav_agent.target_position = my_desk_position

func _on_work_ended():
	coffee_cup_holder.visible = false
	
	if coffee_machine_ref:
		coffee_machine_ref.release(self)
		coffee_machine_ref = null
	
	if toilet_ref:
		toilet_ref.release(self)
		toilet_ref = null
	
	z_index = 0 
	var entrance = get_tree().get_first_node_in_group("entrance")
	if entrance:
		nav_agent.target_position = entrance.global_position
		current_state = State.GOING_HOME
	else:
		_on_arrived_home()

func _on_arrived_home():
	visible = false
	$CollisionShape2D.disabled = true
	current_state = State.HOME
	velocity = Vector2.ZERO

func _go_to_sleep_instant():
	coffee_cup_holder.visible = false
	
	if toilet_ref:
		toilet_ref.release(self)
		toilet_ref = null
	
	visible = false
	$CollisionShape2D.disabled = true
	current_state = State.HOME
	velocity = Vector2.ZERO

# --- ВИЗУАЛ ---
func start_breathing_animation():
	if not body_sprite: return
	var tween = create_tween()
	tween.set_loops()
	tween.tween_interval(randf_range(0.0, 1.0))
	tween.tween_property(body_sprite, "scale", Vector2(0.98, 1.02), 1.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(body_sprite, "scale", Vector2(1.02, 0.98), 1.5).set_trans(Tween.TRANS_SINE)

func setup_employee(new_data: EmployeeData):
	data = new_data
	data.current_energy = 100.0
	update_visuals()

func update_visuals():
	if not body_sprite: return
	if data.job_title == "Backend Developer":
		body_sprite.self_modulate = Color(0.4, 0.4, 1.0)
	elif data.job_title == "Business Analyst":
		body_sprite.self_modulate = Color(1.0, 0.4, 0.4)
	elif data.job_title == "QA Engineer":
		body_sprite.self_modulate = Color(0.4, 1.0, 0.4)
	else:
		body_sprite.self_modulate = Color.WHITE

func interact():
	var hud = get_tree().get_first_node_in_group("ui")
	if hud and data:
		hud.show_employee_card(data)

func update_debug_label():
	if debug_label and data:
		var state_name = State.keys()[current_state]
		var energy_str = "%d%%" % int(data.current_energy)
		var eff_str = "x%.1f" % data.get_efficiency_multiplier()
		
		debug_label.text = "%s\nEn: %s (%s)" % [state_name, energy_str, eff_str]
		
		match current_state:
			State.IDLE: debug_label.modulate = Color.WHITE
			State.MOVING: debug_label.modulate = Color.YELLOW
			State.WORKING: debug_label.modulate = Color.GREEN
			State.GOING_HOME: debug_label.modulate = Color.ORANGE
			State.HOME: debug_label.modulate = Color.GRAY
			State.GOING_COFFEE: debug_label.modulate = Color.AQUA
			State.COFFEE_BREAK: debug_label.modulate = Color.SKY_BLUE
			State.GOING_TOILET: debug_label.modulate = Color.DEEP_PINK
			State.TOILET_BREAK: debug_label.modulate = Color.MEDIUM_PURPLE
			State.WANDERING: debug_label.modulate = Color.SANDY_BROWN
			State.WANDER_PAUSE: debug_label.modulate = Color.TAN
