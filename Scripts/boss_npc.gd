extends CharacterBody2D

# =========================================================
# === BOSS NPC — динамическое расписание ====================
# =========================================================

enum BossState { AWAY, COMING, IN_OFFICE, LEAVING }

const BOSS_SOUND_RADIUS: float = 400.0
const TUTORIAL_PROXIMITY_RADIUS: float = 260.0
const ARRIVAL_DISTANCE: float = 80.0  # Расстояние до точки, при котором считаем "дошёл"

var current_state: int = BossState.AWAY
var movement_speed: float = 100.0

# Позиция рабочего места босса (устанавливается при спавне)
var desk_position: Vector2 = Vector2.ZERO

# Расписание на сегодня
var _arrival_hour: int = -1
var _arrival_minute: int = 0
var _departure_hour: int = -1
var _departure_minute: int = 0

# Флаги
var _is_player_in_radius: bool = false
var _schedule_generated: bool = false

# Bubble, звук и визуал
var _exclamation_bubble: Node2D = null
var _boss_player: AudioStreamPlayer = null
var hair_sprite: Sprite2D = null

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var body_sprite: Sprite2D = $Visuals/Body
@onready var head_sprite: Sprite2D = $Visuals/Body/Head

func _ready():
	add_to_group("boss_desk")
	add_to_group("desk")
	add_to_group("boss_npc")
	y_sort_enabled = true

	# Устанавливаем текстуру тела босса (уже с цветом) и сбрасываем модуляцию
	if body_sprite:
		body_sprite.texture = load("res://Sprites/Office/boss_body.png")
		body_sprite.self_modulate = Color.WHITE
	
	if head_sprite:
		head_sprite.self_modulate = Color("#fff0e1")

	# Добавляем седую причёску
	_create_hair_sprite()

	# ПРИМЕНЯЕМ ШЕЙДЕР ТЕНИ (вызов функции)
	

	# Строим exclamation bubble
	_build_exclamation_mark()

	# Настраиваем плеер для звука босса
	_boss_player = AudioStreamPlayer.new()
	_boss_player.stream = load("res://Sound/bosssound.mp3")
	_boss_player.bus = "Master"
	add_child(_boss_player)

	# Начальное состояние: босс не в офисе
	visible = false
	$CollisionShape2D.disabled = true

	# Подключаем сигналы времени (deferred, чтобы autoload'ы были готовы)
	call_deferred("_connect_signals")

func _create_hair_sprite():
	if hair_sprite and is_instance_valid(hair_sprite):
		hair_sprite.queue_free()

	hair_sprite = Sprite2D.new()
	hair_sprite.name = "Hair"
	hair_sprite.position = Vector2(0.0, -20.0) # Смещение как в employee.gd
	hair_sprite.texture = load("res://Sprites/hairs/man_hair3.png")
	
	# Красим волосы в седой цвет
	hair_sprite.self_modulate = Color(0.8, 0.8, 0.8, 1.0)

	if head_sprite:
		head_sprite.add_child(hair_sprite)

func _connect_signals():
	GameTime.time_tick.connect(_on_time_tick)
	GameTime.day_started.connect(_on_day_started)
	GameTime.night_skip_started.connect(_on_night_skip_started)
	GameTime.night_skip_finished.connect(_on_night_skip_finished)

	# Генерируем расписание для текущего дня
	call_deferred("_generate_schedule_for_current_day")

func _generate_schedule_for_current_day():
	_generate_schedule(GameTime.day)
	# Проверяем: может быть, босс уже должен быть в офисе прямо сейчас?
	_sync_state_to_current_time()

# =========================================================
# === ГЕНЕРАЦИЯ РАСПИСАНИЯ =================================
# =========================================================

func _generate_schedule(day_num: int):
	_schedule_generated = true

	# День 1 (туториал): босс в офисе весь день
	if day_num <= 1:
		_arrival_hour = 8
		_arrival_minute = 0
		_departure_hour = 18
		_departure_minute = 0
		return

	# Выходные: босс не приходит
	if GameTime.is_weekend(day_num):
		_arrival_hour = -1
		_departure_hour = -1
		return

	# День 2 ИЛИ первый день месяца: полный день
	var day_in_month = GameTime.get_day_in_month(day_num)
	if day_num == 2 or day_in_month == 1:
		_arrival_hour = 8
		_arrival_minute = 0
		_departure_hour = 18
		_departure_minute = 0
		return

	# Обычный день: рандомное расписание
	_arrival_hour = randi_range(10, 12)
	_arrival_minute = randi_range(0, 59)
	_departure_hour = randi_range(14, 16)
	_departure_minute = randi_range(0, 59)

	# Гарантируем, что уход не раньше или одновременно с приходом
	var arrival_min = _arrival_hour * 60 + _arrival_minute
	var departure_min = _departure_hour * 60 + _departure_minute
	if departure_min <= arrival_min + 60:
		_departure_hour = min(_arrival_hour + 2, 17)
		_departure_minute = _arrival_minute

