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

# --- ПОДСКАЗКА ВЗАИМОДЕЙСТВИЯ [E] ---
var _interact_hint: PanelContainer = null
var _interact_hint_label: Label = null
var _current_hint_target = null  # Объект, над которым сейчас висит подсказка

func _ready():
	target_zoom = camera.zoom
	_create_interact_hint()

func _create_interact_hint():
	_interact_hint = PanelContainer.new()
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.17254902, 0.30980393, 0.5686275, 1)  # Тёмно-синий
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	# Чёрная обводка
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0, 0, 0, 1)
	# Тень
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 4
	_interact_hint.add_theme_stylebox_override("panel", style)
	
	_interact_hint_label = Label.new()
	_interact_hint_label.text = "E"
	_interact_hint_label.add_theme_color_override("font_color", Color.WHITE)
	_interact_hint_label.add_theme_font_size_override("font_size", 28)
	_interact_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interact_hint.add_child(_interact_hint_label)
	
	_interact_hint.visible = false
	_interact_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_interact_hint.z_index = 100
	
	call_deferred("_attach_hint_to_hud")

func _attach_hint_to_hud():
	var hud = get_tree().get_first_node_in_group("ui")
	if hud:
		hud.add_child(_interact_hint)
	else:
		# Фолбэк — добавляем к себе (будет масштабироваться с камерой, но хотя бы работает)
		add_child(_interact_hint)

func _physics_process(delta):
	# --- БЛОК БЛОКИРОВКИ УПРАВЛЕНИЯ ---
	if GameTime.is_night_skip:
		velocity = Vector2.ZERO
		move_and_slide()
		_hide_interact_hint()
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

	# --- ПОДСКАЗКА [E] ---
	_update_interact_hint()

	# --- БЛОК ВЗАИМОДЕЙСТВИЯ (новый) ---
	# Если нажали кноп��у "interact" (наша E)
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

# --- ПОДСКАЗКА [E]: обновление каждый кадр ---
func _update_interact_hint():
	var target = _get_nearest_interactable()
	
	if target == null:
		_hide_interact_hint()
		return
	
	# Показываем подсказку и позиционируем над объектом
	_current_hint_target = target
	_interact_hint.visible = true
	
	# Конвертируем мировую позицию объекта в экранную
	var target_world_pos: Vector2
	if target is Node2D:
		target_world_pos = target.global_position + Vector2(0, -80)  # Смещение вверх
	else:
		target_world_pos = target.global_position + Vector2(0, -80)
	
	# Мировые координаты → экранные через камеру
	var screen_pos = _world_to_screen(target_world_pos)
	
	# Центрируем подсказку по X
	var hint_size = _interact_hint.size
	_interact_hint.global_position = Vector2(
		screen_pos.x - hint_size.x / 2.0,
		screen_pos.y - hint_size.y
	)

func _hide_interact_hint():
	_interact_hint.visible = false
	_current_hint_target = null

func _get_nearest_interactable():
	# Та же логика, что и в interact(), но без вызова — просто ищем цель
	var bodies = interaction_zone.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("npc") and "data" in body and body.data:
			return body
		if body.is_in_group("desk") and body.has_method("interact"):
			return body
	return null

func _world_to_screen(world_pos: Vector2) -> Vector2:
	# Переводим мировые координаты в экранные с учётом камеры
	var canvas_transform = get_viewport().get_canvas_transform()
	return canvas_transform * world_pos

func interact():
	var bodies = interaction_zone.get_overlapping_bodies()
	for body in bodies:
		# NPC — показываем карточку сотрудника
		if body.is_in_group("npc") and body.data:
			AudioManager.play_sfx("interact")  # 🔊 Звук при взаимодействии
			get_tree().call_group("ui", "show_employee_card", body.data)
			return
		
		# Стол или другой интерактивный объект — вызываем interact()
		# НО только если у объекта ЕСТЬ метод interact (защита от вылета)
		if body.is_in_group("desk") and body.has_method("interact"):
			AudioManager.play_sfx("interact")  # 🔊 Звук при взаимодействии
			body.interact()
			return
