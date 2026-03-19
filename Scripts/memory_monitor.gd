extends Node

# === МОНИТОР ПАМЯТИ ===
# Автолоад: Логирует состояние памяти каждые 5 минут реального времени.
#
# Как читать лог:
#   - Если "Objects" постоянно растёт → утечка нод (tweens, тени, баблы)
#   - Если "Static MB" растёт → утечка данных (массивы, словари)
#   - Если "Orphans" растёт → remove_child() без queue_free()

const LOG_INTERVAL_SECONDS: float = 300.0  # 5 минут

var _timer: float = 0.0
var _snapshot_count: int = 0
var _prev_objects: int = 0
var _prev_orphans: int = 0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta):
	_timer += delta
	if _timer >= LOG_INTERVAL_SECONDS:
		_timer = 0.0
		_log_memory()

func _log_memory():
	_snapshot_count += 1
	var static_mem = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	var objects = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var nodes = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var orphans = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))

	var delta_objects = objects - _prev_objects if _prev_objects > 0 else 0
	var delta_orphans = orphans - _prev_orphans if _prev_orphans > 0 else 0

	print("=== MEMORY #%d ===" % _snapshot_count)
	print("  Static: %.1f MB" % static_mem)
	print("  Objects: %d (%+d)" % [objects, delta_objects])
	print("  Nodes: %d" % nodes)
	print("  Orphans: %d (%+d)" % [orphans, delta_orphans])
	print("==================")

	_prev_objects = objects
	_prev_orphans = orphans
