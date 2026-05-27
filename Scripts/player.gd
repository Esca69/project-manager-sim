extends CharacterBody2D

const SPEED = 300.0

const ZOOM_STEP = 0.1
const ZOOM_MIN = 0.6
const ZOOM_MAX = 1.6
const ZOOM_SMOOTH_SPEED = 8.0

const LEAN_ANGLE = 0.12
const LEAN_SPEED = 10.0
const SHADOW_LEAN_STRETCH_FACTOR = 1.2
const SHADOW_LEAN_SHIFT_DISTANCE = 12.0

# === МОТИВАЦИЯ ===
const MOTIVATE_RADIUS = 350.0
const MOTIVATE_BONUS = 0.20
const MOTIVATE_DURATION_MINUTES = 120
const MOTIVATE_COOLDOWN_MINUTES = 480
var _motivate_cooldown_left: float = 0.0

# === ЗАПРЕТ ТУАЛЕТА ===
const NO_TOILET_RADIUS = 350.0
const NO_TOILET_DURATION_MINUTES = 240   # 4 игровых часа
const NO_TOILET_COOLDOWN_MINUTES = 480   # 8 игровых часов перезарядки
var _no_toilet_cooldown_left: float = 0.0

# === РАБОТА — КАЙФ ===
const WORK_FUN_RADIUS = 350.0
const WORK_FUN_MOOD_BONUS = 10.0
const WORK_FUN_DURATION_MINUTES = 120
const WORK_FUN_COOLDOWN_MINUTES = 480
var _work_fun_cooldown_left: float = 0.0

@onready var interaction_zone = $InteractionZone
@onready var camera = $Camera2D
@onready var body_sprite = $Sprite2D
@onready var head_sprite = $Sprite2D/Head2
@onready var shadow_sprite = $Shadow

var target_zoom: Vector2 = Vector2.ONE
var last_move_velocity: Vector2 = Vector2.ZERO

var _shadow_base_pos: Vector2 = Vector2.ZERO
var _shadow_base_scale: Vector2 = Vector2.ONE

# === СВОБОДНАЯ КАМЕРА ===
var _free_camera_mode: bool = false
var _free_camera_offset: Vector2 = Vector2.ZERO
var _free_camera_returning: bool = false  # Камера возвращается к игроку
const FREE_CAMERA_BASE_SPEED: float = 450.0
const FREE_CAMERA_RETURN_SPEED: float = 5.0  # Скорость lerp при возврате
const FREE_CAMERA_RETURN_THRESHOLD: float = 1.0  # Порог длины смещения для завершения возврата
const FREE_CAMERA_MIN_TIME_SCALE: float = 0.001  # Защита от деления на ноль при нулевом time_scale

# Принудительно сбрасывает состояние свободной камеры. Вызывается перед снятием паузы/ночной промоткой.
func force_reset_camera():
	_free_camera_mode = false
	_free_camera_returning = false
	_free_camera_offset = Vector2.ZERO
	camera.position = Vector2.ZERO
	camera.reset_smoothing()
	var hud_ref = get_tree().get_first_node_in_group("ui")
	if hud_ref and hud_ref.has_method("hide_free_camera_hint"):
		hud_ref.hide_free_camera_hint()

# Границы офиса для ограничения камеры.
# Вычислены из office.tscn: NavigationPolygon outlines покрывают область примерно от (-350, -1200) до (3350, 900).
# Используем эти значения с небольшим запасом.
const OFFICE_BOUNDS: Rect2 = Rect2(-400, -1200, 3800, 2200)
# Это означает: X от -400 до 3400, Y от -1200 до 1000

# --- ПОДСКАЗКА ВЗАИМОДЕЙСТВИЯ [E] ---
var _interact_hint: PanelContainer = null
var _interact_hint_label: Label = null
var _current_hint_target = null

# --- ПРОГРЕСС-БАР ОБСУЖДЕНИЯ ---
var _discuss_bar_container: PanelContainer = null
var _discuss_progress_bar: ProgressBar = null
var _discuss_label: Label = null
var _discuss_timer_label: Label = null
var _discuss_bar_attached: bool = false

# --- КНОПКА МОТИВАЦИИ НА HUD ---
var _motivate_btn: Button = null
var _motivate_cooldown_label: Label = null
var _motivate_container: VBoxContainer = null

# --- КНОПКА ЗАПРЕТА ТУАЛЕТА НА HUD ---
var _no_toilet_btn: Button = null
var _no_toilet_cooldown_label: Label = null
var _no_toilet_container: VBoxContainer = null

# --- КНОПКА РАБОТА-КАЙФ НА HUD ---
var _work_fun_btn: Button = null
var _work_fun_cooldown_label: Label = null
var _work_fun_container: VBoxContainer = null

# === КОЛЬЦО АУРЫ PM ===
var _aura_ring_cooldown: float = 0.0  # Чтобы не спамить кольцами

# === ВОЛОСЫ ===
var hair_sprite: Sprite2D = null

func _ready():
	add_to_group("player")
	process_mode = Node.PROCESS_MODE_ALWAYS
	target_zoom = camera.zoom
	if shadow_sprite:
		_shadow_base_pos = shadow_sprite.position
		_shadow_base_scale = shadow_sprite.scale
	_create_interact_hint()
	_create_discuss_bar()

	# Применяем внешность из PMData
	update_visuals()

	# === ПРИМЕНЯЕМ ОБЪЕМНЫЙ СВЕТ И ТЕНЬ К ТЕЛУ ===
	_apply_volume_materials()

	# Подключаем тики времени для кулдаунов
	GameTime.time_tick.connect(_on_time_tick)
	GameTime.night_skip_finished.connect(_on_night_skip_finished)

	# Подписываемся на прокачку навыков — чтобы кнопки появлялись сразу
	PMData.skill_unlocked.connect(_on_pm_skill_unlocked)

	call_deferred("_create_motivate_button")
	call_deferred("_create_no_toilet_button")
	call_deferred("_create_work_fun_button")

