extends Node2D

# Ссылка на сцену сотрудника
var employee_scene = preload("res://Scenes/Employee.tscn")

# Точка спавна (убедись, что у тебя есть узел SpawnPoint в сцене Office)
@onready var spawn_point = $SpawnPoint

func _ready():
	pass

# Эту функцию вызывает UI Найма
func spawn_new_employee(data: EmployeeData):
	# 1. Создаем копию
	var new_npc = employee_scene.instantiate()
	
	# 2. Настраиваем данные СРАЗУ (до добавления в сцену)
	new_npc.setup_employee(data)
	
	# 3. [ГЛАВНОЕ ИЗМЕНЕНИЕ] Ищем слой для сортировки
	var world_layer = get_tree().get_first_node_in_group("world_layer")
	
	if world_layer:
		# Добавляем сотрудника в слой с Y-Sort
		world_layer.add_child(new_npc)
	else:
		# Если группу забыли, добавляем по старинке (чтобы не упало)
		add_child(new_npc)
		print("ВНИМАНИЕ: Нет группы 'world_layer'! Сортировка может сломаться.")
	
	# 4. РАССЧИТЫВАЕМ ПОЗИЦИЮ
	# Важно делать это ПОСЛЕ добавления add_child, чтобы global_position сработал корректно
	if spawn_point:
		var random_offset = Vector2(randf_range(-50, 50), randf_range(-50, 50))
		new_npc.global_position = spawn_point.global_position + random_offset
	else:
		# На случай если SpawnPoint удалил, ставим в центр
		new_npc.global_position = Vector2(500, 300)

	print("Заспавнен сотрудник: ", data.employee_name)
