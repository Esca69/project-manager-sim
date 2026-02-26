extends Resource
class_name ProjectData

# Меняем дефолтное значение на ключ
@export var title: String = "PROJ_DEFAULT_TITLE"

# --- КАТЕГОРИЯ ---
# "micro" = 1 этап, "simple" = 2 этапа, "easy" = 3 этапа (BA→DEV→QA)
@export var category: String = "simple"

# --- КЛИЕНТ ---
@export var client_id: String = ""

# --- ВРЕМЯ ---
@export var created_at_day: int = 1
@export var deadline_day: int = 0
@export var soft_deadline_day: int = 0
@export var start_global_time: float = 0.0
var elapsed_days: float = 0.0

# --- БЮДЖЕТ ДНЕЙ (сколько дней даётся на проект, без привязки к дате) ---
@export var hard_days_budget: int = 0
@export var soft_days_budget: int = 0

# --- СТРУКТУРА ЭТ��ПОВ ---
@export var stages: Array = []

# --- ФИНАНСЫ ---
@export var budget: int = 5000

# Штраф за просрочку софт-дедлайна (процент от бюджета: 10, 20 или 30)
@export var soft_deadline_penalty_percent: int = 10

# --- АНАЛИТИКА: ЗАТРАТЫ НА РАБОЧУЮ СИЛУ ---
# Суммарные затраты за всё время проекта (накопительно)
var total_labor_cost: float = 0.0
# Затраты за сегодняшний день (сбрасывается в начале рабочего дня)
var daily_labor_cost: float = 0.0

enum State { DRAFTING, IN_PROGRESS, FINISHED, FAILED }
var state = State.DRAFTING

# Вычисляем итоговую выплату при завершении
func get_final_payout(finish_day: int) -> int:
	# Провал хард-дедлайна — $0
	if finish_day >= deadline_day:
		return 0
	# Просрочка софт-дедлайна — штраф
	if finish_day >= soft_deadline_day:
		var penalty = int(budget * soft_deadline_penalty_percent / 100.0)
		return budget - penalty
	# Успели до софта — полный бюджет
	return budget

# Проверка: завершён ли вовремя (до софт-дедлайна)
func is_finished_on_time(finish_day: int) -> bool:
	return finish_day < soft_deadline_day

# Прибыль/убыток: выплата минус затраты на рабочую силу
func get_profit(finish_day: int) -> int:
	return get_final_payout(finish_day) - int(total_labor_cost)

# Получить данные клиента
func get_client():
	if client_id == "":
		return null
	var cm = Engine.get_main_loop().root.get_node_or_null("/root/ClientManager")
	if cm:
		return cm.get_client_by_id(client_id)
	return null

func get_client_display_name() -> String:
	var client = get_client()
	if client:
		return client.get_display_name()
	return tr("PROJ_UNKNOWN_CLIENT")

# Метка категории для UI
func get_category_label() -> String:
	match category:
		"micro": return tr("PROJ_CAT_MICRO")
		"simple": return tr("PROJ_CAT_SIMPLE")
		"easy": return tr("PROJ_CAT_EASY")
	return tr("PROJ_CAT_UNKNOWN")