func update_visuals():
	var gender = PMData.appearance_gender
	var body_type = PMData.appearance_body_type
	var skin_color = PMData.appearance_skin_color
	var hair_type = PMData.appearance_hair_type
	var hair_color = PMData.appearance_hair_color

	# --- Тело ---
	var body_path: String = VisualGlobals.DEFAULT_BODY_PATH
	if body_type == "default":
		body_path = VisualGlobals.DEFAULT_BODY_PATH
	elif gender == "male" and VisualGlobals.MALE_BODY_PATHS.has(body_type):
		body_path = VisualGlobals.MALE_BODY_PATHS[body_type]
	elif gender == "female" and VisualGlobals.FEMALE_BODY_PATHS.has(body_type):
		body_path = VisualGlobals.FEMALE_BODY_PATHS[body_type]

	if body_sprite:
		body_sprite.texture = load(body_path)
		body_sprite.self_modulate = PMData.appearance_clothing_color

	# --- Голова (цвет кожи) ---
	if head_sprite:
		head_sprite.self_modulate = skin_color

	# --- Волосы ---
	if hair_type < 0:
		if is_instance_valid(hair_sprite):
			hair_sprite.queue_free()
			hair_sprite = null
	else:
		var hair_paths: Array[String] = VisualGlobals.MALE_HAIR_PATHS if gender == "male" else VisualGlobals.FEMALE_HAIR_PATHS
		var safe_idx = clamp(hair_type, 0, hair_paths.size() - 1)
		var hair_path = hair_paths[safe_idx]

		if not is_instance_valid(hair_sprite):
			hair_sprite = Sprite2D.new()
			hair_sprite.name = "HairSprite"
			if head_sprite:
				head_sprite.add_child(hair_sprite)
			else:
				body_sprite.add_child(hair_sprite)

		hair_sprite.texture = load(hair_path)
		hair_sprite.self_modulate = hair_color
		# Head2 uses offset (0, -65), so hair position must account for that
		var head_offset_y = head_sprite.offset.y if head_sprite else 0.0
		hair_sprite.position = Vector2(VisualGlobals.HAIR_OFFSET_X, head_offset_y + VisualGlobals.HAIR_OFFSET_Y)
		hair_sprite.z_index = 0

func _on_pm_skill_unlocked(_skill_id: String):
	_update_motivate_btn()
	_update_no_toilet_btn()
	_update_work_fun_btn()

func _create_interact_hint():
	_interact_hint = PanelContainer.new()

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.17254902, 0.30980393, 0.5686275, 1)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0, 0, 0, 1)
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
	_interact_hint.z_index = 80

	call_deferred("_attach_hint_to_hud")

# === СОЗДАНИЕ ПРОГРЕСС-БАРА ОБСУЖДЕНИЯ ===
func _create_discuss_bar():
	_discuss_bar_container = PanelContainer.new()
	_discuss_bar_container.visible = false
	_discuss_bar_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_discuss_bar_container.z_index = 80
	_discuss_bar_container.custom_minimum_size = Vector2(110, 0)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(1, 1, 1, 0.92)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.content_margin_left = 8
	panel_style.content_margin_right = 8
	panel_style.content_margin_top = 5
	panel_style.content_margin_bottom = 5
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.17254902, 0.30980393, 0.5686275, 0.6)
	panel_style.shadow_color = Color(0, 0, 0, 0.15)
	panel_style.shadow_size = 3
	_discuss_bar_container.add_theme_stylebox_override("panel", panel_style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	_discuss_bar_container.add_child(vbox)

	_discuss_label = Label.new()
	_discuss_label.text = tr("PLAYER_DISCUSS_TITLE")
	_discuss_label.add_theme_color_override("font_color", Color(0.17254902, 0.30980393, 0.5686275, 1))
	_discuss_label.add_theme_font_size_override("font_size", 11)
	_discuss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme: UITheme.apply_font(_discuss_label, "semibold")
	vbox.add_child(_discuss_label)

	_discuss_timer_label = Label.new()
	_discuss_timer_label.text = "🤝 4:00"
	_discuss_timer_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5, 1))
	_discuss_timer_label.add_theme_font_size_override("font_size", 10)
	_discuss_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme: UITheme.apply_font(_discuss_timer_label, "regular")
	vbox.add_child(_discuss_timer_label)

	_discuss_progress_bar = ProgressBar.new()
	_discuss_progress_bar.custom_minimum_size = Vector2(90, 8)
	_discuss_progress_bar.max_value = 100
	_discuss_progress_bar.value = 0
	_discuss_progress_bar.show_percentage = false

	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.85, 0.85, 0.85, 1)
	bg.corner_radius_top_left = 4
	bg.corner_radius_top_right = 4
	bg.corner_radius_bottom_right = 4
	bg.corner_radius_bottom_left = 4
	_discuss_progress_bar.add_theme_stylebox_override("background", bg)

	var fill = StyleBoxFlat.new()
	fill.bg_color = Color(0.17254902, 0.30980393, 0.5686275, 1)
	fill.corner_radius_top_left = 4
	fill.corner_radius_top_right = 4
	fill.corner_radius_bottom_right = 4
	fill.corner_radius_bottom_left = 4
	_discuss_progress_bar.add_theme_stylebox_override("fill", fill)

	vbox.add_child(_discuss_progress_bar)

	call_deferred("_attach_discuss_bar_to_hud")

func _attach_hint_to_hud():
	var hud = get_tree().get_first_node_in_group("ui")
	if hud:
		hud.add_child(_interact_hint)
	else:
		add_child(_interact_hint)

func _attach_discuss_bar_to_hud():
	var hud = get_tree().get_first_node_in_group("ui")
	if hud:
		hud.add_child(_discuss_bar_container)
	else:
		add_child(_discuss_bar_container)
	_discuss_bar_attached = true

# --- Проверка: открыто ли меню в HUD ---
func _is_ui_blocking() -> bool:
	var hud = get_tree().get_first_node_in_group("ui")
	if hud and hud.has_method("is_any_menu_open"):
		return hud.is_any_menu_open()
	return false

