extends Node

# === BOSS EVENT SYSTEM — autoload singleton ===
# Управляет жизненным циклом ивентов босса:
# IDLE → PENDING (генерация в 10:00) → ACTIVE (принятие) → IDLE (окончание)

enum State {
	IDLE,    # Нет ивента, кулдаун может тикать
	PENDING, # Ивент сгенерирован, ожидает реакции игрока (до 18:00)
	ACTIVE,  # Ивент принят, эффект действует N дней
}

const EXCLUDED_EVENT_IDS = ["boss_event_overtime", "boss_event_reshuffle"]

const BOSS_EVENTS = {
	"boss_event_daily_reports": {
		"title_key": "EVENT_DAILY_REPORT_TITLE",
		"desc_key": "EVENT_DAILY_REPORT_DESC",
		"emoji": "📊",
		"min_days": 7,
		"max_days": 14,
		"trust_accept": 0,
		"trust_reject": -10,
		"trust_ignore": -20,
	},
	"boss_event_no_lunch": {
		"title_key": "EVENT_NO_LUNCH_TITLE",
		"desc_key": "EVENT_NO_LUNCH_DESC",
		"emoji": "🍽️",
		"min_days": 7,
		"max_days": 14,
		"trust_accept": 0,
		"trust_reject": -10,
		"trust_ignore": -20,
	},
	"boss_event_total_communication": {
		"title_key": "BOSS_EVENT_TOTAL_COMM_TITLE",
		"desc_key": "BOSS_EVENT_TOTAL_COMM_DESC",
		"emoji": "🗣️",
		"min_days": 7,
		"max_days": 14,
		"trust_accept": 0,
		"trust_reject": -10,
		"trust_ignore": -20,
	},
	"boss_event_overtime": {
		"title_key": "BOSS_EVENT_OVERTIME_TITLE",
		"desc_key": "BOSS_EVENT_OVERTIME_DESC",
		"emoji": "⏰",
		"min_days": 2,
		"max_days": 5,
		"trust_accept": 3,
		"trust_reject": -1,
		"trust_ignore": -20,
	},
	"boss_event_reshuffle": {
		"title_key": "BOSS_EVENT_RESHUFFLE_TITLE",
		"desc_key": "BOSS_EVENT_RESHUFFLE_DESC",
		"emoji": "🔀",
		"min_days": 0,
		"max_days": 0,
		"trust_accept": 2,
		"trust_reject": -2,
		"trust_ignore": -20,
	},
	"boss_event_we_are_family": {
		"title_key": "BOSS_EVENT_FAMILY_TITLE",
		"desc_key": "BOSS_EVENT_FAMILY_DESC",
		"emoji": "👨‍👩‍👧‍👦",
		"min_days": 7,
		"max_days": 14,
		"trust_accept": 0,
		"trust_reject": -10,
		"trust_ignore": -20,
	},
	"boss_event_no_hiring": {
		"title_key": "EVENT_NO_HIRING_TITLE",
		"desc_key": "EVENT_NO_HIRING_DESC",
		"emoji": "🚫",
		"min_days": 7,
		"max_days": 14,
		"trust_accept": 0,
		"trust_reject": -10,
		"trust_ignore": -10,
	},
}

# === СИГНАЛЫ ===
signal boss_event_generated(event_id: String)
signal boss_event_accepted(event_id: String)
signal boss_event_rejected(event_id: String)
signal boss_event_ended(event_id: String)
signal boss_event_ignored()

# === СОСТОЯНИЕ ===
var state: int = State.IDLE
var pending_event_id: String = ""
var active_event_id: String = ""
var active_days_remaining: int = 0
var cooldown_days: int = 0
var recent_event_ids: Array = []  # последние 2 ивента (для антиповтора)
var ignore_penalty_pending: bool = false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameTime.time_tick.connect(_on_time_tick)
	GameTime.day_started.connect(_on_day_started)

# ============================================================
#                     ГЕНЕРАЦИЯ / ИГНОР
# ============================================================

