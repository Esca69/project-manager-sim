extends Resource
class_name ClientData

@export var client_id: String = ""
@export var client_name: String = ""
@export var emoji: String = ""
@export var description: String = ""

# === УЛУЧШЕНИЯ КЛИЕНТА ===
@export var budget_level: int = 0   # 0–6, каждый уровень = +5% к бюджету
@export var has_simple: bool = false
@export var has_easy: bool = false
@export var has_support: bool = false

# === СТОИМОСТЬ УЛУЧШЕНИЙ ===
const BUDGET_UPGRADE_COST: int = 5
const MAX_BUDGET_LEVEL: int = 6
const SIMPLE_UNLOCK_COST: int = 10
const EASY_UNLOCK_COST: int = 20
const SUPPORT_UNLOCK_COST: int = 15

# === СТАТИСТИКА ===
@export var projects_completed_on_time: int = 0   # Завершены до софт-дедлайна
@export var projects_completed_late: int = 0       # Завершены после софт, до хард
@export var projects_failed: int = 0               # Провалены (хард истёк)

# === БОНУС К БЮДЖЕТУ ===
func get_budget_bonus_percent() -> int:
	return budget_level * 5

# === РАЗБЛОКИРОВАННЫЕ ТИПЫ ПРОЕКТОВ ===
func get_unlocked_project_types() -> Array[String]:
	var types: Array[String] = ["micro"]
	if has_simple:
		types.append("simple")
	if has_easy:
		types.append("easy")
	if has_support:
		types.append("support")
	return types

func get_total_projects() -> int:
	return projects_completed_on_time + projects_completed_late + projects_failed

func record_project_on_time():
	projects_completed_on_time += 1

func record_project_late():
	projects_completed_late += 1

func record_project_failed():
	projects_failed += 1

# Геттеры для динамического перевода имени и описания
func get_display_name() -> String:
	return emoji + " " + tr(client_name)

func get_display_desc() -> String:
	return tr(description)
