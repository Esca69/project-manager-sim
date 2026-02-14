extends Node

# === ДИНАМИЧЕСКОЕ ОСВЕЩЕНИЕ ОФИСА v2 ===
# Офисный свет: днём почти белый, минимум желтизны.
# Ночью — холодный синий, а не тёплый.

var _canvas_modulate: CanvasModulate = null
var _current_color: Color = Color.WHITE
var _target_color: Color = Color.WHITE

# === ПАЛИТРА ЧАСОВ ===
# Убрана желтизна, днём почти чистый белый, переходы мягче
const LIGHT_PALETTE = {
	0:  Color(0.20, 0.22, 0.35, 1.0),   # Полночь — холодный тёмно-синий
	4:  Color(0.25, 0.27, 0.40, 1.0),   # Предрассвет — чуть светлее
	6:  Color(0.60, 0.60, 0.65, 1.0),   # Рассвет — серо-голубой (без розового)
	7:  Color(0.82, 0.82, 0.82, 1.0),   # Раннее утро — нейтральный серый-светлый
	8:  Color(0.94, 0.94, 0.93, 1.0),   # Утро — почти белый, еле тёплый
	9:  Color(1.0, 1.0, 0.99, 1.0),     # Начало работы — чистый белый
	12: Color(1.0, 1.0, 1.0, 1.0),      # Полдень — идеальный белый
	15: Color(1.0, 1.0, 0.99, 1.0),     # После обеда — всё ещё белый
	17: Color(0.97, 0.95, 0.92, 1.0),   # Предзакатный — ЧУТЬ теплее (минимально)
	18: Color(0.85, 0.78, 0.72, 1.0),   # Закат — мягкий, не ядовито-оранжевый
	19: Color(0.60, 0.55, 0.58, 1.0),   # Сумерки — приглушённый серо-сиреневый
	20: Color(0.40, 0.38, 0.48, 1.0),   # Вечер — холодный сиреневый
	22: Color(0.25, 0.25, 0.38, 1.0),   # Поздний вечер — тёмно-синий
}

const LERP_SPEED = 1.5

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func setup(scene_root: Node2D):
	_canvas_modulate = CanvasModulate.new()
	_canvas_modulate.color = Color.WHITE
	_canvas_modulate.z_index = 100
	scene_root.add_child(_canvas_modulate)

	_current_color = _get_color_for_time(GameTime.hour, GameTime.minute)
	_target_color = _current_color
	_canvas_modulate.color = _current_color

	if not GameTime.time_tick.is_connected(_on_time_tick):
		GameTime.time_tick.connect(_on_time_tick)

func _on_time_tick(h: int, m: int):
	_target_color = _get_color_for_time(h, m)

func _process(delta):
	if _canvas_modulate == null:
		return
	_current_color = _current_color.lerp(_target_color, clamp(delta * LERP_SPEED, 0.0, 1.0))
	_canvas_modulate.color = _current_color

func _get_color_for_time(h: int, m: int) -> Color:
	var time_float = float(h) + float(m) / 60.0

	var keys = LIGHT_PALETTE.keys()
	keys.sort()

	if LIGHT_PALETTE.has(h) and m == 0:
		return LIGHT_PALETTE[h]

	var lower_key = keys[0]
	var upper_key = keys[keys.size() - 1]

	for i in range(keys.size()):
		if keys[i] <= time_float:
			lower_key = keys[i]
		if keys[i] > time_float:
			upper_key = keys[i]
			break

	if lower_key == upper_key:
		return LIGHT_PALETTE[lower_key]

	if time_float < float(keys[0]):
		lower_key = keys[keys.size() - 1]
		upper_key = keys[0]
		var range_val = (24.0 - float(lower_key)) + float(upper_key)
		var t = (time_float + 24.0 - float(lower_key)) / range_val
		return LIGHT_PALETTE[lower_key].lerp(LIGHT_PALETTE[upper_key], t)

	if time_float > float(keys[keys.size() - 1]):
		lower_key = keys[keys.size() - 1]
		upper_key = keys[0]
		var range_val = (24.0 - float(lower_key)) + float(upper_key)
		var t = (time_float - float(lower_key)) / range_val
		return LIGHT_PALETTE[lower_key].lerp(LIGHT_PALETTE[upper_key], t)

	var range_val = float(upper_key) - float(lower_key)
	if range_val == 0:
		return LIGHT_PALETTE[lower_key]

	var t = (time_float - float(lower_key)) / range_val
	return LIGHT_PALETTE[lower_key].lerp(LIGHT_PALETTE[upper_key], t)