func _physics_process(delta):
	if GameTime.is_night_skip:
		# UNCONDITIONALLY reset everything every frame during night skip
		_free_camera_mode = false
		_free_camera_returning = false
		_free_camera_offset = Vector2.ZERO
		camera.position = Vector2.ZERO
		velocity = Vector2.ZERO
		last_move_velocity = velocity
		move_and_slide()
		_hide_interact_hint()
		var hud_ref = get_tree().get_first_node_in_group("ui")
		if hud_ref and hud_ref.has_method("hide_free_camera_hint"):
			hud_ref.hide_free_camera_hint()
		return

	# === ПРОВЕРКА LONG ACTION ===
	var hud = get_tree().get_first_node_in_group("ui")
	var long_action = hud and hud.has_method("is_long_action_active") and hud.is_long_action_active()

	# === СВОБОДНАЯ КАМЕРА ПРИ ПАУЗЕ ===
	if GameTime.is_game_paused and not long_action:
		if _is_ui_blocking():
			velocity = Vector2.ZERO
			last_move_velocity = velocity
			move_and_slide()
			return

		if not _free_camera_mode:
			_free_camera_mode = true
			_free_camera_returning = false
			_free_camera_offset = Vector2.ZERO
			_hide_interact_hint()
			if hud and hud.has_method("show_free_camera_hint"):
				hud.show_free_camera_hint()
		else:
			# Если камера возвращалась (после long_action) — останавливаем возврат
			_free_camera_returning = false

		var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		var zoom_factor = 1.0 / camera.zoom.x
		_free_camera_offset += direction * FREE_CAMERA_BASE_SPEED * zoom_factor * delta

		var cam_global = global_position + _free_camera_offset
		cam_global.x = clamp(cam_global.x, OFFICE_BOUNDS.position.x, OFFICE_BOUNDS.position.x + OFFICE_BOUNDS.size.x)
		cam_global.y = clamp(cam_global.y, OFFICE_BOUNDS.position.y, OFFICE_BOUNDS.position.y + OFFICE_BOUNDS.size.y)
		_free_camera_offset = cam_global - global_position
		camera.position = _free_camera_offset

		velocity = Vector2.ZERO
		last_move_velocity = velocity
		move_and_slide()
		return

	# === РЕЖИМ СВОБОДНОЙ КАМЕРЫ ===
	if long_action:
		if not _free_camera_mode:
			# Вход в режим свободной камеры
			_free_camera_mode = true
			_free_camera_returning = false
			_free_camera_offset = Vector2.ZERO
			_hide_interact_hint()
			# Показать индикатор
			if hud and hud.has_method("show_free_camera_hint"):
				hud.show_free_camera_hint()
		else:
			# Если камера возвращалась (переход из паузы) — останавливаем возврат
			_free_camera_returning = false

		# Если открыто UI-меню — не двигаем камеру, стоим
		if _is_ui_blocking():
			velocity = Vector2.ZERO
			last_move_velocity = velocity
			move_and_slide()
			return

		# Движение камеры (НЕ персонажа)
		var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		var zoom_factor = 1.0 / camera.zoom.x
		# Делим на Engine.time_scale чтобы скорость камеры была одинаковой при 1x/2x/5x
		var effective_delta = delta / maxf(Engine.time_scale, FREE_CAMERA_MIN_TIME_SCALE)
		_free_camera_offset += direction * FREE_CAMERA_BASE_SPEED * zoom_factor * effective_delta

		# Clamping к границам офиса
		var cam_global = global_position + _free_camera_offset
		cam_global.x = clamp(cam_global.x, OFFICE_BOUNDS.position.x, OFFICE_BOUNDS.position.x + OFFICE_BOUNDS.size.x)
		cam_global.y = clamp(cam_global.y, OFFICE_BOUNDS.position.y, OFFICE_BOUNDS.position.y + OFFICE_BOUNDS.size.y)
		_free_camera_offset = cam_global - global_position

		camera.position = _free_camera_offset

		# Персонаж стоит на месте
		velocity = Vector2.ZERO
		last_move_velocity = velocity
		move_and_slide()
		return

	# === ВОЗВРАТ КАМЕРЫ (long action завершился, камера ещё не вернулась) ===
	if _free_camera_mode:
		if not _free_camera_returning:
			_free_camera_returning = true
			# Скрыть индикатор
			if hud and hud.has_method("hide_free_camera_hint"):
				hud.hide_free_camera_hint()

		# Делим на Engine.time_scale чтобы скорость возврата была одинаковой
		var effective_delta = delta / maxf(Engine.time_scale, FREE_CAMERA_MIN_TIME_SCALE)
		_free_camera_offset = _free_camera_offset.lerp(Vector2.ZERO, FREE_CAMERA_RETURN_SPEED * effective_delta)
		camera.position = _free_camera_offset

		if _free_camera_offset.length() < FREE_CAMERA_RETURN_THRESHOLD:
			_free_camera_offset = Vector2.ZERO
			camera.position = Vector2.ZERO
			_free_camera_mode = false
			_free_camera_returning = false

		# Персонаж стоит пока камера возвращается
		velocity = Vector2.ZERO
		last_move_velocity = velocity
		move_and_slide()
		return

	# === ОБЫЧНЫЙ РЕЖИМ (существующий код без изменений) ===
	if _is_ui_blocking():
		velocity = Vector2.ZERO
		last_move_velocity = velocity
		move_and_slide()
		_hide_interact_hint()
		return

	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if direction:
		velocity = direction * SPEED * (1.0 + PMData.get_movement_bonus())
	else:
		velocity = Vector2.ZERO
	last_move_velocity = velocity
	move_and_slide()

	var target_lean = 0.0
	if direction.x > 0.1:
		target_lean = LEAN_ANGLE
	elif direction.x < -0.1:
		target_lean = -LEAN_ANGLE

	body_sprite.rotation = lerp(body_sprite.rotation, target_lean, LEAN_SPEED * delta)
	head_sprite.rotation = lerp(head_sprite.rotation, target_lean * 0.6, LEAN_SPEED * delta)

	if shadow_sprite:
		var lean_amount = body_sprite.rotation
		var target_scale_x = _shadow_base_scale.x * (1.0 + abs(lean_amount) * SHADOW_LEAN_STRETCH_FACTOR)
		var target_pos_x = _shadow_base_pos.x + lean_amount * SHADOW_LEAN_SHIFT_DISTANCE
		shadow_sprite.scale.x = lerp(shadow_sprite.scale.x, target_scale_x, LEAN_SPEED * delta)
		shadow_sprite.position.x = lerp(shadow_sprite.position.x, target_pos_x, LEAN_SPEED * delta)

	_update_interact_hint()

	if Input.is_action_just_pressed("interact"):
		interact()

	# === АКТИВАЦИЯ МОТИВАЦИИ ПО Q ===
	if Input.is_action_just_pressed("motivate"):
		_activate_motivate()

	# === АКТИВАЦИЯ ЗАПРЕТА ТУАЛЕТА ПО R ===
	if Input.is_action_just_pressed("no_toilet"):
		_activate_no_toilet()

	# === АКТИВАЦИЯ РАБОТА-КАЙФ ПО T ===
	if Input.is_action_just_pressed("work_is_fun"):
		_activate_work_fun()

