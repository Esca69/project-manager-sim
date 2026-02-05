extends StaticBody2D

# Данные сотрудника, который тут сидит (если null - стол свободен)
var assigned_employee: EmployeeData = null

# Ссылки на узлы
@onready var name_tag = $NameTag
@onready var seat_point = $SeatPosition # Точка, куда мы телепортируем человека

func _ready():
	# При старте обновляем табличку
	update_desk_visuals()

# Эту функцию вызывает Игрок через interact()
func interact():
	print("Игрок трогает стол...")
	
	if assigned_employee:
		# Если занято - пока просто пишем в консоль
		print("Этот стол занят: ", assigned_employee.employee_name)
		# Тут потом можно сделать меню увольнения/снятия со стола
	else:
		# Если свободно - открываем меню назначения
		print("Стол свободен. Открываем список бомжей...")
		var hud = get_tree().get_first_node_in_group("ui")
		if hud:
			# Ищем наше будущее меню (мы его сейчас создадим)
			var menu = hud.get_node_or_null("AssignmentMenu")
			if menu:
				# Передаем меню ссылку на ЭТОТ стол (self), 
				# чтобы меню знало, кого заселять
				menu.open_assignment_list(self)
			else:
				print("ОШИБКА: AssignmentMenu не найдено в HUD!")

# Эту функцию вызовет Меню, когда мы выберем человека
func assign_employee(data: EmployeeData):
	assigned_employee = data
	update_desk_visuals()
	
	# --- ГЛАВНАЯ МАГИЯ ---
	# Нам нужно найти физическое тело этого сотрудника в мире и посадить его сюда
	# Но пока просто настроим стол. Перемещение добавим следующим шагом.

func update_desk_visuals():
	if assigned_employee:
		name_tag.text = assigned_employee.employee_name
		name_tag.modulate = Color.GREEN # Зеленый текст
	else:
		name_tag.text = "СВОБОДНО"
		name_tag.modulate = Color.WHITE
