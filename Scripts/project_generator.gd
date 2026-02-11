extends Node
class_name ProjectGenerator

const HOURLY_RATE = {
	"BA": 15,
	"DEV": 22,
	"QA": 12,
}

const AVERAGE_SKILL = 100.0
const WORK_HOURS_PER_DAY = 9.0
const MARGIN_MULTIPLIER = 1.4

# === ШАБЛОНЫ ПРОЕКТОВ ===

const MICRO_TEMPLATES = [
	{ "name": "Фикс бага на сайте",            "stages": ["DEV"],        "difficulty": 1 },
	{ "name": "Протестировать форму",           "stages": ["QA"],         "difficulty": 1 },
	{ "name": "Составить ТЗ на лендинг",        "stages": ["BA"],         "difficulty": 1 },
	{ "name": "Описать и сделать FAQ",          "stages": ["BA", "DEV"],  "difficulty": 1 },
	{ "name": "Написать и протестить API",       "stages": ["DEV", "QA"],  "difficulty": 1 },
	{ "name": "Поправить вёрстку письма",        "stages": ["DEV"],        "difficulty": 1 },
	{ "name": "Тестирование авторизации",        "stages": ["QA"],         "difficulty": 1 },
	{ "name": "Анализ конкурентов",              "stages": ["BA"],         "difficulty": 1 },
	{ "name": "Описание + правка формы",         "stages": ["BA", "DEV"],  "difficulty": 1 },
	{ "name": "Доработка + тест фильтров",       "stages": ["DEV", "QA"],  "difficulty": 1 },
]

const SIMPLE_TEMPLATES = [
	{ "name": "Лендинг пекарни",     "stages": ["BA", "DEV", "QA"], "difficulty": 2 },
	{ "name": "Сайт-визитка",        "stages": ["BA", "DEV", "QA"], "difficulty": 2 },
	{ "name": "CRM для такси",       "stages": ["BA", "DEV", "QA"], "difficulty": 2 },
	{ "name": "Модуль авторизации",   "stages": ["BA", "DEV", "QA"], "difficulty": 2 },
	{ "name": "Интернет-магазин",     "stages": ["BA", "DEV", "QA"], "difficulty": 2 },
	{ "name": "Портал заказов",       "stages": ["BA", "DEV", "QA"], "difficulty": 2 },
	{ "name": "Чат поддержки",        "stages": ["BA", "DEV", "QA"], "difficulty": 2 },
	{ "name": "Дашборд статистики",   "stages": ["BA", "DEV", "QA"], "difficulty": 2 },
]

const WORK_UNITS = {
	"micro": {
		"BA":  [400, 800],
		"DEV": [600, 1200],
		"QA":  [300, 700],
	},
	"simple": {
		"BA":  [1000, 2000],
		"DEV": [2000, 4000],
		"QA":  [800, 1600],
	},
}

const SOFT_PENALTIES = [10, 20, 30]

# === МИНИМАЛЬНЫЕ ДЕДЛАЙНЫ ===
const MIN_HARD_DEADLINE_DAYS = {
	"micro": 3,
	"simple": 5,
}

static func generate_random_project(current_game_day: int) -> ProjectData:
	var new_proj = ProjectData.new()
	new_proj.created_at_day = current_game_day
	new_proj.state = new_proj.State.DRAFTING
	
	# 1. Выбираем категорию (60% micro, 40% simple)
	var category: String
	var template: Dictionary
	
	if randf() < 0.60:
		category = "micro"
		template = MICRO_TEMPLATES.pick_random()
	else:
		category = "simple"
		template = SIMPLE_TEMPLATES.pick_random()
	
	new_proj.category = category
	new_proj.title = template["name"]
	
	# 2. Генерируем этапы
	var stage_types: Array = template["stages"]
	new_proj.stages = []
	
	var total_estimated_cost: float = 0.0
	var total_ideal_hours: float = 0.0
	
	for stage_type in stage_types:
		var units_range = WORK_UNITS[category][stage_type]
		var work_units = randi_range(units_range[0], units_range[1])
		
		new_proj.stages.append({
			"type": stage_type,
			"amount": work_units,
			"progress": 0.0,
			"workers": [],
			"plan_start": 0.0,
			"plan_duration": 0.0,
			"actual_start": -1.0,
			"actual_end": -1.0,
			"is_completed": false,
		})
		
		var ideal_hours = float(work_units) / AVERAGE_SKILL
		total_ideal_hours += ideal_hours
		total_estimated_cost += ideal_hours * HOURLY_RATE[stage_type]
	
	# 3. Бюджет
	var budget_raw = total_estimated_cost * MARGIN_MULTIPLIER
	budget_raw *= randf_range(0.9, 1.1)
	new_proj.budget = int(round(budget_raw / 50.0)) * 50
	
	# 4. Штраф за софт-дедлайн
	new_proj.soft_deadline_penalty_percent = SOFT_PENALTIES.pick_random()
	
	# 5. Хард-дедлайн
	var ideal_days = total_ideal_hours / WORK_HOURS_PER_DAY
	var buffer_coef = randf_range(1.3, 1.7)
	var days_given = ceil(ideal_days * buffer_coef)
	
	# [ПУНКТ 1] Минимальный дедлайн по категории
	var min_days = MIN_HARD_DEADLINE_DAYS[category]
	if days_given < min_days:
		days_given = min_days
	
	new_proj.deadline_day = current_game_day + int(days_given)
	
	# 6. Софт-дедлайн
	var soft_coef = randf_range(0.60, 0.75)
	var soft_days = ceil(days_given * soft_coef)
	
	# [ПУНКТ 4] Софт ВСЕГДА минимум на 1 день раньше хард
	if soft_days >= days_given:
		soft_days = days_given - 1
	if soft_days < 1:
		soft_days = 1
	
	new_proj.soft_deadline_day = current_game_day + int(soft_days)
	
	return new_proj
