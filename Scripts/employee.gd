extends CharacterBody2D

# --- СОСТОЯНИЯ ---
enum State {
	IDLE,       # Стоит (не работает)
	MOVING,     # Идет к цели (не работает)
	WORKING,    # Сидит за столом (РАБОТАЕТ)
	GOING_HOME, # Идет к выходу (18:00)
	HOME        # Исчез (дома)
}

var current_state = State.IDLE
var movement_speed = 100.0 

# Настройка потери энергии (10 ед в игровой час)
const ENERGY_LOSS_PER_GAME_HOUR = 10.0

var my_desk_position: Vector2 = Vector2.ZERO 

@export var data: EmployeeData

@onready var body_sprite = $Visuals/Body
@onready var head_sprite = $Visuals/Body/Head
@onready var nav_agent = $NavigationAgent2D 
@onready var debug_label = $DebugLabel

func _ready():
	add_to_group("npc")
	start_breathing_animation()
	
	nav_agent.path_desired_distance = 20.0
	nav_agent.target_desired_distance = 20.0
	
	if data:
		update_visuals()
		# На старте полная энергия
		data.current_energy = 100.0

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
			# --- [НОВОЕ] ТРАТИМ ЭНЕРГИЮ ---
			# Формула: (Потеря в час / 60 мин) * (Скорость минут в сек) * delta
			var loss_speed = (ENERGY_LOSS_PER_GAME_HOUR / 60.0) * GameTime.MINUTES_PER_REAL_SECOND
			
			data.current_energy -= loss_speed * delta
			
			# Не даем уйти ниже нуля
			if data.current_energy < 0:
				data.current_energy = 0
			
		State.MOVING:
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

func _move_along_path():
	var next_path_position = nav_agent.get_next_path_position()
	var new_velocity = global_position.direction_to(next_path_position) * movement_speed
	velocity = new_velocity
	move_and_slide()

# --- ФУНКЦИИ УПРАВЛЕНИЯ ---

func move_to_desk(target_point: Vector2):
	my_desk_position = target_point 
	current_state = State.MOVING
	z_index = 0 
	nav_agent.target_position = target_point
	visible = true
	$CollisionShape2D.disabled = false

func _on_navigation_finished():
	global_position = nav_agent.target_position
	current_state = State.WORKING
	z_index = -1 
	velocity = Vector2.ZERO

# --- ЛОГИКА ДЕНЬ/НОЧЬ ---

func _on_work_started():
	# [НОВОЕ] Утро! Восстанавливаем силы!
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
	visible = false
	$CollisionShape2D.disabled = true
	current_state = State.HOME

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
	# При создании тоже даем 100 энергии
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

# --- [ОБНОВЛЕНО] ОТЛАДКА ---
func update_debug_label():
	if debug_label and data:
		var state_name = State.keys()[current_state]
		# Показываем Состояние + Энергию + Эффективность
		var energy_str = "%d%%" % int(data.current_energy)
		var eff_str = "x%.1f" % data.get_efficiency_multiplier()
		
		debug_label.text = "%s\nEn: %s (%s)" % [state_name, energy_str, eff_str]
		
		match current_state:
			State.IDLE: debug_label.modulate = Color.WHITE
			State.MOVING: debug_label.modulate = Color.YELLOW
			State.WORKING: debug_label.modulate = Color.GREEN
			State.GOING_HOME: debug_label.modulate = Color.ORANGE
			State.HOME: debug_label.modulate = Color.GRAY
