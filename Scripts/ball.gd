extends RigidBody2D

@export var kick_force: float = 600.0
@export var kick_distance: float = 70.0
## Скорость вращения спрайта относительно линейной скорости
@export var spin_factor: float = 0.015

var _player: CharacterBody2D = null
var _kick_cooldown: float = 0.0

func _ready():
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	body_entered.connect(_on_body_entered)
	_player = get_tree().get_first_node_in_group("player")

func _physics_process(delta):
	if _kick_cooldown > 0.0:
		_kick_cooldown -= delta / maxf(Engine.time_scale, 1.0)

	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")

	if _player != null:
		_try_kick_from(_player, kick_force)

	for npc in get_tree().get_nodes_in_group("npc"):
		if npc is CharacterBody2D:
			_try_kick_from(npc, kick_force * 0.7)

	# === ВРАЩЕНИЕ: крутим спрайт пока мяч катится ===
	var speed = linear_velocity.length()
	if speed > 5.0:
		# Определяем направление вращения по горизонтальной составляющей скорости
		# Мяч летит вправо → крутится по часовой (+), влево → против (-)
		var spin_direction = sign(linear_velocity.x) if abs(linear_velocity.x) > abs(linear_velocity.y) else sign(linear_velocity.y)
		angular_velocity = speed * spin_factor * spin_direction
	else:
		# Мяч почти остановился — гасим вращение
		angular_velocity = lerp(angular_velocity, 0.0, 5.0 * delta)

func _try_kick_from(body: CharacterBody2D, force: float):
	if _kick_cooldown > 0.0:
		return
	var to_ball = global_position - body.global_position
	var distance = to_ball.length()
	var effective_distance = kick_distance * maxf(1.0, Engine.time_scale * 0.5)
	if distance < effective_distance:
		var body_velocity = body.velocity
		if body_velocity.length() > 10:
			var direction = to_ball.normalized()
			var dot = body_velocity.normalized().dot(direction)
			if dot > 0.1:
				apply_central_impulse(direction * force * dot)
				_kick_cooldown = 0.15

func _on_body_entered(body: Node):
	if body is CharacterBody2D:
		if _kick_cooldown > 0.0:
			return
		var direction = (global_position - body.global_position).normalized()
		apply_central_impulse(direction * kick_force)
		_kick_cooldown = 0.15
