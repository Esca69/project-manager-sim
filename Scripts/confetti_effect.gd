extends Node2D

# ============================================================
# ConfettiEffect — анимация конфетти при завершении проекта
# ============================================================

var _particles: Array = []
var _lifetime: float = 2.5
var _elapsed: float = 0.0
var _alpha: float = 1.0

const GRAVITY: float = 280.0
const PARTICLE_COUNT_MIN: int = 40
const PARTICLE_COUNT_MAX: int = 60
const FADE_START: float = 1.8
const PARTICLE_COLORS: Array = [
	Color(0.2, 0.8, 0.3),    # зелёный
	Color(0.2, 0.7, 1.0),    # голубой
	Color(1.0, 0.9, 0.1),    # жёлтый
	Color(1.0, 0.5, 0.1),    # оранжевый
	Color(0.7, 0.2, 1.0),    # фиолетовый
	Color(1.0, 0.2, 0.5),    # розовый
]

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_spawn_particles()

func _spawn_particles():
	var viewport_size = get_viewport_rect().size
	var spawn_x_center = viewport_size.x * 0.5
	var count = randi_range(PARTICLE_COUNT_MIN, PARTICLE_COUNT_MAX)
	for i in range(count):
		var angle = randf_range(-PI * 0.8, -PI * 0.2)
		var speed = randf_range(180.0, 420.0)
		_particles.append({
			"pos": Vector2(
				spawn_x_center + randf_range(-viewport_size.x * 0.4, viewport_size.x * 0.4),
				viewport_size.y * 0.35
			),
			"vel": Vector2(cos(angle) * speed * randf_range(0.5, 1.5), sin(angle) * speed),
			"size": Vector2(randi_range(4, 7), randi_range(6, 10)),
			"color": PARTICLE_COLORS[randi() % PARTICLE_COLORS.size()],
			"rotation": randf_range(0.0, TAU),
			"rot_speed": randf_range(-4.0, 4.0),
		})

func _process(delta: float):
	_elapsed += delta
	if _elapsed >= _lifetime:
		queue_free()
		return

	if _elapsed >= FADE_START:
		_alpha = 1.0 - (_elapsed - FADE_START) / (_lifetime - FADE_START)
	else:
		_alpha = 1.0

	for p in _particles:
		p["vel"].y += GRAVITY * delta
		p["pos"] += p["vel"] * delta
		p["rotation"] += p["rot_speed"] * delta

	queue_redraw()

func _draw():
	for p in _particles:
		var c = p["color"]
		c.a = _alpha
		draw_set_transform(p["pos"], p["rotation"])
		draw_rect(Rect2(-p["size"] * 0.5, p["size"]), c)
	draw_set_transform(Vector2.ZERO, 0.0)