func _on_time_tick(hour: int, minute: int):
	# Генерация в 10:09 рабочего дня (ровно один раз в день)
	if hour == 10 and minute == 9 and state == State.IDLE and cooldown_days == 0:
		if not GameTime.is_weekend():
			_try_generate_event()
	# Игнор в 18:00 если ещё ожидается
	elif hour == 18 and state == State.PENDING:
		_on_ignore()
	# Ежедневные отчёты: триггер 17:00
	if hour == 17 and minute == 0 and state == State.ACTIVE and active_event_id == "boss_event_daily_reports":
		if not GameTime.is_weekend():
			_trigger_daily_reports()
	# Ежедневные отчёты: завершение 17:45
	if hour == 17 and minute == 45 and state == State.ACTIVE and active_event_id == "boss_event_daily_reports":
		if not GameTime.is_weekend():
			_end_daily_reports_session()

func _try_generate_event():
	if randf() > 0.4:
		return
	var available = []
	for eid in BOSS_EVENTS.keys():
		if eid in EXCLUDED_EVENT_IDS:
			continue
		if not recent_event_ids.has(eid):
			available.append(eid)
	if available.is_empty():
		# Фоллбэк — без excluded и без антиповтора
		for eid in BOSS_EVENTS.keys():
			if eid not in EXCLUDED_EVENT_IDS:
				available.append(eid)
	if available.is_empty():
		return
	var chosen_id: String = available[randi() % available.size()]
	state = State.PENDING
	pending_event_id = chosen_id
	emit_signal("boss_event_generated", chosen_id)
	var event = BOSS_EVENTS[chosen_id]
	EventLog.add(tr("BOSS_EVENT_LOG_GENERATED") % tr(event["title_key"]), EventLog.LogType.ALERT)

func _on_ignore():
	var event = BOSS_EVENTS.get(pending_event_id, {})
	if event.is_empty():
		state = State.IDLE
		pending_event_id = ""
		cooldown_days = randi_range(7, 14)
		emit_signal("boss_event_ignored")
		return
	BossManager.change_trust(event["trust_ignore"])
	state = State.IDLE
	pending_event_id = ""
	cooldown_days = randi_range(7, 14)
	emit_signal("boss_event_ignored")
	EventLog.add(tr("BOSS_EVENT_LOG_IGNORED"), EventLog.LogType.ALERT)

# ============================================================
#                     ПРИНЯТИЕ / ОТКЛОНЕНИЕ
# ============================================================

func accept_event():
	if state != State.PENDING or pending_event_id == "":
		return
	var event_id = pending_event_id
	var event = BOSS_EVENTS[event_id]
	BossManager.change_trust(event["trust_accept"])
	active_event_id = event_id
	pending_event_id = ""
	_add_to_recent(event_id)
	cooldown_days = randi_range(7, 14)
	var days = randi_range(event["min_days"], event["max_days"])
	if days <= 0:
		state = State.IDLE
		active_days_remaining = 0
	else:
		state = State.ACTIVE
		active_days_remaining = days
	emit_signal("boss_event_accepted", event_id)
	_apply_event_effects(event_id)
	EventLog.add(tr("BOSS_EVENT_LOG_ACCEPTED") % tr(event["title_key"]), EventLog.LogType.ALERT)
	# Если мгновенный ивент — сразу завершаем
	if days <= 0:
		_end_active_event()

func reject_event():
	if state != State.PENDING or pending_event_id == "":
		return
	var event_id = pending_event_id
	var event = BOSS_EVENTS[event_id]
	BossManager.change_trust(event["trust_reject"])
	state = State.IDLE
	pending_event_id = ""
	cooldown_days = randi_range(7, 14)
	emit_signal("boss_event_rejected", event_id)
	EventLog.add(tr("BOSS_EVENT_LOG_REJECTED") % tr(event["title_key"]), EventLog.LogType.ALERT)
	_on_reject_custom_log(event_id)

# ============================================================
#                     ТИК ДНЯ
# ============================================================