# =========================================================
# === СИНХРОНИЗАЦИЯ СОСТОЯНИЯ С ТЕКУЩИМ ВРЕМЕНЕМ ===========
# =========================================================

func _sync_state_to_current_time():
	if _arrival_hour == -1:
		_set_state_away(false)
		return

	var now_minutes = GameTime.hour * 60 + GameTime.minute
	var arrival_minutes = _arrival_hour * 60 + _arrival_minute
	var departure_minutes = _departure_hour * 60 + _departure_minute

	if now_minutes >= arrival_minutes and now_minutes < departure_minutes:
		global_position = desk_position
		_set_state_in_office(false)
	elif now_minutes >= departure_minutes:
		_set_state_away(false)
	else:
		_set_state_away(false)

# =========================================================
# === СИГНАЛЫ ВРЕМЕНИ =====================================
# =========================================================

func _on_day_started(day_number: int):
	_generate_schedule(day_number)
	_sync_state_to_current_time()

func _on_time_tick(h: int, m: int):
	if _arrival_hour == -1:
		return

	var now_minutes = h * 60 + m
	var arrival_minutes = _arrival_hour * 60 + _arrival_minute
	var departure_minutes = _departure_hour * 60 + _departure_minute

	match current_state:
		BossState.AWAY:
			if now_minutes >= arrival_minutes and now_minutes < departure_minutes:
				_start_coming()
		BossState.IN_OFFICE:
			if now_minutes >= departure_minutes:
				_start_leaving()

var _is_night_skip: bool = false

func _on_night_skip_started():
	_is_night_skip = true
	match current_state:
		BossState.IN_OFFICE:
			_start_leaving()
		BossState.COMING:
			current_state = BossState.LEAVING
			var boss_spawn = get_tree().get_first_node_in_group("boss_spawn")
			if boss_spawn:
				nav_agent.target_position = boss_spawn.global_position
			else:
				_set_state_away(false)

func _on_night_skip_finished():
	_is_night_skip = false
	if current_state != BossState.AWAY:
		_set_state_away(false)
	_sync_state_to_current_time()

# =========================================================
# === ПЕРЕХОДЫ СОСТОЯНИЙ ==================================
# =========================================================

func _start_coming():
	var boss_spawn = get_tree().get_first_node_in_group("boss_spawn")
	if boss_spawn:
		global_position = boss_spawn.global_position
	elif desk_position != Vector2.ZERO:
		global_position = desk_position

	visible = true
	$CollisionShape2D.disabled = false
	current_state = BossState.COMING

	if desk_position != Vector2.ZERO:
		nav_agent.target_position = desk_position

func _set_state_in_office(show_toast: bool = true):
	global_position = desk_position
	velocity = Vector2.ZERO
	if body_sprite:
		body_sprite.rotation = 0.0
	current_state = BossState.IN_OFFICE
	visible = true
	$CollisionShape2D.disabled = false

	if show_toast and ScreenJuice and not _is_night_skip:
		ScreenJuice.show_toast("🏢", tr("BOSS_ARRIVED"))

func _start_leaving():
	current_state = BossState.LEAVING
	var boss_spawn = get_tree().get_first_node_in_group("boss_spawn")
	if boss_spawn:
		nav_agent.target_position = boss_spawn.global_position
	else:
		_set_state_away()

func _set_state_away(show_toast: bool = true):
	visible = false
	velocity = Vector2.ZERO
	if body_sprite:
		body_sprite.rotation = 0.0
	$CollisionShape2D.disabled = true
	current_state = BossState.AWAY

	if show_toast and ScreenJuice and not _is_night_skip:
		ScreenJuice.show_toast("🚪", tr("BOSS_LEFT"))

# =========================================================
# === ФИЗИКА / ДВИЖЕНИЕ ====================================
# =========================================================

func _physics_process(delta):
	match current_state:
		BossState.COMING:
			if desk_position == Vector2.ZERO:
				return
			var dist = global_position.distance_to(desk_position)
			if dist <= ARRIVAL_DISTANCE or nav_agent.is_navigation_finished():
				_set_state_in_office()
			else:
				_move_along_path(delta)

		BossState.LEAVING:
			var boss_spawn = get_tree().get_first_node_in_group("boss_spawn")
			if boss_spawn == null:
				_set_state_away()
				return
			var dist = global_position.distance_to(boss_spawn.global_position)
			if dist <= ARRIVAL_DISTANCE or nav_agent.is_navigation_finished():
				_set_state_away()
			else:
				_move_along_path(delta)

func _move_along_path(delta):
	if nav_agent.is_navigation_finished():
		return
	var next_pos = nav_agent.get_next_path_position()
	var to_next = next_pos - global_position
	var distance_to_next = to_next.length()
	var direction = to_next.normalized() if distance_to_next > 0.001 else Vector2.ZERO
	var step_speed = movement_speed
	var max_step = step_speed * delta
	if distance_to_next < max_step and delta > 0.0:
		velocity = to_next / delta
	else:
		velocity = direction * step_speed
	move_and_slide()
	
	if body_sprite and direction.length() > 0.1:
		var target_lean = direction.x * 0.12
		var current_lean = body_sprite.rotation
		body_sprite.rotation = lerp(current_lean, target_lean, 1.0 - exp(-10.0 * delta))

