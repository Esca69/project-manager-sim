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
	var month = 1
	var day_in_month = 1
	
	if GameTime and GameTime.has_method("get_month"):
		month = GameTime.get_month(GameTime.day)
		day_in_month = GameTime.get_day_in_month(GameTime.day)
	elif GameTime:
		day_in_month = GameTime.day

	# ИСПРАВЛЕНИЕ 1: Теперь выводит [мес 1 день 12 | 10:05]
	var time_str = "[%s %d %s %d | %02d:%02d]" % [
		tr("LOG_MONTH"), month, 
		tr("LOG_DAY"), day_in_month, 
		GameTime.hour, GameTime.minute
	]
	
	var entry = {
		"text": time_str + " " + text,
		"type": type,
		"time_str": time_str
	}
	entries.push_front(entry)
	while entries.size() > MAX_ENTRIES:
		entries.pop_back()
	emit_signal("log_added", entry)
	if type == LogType.ALERT:
		emit_signal("alert_added")
	print(entry["text"])

func clear():
	entries.clear()
	add(tr("LOG_NEW_DAY"))
