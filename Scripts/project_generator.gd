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

# === ШАБЛОНЫ ПРОЕКТОВ (используем ключи из CSV) ===

# MICRO — 1 вид работ
const MICRO_TEMPLATES = [
	{ "name": "PROJ_FIX_BUG",            "stages": ["DEV"],  "difficulty": 1 },
	{ "name": "PROJ_TEST_FORM",           "stages": ["QA"],   "difficulty": 1 },
	{ "name": "PROJ_WRITE_TZ",           "stages": ["BA"],   "difficulty": 1 },
	{ "name": "PROJ_FIX_LAYOUT",         "stages": ["DEV"],  "difficulty": 1 },
	{ "name": "PROJ_TEST_AUTH",          "stages": ["QA"],   "difficulty": 1 },
	{ "name": "PROJ_COMPETITOR_ANALYSIS", "stages": ["BA"],   "difficulty": 1 },
]

# SIMPLE — 2 вида работ
const SIMPLE_TEMPLATES = [
	{ "name": "PROJ_FAQ",             "stages": ["BA", "DEV"],  "difficulty": 2 },
	{ "name": "PROJ_API",             "stages": ["DEV", "QA"],  "difficulty": 2 },
	{ "name": "PROJ_FORM_DESC",       "stages": ["BA", "DEV"],  "difficulty": 2 },
	{ "name": "PROJ_FILTERS",         "stages": ["DEV", "QA"],  "difficulty": 2 },
	{ "name": "PROJ_MODULE_TEST",     "stages": ["BA", "QA"],   "difficulty": 2 },
	{ "name": "PROJ_REPORT",          "stages": ["BA", "DEV"],  "difficulty": 2 },
]

# EASY — 3 вида работ (полный цикл BA→DEV→QA)
const EASY_TEMPLATES = [
	{ "name": "PROJ_LANDING",      "stages": ["BA", "DEV", "QA"], "difficulty": 3 },
	{ "name": "PROJ_SITE_CARD",    "stages": ["BA", "DEV", "QA"], "difficulty": 3 },
	{ "name": "PROJ_CRM_TAXI",     "stages": ["BA", "DEV", "QA"], "difficulty": 3 },
	{ "name": "PROJ_AUTH_MODULE",  "stages": ["BA", "DEV", "QA"], "difficulty": 3 },
	{ "name": "PROJ_SHOP",         "stages": ["BA", "DEV", "QA"], "difficulty": 3 },
	{ "name": "PROJ_ORDERS",       "stages": ["BA", "DEV", "QA"], "difficulty": 3 },
	{ "name": "PROJ_CHAT",         "stages": ["BA", "DEV", "QA"], "difficulty": 3 },
	{ "name": "PROJ_DASHBOARD",    "stages": ["BA", "DEV", "QA"], "difficulty": 3 },
]

# WORK_UNITS: micro увеличены x1.5
const WORK_UNITS = {
	"micro": {
		"BA":  [600, 1200],
		"DEV": [900, 1800],
		"QA":  [450, 1050],
	},
	"simple": {
		"BA":  [600, 1200],
		"DEV": [1000, 2000],
		"QA":  [500, 1000],
	},
	"easy": {
		"BA":  [1000, 2000],
		"DEV": [2000, 4000],
		"QA":  [800, 1600],
	},
}

const SOFT_PENALTIES = [10, 20, 30]

# === МИНИМАЛЬНЫЕ ДЕДЛАЙНЫ ===
const MIN_HARD_DEADLINE_DAYS = {
	"micro": 4,
	"simple": 5,
	"easy": 8,
}

# === ВЕСА ГЕНЕРАЦИИ ТИПОВ ПО ДОСТУПНЫМ КАТЕГОРИЯМ ===
const TYPE_WEIGHTS = {
	"micro": {"micro": 1.0},
	"micro_simple": {"micro": 0.40, "simple": 0.60},
	"simple_easy": {"simple": 0.55, "easy": 0.45},
}

static func generate_random_project(current_game_day: int, client: ClientData = null) -> ProjectData:
	var new_proj = ProjectData.new()
	new_proj.created_at_day = current_game_day
	new_proj.state = new_proj.State.DRAFTING

	if client == null:
		client = ClientManager.get_random_client()
	if client:
		new_proj.client_id = client.client_id

	var available_types: Array[String] = ["micro"]
	if client:
		available_types = client.get_unlocked_project_types()
	if available_types.is_empty():
		available_types = ["micro"]

	var category = _pick_category_by_weights(available_types)
	var template: Dictionary

	match category:
		"micro":
			template = MICRO_TEMPLATES.pick_random()
		"simple":
			template = SIMPLE_TEMPLATES.pick_random()
		"easy":
			template = EASY_TEMPLATES.pick_random()
		_:
			category = "micro"
			template = MICRO_TEMPLATES.pick_random()

	new_proj.category = category
	
	# ИСПРАВЛЕНИЕ: Используем TranslationServer для статической функции
	new_proj.title = TranslationServer.translate(template["name"])

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

	var budget_raw = total_estimated_cost * MARGIN_MULTIPLIER
	budget_raw *= randf_range(0.9, 1.1)

	if client:
		var bonus = client.get_budget_bonus_percent()
		if bonus > 0:
			budget_raw *= (1.0 + float(bonus) / 100.0)

	new_proj.budget = int(round(budget_raw / 50.0)) * 50

	new_proj.soft_deadline_penalty_percent = SOFT_PENALTIES.pick_random()

	# === РАССЧИТЫВАЕМ БЮДЖЕТ ДНЕЙ (относительные, без привязки к дате) ===
	var ideal_days = total_ideal_hours / WORK_HOURS_PER_DAY
	var buffer_coef = randf_range(1.3, 1.7)
	var days_given = ceil(ideal_days * buffer_coef)

	var min_days = MIN_HARD_DEADLINE_DAYS[category]
	if days_given < min_days:
		days_given = min_days

	new_proj.hard_days_budget = int(days_given)

	var soft_coef = randf_range(0.60, 0.75)
	var soft_days = ceil(days_given * soft_coef)

	if soft_days >= days_given:
		soft_days = days_given - 1
	if soft_days < 1:
		soft_days = 1

	new_proj.soft_days_budget = int(soft_days)

	new_proj.deadline_day = 0
	new_proj.soft_deadline_day = 0

	return new_proj

static func _pick_category_by_weights(available_types: Array[String]) -> String:
	var key: String
	if available_types.has("easy"):
		key = "simple_easy"
	elif available_types.has("simple"):
		key = "micro_simple"
	else:
		key = "micro"

	var weights = TYPE_WEIGHTS[key]
	var roll = randf()
	var cumulative = 0.0

	for type_name in weights:
		cumulative += weights[type_name]
		if roll <= cumulative:
			return type_name

	return weights.keys()[weights.size() - 1]