func _on_day_started():
	# Кулдаун тикает КАЖДЫЙ день (включая выходные) — календарные дни
	if cooldown_days > 0:
		cooldown_days -= 1

	# Остальная логика — только рабочие дни
	if GameTime.is_weekend():
		return
	if state == State.ACTIVE:
		active_days_remaining -= 1
		if active_days_remaining <= 0:
			_end_active_event()

func _end_active_event():
	var ended_id = active_event_id
	_remove_event_effects(ended_id)
	emit_signal("boss_event_ended", ended_id)
	var event = BOSS_EVENTS.get(ended_id, {})
	if not event.is_empty():
		EventLog.add(tr("BOSS_EVENT_LOG_ENDED") % tr(event["title_key"]), EventLog.LogType.PROGRESS)
	state = State.IDLE
	active_event_id = ""
	active_days_remaining = 0

# ============================================================
#                     ВСПОМОГАТЕЛЬНЫЕ
# ============================================================

func _add_to_recent(event_id: String):
	recent_event_ids.append(event_id)
	while recent_event_ids.size() > 2:
		recent_event_ids.pop_front()

# ============================================================
#                     ЗАГЛУШКИ ЭФФЕКТОВ
# ============================================================

func _apply_event_effects(event_id: String) -> void:
	match event_id:
		"boss_event_daily_reports":
			_apply_daily_reports()
		"boss_event_no_lunch":
			_apply_no_lunch()
		"boss_event_total_communication":
			_apply_total_communication()
		"boss_event_overtime": pass       # PR #3
		"boss_event_reshuffle": pass      # PR #2
		"boss_event_we_are_family":
			_apply_we_are_family()
		"boss_event_no_hiring":
			_apply_no_hiring()

func _apply_daily_reports():
	pass  # No immediate effect at accept time — 17:00 trigger handles sessions

func _remove_daily_reports():
	# Force end any active report sessions when event ends
	var npcs = get_tree().get_nodes_in_group("npc")
	for npc in npcs:
		if npc.has_method("force_end_report"):
			npc.force_end_report()
	EventLog.add(tr("LOG_DAILY_REPORTS_ENDED"), EventLog.LogType.PROGRESS)

func _trigger_daily_reports():
	var npcs = get_tree().get_nodes_in_group("npc")
	for npc in npcs:
		if npc.has_method("force_start_report"):
			npc.force_start_report()
	EventLog.add(tr("LOG_DAILY_REPORTS_STARTED"), EventLog.LogType.PROGRESS)

func _end_daily_reports_session():
	var npcs = get_tree().get_nodes_in_group("npc")
	for npc in npcs:
		if npc.has_method("force_end_report"):
			npc.force_end_report()

func _apply_total_communication():
	EventLog.add(tr("BOSS_EVENT_TOTAL_COMM_LOG_START"), EventLog.LogType.ALERT)

func _apply_we_are_family():
	EventLog.add(tr("BOSS_EVENT_FAMILY_LOG_START"), EventLog.LogType.ALERT)

func _apply_no_hiring():
	EventLog.add(tr("LOG_NO_HIRING_EVENT_START"), EventLog.LogType.ALERT)

func _apply_no_lunch():
	var npcs = get_tree().get_nodes_in_group("npc")
	for npc in npcs:
		if npc.has_method("force_cancel_lunch"):
			npc.force_cancel_lunch()
	EventLog.add(tr("LOG_NO_LUNCH_EVENT_START"), EventLog.LogType.ALERT)

func _remove_event_effects(event_id: String) -> void:
	match event_id:
		"boss_event_daily_reports":
			_remove_daily_reports()
		"boss_event_no_lunch":
			_remove_no_lunch()
		"boss_event_total_communication":
			_remove_total_communication()
		"boss_event_overtime": pass
		"boss_event_reshuffle": pass
		"boss_event_we_are_family":
			_remove_we_are_family()
		"boss_event_no_hiring":
			_remove_no_hiring()

