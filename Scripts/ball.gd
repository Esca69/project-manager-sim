extends RigidBody2D

@export var kick_force: float = 400.0

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node):
	if body is CharacterBody2D:
		var direction = (global_position - body.global_position).normalized()
		apply_central_impulse(direction * kick_force)
