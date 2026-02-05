extends Control

# Сигнал, который полетит в HUD, когда мы выберем проект
signal project_selected(data: ProjectData)

@onready var cards = [
	$Panel/HBoxContainer/Card1,
	$Panel/HBoxContainer/Card2,
	$Panel/HBoxContainer/Card3
]

# Временный список проектов
var current_options = []

func _ready():
	visible = false

# Функция открытия меню (генерирует новые варианты)
func open_selection():
	visible = true
	current_options.clear()
	
	for i in range(3):
		# 1. Генерируем проект
		# ИСПРАВЛЕНИЕ: Передаем текущий день из GameTime
		var proj = ProjectGenerator.generate_random_project(GameTime.day)
		current_options.append(proj)
		
		# 2. Пишем текст на кнопке
		var text = proj.title + "\n\n"
		
		# ИСПРАВЛЕНИЕ: Теперь данные лежат в массиве stages, а не в переменных
		# Нам нужно достать цифры из массива
		var ba_amount = 0
		var dev_amount = 0
		var qa_amount = 0
		
		for stage in proj.stages:
			match stage.type:
				"BA": ba_amount = stage.amount
				"DEV": dev_amount = stage.amount
				"QA": qa_amount = stage.amount
		
		text += "BA: " + str(ba_amount) + "\n"
		text += "Dev: " + str(dev_amount) + "\n"
		text += "QA: " + str(qa_amount) + "\n"
		text += "\n"
		
		# Добавляем инфо о дедлайне
		var days_to_finish = proj.deadline_day - GameTime.day
		text += "Срок: " + str(days_to_finish) + " дн.\n"
		text += "$" + str(proj.budget)
		
		cards[i].text = text
		
		# 3. Переподключаем нажатие кнопки
		if cards[i].pressed.is_connected(_on_card_pressed):
			cards[i].pressed.disconnect(_on_card_pressed)
		
		# bind(i) передает номер кнопки в функцию
		cards[i].pressed.connect(_on_card_pressed.bind(i))

# Когда нажали на любую карточку
func _on_card_pressed(index):
	var selected = current_options[index]
	emit_signal("project_selected", selected) # Отправляем выбор наверх
	visible = false # Закрываемся