func _process(delta):
	camera.zoom = camera.zoom.lerp(target_zoom, min(1.0, ZOOM_SMOOTH_SPEED * delta))
	_update_discuss_bar_position()

	# Кулдаун кольца ауры
	if _aura_ring_cooldown > 0:
		_aura_ring_cooldown -= delta

func _unhandled_input(event):
	if GameTime.is_night_skip:
		return

	# Разрешаем зум во время свободной камеры
	if _free_camera_mode:
		if _is_ui_blocking():
			return  # Блокируем ВСЕ инпуты камеры когда UI открыт
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_set_zoom(ZOOM_STEP)
				return
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_set_zoom(-ZOOM_STEP)
				return
		return  # Все остальные инпуты блокируем в свободном режиме

	if _is_ui_blocking():
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(ZOOM_STEP)
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(-ZOOM_STEP)
			return

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

	_current_hint_target = target

	_interact_hint.visible = true

	var target_world_pos: Vector2
	# NPC с рейзом — хинт выше (над иконкой ❗)
	if target.is_in_group("npc"):
		target_world_pos = target.global_position + Vector2(0, -100)
	elif target is Node2D:
		target_world_pos = target.global_position + Vector2(0, -60)
	else:
		target_world_pos = target.global_position + Vector2(0, -60)

	var screen_pos = _world_to_screen(target_world_pos)

	var hint_size = _interact_hint.size
	_interact_hint.global_position = Vector2(
		screen_pos.x - hint_size.x / 2.0,
		screen_pos.y - hint_size.y - 100
	)

func _hide_interact_hint():
	if _interact_hint:
		_interact_hint.visible = false
	_current_hint_target = null


# =========================================================================
# === ИСПРАВЛЕННАЯ ЖЕЛЕЗОБЕТОННАЯ ЛОГИКА ПОИСКА (БЕЗ СОТРУДНИКОВ) ===
# =========================================================================

func _get_nearest_interactable():
	var bodies = interaction_zone.get_overlapping_bodies()

	# === RAISES: Приоритет — NPC с активным запросом рейза, который НЕ работает ===
	for body in bodies:
		if body == self:
			continue
		if body.is_in_group("npc") and body.has_method("can_discuss_raise") and body.can_discuss_raise():
			return body

	# === PM INTERACTION: Второй приоритет — NPC с которым можно взаимодействовать ===
	var nearest_npc = null
	var nearest_npc_dist = INF
	for body in bodies:
		if body == self:
			continue
		if body.is_in_group("npc") and body.has_method("can_pm_interact") and body.can_pm_interact():
			var dist = global_position.distance_to(body.global_position)
			if dist < nearest_npc_dist:
				nearest_npc_dist = dist
				nearest_npc = body
	if nearest_npc:
		return nearest_npc

	for body in bodies:
		if body == self:
			continue

		# 1. Если это сотрудник (группа npc) — жестко игнорируем!
		if body.is_in_group("npc"):
			continue

		# 2. Оставляем взаимодействие ТОЛЬКО для столов (hr_desk, boss_desk и тд)
		if body.is_in_group("desk") and body.has_method("interact"):
			# Босс — показываем E только когда он IN_OFFICE
			if body.is_in_group("boss_npc"):
				if body.current_state != body.BossState.IN_OFFICE:
					continue
			return body

	return null

func _world_to_screen(world_pos: Vector2) -> Vector2:
	var canvas_transform = get_viewport().get_canvas_transform()
	return canvas_transform * world_pos

func interact():
	var bodies = interaction_zone.get_overlapping_bodies()

	# === RAISES: Приоритет — NPC с рейзом ===
	for body in bodies:
		if body == self:
			continue
		if body.is_in_group("npc") and body.has_method("can_discuss_raise") and body.can_discuss_raise():
			body.open_raise_dialog()
			return

	# === PM INTERACTION: NPC без рейза ===
	var nearest_npc = null
	var nearest_npc_dist = INF
	for body in bodies:
		if body == self:
			continue
		if body.is_in_group("npc") and body.has_method("can_pm_interact") and body.can_pm_interact():
			var dist = global_position.distance_to(body.global_position)
			if dist < nearest_npc_dist:
				nearest_npc_dist = dist
				nearest_npc = body
	if nearest_npc:
		_open_employee_interaction(nearest_npc)
		return

	for body in bodies:
		if body == self:
			continue

		# 1. Если это сотрудник — игнорируем нажатие Е
		if body.is_in_group("npc"):
			continue

		# 2. Вызываем функцию стола
		if body.is_in_group("desk") and body.has_method("interact"):
			# Босс — вызываем interact только когда он IN_OFFICE
			if body.is_in_group("boss_npc"):
				if body.current_state != body.BossState.IN_OFFICE:
					continue
			AudioManager.play_sfx("interact")
			body.interact()
			return

func _open_employee_interaction(npc_node):
	var hud = get_tree().get_first_node_in_group("ui")
	if hud:
		var panel = hud.get_node_or_null("EmployeeInteractionPanel")
		if panel:
			AudioManager.play_sfx("interact")
			panel.open_for_employee(npc_node)


# === ПРОГРЕСС-БАР ОБСУЖДЕНИЯ: ПУБЛИЧНЫЙ API ДЛЯ HUD ===

func show_discuss_bar(total_minutes: float):
	_discuss_progress_bar.max_value = total_minutes
	_discuss_progress_bar.value = 0
	_discuss_label.text = tr("PLAYER_DISCUSS_TITLE")
	var hours = int(total_minutes) / 60
	var mins = int(total_minutes) % 60
	_discuss_timer_label.text = "🤝 %d:%02d" % [hours, mins]
	_discuss_bar_container.visible = true
	_update_discuss_bar_position()

