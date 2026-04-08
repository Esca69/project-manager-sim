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
#   - ⚠️ GROWING COLLECTION → коллекция растёт 3+ снапшота подряд
#   - ⚠️ DEGRADING PERFORMANCE → frame time растёт 3+ снапшота подряд

const LOG_INTERVAL_SECONDS: float = 60.0   # снапшот каждую минуту
const HEARTBEAT_INTERVAL_SECONDS: float = 10.0  # пульс каждые 10 сек
const LOW_FPS_THRESHOLD: int = 15
const OBJECT_SPIKE_THRESHOLD: int = 500
const ORPHAN_SPIKE_THRESHOLD: int = 10
const MEMORY_SPIKE_MB: float = 50.0          # алерт если Static Memory выросла > 50 MB
const COLLECTION_OVERFLOW_THRESHOLD: int = 100  # алерт если коллекция > 100 элементов
const PHYSICS_LAG_MS: float = 33.0          # алерт если physics frame time > 33ms (< 30fps)
const TREND_HISTORY_SIZE: int = 10          # кольцевой буфер для трендов

const CRASH_REPORT_PATH = "user://crash_report.txt"
var _game_exited_cleanly: bool = false

var _diag_timer: float = 0.0
var _heartbeat_timer: float = 0.0
var _snapshot_count: int = 0
var _start_time_ticks: int = 0
var _prev_objects: int = 0
var _prev_orphans: int = 0
var _prev_static_mb: float = 0.0
var _low_fps_logged: bool = false  # антиспам для LOW FPS

# Кольцевой буфер для трендов (последние TREND_HISTORY_SIZE снапшотов)
var _trend_history: Array = []

# Предыдущие размеры коллекций для дельт
var _prev_collections: Dictionary = {}

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

# === СБОР МЕТРИК ===
func _collect_snapshot_data() -> Dictionary:
	var data = {}

	# Базовые перформанс метрики
	data["static_mb"] = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	data["objects"] = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	data["nodes"] = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	data["orphans"] = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	data["fps"] = Engine.get_frames_per_second()
	data["physics_ms"] = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	data["process_ms"] = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0

	# Дельты от предыдущего снапшота
	data["delta_objects"] = data["objects"] - _prev_objects if _prev_objects > 0 else 0
	data["delta_orphans"] = data["orphans"] - _prev_orphans if _prev_orphans > 0 else 0
	data["delta_static_mb"] = data["static_mb"] - _prev_static_mb if _prev_static_mb > 0.0 else 0.0

	# Состояние игры
	var gt = GameTime
	data["day"] = gt.day
	data["hour"] = gt.hour
	data["minute"] = gt.minute
	data["speed"] = gt.current_speed_scale
	data["paused"] = gt.is_game_paused
	data["night_skip"] = gt.is_night_skip
	data["balance"] = GameState.company_balance

	# Проекты
	data["active_count"] = 0
	data["completed_count"] = 0
	data["state_counts"] = {0: 0, 1: 0, 2: 0, 3: 0}  # DRAFTING, IN_PROGRESS, FINISHED, FAILED
	if "active_projects" in ProjectManager:
		data["active_count"] = ProjectManager.active_projects.size()
		for proj in ProjectManager.active_projects:
			var s = int(proj.state)
			if data["state_counts"].has(s):
				data["state_counts"][s] += 1
	if "completed_projects" in ProjectManager:
		data["completed_count"] = ProjectManager.completed_projects.size()
		for proj in ProjectManager.completed_projects:
			var s = int(proj.state)
			if data["state_counts"].has(s):
				data["state_counts"][s] += 1

	# Коллекции синглтонов
	var cols: Dictionary = {}
	cols["PeopleHistory"] = PeopleHistory.daily_records.size() if PeopleHistory else 0
	cols["FinHistory"] = FinancialHistory.daily_records.size() if FinancialHistory and "daily_records" in FinancialHistory else 0
	if EventManager:
		cols["Effects"] = EventManager.active_effects.size()
		cols["Cooldowns"] = EventManager.employee_cooldowns.size()
		cols["Reviews"] = EventManager._pending_reviews.size()
		cols["ScopeExpanded"] = EventManager._scope_expanded_projects.size()
		cols["JuniorMistakes"] = EventManager._junior_mistake_stages.size()
	else:
		cols["Effects"] = 0
		cols["Cooldowns"] = 0
		cols["Reviews"] = 0
		cols["ScopeExpanded"] = 0
		cols["JuniorMistakes"] = 0
	var bm = get_node_or_null("/root/BossManager")
	cols["QuestHistory"] = bm.quest_history.size() if bm and "quest_history" in bm else 0
	data["collections"] = cols

	# Дельты коллекций
	var col_deltas: Dictionary = {}
	for key in cols:
		col_deltas[key] = cols[key] - _prev_collections.get(key, cols[key])
	data["col_deltas"] = col_deltas

	# NPC агрегаты
	var npc_nodes = get_tree().get_nodes_in_group("npc")
	data["npc_count"] = npc_nodes.size()
	var state_counts: Dictionary = {}
	var total_mood_mods: int = 0
	var max_mood_mods: int = 0
	for npc in npc_nodes:
		var st = str(npc.current_state) if "current_state" in npc else "?"
		state_counts[st] = state_counts.get(st, 0) + 1
		if npc.data and "mood_temp_modifiers" in npc.data:
			var cnt = npc.data.mood_temp_modifiers.size()
			total_mood_mods += cnt
			if cnt > max_mood_mods:
				max_mood_mods = cnt
	data["npc_state_counts"] = state_counts
	data["total_mood_mods"] = total_mood_mods
	data["max_mood_mods"] = max_mood_mods

	return data

