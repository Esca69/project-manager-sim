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
	WANDERING,
	WANDER_PAUSE,
	# === EVENT SYSTEM: Новые стейты ===
	SICK_LEAVE,
	DAY_OFF,
}

var current_state = State.IDLE
var movement_speed = 100.0 

const ENERGY_LOSS_PER_GAME_HOUR = 10.0

const COFFEE_THRESHOLD = 70.0
const COFFEE_MIN_GAIN = 10.0
const COFFEE_MAX_GAIN = 15.0
const COFFEE_MIN_MINUTES = 10.0
const COFFEE_MAX_MINUTES = 15.0

const COFFEE_LOVER_DURATION_MULT = 2.0

const TOILET_VISITS_PER_DAY = 2
const TOILET_BREAK_MINUTES = 15.0
const TOILET_LOVER_DURATION_MULT = 2.0

const LEAN_ANGLE = 0.12
const LEAN_SPEED = 10.0

const WANDER_RADIUS = 1000.0
const WANDER_PAUSE_MIN = 2.0
const WANDER_PAUSE_MAX = 5.0
const WANDER_SPEED_MULT = 0.5

const EARLY_BIRD_MINUTES_EARLY_MIN = 30
const EARLY_BIRD_MINUTES_EARLY_MAX = 40
var _early_bird_start_hour: int = -1
var _early_bird_start_minute: int = -1
var _early_bird_arrived: bool = false

var my_desk_position: Vector2 = Vector2.ZERO 
var coffee_machine_ref = null
var coffee_break_minutes_left := 0.0

var toilet_ref = null
var toilet_break_minutes_left := 0.0
var toilet_visit_times: Array[int] = []
var toilet_visits_done := 0

var _wander_pause_timer := 0.0
var _wander_origin: Vector2 = Vector2.ZERO

var _should_go_home: bool = false

# Ссылка на текущий бабл с мыслями
var current_bubble: Node2D = null
# Таймер для фоновых мыслей во время работы
var _work_bubble_cooldown := 0.0

# === МОТИВАЦИЯ ОТ PM ===
var _motivation_minutes_left: float = 0.0

# Анимация мотивации — защита от повторного запуска
var _motivation_anim_tween: Tween = null

# === ЗАПРЕТ ТУАЛЕТА ОТ PM ===
var _toilet_ban_minutes_left: float = 0.0

# === EVENT SYSTEM: Счётчик дней болезни и флаг отгула ===
var sick_days_left: int = 0
var is_on_day_off: bool = false

# Уникальный цвет одежды и кожи для персонализации
var personal_color: Color = Color.WHITE
var skin_color: Color = Color.WHITE

const CLOTHING_PALETTE: Array[Color] = [
	Color("#FFADAD"), Color("#FFD6A5"), Color("#FDFFB6"), Color("#CAFFBF"),
	Color("#9BF6FF"), Color("#A0C4FF"), Color("#BDB2FF"), Color("#FFC6FF"),
	Color("#F15BB5"), Color("#FEE440"), Color("#00BBF9"), Color("#00F5D4"),
	Color("#8A2BE2"), Color("#FF9F1C"), Color("#2EC4B6"), Color("#E71D36"),
	Color("#9C89B8"), Color("#F0A6CA"), Color("#B8BEDD"), Color("#99E2B4")
]

const SKIN_LIGHT: Array[Color] = [
	Color("#FFE0BD"), Color("#FFCD94"), Color("#fff0e1")
]

const SKIN_MEDIUM: Array[Color] = [
	Color("#FFAD60"), Color("#CB8E63"), Color("#C68642"), Color("#8D5524")
]

const SKIN_DARK: Array[Color] = [
	Color("#61412A"), Color("#4A2E1B"), Color("#311A0E")
]

@export var data: EmployeeData

@onready var body_sprite = $Visuals/Body
@onready var head_sprite = $Visuals/Body/Head
@onready var nav_agent = $NavigationAgent2D 
@onready var debug_label = $DebugLabel
@onready var coffee_cup_holder = $CoffeeCupHolder

