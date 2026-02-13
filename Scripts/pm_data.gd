extends Resource
class_name ProjectData

@export var title: String = "Проект"

# --- КАТЕГОРИЯ ---
@export var category: String = "simple"

# --- ВРЕМЯ ---
@export var created_at_day: int = 1
@export var deadline_day: int = 0
@export var soft_deadline_day: int = 0
@export var start_global_time: float = 0.0
var elapsed_days: float = 0.0

# --- СТРУКТУРА ЭТАПОВ ---
@export var stages: Array = []

# --- ФИНАНСЫ ---
@export var budget: int = 5000

@export var soft_deadline_penalty_percent: int = 10

enum State { DRAFTING, IN_PROGRESS, FINISHED, FAILED }
var state = State.DRAFTING

func get_final_payout(finish_day: int) -> int:
	if finish_day >= deadline_day:
		return 0
	if finish_day >= soft_deadline_day:
		var penalty = int(budget * soft_deadline_penalty_percent / 100.0)
		return budget - penalty
	return budget
