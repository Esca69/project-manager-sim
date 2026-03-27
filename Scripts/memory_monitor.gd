extends Node

# === МОНИТОР ПАМЯТИ / ДИАГНОСТИКА КРАШЕЙ ===
# Автолоад: Расширенная диагностика для поиска причины краша.
#
# Как читать лог:
#   - Если "Objects" постоянно растёт → утечка нод (tweens, тени, баблы)
#   - Если "Static MB" растёт → утечка данных (массивы, словари)
#   - Если "Orphans" растёт → remove_child() без queue_free()
#   - Heartbeat ♥ прерывается → игра зависла/упала в этот момент
#   - ⚠️ LOW FPS / OBJECT SPIKE / ORPHAN SPIKE → подозрительное место

const LOG_INTERVAL_SECONDS: float = 60.0   # снапшот каждую минуту
const HEARTBEAT_INTERVAL_SECONDS: float = 10.0  # пульс каждые 10 сек
const LOW_FPS_THRESHOLD: int = 15
const OBJECT_SPIKE_THRESHOLD: int = 500
const ORPHAN_SPIKE_THRESHOLD: int = 10

const CRASH_REPORT_PATH = "user://crash_report.txt"
var _game_exited_cleanly: bool = false

var _diag_timer: float = 0.0
var _heartbeat_timer: float = 0.0
var _snapshot_count: int = 0
var _start_time_ticks: int = 0
var _prev_objects: int = 0
var _prev_orphans: int = 0
var _low_fps_logged: bool = false  # антиспам для LOW FPS

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_start_time_ticks = Time.get_ticks_msec()
	_check_previous_crash()
	_log_startup()

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_game_exited_cleanly = true
		_cleanup_crash_report()

func _process(delta):
	_heartbeat_timer += delta
	if _heartbeat_timer >= HEARTBEAT_INTERVAL_SECONDS:
		_heartbeat_timer = 0.0
		_log_heartbeat()

	_diag_timer += delta
	if _diag_timer >= LOG_INTERVAL_SECONDS:
		_diag_timer = 0.0
		_low_fps_logged = false  # сбрасываем антиспам раз в минуту
		_log_snapshot("")

	_check_crash_guards()

func _elapsed_seconds() -> int:
	return (Time.get_ticks_msec() - _start_time_ticks) / 1000

func _log_startup():
	var dt = Time.get_datetime_dict_from_system()
	var time_str = "%04d-%02d-%02d %02d:%02d:%02d" % [
		dt.year, dt.month, dt.day,
		dt.hour, dt.minute, dt.second
	]
	print("🚀 GAME STARTED | Engine: %s | OS: %s | Time: %s" % [
		Engine.get_version_info().get("string", "unknown"),
		OS.get_name(),
		time_str
	])

func _log_heartbeat():
	var fps = Engine.get_frames_per_second()
	var t = _elapsed_seconds()
	print("♥ T=%ds FPS=%d" % [t, fps])

func _log_snapshot(emergency_tag: String):
	_snapshot_count += 1
	var t = _elapsed_seconds()

	var static_mem = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	var objects = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var nodes = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var orphans = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var fps = Engine.get_frames_per_second()

	var delta_objects = objects - _prev_objects if _prev_objects > 0 else 0
	var delta_orphans = orphans - _prev_orphans if _prev_orphans > 0 else 0

	# Заголовок
	var header = "=== DIAG #%d [%ds] ===" % [_snapshot_count, t]
	if emergency_tag != "":
		header += " (EMERGENCY: %s)" % emergency_tag
	print(header)

	# Состояние игры
	var gt = GameTime
	var day_str = "Day %d %02d:%02d" % [gt.day, gt.hour, gt.minute]
	var flags = "Speed: x%.1f | Paused: %s | NightSkip: %s" % [
		gt.current_speed_scale,
		str(gt.is_game_paused),
		str(gt.is_night_skip)
	]
	print("  %s | %s" % [day_str, flags])

	# FPS и объекты
	print("  FPS: %d | Objects: %d (%+d) | Nodes: %d | Orphans: %d (%+d)" % [
		fps, objects, delta_objects, nodes, orphans, delta_orphans
	])

	# Игровые счётчики
	var npc_count = get_tree().get_nodes_in_group("npc").size()
	var projects_count = 0
	if "active_projects" in ProjectManager:
		projects_count = ProjectManager.active_projects.size()
	var balance = GameState.company_balance
	print("  NPCs: %d | Projects: %d | Balance: $%d" % [npc_count, projects_count, balance])

	# Память
	print("  Static: %.1f MB" % static_mem)
	print("======================")

	_prev_objects = objects
	_prev_orphans = orphans

	_write_crash_report()

