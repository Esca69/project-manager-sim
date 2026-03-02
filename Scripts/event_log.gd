extends Node

enum LogType { ROUTINE, PROGRESS, ALERT }

signal log_added(entry: Dictionary)
signal alert_added

const MAX_ENTRIES: int = 100

var entries: Array = []

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	if GameTime:
		GameTime.work_started.connect(clear)

func add(text: String, type: int = LogType.ROUTINE):
	var time_str = "[%02d:%02d]" % [GameTime.hour, GameTime.minute]
	var entry = {
		"text": time_str + " " + text,
		"type": type,
		"time_str": time_str
	}
	entries.append(entry)
	while entries.size() > MAX_ENTRIES:
		entries.pop_front()
	emit_signal("log_added", entry)
	if type == LogType.ALERT:
		emit_signal("alert_added")
	print(entry["text"])

func clear():
	entries.clear()
	add(tr("LOG_NEW_DAY"))
