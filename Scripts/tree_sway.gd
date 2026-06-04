extends StaticBody2D

@onready var leaves = $leaves

@export var sway_angle: float = 3.0
@export var sway_speed: float = 1.2

func _ready():
	await get_tree().create_timer(randf_range(0.0, sway_speed * 2)).timeout
	_start_sway()

func _start_sway():
	var tween = create_tween().set_loops()
	tween.tween_property(leaves, "rotation_degrees", sway_angle, sway_speed)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(leaves, "rotation_degrees", -sway_angle, sway_speed)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
