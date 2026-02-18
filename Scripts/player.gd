extends CharacterBody2D

const SPEED = 300.0

const ZOOM_STEP = 0.1
const ZOOM_MIN = 0.6
const ZOOM_MAX = 1.6
const ZOOM_SMOOTH_SPEED = 8.0

const LEAN_ANGLE = 0.12
const LEAN_SPEED = 10.0

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

@onready var interaction_zone = $InteractionZone
@onready var camera = $Camera2D
@onready var body_sprite = $Sprite2D
@onready var head_sprite = $Sprite2D/Head2

var target_zoom: Vector2 = Vector2.ONE

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

func _ready():
	add_to_group("player")
	target_zoom = camera.zoom
	_create_interact_hint()
	_create_discuss_bar()

	body_sprite.self_modulate = Color("#a2c5ea")
	head_sprite.self_modulate = Color("#fff0e1")

	# Подключаем тики времени для кулдаунов
	GameTime.time_tick.connect(_on_motivate_time_tick)
	GameTime.time_tick.connect(_on_no_toilet_time_tick)

	# Подписываемся на прокачку навыков — чтобы кнопки появлялись сразу
	PMData.skill_unlocked.connect(_on_pm_skill_unlocked)

	call_deferred("_create_motivate_button")
	call_deferred("_create_no_toilet_button")

func _on_pm_skill_unlocked(_skill_id: String):
	_update_motivate_btn()
	_update_no_toilet_btn()

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
	_discuss_label.text = "Обсуждение"
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
		velocity = Vector2.ZERO
		move_and_slide()
		_hide_interact_hint()
		return

	if _is_ui_blocking():
		velocity = Vector2.ZERO
		move_and_slide()
		_hide_interact_hint()
		return

	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if direction:
		velocity = direction * SPEED
	else:
		velocity = Vector2.ZERO
	move_and_slide()

	var target_lean = 0.0
	if direction.x > 0.1:
		target_lean = LEAN_ANGLE
	elif direction.x < -0.1:
		target_lean = -LEAN_ANGLE

	body_sprite.rotation = lerp(body_sprite.rotation, target_lean, LEAN_SPEED * delta)
	head_sprite.rotation = lerp(head_sprite.rotation, target_lean * 0.6, LEAN_SPEED * delta)

	_update_interact_hint()

	if Input.is_action_just_pressed("interact"):
		interact()

	# === АКТИВАЦИЯ МОТИВАЦИИ ПО Q ===
	if Input.is_action_just_pressed("motivate"):
		_activate_motivate()

	# === АКТИВАЦИЯ ЗАПРЕТА ТУАЛЕТА ПО R ===
	if Input.is_action_just_pressed("no_toilet"):
		_activate_no_toilet()

func _process(delta):
	camera.zoom = camera.zoom.lerp(target_zoom, min(1.0, ZOOM_SMOOTH_SPEED * delta))
	_update_discuss_bar_position()

func _unhandled_input(event):
	if GameTime.is_night_skip:
		return

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
	if target is Node2D:
		target_world_pos = target.global_position + Vector2(0, -80)
	else:
		target_world_pos = target.global_position + Vector2(0, -80)

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

func _get_nearest_interactable():
	var bodies = interaction_zone.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("npc") and "data" in body and body.data:
			return body
		if body.is_in_group("desk") and body.has_method("interact"):
			return body
	return null

func _world_to_screen(world_pos: Vector2) -> Vector2:
	var canvas_transform = get_viewport().get_canvas_transform()
	return canvas_transform * world_pos

func interact():
	var bodies = interaction_zone.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("npc") and body.data:
			AudioManager.play_sfx("interact")
			get_tree().call_group("ui", "show_employee_card", body.data)
			return

		if body.is_in_group("desk") and body.has_method("interact"):
			AudioManager.play_sfx("interact")
			body.interact()
			return

# === ПРОГРЕСС-БА�� ОБСУЖДЕНИЯ: ПУБЛИЧНЫЙ API ДЛЯ HUD ===

func show_discuss_bar(total_minutes: float):
	_discuss_progress_bar.max_value = total_minutes
	_discuss_progress_bar.value = 0
	_discuss_label.text = "Обсуждение"
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
	_discuss_bar_container.global_position = Vector2(
		screen_pos.x - bar_size.x / 2.0,
		screen_pos.y - bar_size.y
	)

# ============================
# === МОТИВАЦИЯ: ЛОГИКА ===
# ============================

func _activate_motivate():
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

func _on_motivate_time_tick(_h, _m):
	if _motivate_cooldown_left > 0:
		_motivate_cooldown_left -= 1.0
		_update_motivate_btn()
		if _motivate_cooldown_left <= 0:
			_motivate_cooldown_left = 0
			_update_motivate_btn()
			print("🔥 Мотивация снова доступна!")

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
	var label_settings = LabelSettings.new()
	label_settings.font_size = 42
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
	if not PMData.has_skill("no_toilet"):
		return

	if _no_toilet_cooldown_left > 0:
		print("🚽 Запрет туалета на перезарядке! Осталось %d мин." % int(_no_toilet_cooldown_left))
		return

	var hud = get_tree().get_first_node_in_group("ui")
	if hud and hud.has_method("is_pm_busy") and hud.is_pm_busy():
		print("🚽 PM за��ят, нельзя запретить туалет!")
		return

	AudioManager.play_sfx("closedoor")

	var affected_count = 0
	for npc in get_tree().get_nodes_in_group("npc"):
		if not npc.visible:
			continue
		if not npc.data:
			continue
		var dist = global_position.distance_to(npc.global_position)
		if dist <= NO_TOILET_RADIUS:
			npc.apply_toilet_ban(NO_TOILET_DURATION_MINUTES)
			affected_count += 1

	_no_toilet_cooldown_left = NO_TOILET_COOLDOWN_MINUTES
	_update_no_toilet_btn()

	_show_no_toilet_wave()
	_show_radius_circle(NO_TOILET_RADIUS, Color(0.6, 0.2, 0.2, 0.6))

	if affected_count > 0:
		print("🚽 Запрет туалета активирован! Затронуто: %d сотрудников" % affected_count)
	else:
		print("🚽 Запрет туалета активирован! Никого рядом не оказалось.")

func _on_no_toilet_time_tick(_h, _m):
	if _no_toilet_cooldown_left > 0:
		_no_toilet_cooldown_left -= 1.0
		_update_no_toilet_btn()
		if _no_toilet_cooldown_left <= 0:
			_no_toilet_cooldown_left = 0
			_update_no_toilet_btn()
			print("🚽 Запрет туалета снова доступен!")

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
	var label_settings = LabelSettings.new()
	label_settings.font_size = 42
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
	_motivate_btn.text = "🔥 Мотивировать [Q]"
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
		_motivate_cooldown_label.text = "⏳ Перезарядка: %d:%02d" % [hours, mins]
	else:
		_motivate_btn.disabled = false
		_motivate_cooldown_label.text = "Готово!"

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
	_no_toilet_btn.text = "🚽 Запретить с*ать [R]"
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
		_no_toilet_cooldown_label.text = "⏳ Перезарядка: %d:%02d" % [hours, mins]
	else:
		_no_toilet_btn.disabled = false
		_no_toilet_cooldown_label.text = "Готово!"