func _ready():
	add_to_group("npc")
	start_breathing_animation()
	
	nav_agent.path_desired_distance = 20.0
	nav_agent.target_desired_distance = 20.0
	
	if debug_label:
		var label_settings = LabelSettings.new()
		label_settings.font = load("res://Fonts/Inter-VariableFont_opsz,wght.ttf")
		label_settings.font_size = 18
		label_settings.outline_size = 4
		label_settings.outline_color = Color(0.1, 0.1, 0.1, 1.0)
		label_settings.line_spacing = -2.0 
		
		debug_label.label_settings = label_settings
		debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		debug_label.position = Vector2(-20, -230)
		debug_label.custom_minimum_size = Vector2(200, 75)
		debug_label.modulate.a = 0.0 
		
		debug_label.z_index = 50
		debug_label.z_as_relative = false
	
	if data:
		_assign_random_color()
		update_visuals()
		data.current_energy = 100.0
		_setup_early_bird()

	coffee_cup_holder.visible = false

	GameTime.work_started.connect(_on_work_started)
	GameTime.work_ended.connect(_on_work_ended)
	GameTime.time_tick.connect(_on_time_tick)
	GameTime.day_started.connect(_on_day_started)
	
	if GameTime.hour < 9 or GameTime.hour >= 18 or GameTime.is_weekend():
		_go_to_sleep_instant()

# === МОТИВАЦИЯ: ПРИМЕНИТЬ БОНУС ===
func apply_motivation(bonus: float, duration_minutes: float):
	if not data:
		return
	data.motivation_bonus = bonus
	_motivation_minutes_left = duration_minutes
	show_thought_bubble("🔥", 5.0)
	_play_motivation_reaction()
	print("🔥 %s замотивирован! +%d%% на %d мин." % [data.employee_name, int(bonus * 100), int(duration_minutes)])

func remove_motivation():
	if data:
		data.motivation_bonus = 0.0
	_motivation_minutes_left = 0.0

# === ЗАПРЕТ ТУАЛЕТА: ПРИМЕНИТЬ БАН ===
func apply_toilet_ban(duration_minutes: float):
	_toilet_ban_minutes_left = duration_minutes
	show_thought_bubble("🚫", 5.0)
	_play_motivation_reaction()
	
	if current_state == State.GOING_TOILET:
		if toilet_ref:
			toilet_ref.release(self)
			toilet_ref = null
		if my_desk_position != Vector2.ZERO and _is_my_stage_active():
			move_to_desk(my_desk_position)
		elif _is_work_time():
			_start_wandering()
	elif current_state == State.TOILET_BREAK:
		if toilet_ref:
			toilet_ref.release(self)
			toilet_ref = null
		toilet_visits_done += 1
		if my_desk_position != Vector2.ZERO and _is_my_stage_active():
			move_to_desk(my_desk_position)
		elif _is_work_time():
			_start_wandering()
	
	if data:
		print("🚫 %s: туалет запрещён на %d мин." % [data.employee_name, int(duration_minutes)])

func remove_toilet_ban():
	_toilet_ban_minutes_left = 0.0

# =============================================
# === EVENT SYSTEM: БОЛЕЗНЬ ===
# =============================================
func start_sick_leave(days: int):
	sick_days_left = days
	is_on_day_off = false
	
	coffee_cup_holder.visible = false
	if coffee_machine_ref:
		coffee_machine_ref.release(self)
		coffee_machine_ref = null
	if toilet_ref:
		toilet_ref.release(self)
		toilet_ref = null
	
	visible = false
	$CollisionShape2D.disabled = true
	velocity = Vector2.ZERO
	current_state = State.SICK_LEAVE
	
	show_thought_bubble("🤒", 3.0)
	if data:
		print("🤒 %s уходит на больничный (%d дн.)" % [data.employee_name, days])

func tick_sick_day():
	if current_state != State.SICK_LEAVE:
		return
	
	sick_days_left -= 1
	if sick_days_left <= 0:
		_recover_from_sick()

func _recover_from_sick():
	sick_days_left = 0
	current_state = State.HOME
	if data:
		data.current_energy = 100.0
		print("✅ %s выздоровел и готов к работе!" % data.employee_name)

# =============================================
# === EVENT SYSTEM: ОТГУЛ ===
# =============================================
func start_day_off():
	is_on_day_off = true
	sick_days_left = 0
	
	coffee_cup_holder.visible = false
	if coffee_machine_ref:
		coffee_machine_ref.release(self)
		coffee_machine_ref = null
	if toilet_ref:
		toilet_ref.release(self)
		toilet_ref = null
	
	velocity = Vector2.ZERO
	z_index = 0
	
	var entrance = get_tree().get_first_node_in_group("entrance")
	if entrance:
		nav_agent.target_position = entrance.global_position
		current_state = State.GOING_HOME
	else:
		_finalize_day_off()