# =========================================================
# === ПРОЦЕСС (EXCLAMATION + SOUND) ========================
# =========================================================

func _process(_delta):
	if _exclamation_bubble:
		if current_state != BossState.IN_OFFICE or TutorialManager.is_active():
			_exclamation_bubble.visible = false
		else:
			_exclamation_bubble.visible = (
				BossManager.should_show_quest() or
				BossManager.should_show_report() or
				BossEventSystem.has_pending_event()
			)
	_check_proximity()

func _check_proximity():
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	var dist = global_position.distance_to(player.global_position)

	if current_state == BossState.IN_OFFICE:
		if dist <= BOSS_SOUND_RADIUS:
			if not _is_player_in_radius:
				_is_player_in_radius = true
				if _boss_player:
					_boss_player.volume_db = AudioManager.get_current_sfx_db()
					_boss_player.play()
		else:
			_is_player_in_radius = false

		if dist <= TUTORIAL_PROXIMITY_RADIUS:
			TutorialManager.notify_player_near_boss()
	else:
		_is_player_in_radius = false

# =========================================================
# === ВЗАИМОДЕЙСТВИЕ ========================================
# =========================================================

func interact():
	if current_state != BossState.IN_OFFICE:
		if ScreenJuice:
			ScreenJuice.show_toast("🚪", tr("BOSS_NOT_HERE"))
		return

	var hud = get_tree().get_first_node_in_group("ui")
	if not hud:
		return

	if TutorialManager.is_active():
		if TutorialManager.current_step == TutorialManager.Step.STEP_2_TAKE_PROJECT:
			hud.open_boss_menu()
		return

	if BossManager.should_show_report():
		var last_report = BossManager.quest_history[BossManager.quest_history.size() - 1]
		hud.open_boss_report(last_report)
		return

	if BossEventSystem.has_pending_event():
		hud.open_boss_event(BossEventSystem.get_pending_event_data())
		return

	if BossManager.should_show_quest():
		var quest = BossManager.generate_quest_for_month(GameTime.get_month())
		hud.open_boss_quest(quest)
		return

	hud.open_boss_menu()

# =========================================================
# === EXCLAMATION BUBBLE ====================================
# =========================================================

func _build_exclamation_mark():
	_exclamation_bubble = Node2D.new()
	_exclamation_bubble.position = Vector2(0, -225)
	_exclamation_bubble.z_index = 100
	_exclamation_bubble.visible = false
	add_child(_exclamation_bubble)

	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(72, 72)
	panel.size = Vector2(72, 72)
	panel.position = Vector2(-36, -36)
	_exclamation_bubble.add_child(panel)

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
	label.custom_minimum_size = Vector2(72, 72)
	label.size = Vector2(72, 72)
	label.text = "❗"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.label_settings = UITheme.make_label_settings(42)
	panel.add_child(label)

func is_in_office() -> bool:
	return current_state == BossState.IN_OFFICE

# =========================================================
# === ОБЪЕМНАЯ ТЕНЬ ТЕЛА (САМА ФУНКЦИЯ) ====================
# =========================================================

func _apply_volume_materials():
	if not body_sprite: return
	
	body_sprite.clip_children = CanvasItem.CLIP_CHILDREN_DISABLED

	for child in body_sprite.get_children():
		if child is Sprite2D and child != head_sprite:
			child.queue_free()

	# Шейдер методом "Смещенной маски" (Inner Shadow)
	var shader_code = """
	shader_type canvas_item;

	void fragment() {
		// Оригинальный пиксель тела
		vec4 c = texture(TEXTURE, UV) * COLOR;

		// ТОЛЩИНА ТЕНИ в пикселях (уменьшена до 8, чтобы не перекрывать все тело)
		float shadow_x = 8.0; 
		float shadow_y = 8.0; 

		// Смещаем координаты ВЛЕВО (-X) и ВНИЗ (+Y)
		vec2 offset = vec2(-shadow_x * TEXTURE_PIXEL_SIZE.x, shadow_y * TEXTURE_PIXEL_SIZE.y);
		vec2 sample_uv = UV + offset;

		// По умолчанию считаем, что вылезли за пределы текстуры - там пустота
		float shifted_alpha = 0.0; 
		
		// Читаем соседний пиксель, если он внутри картинки
		if (sample_uv.x >= 0.0 && sample_uv.x <= 1.0 && sample_uv.y >= 0.0 && sample_uv.y <= 1.0) {
			shifted_alpha = texture(TEXTURE, sample_uv).a;
		}

		// Если мы часть тела, а смещенный пиксель - пустота, значит мы на контуре!
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
