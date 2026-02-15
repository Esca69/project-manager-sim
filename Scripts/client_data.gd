extends Resource
class_name ClientData

@export var client_id: String = ""
@export var client_name: String = ""
@export var emoji: String = ""
@export var description: String = ""

# === ЛОЯЛЬНОСТЬ ===
@export var loyalty: int = 0

# === СТАТИСТИКА ===
@export var projects_completed_on_time: int = 0   # Завершены до софт-дедлайна
@export var projects_completed_late: int = 0       # Завершены после софт, до хард
@export var projects_failed: int = 0               # Провалены (хард истёк)

# === ОЧКИ ЛОЯЛЬНОСТИ ЗА СОБЫТИЯ ===
const LOYALTY_ON_TIME: int = 3       # Завершён до софт-дедлайна
const LOYALTY_LATE: int = 1          # Завершён после софт, до хард
const LOYALTY_FAILED: int = -5       # Провален

# === ПОРОГИ БОНУСА К БЮДЖЕТУ ===
# [min_loyalty, bonus_percent]
const BUDGET_BONUS_TABLE = [
	[30, 25],
	[20, 20],
	[15, 15],
	[10, 10],
	[5, 5],
	[0, 0],
]

# ИСПРАВЛЕНИЕ: убрана типизация client: ClientData — циклическая ссылка при парсинге
signal loyalty_changed(client, old_value: int, new_value: int)

func get_budget_bonus_percent() -> int:
	for entry in BUDGET_BONUS_TABLE:
		if loyalty >= entry[0]:
			return entry[1]
	return 0

func get_next_bonus_threshold() -> Array:
	# Возвращает [next_threshold, next_bonus_percent] или [0, 0] если уже максимум
	for i in range(BUDGET_BONUS_TABLE.size()):
		var entry = BUDGET_BONUS_TABLE[i]
		if loyalty >= entry[0]:
			if i == 0:
				return [0, 0]  # Уже на максимуме
			var prev = BUDGET_BONUS_TABLE[i - 1]
			return [prev[0], prev[1]]
	# Ниже всех порогов — следующий порог это последний в таблице (5, 5%)
	var last = BUDGET_BONUS_TABLE[BUDGET_BONUS_TABLE.size() - 2]
	return [last[0], last[1]]

func get_total_projects() -> int:
	return projects_completed_on_time + projects_completed_late + projects_failed

func add_loyalty(amount: int):
	var old = loyalty
	loyalty += amount
	emit_signal("loyalty_changed", self, old, loyalty)

func record_project_on_time():
	projects_completed_on_time += 1
	add_loyalty(LOYALTY_ON_TIME)

func record_project_late():
	projects_completed_late += 1
	add_loyalty(LOYALTY_LATE)

func record_project_failed():
	projects_failed += 1
	add_loyalty(LOYALTY_FAILED)

func get_display_name() -> String:
	return emoji + " " + client_name
