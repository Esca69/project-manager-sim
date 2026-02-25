extends StaticBody2D

var is_busy := false
var current_user = null

@onready var kitchen_spot = $KitchenSpot

func _ready():
	add_to_group("kitchen")

func try_reserve(user) -> bool:
	if is_busy:
		return false
	is_busy = true
	current_user = user
	return true

func release(user):
	if current_user == user:
		is_busy = false
		current_user = null

func get_spot_position() -> Vector2:
	return kitchen_spot.global_position
