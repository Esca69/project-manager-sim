extends RigidBody2D

@export var kick_force: float = 700.0
@export var kick_distance: float = 70.0
## Скорость вращения спрайта относительно линейной скорости
@export var spin_factor: float = 0.015

var _player: CharacterBody2D = null
var _kick_cooldown: float = 0.0

func _ready():
	add_to_group("ball")
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	body_entered.connect(_on_body_entered)
	_player = get_tree().get_first_node_in_group("player")

func _physics_process(delta):
	# Кулдаун в реальном времени (не зависит от time_scale)
	if _kick_cooldown > 0.0:
		_kick_cooldown -= delta / maxf(Engine.time_scale, 1.0)

	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")

	if _player != null:
		# Во время спринта сила удара увеличивается в 2.5 раза
		var player_force = kick_force
		if _player.get("_is_sprinting") == true:
			player_force *= 2.5
		_try_kick_from(_player, player_force)

	for npc in get_tree().get_nodes_in_group("npc"):
		if npc is CharacterBody2D:
			_try_kick_from(npc, kick_force * 0.7)

	# === ВРАЩЕНИЕ: крутим спрайт пока мяч катится ===
	var speed = linear_velocity.length()
	if speed > 5.0:
		var spin_direction = sign(linear_velocity.x) if abs(linear_velocity.x) > abs(linear_velocity.y) else sign(linear_velocity.y)
		angular_velocity = speed * spin_factor * spin_direction
	else:
		angular_velocity = lerp(angular_velocity, 0.0, 5.0 * delta)

func _try_kick_from(body: CharacterBody2D, force: float):
	if _kick_cooldown > 0.0:
		return
	var body_center = body.global_position + Vector2(1, -22)
	var to_ball = global_position - body_center
	var distance = to_ball.length()
	# БЕЗ масштабирования на time_scale — дистанция всегда 70px
	if distance < kick_distance:
		var body_velocity = body.last_move_velocity if "last_move_velocity" in body else body.velocity
		if body_velocity.length() > 10.0:
			var direction = to_ball.normalized()
			var dot = body_velocity.normalized().dot(direction)
			# dot используем только для масштабирования силы
			# НЕТ порога dot > 0.1 — это и было причиной бага на 5x/10x
			# (игрок перескакивал мяч за 1 кадр, dot становился отрицательным)
			var kick_multiplier = clampf(dot, 0.5, 1.0)
			var push_dir = (direction + body_velocity.normalized() * 0.4).normalized()
			apply_central_impulse(push_dir * force * kick_multiplier)
			AudioManager.play_sfx("ball_kick")
			_kick_cooldown = 0.15
		else:
			# Игрок стоит и касается мяча — лёгкий толчок
			var direction = to_ball.normalized()
			apply_central_impulse(direction * force * 0.4)
			AudioManager.play_sfx("ball_kick")
			_kick_cooldown = 0.15

func _on_body_entered(body: Node):
	# Этот сигнал срабатывает только для объектов на layer 1 (стены, NPC)
	# Игрок на layer 2 — не попадает сюда. Логика удара выше в _try_kick_from.
	if body is CharacterBody2D:
		if _kick_cooldown > 0.0:
			return
		var direction = (global_position - body.global_position).normalized()
		apply_central_impulse(direction * kick_force * 0.5)
		_kick_cooldown = 0.15

	# Проверяем, не попал ли мяч в стол сотрудника
	if body.is_in_group("desk") and body.has_method("on_ball_hit"):
		body.on_ball_hit()

func on_goal_hit():
	# Сохраняем направление, резко гасим скорость — имитация попадания в сетку
	linear_velocity *= 0.30
	angular_velocity *= 0.30
