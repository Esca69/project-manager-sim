extends CharacterBody2D

const SPEED = 300.0

const ZOOM_STEP = 0.1
const ZOOM_MIN = 0.6
const ZOOM_MAX = 1.6
const ZOOM_SMOOTH_SPEED = 8.0

const LEAN_ANGLE = 0.12 # ~7 градусов
const LEAN_SPEED = 10.0

# Ссылка на нашу зону взаимодействия (чтобы каждый раз не искать)
@onready var interaction_zone = $InteractionZone
@onready var camera = $Camera2D
@onready var body_sprite = $Sprite2D
@onready var head_sprite = $Sprite2D/Head2

var target_zoom: Vector2 = Vector2.ONE

func _ready():
	target_zoom = camera.zoom

func _physics_process(delta):
	# --- БЛОК БЛОКИРОВКИ УПРАВЛЕНИЯ ---
	if GameTime.is_night_skip:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	# --- БЛОК ДВИЖЕНИЯ (старый) ---
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if direction:
		velocity = direction * SPEED
	else:
		velocity = Vector2.ZERO
	move_and_slide()

	# --- НАКЛОН ПРИ ДВИЖЕНИИ ---
	var target_lean = 0.0
	if direction.x > 0.1:
		target_lean = LEAN_ANGLE
	elif direction.x < -0.1:
		target_lean = -LEAN_ANGLE

	body_sprite.rotation = lerp(body_sprite.rotation, target_lean, LEAN_SPEED * delta)
	head_sprite.rotation = lerp(head_sprite.rotation, target_lean * 0.6, LEAN_SPEED * delta)

	# --- БЛОК ВЗАИМОДЕЙСТВИЯ (новый) ---
	# Если нажали кнопку "interact" (наша E)
	if Input.is_action_just_pressed("interact"):
		interact()

func _process(delta):
	# Плавное приближение к целевому зуму
	camera.zoom = camera.zoom.lerp(target_zoom, min(1.0, ZOOM_SMOOTH_SPEED * delta))

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed:
		# Вверх = приблизить, вниз = отдалить
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(-ZOOM_STEP)

func _set_zoom(delta):
	var new_zoom = target_zoom + Vector2(delta, delta)
	new_zoom.x = clamp(new_zoom.x, ZOOM_MIN, ZOOM_MAX)
	new_zoom.y = clamp(new_zoom.y, ZOOM_MIN, ZOOM_MAX)
	target_zoom = new_zoom

func interact():
	var bodies = interaction_zone.get_overlapping_bodies()
	for body in bodies:
		# NPC — показываем карточку сотрудника
		if body.is_in_group("npc") and body.data:
			get_tree().call_group("ui", "show_employee_card", body.data)
			return
		
		# Стол или другой интерактивный объект — вызываем interact()
		# НО только если у объекта ЕСТЬ метод interact (защита от вылета)
		if body.is_in_group("desk") and body.has_method("interact"):
			body.interact()
			return
