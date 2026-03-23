extends Node2D

# ============================================================
# ChatSparkleEffect — искры при proximity chat между NPC
# Создаётся через set_script() в ScreenJuice.show_chat_sparkles()
# ============================================================

var start_pos: Vector2 = Vector2.ZERO
var end_pos: Vector2 = Vector2.ZERO
var spark_color: Color = Color(0.2, 0.9, 0.3, 1.0)
var _particles: Array = []

const PARTICLE_COUNT: int = 5
const FLIGHT_DURATION: float = 1.5

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func setup(from: Vector2, to: Vector2, color: Color):
	start_pos = from
	end_pos = to
	spark_color = color
	_spawn_particles()

func _spawn_particles():
	for i in range(PARTICLE_COUNT):
		_particles.append({
			"progress": 0.0,
			"arc_offset": randf_range(-30.0, 30.0),
		})

func _process(delta: float):
	var all_done = true
	for p in _particles:
		p["progress"] += delta / FLIGHT_DURATION
		if p["progress"] < 1.0:
			all_done = false

	queue_redraw()

	if all_done:
		queue_free()

func _draw():
	for p in _particles:
		var t = minf(p["progress"], 1.0)
		var pos = start_pos.lerp(end_pos, t) + Vector2(0.0, p["arc_offset"] * sin(t * PI))
		var local_pos = pos - global_position
		var c = spark_color
		c.a = 1.0 - t
		draw_circle(local_pos, 3.0, c)
