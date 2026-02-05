extends Node
class_name ProjectGenerator

const TITLES = ["Лендинг пекарни", "CRM такси", "Сайт визитка", "Мобильная игра", "Интернет-магазин"]

# Константы для расчета дедлайна
const MARKET_SPEED_PER_HOUR = 60.0 
const WORK_HOURS_PER_DAY = 9.0     

static func generate_random_project(current_game_day: int) -> ProjectData:
	var new_proj = ProjectData.new()
	new_proj.title = TITLES.pick_random()
	
	# Теперь это работает, так как мы вернули переменную в ProjectData
	new_proj.created_at_day = current_game_day 
	
	new_proj.state = new_proj.State.DRAFTING
	
	# 1. Генерируем сложность
	var ba_points = randi_range(1500, 3000)   
	var dev_points = randi_range(4000, 8000)  
	var qa_points = randi_range(2000, 4000)   
	
	# 2. Заполняем массив этапов (СРАЗУ С ПОЛНОЙ СТРУКТУРОЙ)
	# Это предотвратит ошибки "Invalid index" в будущем
	new_proj.stages = [
		{ 
			"type": "BA",  "amount": ba_points,  "progress": 0.0, "worker": null,
			"plan_start": 0.0, "plan_duration": 0.0, 
			"actual_start": -1.0, "actual_end": -1.0, "is_completed": false
		},
		{ 
			"type": "DEV", "amount": dev_points, "progress": 0.0, "worker": null,
			"plan_start": 0.0, "plan_duration": 0.0, 
			"actual_start": -1.0, "actual_end": -1.0, "is_completed": false
		},
		{ 
			"type": "QA",  "amount": qa_points,  "progress": 0.0, "worker": null,
			"plan_start": 0.0, "plan_duration": 0.0, 
			"actual_start": -1.0, "actual_end": -1.0, "is_completed": false
		}
	]
	
	# 3. Расчет Бюджета
	var total_points = ba_points + dev_points + qa_points
	new_proj.budget = int(total_points * 1.5)
	
	# 4. Расчет Дедлайна
	var hours_needed_ideal = total_points / MARKET_SPEED_PER_HOUR
	var days_needed_ideal = hours_needed_ideal / WORK_HOURS_PER_DAY
	
	var buffer_coef = randf_range(1.4, 1.8) 
	var days_given = ceil(days_needed_ideal * buffer_coef) + 1
	
	new_proj.deadline_day = current_game_day + int(days_given)
	
	return new_proj