func _finalize_day_off():
	visible = false
	$CollisionShape2D.disabled = true
	velocity = Vector2.ZERO
	current_state = State.DAY_OFF
	if data:
		print("🏠 %s ушёл в отгул до завтра" % data.employee_name)

func end_day_off():
	if current_state != State.DAY_OFF:
		return
	is_on_day_off = false
	current_state = State.HOME
	if data:
		data.current_energy = 100.0
		print("✅ %s вернулся из отгула" % data.employee_name)

# === АНИМАЦИЯ РЕАКЦИИ НА МОТИВАЦИЮ ===
func _play_motivation_reaction():
	if not body_sprite or not head_sprite:
		return

	if _motivation_anim_tween and _motivation_anim_tween.is_valid():
		_motivation_anim_tween.kill()

	var body_origin_y = body_sprite.position.y
	var head_origin_rot = head_sprite.rotation

	_motivation_anim_tween = create_tween()

	_motivation_anim_tween.tween_property(body_sprite, "position:y", body_origin_y - 30.0, 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_motivation_anim_tween.tween_property(body_sprite, "position:y", body_origin_y + 5.0, 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_motivation_anim_tween.tween_property(body_sprite, "position:y", body_origin_y, 0.06) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var shake_angle = 0.25
	var shake_step = 0.07

	_motivation_anim_tween.tween_property(head_sprite, "rotation", shake_angle, shake_step)
	_motivation_anim_tween.tween_property(head_sprite, "rotation", -shake_angle, shake_step)
	_motivation_anim_tween.tween_property(head_sprite, "rotation", shake_angle * 0.7, shake_step)
	_motivation_anim_tween.tween_property(head_sprite, "rotation", -shake_angle * 0.7, shake_step)
	_motivation_anim_tween.tween_property(head_sprite, "rotation", shake_angle * 0.3, shake_step)
	_motivation_anim_tween.tween_property(head_sprite, "rotation", -shake_angle * 0.3, shake_step)

	_motivation_anim_tween.tween_property(head_sprite, "rotation", head_origin_rot, 0.1) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _assign_random_color():
	var available_colors = CLOTHING_PALETTE.duplicate()
	
	var tree = get_tree()
	if tree == null:
		tree = Engine.get_main_loop()
	
	if tree and tree.has_method("get_nodes_in_group"):
		var npcs = tree.get_nodes_in_group("npc")
		for npc in npcs:
			if npc != self and "personal_color" in npc:
				var idx = available_colors.find(npc.personal_color)
				if idx != -1:
					available_colors.remove_at(idx)
	
	if available_colors.is_empty():
		personal_color = CLOTHING_PALETTE.pick_random()
	else:
		personal_color = available_colors.pick_random()

	var skin_roll = randi_range(1, 100)
	
	if skin_roll <= 75:
		skin_color = SKIN_LIGHT.pick_random()
	elif skin_roll <= 90:
		skin_color = SKIN_MEDIUM.pick_random()
	else:
		skin_color = SKIN_DARK.pick_random()

func _setup_early_bird():
	if not data or not data.has_trait("early_bird"):
		_early_bird_start_hour = -1
		_early_bird_start_minute = -1
		return
	
	var minutes_early = randi_range(EARLY_BIRD_MINUTES_EARLY_MIN, EARLY_BIRD_MINUTES_EARLY_MAX)
	var start_total_minutes = GameTime.START_HOUR * 60 - minutes_early
	_early_bird_start_hour = start_total_minutes / 60
	_early_bird_start_minute = start_total_minutes % 60

func _on_day_started(_day_number: int):
	_early_bird_arrived = false
	_setup_early_bird()

func _on_time_tick(_hour, _minute):
	if not data: return

	# === EVENT SYSTEM: Не тикаем таймеры если болеем или в отгуле ===
	if current_state == State.SICK_LEAVE or current_state == State.DAY_OFF:
		return

	# === MOOD SYSTEM v2: Обновляем флаг стола ===
	data.has_active_desk = (my_desk_position != Vector2.ZERO and _is_my_stage_active())

	# === MOOD SYSTEM v2: Тикаем временные модификаторы + пересчёт mood ===
	data.tick_mood_modifiers()

	# === МОТИВАЦИЯ: ТАЙМЕР ===
	if _motivation_minutes_left > 0:
		_motivation_minutes_left -= 1.0
		if _motivation_minutes_left <= 0:
			remove_motivation()
			print("⏰ Мотивация закончилась у %s" % data.employee_name)

	# === ЗАПРЕТ ТУАЛЕТА: ТАЙМЕР ===
	if _toilet_ban_minutes_left > 0:
		_toilet_ban_minutes_left -= 1.0
		if _toilet_ban_minutes_left <= 0:
			remove_toilet_ban()
			print("🚽 Запрет туалета закончился у %s" % data.employee_name)

	# --- Early bird логика ---
	if not data.has_trait("early_bird"): return
	if _early_bird_start_hour < 0: return
	if _early_bird_arrived: return
	if GameTime.is_weekend(): return
	if current_state != State.HOME: return
	
	if GameTime.hour >= GameTime.END_HOUR: return
	
	var current_total = GameTime.hour * 60 + GameTime.minute
	var early_total = _early_bird_start_hour * 60 + _early_bird_start_minute
	
	if current_total >= early_total:
		_early_bird_arrived = true
		_arrive_early_bird()

func _arrive_early_bird():
	if data:
		data.current_energy = 100.0
	
	_setup_toilet_schedule()
	
	var entrance = get_tree().get_first_node_in_group("entrance")
	if entrance:
		global_position = entrance.global_position
	
	visible = true
	$CollisionShape2D.disabled = false
	z_index = 0
	
	if my_desk_position != Vector2.ZERO and _is_my_stage_active():
		current_state = State.MOVING
		nav_agent.target_position = my_desk_position
	else:
		_start_wandering()

func _process(delta):
	var cam = get_viewport().get_camera_2d()
	if cam and debug_label:
		var z = cam.zoom.x
		var target_alpha = 0.0
		
		if z >= 0.8:
			target_alpha = 1.0
		elif z > 1.05:
			target_alpha = inverse_lerp(1.25, 1.45, z)
		else:
			target_alpha = 0.0
		
		var current_color = debug_label.modulate
		current_color.a = lerp(current_color.a, target_alpha, 8.0 * delta)
		debug_label.modulate = current_color

func _physics_process(delta):
	update_status_label()
	
	if _should_go_home:
		_should_go_home = false
		_force_go_home()
		return
	
	match current_state:
		State.IDLE:
			_apply_lean(Vector2.ZERO, delta)
			if my_desk_position == Vector2.ZERO and _is_work_time():
				_start_wandering()
		
		State.HOME:
			_apply_lean(Vector2.ZERO, delta)
		
		State.SICK_LEAVE, State.DAY_OFF:
			pass
			
		State.WORKING:
			if not _is_work_time():
				_force_go_home()
				return
			
			var drain_mult = data.get_energy_drain_multiplier()
			var loss_speed = (ENERGY_LOSS_PER_GAME_HOUR / 60.0) * GameTime.MINUTES_PER_REAL_SECOND * drain_mult
			data.current_energy -= loss_speed * delta
			if data.current_energy < 0:
				data.current_energy = 0
			
			if not _is_my_stage_active():
				_leave_desk_to_wander()
				return
			
			_try_start_toilet_break()
			_try_start_coffee_break()
			_apply_lean(Vector2.ZERO, delta)
			
			_work_bubble_cooldown -= delta
			if _work_bubble_cooldown <= 0.0:
				_show_random_work_thought()
				_work_bubble_cooldown = randf_range(15.0, 25.0)
			
		State.MOVING, State.GOING_COFFEE, State.GOING_TOILET:
			if not _is_work_time():
				_force_go_home()
				return
			
			var dist = global_position.distance_to(nav_agent.target_position)
			if dist < 100.0:
				_on_navigation_finished()
				return
			_move_along_path(delta)

		State.GOING_HOME:
			var dist = global_position.distance_to(nav_agent.target_position)
			if dist < 50.0:
				if is_on_day_off:
					_finalize_day_off()
				else:
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

		State.WANDERING:
			if not _is_work_time():
				_force_go_home()
				return
			
			if my_desk_position != Vector2.ZERO and _is_my_stage_active():
				move_to_desk(my_desk_position)
				return
			
			var dist = global_position.distance_to(nav_agent.target_position)
			if dist < 100.0:
				_on_wander_arrived()
				return
			_move_along_path_slow(delta)

		State.WANDER_PAUSE:
			if not _is_work_time():
				_force_go_home()
				return
			
			if my_desk_position != Vector2.ZERO and _is_my_stage_active():
				move_to_desk(my_desk_position)
				return
			
			_wander_pause_timer -= delta
			_apply_lean(Vector2.ZERO, delta)
			if _wander_pause_timer <= 0.0:
				_pick_next_wander_target()

func _is_my_stage_active() -> bool:
	if not data:
		return false
	return ProjectManager.is_employee_on_active_stage(data)

func _force_go_home():
	coffee_cup_holder.visible = false
	
	if coffee_machine_ref:
		coffee_machine_ref.release(self)
		coffee_machine_ref = null
	if toilet_ref:
		toilet_ref.release(self)
		toilet_ref = null
	
	if current_state == State.HOME or current_state == State.GOING_HOME or current_state == State.SICK_LEAVE or current_state == State.DAY_OFF:
		return
	
	velocity = Vector2.ZERO
	z_index = 0
	
	var entrance = get_tree().get_first_node_in_group("entrance")
	if entrance:
		nav_agent.target_position = entrance.global_position
		current_state = State.GOING_HOME
	else:
		_on_arrived_home()

func _leave_desk_to_wander():
	coffee_cup_holder.visible = false
	if coffee_machine_ref:
		coffee_machine_ref.release(self)
		coffee_machine_ref = null
	if toilet_ref:
		toilet_ref.release(self)
		toilet_ref = null
	
	velocity = Vector2.ZERO
	
	if _is_work_time():
		_start_wandering()
	else:
		_force_go_home()

func _move_along_path(delta):
	var next_path_position = nav_agent.get_next_path_position()
	var direction = global_position.direction_to(next_path_position)
	var new_velocity = direction * movement_speed
	velocity = new_velocity
	move_and_slide()
	_apply_lean(direction, delta)

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

func _is_work_time() -> bool:
	if GameTime.is_weekend():
		return false
	if data and data.has_trait("early_bird") and _early_bird_arrived:
		return GameTime.hour >= _early_bird_start_hour and GameTime.hour < GameTime.END_HOUR
	return GameTime.hour >= GameTime.START_HOUR and GameTime.hour < GameTime.END_HOUR

func _start_wandering():
	_wander_origin = global_position
	_pick_next_wander_target()

func _pick_next_wander_target():
	if my_desk_position != Vector2.ZERO and _is_my_stage_active():
		move_to_desk(my_desk_position)
		return
	
	if not _is_work_time():
		_force_go_home()
		return
	
	var random_angle = randf() * TAU
	var random_dist = randf_range(50.0, WANDER_RADIUS)
	var raw_target = _wander_origin + Vector2(cos(random_angle), sin(random_angle)) * random_dist
	
	var nav_map = get_world_2d().navigation_map
	var safe_target = NavigationServer2D.map_get_closest_point(nav_map, raw_target)
	
	if global_position.distance_to(safe_target) < 30.0:
		_wander_pause_timer = 0.5
		current_state = State.WANDER_PAUSE
		return
	
	nav_agent.target_position = safe_target
	current_state = State.WANDERING
	z_index = 0

func _try_start_coffee_break():
	if data.current_energy > COFFEE_THRESHOLD:
		return
	
	var machine = get_tree().get_first_node_in_group("coffee_machine")
	if machine and machine.try_reserve(self):
		coffee_machine_ref = machine
		current_state = State.GOING_COFFEE
		nav_agent.target_position = machine.get_spot_position()
		z_index = 0
		show_thought_bubble("☕")

func _start_coffee_break():
	current_state = State.COFFEE_BREAK
	velocity = Vector2.ZERO
	coffee_cup_holder.visible = true
	
	var min_minutes = COFFEE_MIN_MINUTES
	var max_minutes = COFFEE_MAX_MINUTES
	if data and data.has_trait("coffee_lover"):
		min_minutes *= COFFEE_LOVER_DURATION_MULT
		max_minutes *= COFFEE_LOVER_DURATION_MULT
	
	coffee_break_minutes_left = randf_range(min_minutes, max_minutes)

func _finish_coffee_break():
	coffee_cup_holder.visible = false
	if coffee_machine_ref:
		coffee_machine_ref.release(self)
		coffee_machine_ref = null
	
	data.current_energy = min(100.0, data.current_energy + randf_range(COFFEE_MIN_GAIN, COFFEE_MAX_GAIN))
	
	# === MOOD SYSTEM v2: Кофе → временный модификатор +3 на 60 мин ===
	if data:
		data.add_mood_modifier("coffee_boost", "MOOD_MOD_COFFEE", 3.0, 60.0)
	
	if my_desk_position != Vector2.ZERO and _is_my_stage_active():
		move_to_desk(my_desk_position)
	elif _is_work_time():
		_start_wandering()
	else:
		_force_go_home()

func _setup_toilet_schedule():
	toilet_visit_times.clear()
	toilet_visits_done = 0
	
	var work_minutes = (GameTime.END_HOUR - GameTime.START_HOUR) * 60
	for i in range(TOILET_VISITS_PER_DAY):
		var t = randi_range(30, work_minutes - int(TOILET_BREAK_MINUTES) - 30)
		toilet_visit_times.append(t)
	
	toilet_visit_times.sort()

func _try_start_toilet_break():
	if _toilet_ban_minutes_left > 0:
		return
	
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
		show_thought_bubble("🚽")

func _start_toilet_break():
	current_state = State.TOILET_BREAK
	velocity = Vector2.ZERO
	
	var duration = TOILET_BREAK_MINUTES
	if data and data.has_trait("toilet_lover"):
		duration *= TOILET_LOVER_DURATION_MULT
	
	toilet_break_minutes_left = duration

func _finish_toilet_break():
	if toilet_ref:
		toilet_ref.release(self)
		toilet_ref = null
	
	toilet_visits_done += 1
	
	# === MOOD SYSTEM v2: Туалет → временный модификатор +3 на 60 мин ===
	if data:
		data.add_mood_modifier("toilet_relief", "MOOD_MOD_TOILET", 3.0, 60.0)
	
	if my_desk_position != Vector2.ZERO and _is_my_stage_active():
		move_to_desk(my_desk_position)
	elif _is_work_time():
		_start_wandering()
	else:
		_force_go_home()

func _on_wander_arrived():
	velocity = Vector2.ZERO
	current_state = State.WANDER_PAUSE
	_wander_pause_timer = randf_range(WANDER_PAUSE_MIN, WANDER_PAUSE_MAX)

func move_to_desk(target_point: Vector2):
	my_desk_position = target_point
	
	if not _is_work_time():
		_go_to_sleep_instant()
		return
	
	if not _is_my_stage_active():
		if _is_work_time():
			_start_wandering()
		else:
			current_state = State.IDLE
		return
	
	current_state = State.MOVING
	z_index = 0 
	nav_agent.target_position = target_point
	visible = true
	$CollisionShape2D.disabled = false

func release_from_desk():
	my_desk_position = Vector2.ZERO
	
	coffee_cup_holder.visible = false
	if coffee_machine_ref:
		coffee_machine_ref.release(self)
		coffee_machine_ref = null
	if toilet_ref:
		toilet_ref.release(self)
		toilet_ref = null
	
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
	
	if not _is_work_time():
		_force_go_home()
		return
	
	if not _is_my_stage_active():
		_start_wandering()
		return
	
	global_position = nav_agent.target_position
	current_state = State.WORKING
	velocity = Vector2.ZERO
	
	_work_bubble_cooldown = randf_range(5.0, 10.0)

func _on_work_started():
	if current_state == State.SICK_LEAVE or current_state == State.DAY_OFF:
		return
	
	if data and data.has_trait("early_bird") and _early_bird_arrived:
		if current_state != State.HOME:
			return
	
	if data and data.has_trait("early_bird"):
		data.current_energy = 100.0
		_setup_toilet_schedule()
		_should_go_home = false
		return
	
	if data:
		data.current_energy = 100.0
		
	_setup_toilet_schedule()
	_should_go_home = false
	
	if my_desk_position == Vector2.ZERO:
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
	
	if _is_my_stage_active():
		current_state = State.MOVING
		nav_agent.target_position = my_desk_position
	else:
		_start_wandering()

func _on_work_ended():
	if current_state == State.HOME or current_state == State.GOING_HOME or current_state == State.SICK_LEAVE or current_state == State.DAY_OFF:
		return
	_should_go_home = true

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
	
	if current_state == State.SICK_LEAVE or current_state == State.DAY_OFF:
		return
	
	visible = false
	$CollisionShape2D.disabled = true
	current_state = State.HOME
	velocity = Vector2.ZERO

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
	_assign_random_color()
	update_visuals()
	_setup_early_bird()

func update_visuals():
	if body_sprite:
		body_sprite.self_modulate = personal_color
	if head_sprite:
		head_sprite.self_modulate = skin_color

func interact():
	var hud = get_tree().get_first_node_in_group("ui")
	if hud and data:
		hud.show_employee_card(data)

func get_human_state_name() -> String:
	match current_state:
		State.IDLE: return tr("EMP_ACTION_IDLE")
		State.MOVING: return tr("EMP_ACTION_MOVING")
		State.WORKING:
			if data.employee_name in ["Лера", "Lera"]: return tr("EMP_ACTION_WORK_LERA")
			elif data.job_title == "Backend Developer": return tr("EMP_ACTION_WORK_DEV")
			elif data.job_title == "Business Analyst": return tr("EMP_ACTION_WORK_BA")
			elif data.job_title == "QA Engineer": return tr("EMP_ACTION_WORK_QA")
			return tr("EMP_ACTION_WORK_DEFAULT")
		State.GOING_HOME: return tr("EMP_ACTION_GOING_HOME")
		State.HOME: return tr("EMP_ACTION_HOME")
		State.GOING_COFFEE: return tr("EMP_ACTION_GOING_COFFEE")
		State.COFFEE_BREAK: return tr("EMP_ACTION_COFFEE_BREAK")
		State.GOING_TOILET: return tr("EMP_ACTION_GOING_TOILET")
		State.TOILET_BREAK: return tr("EMP_ACTION_TOILET_BREAK")
		State.WANDERING: return tr("EMP_ACTION_WANDERING")
		State.WANDER_PAUSE: return tr("EMP_ACTION_WANDER_PAUSE")
		State.SICK_LEAVE: return tr("EMP_ACTION_SICK_LEAVE")
		State.DAY_OFF: return tr("EMP_ACTION_DAY_OFF")
	return "..."

func update_status_label():
	if debug_label and data:
		var action_text = get_human_state_name()
		
		var short_role = ""
		if data.job_title == "Backend Developer":
			short_role = tr("ROLE_SHORT_DEV")
		elif data.job_title == "Business Analyst":
			short_role = tr("ROLE_SHORT_BA")
		elif data.job_title == "QA Engineer":
			short_role = tr("ROLE_SHORT_QA")
		else:
			short_role = data.job_title
		
		debug_label.text = short_role + "\n" + data.employee_name + "\n" + action_text

func _show_random_work_thought():
	var emoji = "💼"
	if data:
		if data.employee_name in ["Лера", "Lera"]: emoji = "☎️"
		elif data.job_title == "Backend Developer": emoji = "💻" 
		elif data.job_title == "Business Analyst": emoji = "📝" 
		elif data.job_title == "QA Engineer": emoji = "🐞" 
	
	show_thought_bubble(emoji, 3.0)

func show_thought_bubble(emoji_text: String, duration: float = 9.0):
	if is_instance_valid(current_bubble):
		current_bubble.queue_free()

	current_bubble = Node2D.new()
	add_child(current_bubble)

	current_bubble.position = Vector2(0, -210)
	current_bubble.z_index = 100 

	var panel = Panel.new()
	current_bubble.add_child(panel)
	
	panel.custom_minimum_size = Vector2(72, 72)
	panel.size = Vector2(72, 72)
	panel.position = Vector2(-36, -36) 

	var style = StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 1.0, 1.0) 
	style.border_width_bottom = 2
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color(0.2, 0.2, 0.2, 1.0) 
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.shadow_color = Color(0, 0, 0, 0.1) 
	style.shadow_size = 4
	panel.add_theme_stylebox_override("panel", style)

	var label = Label.new()
	panel.add_child(label)
	
	label.custom_minimum_size = Vector2(72, 72)
	label.size = Vector2(72, 72)
	label.position = Vector2.ZERO
	
	label.text = emoji_text
	
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var label_settings = LabelSettings.new()
	label_settings.font_size = 42
	label.label_settings = label_settings

	current_bubble.scale = Vector2.ZERO
	var tween = create_tween()
	
	tween.tween_property(current_bubble, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(duration)
	tween.tween_property(current_bubble, "modulate:a", 0.0, 0.5)
	tween.parallel().tween_property(current_bubble, "position:y", current_bubble.position.y - 30, 0.5)
	tween.tween_callback(current_bubble.queue_free)