func update_discuss_bar(elapsed: float, minutes_remaining: float):
	_discuss_progress_bar.value = elapsed
	var hours_left = int(minutes_remaining) / 60
	var mins_left = int(minutes_remaining) % 60
	_discuss_timer_label.text = "🤝 %d:%02d" % [hours_left, mins_left]

func hide_discuss_bar():
	_discuss_bar_container.visible = false

func _update_discuss_bar_position():
	if _discuss_bar_container == null:
		return
	if not _discuss_bar_container.visible:
		return
	var world_pos = global_position + Vector2(0, -115)
	var screen_pos = _world_to_screen(world_pos)
	var bar_size = _discuss_bar_container.size
	if bar_size.x < 1.0:
		bar_size = _discuss_bar_container.custom_minimum_size
	var target_x = screen_pos.x - bar_size.x / 2.0
	var target_y = screen_pos.y - bar_size.y

	# Clamp: не выше TopBar (~50px) и не ниже BottomBar
	var vp_size = get_viewport().get_visible_rect().size
	var top_margin = 50.0    # высота TopBar
	var bottom_margin = 60.0 # высота BottomBar
	target_y = clamp(target_y, top_margin, vp_size.y - bottom_margin - bar_size.y)
	target_x = clamp(target_x, 0.0, vp_size.x - bar_size.x)

	_discuss_bar_container.global_position = Vector2(target_x, target_y)

# ============================
# === МОТИВАЦИЯ: ЛОГИКА ===
# ============================

func _activate_motivate():
	if _free_camera_mode:
		return
	if not PMData.has_skill("motivate"):
		return

	if _motivate_cooldown_left > 0:
		print("🔥 Мотивация на перезарядке! Осталось %d мин." % int(_motivate_cooldown_left))
		return

	var hud = get_tree().get_first_node_in_group("ui")
	if hud and hud.has_method("is_pm_busy") and hud.is_pm_busy():
		print("🔥 PM занят, нельзя мотивировать!")
		return

	AudioManager.play_sfx("bark")

	var affected_count = 0
	for npc in get_tree().get_nodes_in_group("npc"):
		if not npc.visible:
			continue
		if not npc.data:
			continue
		var dist = global_position.distance_to(npc.global_position)
		if dist <= MOTIVATE_RADIUS:
			npc.apply_motivation(MOTIVATE_BONUS, MOTIVATE_DURATION_MINUTES)
			affected_count += 1

	_motivate_cooldown_left = MOTIVATE_COOLDOWN_MINUTES
	_update_motivate_btn()

	_show_motivate_wave()
	_show_radius_circle(MOTIVATE_RADIUS, Color(0.9, 0.4, 0.1, 0.6))

	if affected_count > 0:
		print("🔥 Мотивация активирована! Затронуто: %d сотрудников" % affected_count)
	else:
		print("🔥 Мотивация активирована! Никого рядом не оказалось.")

func _on_night_skip_finished():
	velocity = Vector2.ZERO
	force_reset_camera()
	# Safety: clamp player position to office bounds
	global_position.x = clamp(global_position.x, OFFICE_BOUNDS.position.x, OFFICE_BOUNDS.position.x + OFFICE_BOUNDS.size.x)
	global_position.y = clamp(global_position.y, OFFICE_BOUNDS.position.y, OFFICE_BOUNDS.position.y + OFFICE_BOUNDS.size.y)

func _on_time_tick(h, m):
	# Страховочный сброс камеры утром
	if h == 8 and m == 1:
		if _free_camera_mode or camera.position != Vector2.ZERO:
			force_reset_camera()
	if _motivate_cooldown_left > 0:
		_motivate_cooldown_left -= 1.0
		_update_motivate_btn()
		if _motivate_cooldown_left <= 0:
			_motivate_cooldown_left = 0
			_update_motivate_btn()
			print("🔥 Мотивация снова доступна!")
	if _no_toilet_cooldown_left > 0:
		_no_toilet_cooldown_left -= 1.0
		_update_no_toilet_btn()
		if _no_toilet_cooldown_left <= 0:
			_no_toilet_cooldown_left = 0
			_update_no_toilet_btn()
			print("🚽 Запрет туалета снова доступен!")
	if _work_fun_cooldown_left > 0:
		_work_fun_cooldown_left -= 1.0
		_update_work_fun_btn()
		if _work_fun_cooldown_left <= 0:
			_work_fun_cooldown_left = 0
			_update_work_fun_btn()
			print("🎉 Работа-кайф снова доступна!")