func _log_snapshot(emergency_tag: String):
	_snapshot_count += 1
	var t = _elapsed_seconds()

	var d = _collect_snapshot_data()

	# Заголовок
	var header = "=== DIAG #%d [%ds] ===" % [_snapshot_count, t]
	if emergency_tag != "":
		header += " (EMERGENCY: %s)" % emergency_tag
	print(header)

	# Состояние игры
	print("  Day %d %02d:%02d | Speed: x%.1f | Paused: %s | NightSkip: %s" % [
		d["day"], d["hour"], d["minute"],
		d["speed"], str(d["paused"]), str(d["night_skip"])
	])

	# FPS и объекты
	print("  FPS: %d | Objects: %d (%+d) | Nodes: %d | Orphans: %d (%+d)" % [
		d["fps"], d["objects"], d["delta_objects"],
		d["nodes"], d["orphans"], d["delta_orphans"]
	])

	# Frame times
	print("  PhysicsTime: %.2fms | ProcessTime: %.2fms" % [d["physics_ms"], d["process_ms"]])

	# Память
	print("  Static: %.1f MB (%+.1f)" % [d["static_mb"], d["delta_static_mb"]])

	# Проекты
	var sc = d["state_counts"]
	print("  --- PROJECTS ---")
	print("  Active: %d | Completed: %d | Total: %d" % [
		d["active_count"], d["completed_count"],
		d["active_count"] + d["completed_count"]
	])
	print("  States: DRAFTING=%d IN_PROGRESS=%d FINISHED=%d FAILED=%d" % [
		sc.get(0, 0), sc.get(1, 0), sc.get(2, 0), sc.get(3, 0)
	])

	# Коллекции
	var cols = d["collections"]
	var col_d = d["col_deltas"]
	print("  --- COLLECTIONS ---")
	print("  PeopleHistory: %d (%+d) | FinHistory: %d (%+d) | Effects: %d (%+d)" % [
		cols["PeopleHistory"], col_d["PeopleHistory"],
		cols["FinHistory"], col_d["FinHistory"],
		cols["Effects"], col_d["Effects"]
	])
	print("  Cooldowns: %d (%+d) | Reviews: %d (%+d) | QuestHistory: %d (%+d)" % [
		cols["Cooldowns"], col_d["Cooldowns"],
		cols["Reviews"], col_d["Reviews"],
		cols["QuestHistory"], col_d["QuestHistory"]
	])

	# NPC
	print("  --- NPCs (%d total) ---" % d["npc_count"])
	var state_str = ""
	for k in d["npc_state_counts"]:
		state_str += "ST%s=%d " % [k, d["npc_state_counts"][k]]
	print("  States: %s| MoodMods: %d total (max %d/npc)" % [
		state_str, d["total_mood_mods"], d["max_mood_mods"]
	])
	print("======================")

	# Обновляем предыдущие значения
	_prev_objects = d["objects"]
	_prev_orphans = d["orphans"]
	_prev_static_mb = d["static_mb"]
	for key in d["collections"]:
		_prev_collections[key] = d["collections"][key]

	# Добавляем снапшот в кольцевой буфер
	_trend_history.append(d)
	if _trend_history.size() > TREND_HISTORY_SIZE:
		_trend_history.pop_front()

	# Проверяем тренды и выводим алерты
	_check_trends()

	_write_crash_report()

