extends RigidBody2D

@export var kick_force: float = 400.0
@export var kick_distance: float = 50.0

var _player: CharacterBody2D = null

func _ready():
	body_entered.connect(_on_body_entered)
	_player = get_tree().get_first_node_in_group("player")

func _physics_process(_delta):
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		return
	var to_ball = global_position - _player.global_position
	var distance = to_ball.length()
	if distance < kick_distance:
		var player_velocity = _player.velocity
		if player_velocity.length() > 10:
			var direction = to_ball.normalized()
			var dot = player_velocity.normalized().dot(direction)
			if dot > 0.3:
				# Only apply impulse if ball is not already moving away faster than kick would add
				if linear_velocity.dot(direction) < kick_force * dot * 0.5:
					var force = direction * kick_force * dot
					apply_central_impulse(force)

func _on_body_entered(body: Node):
	if body is CharacterBody2D:
		var direction = (global_position - body.global_position).normalized()
		apply_central_impulse(direction * kick_force)
