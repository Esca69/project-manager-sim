extends Node
class_name ProjectGenerator

const TITLES = ["Лендинг пекарни", "CRM такси", "Сайт визитка", "Мобильная игра", "Интернет-магазин"]

# Константы для расчета дедлайна
const MARKET_SPEED_PER_HOUR = 60.0 
const WORK_HOURS_PER_DAY = 9.0     

static func generate_random_project(current_game_day: int) -> ProjectData:
	var new_proj = ProjectData.new()
	new_proj.title = TITLES.pick_random()
	
	new_proj.created_at_day = current_game_day 
	
	new_proj.state = new_proj.State.DRAFTING
	
	# 1. Генерируем сложность
	var ba_points = randi_range(1500, 3000)   
	var dev_points = randi_range(4000, 8000)  
	var qa_points = randi_range(2000, 4000)   
	
	# 2. Заполняем массив этапов
	new_proj.stages = [
		{ 
			"type": "BA",  "amount": ba_points,  "progress": 0.0, "workers": [],
			"plan_start": 0.0, "plan_duration": 0.0, 
			"actual_start": -1.0, "actual_end": -1.0, "is_completed": false
		},
		{ 
			"type": "DEV", "amount": dev_points, "progress": 0.0, "workers": [],
			"plan_start": 0.0, "plan_duration": 0.0, 
			"actual_start": -1.0, "actual_end": -1.0, "is_completed": false
		},
		{ 
			"type": "QA",  "amount": qa_points,  "progress": 0.0, "workers": [],
			"plan_start": 0.0, "plan_duration": 0.0, 
			"actual_start": -1.0, "actual_end": -1.0, "is_completed": false
		}
	]
	
	# 3. Расчет Бюджета
	var total_points = ba_points + dev_points + qa_points
	new_proj.budget = int(total_points * 1.5)
	
	# 4. Расчет Хард-дедлайна
	# [ИЗМЕНЕНИЕ] Сокращён в ~2 раза: было 1.4-1.8, стало 0.7-0.9
	var hours_needed_ideal = total_points / MARKET_SPEED_PER_HOUR
	var days_needed_ideal = hours_needed_ideal / WORK_HOURS_PER_DAY
	
	var buffer_coef = randf_range(0.7, 0.9) 
	var days_given = ceil(days_needed_ideal * buffer_coef) + 1
	
	new_proj.deadline_day = current_game_day + int(days_given)
	
	# 5. Расчет Софт-дедлайна (~65-75% от хард-дедлайна)
	var soft_coef = randf_range(0.65, 0.75)
	var soft_days = ceil(days_given * soft_coef)
	new_proj.soft_deadline_day = current_game_day + int(soft_days)
	
	return new_proj
