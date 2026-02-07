extends Node2D

var is_busy := false
var current_user = null

@onready var coffee_spot = $CoffeeSpot

func _ready():
	add_to_group("coffee_machine")

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
	return coffee_spot.global_position
