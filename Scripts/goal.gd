extends StaticBody2D

# ============================================================
# goal.gd — механика ворот: гол, тряска, конфетти, замедление мяча
# ============================================================

const CONFETTI_COOLDOWN: float = 1.0

var _confetti_cooldown: float = 0.0
var _is_shaking: bool = false
var _origin_position: Vector2

func _ready():
	_origin_position = position
	$GoalArea.body_entered.connect(_on_goal_area_body_entered)

func _process(delta: float):
	if _confetti_cooldown > 0.0:
		_confetti_cooldown -= delta

func _on_goal_area_body_entered(body: Node):
	if not body.is_in_group("ball"):
		return
	if _confetti_cooldown > 0.0:
		return

	_confetti_cooldown = CONFETTI_COOLDOWN
	_score_goal(body)

func _score_goal(ball: Node):
	if ball.has_method("on_goal_hit"):
		ball.on_goal_hit()

	_shake()
	_spawn_confetti()

func _shake():
	if _is_shaking:
		return
	_is_shaking = true
	var tween = create_tween()
	var shake_offsets = [
		Vector2(4, 0), Vector2(-4, 2), Vector2(3, -2),
		Vector2(-3, 1), Vector2(2, -1), Vector2(-2, 0),
		Vector2(1, 1), Vector2(0, 0)
	]
	for offset in shake_offsets:
		tween.tween_property(self, "position", _origin_position + offset, 0.04)
	tween.tween_property(self, "position", _origin_position, 0.05)
	tween.tween_callback(func(): _is_shaking = false)

func _spawn_confetti():
	var confetti_script = load("res://Scripts/confetti_effect.gd")
	if not confetti_script:
		return
	var scene = get_tree().current_scene
	if scene == null:
		return
	var c = Node2D.new()
	c.set_script(confetti_script)
	c.process_mode = Node.PROCESS_MODE_ALWAYS
	c.add_to_group("transient_vfx")
	scene.add_child(c)
	c.global_position = global_position + Vector2(0, -130)