func _show_motivate_wave():
	var bubble = Node2D.new()
	add_child(bubble)
	bubble.position = Vector2(0, -210)
	bubble.z_index = 100

	var panel = Panel.new()
	bubble.add_child(panel)
	panel.custom_minimum_size = Vector2(72, 72)
	panel.size = Vector2(72, 72)
	panel.position = Vector2(-36, -36)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.95, 0.9, 1.0)
	style.border_width_bottom = 2
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color(0.9, 0.4, 0.1, 1.0)
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	panel.add_theme_stylebox_override("panel", style)

	var label = Label.new()
	panel.add_child(label)
	label.custom_minimum_size = Vector2(72, 72)
	label.size = Vector2(72, 72)
	label.position = Vector2.ZERO
	label.text = "🔥"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var label_settings = UITheme.make_label_settings(42)
	label.label_settings = label_settings

	bubble.scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(bubble, "scale", Vector2(1.3, 1.3), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(bubble, "scale", Vector2.ONE, 0.2)
	tween.tween_interval(2.0)
	tween.tween_property(bubble, "modulate:a", 0.0, 0.5)
	tween.parallel().tween_property(bubble, "position:y", bubble.position.y - 30, 0.5)
	tween.tween_callback(bubble.queue_free)

# ====================================
# === ЗАПРЕТ ТУАЛЕТА: ЛОГИКА ===
# ====================================

func _activate_no_toilet():
	if _free_camera_mode:
		return
	if not PMData.has_skill("no_toilet"):
		return

	if _no_toilet_cooldown_left > 0:
		print("🚽 Запрет туалета на перезарядке! Осталось %d мин." % int(_no_toilet_cooldown_left))
		return

	var hud = get_tree().get_first_node_in_group("ui")
	if hud and hud.has_method("is_pm_busy") and hud.is_pm_busy():
		print("🚽 PM занят, нельзя запретить туалет!")
		return

	AudioManager.play_sfx("closedoor")

	var affected_count = 0
	for npc in get_tree().get_nodes_in_group("npc"):
		if not npc.visible:
			continue
		if not npc.data:
			continue
		npc.apply_toilet_ban(NO_TOILET_DURATION_MINUTES)
		affected_count += 1

	_no_toilet_cooldown_left = NO_TOILET_COOLDOWN_MINUTES
	_update_no_toilet_btn()

	_show_no_toilet_wave()
	

	if affected_count > 0:
		print("🚽 Запрет туалета активирован! Затронуто: %d сотрудников" % affected_count)
	else:
		print("🚽 Запрет туалета активирован! Никого рядом не оказалось.")

func _show_no_toilet_wave():
	var bubble = Node2D.new()
	add_child(bubble)
	bubble.position = Vector2(0, -210)
	bubble.z_index = 100

	var panel = Panel.new()
	bubble.add_child(panel)
	panel.custom_minimum_size = Vector2(72, 72)
	panel.size = Vector2(72, 72)
	panel.position = Vector2(-36, -36)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.92, 0.92, 1.0)
	style.border_width_bottom = 2
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color(0.6, 0.2, 0.2, 1.0)
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	panel.add_theme_stylebox_override("panel", style)

	var label = Label.new()
	panel.add_child(label)
	label.custom_minimum_size = Vector2(72, 72)
	label.size = Vector2(72, 72)
	label.position = Vector2.ZERO
	label.text = "🚫"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var label_settings = UITheme.make_label_settings(42)
	label.label_settings = label_settings

	bubble.scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(bubble, "scale", Vector2(1.3, 1.3), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(bubble, "scale", Vector2.ONE, 0.2)
	tween.tween_interval(2.0)
	tween.tween_property(bubble, "modulate:a", 0.0, 0.5)
	tween.parallel().tween_property(bubble, "position:y", bubble.position.y - 30, 0.5)
	tween.tween_callback(bubble.queue_free)

# === ОБЩАЯ АНИМАЦИЯ КРУГА РАДИУСА ===
func _show_radius_circle(radius: float, color: Color):
	var ring = _MotivateRing.new()
	ring.radius = radius
	ring.ring_color = color
	ring.ring_width = 3.0
	ring.z_index = 40
	add_child(ring)

	ring.scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(ring, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_interval(2.0)
	tween.tween_property(ring, "modulate:a", 0.0, 0.7)
	tween.tween_callback(ring.queue_free)

# === АУРА PM: Показать кольцо (вызывается из employee.gd) ===
func show_aura_ring():
	# Не показываем чаще, чем раз в 5 секунд реального времени
	if _aura_ring_cooldown > 0:
		return
	_aura_ring_cooldown = 5.0
	
	var ring = _MotivateRing.new()
	ring.radius = 250.0  # PM_AURA_RADIUS
	ring.ring_color = Color(0.2, 0.6, 0.9, 0.5)  # Синеватый, полупрозрачный
	ring.ring_width = 2.0
	ring.z_index = 40
	add_child(ring)
	
	ring.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(ring, "modulate:a", 0.6, 0.15)
	tween.tween_interval(0.7)
	tween.tween_property(ring, "modulate:a", 0.0, 0.5)
	tween.tween_callback(ring.queue_free)

# Вспомогательный класс для рисования кольца через _draw
class _MotivateRing extends Node2D:
	var radius: float = 600.0
	var ring_color: Color = Color(0.9, 0.4, 0.1, 0.6)
	var ring_width: float = 3.0

	func _draw():
		draw_arc(Vector2.ZERO, radius, 0, TAU, 128, ring_color, ring_width, true)

# === КНОПКА МОТИВАЦИИ НА HUD ===
func _create_motivate_button():
	var hud = get_tree().get_first_node_in_group("ui")
	if not hud:
		return

	_motivate_container = VBoxContainer.new()
	_motivate_container.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_motivate_container.position = Vector2(20, -220)
	_motivate_container.add_theme_constant_override("separation", 2)
	hud.add_child(_motivate_container)

	_motivate_btn = Button.new()
	_motivate_btn.text = tr("SKILL_MOTIVATE_NAME") + " [Q]"
	_motivate_btn.custom_minimum_size = Vector2(200, 40)
	_motivate_btn.pressed.connect(_activate_motivate)

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.9, 0.4, 0.1, 1)
	btn_style.corner_radius_top_left = 10
	btn_style.corner_radius_top_right = 10
	btn_style.corner_radius_bottom_right = 10
	btn_style.corner_radius_bottom_left = 10
	btn_style.content_margin_left = 12
	btn_style.content_margin_right = 12
	btn_style.content_margin_top = 6
	btn_style.content_margin_bottom = 6
	_motivate_btn.add_theme_stylebox_override("normal", btn_style)

	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = Color(1.0, 0.5, 0.15, 1)
	_motivate_btn.add_theme_stylebox_override("hover", btn_hover)

	var btn_disabled = btn_style.duplicate()
	btn_disabled.bg_color = Color(0.5, 0.5, 0.5, 0.6)
	_motivate_btn.add_theme_stylebox_override("disabled", btn_disabled)

	_motivate_btn.add_theme_color_override("font_color", Color.WHITE)
	_motivate_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	_motivate_btn.add_theme_color_override("font_disabled_color", Color(0.8, 0.8, 0.8, 0.6))
	_motivate_btn.add_theme_font_size_override("font_size", 14)
	if UITheme: UITheme.apply_font(_motivate_btn, "semibold")

	_motivate_container.add_child(_motivate_btn)

	_motivate_cooldown_label = Label.new()
	_motivate_cooldown_label.text = ""
	_motivate_cooldown_label.add_theme_font_size_override("font_size", 11)
	_motivate_cooldown_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
	_motivate_cooldown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme: UITheme.apply_font(_motivate_cooldown_label, "regular")
	_motivate_container.add_child(_motivate_cooldown_label)

	_update_motivate_btn()

func _update_motivate_btn():
	if _motivate_btn == null:
		return

	if not PMData.has_skill("motivate"):
		_motivate_container.visible = false
		return
	_motivate_container.visible = true

	if _motivate_cooldown_left > 0:
		_motivate_btn.disabled = true
		var hours = int(_motivate_cooldown_left) / 60
		var mins = int(_motivate_cooldown_left) % 60
		_motivate_cooldown_label.text = tr("PLAYER_COOLDOWN_FORMAT") % [hours, mins]
	else:
		_motivate_btn.disabled = false
		_motivate_cooldown_label.text = tr("PLAYER_SKILL_READY")

# === КНОПКА ЗАПРЕТА ТУАЛЕТА НА HUD ===
func _create_no_toilet_button():
	var hud = get_tree().get_first_node_in_group("ui")
	if not hud:
		return

	_no_toilet_container = VBoxContainer.new()
	_no_toilet_container.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_no_toilet_container.position = Vector2(20, -140)
	_no_toilet_container.add_theme_constant_override("separation", 2)
	hud.add_child(_no_toilet_container)

	_no_toilet_btn = Button.new()
	_no_toilet_btn.text = tr("SKILL_NO_TOILET_NAME") + " [R]"
	_no_toilet_btn.custom_minimum_size = Vector2(200, 40)
	_no_toilet_btn.pressed.connect(_activate_no_toilet)

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.6, 0.2, 0.2, 1)
	btn_style.corner_radius_top_left = 10
	btn_style.corner_radius_top_right = 10
	btn_style.corner_radius_bottom_right = 10
	btn_style.corner_radius_bottom_left = 10
	btn_style.content_margin_left = 12
	btn_style.content_margin_right = 12
	btn_style.content_margin_top = 6
	btn_style.content_margin_bottom = 6
	_no_toilet_btn.add_theme_stylebox_override("normal", btn_style)

	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = Color(0.75, 0.3, 0.3, 1)
	_no_toilet_btn.add_theme_stylebox_override("hover", btn_hover)

	var btn_disabled = btn_style.duplicate()
	btn_disabled.bg_color = Color(0.5, 0.5, 0.5, 0.6)
	_no_toilet_btn.add_theme_stylebox_override("disabled", btn_disabled)

	_no_toilet_btn.add_theme_color_override("font_color", Color.WHITE)
	_no_toilet_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	_no_toilet_btn.add_theme_color_override("font_disabled_color", Color(0.8, 0.8, 0.8, 0.6))
	_no_toilet_btn.add_theme_font_size_override("font_size", 14)
	if UITheme: UITheme.apply_font(_no_toilet_btn, "semibold")

	_no_toilet_container.add_child(_no_toilet_btn)

	_no_toilet_cooldown_label = Label.new()
	_no_toilet_cooldown_label.text = ""
	_no_toilet_cooldown_label.add_theme_font_size_override("font_size", 11)
	_no_toilet_cooldown_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
	_no_toilet_cooldown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme: UITheme.apply_font(_no_toilet_cooldown_label, "regular")
	_no_toilet_container.add_child(_no_toilet_cooldown_label)

	_update_no_toilet_btn()

