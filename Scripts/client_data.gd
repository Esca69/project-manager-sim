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

# === УРОВНИ ЛОЯЛЬНОСТИ ===
# [порог_очков, тип_награды, значение_награды]
# тип: "budget" = бонус к бюджету (%), "unlock" = разблокировка типа проектов
const LOYALTY_LEVELS = [
	{"threshold": 0,  "type": "unlock",  "value": "micro",  "label": "Micro проекты"},
	{"threshold": 5,  "type": "budget",  "value": 5,        "label": "+5% к бюджету"},
	{"threshold": 12, "type": "unlock",  "value": "simple", "label": "Simple проекты"},
	{"threshold": 22, "type": "budget",  "value": 10,       "label": "+10% к бюджету"},
	{"threshold": 35, "type": "unlock",  "value": "easy",   "label": "Easy проекты"},
	{"threshold": 50, "type": "budget",  "value": 15,       "label": "+15% к бюджету"},
	{"threshold": 70, "type": "budget",  "value": 20,       "label": "+20% к бюджету"},
]

const MAX_LOYALTY: int = 70  # Максимальный порог

# ИСПРАВЛЕНИЕ: убрана типизация client: ClientData — циклическая ссылка при парсинге
signal loyalty_changed(client, old_value: int, new_value: int)

# === ТЕКУЩИЙ УРОВЕНЬ ЛОЯЛЬНОСТИ (0-6) ===
func get_loyalty_level() -> int:
	var level = 0
	for i in range(LOYALTY_LEVELS.size()):
		if loyalty >= LOYALTY_LEVELS[i]["threshold"]:
			level = i
	return level

# === БОНУС К БЮДЖЕТУ (НЕ суммируется — берём последний достигнутый) ===
func get_budget_bonus_percent() -> int:
	var bonus = 0
	for i in range(LOYALTY_LEVELS.size()):
		if loyalty >= LOYALTY_LEVELS[i]["threshold"]:
			if LOYALTY_LEVELS[i]["type"] == "budget":
				bonus = LOYALTY_LEVELS[i]["value"]
	return bonus

# === РАЗБЛОКИРОВАННЫЕ ТИПЫ ПРОЕКТОВ ===
func get_unlocked_project_types() -> Array[String]:
	var types: Array[String] = []
	for i in range(LOYALTY_LEVELS.size()):
		if loyalty >= LOYALTY_LEVELS[i]["threshold"]:
			if LOYALTY_LEVELS[i]["type"] == "unlock":
				types.append(LOYALTY_LEVELS[i]["value"])
	return types

# === ИНФОРМАЦИЯ О СЛЕДУЮЩЕМ УРОВНЕ ===
func get_next_level_info() -> Dictionary:
	# Возвращает {"threshold": int, "label": String} или {} если максимум
	var current_level = get_loyalty_level()
	if current_level >= LOYALTY_LEVELS.size() - 1:
		return {}  # Уже максимум
	var next = LOYALTY_LEVELS[current_level + 1]
	return {"threshold": next["threshold"], "label": next["label"]}

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