func _check_crash_guards():
	var fps = Engine.get_frames_per_second()
	var objects = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var orphans = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var t = _elapsed_seconds()

	# LOW FPS
	if fps > 0 and fps < LOW_FPS_THRESHOLD and not _low_fps_logged:
		_low_fps_logged = true
		var gt = GameTime
		print("⚠️ LOW FPS ALERT [T=%ds] FPS=%d | Day %d %02d:%02d | Speed: x%.1f | Objects: %d" % [
			t, fps, gt.day, gt.hour, gt.minute, gt.current_speed_scale, objects
		])
		_log_snapshot("LOW FPS")
		return  # снапшот уже обновил _prev_objects/_prev_orphans

	# OBJECT SPIKE
	if _prev_objects > 0 and (objects - _prev_objects) > OBJECT_SPIKE_THRESHOLD:
		print("⚠️ OBJECT SPIKE ALERT [T=%ds] Objects: %d (+%d)" % [
			t, objects, objects - _prev_objects
		])
		_log_snapshot("OBJECT SPIKE")
		return

	# ORPHAN SPIKE
	if _prev_orphans > 0 and (orphans - _prev_orphans) > ORPHAN_SPIKE_THRESHOLD:
		print("⚠️ ORPHAN SPIKE ALERT [T=%ds] Orphans: %d (+%d)" % [
			t, orphans, orphans - _prev_orphans
		])
		_log_snapshot("ORPHAN SPIKE")

func _check_previous_crash():
	if FileAccess.file_exists(CRASH_REPORT_PATH):
		var file = FileAccess.open(CRASH_REPORT_PATH, FileAccess.READ)
		if file:
			var content = file.get_as_text()
			file.close()
			print("⚠️ === PREVIOUS SESSION CRASH REPORT FOUND ===")
			print(content)
			print("⚠️ === END CRASH REPORT ===")
			# Переименовываем в бэкап
			var backup_path = "user://crash_report_prev.txt"
			DirAccess.rename_absolute(
				ProjectSettings.globalize_path(CRASH_REPORT_PATH),
				ProjectSettings.globalize_path(backup_path)
			)

func _write_crash_report():
	var file = FileAccess.open(CRASH_REPORT_PATH, FileAccess.WRITE)
	if not file:
		return

	var dt = Time.get_datetime_dict_from_system()
	var time_str = "%04d-%02d-%02d %02d:%02d:%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second]
	var t = _elapsed_seconds()

	file.store_line("=== CRASH REPORT ===")
	file.store_line("Generated: %s (session uptime: %ds)" % [time_str, t])
	file.store_line("Engine: %s | OS: %s" % [Engine.get_version_info().get("string", "unknown"), OS.get_name()])
	file.store_line("")

	# Состояние игры
	file.store_line("--- GAME STATE ---")
	var gt = GameTime
	file.store_line("Day %d %02d:%02d | Speed: x%.1f | Paused: %s | NightSkip: %s" % [
		gt.day, gt.hour, gt.minute, gt.current_speed_scale,
		str(gt.is_game_paused), str(gt.is_night_skip)
	])
	file.store_line("")

	# Производительность
	file.store_line("--- PERFORMANCE ---")
	var static_mem = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	var objects = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var nodes = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var orphans = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var fps = Engine.get_frames_per_second()
	file.store_line("FPS: %d | Objects: %d | Nodes: %d | Orphans: %d" % [fps, objects, nodes, orphans])
	file.store_line("Static Memory: %.1f MB" % static_mem)
	file.store_line("")

	# Игровые счётчики
	file.store_line("--- COUNTERS ---")
	var npc_count = 0
	var tree = get_tree()
	if tree != null:
		npc_count = tree.get_nodes_in_group("npc").size()
	var projects_count = 0
	if "active_projects" in ProjectManager:
		projects_count = ProjectManager.active_projects.size()
	var balance = GameState.company_balance
	file.store_line("NPCs: %d | Projects: %d | Balance: $%d" % [npc_count, projects_count, balance])
	file.store_line("")

	file.store_line("If you see this file, the game did NOT exit cleanly.")
	file.store_line("Send this file to the developer for diagnosis.")
	file.close()

func _cleanup_crash_report():
	if FileAccess.file_exists(CRASH_REPORT_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CRASH_REPORT_PATH))