func _update_no_toilet_btn():
	if _no_toilet_btn == null:
		return

	if not PMData.has_skill("no_toilet"):
		_no_toilet_container.visible = false
		return
	_no_toilet_container.visible = true

	if _no_toilet_cooldown_left > 0:
		_no_toilet_btn.disabled = true
		var hours = int(_no_toilet_cooldown_left) / 60
		var mins = int(_no_toilet_cooldown_left) % 60
		_no_toilet_cooldown_label.text = tr("PLAYER_COOLDOWN_FORMAT") % [hours, mins]
	else:
		_no_toilet_btn.disabled = false
		_no_toilet_cooldown_label.text = tr("PLAYER_SKILL_READY")

# ====================================
# === РАБОТА — КАЙФ: ЛОГИКА ===
# ====================================

func _activate_work_fun():
	if _free_camera_mode:
		return
	if not PMData.has_skill("work_is_fun"):
		return

	if _work_fun_cooldown_left > 0:
		print("🎉 Работа-кайф на перезарядке! Осталось %d мин." % int(_work_fun_cooldown_left))
		return

	var hud = get_tree().get_first_node_in_group("ui")
	if hud and hud.has_method("is_pm_busy") and hud.is_pm_busy():
		print("🎉 PM занят!")
		return

	AudioManager.play_sfx("funsound")

	var affected_count = 0
	for npc in get_tree().get_nodes_in_group("npc"):
		if not npc.visible: continue
		if not npc.data: continue
		var dist = global_position.distance_to(npc.global_position)
		if dist <= WORK_FUN_RADIUS:
			npc.apply_mood_boost(WORK_FUN_MOOD_BONUS, WORK_FUN_DURATION_MINUTES)
			affected_count += 1

	_work_fun_cooldown_left = WORK_FUN_COOLDOWN_MINUTES
	_update_work_fun_btn()
	_show_work_fun_wave()
	_show_radius_circle(WORK_FUN_RADIUS, Color(0.2, 0.8, 0.3, 0.6))

	if affected_count > 0:
		print("🎉 Работа-кайф! Затронуто: %d сотрудников" % affected_count)
	else:
		print("🎉 Работа-кайф! Никого рядом.")

