extends StaticBody2D

var is_busy := false
var current_user = null
var is_broken := false

const COFFEE_MACHINE_REPAIR_COST: int = 300

@onready var coffee_spot = $CoffeeSpot

func _ready():
	add_to_group("coffee_machine")
	update_machine_visuals()

func try_reserve(user) -> bool:
	if is_busy or is_broken:
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

func on_ball_hit():
	if is_broken:
		return
	if randf() < 0.30:
		break_machine()

func break_machine():
	is_broken = true
	update_machine_visuals()
	AudioManager.play_sfx("monitor_break")

	var user = current_user
	if user and is_instance_valid(user):
		user.coffee_cup_holder.visible = false
		user.coffee_machine_ref = null
		release(user)
		if user._is_work_time():
			user._start_wandering()
		else:
			user.current_state = user.State.IDLE
			user.velocity = Vector2.ZERO
	else:
		is_busy = false
		current_user = null

func repair_machine() -> bool:
	var gs = get_node_or_null("/root/GameState")
	if gs == null:
		return false
	if gs.company_balance < COFFEE_MACHINE_REPAIR_COST:
		return false

	gs.add_expense(COFFEE_MACHINE_REPAIR_COST)
	gs.daily_event_expenses.append({"reason": "SUMMARY_COFFEE_MACHINE_REPAIR", "amount": COFFEE_MACHINE_REPAIR_COST})
	is_broken = false
	update_machine_visuals()

	var el = get_node_or_null("/root/EventLog")
	if el:
		el.add(tr("LOG_COFFEE_MACHINE_REPAIRED"), el.LogType.PROGRESS)
	return true

func is_broken_machine() -> bool:
	return is_broken

func update_machine_visuals():
	var sprite_normal = get_node_or_null("Sprite")
	var sprite_broken = get_node_or_null("CoffemachineBroken")
	if sprite_normal:
		sprite_normal.visible = not is_broken
	if sprite_broken:
		sprite_broken.visible = is_broken

	var smoke = get_node_or_null("SmokeParticles")
	if smoke and (smoke is CPUParticles2D or smoke is GPUParticles2D):
		smoke.emitting = is_broken

func interact():
	if not is_broken:
		return
	var hud = get_tree().get_first_node_in_group("ui")
	if hud:
		var panel = hud.get_node_or_null("CoffeeMachinePanel")
		if panel:
			panel.open_for_machine(self)
