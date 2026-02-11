extends Resource
class_name EmployeeData

@export var employee_name: String = "Новичок"
@export var job_title: String = "Junior Developer"
@export var monthly_salary: int = 3000

var current_energy: float = 100.0

# --- СИСТЕМА ТРЕЙТОВ ---
@export var traits: Array[String] = []
@export var trait_text: String = ""

# Полный словарь трейтов
const TRAIT_NAMES = {
	# Положительные
	"fast_learner": "🧠 Быстрый ум",
	"energizer": "⚡ Энерджайзер",
	"early_bird": "🐦 Ранняя пташка",
	"cheap_hire": "💰 Скромный",
	# Отрицательные
	"toilet_lover": "🚽 Любит покакать",
	"coffee_lover": "☕ Кофеман",
	"slowpoke": "🐌 Тормоз",
	"expensive": "💸 Зазнайка",
}

# Описания для тултипов (что делает трейт)
const TRAIT_DESCRIPTIONS = {
	"fast_learner": "+20% к скорости работы на этапах проекта",
	"energizer": "Энергия тратится на 30% медленнее",
	"early_bird": "Приходит на работу на 30-40 минут раньше",
	"cheap_hire": "Зарплата на 15% ниже",
	"toilet_lover": "Сидит в туалете в 2 раза дольше",
	"coffee_lover": "Кофе-брейк длится в 2 раза дольше",
	"slowpoke": "-20% к скорости работы на этапах проекта",
	"expensive": "Зарплата на 20% выше",
}

# Какие трейты положительные
const POSITIVE_TRAITS = ["fast_learner", "energizer", "early_bird", "cheap_hire"]
const NEGATIVE_TRAITS = ["toilet_lover", "coffee_lover", "slowpoke", "expensive"]

# Пары-антагонисты (не могут быть вместе)
const CONFLICTING_PAIRS = [
	["fast_learner", "slowpoke"],
	["cheap_hire", "expensive"],
]

func is_positive_trait(trait_id: String) -> bool:
	return trait_id in POSITIVE_TRAITS

func is_negative_trait(trait_id: String) -> bool:
	return trait_id in NEGATIVE_TRAITS

func has_trait(trait_id: String) -> bool:
	return traits.has(trait_id)

func build_trait_text() -> String:
	if traits.is_empty():
		return ""
	var parts: Array[String] = []
	for t in traits:
		if TRAIT_NAMES.has(t):
			parts.append(TRAIT_NAMES[t])
		else:
			parts.append(t)
	return ", ".join(parts)

func get_trait_description(trait_id: String) -> String:
	if TRAIT_DESCRIPTIONS.has(trait_id):
		return TRAIT_DESCRIPTIONS[trait_id]
	return ""

# --- Модификатор скорости работы (учитывает fast_learner и slowpoke) ---
func get_work_speed_multiplier() -> float:
	var mult = 1.0
	if has_trait("fast_learner"):
		mult += 0.2
	if has_trait("slowpoke"):
		mult -= 0.2
	return mult

# --- Модификатор расхода энергии (учитывает energizer) ---
func get_energy_drain_multiplier() -> float:
	if has_trait("energizer"):
		return 0.7  # На 30% медленнее
	return 1.0

var daily_salary: int:
	get:
		return monthly_salary / 30

var hourly_rate: int:
	get:
		if monthly_salary <= 0: return 1
		return monthly_salary / 160

@export var skill_backend: int = 10
@export var skill_qa: int = 5
@export var skill_business_analysis: int = 0

@export var avatar: Texture2D

func get_efficiency_multiplier() -> float:
	if current_energy >= 70.0:
		return 1.0
	elif current_energy >= 50.0:
		return 0.8
	elif current_energy >= 30.0:
		return 0.5
	else:
		return 0.2