func _check_trends():
	if _trend_history.size() < 3:
		return

	var last3 = _trend_history.slice(_trend_history.size() - 3, _trend_history.size())

	# Проверяем рост коллекций 3+ снапшота подряд
	var col_keys = last3[0]["collections"].keys() if last3[0].has("collections") else []
	for key in col_keys:
		var v0 = last3[0]["collections"].get(key, 0)
		var v1 = last3[1]["collections"].get(key, 0)
		var v2 = last3[2]["collections"].get(key, 0)
		if v2 > v1 and v1 > v0:
			print("⚠️ GROWING COLLECTION: %s grew %d→%d→%d over 3 snapshots" % [key, v0, v1, v2])

	# Проверяем рост physics frame time 3+ снапшота подряд
	var p0 = last3[0].get("physics_ms", 0.0)
	var p1 = last3[1].get("physics_ms", 0.0)
	var p2 = last3[2].get("physics_ms", 0.0)
	if p2 > p1 and p1 > p0:
		print("⚠️ DEGRADING PERFORMANCE: physics frame time grew %.2f→%.2f→%.2fms over 3 snapshots" % [p0, p1, p2])

func _check_crash_guards():
	var fps = Engine.get_frames_per_second()
	var objects = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var orphans = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var static_mb = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	var physics_ms = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var t = _elapsed_seconds()

	# LOW FPS
	if fps > 0 and fps < LOW_FPS_THRESHOLD and not _low_fps_logged:
		_low_fps_logged = true
		var gt = GameTime
		print("⚠️ LOW FPS ALERT [T=%ds] FPS=%d | Day %d %02d:%02d | Speed: x%.1f | Objects: %d" % [
			t, fps, gt.day, gt.hour, gt.minute, gt.current_speed_scale, objects
		])
		_log_snapshot("LOW FPS")
		return  # снапшот уже обновил предыдущие значения

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
		return

	# MEMORY SPIKE
	if _prev_static_mb > 0.0 and (static_mb - _prev_static_mb) > MEMORY_SPIKE_MB:
		print("⚠️ MEMORY SPIKE ALERT [T=%ds] Static: %.1f MB (+%.1f MB)" % [
			t, static_mb, static_mb - _prev_static_mb
		])
		_log_snapshot("MEMORY SPIKE")
		return

	# PHYSICS LAG
	if physics_ms > PHYSICS_LAG_MS:
		print("⚠️ PHYSICS LAG ALERT [T=%ds] PhysicsTime: %.2fms (> %.0fms threshold)" % [
			t, physics_ms, PHYSICS_LAG_MS
		])
		_log_snapshot("PHYSICS LAG")
		return

	# COLLECTION OVERFLOW
	if "active_projects" in ProjectManager and "completed_projects" in ProjectManager:
		var active_proj = ProjectManager.active_projects.size()
		var completed_proj = ProjectManager.completed_projects.size()
		if active_proj > COLLECTION_OVERFLOW_THRESHOLD:
			print("⚠️ COLLECTION OVERFLOW: active_projects=%d (> %d)" % [active_proj, COLLECTION_OVERFLOW_THRESHOLD])
			_log_snapshot("COLLECTION OVERFLOW")
		elif completed_proj > COLLECTION_OVERFLOW_THRESHOLD:
			print("⚠️ COLLECTION OVERFLOW: completed_projects=%d (> %d)" % [completed_proj, COLLECTION_OVERFLOW_THRESHOLD])
			_log_snapshot("COLLECTION OVERFLOW")

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

	# Текущий снапшот
	if _trend_history.is_empty():
		file.store_line("No snapshot data available yet.")
		file.store_line("")
	else:
		var d = _trend_history[_trend_history.size() - 1]
		var gt = GameTime

		file.store_line("--- GAME STATE ---")
		file.store_line("Day %d %02d:%02d | Speed: x%.1f | Paused: %s | NightSkip: %s" % [
			gt.day, gt.hour, gt.minute, gt.current_speed_scale,
			str(gt.is_game_paused), str(gt.is_night_skip)
		])
		file.store_line("")

		file.store_line("--- PERFORMANCE ---")
		file.store_line("FPS: %d | Objects: %d | Nodes: %d | Orphans: %d" % [
			d.get("fps", 0), d.get("objects", 0), d.get("nodes", 0), d.get("orphans", 0)
		])
		file.store_line("PhysicsTime: %.2fms | ProcessTime: %.2fms" % [
			d.get("physics_ms", 0.0), d.get("process_ms", 0.0)
		])
		file.store_line("Static Memory: %.1f MB" % d.get("static_mb", 0.0))
		file.store_line("")

		file.store_line("--- PROJECTS ---")
		var sc = d.get("state_counts", {})
		file.store_line("Active: %d | Completed: %d | Total: %d" % [
			d.get("active_count", 0), d.get("completed_count", 0),
			d.get("active_count", 0) + d.get("completed_count", 0)
		])
		file.store_line("DRAFTING=%d IN_PROGRESS=%d FINISHED=%d FAILED=%d" % [
			sc.get(0, 0), sc.get(1, 0), sc.get(2, 0), sc.get(3, 0)
		])
		file.store_line("")

		file.store_line("--- COLLECTIONS ---")
		var cols = d.get("collections", {})
		for key in cols:
			file.store_line("  %s: %d" % [key, cols[key]])
		file.store_line("")

		file.store_line("--- NPCs ---")
		file.store_line("Total: %d | MoodMods: %d total (max %d/npc)" % [
			d.get("npc_count", 0), d.get("total_mood_mods", 0), d.get("max_mood_mods", 0)
		])
		var npc_states = d.get("npc_state_counts", {})
		var state_str = ""
		for k in npc_states:
			state_str += "ST%s=%d " % [k, npc_states[k]]
		file.store_line("States: %s" % state_str)
		file.store_line("")

	# История трендов (последние N снапшотов)
	file.store_line("--- TREND HISTORY (last %d snapshots) ---" % _trend_history.size())
	for i in range(_trend_history.size()):
		var snap = _trend_history[i]
		file.store_line("  [%d] Day %d %02d:%02d | FPS: %d | Static: %.1f MB | PhysicsTime: %.2fms | Active: %d | Completed: %d" % [
			i + 1,
			snap.get("day", 0), snap.get("hour", 0), snap.get("minute", 0),
			snap.get("fps", 0),
			snap.get("static_mb", 0.0),
			snap.get("physics_ms", 0.0),
			snap.get("active_count", 0),
			snap.get("completed_count", 0)
		])
	file.store_line("")

	# Топ-3 самых больших коллекции
	if not _trend_history.is_empty():
		var last = _trend_history[_trend_history.size() - 1]
		var cols = last.get("collections", {})
		if not cols.is_empty():
			file.store_line("--- TOP COLLECTIONS ---")
			var sorted_cols = []
			for key in cols:
				sorted_cols.append({"name": key, "size": cols[key]})
			sorted_cols.sort_custom(func(a, b): return a["size"] > b["size"])
			var top3 = min(3, sorted_cols.size())
			for i in range(top3):
				file.store_line("  #%d %s: %d" % [i + 1, sorted_cols[i]["name"], sorted_cols[i]["size"]])
			file.store_line("")

	# Список всех проектов
	file.store_line("--- ALL PROJECTS ---")
	var state_names = ["DRAFTING", "IN_PROGRESS", "FINISHED", "FAILED"]
	if "active_projects" in ProjectManager:
		for proj in ProjectManager.active_projects:
			var sname = state_names[int(proj.state)] if int(proj.state) < state_names.size() else str(proj.state)
			file.store_line("  [active] %s | state=%s | deadline=%d" % [
				proj.title, sname, proj.deadline_day
			])
	if "completed_projects" in ProjectManager:
		for proj in ProjectManager.completed_projects:
			var sname = state_names[int(proj.state)] if int(proj.state) < state_names.size() else str(proj.state)
			file.store_line("  [done]   %s | state=%s | deadline=%d" % [
				proj.title, sname, proj.deadline_day
			])
	file.store_line("")

	# Список всех NPC
	file.store_line("--- ALL NPCs ---")
	var npc_nodes = get_tree().get_nodes_in_group("npc")
	for npc in npc_nodes:
		var npc_name = npc.data.employee_name if npc.data and "employee_name" in npc.data else "?"
		var npc_state = str(npc.current_state) if "current_state" in npc else "?"
		var mood_mods = npc.data.mood_temp_modifiers.size() if npc.data and "mood_temp_modifiers" in npc.data else 0
		file.store_line("  %s | state=%s | mood_mods=%d" % [npc_name, npc_state, mood_mods])
	file.store_line("")

	file.store_line("If you see this file, the game did NOT exit cleanly.")
	file.store_line("Send this file to the developer for diagnosis.")
	file.close()

func _cleanup_crash_report():
	if FileAccess.file_exists(CRASH_REPORT_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CRASH_REPORT_PATH))
