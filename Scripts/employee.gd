extends CharacterBody2D

# --- СОСТОЯНИЯ ---
enum State {
	IDLE,
	MOVING,
	WORKING,
	GOING_HOME,
	HOME,
	GOING_COFFEE,
	COFFEE_BREAK
}

var current_state = State.IDLE
var movement_speed = 100.0 

# Настройка потери энергии (10 ед в игровой час)
const ENERGY_LOSS_PER_GAME_HOUR = 10.0

# Кофе-настройки
const COFFEE_THRESHOLD = 70.0
const COFFEE_MIN_GAIN = 10.0
const COFFEE_MAX_GAIN = 15.0
const COFFEE_MIN_MINUTES = 10.0
const COFFEE_MAX_MINUTES = 15.0

var my_desk_position: Vector2 = Vector2.ZERO 
var coffee_machine_ref = null
var coffee_break_minutes_left := 0.0

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
		State.IDLE, State.HOME:
			pass
			
		State.WORKING:
			var loss_speed = (ENERGY_LOSS_PER_GAME_HOUR / 60.0) * GameTime.MINUTES_PER_REAL_SECOND
			data.current_energy -= loss_speed * delta
			if data.current_energy < 0:
				data.current_energy = 0
			
			_try_start_coffee_break()
			
		State.MOVING, State.GOING_COFFEE:
			var dist = global_position.distance_to(nav_agent.target_position)
			if dist < 100.0:
				_on_navigation_finished()
				return
			_move_along_path()

		State.GOING_HOME:
			var dist = global_position.distance_to(nav_agent.target_position)
			if dist < 50.0:
				_on_arrived_home()
				return
			_move_along_path()

		State.COFFEE_BREAK:
			coffee_cup_holder.visible = true
			
			coffee_break_minutes_left -= GameTime.MINUTES_PER_REAL_SECOND * delta
			if coffee_break_minutes_left <= 0.0:
				_finish_coffee_break()

func _move_along_path():
	var next_path_position = nav_agent.get_next_path_position()
	var new_velocity = global_position.direction_to(next_path_position) * movement_speed
	velocity = new_velocity
	move_and_slide()

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
	coffee_break_minutes_left = randf_range(COFFEE_MIN_MINUTES, COFFEE_MAX_MINUTES)

func _finish_coffee_break():
	coffee_cup_holder.visible = false
	
	if coffee_machine_ref:
		coffee_machine_ref.release(self)
		coffee_machine_ref = null
	
	data.current_energy = min(100.0, data.current_energy + randf_range(COFFEE_MIN_GAIN, COFFEE_MAX_GAIN))
	
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

func _on_navigation_finished():
	if current_state == State.GOING_COFFEE:
		_start_coffee_break()
		return
	
	global_position = nav_agent.target_position
	current_state = State.WORKING
	z_index = -1 
	velocity = Vector2.ZERO

# --- ЛОГИКА ДЕНЬ/НОЧЬ ---
func _on_work_started():
	if data:
		data.current_energy = 100.0
		
	if my_desk_position == Vector2.ZERO:
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
