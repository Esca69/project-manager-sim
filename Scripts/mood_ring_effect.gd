extends Node2D

# ============================================================
# MoodRingEffect — кольцо-пульс при пересечении порога настроения
# Создаётся через set_script() в ScreenJuice.show_mood_ring()
# ============================================================

var ring_color: Color = Color(0.2, 0.9, 0.3, 1.0)
var _elapsed: float = 0.0
var _max_radius: float = 40.0
var _duration: float = 0.4
var _current_radius: float = 0.0
var _current_alpha: float = 1.0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float):
	_elapsed += delta
	if _elapsed >= _duration:
		queue_free()
		return

	var t = _elapsed / _duration
	_current_radius = _max_radius * t
	_current_alpha = 1.0 - t
	queue_redraw()

func _draw():
	var c = ring_color
	c.a = _current_alpha
	draw_arc(Vector2.ZERO, _current_radius, 0.0, TAU, 32, c, 3.0)