func _show_work_fun_wave():
	var bubble = Node2D.new()
	add_child(bubble)
	bubble.position = Vector2(0, -210)
	bubble.z_index = 100
	var panel = Panel.new()
	bubble.add_child(panel)
	panel.size = Vector2(65, 65)
	panel.position = Vector2(-32, -32)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.2, 0.8, 0.3, 0.9)
	panel_style.corner_radius_top_left = 32
	panel_style.corner_radius_top_right = 32
	panel_style.corner_radius_bottom_right = 32
	panel_style.corner_radius_bottom_left = 32
	panel.add_theme_stylebox_override("panel", panel_style)
	var label = Label.new()
	panel.add_child(label)
	label.text = "🎉"
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BOTH
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var label_settings = UITheme.make_label_settings(42)
	label.label_settings = label_settings
	bubble.scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(bubble, "scale", Vector2(1.3, 1.3), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(bubble, "scale", Vector2.ONE, 0.2)
	tween.tween_interval(2.0)
	tween.tween_property(bubble, "modulate:a", 0.0, 0.5)
	tween.parallel().tween_property(bubble, "position:y", bubble.position.y - 30, 0.5)
	tween.tween_callback(bubble.queue_free)

# === КНОПКА РАБОТА-КАЙФ НА HUD ===
func _create_work_fun_button():
	var hud = get_tree().get_first_node_in_group("ui")
	if not hud:
		return

	_work_fun_container = VBoxContainer.new()
	_work_fun_container.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_work_fun_container.position = Vector2(20, -300)
	_work_fun_container.add_theme_constant_override("separation", 2)
	hud.add_child(_work_fun_container)

	_work_fun_btn = Button.new()
	_work_fun_btn.text = tr("SKILL_WORK_FUN_NAME") + " [T]"
	_work_fun_btn.custom_minimum_size = Vector2(200, 40)
	_work_fun_btn.pressed.connect(_activate_work_fun)

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.6, 0.25, 1)
	btn_style.corner_radius_top_left = 10
	btn_style.corner_radius_top_right = 10
	btn_style.corner_radius_bottom_right = 10
	btn_style.corner_radius_bottom_left = 10
	btn_style.content_margin_left = 12
	btn_style.content_margin_right = 12
	btn_style.content_margin_top = 6
	btn_style.content_margin_bottom = 6
	_work_fun_btn.add_theme_stylebox_override("normal", btn_style)

	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = Color(0.25, 0.7, 0.3, 1)
	_work_fun_btn.add_theme_stylebox_override("hover", btn_hover)

	var btn_disabled = btn_style.duplicate()
	btn_disabled.bg_color = Color(0.5, 0.5, 0.5, 0.6)
	_work_fun_btn.add_theme_stylebox_override("disabled", btn_disabled)

	_work_fun_btn.add_theme_color_override("font_color", Color.WHITE)
	_work_fun_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	_work_fun_btn.add_theme_color_override("font_disabled_color", Color(0.8, 0.8, 0.8, 0.6))
	_work_fun_btn.add_theme_font_size_override("font_size", 14)
	if UITheme: UITheme.apply_font(_work_fun_btn, "semibold")

	_work_fun_container.add_child(_work_fun_btn)

	_work_fun_cooldown_label = Label.new()
	_work_fun_cooldown_label.text = ""
	_work_fun_cooldown_label.add_theme_font_size_override("font_size", 11)
	_work_fun_cooldown_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
	_work_fun_cooldown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme: UITheme.apply_font(_work_fun_cooldown_label, "regular")
	_work_fun_container.add_child(_work_fun_cooldown_label)

	_update_work_fun_btn()

func _update_work_fun_btn():
	if _work_fun_btn == null:
		return

	if not PMData.has_skill("work_is_fun"):
		_work_fun_container.visible = false
		return
	_work_fun_container.visible = true

	if _work_fun_cooldown_left > 0:
		_work_fun_btn.disabled = true
		var hours = int(_work_fun_cooldown_left) / 60
		var mins = int(_work_fun_cooldown_left) % 60
		_work_fun_cooldown_label.text = tr("PLAYER_COOLDOWN_FORMAT") % [hours, mins]
	else:
		_work_fun_btn.disabled = false
		_work_fun_cooldown_label.text = tr("PLAYER_SKILL_READY")

# =================================================================
# === ИСПРАВЛЕННЫЙ ОБЪЕМНЫЙ СВЕТ И ТЕНЬ (ЧЕРЕЗ ШЕЙДЕР) ===
# =================================================================
# =================================================================
# === ОБЪЕМНЫЙ СВЕТ И ТЕНЬ (ЖЕСТКАЯ ТЕНЬ / СЕЛ-ШЕЙДИНГ) ===
# =================================================================
# =================================================================
# === ОБЪЕМНЫЙ СВЕТ И ТЕНЬ (ЖЕСТКАЯ ТЕНЬ / СЕЛ-ШЕЙДИНГ С ЗАКРУГЛЕНИЕМ) ===
# =================================================================
# =================================================================
# === ОБЪЕМНЫЙ СВЕТ И ТЕНЬ (ДИНАМИЧЕСКАЯ ТЕНЬ ПО КОНТУРУ ТЕЛА) ===
# =================================================================
func _apply_volume_materials():
	# Разрешаем отрисовку дочерних узлов без обрезки (чтобы голова была видна)
	body_sprite.clip_children = CanvasItem.CLIP_CHILDREN_DISABLED

	# Удаляем старые тестовые спрайты теней, если они остались в сцене
	for child in body_sprite.get_children():
		if child is Sprite2D and child != head_sprite:
			child.queue_free()

	# Исправленный шейдер: метод "Смещенной маски"
	var shader_code = """
	shader_type canvas_item;

	void fragment() {
		// Оригинальный пиксель тела
		vec4 c = texture(TEXTURE, UV) * COLOR;

		// ТОЛЩИНА ТЕНИ в пикселях.
		float shadow_x = 20.0; // Ширина тени слева
		float shadow_y = 20.0; // Высота тени снизу

		// ИСПРАВЛЕНИЕ ЗДЕСЬ: Смещаем координаты ВЛЕВО (-X) и ВНИЗ (+Y).
		// Это найдет именно левый и нижний контуры тела.
		vec2 offset = vec2(-shadow_x * TEXTURE_PIXEL_SIZE.x, shadow_y * TEXTURE_PIXEL_SIZE.y);
		vec2 sample_uv = UV + offset;

		// По умолчанию считаем, что если мы вылезли за пределы текстуры - там пустота (0.0)
		float shifted_alpha = 0.0; 
		
		// Читаем соседний пиксель, если он внутри картинки
		if (sample_uv.x >= 0.0 && sample_uv.x <= 1.0 && sample_uv.y >= 0.0 && sample_uv.y <= 1.0) {
			shifted_alpha = texture(TEXTURE, sample_uv).a;
		}

		// ЛОГИКА ТЕНИ:
		// Если текущий пиксель - это часть тела (c.a > 0.1)
		// А пиксель, смещенный влево-вниз - это пустота (shifted_alpha < 0.1)
		// Значит мы находимся ровно на левом или нижнем контуре!
		float is_shadow = 0.0;
		if (c.a > 0.1 && shifted_alpha < 0.1) {
			is_shadow = 1.0;
		}

		// Накладываем черный цвет с прозрачностью 10% (0.1)
		c.rgb = mix(c.rgb, vec3(0.0), 0.1 * is_shadow);

		COLOR = c;
	}
	"""

	var mat = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = shader_code
	mat.shader = shader

	# Шейдер применяется ТОЛЬКО к рубашке
	body_sprite.material = mat
