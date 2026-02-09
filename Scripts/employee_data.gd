extends Resource
class_name EmployeeData

@export var employee_name: String = "Новичок"
@export var job_title: String = "Junior Developer"
@export var monthly_salary: int = 3000

# Текущая энергия (0.0 - 100.0)
var current_energy: float = 100.0

# --- СИСТЕМА ТРЕЙТОВ ---
# Массив строковых ID трейтов (например: ["coffee_lover"])
@export var traits: Array[String] = []

# Текст для отображения в UI (формируется автоматически)
@export var trait_text: String = ""

# Словарь: ID трейта -> читаемое название для UI
const TRAIT_NAMES = {
	"coffee_lover": "☕ Обожает кофе",
	# Сюда потом добавим новые трейты:
	# "lazy": "🦥 Лентяй",
	# "genius": "🧠 Гений",
}

# Проверка: есть ли у сотрудника конкретный трейт
func has_trait(trait_id: String) -> bool:
	return traits.has(trait_id)

# Собирает trait_text из массива traits для UI
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

var daily_salary: int:
	get:
		return monthly_salary / 30

# Ставка в час (для точного расчета стоимости проекта)
# Считаем 160 рабочих часов в месяц (стандарт)
var hourly_rate: int:
	get:
		if monthly_salary <= 0: return 1
		return monthly_salary / 160

# Навыки (от 0 до 100)
@export var skill_backend: int = 10
@export var skill_qa: int = 5
@export var skill_business_analysis: int = 0

@export var avatar: Texture2D

# --- МАТЕМАТИКА ЭФФЕКТИВНОСТИ ---
# Возвращает коэффициент от 0.2 до 1.0 в зависимости от энергии
func get_efficiency_multiplier() -> float:
	if current_energy >= 70.0:
		return 1.0 # 100% (Бодр и весел)
	elif current_energy >= 50.0:
		return 0.8 # 80% (Нормально)
	elif current_energy >= 30.0:
		return 0.5 # 50% (Устал)
	else:
		return 0.2 # 20% (��омби)
