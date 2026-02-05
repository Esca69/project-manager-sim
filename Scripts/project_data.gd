extends Resource
class_name ProjectData

@export var title: String = "Проект"

# --- ВРЕМЯ ---
@export var created_at_day: int = 1

# Дедлайн (номер дня, к которому надо успеть)
@export var deadline_day: int = 0

# [ВАЖНО] Точное время старта. Добавил @export, чтобы ты мог видеть его в редакторе (Remote)
@export var start_global_time: float = 0.0

# Сколько дней прошло с момента старта
var elapsed_days: float = 0.0

# --- СТРУКТУРА ЭТАПОВ ---
@export var stages: Array = []

@export var budget: int = 5000

enum State { DRAFTING, IN_PROGRESS, FINISHED, FAILED }
var state = State.DRAFTING