func _remove_total_communication():
	# Убрать mood-модификаторы у всех сотрудников
	var npcs = get_tree().get_nodes_in_group("npc")
	for npc in npcs:
		if npc.data and npc.data is EmployeeData:
			npc.data.remove_mood_modifier("boss_event_comm_extrovert")
			npc.data.remove_mood_modifier("boss_event_comm_introvert")
	EventLog.add(tr("BOSS_EVENT_TOTAL_COMM_LOG_END"), EventLog.LogType.PROGRESS)

func _remove_we_are_family():
	EventLog.add(tr("BOSS_EVENT_FAMILY_LOG_END"), EventLog.LogType.PROGRESS)

func _remove_no_hiring():
	EventLog.add(tr("LOG_NO_HIRING_EVENT_SUCCESS"), EventLog.LogType.PROGRESS)

func _remove_no_lunch():
	EventLog.add(tr("LOG_NO_LUNCH_ENDED"), EventLog.LogType.PROGRESS)

func _on_reject_custom_log(event_id: String):
	match event_id:
		"boss_event_daily_reports":
			EventLog.add(tr("LOG_DAILY_REPORTS_REJECTED"), EventLog.LogType.PROGRESS)
		"boss_event_total_communication":
			EventLog.add(tr("BOSS_EVENT_TOTAL_COMM_LOG_REJECT"), EventLog.LogType.ALERT)
		"boss_event_we_are_family":
			EventLog.add(tr("BOSS_EVENT_FAMILY_LOG_REJECT"), EventLog.LogType.PROGRESS)
		"boss_event_no_hiring":
			EventLog.add(tr("LOG_NO_HIRING_EVENT_REJECTED"), EventLog.LogType.PROGRESS)
		"boss_event_no_lunch":
			EventLog.add(tr("LOG_NO_LUNCH_REJECTED"), EventLog.LogType.PROGRESS)

# === УНИВЕРСАЛЬНОЕ ПРЕРЫВАНИЕ ИВЕНТА ИЗВНЕ ===
func abort_active_event(penalty: int, log_message: String):
	if state != State.ACTIVE or active_event_id == "":
		return
	_remove_event_effects(active_event_id)
	BossManager.change_trust(penalty)
	EventLog.add(log_message, EventLog.LogType.ALERT)
	state = State.IDLE
	active_event_id = ""
	active_days_remaining = 0
	cooldown_days = randi_range(7, 14)

# ============================================================
#                     ГЕТТЕРЫ
# ============================================================

func is_boss_event_active(event_id: String = "") -> bool:
	if event_id == "":
		return state == State.ACTIVE
	return state == State.ACTIVE and active_event_id == event_id

func get_active_event_id() -> String:
	return active_event_id

func get_pending_event_id() -> String:
	return pending_event_id

func get_active_event_data() -> Dictionary:
	if active_event_id == "":
		return {}
	return BOSS_EVENTS.get(active_event_id, {})

func get_pending_event_data() -> Dictionary:
	if pending_event_id == "":
		return {}
	return BOSS_EVENTS.get(pending_event_id, {})

func has_pending_event() -> bool:
	return state == State.PENDING and pending_event_id != ""

# ============================================================
#                     СЕРИАЛИЗАЦИЯ
# ============================================================

func serialize() -> Dictionary:
	return {
		"state": state,
		"pending_event_id": pending_event_id,
		"active_event_id": active_event_id,
		"active_days_remaining": active_days_remaining,
		"cooldown_days": cooldown_days,
		"recent_event_ids": recent_event_ids.duplicate(),
		"ignore_penalty_pending": ignore_penalty_pending,
	}

func deserialize(d: Dictionary):
	state = int(d.get("state", State.IDLE))
	pending_event_id = str(d.get("pending_event_id", ""))
	active_event_id = str(d.get("active_event_id", ""))
	active_days_remaining = int(d.get("active_days_remaining", 0))
	cooldown_days = int(d.get("cooldown_days", 0))
	recent_event_ids.clear()
	for eid in d.get("recent_event_ids", []):
		recent_event_ids.append(str(eid))
	ignore_penalty_pending = d.get("ignore_penalty_pending", false)
