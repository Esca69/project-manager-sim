extends Resource
class_name EmployeeData

@export var employee_name: String = "Новичок"
@export var job_title: String = "Junior Developer"
@export var monthly_salary: int = 3000

# Текущая энергия (0.0 - 100.0)
var current_energy: float = 100.0

var daily_salary: int:
	get:
		return monthly_salary / 30

# [НОВОЕ] Ставка в час (для точного расчета стоимости проекта)
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

# --- НОВАЯ МАТЕМАТИКА ЭФФЕКТИВНОСТИ ---
# Возвращает коэффициент от 0.2 до 1.0 в зависимости от энергии
func get_efficiency_multiplier() -> float:
	if current_energy >= 70.0:
		return 1.0 # 100% (Бодр и весел)
	elif current_energy >= 50.0:
		return 0.8 # 80% (Нормально)
	elif current_energy >= 30.0:
		return 0.5 # 50% (Устал)
	else:
		return 0.2 # 20% (Зомби)
