extends RigidBody2D

@export var kick_force: float = 400.0
@export var kick_distance: float = 80.0

var _player: CharacterBody2D = null
var _kick_cooldown: float = 0.0

func _ready():
	body_entered.connect(_on_body_entered)
	_player = get_tree().get_first_node_in_group("player")

func _physics_process(delta):
	if _kick_cooldown > 0.0:
		_kick_cooldown -= delta

	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")

	if _player != null:
		_try_kick_from(_player, kick_force)

	for npc in get_tree().get_nodes_in_group("npc"):
		if npc is CharacterBody2D:
			_try_kick_from(npc, kick_force * 0.7)

func _try_kick_from(body: CharacterBody2D, force: float):
	if _kick_cooldown > 0.0:
		return
	var to_ball = global_position - body.global_position
	var distance = to_ball.length()
	if distance < kick_distance:
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
